// Grigri's matchmaking rules, pure: no I/O. Each operation takes a plan with
// its requests and returns what changes (Effects), which the store then
// writes in one transaction. Ported from the app's on-device GrigriStore,
// without its made-up auto-answering climbers: here every answer is a real
// member's (or an admin's).
import { conflict, forbidden, notFound, tooMany } from './errors.js';
import type { PlanInput } from './validate.js';
import {
  type Climber,
  type JoinRequest,
  type Match,
  type Message,
  type Attachment,
  type Notice,
  type NoticeKind,
  type Plan,
  isOpen,
  requestId,
} from './model.js';

/** What the rules need from the outside world. */
export interface Context {
  now: Date;
  /** A new unique id (messages). */
  newId: () => string;
  /** A climber's name, for the chat's notes. */
  name: (climberId: string) => string;
  /** A number in [0, 1), like Math.random (a new organizer's pick). */
  random: () => number;
}

/** A notice for one climber. */
export interface Delivery {
  to: string;
  notice: Notice;
}

/** What an operation changes. */
export interface Effects {
  /** The plan after it; null when it's gone (its last member left). */
  plan: Plan | null;
  /** Requests that changed (written whole). */
  requests: JoinRequest[];
  notices: Delivery[];
  /** New messages (the chat's notes). */
  messages: Message[];
  /** Who joined. */
  matches: Match[];
}

/** A plan and its requests, as loaded. */
export interface PlanState {
  plan: Plan;
  requests: JoinRequest[];
}

// --- Decks ---------------------------------------------------------------

/**
 * How well the plan's grades suit me, 0 to 1: 1 when my grades for its
 * discipline overlap its grades, less the further apart they are (0 at 4
 * grades apart), 0 when I don't climb its discipline.
 */
export function fitScore(climber: Pick<Climber, 'levels'>, plan: Plan): number {
  const level = climber.levels[plan.discipline];
  if (level === undefined || level.scale !== plan.grades.scale) return 0;
  const gap = Math.max(level.min - plan.grades.max, plan.grades.min - level.max, 0);
  return gap === 0 ? 1 : Math.max(0, 0.6 * (1 - (gap - 1) / 3));
}

const EARTH_KM = 6371;

/** Great-circle distance, in km. */
export function haversineKm(a: { lat: number; lon: number }, b: { lat: number; lon: number }): number {
  const rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad;
  const dLon = (b.lon - a.lon) * rad;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_KM * Math.asin(Math.min(1, Math.sqrt(h)));
}

/**
 * How far the plan is from me: from the nearest of my location and areas.
 * Undefined when the plan has no point (typed in by hand) or I set none.
 */
export function distanceKm(climber: Pick<Climber, 'location' | 'areas'>, plan: Plan): number | undefined {
  if (plan.lat === undefined || plan.lon === undefined) return undefined;
  const mine = [...(climber.location ? [climber.location] : []), ...(climber.areas ?? [])];
  if (mine.length === 0) return undefined;
  const point = { lat: plan.lat, lon: plan.lon };
  return Math.min(...mine.map((l) => haversineKm(l, point)));
}

/** Nearness, 0 to 1: 1 on my doorstep, about 0.37 at 50 km, 0.14 at 100 km. */
export const NEAR_KM = 50;
/** The nearness of a plan whose distance isn't known: like one about 70 km away. */
export const UNKNOWN_NEARNESS = 0.25;

export function nearScore(km: number | undefined): number {
  return km === undefined ? UNKNOWN_NEARNESS : Math.exp(-km / NEAR_KM);
}

/** A deck: the plans, best first, and how far each is from me (km, rounded), when known. */
export interface Deck {
  plans: Plan[];
  distanceKm: Record<string, number>;
}

/**
 * Plans to swipe on (never full: groups have no size limit): upcoming, I'm
 * not in, I haven't passed or asked. Ranked by how well they match my
 * profile plus how close they are (fitScore + nearScore), then soonest.
 */
