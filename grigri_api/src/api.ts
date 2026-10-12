// The routes (specs/api.md): authorization, then the domain rules, then the
// store. Every route but GET /api/health and POST /api/session needs a
// caller (handler.ts finds it from the session token); most also need the
// caller's profile (409 "no profile" until GET /api/me creates it, from the
// Google account's name, or PUT /api/me saves it).
import { randomBytes } from 'node:crypto';
import { type Auth, type Caller, subjectHash } from './auth.js';
import { ApiError, badRequest, conflict, forbidden, notFound } from './domain/errors.js';
import {
  type Climber,
  type JoinRequest,
  type Plan,
  type PublicClimber,
  isOpen,
  publicClimber,
  requestJson,
} from './domain/model.js';
import * as rules from './domain/rules.js';
import { asObject, id, messageText, parseDate, planInput, profileInput } from './domain/validate.js';
import { type Params, Router } from './router.js';
import { type Delivery, type Realtime, hintsFor } from './realtime.js';
import { Conflict, type LoadedPlan, type Store } from './store/store.js';

/** Most requests a plan keeps waiting: bounds its transactions (DynamoDB takes 100 items; each join writes 3). */
export const MAX_OPEN_REQUESTS = 30;

/** A new profile's name when Google didn't give one (sessions from before names were kept). */
export const NO_NAME = 'Climber';

export interface Photos {
  /**
   * A presigned POST for `key` (S3 object photos/<key>). The object is
   * tagged pending: the bucket expires it after a day unless kept.
   */
  presign(key: string, contentType: string): Promise<{ url: string; fields: Record<string, string> }>;
  /** Clears the pending tag of photos a profile now uses; false for one that isn't there. */
  keep(key: string): Promise<boolean>;
  /** Deletes photos a profile no longer uses. */
  remove(keys: string[]): Promise<void>;
}

export interface Config {
  stage: string;
  version: string;
}

export interface Deps {
  store: Store;
  photos: Photos;
  auth: Pick<Auth, 'signIn' | 'signOut' | 'signOutEverywhere'>;
  config: Config;
  /** Live updates' hints (realtime.ts); none: off. */
  realtime?: Realtime;
  clock?: () => Date;
}

export interface Request {
  caller: Caller | null;
  params: Params;
  query: Record<string, string | undefined>;
  body: unknown;
}

/** public: anyone; session: a caller, nothing loaded; caller: plus their profile if any; profile: must have one; admin: and be one. */
export type Access = 'public' | 'session' | 'caller' | 'profile' | 'admin';

interface Session {
  caller: Caller;
  /** The caller's profile ('profile' and 'admin' routes always have one). */
  me: Climber;
  now: Date;
  ctx: rules.Context;
  /** Names known so far, for the chat's notes. */
  names: Map<string, string>;
}

type Handler = (req: Request, s: Session) => Promise<unknown>;

interface Route {
  access: Access;
  handler: Handler;
}

function photosOf(c: Pick<Climber, 'photo' | 'gearPhotos'>): string[] {
  return [...(c.photo ? [c.photo] : []), ...c.gearPhotos];
}

/** A URL-safe random id (16 characters, 96 bits). */
export function newId(): string {
  return randomBytes(12).toString('base64url');
}

/** Message ids that sort in creation order within one request. */
function messageIds(): () => string {
  let n = 0;
  return () => `${(n++).toString().padStart(3, '0')}${randomBytes(6).toString('base64url')}`;
}

const CONTENT_TYPES: Record<string, string> = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' };

export class Api {
  private readonly router = new Router<Route>();
  private readonly store: Store;
  private readonly clock: () => Date;

