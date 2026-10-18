// What every deck shares, kept in the warm function's memory: the
// upcoming plans, and the approved ads with their setting and owners.
// Reading them in full on every deck (every 15 s per open Discover) cost
// the most of any route, so each deck instead reads the table's change
// log (CHANGES, src/store/store.ts): one strongly consistent query of the
// last minute's entries, which every write of a plan, an ad, the ads'
// setting or a profile adds to (plans in the same transaction). What
// changed is read again, strongly consistent, and patched in; nothing
// changed: the copy in memory is the table as it is. So a plan created,
// changed or deleted on any instance is on every deck at once, as before.
//
// Why a log and not one version counter: the full read is a query of a
// global secondary index, which lags the table (eventually consistent,
// usually well under a second), so a counter seen to move could re-read
// the index before it has the change and keep that stale copy; reading
// the changed items themselves, consistently, can't. And a counter item
// in every plan transaction would make concurrent transactions conflict.
import type { Ad, AdSettings } from './domain/ads.js';
import type { Climber, Plan } from './domain/model.js';
import type { Change, Store } from './store/store.js';

/**
 * How far back every poll of the log looks again: a write's entry is
 * stamped by its writer's clock just before it commits, so one may land
 * a little behind the last poll. Entries already applied are skipped.
 */
export const CHANGE_OVERLAP_MS = 60_000;
/**
 * At least this often each cache is read in full again (and the log
 * restarts after an instance sat idle this long): a safety net should any
 * write ever skip the log.
 */
export const CACHE_MAX_AGE_MS = 5 * 60_000;

type ChangeSource = Pick<Store, 'changesSince'>;

export interface Poll {
  /** Every log entry in the window looked at (applied ones too). */
  changes: Change[];
  /** The log restarted (first poll, or after a long idle): caches read in full. */
  restart: boolean;
}

/** One query of the change log per deck, for both caches. */
export class ChangeFeed {
  private polledAt: number | undefined;

  constructor(
    private readonly source: ChangeSource,
    private readonly wallClock: () => number = Date.now,
  ) {}

  async poll(): Promise<Poll> {
    const now = this.wallClock();
    const last = this.polledAt;
    const restart = last === undefined || now - last > CACHE_MAX_AGE_MS || now < last - CHANGE_OVERLAP_MS;
    const from = restart ? now - CHANGE_OVERLAP_MS : Math.min(last, now) - CHANGE_OVERLAP_MS;
    const changes = await this.source.changesSince(new Date(from).toISOString());
    this.polledAt = now;
    return { changes, restart };
  }
}

/** Log entries not applied yet, and remembers the window's (by their keys). */
class Applied {
  private readonly at = new Map<string, number>();

  clear(): void {
    this.at.clear();
  }

  pending(changes: Change[]): Change[] {
    return changes.filter((c) => !this.at.has(c.key));
  }

  remember(changes: Change[], now: number): void {
    for (const c of changes) this.at.set(c.key, now);
    // What's older than the window can't come back in a poll.
    for (const [k, t] of this.at) if (now - t > CACHE_MAX_AGE_MS + CHANGE_OVERLAP_MS) this.at.delete(k);
  }
}

/** A plan's place in the by-start index (src/store/store.ts planItem): undated after every date. */
export function byStart(p: Plan): string {
  return `${p.start ?? '~'}#${p.id}`;
}

type PlanSource = Pick<Store, 'upcomingPlans' | 'getPlans'>;

/** The upcoming plans, in the by-start index's order. */
export class PlanCache {
  private plans: Plan[] | undefined;
  /** Read in full for plans starting after this (an ISO time). */
  private after = '';
  private loadedAt = 0;
  private readonly applied = new Applied();

  constructor(
    private readonly store: PlanSource,
    private readonly wallClock: () => number = Date.now,
  ) {}

