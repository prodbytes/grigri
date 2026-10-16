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
  type PicCatalog,
  type Plan,
  type PlanPic,
  type PublicClimber,
  isOpen,
  publicClimber,
  requestJson,
} from './domain/model.js';
import { type PicWithCrag, type Where, picsFor } from './domain/pics.js';
import * as rules from './domain/rules.js';
import { asObject, id, messageInput, parseDate, planInput, planPicKey, profileInput } from './domain/validate.js';
import { type MatchScore, type MatchScorer, pooled } from './match/aityx.js';
import { matchFacts } from './match/facts.js';
import { openByPlan, othersWaiting } from './match/run.js';
import type { RolesLookup } from './rbacr.js';
import type { ScoresStore } from './store/scores.js';
import { type Params, Router } from './router.js';
import { type Delivery, type Realtime, hintsFor } from './realtime.js';
import { Conflict, type LoadedPlan, type Store } from './store/store.js';

/** Most requests a plan keeps waiting: bounds its transactions (DynamoDB takes 100 items; each join writes 3). */
export const MAX_OPEN_REQUESTS = 30;

/** A new profile's name when Google didn't give one (sessions from before names were kept). */
export const NO_NAME = 'Climber';

/** The deck's plans an admin's deck scores (the best first), and how many at once. */
export const SCORED_DECK = 30;
const SCORE_CONCURRENCY = 10;
/**
 * No new call to aityx after this long: with one call's own timeout (3 s),
 * the deck answers within about 7 s, under the HTTP API's 10.
 */
const SCORE_BUDGET_MS = 4000;
/** The best scores the admin's preview shows. */
export const SCORES_PREVIEW = 20;

/** Largest photo upload (profile, gear, chat): the app downsizes them well under it. */
export const MAX_PHOTO_BYTES = 2 * 1024 * 1024;
/** Largest chat video upload. */
export const MAX_VIDEO_BYTES = 50 * 1024 * 1024;

/** Most photos a plan's "Your Pics" keeps (chat photos past it stay in the chat only). */
export const MAX_PLAN_PICS = 100;

export interface Photos {
  /**
   * A presigned POST for `key` (S3 object photos/<key>) of `contentType`,
   * at most `maxBytes`. The object is tagged pending: the bucket expires it
   * after a day unless kept.
   */
  presign(key: string, contentType: string, maxBytes: number): Promise<{ url: string; fields: Record<string, string> }>;
  /** Clears the pending tag of photos a profile or a chat message now uses; false for one that isn't there. */
  keep(key: string): Promise<boolean>;
  /** Deletes photos a profile no longer uses. */
  remove(keys: string[]): Promise<void>;
}

/** GriGri Pics: Grigri's own crag photos (specs/pics.md). */
export interface GrigriPics {
  /** The catalog (pics/catalog.json); empty when there's none yet. */
  catalog(): Promise<PicCatalog>;
}

export interface Config {
  stage: string;
  version: string;
}

export interface Deps {
  store: Store;
  photos: Photos;
  /** GriGri Pics' catalog; none: no GriGri Pics. */
  pics?: GrigriPics;
  auth: Pick<Auth, 'signIn' | 'signOut' | 'signOutEverywhere'>;
  config: Config;
  /** Live updates' hints (realtime.ts); none: off. */
  realtime?: Realtime;
  /** My roles in Grigri, from rbacr (rbacr.ts); none: unknown. */
  roles?: RolesLookup;
  /** Match scores from aityx (match/aityx.ts), on admins' decks; none: off. */
  matchScorer?: MatchScorer;
  /** The match scores table (store/scores.ts), for the admin's preview; none: off. */
  scores?: Pick<ScoresStore, 'top' | 'latestRun'>;
  /** Keeps the demo showcase upcoming (seed/seed.ts); runs before the deck. */
  showcase?: (now: Date) => Promise<void>;
  clock?: () => Date;
  /** In [0, 1): picks a new organizer when one leaves; default Math.random. */
  random?: () => number;
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
/** What a chat can carry: photos as above, and MP4 or QuickTime videos. Nothing else. */
const VIDEO_TYPES: Record<string, string> = { 'video/mp4': 'mp4', 'video/quicktime': 'mov' };
const CHAT_TYPES: Record<string, string> = { ...CONTENT_TYPES, ...VIDEO_TYPES };

export class Api {
  private readonly router = new Router<Route>();
  private readonly store: Store;
  private readonly clock: () => Date;
  private readonly random: () => number;