  constructor(private readonly deps: Deps) {
    this.store = deps.store;
    this.clock = deps.clock ?? (() => new Date());
    const r = (pattern: string, access: Access, handler: Handler) => this.router.add(pattern, { access, handler });

    r('GET /api/health', 'public', async () => ({ ok: true, stage: deps.config.stage, version: deps.config.version }));

    r('POST /api/session', 'public', (req) => deps.auth.signIn(req.body));
    r('DELETE /api/session', 'session', async (_req, s) => {
      await deps.auth.signOut(s.caller);
      return {};
    });
    r('DELETE /api/sessions', 'session', async (_req, s) => {
      await deps.auth.signOutEverywhere(s.caller);
      return {};
    });

    r('GET /api/me', 'caller', async (_req, s) => ({ climber: await this.myProfile(s), admin: s.caller.admin }));
    r('PUT /api/me', 'caller', (req, s) => this.saveProfile(req, s));
    r('POST /api/photos', 'caller', (req, s) => this.presignPhoto(req, s));
    r('GET /api/realtime', 'profile', async (_req, s) => deps.realtime?.info(s.me.id) ?? { url: null });

    r('GET /api/discover', 'profile', (_req, s) => this.discover(s));
    r('POST /api/plans', 'profile', (req, s) => this.createPlan(req, s));
    r('GET /api/plans', 'profile', (_req, s) => this.myPlans(s));
    r('GET /api/plans/{id}', 'profile', (req, s) => this.getPlan(req, s));
    r('PUT /api/plans/{id}', 'profile', (req, s) => this.updatePlan(req, s));
    r('POST /api/plans/{id}/leave', 'profile', (req, s) => this.leave(req, s));
    r('POST /api/plans/{id}/join', 'profile', (req, s) => this.join(req, s));
    r('POST /api/plans/{id}/pass', 'profile', (req, s) => this.pass(req, s));
    r('GET /api/plans/{id}/messages', 'profile', (req, s) => this.messages(req, s));
    r('POST /api/plans/{id}/messages', 'profile', (req, s) => this.send(req, s));

    r('GET /api/requests', 'profile', (_req, s) => this.toReview(s));
    r('POST /api/requests/{planId}/{climberId}/accept', 'profile', (req, s) => this.answer(req, s, 'accept', false));
    r('POST /api/requests/{planId}/{climberId}/reject', 'profile', (req, s) => this.answer(req, s, 'reject', false));
    r('POST /api/requests/{planId}/{climberId}/dismiss', 'profile', (req, s) => this.dismiss(req, s));

    r('GET /api/notices', 'profile', (_req, s) => this.notices(s));
    r('POST /api/notices/read', 'profile', async (_req, s) => {
      await this.store.markNoticesRead(s.me.id);
      return {};
    });

    r('GET /api/admin/requests', 'admin', () => this.adminRequests());
    r('POST /api/admin/requests/{planId}/{climberId}/accept', 'admin', (req, s) => this.answer(req, s, 'accept', true));
    r('POST /api/admin/requests/{planId}/{climberId}/reject', 'admin', (req, s) => this.answer(req, s, 'reject', true));
  }

  /** Who may call a route (404 for no such route). */
  access(method: string, path: string): Access {
    return this.router.match(method, path).handler.access;
  }

  /** Runs a request: the route's access rule, then its handler. */
  async handle(method: string, path: string, req: Omit<Request, 'params'>): Promise<unknown> {
    const { handler: route, params } = this.router.match(method, path);
    const full: Request = { ...req, params };
    if (route.access === 'public') return route.handler(full, undefined as never);
    if (!req.caller) throw new ApiError(401, 'signed out');
    const now = this.clock();
    if (route.access === 'session') {
      const names = new Map<string, string>();
      const ctx = { now, newId: messageIds(), name: () => 'Someone' };
      return route.handler(full, { caller: req.caller, me: undefined as never, now, ctx, names });
    }
    const climberId = await this.store.climberIdFor(req.caller.subject);
    const me = climberId ? await this.store.getClimber(climberId) : undefined;
    if (!me && route.access !== 'caller') throw conflict('no profile');
    if (route.access === 'admin' && !req.caller.admin) throw forbidden('admins only');
    const names = new Map<string, string>();
    const session: Session = {
      caller: req.caller,
      // Undefined only on 'caller' routes, before the first GET or PUT /api/me.
      me: me as Climber,
      now,
      ctx: { now, newId: messageIds(), name: (cid) => names.get(cid) ?? 'Someone' },
      names,
    };
    if (me) names.set(me.id, me.name);
    return route.handler(full, session);
  }