  /** Plans that start after `afterIso` (or undated), as `store.upcomingPlans` gives them. */
  async upcoming(afterIso: string, poll: Poll): Promise<Plan[]> {
    const now = this.wallClock();
    let plans = this.plans;
    let after = this.after;
    let pending: Change[];
    if (!plans || poll.restart || now - this.loadedAt > CACHE_MAX_AGE_MS || afterIso < after) {
      plans = await this.store.upcomingPlans(afterIso);
      after = afterIso;
      this.applied.clear();
      this.loadedAt = now;
      // The index may not have the window's writes yet: read them again.
      pending = poll.changes;
    } else {
      pending = this.applied.pending(poll.changes);
    }
    const ids = [...new Set(pending.filter((c) => c.kind === 'plan').map((c) => c.id))];
    if (ids.length > 0) {
      const fresh = new Map((await this.store.getPlans(ids, true)).map((p) => [p.id, p]));
      const changed = new Set(ids);
      plans = [
        ...plans.filter((p) => !changed.has(p.id)),
        ...[...fresh.values()].filter((p) => byStart(p) > after),
      ].sort((a, b) => (byStart(a) < byStart(b) ? -1 : byStart(a) > byStart(b) ? 1 : 0));
    }
    this.plans = plans;
    this.after = after;
    this.applied.remember(pending, now);
    return plans.filter((p) => byStart(p) > afterIso);
  }
}

/** The deck's shared ad data: the setting, approved ads (newest first) and their owners' profiles and emails. */
export interface AdState {
  settings: AdSettings;
  approved: Ad[];
  climbers: Record<string, Climber>;
  emails: Record<string, string>;
}

type AdSource = Pick<Store, 'getAdSettings' | 'adsByStatus' | 'getAd' | 'getClimbers' | 'getEmails'>;

function newestFirst(a: Ad, b: Ad): number {
  const [x, y] = [`${a.createdAt}#${a.id}`, `${b.createdAt}#${b.id}`];
  return x > y ? -1 : x < y ? 1 : 0;
}

export class AdCache {
  private state: AdState | undefined;
  private loadedAt = 0;
  private readonly applied = new Applied();

  constructor(
    private readonly store: AdSource,
    private readonly wallClock: () => number = Date.now,
  ) {}

  async get(poll: Poll): Promise<AdState> {
    const now = this.wallClock();
    let state = this.state;
    let pending: Change[];
    if (!state || poll.restart || now - this.loadedAt > CACHE_MAX_AGE_MS) {
      const [settings, approved] = await Promise.all([this.store.getAdSettings(), this.store.adsByStatus('approved')]);
      const owners = [...new Set(approved.map((a) => a.ownerId))];
      const [climbers, emails] = await Promise.all([this.store.getClimbers(owners), this.store.getEmails(owners)]);
      state = { settings, approved, climbers, emails };
      this.applied.clear();
      this.loadedAt = now;
      pending = poll.changes;
    } else {
      pending = this.applied.pending(poll.changes);
    }
    if (pending.length > 0) state = await this.patch(state, pending);
    this.state = state;
    this.applied.remember(pending, now);
    return state;
  }

  /** A new state with what changed read again, consistently (the old one stays if a read fails). */
  private async patch(state: AdState, changes: Change[]): Promise<AdState> {
    const ofKind = (kind: Change['kind']) => [...new Set(changes.filter((c) => c.kind === kind).map((c) => c.id))];
    const adIds = ofKind('ad');
    const settingsChanged = changes.some((c) => c.kind === 'adSettings');
    const [settings, ads] = await Promise.all([
      settingsChanged ? this.store.getAdSettings(true) : Promise.resolve(state.settings),
      Promise.all(adIds.map((id) => this.store.getAd(id, true))),
    ]);
    const changedAds = new Set(adIds);
    const approved = [
      ...state.approved.filter((a) => !changedAds.has(a.id)),
      ...ads.filter((a): a is Ad => a?.status === 'approved'),
    ].sort(newestFirst);
    const owners = new Set(approved.map((a) => a.ownerId));
    // Owners whose profile or email changed, and new owners: read them again.
    const stale = new Set(ofKind('climber').filter((id) => owners.has(id)));
    for (const o of owners) if (!(o in state.climbers) && !(o in state.emails)) stale.add(o);
    const [climbers, emails] = stale.size > 0
      ? await Promise.all([this.store.getClimbers(stale, true), this.store.getEmails(stale, true)])
      : [{}, {}];
    const keep = <T>(old: Record<string, T>, fresh: Record<string, T>) =>
      Object.fromEntries([
        ...Object.entries(old).filter(([id]) => owners.has(id) && !stale.has(id)),
        ...Object.entries(fresh),
      ]);
    return { settings, approved, climbers: keep(state.climbers, climbers), emails: keep(state.emails, emails) };
  }
}
