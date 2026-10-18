// The decks' caches (src/deck-cache.ts): the upcoming plans and the ads
// kept in the warm function's memory, patched from the change log. The
// deck must be the same as reading everything every time: a plan created,
// changed or deleted, on this instance or another, is on the next deck.
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { BatchWriteCommand, GetCommand, PutCommand, QueryCommand, TransactWriteCommand } from '@aws-sdk/lib-dynamodb';
import { Api } from '../src/api.js';
import { Auth, type Caller } from '../src/auth.js';
import { CACHE_MAX_AGE_MS, CHANGE_OVERLAP_MS } from '../src/deck-cache.js';
import { Store } from '../src/store/store.js';
import { SHOWCASE_VERSION, seedShowcase, showcaseFreshUntil, showcaseKeeper } from '../seed/seed.js';
import { showcaseData } from '../seed/showcase.js';
import { FakeRbacr } from './fake-rbacr.js';
import { FakeStore } from './fake-store.js';

let now: Date;
/** The real time the caches see (epoch ms), moved by hand. */
let wall: number;
let store: FakeStore;
let rbacr: FakeRbacr;
let auth: Auth;
let api: Api;

const who = (name: string, admin = false): Caller => ({ subject: `test#${name}`, email: `${name}@example.com`, isAdmin: async () => admin });
const ada = who('ada');
const ben = who('ben');
const cy = who('cy');
const root = who('root', true);

const photos = { presign: async () => ({ url: '', fields: {} }), keep: async () => true, remove: async () => {} };
/** Another warm instance of the function, with its own memory, on the same table. */
const instance = () => new Api({ store: store.asStore(), photos, auth, roles: rbacr.lookup, grants: rbacr.api, config: { stage: 'local', version: 'test' }, clock: () => now, wallClock: () => wall });

const on = async (a: Api, c: Caller, method: string, path: string, body?: unknown) =>
  (await a.handle(method, path, { caller: c, body, query: {} })) as Record<string, any>;
const call = (c: Caller, method: string, path: string, body?: unknown) => on(api, c, method, path, body);
const deckIds = async (c: Caller, a = api) => (await on(a, c, 'GET', '/api/discover')).plans.map((p: { id: string }) => p.id);

const profile = (name: string) => ({ name, bio: '', levels: { sport: { scale: 'routes', min: 6, max: 10 } }, gear: ['rope'] });
const planBody = (place: string, start = '2030-05-10T08:00:00Z', end = '2030-05-10T14:00:00Z') => ({
  discipline: 'sport', place, area: 'Nowhere', start, end, grades: { scale: 'routes', min: 6, max: 10 }, notes: '',
});

beforeEach(async () => {
  now = new Date('2030-05-01T10:00:00.000Z');
  wall = Date.parse('2026-10-18T10:00:00.000Z');
  store = new FakeStore();
  store.wallClock = () => wall;
  rbacr = new FakeRbacr(() => now);
  rbacr.give('root@example.com', 'admin');
  auth = new Auth({ store: store.asStore(), verify: async () => { throw new Error('unused'); }, config: { devMode: false, isAdmin: async () => false }, clock: () => now });
  api = instance();
  for (const [c, name] of [[ada, 'Ada'], [ben, 'Ben'], [cy, 'Cy'], [root, 'Root']] as const) await call(c, 'PUT', '/api/me', profile(name));
});