  // --- Profile and photos --------------------------------------------------

  /**
   * GET /api/me: my profile, created the first time from my Google account
   * (its name; the rest empty, for me to fill in).
   */
  private async myProfile(s: Session): Promise<Climber> {
    if (s.me) return s.me;
    const starter: Climber = {
      id: newId(),
      name: s.caller.name ?? NO_NAME,
      bio: '',
      levels: {},
      gear: [],
      gearPhotos: [],
    };
    try {
      await this.store.createProfile(s.caller.subject, starter, s.now);
      return starter;
    } catch (e) {
      if (!(e instanceof Conflict)) throw e;
      // Created meanwhile (two first loads at once): that one.
      const existing = await this.store.climberIdFor(s.caller.subject);
      const climber = existing ? await this.store.getClimber(existing) : undefined;
      if (!climber) throw e;
      return climber;
    }
  }

  private async saveProfile(req: Request, s: Session) {
    const owners = [subjectHash(s.caller.subject), ...(s.me ? [s.me.id] : [])];
    const input = profileInput(req.body, owners);
    // Photos: new ones lose their pending tag before the profile points at
    // them (else the bucket would expire them); ones it no longer uses are
    // deleted after it's saved.
    const before = new Set(s.me ? photosOf(s.me) : []);
    const after = new Set(photosOf(input));
    for (const key of after) {
      if (before.has(key)) continue;
      if (!(await this.deps.photos.keep(key))) throw badRequest(`photo ${key} isn't uploaded (or expired): upload it again`);
    }
    // Only ever my own folder's (defense in depth: saved keys were checked).
    const unused = [...before].filter((key) => !after.has(key) && owners.includes(key.split('/')[0]!));
    let saved: Climber;
    if (s.me) {
      saved = { id: s.me.id, ...input };
      await this.store.saveProfile(saved, s.caller.subject, s.now);
    } else {
      saved = { id: newId(), ...input };
      try {
        await this.store.createProfile(s.caller.subject, saved, s.now);
      } catch (e) {
        if (!(e instanceof Conflict)) throw e;
        // Created meanwhile (two first saves at once): update that one.
        const existing = await this.store.climberIdFor(s.caller.subject);
        if (!existing) throw e;
        saved = { ...saved, id: existing };
        await this.store.saveProfile(saved, s.caller.subject, s.now);
      }
    }
    if (unused.length > 0) {
      // Best effort: a leftover only costs storage.
      await this.deps.photos.remove(unused).catch((e: unknown) => {
        console.error(JSON.stringify({ level: 'warn', msg: 'photo cleanup failed', error: String(e) }));
      });
    }
    return { climber: saved };
  }

  private async presignPhoto(req: Request, s: Session) {
    const o = asObject(req.body);
    if (o.kind !== 'profile' && o.kind !== 'gear') throw badRequest('kind must be profile or gear');
    const ext = typeof o.contentType === 'string' ? CONTENT_TYPES[o.contentType] : undefined;
    if (!ext) throw badRequest(`contentType must be one of ${Object.keys(CONTENT_TYPES).join(', ')}`);
    const key = `${subjectHash(s.caller.subject)}/${o.kind}/${newId()}.${ext}`;
    const { url, fields } = await this.deps.photos.presign(key, o.contentType as string);
    return { key, url, fields };
  }

  // --- Decks and plans ------------------------------------------------------