export function discover(
  plans: Plan[],
  me: Climber,
  passed: ReadonlySet<string>,
  asked: ReadonlySet<string>,
  now: Date,
): Deck {
  const nowIso = now.toISOString();
  const distances: Record<string, number> = {};
  const scored = plans
    .filter(
      (p) =>
        p.start > nowIso &&
        !p.memberIds.includes(me.id) &&
        !passed.has(p.id) &&
        !asked.has(p.id),
    )
    .map((plan) => {
      const km = distanceKm(me, plan);
      if (km !== undefined) distances[plan.id] = Math.round(km);
      return { plan, score: fitScore(me, plan) + nearScore(km) };
    });
  scored.sort((a, b) => {
    if (a.score !== b.score) return b.score - a.score;
    const [x, y] = [a.plan, b.plan];
    return x.start < y.start ? -1 : x.start > y.start ? 1 : x.id.localeCompare(y.id);
  });
  return { plans: scored.map((s) => s.plan), distanceKm: distances };
}

/** Requests for me to review: open, on plans I'm in, that I haven't accepted. */
export function toReview(states: PlanState[], meId: string): JoinRequest[] {
  return states.flatMap(({ plan, requests }) =>
    plan.memberIds.includes(meId)
      ? requests.filter(
          (r) => isOpen(r) && !r.acceptedBy.includes(meId) && !plan.memberIds.includes(r.climberId),
        )
      : [],
  );
}

/** Plans sorted soonest first. */
export function soonestFirst(plans: Plan[]): Plan[] {
  return [...plans].sort((a, b) => (a.start < b.start ? -1 : a.start > b.start ? 1 : a.id.localeCompare(b.id)));
}

// --- Plans ---------------------------------------------------------------

/** A new plan, organized by `organizerId`, with the chat's first note. */
export function createPlan(id: string, organizerId: string, input: PlanInput, ctx: Context): Effects {
  const plan: Plan = { id, organizerId, memberIds: [organizerId], ...input };
  return {
    plan,
    requests: [],
    notices: [],
    messages: [note(plan.id, `${ctx.name(organizerId)} created the plan. People who match will show up here.`, ctx)],
    matches: [],
  };
}

/** The organizer changes a plan; its members stay. */
export function updatePlan(plan: Plan, actorId: string, input: PlanInput): Plan {
  if (plan.organizerId !== actorId) throw forbidden('only the organizer can change the plan');
  // Written whole: a sectorId left out is cleared.
  const { sectorId: _old, ...rest } = plan;
  return { ...rest, ...input, id: plan.id, organizerId: plan.organizerId, memberIds: plan.memberIds };
}

/**
 * I leave (cancel) a plan. The organizer leaving hands it to a member picked
 * at random; the last member leaving ends the plan (and its requests). Open
 * requests stop waiting for me, so someone may now join.
 */
export function leave(state: PlanState, actorId: string, ctx: Context): Effects {
  const { plan } = state;
  if (!plan.memberIds.includes(actorId)) throw forbidden("you're not in this plan");
  const members = plan.memberIds.filter((m) => m !== actorId);
  if (members.length === 0) {
    return { plan: null, requests: [], notices: [], messages: [], matches: [] };
  }
  const handOver = plan.organizerId === actorId;
  const organizerId = handOver
    ? members[Math.min(members.length - 1, Math.floor(ctx.random() * members.length))]!
    : plan.organizerId;
  // The organizer first, as always; the others keep their join order.
  const after: Plan = { ...plan, memberIds: [organizerId, ...members.filter((m) => m !== organizerId)], organizerId };
  // My acceptances no longer count: I'm not a member.
  const changed = new Map<string, JoinRequest>();
  const requests = state.requests.map((r) => {
    if (!isOpen(r) || !r.acceptedBy.includes(actorId)) return r;
    const updated = { ...r, acceptedBy: r.acceptedBy.filter((m) => m !== actorId) };
    changed.set(updated.id, updated);
    return updated;
  });
  const effects: Effects = {
    plan: after,
    requests: [],
    notices: [],
    messages: [
      note(
        plan.id,
        handOver
          ? `${ctx.name(actorId)} left the plan; ${ctx.name(organizerId)} organizes it now`
          : `${ctx.name(actorId)} left the plan`,
        ctx,
      ),
    ],
    matches: [],
  };
  settleInto(effects, requests, changed, ctx);
  effects.requests = [...changed.values()];
  return effects;
}