describe("the deck's plans", () => {
  it('are read in full once; later decks read only the change log', async () => {
    await call(ada, 'POST', '/api/plans', planBody('Crag A'));
    expect(await deckIds(ben)).toHaveLength(1);
    expect(await deckIds(ben)).toHaveLength(1);
    expect(await deckIds(cy)).toHaveLength(1);
    expect(store.reads.upcomingPlans).toBe(1);
    expect(store.reads.changes).toBe(3);
  });

  it('a plan created, changed or deleted is on the next cached deck', async () => {
    expect(await deckIds(ben)).toEqual([]);
    const { plan } = await call(ada, 'POST', '/api/plans', planBody('Crag A'));
    expect(await deckIds(ben)).toEqual([plan.id]);
    await call(ada, 'PUT', `/api/plans/${plan.id}`, { ...planBody('Crag B'), notes: 'New notes' });
    const deck = await on(api, ben, 'GET', '/api/discover');
    expect(deck.plans[0]).toMatchObject({ id: plan.id, place: 'Crag B', notes: 'New notes' });
    // A join changes its members: Cy's in, so it leaves Cy's deck, and Cy's in Ben's deck's climbers.
    const open = (await call(ada, 'POST', '/api/plans', { ...planBody('Open crag'), type: 'open' })).plan;
    await call(cy, 'POST', `/api/plans/${open.id}/join`);
    expect(await deckIds(cy)).toEqual([plan.id]);
    const cyId = store.subjects.get(cy.subject)!;
    const benDeck = await on(api, ben, 'GET', '/api/discover');
    expect(benDeck.plans.find((p: { id: string }) => p.id === open.id).memberIds).toEqual([plan.organizerId, cyId]);
    expect(Object.keys(benDeck.climbers).sort()).toEqual([plan.organizerId, cyId].sort());
    // The last member leaves: the plan is gone.
    await call(ada, 'POST', `/api/plans/${plan.id}/leave`);
    expect(await deckIds(ben)).toEqual([open.id]);
    expect(store.reads.upcomingPlans).toBe(1);
  });

  it("another instance's writes are on this instance's cached deck at once", async () => {
    const other = instance();
    expect(await deckIds(ben)).toEqual([]);
    expect(await deckIds(ben, other)).toEqual([]);
    const { plan } = await on(other, ada, 'POST', '/api/plans', planBody('Crag A'));
    expect(await deckIds(ben)).toEqual([plan.id]);
    await on(other, ada, 'PUT', `/api/plans/${plan.id}`, planBody('Crag B'));
    expect((await on(api, ben, 'GET', '/api/discover')).plans[0].place).toBe('Crag B');
    await on(other, ada, 'POST', `/api/plans/${plan.id}/leave`);
    expect(await deckIds(ben)).toEqual([]);
  });

  it("doesn't trust a lagging index: the window's writes are read again, consistently", async () => {
    const { plan } = await call(ada, 'POST', '/api/plans', planBody('Crag A'));
    // The index hasn't caught up with the new plan yet.
    const full = store.upcomingPlans.bind(store);
    store.upcomingPlans = async (after: string) => (await full(after)).filter((p) => p.id !== plan.id);
    expect(await deckIds(ben)).toEqual([plan.id]);
    expect(await deckIds(ben)).toEqual([plan.id]);
  });

  it('a plan leaves the deck once it starts, with no write', async () => {
    const soon = (await call(ada, 'POST', '/api/plans', planBody('Soon', '2030-05-02T08:00:00Z', '2030-05-02T12:00:00Z'))).plan;
    const later = (await call(ada, 'POST', '/api/plans', planBody('Later'))).plan;
    expect(await deckIds(ben)).toEqual([soon.id, later.id]);
    now = new Date('2030-05-02T09:00:00.000Z');
    expect(await deckIds(ben)).toEqual([later.id]);
    expect(store.reads.upcomingPlans).toBe(1);
  });

  it('an admin clearing notes and a withdrawn request are changes too', async () => {
    const { plan } = await call(ada, 'POST', '/api/plans', { ...planBody('Crag A'), notes: 'Bring snacks' });
    expect((await on(api, ben, 'GET', '/api/discover')).plans[0].notes).toBe('Bring snacks');
    await store.clearPlanNotes(plan.id);
    expect((await on(api, ben, 'GET', '/api/discover')).plans[0].notes).toBe('');
    // Asking to join a shared plan doesn't change the plan item (only a check on its version)...
    const before = store.changeLog.length;
    await call(cy, 'POST', `/api/plans/${plan.id}/join`);
    expect(store.changeLog.length).toBe(before);
    // ...withdrawing moves its version on: an entry.
    await store.withdrawRequest(store.plans.get(plan.id)!, store.subjects.get(cy.subject)!);
    expect(store.changeLog.slice(before).map((c) => `${c.kind}:${c.id}`)).toEqual([`plan:${plan.id}`]);
  });

  it('is read in full again after the max age (a write that skipped the log shows then)', async () => {
    const { plan } = await call(ada, 'POST', '/api/plans', planBody('Crag A'));
    expect(await deckIds(ben)).toEqual([plan.id]);
    // Written behind the log's back.
    const stored = store.plans.get(plan.id)!;
    store.plans.set(plan.id, { ...stored, plan: { ...stored.plan, place: 'Elsewhere' } });
    wall += CACHE_MAX_AGE_MS - 1000;
    expect((await on(api, ben, 'GET', '/api/discover')).plans[0].place).toBe('Crag A');
    wall += 2000;
    expect((await on(api, ben, 'GET', '/api/discover')).plans[0].place).toBe('Elsewhere');
    expect(store.reads.upcomingPlans).toBe(2);
  });

  it('a log entry stamped a little behind the last poll is still seen', async () => {
    expect(await deckIds(ben)).toEqual([]);
    wall += 10_000;
    // A write whose entry's time is from before the last poll (a slow commit, another clock).
    const { plan } = await call(ada, 'POST', '/api/plans', planBody('Crag A'));
    const entry = store.changeLog.at(-1)!;
    store.changeLog[store.changeLog.length - 1] = { ...entry, key: `${new Date(wall - CHANGE_OVERLAP_MS / 2 - 10_000).toISOString()}${entry.key.slice(24)}` };
    expect(await deckIds(ben)).toEqual([plan.id]);
  });

  it('gives the same deck as a cold instance reading everything', async () => {
    const warm = instance();
    await deckIds(ben, warm);
    const plans = [];
    for (let i = 0; i < 6; i++) {
      const day = String(10 + (i % 3)).padStart(2, '0');
      plans.push((await call(i % 2 ? ada : cy, 'POST', '/api/plans', planBody(`Crag ${i}`, `2030-05-${day}T08:00:00Z`, `2030-05-${day}T14:00:00Z`))).plan);
      await deckIds(ben, warm);
    }
    await call(ada, 'PUT', `/api/plans/${plans[1]!.id}`, planBody('Moved', '2030-05-03T08:00:00Z', '2030-05-03T10:00:00Z'));
    await call(cy, 'POST', `/api/plans/${plans[2]!.id}/leave`);
    await call(ben, 'POST', `/api/plans/${plans[3]!.id}/pass`);
    expect(await on(warm, ben, 'GET', '/api/discover')).toEqual(await on(instance(), ben, 'GET', '/api/discover'));
    expect(await on(warm, root, 'GET', '/api/discover')).toEqual(await on(instance(), root, 'GET', '/api/discover'));
  });
});