  private async discover(s: Session) {
    const [upcoming, passed, asked] = await Promise.all([
      this.store.upcomingPlans(s.now.toISOString()),
      this.store.passedPlanIds(s.me.id),
      this.store.askedRequests(s.me.id),
    ]);
    const deck = rules.discover(upcoming, s.me, new Set(passed), new Set(asked.map((r) => r.planId)), s.now);
    return { plans: deck.plans, distanceKm: deck.distanceKm, climbers: await this.climbersOf(deck.plans) };
  }

  private async createPlan(req: Request, s: Session) {
    const input = planInput(req.body, s.now);
    const effects = rules.createPlan(newId(), s.me.id, input, s.ctx);
    await this.store.apply(null, effects, s.now);
    return { plan: effects.plan };
  }

  private async myPlans(s: Session) {
    const [memberOf, asked, passed] = await Promise.all([
      this.store.memberPlanIds(s.me.id),
      this.store.askedRequests(s.me.id),
      this.store.passedPlanIds(s.me.id),
    ]);
    const passedSet = new Set(passed);
    const waiting = asked.filter((r) => !r.joined && !r.dismissed && (!r.rejected || !passedSet.has(r.planId)));
    const plans = await this.store.getPlans([...memberOf, ...waiting.map((r) => r.planId)]);
    const byId = new Map(plans.map((p) => [p.id, p]));
    const mine = rules.soonestFirst(plans.filter((p) => p.memberIds.includes(s.me.id)));
    const askedOut = waiting
      .filter((r) => byId.has(r.planId) && !byId.get(r.planId)!.memberIds.includes(s.me.id))
      .sort((a, b) => (a.time > b.time ? -1 : 1))
      .map((r) => ({ request: requestJson(r), plan: byId.get(r.planId)! }));
    return {
      plans: mine,
      asked: askedOut,
      climbers: await this.climbersOf([...mine, ...askedOut.map((a) => a.plan)]),
    };
  }

  private async getPlan(req: Request, s: Session) {
    const loaded = await this.loadPlan(req.params.id);
    const member = loaded.plan.memberIds.includes(s.me.id);
    const requests = member ? loaded.requests.filter((r) => isOpen(r) && !loaded.plan.memberIds.includes(r.climberId)) : [];
    return {
      plan: loaded.plan,
      requests: requests.map(requestJson),
      climbers: await this.climbersOf([loaded.plan], requests),
    };
  }

  private async updatePlan(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    return this.retry(async () => {
      const current = await this.store.getPlan(planId);
      if (!current) throw notFound('no such plan');
      const input = planInput(req.body, s.now);
      const plan = rules.updatePlan(current.plan, s.me.id, input);
      await this.store.apply(current, { plan, requests: [], notices: [], messages: [], matches: [] }, s.now);
      await this.hint(hintsFor(plan.memberIds, { kind: 'plan', planId }, s.me.id));
      return { plan };
    });
  }

  private async leave(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    const members = await this.retry(async () => {
      const loaded = await this.loadPlan(planId);
      await this.loadNames(s, loaded.plan.memberIds, loaded.requests.map((r) => r.climberId));
      const effects = rules.leave(loaded, s.me.id, s.ctx);
      await this.store.apply(loaded, effects, s.now);
      return effects.plan?.memberIds ?? [];
    });
    // Out of my deck, now that I've left it.
    await this.store.addPass(s.me.id, planId, s.now);
    await this.hint(hintsFor(members, { kind: 'plan', planId }, s.me.id));
    return {};
  }

  private async join(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    return this.retry(async () => {
      const loaded = await this.loadPlan(planId);
      if (loaded.requests.filter(isOpen).length >= MAX_OPEN_REQUESTS) {
        throw conflict('the plan has too many requests waiting; try again later');
      }
      const existing = loaded.requests.find((r) => r.climberId === s.me.id);
      const effects = rules.ask(loaded.plan, s.me.id, existing, s.ctx);
      try {
        await this.store.ask(loaded, effects);
      } catch (e) {
        // My request appeared meanwhile (a double swipe): already asked.
        if (e instanceof Conflict && (await this.store.getRequest(planId, s.me.id))) {
          throw conflict('you already asked to join this plan');
        }
        throw e;
      }
      await this.hint(hintsFor(loaded.plan.memberIds, { kind: 'request', planId }, s.me.id));
      return { request: requestJson(effects.requests[0]!) };
    });
  }

