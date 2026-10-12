// Grigri's matchmaking rules, pure: no I/O. Each operation takes a plan with
// its requests and returns what changes (Effects), which the store then
// writes in one transaction. Ported from the app's on-device GrigriStore,
// without its made-up auto-answering climbers: here every answer is a real
// member's (or an admin's).
import { conflict, forbidden, notFound } from './errors.js';
import type { PlanInput } from './validate.js';
import {
  type Climber,
  type JoinRequest,
  type Match,
  type Message,
  type Notice,
  type NoticeKind,
  type Plan,
  isOpen,
  overlaps,
  requestId,
} from './model.js';

/** What the rules need from the outside world. */
export interface Context {
  now: Date;
  /** A new unique id (messages). */
  newId: () => string;
  /** A climber's name, for the chat's notes. */
  name: (climberId: string) => string;
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

/** Whether the climber's grades for the plan's discipline overlap its grades. */
export function fits(climber: Pick<Climber, 'levels'>, plan: Plan): boolean {
  const level = climber.levels[plan.discipline];
  return level !== undefined && overlaps(level, plan.grades);
}

/**
 * Plans to swipe on (never full: groups have no size limit): upcoming, I'm not in, I haven't passed or
 * asked; my grades' fits first, then soonest.
 */
export function discover(
  plans: Plan[],
  me: Climber,
  passed: ReadonlySet<string>,
  asked: ReadonlySet<string>,
  now: Date,
): Plan[] {
  const nowIso = now.toISOString();
  return plans
    .filter(
      (p) =>
        p.start > nowIso &&
        !p.memberIds.includes(me.id) &&
        !passed.has(p.id) &&
        !asked.has(p.id),
    )
    .sort((a, b) => {
      const byFit = Number(fits(me, b)) - Number(fits(me, a));
      if (byFit !== 0) return byFit;
      return a.start < b.start ? -1 : a.start > b.start ? 1 : a.id.localeCompare(b.id);
    });
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
 * I leave a plan. The organizer leaving hands it to the next member; the
 * last member leaving ends the plan (and its requests). Open requests stop
 * waiting for me, so someone may now join.
 */
export function leave(state: PlanState, actorId: string, ctx: Context): Effects {
  const { plan } = state;
  if (!plan.memberIds.includes(actorId)) throw forbidden("you're not in this plan");
  const members = plan.memberIds.filter((m) => m !== actorId);
  if (members.length === 0) {
    return { plan: null, requests: [], notices: [], messages: [], matches: [] };
  }
  const after: Plan = {
    ...plan,
    memberIds: members,
    organizerId: plan.organizerId === actorId ? members[0]! : plan.organizerId,
  };
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
    messages: [note(plan.id, `${ctx.name(actorId)} left the plan`, ctx)],
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

/** A group answers a request once, and nobody asks twice: ids are stable. */
export function noticeId(kind: NoticeKind, planId: string, climberId?: string): string {
  return kind === 'request' ? `${planId}/request/${climberId}` : `${planId}/${kind}`;
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
export function chatMessage(plan: Plan, authorId: string, text: string, ctx: Context): Message {
  if (!plan.memberIds.includes(authorId)) throw forbidden("you're not in this plan");
  return { id: ctx.newId(), planId: plan.id, authorId, text, time: ctx.now.toISOString() };
}