describe("the deck's ads", () => {
  async function approvedAd(text: string) {
    rbacr.give('ada@example.com', 'premium', '2030-06-03T00:00:00.000Z');
    const { ad } = await call(ada, 'POST', '/api/ads', { text, link: 'https://shop.example.com' });
    await call(root, 'POST', `/api/admin/ads/${ad.id}/approve`);
    return ad as { id: string; ownerId: string };
  }
  const deckAds = async (a = api) => {
    const deck = await on(a, ben, 'GET', '/api/discover');
    return { ids: deck.ads.map((x: { id: string }) => x.id), every: deck.adEvery, owners: deck.climbers };
  };

  it('are read in full once; approvals, rejections, deletions and the setting show at once', async () => {
    const other = instance();
    expect((await deckAds()).ids).toEqual([]);
    const first = await approvedAd('Chalk');
    expect((await deckAds()).ids).toEqual([first.id]);
    now = new Date('2030-05-01T11:00:00.000Z');
    const second = await approvedAd('Rope');
    expect((await deckAds()).ids).toEqual([second.id, first.id]);
    await on(other, root, 'PUT', '/api/admin/ads/settings', { every: 4 });
    expect((await deckAds()).every).toBe(4);
    await on(other, root, 'POST', `/api/admin/ads/${second.id}/reject`);
    expect((await deckAds()).ids).toEqual([first.id]);
    await on(other, ada, 'DELETE', `/api/ads/${first.id}`);
    expect((await deckAds()).ids).toEqual([]);
    expect(store.reads.approvedAds).toBe(1);
  });

  it("an owner's new name is on the next deck; my skips are mine", async () => {
    const ad = await approvedAd('Chalk');
    expect((await deckAds()).owners[ad.ownerId].name).toBe('Ada');
    await call(ada, 'PUT', '/api/me', profile('Ada Renamed'));
    expect((await deckAds()).owners[ad.ownerId].name).toBe('Ada Renamed');
    await call(ben, 'POST', `/api/ads/${ad.id}/skip`);
    expect((await deckAds()).ids).toEqual([]);
    expect((await on(api, cy, 'GET', '/api/discover')).ads.map((x: { id: string }) => x.id)).toEqual([ad.id]);
  });
});