  private async pass(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    if (!(await this.store.getPlan(planId))) throw notFound('no such plan');
    await this.store.addPass(s.me.id, planId, s.now);
    return {};
  }

  // --- Requests -------------------------------------------------------------

  private async toReview(s: Session) {
    const planIds = await this.store.memberPlanIds(s.me.id);
    const loaded = (await Promise.all(planIds.map((p) => this.store.loadPlan(p)))).filter(
      (l): l is LoadedPlan => l !== undefined,
    );
    const requests = rules.toReview(loaded, s.me.id);
    const plans = loaded.map((l) => l.plan).filter((p) => requests.some((r) => r.planId === p.id));
    return {
      requests: requests.map(requestJson),
      plans: Object.fromEntries(plans.map((p) => [p.id, p])),
      climbers: await this.climbersOf(plans, requests),
    };
  }

  private async answer(req: Request, s: Session, kind: 'accept' | 'reject', admin: boolean) {
    const planId = id(req.params.planId, 'plan id');
    const climberId = id(req.params.climberId, 'climber id');
    const actor = { id: s.me.id, admin };
    return this.retry(async () => {
      const loaded = await this.loadPlan(planId);
      await this.loadNames(s, loaded.plan.memberIds, loaded.requests.map((r) => r.climberId));
      const effects =
        kind === 'accept' ? rules.accept(loaded, actor, climberId, s.ctx) : rules.reject(loaded, actor, climberId, s.ctx);
      await this.store.apply(loaded, effects, s.now);
      await this.hint(answerHints(loaded, effects, kind, climberId, s.me.id));
      if (kind === 'reject') return {};
      return { match: effects.matches.find((m) => m.newcomerId === climberId) ?? null };
    });
  }

  private async dismiss(req: Request, s: Session) {
    const planId = id(req.params.planId, 'plan id');
    const climberId = id(req.params.climberId, 'climber id');
    if (climberId !== s.me.id) throw forbidden('only the requester can dismiss it');
    const request = rules.dismiss(await this.store.getRequest(planId, climberId), s.me.id);
    try {
      await this.store.saveDismissed(request);
    } catch (e) {
      if (e instanceof Conflict) throw conflict('changed meanwhile');
      throw e;
    }
    await this.store.addPass(s.me.id, planId, s.now);
    return {};
  }

  private async adminRequests() {
    const open = await this.store.openRequests();
    const plans = await this.store.getPlans(open.map((r) => r.planId));
    const byId = new Map(plans.map((p) => [p.id, p]));
    const requests = open.filter((r) => isOpen(r) && byId.has(r.planId) && !byId.get(r.planId)!.memberIds.includes(r.climberId));
    return {
      requests: requests.map(requestJson),
      plans: Object.fromEntries(plans.map((p) => [p.id, p])),
      climbers: await this.climbersOf(plans, requests),
    };
  }

  // --- Notices and chat -------------------------------------------------------

  private async notices(s: Session) {
    const notices = await this.store.notices(s.me.id);
    const ids = notices.flatMap((n) => (n.climberId ? [n.climberId] : []));
    return { notices, climbers: await this.publicClimbers(ids) };
  }

  private async messages(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    const current = await this.store.getPlan(planId);
    if (!current) throw notFound('no such plan');
    if (!current.plan.memberIds.includes(s.me.id)) throw forbidden("you're not in this plan");
    const after = req.query.after ? parseDate(req.query.after, 'after').toISOString() : undefined;
    const messages = await this.store.messages(planId, after);
    const ids = new Set<string>(current.plan.memberIds);
    for (const m of messages) {
      if (m.authorId) ids.add(m.authorId);
      if (m.requestId) ids.add(m.requestId.split('/')[1]!);
    }
    return { messages, climbers: await this.publicClimbers(ids) };
  }