// --- Requests --------------------------------------------------------------

/**
 * I swipe right: a join request. Every member is notified and the chat
 * gets a request note. `existing` is my earlier request for it, if any.
 */
export function ask(plan: Plan, climberId: string, existing: JoinRequest | undefined, ctx: Context): Effects {
  if (plan.memberIds.includes(climberId)) throw conflict("you're already in this plan");
  if (existing) throw conflict('you already asked to join this plan');
  if (plan.start <= ctx.now.toISOString()) throw conflict('the plan has started');
  const time = ctx.now.toISOString();
  const request: JoinRequest = {
    id: requestId(plan.id, climberId),
    planId: plan.id,
    climberId,
    acceptedBy: [],
    rejected: false,
    time,
  };
  return {
    plan,
    requests: [request],
    notices: plan.memberIds.map((to) => ({ to, notice: requestNotice(plan, climberId, ctx) })),
    messages: [{ ...note(plan.id, `${ctx.name(climberId)} asked to join`, ctx), requestId: request.id }],
    matches: [],
  };
}

/**
 * Accepts a request. A member's yes counts as theirs; when every current
 * member has said yes, they join. An admin's yes lets them in at once, as
 * if every member had accepted.
 */
export function accept(
  state: PlanState,
  actor: { id: string; admin?: boolean },
  climberId: string,
  ctx: Context,
): Effects {
  const { plan } = state;
  if (!actor.admin && !plan.memberIds.includes(actor.id)) throw forbidden("you're not in this plan");
  const request = openRequest(state, climberId);
  const acceptedBy = actor.admin
    ? [...new Set([...request.acceptedBy, ...plan.memberIds])]
    : request.acceptedBy.includes(actor.id)
      ? request.acceptedBy
      : [...request.acceptedBy, actor.id];
  const updated: JoinRequest = { ...request, acceptedBy };
  const changed = new Map<string, JoinRequest>([[updated.id, updated]]);
  const requests = state.requests.map((r) => (r.id === updated.id ? updated : r));
  const effects: Effects = { plan, requests: [], notices: [], messages: [], matches: [] };
  settleInto(effects, requests, changed, ctx);
  effects.requests = [...changed.values()];
  return effects;
}

/** One no is enough: a member (or an admin) turns a request down. */
export function reject(state: PlanState, actor: { id: string; admin?: boolean }, climberId: string, ctx: Context): Effects {
  const { plan } = state;
  if (!actor.admin && !plan.memberIds.includes(actor.id)) throw forbidden("you're not in this plan");
  const request = openRequest(state, climberId);
  return {
    plan,
    requests: [{ ...request, rejected: true }],
    notices: [{ to: climberId, notice: answerNotice('declined', plan, ctx) }],
    messages: [],
    matches: [],
  };
}

/** The requester clears a declined request (the plan stays out of their deck). */
export function dismiss(request: JoinRequest | undefined, climberId: string): JoinRequest {
  if (!request || request.climberId !== climberId) throw notFound('no such request');
  if (!request.rejected) throw conflict("the request wasn't declined");
  return { ...request, dismissed: true };
}

/** How long a requester waits between nudges: 12 hours. */
export const NUDGE_COOLDOWN_MS = 12 * 60 * 60 * 1000;

/**
 * The requester nudges the group: a nudge notice for each member who
 * hasn't said yes yet, asking them to accept or decline. At most once
 * per NUDGE_COOLDOWN_MS per request (429 until then). The returned
 * request carries the new nudgedAt; the deliveries go to `notices`.
 */