  constructor(private readonly deps: Deps) {
    this.store = deps.store;
    this.clock = deps.clock ?? (() => new Date());
    this.random = deps.random ?? Math.random;
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

    r('GET /api/me', 'caller', async (_req, s) => {
      const email = s.caller.email;
      const [climber, roles] = await Promise.all([
        this.myProfile(s),
        email && deps.roles ? deps.roles(email) : Promise.resolve(null),
      ]);
      // roles: my roles in Grigri from rbacr, or null when it can't say.
      return { climber, admin: s.caller.admin, roles };
    });
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
    r('POST /api/plans/{id}/nudge', 'profile', (req, s) => this.nudge(req, s));
    r('POST /api/plans/{id}/pass', 'profile', (req, s) => this.pass(req, s));
    r('DELETE /api/passes', 'profile', (_req, s) => this.clearPasses(s));
    r('GET /api/plans/{id}/messages', 'profile', (req, s) => this.messages(req, s));
    r('POST /api/plans/{id}/messages', 'profile', (req, s) => this.send(req, s));
    r('POST /api/plans/{id}/media', 'profile', (req, s) => this.presignChatMedia(req, s));
    r('GET /api/plans/{id}/pics', 'profile', (req, s) => this.planPics(req, s));
    r('POST /api/plans/{id}/pics/upload', 'profile', (req, s) => this.presignPlanPic(req, s));
    r('POST /api/plans/{id}/pics', 'profile', (req, s) => this.addPlanPic(req, s));
    r('DELETE /api/plans/{id}/pics/{picId}', 'profile', (req, s) => this.deletePlanPic(req, s));
    r('GET /api/pics', 'profile', async (req) => ({ pics: await this.grigriPics(whereFrom(req.query)) }));

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
    r('GET /api/admin/scores', 'admin', () => this.adminScores());
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
      const ctx = { now, newId: messageIds(), name: () => 'Someone', random: this.random };
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
      ctx: { now, newId: messageIds(), name: (cid) => names.get(cid) ?? 'Someone', random: this.random },
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
    const ext = typeof o.contentType === 'string' && Object.hasOwn(CONTENT_TYPES, o.contentType) ? CONTENT_TYPES[o.contentType] : undefined;
    if (!ext) throw badRequest(`contentType must be one of ${Object.keys(CONTENT_TYPES).join(', ')}`);
    const key = `${subjectHash(s.caller.subject)}/${o.kind}/${newId()}.${ext}`;
    const { url, fields } = await this.deps.photos.presign(key, o.contentType as string, MAX_PHOTO_BYTES);
    return { key, url, fields };
  }

  /**
   * POST /api/plans/{id}/media: where a member uploads a photo or video for
   * the plan's chat (key `chat/<planId>/<id>.<ext>`, pending until a
   * message uses it).
   */
  private async presignChatMedia(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    const o = asObject(req.body);
    const contentType = typeof o.contentType === 'string' ? o.contentType : '';
    const ext = Object.hasOwn(CHAT_TYPES, contentType) ? CHAT_TYPES[contentType] : undefined;
    if (!ext) throw badRequest(`contentType must be one of ${Object.keys(CHAT_TYPES).join(', ')}`);
    const current = await this.store.getPlan(planId);
    if (!current) throw notFound('no such plan');
    if (!current.plan.memberIds.includes(s.me.id)) throw forbidden("you're not in this plan");
    const key = `chat/${planId}/${newId()}.${ext}`;
    const maxBytes = Object.hasOwn(VIDEO_TYPES, contentType) ? MAX_VIDEO_BYTES : MAX_PHOTO_BYTES;
    const { url, fields } = await this.deps.photos.presign(key, contentType, maxBytes);
    return { key, url, fields, maxBytes };
  }

  // --- Plan pics: "Your Pics" and GriGri Pics ----------------------------------