  private async send(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    const text = messageText(req.body);
    const current = await this.store.getPlan(planId);
    if (!current) throw notFound('no such plan');
    const message = rules.chatMessage(current.plan, s.me.id, text, s.ctx);
    await this.store.putMessage(message);
    await this.hint(hintsFor(current.plan.memberIds, { kind: 'message', planId }, s.me.id));
    return { message };
  }

  // --- Helpers ------------------------------------------------------------------

  /** Live updates: best effort, never fails the request (Realtime.notify). */
  private async hint(deliveries: Delivery[]): Promise<void> {
    await this.deps.realtime?.notify(deliveries);
  }

  private async loadPlan(rawId: string | undefined): Promise<LoadedPlan> {
    const planId = id(rawId, 'plan id');
    const loaded = await this.store.loadPlan(planId);
    if (!loaded) throw notFound('no such plan');
    return loaded;
  }

  /** Names for the chat's notes. */
  private async loadNames(s: Session, ...groups: string[][]): Promise<void> {
    const { names } = s;
    const missing = groups.flat().filter((cid) => !names.has(cid));
    const climbers = await this.store.getClimbers(missing);
    for (const c of Object.values(climbers)) names.set(c.id, c.name);
  }

  /** Every climber the plans and requests mention. */
  private climbersOf(plans: Plan[], requests: JoinRequest[] = []): Promise<Record<string, PublicClimber>> {
    const ids = new Set<string>();
    for (const p of plans) {
      ids.add(p.organizerId);
      for (const m of p.memberIds) ids.add(m);
    }
    for (const r of requests) {
      ids.add(r.climberId);
      for (const a of r.acceptedBy) ids.add(a);
    }
    return this.publicClimbers(ids);
  }

  /** Other people's profiles, without where they are (location and areas are only mine to see). */
  private async publicClimbers(ids: Iterable<string>): Promise<Record<string, PublicClimber>> {
    const climbers = await this.store.getClimbers(ids);
    return Object.fromEntries(Object.entries(climbers).map(([cid, c]) => [cid, publicClimber(c)]));
  }

  /** Runs a read-decide-write step again when a conditional write lost a race. */
  private async retry<T>(step: () => Promise<T>): Promise<T> {
    for (let attempt = 1; ; attempt++) {
      try {
        return await step();
      } catch (e) {
        if (!(e instanceof Conflict)) throw e;
        if (attempt >= 4) throw conflict('changed meanwhile; try again');
        await new Promise((resolve) => setTimeout(resolve, 20 * attempt + Math.random() * 30));
      }
    }
  }
}

/**
 * Who hears about an answer: a newcomer (everyone said yes) gets a match
 * and the members a plan change; a partial yes is a request change for
 * the members; a no tells the requester (a notice) and the members.
 */
export function answerHints(
  before: { plan: Plan },
  effects: rules.Effects,
  kind: 'accept' | 'reject',
  climberId: string,
  actorId: string,
): Delivery[] {
  const planId = before.plan.id;
  const members = effects.plan?.memberIds ?? before.plan.memberIds;
  if (kind === 'reject') {
    return [
      ...hintsFor([climberId], { kind: 'notice', planId }, actorId),
      ...hintsFor(before.plan.memberIds, { kind: 'request', planId }, actorId),
    ];
  }
  const newcomers = new Set(effects.matches.map((m) => m.newcomerId));
  if (newcomers.size === 0) return hintsFor(members, { kind: 'request', planId }, actorId);
  return [
    ...hintsFor(newcomers, { kind: 'match', planId }, actorId),
    ...hintsFor(members.filter((m) => !newcomers.has(m)), { kind: 'plan', planId }, actorId),
  ];
}