describe('the showcase keeper', () => {
  it('reads the marker only once the showcase could be stale', async () => {
    let marker = 0;
    let reads = 0;
    const rewrites: Date[] = [];
    const keep = showcaseKeeper(
      async () => {
        reads++;
        return marker;
      },
      async (at) => {
        rewrites.push(at);
        marker = at.getTime() + 12 * 3_600_000;
      },
    );
    const t0 = Date.parse('2030-05-01T10:00:00.000Z');
    await keep(new Date(t0));
    expect([reads, rewrites.length]).toEqual([1, 1]);
    for (let m = 1; m < 12 * 60; m += 15) await keep(new Date(t0 + m * 60_000));
    expect([reads, rewrites.length]).toEqual([1, 1]);
    // Another instance re-dated it meanwhile: read, found fresh, no rewrite.
    marker = t0 + 18 * 3_600_000;
    await keep(new Date(t0 + 12 * 3_600_000));
    expect([reads, rewrites.length]).toEqual([2, 1]);
    await keep(new Date(t0 + 17 * 3_600_000));
    expect(reads).toBe(2);
    await keep(new Date(t0 + 18 * 3_600_000));
    expect([reads, rewrites.length]).toEqual([3, 2]);
  });

  it('a failed rewrite is tried again on the next deck', async () => {
    let fail = true;
    let rewrites = 0;
    const keep = showcaseKeeper(async () => 0, async () => {
      rewrites++;
      if (fail) throw new Error('table busy');
    });
    await expect(keep(new Date())).rejects.toThrow('table busy');
    fail = false;
    await keep(new Date());
    expect(rewrites).toBe(2);
  });
});

/** DynamoDB as the real store sees it: every command recorded, nothing stored. */
class RecordingDoc {
  sent: object[] = [];
  items: Record<string, unknown>[] = [];
  async send(command: object): Promise<Record<string, unknown>> {
    this.sent.push(command);
    if (command instanceof QueryCommand) return { Items: this.items };
    if (command instanceof GetCommand) return {};
    return {};
  }
  /** The change-log entries written, by kind and id. */
  changes(): string[] {
    const out: string[] = [];
    const take = (item: Record<string, unknown> | undefined) => {
      if (item?.pk === 'CHANGES') out.push(`${item.kind}:${item.id}`);
    };
    for (const c of this.sent) {
      const input = (c as { input: Record<string, any> }).input;
      if (c instanceof PutCommand) take(input.Item);
      if (c instanceof TransactWriteCommand) for (const t of input.TransactItems) take(t.Put?.Item);
      if (c instanceof BatchWriteCommand) for (const reqs of Object.values(input.RequestItems) as any[]) for (const r of reqs) take(r.PutRequest?.Item);
    }
    return out;
  }
}