  /**
   * GET /api/plans/{id}/pics: the plan's GriGri Pics (anyone who can see
   * the plan) and, for members, its "Your Pics".
   */
  private async planPics(req: Request, s: Session) {
    const current = await this.store.getPlan(id(req.params.id, 'plan id'));
    if (!current) throw notFound('no such plan');
    const { plan } = current;
    const member = plan.memberIds.includes(s.me.id);
    const [yours, grigri] = await Promise.all([
      member ? this.store.planPics(plan.id) : Promise.resolve([] as PlanPic[]),
      this.grigriPics({ sectorId: plan.sectorId, lat: plan.lat, lon: plan.lon, place: plan.place, area: plan.area }),
    ]);
    return { yours, grigri, member, climbers: await this.publicClimbers(new Set(yours.map((p) => p.uploaderId))) };
  }

  /** GriGri Pics for a place; none (never an error) when the catalog can't be read. */
  private async grigriPics(where: Where): Promise<PicWithCrag[]> {
    if (!this.deps.pics) return [];
    try {
      return picsFor(await this.deps.pics.catalog(), where);
    } catch (e) {
      console.error(JSON.stringify({ level: 'warn', msg: 'pics catalog failed', error: String(e) }));
      return [];
    }
  }

  /** POST /api/plans/{id}/pics/upload: where a member uploads a photo for the plan (`plans/<planId>/<id>.<ext>`, pending until added). */
  private async presignPlanPic(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    const o = asObject(req.body);
    const ext = typeof o.contentType === 'string' && Object.hasOwn(CONTENT_TYPES, o.contentType) ? CONTENT_TYPES[o.contentType] : undefined;
    if (!ext) throw badRequest(`contentType must be one of ${Object.keys(CONTENT_TYPES).join(', ')}`);
    await this.memberPlan(planId, s);
    const key = `plans/${planId}/${newId()}.${ext}`;
    const { url, fields } = await this.deps.photos.presign(key, o.contentType as string, MAX_PHOTO_BYTES);
    return { key, url, fields, maxBytes: MAX_PHOTO_BYTES };
  }

  /** POST /api/plans/{id}/pics: a member adds an uploaded photo to the plan. */
  private async addPlanPic(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    const key = planPicKey(asObject(req.body).key, planId);
    const plan = await this.memberPlan(planId, s);
    const pics = await this.store.planPics(planId);
    if (pics.length >= MAX_PLAN_PICS) throw conflict(`a plan keeps at most ${MAX_PLAN_PICS} photos; delete one first`);
    const existing = pics.find((p) => p.key === key);
    if (existing) return { pic: existing };
    if (!(await this.deps.photos.keep(key))) throw badRequest("the photo isn't uploaded (or expired): upload it again");
    const pic: PlanPic = { id: newId(), planId, key, uploaderId: s.me.id, time: s.now.toISOString(), fromChat: false };
    await this.store.putPlanPic(pic);
    await this.hint(hintsFor(plan.memberIds, { kind: 'pics', planId }, s.me.id));
    return { pic };
  }

  /**
   * DELETE /api/plans/{id}/pics/{picId}: whoever added it, the organizer or
   * an admin. A photo added here is deleted; a chat photo stays in the chat.
   */
  private async deletePlanPic(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    const picId = id(req.params.picId, 'pic id');
    const current = await this.store.getPlan(planId);
    if (!current) throw notFound('no such plan');
    const { plan } = current;
    if (!plan.memberIds.includes(s.me.id) && !s.caller.admin) throw forbidden("you're not in this plan");
    const pic = (await this.store.planPics(planId)).find((p) => p.id === picId);
    if (!pic) throw notFound('no such photo');
    if (pic.uploaderId !== s.me.id && plan.organizerId !== s.me.id && !s.caller.admin) {
      throw forbidden('only whoever added it, or the organizer, can delete it');
    }
    await this.store.deletePlanPic(planId, picId);
    if (!pic.fromChat) {
      // Best effort: a leftover only costs storage, and expires anyway.
      await this.deps.photos.remove([pic.key]).catch((e: unknown) => {
        console.error(JSON.stringify({ level: 'warn', msg: 'plan pic cleanup failed', error: String(e) }));
      });
    }
    await this.hint(hintsFor(plan.memberIds, { kind: 'pics', planId }, s.me.id));
    return {};
  }