export function nudge(state: PlanState, climberId: string, ctx: Context): Effects {
  const { plan } = state;
  const request = state.requests.find((r) => r.climberId === climberId);
  if (!request) throw notFound("you haven't asked to join this plan");
  if (request.rejected) throw conflict('the request was declined');
  if (request.joined || plan.memberIds.includes(climberId)) throw conflict("you're already in this plan");
  if (plan.start <= ctx.now.toISOString()) throw conflict('the plan has started');
  if (request.nudgedAt && ctx.now.getTime() < Date.parse(request.nudgedAt) + NUDGE_COOLDOWN_MS) {
    throw tooMany('you nudged the group less than 12 hours ago; try again later');
  }
  const waitingFor = plan.memberIds.filter((m) => !request.acceptedBy.includes(m));
  if (waitingFor.length === 0) throw conflict('nobody left to answer');
  const time = ctx.now.toISOString();
  const notice: Notice = {
    id: noticeId('nudge', plan.id, climberId),
    kind: 'nudge',
    planId: plan.id,
    planTitle: plan.place,
    climberId,
    time,
    read: false,
  };
  return {
    plan,
    requests: [{ ...request, nudgedAt: time }],
    notices: waitingFor.map((to) => ({ to, notice })),
    messages: [],
    matches: [],
  };
}

function openRequest(state: PlanState, climberId: string): JoinRequest {
  const request = state.requests.find((r) => r.climberId === climberId);
  if (!request) throw notFound('no such request');
  if (request.rejected) throw conflict('the request was declined');
  if (request.joined || state.plan.memberIds.includes(climberId)) throw conflict('they already joined');
  return request;
}

/**
 * Lets in everyone every current member has accepted, until nothing
 * changes: each newcomer becomes a member, and the
 * requests still open now wait for them too (they're notified).
 */
function settleInto(effects: Effects, requests: JoinRequest[], changed: Map<string, JoinRequest>, ctx: Context): void {
  let plan = effects.plan!;
  let current = requests;
  for (;;) {
    const next = current.find(
      (r) =>
        isOpen(r) &&
        !plan.memberIds.includes(r.climberId) &&
        plan.memberIds.every((m) => r.acceptedBy.includes(m)),
    );
    if (!next) break;
    const joined: JoinRequest = { ...next, joined: true };
    changed.set(joined.id, joined);
    current = current.map((r) => (r.id === joined.id ? joined : r));
    plan = { ...plan, memberIds: [...plan.memberIds, joined.climberId] };
    effects.messages.push(note(plan.id, `${ctx.name(joined.climberId)} joined the plan 🎉`, ctx));
    effects.notices.push({ to: joined.climberId, notice: answerNotice('accepted', plan, ctx) });
    effects.matches.push({ plan, newcomerId: joined.climberId });
    for (const open of current) {
      if (isOpen(open) && !plan.memberIds.includes(open.climberId)) {
        effects.notices.push({ to: joined.climberId, notice: requestNotice(plan, open.climberId, ctx, open.time) });
      }
    }
  }
  effects.plan = plan;
  // A match shows the plan as it ended up.
  effects.matches = effects.matches.map((m) => ({ ...m, plan }));
}

// --- Notices and notes -------------------------------------------------------

/**
 * A group answers a request once, and nobody asks twice: ids are stable.
 * A new nudge replaces the last one (unread again, with its new time).
 */
export function noticeId(kind: NoticeKind, planId: string, climberId?: string): string {
  return kind === 'request' || kind === 'nudge' ? `${planId}/${kind}/${climberId}` : `${planId}/${kind}`;
}

function requestNotice(plan: Plan, climberId: string, ctx: Context, time?: string): Notice {
  return {
    id: noticeId('request', plan.id, climberId),
    kind: 'request',
    planId: plan.id,
    planTitle: plan.place,
    climberId,
    time: time ?? ctx.now.toISOString(),
    read: false,
  };
}

function answerNotice(kind: 'accepted' | 'declined', plan: Plan, ctx: Context): Notice {
  return {
    id: noticeId(kind, plan.id),
    kind,
    planId: plan.id,
    planTitle: plan.place,
    time: ctx.now.toISOString(),
    read: false,
  };
}

function note(planId: string, text: string, ctx: Context): Message {
  return { id: ctx.newId(), planId, authorId: null, text, time: ctx.now.toISOString() };
}

/** A member's chat message. */
export function chatMessage(plan: Plan, authorId: string, text: string, ctx: Context, attachment?: Attachment): Message {
  if (!plan.memberIds.includes(authorId)) throw forbidden("you're not in this plan");
  return {
    id: ctx.newId(),
    planId: plan.id,
    authorId,
    text,
    time: ctx.now.toISOString(),
    ...(attachment ? { attachment } : {}),
  };
}