describe('the real store writes the change log', () => {
  const plan = { id: 'p1', organizerId: 'c1', discipline: 'sport' as const, place: 'Somewhere', area: '', grades: { scale: 'routes' as const, min: 6, max: 10 }, memberIds: ['c1'], notes: '' };
  const climber = { id: 'c1', name: 'Made-up Climber', bio: '', levels: {}, gear: [], gearPhotos: [], areas: [] };
  const ad = { id: 'a1', ownerId: 'c1', text: 'Chalk', link: 'https://shop.example.com', status: 'approved' as const, createdAt: '2030-05-01T10:00:00.000Z' };
  const at = new Date('2030-05-01T10:00:00.000Z');
  let doc: RecordingDoc;
  let real: Store;
  beforeEach(() => {
    doc = new RecordingDoc();
    real = new Store(doc as never, 't');
  });

  it('in the same transaction as every plan write', async () => {
    await real.apply(null, { plan, requests: [], messages: [], notices: [], matches: [] }, at);
    await real.apply({ plan, version: 1 }, { plan: { ...plan, place: 'Elsewhere' }, requests: [], messages: [], notices: [], matches: [] }, at);
    await real.apply({ plan, version: 2 }, { plan: null, requests: [], messages: [], notices: [], matches: [] }, at);
    await real.withdrawRequest({ plan, version: 3 }, 'c2');
    await real.clearPlanNotes('p1');
    const transactions = doc.sent.filter((c) => c instanceof TransactWriteCommand) as TransactWriteCommand[];
    expect(transactions).toHaveLength(5);
    for (const t of transactions) {
      expect(t.input.TransactItems!.some((i) => i.Put?.Item?.pk === 'CHANGES' && i.Put.Item.kind === 'plan' && i.Put.Item.id === 'p1')).toBe(true);
    }
    const entry = transactions[0]!.input.TransactItems!.find((i) => i.Put?.Item?.pk === 'CHANGES')!.Put!.Item!;
    expect(entry.sk).toMatch(/^\d{4}-\d\d-\d\dT[\d:.]+Z#plan#p1#[0-9a-f]{8}$/);
    expect(entry.ttl).toBeGreaterThan(Date.now() / 1000);
  });

  it('after every ad, setting and profile write', async () => {
    await real.putAd(ad);
    await real.deleteAd('a1');
    await real.putAdSettings({ every: 5 });
    await real.createProfile('test#c1', climber, at);
    await real.saveProfile(climber, 'test#c1', at);
    await real.putEmail('c1', 'made-up@example.com');
    await real.clearProfileContent('c1');
    await real.deleteClimberItems('c1');
    expect(doc.changes()).toEqual(['ad:a1', 'ad:a1', 'adSettings:ads', 'climber:c1', 'climber:c1', 'climber:c1', 'climber:c1', 'climber:c1']);
  });

  it('the showcase logs each plan it re-dates', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    const t = new Date('2030-05-01T10:00:00.000Z');
    await seedShowcase(real, t);
    const plans = showcaseData(t).plans.map((p) => `plan:${p.id}`);
    expect(doc.changes().filter((c) => c.startsWith('plan:'))).toEqual(plans);
    // And the marker it writes says until when it's fresh.
    const marker = (doc.sent.filter((c) => c instanceof PutCommand) as PutCommand[]).map((c) => c.input.Item!).find((i) => i.pk === 'META#SHOWCASE')!;
    expect(marker).toMatchObject({ version: SHOWCASE_VERSION, time: t.toISOString() });
    doc.send = async (c: object) => (c instanceof GetCommand ? { Item: marker } : {});
    expect(await showcaseFreshUntil(real)).toBe(t.getTime() + 12 * 3_600_000);
  });

  it('reads the log with one strongly consistent query', async () => {
    doc.items = [{ pk: 'CHANGES', sk: '2030-05-01T10:00:00.000Z#plan#p1#00000000', kind: 'plan', id: 'p1' }];
    expect(await real.changesSince('2030-05-01T09:59:00.000Z')).toEqual([{ key: '2030-05-01T10:00:00.000Z#plan#p1#00000000', kind: 'plan', id: 'p1' }]);
    const q = doc.sent.find((c) => c instanceof QueryCommand) as QueryCommand;
    expect(q.input).toMatchObject({ ConsistentRead: true, KeyConditionExpression: 'pk = :pk AND sk > :after', ExpressionAttributeValues: { ':pk': 'CHANGES', ':after': '2030-05-01T09:59:00.000Z' } });
    expect(q.input.IndexName).toBeUndefined();
  });
});