  /** A plan I'm in (404: none; 403: not mine). */
  private async memberPlan(planId: string, s: Session): Promise<Plan> {
    const current = await this.store.getPlan(planId);
    if (!current) throw notFound('no such plan');
    if (!current.plan.memberIds.includes(s.me.id)) throw forbidden("you're not in this plan");
    return current.plan;
  }

  // --- Decks and plans ------------------------------------------------------

  private async discover(s: Session) {
    // The demo plans' dates move with time: re-dated twice a day, by the
    // first deck asked for after that. Never fails the deck.
    await this.deps.showcase?.(s.now).catch((e: unknown) => {
      console.error(JSON.stringify({ level: 'warn', msg: 'showcase refresh failed', error: String(e) }));
    });
    const [upcoming, passed, asked] = await Promise.all([
      this.store.upcomingPlans(s.now.toISOString()),
      this.store.passedPlanIds(s.me.id),
      this.store.askedRequests(s.me.id),
    ]);
    const deck = rules.discover(upcoming, s.me, new Set(passed), new Set(asked.map((r) => r.planId)), s.now);
    const [climbers, scores] = await Promise.all([
      this.climbersOf(deck.plans),
      s.caller.admin ? this.deckScores(deck.plans, s) : Promise.resolve(undefined),
    ]);
    return { plans: deck.plans, distanceKm: deck.distanceKm, climbers, ...(scores ? { scores } : {}) };
  }

  /**
   * Admins only: how likely each of the deck's best plans ends in a match
   * for me, from aityx, live. Best effort: a plan aityx didn't score (or
   * not in time) has no score; never fails the deck.
   */
  private async deckScores(plans: Plan[], s: Session): Promise<Record<string, MatchScore> | undefined> {
    const scorer = this.deps.matchScorer;
    if (!scorer || plans.length === 0) return undefined;
    try {
      const open = openByPlan(await this.store.openRequests());
      const top = plans.slice(0, SCORED_DECK);
      const deadline = Date.now() + SCORE_BUDGET_MS;
      const results = await pooled(top, SCORE_CONCURRENCY, async (plan) =>
        Date.now() > deadline ? null : scorer(matchFacts(s.me, plan, othersWaiting(open, plan.id, s.me.id), s.now)),
      );
      const scores: Record<string, MatchScore> = {};
      top.forEach((plan, i) => {
        const out = results[i];
        if (out) scores[plan.id] = out.score;
      });
      return scores;
    } catch (e) {
      console.error(JSON.stringify({ level: 'warn', msg: 'deck scores failed', error: String(e) }));
      return undefined;
    }
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
    // Out of my deck for good, now that I've left it (a refresh keeps it out).
    await this.store.addPass(s.me.id, planId, s.now, true);
    await this.hint(hintsFor(members, { kind: 'plan', planId }, s.me.id));
    return {};
  }

  private async join(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    const asked = await this.ask(planId, s);
    if (!asked.demo) return { request: requestJson(asked.request) };
    // A demo plan's made-up members can't answer: the group says yes at
    // once, as an admin's yes would, and I match.
    return this.retry(async () => {
      const loaded = await this.loadPlan(planId);
      await this.loadNames(s, loaded.plan.memberIds, loaded.requests.map((r) => r.climberId));
      const effects = rules.accept(loaded, { id: loaded.plan.organizerId, admin: true }, s.me.id, s.ctx);
      await this.store.apply(loaded, effects, s.now);
      await this.hint(answerHints(loaded, effects, 'accept', s.me.id, s.me.id));
      const request = effects.requests.find((r) => r.climberId === s.me.id) ?? asked.request;
      return { request: requestJson(request) };
    });
  }

  /** My join request, saved; whether the plan is a demo. */
  private async ask(planId: string, s: Session): Promise<{ request: JoinRequest; demo: boolean }> {
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
      return { request: effects.requests[0]!, demo: loaded.plan.demo === true };
    });
  }

  /**
   * I nudge the members who haven't answered my open request on this plan:
   * each gets a nudge notice and a notice hint. Once per 12 hours (429).
   */
  private async nudge(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    return this.retry(async () => {
      const loaded = await this.loadPlan(planId);
      const before = loaded.requests.find((r) => r.climberId === s.me.id);
      const effects = rules.nudge(loaded, s.me.id, s.ctx);
      const request = effects.requests[0]!;
      await this.store.nudge(request, before?.nudgedAt, effects.notices);
      const nudged = effects.notices.map((d) => d.to);
      await this.hint(hintsFor(nudged, { kind: 'notice', planId }, s.me.id));
      return { request: requestJson(request), nudged: nudged.length };
    });
  }

  /**
   * Discover's refresh: the plans I passed on come back (I may have changed
   * my mind). Not the ones I asked to join (a dismissed "no" stays hidden)
   * or left (cancelled).
   */
  private async clearPasses(s: Session) {
    const [passed, asked, left] = await Promise.all([
      this.store.passedPlanIds(s.me.id),
      this.store.askedRequests(s.me.id),
      this.store.leftPlanIds(s.me.id),
    ]);
    const keep = new Set([...asked.map((r) => r.planId), ...left]);
    await this.store.deletePasses(s.me.id, passed.filter((p) => !keep.has(p)));
    return {};
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

  /**
   * GET /api/admin/scores: the latest scoring run's summary and its best
   * scores, with their plans and climbers (null run: never run, or no
   * scores table).
   */
  private async adminScores() {
    const table = this.deps.scores;
    const run = (await table?.latestRun()) ?? null;
    const top = run && table ? await table.top(run.runId, SCORES_PREVIEW) : [];
    const plans = await this.store.getPlans(top.map((t) => t.planId));
    const ids = new Set([...top.map((t) => t.climberId), ...plans.flatMap((p) => [p.organizerId, ...p.memberIds])]);
    return {
      run,
      scores: top.map(({ climberId, planId, score, level, reason, scoredAt }) => ({ climberId, planId, score, level, reason, scoredAt })),
      plans: Object.fromEntries(plans.map((p) => [p.id, p])),
      climbers: await this.publicClimbers(ids),
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
    const input = messageInput(req.body, planId);
    const current = await this.store.getPlan(planId);
    if (!current) throw notFound('no such plan');
    const message = rules.chatMessage(current.plan, s.me.id, input.text, s.ctx, input.attachment);
    // The upload loses its pending tag (else the bucket would expire it)
    // only once I'm known to be a member; one that isn't there is refused.
    if (input.attachment && !(await this.deps.photos.keep(input.attachment.key))) {
      throw badRequest("the attachment isn't uploaded (or expired): upload it again");
    }
    await this.store.putMessage(message);
    // A chat photo goes to the plan's "Your Pics" too.
    if (input.attachment?.kind === 'image') await this.chatPhotoToPics(planId, input.attachment.key, s);
    await this.hint(hintsFor(current.plan.memberIds, { kind: 'message', planId }, s.me.id));
    return { message };
  }

  /** Best effort: the message is sent either way; a full plan keeps it in the chat only. */
  private async chatPhotoToPics(planId: string, key: string, s: Session): Promise<void> {
    try {
      if ((await this.store.planPics(planId)).length >= MAX_PLAN_PICS) return;
      await this.store.putPlanPic({ id: newId(), planId, key, uploaderId: s.me.id, time: s.now.toISOString(), fromChat: true });
    } catch (e) {
      console.error(JSON.stringify({ level: 'warn', msg: 'chat photo to pics failed', error: String(e) }));
    }
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

/** GET /api/pics's query: `sector`, `lat` and `lon` (both or neither), `place`, `area`. */
export function whereFrom(query: Record<string, string | undefined>): Where {
  const where: Where = {};
  if (query.sector) where.sectorId = query.sector.slice(0, 64);
  if (query.place) where.place = query.place.slice(0, 120);
  if (query.area) where.area = query.area.slice(0, 120);
  if (query.lat !== undefined || query.lon !== undefined) {
    const lat = Number(query.lat);
    const lon = Number(query.lon);
    if (!Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) {
      throw badRequest('lat and lon must be numbers (both or neither)');
    }
    where.lat = lat;
    where.lon = lon;
  }
  return where;
}
