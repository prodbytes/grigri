import { beforeEach, describe, expect, it, vi } from 'vitest';
import { Api, NO_NAME } from '../src/api.js';
import { Auth, type Caller, hashToken, subjectHash } from '../src/auth.js';
import { ApiError } from '../src/domain/errors.js';
import type { PicCatalog } from '../src/domain/model.js';
import { FakeRbacr } from './fake-rbacr.js';
import { FakeStore } from './fake-store.js';

let now = new Date('2030-05-01T10:00:00.000Z');
let store: FakeStore;
let api: Api;
let auth: Auth;
/** S3 as the fake photos see it: key -> pending tag. */
let objects: Map<string, boolean>;
/** Each presigned upload: its key, type and size cap. */
let presigned: { key: string; contentType: string; maxBytes: number }[];
let removed: string[];
let rbacr: FakeRbacr;
/** GriGri Pics' catalog, as the fake bucket has it. */
let catalog: PicCatalog;

const who = (name: string, admin = false): Caller => ({ subject: `test#${name}`, email: `${name}@example.com`, isAdmin: async () => admin });
const ada = who('ada');
const ben = who('ben');
const cy = who('cy');
const root = who('root', true);

async function call(c: Caller | null, method: string, path: string, body?: unknown, query: Record<string, string> = {}) {
  return (await api.handle(method, path, { caller: c, body, query })) as Record<string, any>;
}

async function fails(promise: Promise<unknown>, status: number, message?: RegExp) {
  const error = await promise.then(() => undefined, (e: unknown) => e);
  expect(error).toBeInstanceOf(ApiError);
  expect((error as ApiError).status).toBe(status);
  if (message) expect((error as ApiError).message).toMatch(message);
}

const profile = (name: string) => ({ name, bio: '', levels: { sport: { scale: 'routes', min: 6, max: 10 } }, gear: ['rope'] });
const planBody = {
  discipline: 'sport',
  place: 'Somewhere',
  area: 'Nowhere',
  start: '2030-05-10T08:00:00Z',
  end: '2030-05-10T14:00:00Z',
  grades: { scale: 'routes', min: 6, max: 10 },
  notes: '',
};

let random = () => 0;

beforeEach(async () => {
  now = new Date('2030-05-01T10:00:00.000Z');
  random = () => 0;
  store = new FakeStore();
  objects = new Map();
  removed = [];
  presigned = [];
  catalog = { generatedAt: '', crags: [] };
  const photos = {
    presign: async (key: string, contentType: string, maxBytes: number) => {
      presigned.push({ key, contentType, maxBytes });
      return { url: 'https://upload.example.com/', fields: { key: `photos/${key}` } };
    },
    keep: async (key: string) => {
      if (!objects.has(key)) return false;
      objects.set(key, false);
      return true;
    },
    remove: async (keys: string[]) => {
      removed.push(...keys);
      for (const k of keys) objects.delete(k);
    },
  };
  auth = new Auth({
    store: store.asStore(),
    verify: async () => ({ subject: 'https://accounts.google.com#42', email: 'ada@example.com', emailVerified: true, name: 'Ada Example' }),
    config: { devMode: false, isAdmin: async (email) => email === 'root@example.com' },
    clock: () => now,
  });
  rbacr = new FakeRbacr(() => now);
  api = new Api({ store: store.asStore(), photos, pics: { catalog: async () => catalog }, roles: rbacr.lookup, grants: rbacr.api, auth, config: { stage: 'local', version: '0.1.2' }, clock: () => now, random: () => random() });
});

describe('access', () => {
  it('health is public', async () => {
    expect(await call(null, 'GET', '/api/health')).toEqual({ ok: true, stage: 'local', version: '0.1.2' });
  });

  it('everything else needs a caller', async () => {
    await fails(call(null, 'GET', '/api/me'), 401);
    await fails(call(null, 'GET', '/api/discover'), 401);
  });

  it('a caller without a profile gets 409 no profile, except me and photos', async () => {
    await fails(call(ada, 'GET', '/api/discover'), 409, /no profile/);
    await fails(call(ada, 'GET', '/api/plans'), 409, /no profile/);
    const photo = await call(ada, 'POST', '/api/photos', { kind: 'profile', contentType: 'image/jpeg' });
    expect(photo.key).toMatch(new RegExp(`^${subjectHash(ada.subject)}/profile/[A-Za-z0-9_-]{16}\\.jpg$`));
  });

  it('GET /api/me creates my profile the first time, from my Google name', async () => {
    const named = { ...ada, name: 'Ada Example' };
    const { climber, admin } = await call(named, 'GET', '/api/me');
    expect(admin).toBe(false);
    expect(climber).toEqual({ id: expect.stringMatching(/^[A-Za-z0-9_-]{16}$/), name: 'Ada Example', bio: '', levels: {}, gear: [], gearPhotos: [] });
    expect((await call(named, 'GET', '/api/me')).climber).toEqual(climber);
    expect(await call(named, 'GET', '/api/discover')).toBeDefined();
    // No name from Google (a session from before names were kept).
    expect((await call(ben, 'GET', '/api/me')).climber.name).toBe(NO_NAME);
  });

  it('GET /api/me has my roles from rbacr, or null when it can\'t say', async () => {
    const photos = { presign: async () => ({ url: '', fields: {} }), keep: async () => true, remove: async () => {} };
    const noRbacr = new Api({ store: store.asStore(), photos, auth, config: { stage: 'local', version: '0.1.2' }, clock: () => now });
    expect((await noRbacr.handle('GET', '/api/me', { caller: ada, body: undefined, query: {} }) as any).roles).toBeNull();
    const asked: string[] = [];
    const withRoles = new Api({
      store: store.asStore(),
      photos: { presign: async () => ({ url: '', fields: {} }), keep: async () => true, remove: async () => {} },
      auth,
      roles: async (email) => {
        asked.push(email);
        return email === root.email ? ['admin', 'root'] : [];
      },
      config: { stage: 'local', version: '0.1.2' },
      clock: () => now,
    });
    expect(await withRoles.handle('GET', '/api/me', { caller: root, body: undefined, query: {} })).toMatchObject({ admin: true, roles: ['admin', 'root'] });
    expect(asked).toEqual([root.email]);
  });

  it('two first loads at once make one profile', async () => {
    const [a, b] = await Promise.all([call(ada, 'GET', '/api/me'), call(ada, 'GET', '/api/me')]);
    expect(a.climber.id).toBe(b.climber.id);
  });

  it('admin routes are admins only', async () => {
    const { climber: me } = await call(ada, 'PUT', '/api/me', profile('Ada'));
    await fails(call(ada, 'GET', '/api/admin/climbers'), 403);
    await fails(call(ada, 'POST', `/api/admin/climbers/${me.id}/block`), 403);
    await call(root, 'PUT', '/api/me', profile('Root'));
    expect((await call(root, 'GET', '/api/admin/climbers')).climbers).toHaveLength(2);
    expect((await call(root, 'GET', '/api/me')).admin).toBe(true);
  });

  it('the admin lists everyone and blocks and unblocks them', async () => {
    const { climber: b } = await call(ben, 'PUT', '/api/me', { ...profile('Ben'), location: { name: 'Town', lat: 41.39, lon: 2.17 } });
    await call(ada, 'PUT', '/api/me', profile('Ada'));
    const { climber: r } = await call(root, 'PUT', '/api/me', profile('Root'));
    const list = (await call(root, 'GET', '/api/admin/climbers')).climbers;
    // By name, without where they are.
    expect(list.map((c: any) => [c.name, c.blocked])).toEqual([['Ada', false], ['Ben', false], ['Root', false]]);
    expect(list[1].location).toBeUndefined();

    expect(await call(root, 'POST', `/api/admin/climbers/${b.id}/block`)).toEqual({ blocked: true });
    // Blocked is rbacr's role, by Ben's verified email.
    expect(rbacr.calls).toEqual(['grant blocked ben@example.com']);
    expect((await call(root, 'GET', '/api/admin/climbers')).climbers[1].blocked).toBe(true);
    // Blocked: nothing works but signing out, and a save can't unblock.
    await fails(call(ben, 'GET', '/api/me'), 403, /blocked/);
    await fails(call(ben, 'PUT', '/api/me', profile('Ben')), 403, /blocked/);
    await fails(call(ben, 'GET', '/api/discover'), 403, /blocked/);
    expect(await call(ben, 'DELETE', '/api/session')).toEqual({});

    expect(await call(root, 'POST', `/api/admin/climbers/${b.id}/unblock`)).toEqual({ blocked: false });
    expect((await call(ben, 'GET', '/api/me')).climber.name).toBe('Ben');

    await fails(call(root, 'POST', `/api/admin/climbers/${r.id}/block`), 400);
    await fails(call(root, 'POST', '/api/admin/climbers/nobody/block'), 404);
  });

  it("blocking finds the email in the climber's sessions; none: 409; rbacr down: nobody's blocked", async () => {
    const { climber: b } = await call(ben, 'PUT', '/api/me', profile('Ben'));
    await call(root, 'PUT', '/api/me', profile('Root'));
    // A climber from before emails were kept: their session's, then kept.
    store.emails.delete(b.id);
    store.sessions.set('s-ben', { id: 's-ben', subject: ben.subject, email: 'ben@example.com', emailVerified: true, createdAt: now.toISOString(), lastUsedAt: now.toISOString(), ttl: 0 } as any);
    await call(root, 'POST', `/api/admin/climbers/${b.id}/block`);
    expect(rbacr.calls).toEqual(['grant blocked ben@example.com']);
    expect(store.emails.get(b.id)).toBe('ben@example.com');
    // No email anywhere: rbacr can't block them.
    const { climber: c } = await call(cy, 'PUT', '/api/me', profile('Cy'));
    store.emails.delete(c.id);
    await fails(call(root, 'POST', `/api/admin/climbers/${c.id}/block`), 409, /no verified email/);
    // rbacr can't say who's blocked: Ben gets in (logged), rather than everyone out.
    rbacr.failNext = true;
    expect((await call(ben, 'GET', '/api/me')).climber.name).toBe('Ben');
  });

  it("a blocked organizer's plans leave everyone's deck", async () => {
    const { climber: b } = await call(ben, 'PUT', '/api/me', profile('Ben'));
    await call(ben, 'POST', '/api/plans', planBody);
    await call(ada, 'PUT', '/api/me', profile('Ada'));
    await call(root, 'PUT', '/api/me', profile('Root'));
    expect((await call(ada, 'GET', '/api/discover')).plans).toHaveLength(1);
    await call(root, 'POST', `/api/admin/climbers/${b.id}/block`);
    const deck = await call(ada, 'GET', '/api/discover');
    expect(deck.plans).toEqual([]);
    expect(deck.climbers).toEqual({});
  });
});

describe('profile', () => {
  it('creates once, then updates the same climber; photos must be mine', async () => {
    const { climber } = await call(ada, 'PUT', '/api/me', profile('Ada'));
    expect(climber.id).toMatch(/^[A-Za-z0-9_-]{16}$/);
    const { key } = await call(ada, 'POST', '/api/photos', { kind: 'profile', contentType: 'image/png' });
    objects.set(key, true);
    const updated = await call(ada, 'PUT', '/api/me', { ...profile('Ada B'), photo: key });
    expect(updated.climber).toMatchObject({ id: climber.id, name: 'Ada B', photo: key });
    await call(ben, 'PUT', '/api/me', profile('Ben'));
    await fails(call(ben, 'PUT', '/api/me', { ...profile('Ben'), photo: key }), 400, /one of your photos/);
  });

  it('keeps the photos a profile saves and deletes the ones it drops', async () => {
    const upload = async (kind: string) => {
      const { key } = await call(ada, 'POST', '/api/photos', { kind, contentType: 'image/jpeg' });
      objects.set(key, true);
      return key as string;
    };
    const [p1, g1, g2] = [await upload('profile'), await upload('gear'), await upload('gear')];
    await call(ada, 'PUT', '/api/me', { ...profile('Ada'), photo: p1, gearPhotos: [g1] });
    expect(objects.get(p1)).toBe(false);
    expect(objects.get(g1)).toBe(false);
    expect(objects.get(g2)).toBe(true); // never saved: the bucket expires it
    const p2 = await upload('profile');
    await call(ada, 'PUT', '/api/me', { ...profile('Ada'), photo: p2, gearPhotos: [g1, g2] });
    expect(removed).toEqual([p1]);
    expect(objects.get(p2)).toBe(false);
    expect(objects.get(g2)).toBe(false);
    // Unchanged photos cost nothing; an upload that isn't there is refused.
    removed = [];
    await call(ada, 'PUT', '/api/me', { ...profile('Ada B'), photo: p2, gearPhotos: [g1, g2] });
    expect(removed).toEqual([]);
    const missing = `${subjectHash(ada.subject)}/gear/AAAAAAAAAAAAAAAA.jpg`;
    await fails(call(ada, 'PUT', '/api/me', { ...profile('Ada'), photo: p2, gearPhotos: [missing] }), 400, /isn't uploaded/);
    expect((await call(ada, 'GET', '/api/me')).climber.gearPhotos).toEqual([g1, g2]);
  });

  it('photos refuse other types', async () => {
    await fails(call(ada, 'POST', '/api/photos', { kind: 'profile', contentType: 'image/gif' }), 400);
    await fails(call(ada, 'POST', '/api/photos', { kind: 'avatar', contentType: 'image/png' }), 400);
  });
});

describe('the matchmaking flow', () => {
  let ids: Record<string, string>;
  let planId: string;

  beforeEach(async () => {
    ids = {};
    for (const [c, name] of [[ada, 'Ada'], [ben, 'Ben'], [cy, 'Cy'], [root, 'Root']] as const) {
      ids[name] = (await call(c, 'PUT', '/api/me', profile(name))).climber.id;
    }
    planId = (await call(ada, 'POST', '/api/plans', planBody)).plan.id;
  });

  it('joining a demo plan matches at once: its made-up members never answer', async () => {
    const stored = store.plans.get(planId)!;
    store.plans.set(planId, { ...stored, plan: { ...stored.plan, demo: true } });
    const { request } = await call(ben, 'POST', `/api/plans/${planId}/join`);
    expect(request).toMatchObject({ climberId: ids.Ben, acceptedBy: [ids.Ada], rejected: false });
    expect((await call(ben, 'GET', '/api/plans')).plans.map((p: any) => p.id)).toEqual([planId]);
    expect((await call(ben, 'GET', '/api/notices')).notices[0]).toMatchObject({ kind: 'accepted', planId, read: false });
    expect((await call(ada, 'GET', '/api/requests')).requests).toEqual([]);
    await fails(call(ben, 'POST', `/api/plans/${planId}/join`), 409, /already in this plan/);
  });

  it('joining an open plan matches at once, with no request for anyone to answer', async () => {
    const open = (await call(ada, 'POST', '/api/plans', { ...planBody, type: 'open' })).plan;
    expect(open.type).toBe('open');
    await call(ben, 'POST', `/api/plans/${open.id}/join`);
    expect((await call(ben, 'GET', '/api/plans')).plans.map((p: any) => p.id)).toEqual([open.id]);
    expect((await call(ben, 'GET', '/api/notices')).notices[0]).toMatchObject({ kind: 'accepted', planId: open.id });
    expect((await call(ada, 'GET', '/api/requests')).requests).toEqual([]);
    expect((await call(ada, 'GET', '/api/notices')).notices).toEqual([]);
  });

  it('only Premium climbers make a plan guided', async () => {
    await fails(call(ben, 'POST', '/api/plans', { ...planBody, type: 'guided', price: { amount: 45, currency: 'EUR' } }), 403, /Premium/);
    await fails(call(ada, 'PUT', `/api/plans/${planId}`, { ...planBody, type: 'guided', price: { amount: 45, currency: 'EUR' } }), 403, /Premium/);
    rbacr.give('ada@example.com', 'premium');
    const { plan } = await call(ada, 'PUT', `/api/plans/${planId}`, { ...planBody, type: 'guided', price: { amount: 45, currency: 'EUR' } });
    expect(plan.type).toBe('guided');
    // Premium ends: the guided plan stays editable.
    await rbacr.api.revoke('ada@example.com', 'premium');
    expect((await call(ada, 'PUT', `/api/plans/${planId}`, { ...planBody, type: 'guided', price: { amount: 50, currency: 'EUR' } })).plan.price.amount).toBe(50);
    // Admins (rbacr's root) hold Premium.
    rbacr.give('root@example.com', 'root');
    expect((await call(root, 'POST', '/api/plans', { ...planBody, type: 'guided', price: { amount: 45, currency: 'EUR' } })).plan.type).toBe('guided');
  });

  it('a guided plan has a price, and only its guide answers', async () => {
    rbacr.give('ada@example.com', 'premium');
    await fails(call(ada, 'POST', '/api/plans', { ...planBody, type: 'guided' }), 400, /needs a price/);
    const guided = (await call(ada, 'POST', '/api/plans', { ...planBody, type: 'guided', price: { amount: 45, currency: 'EUR' } })).plan;
    expect(guided).toMatchObject({ type: 'guided', price: { amount: 45, currency: 'EUR' } });
    await call(ben, 'POST', `/api/plans/${guided.id}/join`);
    await call(ada, 'POST', `/api/requests/${guided.id}/${ids.Ben}/accept`);
    await call(cy, 'POST', `/api/plans/${guided.id}/join`);
    expect((await call(ben, 'GET', '/api/requests')).requests).toEqual([]);
    await fails(call(ben, 'POST', `/api/requests/${guided.id}/${ids.Cy}/accept`), 403, /guide/);
    const { match } = await call(ada, 'POST', `/api/requests/${guided.id}/${ids.Cy}/accept`);
    expect(match.plan.memberIds).toEqual([ids.Ada, ids.Ben, ids.Cy]);
    expect((await call(ben, 'GET', `/api/plans/${guided.id}`)).plan.price).toEqual({ amount: 45, currency: 'EUR' });
  });

  it('making a plan open lets in whoever is waiting', async () => {
    await call(ben, 'POST', `/api/plans/${planId}/join`);
    const { plan } = await call(ada, 'PUT', `/api/plans/${planId}`, { ...planBody, type: 'open' });
    expect(plan.memberIds).toEqual([ids.Ada, ids.Ben]);
    expect((await call(ben, 'GET', '/api/notices')).notices[0]).toMatchObject({ kind: 'accepted', planId });
  });

  it("refreshing brings passed plans back, but not ones I asked to join", async () => {
    await call(ben, 'POST', `/api/plans/${planId}/pass`);
    expect((await call(ben, 'GET', '/api/discover')).plans).toEqual([]);
    expect(await call(ben, 'DELETE', '/api/passes')).toEqual({});
    expect((await call(ben, 'GET', '/api/discover')).plans.map((p: any) => p.id)).toEqual([planId]);

    // Cy asks, is turned down and dismisses it: it stays out of the deck
    // and out of Cy's requests.
    await call(cy, 'POST', `/api/plans/${planId}/join`);
    await call(ada, 'POST', `/api/requests/${planId}/${ids.Cy}/reject`);
    await call(cy, 'POST', `/api/requests/${planId}/${ids.Cy}/dismiss`);
    await call(cy, 'DELETE', '/api/passes');
    expect((await call(cy, 'GET', '/api/discover')).plans).toEqual([]);
    expect((await call(cy, 'GET', '/api/plans')).asked).toEqual([]);
  });

  it('discover, join, unanimous accept, chat, leave', async () => {
    const deck = await call(ben, 'GET', '/api/discover');
    expect(deck.plans.map((p: any) => p.id)).toEqual([planId]);
    expect(Object.keys(deck.climbers)).toEqual([ids.Ada]);
    expect(await call(ada, 'GET', '/api/discover')).toMatchObject({ plans: [] });

    const { request } = await call(ben, 'POST', `/api/plans/${planId}/join`);
    expect(request).toEqual({ id: `${planId}/${ids.Ben}`, planId, climberId: ids.Ben, acceptedBy: [], rejected: false, time: now.toISOString() });
    await fails(call(ben, 'POST', `/api/plans/${planId}/join`), 409, /already asked/);
    expect((await call(ben, 'GET', '/api/discover')).plans).toEqual([]);
    expect((await call(ben, 'GET', '/api/plans')).asked).toHaveLength(1);

    // Ada is notified and sees it to review; outsiders can't answer it.
    const notices = await call(ada, 'GET', '/api/notices');
    expect(notices.notices[0]).toMatchObject({ kind: 'request', climberId: ids.Ben, read: false });
    expect(notices.climbers[ids.Ben!].name).toBe('Ben');
    expect((await call(ada, 'GET', '/api/requests')).requests).toHaveLength(1);
    await fails(call(cy, 'POST', `/api/requests/${planId}/${ids.Ben}/accept`), 403);
    await fails(call(cy, 'GET', `/api/plans/${planId}/messages`), 403);

    now = new Date(now.getTime() + 1000);
    const { match } = await call(ada, 'POST', `/api/requests/${planId}/${ids.Ben}/accept`);
    expect(match.newcomerId).toBe(ids.Ben);
    expect(match.plan.memberIds).toEqual([ids.Ada, ids.Ben]);
    expect((await call(ben, 'GET', '/api/notices')).notices[0]).toMatchObject({ kind: 'accepted', planId });
    expect((await call(ben, 'GET', '/api/plans')).plans.map((p: any) => p.id)).toEqual([planId]);

    // Cy asks: both members must accept now.
    await call(cy, 'POST', `/api/plans/${planId}/join`);
    expect((await call(ada, 'POST', `/api/requests/${planId}/${ids.Cy}/accept`)).match).toBeNull();
    expect((await call(ben, 'POST', `/api/requests/${planId}/${ids.Cy}/accept`)).match.newcomerId).toBe(ids.Cy);

    // Chat: members only; notes for the asks and joins.
    now = new Date(now.getTime() + 1000);
    const { message } = await call(cy, 'POST', `/api/plans/${planId}/messages`, { text: 'Hi all' });
    const chat = await call(ada, 'GET', `/api/plans/${planId}/messages`);
    expect(chat.messages.map((m: any) => m.text)).toEqual([
      'Ada created the plan. People who match will show up here.',
      'Ben asked to join',
      'Ben joined the plan 🎉',
      'Cy asked to join',
      'Cy joined the plan 🎉',
      'Hi all',
    ]);
    const after = await call(ada, 'GET', `/api/plans/${planId}/messages`, undefined, { after: new Date(now.getTime() - 1).toISOString() });
    expect(after.messages).toEqual([message]);
    await fails(call(ada, 'GET', `/api/plans/${planId}/messages`, undefined, { after: 'yesterday' }), 400);

    // The organizer leaves: a random member (here the last) organizes, and
    // the chat says so; the plan is out of Ada's list. Everyone leaves: it's gone.
    random = () => 0.99;
    await call(ada, 'POST', `/api/plans/${planId}/leave`);
    // The organizer comes first in memberIds, as always.
    expect((await call(ben, 'GET', `/api/plans/${planId}`)).plan).toMatchObject({ organizerId: ids.Cy, memberIds: [ids.Cy, ids.Ben] });
    const notes = (await call(ben, 'GET', `/api/plans/${planId}/messages`)).messages.map((m: { text: string }) => m.text);
    expect(notes.at(-1)).toBe('Ada left the plan; Cy organizes it now');
    const adas = await call(ada, 'GET', '/api/plans');
    expect([...adas.plans, ...adas.asked.map((a: any) => a.plan)].map((p: any) => p.id)).not.toContain(planId);
    // Out of Ada's deck, even after a refresh (she created it: no request
    // of hers keeps it out, the left mark does).
    await call(ada, 'DELETE', '/api/passes');
    expect((await call(ada, 'GET', '/api/discover')).plans.map((p: any) => p.id)).not.toContain(planId);
    await fails(call(ada, 'POST', `/api/plans/${planId}/leave`), 403);
    await call(ben, 'POST', `/api/plans/${planId}/leave`);
    await call(cy, 'POST', `/api/plans/${planId}/leave`);
    await fails(call(cy, 'GET', `/api/plans/${planId}`), 404);
  });

  it('my location and areas are mine only; the deck says how far each plan is', async () => {
    const here = { name: 'Home town', lat: 41.39, lon: 2.17 };
    const me = await call(ben, 'PUT', '/api/me', { ...profile('Ben'), location: here, areas: [{ name: 'Crag', lat: 41.26, lon: 0.38 }] });
    expect(me.climber).toMatchObject({ location: here, areas: [{ name: 'Crag' }] });
    expect((await call(ben, 'GET', '/api/me')).climber.location).toEqual(here);

    const near = (await call(ada, 'POST', '/api/plans', { ...planBody, place: 'Near', lat: 41.47, lon: 2.1 })).plan.id;
    const deck = await call(ben, 'GET', '/api/discover');
    expect(deck.plans.map((p: any) => p.id)).toEqual([near, planId]);
    expect(deck.distanceKm).toEqual({ [near]: 11 });

    // Ada sees Ben's profile (he asked to join) without where he is.
    await call(ben, 'POST', `/api/plans/${near}/join`);
    const { climbers } = await call(ada, 'GET', `/api/plans/${near}`);
    expect(climbers[ids.Ben!]).toMatchObject({ name: 'Ben' });
    expect(climbers[ids.Ben!]).not.toHaveProperty('location');
    expect(climbers[ids.Ben!]).not.toHaveProperty('areas');
  });

  it('nudge: the members who have not said yes are notified, once per 12 hours', async () => {
    // Ben joins first, so Cy's request waits for Ada and Ben.
    await call(ben, 'POST', `/api/plans/${planId}/join`);
    await call(ada, 'POST', `/api/requests/${planId}/${ids.Ben}/accept`);
    await fails(call(cy, 'POST', `/api/plans/${planId}/nudge`), 404, /haven't asked/);
    await fails(call(ada, 'POST', `/api/plans/${planId}/nudge`), 404);
    await call(cy, 'POST', `/api/plans/${planId}/join`);
    await call(ada, 'POST', `/api/requests/${planId}/${ids.Cy}/accept`);
    await call(ada, 'POST', '/api/notices/read');
    await call(ben, 'POST', '/api/notices/read');

    now = new Date(now.getTime() + 60_000);
    const first = await call(cy, 'POST', `/api/plans/${planId}/nudge`);
    expect(first).toEqual({ request: expect.objectContaining({ climberId: ids.Cy, nudgedAt: now.toISOString() }), nudged: 1 });
    // Only Ben, who hasn't answered; Ada already said yes.
    expect((await call(ada, 'GET', '/api/notices')).notices.filter((n: any) => !n.read)).toEqual([]);
    const benNotices = await call(ben, 'GET', '/api/notices');
    expect(benNotices.notices[0]).toEqual({
      id: `${planId}/nudge/${ids.Cy}`, kind: 'nudge', planId, planTitle: 'Somewhere', climberId: ids.Cy, time: now.toISOString(), read: false,
    });
    expect(benNotices.climbers[ids.Cy!].name).toBe('Cy');
    // My plans show when I last nudged.
    expect((await call(cy, 'GET', '/api/plans')).asked[0].request.nudgedAt).toBe(now.toISOString());

    // Too soon: 429, nothing sent.
    await call(ben, 'POST', '/api/notices/read');
    now = new Date(now.getTime() + 11 * 3600_000);
    await fails(call(cy, 'POST', `/api/plans/${planId}/nudge`), 429, /less than 12 hours ago/);
    expect((await call(ben, 'GET', '/api/notices')).notices.filter((n: any) => !n.read)).toEqual([]);

    // 12 hours on: again, replacing the last nudge (unread again).
    now = new Date(now.getTime() + 3600_000);
    expect((await call(cy, 'POST', `/api/plans/${planId}/nudge`)).nudged).toBe(1);
    const again = (await call(ben, 'GET', '/api/notices')).notices.filter((n: any) => n.kind === 'nudge');
    expect(again).toEqual([expect.objectContaining({ read: false, time: now.toISOString() })]);

    // An answered request can't be nudged.
    now = new Date(now.getTime() + 13 * 3600_000);
    await call(ben, 'POST', `/api/requests/${planId}/${ids.Cy}/reject`);
    await fails(call(cy, 'POST', `/api/plans/${planId}/nudge`), 409, /declined/);
  });

  it('nudge: not once joined, nor after the plan started', async () => {
    await call(ben, 'POST', `/api/plans/${planId}/join`);
    await call(cy, 'POST', `/api/plans/${planId}/join`);
    await call(ada, 'POST', `/api/requests/${planId}/${ids.Ben}/accept`);
    await fails(call(ben, 'POST', `/api/plans/${planId}/nudge`), 409, /already in this plan/);
    now = new Date('2030-05-10T09:00:00Z');
    await fails(call(cy, 'POST', `/api/plans/${planId}/nudge`), 409, /started/);
    await fails(call(cy, 'POST', '/api/plans/nope/nudge'), 404);
  });

  it('one no: declined notice, then dismiss', async () => {
    await call(ben, 'POST', `/api/plans/${planId}/join`);
    await fails(call(cy, 'POST', `/api/requests/${planId}/${ids.Ben}/dismiss`), 403);
    await fails(call(ben, 'POST', `/api/requests/${planId}/${ids.Ben}/dismiss`), 409, /wasn't declined/);
    await call(ada, 'POST', `/api/requests/${planId}/${ids.Ben}/reject`);
    expect((await call(ben, 'GET', '/api/notices')).notices[0]).toMatchObject({ kind: 'declined' });
    expect((await call(ben, 'GET', '/api/plans')).asked[0].request.rejected).toBe(true);
    await call(ben, 'POST', `/api/requests/${planId}/${ids.Ben}/dismiss`);
    expect((await call(ben, 'GET', '/api/plans')).asked).toEqual([]);
    expect((await call(ben, 'GET', '/api/discover')).plans).toEqual([]);
    await fails(call(ben, 'POST', `/api/plans/${planId}/join`), 409);
  });

  it('chat media: members upload photos and videos, and send them', async () => {
    const media = `/api/plans/${planId}/media`;
    // Members only; photos and MP4 or QuickTime videos only.
    await fails(call(ben, 'POST', media, { contentType: 'image/jpeg' }), 403);
    await fails(call(ada, 'POST', '/api/plans/nope/media', { contentType: 'image/jpeg' }), 404);
    for (const contentType of ['image/gif', 'application/pdf', 'video/webm', 'text/html', 'toString', undefined]) {
      await fails(call(ada, 'POST', media, { contentType }), 400, /contentType/);
    }
    const photo = await call(ada, 'POST', media, { contentType: 'image/webp' });
    expect(photo.key).toMatch(new RegExp(`^chat/${planId}/[A-Za-z0-9_-]{16}\\.webp$`));
    const video = await call(ada, 'POST', media, { contentType: 'video/quicktime' });
    expect(video).toMatchObject({ key: expect.stringMatching(/\.mov$/), maxBytes: 50 * 1024 * 1024 });
    expect(presigned.map((p) => [p.contentType, p.maxBytes])).toEqual([
      ['image/webp', 2 * 1024 * 1024],
      ['video/quicktime', 50 * 1024 * 1024],
    ]);

    // Not uploaded yet: refused. Uploaded: sent, and no longer pending.
    const send = `/api/plans/${planId}/messages`;
    await fails(call(ada, 'POST', send, { attachment: photo.key }), 400, /isn't uploaded/);
    objects.set(photo.key, true);
    objects.set(video.key, true);
    const { message } = await call(ada, 'POST', send, { attachment: photo.key });
    expect(message).toMatchObject({ text: '', attachment: { key: photo.key, kind: 'image' } });
    expect(objects.get(photo.key)).toBe(false);
    await call(ada, 'POST', send, { text: 'Our crag', attachment: video.key });
    const chat = await call(ada, 'GET', send);
    expect(chat.messages.slice(-2).map((m: any) => [m.text, m.attachment])).toEqual([
      ['', { key: photo.key, kind: 'image' }],
      ['Our crag', { key: video.key, kind: 'video' }],
    ]);

    // Another plan's media, or an outsider sending it, is refused (and stays pending).
    const other = (await call(ben, 'POST', '/api/plans', planBody)).plan.id;
    await fails(call(ben, 'POST', `/api/plans/${other}/messages`, { attachment: photo.key }), 400, /this plan/);
    const late = await call(ada, 'POST', media, { contentType: 'image/png' });
    objects.set(late.key, true);
    await fails(call(ben, 'POST', send, { attachment: late.key }), 403);
    expect(objects.get(late.key)).toBe(true);
    // Neither text nor attachment: nothing to send.
    await fails(call(ada, 'POST', send, {}), 400, /text is required/);
  });

  it('only the organizer edits', async () => {
    await fails(call(ben, 'PUT', `/api/plans/${planId}`, planBody), 403);
    const { plan } = await call(ada, 'PUT', `/api/plans/${planId}`, { ...planBody, place: 'Elsewhere' });
    expect(plan.place).toBe('Elsewhere');
    await fails(call(ada, 'PUT', `/api/plans/${planId}`, { ...planBody, start: '2020-01-01T00:00:00Z' }), 400);
  });

  it('pass takes a plan out of my deck; notices can be marked read', async () => {
    await call(ben, 'POST', `/api/plans/${planId}/pass`);
    expect((await call(ben, 'GET', '/api/discover')).plans).toEqual([]);
    await fails(call(ben, 'POST', '/api/plans/nope/pass'), 404);
    await call(ben, 'POST', `/api/plans/${planId}/join`);
    await call(ada, 'POST', '/api/notices/read');
    expect((await call(ada, 'GET', '/api/notices')).notices.every((n: any) => n.read)).toBe(true);
  });

  it('notices name the plan by its place', async () => {
    await call(ben, 'POST', `/api/plans/${planId}/join`);
    expect((await call(ada, 'GET', '/api/notices')).notices[0].planTitle).toBe('Somewhere');
  });

  it("plan pics: members add and delete Your Pics; chat photos join them", async () => {
    const pics = `/api/plans/${planId}/pics`;
    // Members only; photos only.
    await fails(call(ben, 'POST', `${pics}/upload`, { contentType: 'image/jpeg' }), 403);
    await fails(call(ada, 'POST', `${pics}/upload`, { contentType: 'video/mp4' }), 400);
    const up = await call(ada, 'POST', `${pics}/upload`, { contentType: 'image/jpeg' });
    expect(up.key).toMatch(new RegExp(`^plans/${planId}/[A-Za-z0-9_-]{16}\\.jpg$`));
    expect(up.maxBytes).toBe(2 * 1024 * 1024);

    // Not uploaded: refused. Uploaded: added, no longer pending.
    await fails(call(ada, 'POST', pics, { key: up.key }), 400, /isn't uploaded/);
    objects.set(up.key, true);
    const { pic } = await call(ada, 'POST', pics, { key: up.key });
    expect(pic).toMatchObject({ planId, key: up.key, uploaderId: ids.Ada, fromChat: false });
    expect(objects.get(up.key)).toBe(false);
    // Another plan's key, or a key that isn't one, is refused.
    await fails(call(ada, 'POST', pics, { key: 'plans/other/abcdefgh.jpg' }), 400, /this plan/);
    await fails(call(ada, 'POST', pics, { key: `chat/${planId}/abcdefgh.jpg` }), 400);

    // A photo sent in the chat joins them; a video doesn't.
    const media = await call(ada, 'POST', `/api/plans/${planId}/media`, { contentType: 'image/png' });
    const video = await call(ada, 'POST', `/api/plans/${planId}/media`, { contentType: 'video/mp4' });
    objects.set(media.key, true);
    objects.set(video.key, true);
    await call(ada, 'POST', `/api/plans/${planId}/messages`, { attachment: media.key });
    await call(ada, 'POST', `/api/plans/${planId}/messages`, { attachment: video.key });
    const listed = await call(ada, 'GET', pics);
    expect(listed.member).toBe(true);
    expect(listed.yours.map((p: any) => [p.key, p.fromChat])).toEqual([[up.key, false], [media.key, true]]);
    expect(Object.keys(listed.climbers)).toEqual([ids.Ada]);

    // Outsiders see no Your Pics.
    expect(await call(ben, 'GET', pics)).toMatchObject({ yours: [], member: false });

    // Ben joins. He can't delete Ada's photo; the organizer and admins can.
    await call(ben, 'POST', `/api/plans/${planId}/join`);
    await call(ada, 'POST', `/api/requests/${planId}/${ids.Ben}/accept`);
    const chatPic = listed.yours[1];
    await fails(call(ben, 'DELETE', `${pics}/${pic.id}`), 403);
    await call(ada, 'DELETE', `${pics}/${pic.id}`);
    expect(removed).toEqual([up.key]);
    // A chat photo leaves the pics, not the chat.
    await call(root, 'DELETE', `${pics}/${chatPic.id}`);
    expect(removed).toEqual([up.key]);
    expect((await call(ada, 'GET', pics)).yours).toEqual([]);
    expect((await call(ada, 'GET', `/api/plans/${planId}/messages`)).messages.some((m: any) => m.attachment?.key === media.key)).toBe(true);
    await fails(call(ada, 'DELETE', `${pics}/${pic.id}`), 404);
  });

  it('plan pics: at most 100; a full plan keeps new chat photos in the chat only', async () => {
    for (let i = 0; i < 100; i++) {
      store.pics.push({ id: `p${i}`, planId, key: `plans/${planId}/k${i}xxxxxxx.jpg`, uploaderId: ids.Ada!, time: now.toISOString(), fromChat: false });
    }
    const up = await call(ada, 'POST', `/api/plans/${planId}/pics/upload`, { contentType: 'image/webp' });
    objects.set(up.key, true);
    await fails(call(ada, 'POST', `/api/plans/${planId}/pics`, { key: up.key }), 409, /at most 100/);
    const media = await call(ada, 'POST', `/api/plans/${planId}/media`, { contentType: 'image/jpeg' });
    objects.set(media.key, true);
    await call(ada, 'POST', `/api/plans/${planId}/messages`, { attachment: media.key });
    expect(store.pics).toHaveLength(100);
  });

  it("GriGri Pics: the plan's crag, then its area", async () => {
    const photo = (name: string) => ({ key: `crags/x/${name}.jpg`, width: 1600, height: 1067, caption: name, author: 'A. Example', license: 'CC BY-SA 4.0', licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/', source: 'https://commons.wikimedia.org/wiki/File:X.jpg' });
    catalog = {
      generatedAt: '2030-01-01T00:00:00Z',
      crags: [
        { id: 'area:siurana', name: 'Siurana', area: 'Siurana', lat: 41.2577, lon: 0.9318, photos: [photo('village')] },
        { id: 'osm:n1', name: "L'Olla", area: 'Siurana', lat: 41.2569, lon: 0.9302, photos: [photo('olla')] },
        { id: 'osm:n2', name: 'El Pati', area: 'Siurana', lat: 41.2602, lon: 0.9380, photos: [photo('pati')] },
      ],
    };
    // A plan typed by hand at "l'olla, Siurana": the crag by name, then the area by name.
    const typed = (await call(ada, 'POST', '/api/plans', { ...planBody, place: "l'olla", area: 'Siurana, Spain' })).plan.id;
    const got = await call(ben, 'GET', `/api/plans/${typed}/pics`);
    expect(got.grigri.map((p: any) => [p.crag, p.caption])).toEqual([["L'Olla", 'olla'], ['Siurana', 'village']]);
    // A plan at El Pati's sector: its own, then L'Olla (0.85 km away), then the area.
    const atPati = (await call(ada, 'POST', '/api/plans', { ...planBody, place: 'El Pati', sectorId: 'osm:n2', lat: 41.2602, lon: 0.938 })).plan.id;
    expect((await call(ada, 'GET', `/api/plans/${atPati}/pics`)).grigri.map((p: any) => p.cragId)).toEqual(['osm:n2', 'osm:n1', 'area:siurana']);
    // The deck's covers: each plan's best photo, with its credit.
    const deck = await call(ben, 'GET', '/api/discover');
    expect(deck.covers[atPati]).toEqual({ key: 'crags/x/pati.jpg', crag: 'El Pati', author: 'A. Example', license: 'CC BY-SA 4.0' });
    expect(deck.covers[typed].crag).toBe("L'Olla");
    expect(deck.covers[planId]).toBeUndefined();
    // Nowhere near: none. The lookup route takes a point.
    expect((await call(ada, 'GET', `/api/plans/${planId}/pics`)).grigri).toEqual([]);
    const near = await call(ada, 'GET', '/api/pics', undefined, { lat: '41.2570', lon: '0.9300' });
    expect(near.pics.map((p: any) => p.cragId)).toEqual(['osm:n1', 'osm:n2', 'area:siurana']);
    await fails(call(ada, 'GET', '/api/pics', undefined, { lat: 'x' }), 400);
  });

  it('unknown routes and bad ids', async () => {
    await fails(call(ada, 'GET', '/api/nope'), 404);
    await fails(call(ada, 'GET', '/api/plans/bad%20id'), 400);
  });
});

describe('sessions through the API', () => {
  // As handler.ts does: the caller from the headers, unless the route is public.
  async function request(method: string, path: string, headers: Record<string, string> = {}, body?: unknown) {
    const caller = api.access(method, path) === 'public' ? null : await auth.caller(headers);
    return (await api.handle(method, path, { caller, body, query: {} })) as Record<string, any>;
  }

  it('signs in, calls with the token, signs out', async () => {
    await fails(request('GET', '/api/me'), 401, /signed out/);
    const { token, expiresAt } = await request('POST', '/api/session', {}, { idToken: 'a.b.c' });
    expect(token).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(expiresAt).toBe('2031-05-01T10:00:00.000Z');
    const bearer = { authorization: `Bearer ${token}` };
    expect(await request('GET', '/api/me', bearer)).toMatchObject({ climber: { name: 'Ada Example' }, admin: false });
    expect(store.subjects.has('https://accounts.google.com#42')).toBe(true);
    await request('PUT', '/api/me', bearer, profile('Ada'));
    expect(await request('DELETE', '/api/session', bearer)).toEqual({});
    await fails(request('GET', '/api/me', bearer), 401, /signed out/);
  });

  it('signs out everywhere', async () => {
    const a = (await request('POST', '/api/session', {}, { idToken: 'a.b.c' })).token;
    const b = (await request('POST', '/api/session', {}, { idToken: 'a.b.c' })).token;
    expect(await request('DELETE', '/api/sessions', { authorization: `Bearer ${a}` })).toEqual({});
    await fails(request('GET', '/api/me', { authorization: `Bearer ${b}` }), 401);
    expect(store.sessions.size).toBe(0);
  });

  it('health needs no token', async () => {
    expect((await request('GET', '/api/health')).ok).toBe(true);
  });

  it('keeps my climber in the session once known, so requests skip the lookup', async () => {
    const { token } = await request('POST', '/api/session', {}, { idToken: 'a.b.c' });
    const bearer = { authorization: `Bearer ${token}` };
    const id = hashToken(token);
    // No profile yet: looked up on each request, nothing kept.
    await fails(request('GET', '/api/plans', bearer), 409, /no profile/);
    const { climber } = await request('GET', '/api/me', bearer);
    expect(store.sessions.get(id)).not.toHaveProperty('climberId');
    // The next request finds it, and keeps it; later ones don't look it up.
    await request('GET', '/api/plans', bearer);
    expect(store.sessions.get(id)!.climberId).toBe(climber.id);
    const reads = store.subjectReads;
    expect((await request('GET', '/api/me', bearer)).climber.id).toBe(climber.id);
    await request('GET', '/api/plans', bearer);
    expect(store.subjectReads).toBe(reads);
    // A session made later starts with it.
    const second = (await request('POST', '/api/session', {}, { idToken: 'a.b.c' })).token;
    expect(store.sessions.get(hashToken(second))!.climberId).toBe(climber.id);
  });

  it('a kept climber that is gone falls back to the account\'s link', async () => {
    const { token } = await request('POST', '/api/session', {}, { idToken: 'a.b.c' });
    const bearer = { authorization: `Bearer ${token}` };
    const { climber } = await request('GET', '/api/me', bearer);
    // A session whose kept climber no longer exists (made up).
    store.sessions.set(hashToken(token), { ...store.sessions.get(hashToken(token))!, climberId: 'gone-climber-001' });
    expect((await request('GET', '/api/me', bearer)).climber.id).toBe(climber.id);
    expect(store.sessions.get(hashToken(token))!.climberId).toBe(climber.id);
  });

  it('a kept climber never skips the blocked or admin checks', async () => {
    const { token } = await request('POST', '/api/session', {}, { idToken: 'a.b.c' });
    const bearer = { authorization: `Bearer ${token}` };
    await request('GET', '/api/me', bearer);
    await request('GET', '/api/plans', bearer);
    expect(store.sessions.get(hashToken(token))!.climberId).toBeDefined();
    await fails(request('GET', '/api/admin/climbers', bearer), 403, /admins only/);
    rbacr.give('ada@example.com', 'blocked');
    await fails(request('GET', '/api/plans', bearer), 403, /blocked/);
    await fails(request('GET', '/api/me', bearer), 403, /blocked/);
    await fails(request('GET', '/api/admin/climbers', bearer), 403, /blocked/);
    // Signing out still works.
    expect(await request('DELETE', '/api/session', bearer)).toEqual({});
  });

  it('deleting my account leaves no session with my old climber; signing in again starts afresh', async () => {
    const { token } = await request('POST', '/api/session', {}, { idToken: 'a.b.c' });
    const bearer = { authorization: `Bearer ${token}` };
    const { climber } = await request('GET', '/api/me', bearer);
    await request('GET', '/api/plans', bearer);
    await request('DELETE', '/api/me', bearer, { confirm: true });
    expect(store.sessions.size).toBe(0);
    const again = (await request('POST', '/api/session', {}, { idToken: 'a.b.c' })).token;
    expect(store.sessions.get(hashToken(again))).not.toHaveProperty('climberId');
    const fresh = (await request('GET', '/api/me', { authorization: `Bearer ${again}` })).climber;
    expect(fresh.id).not.toBe(climber.id);
  });

  it('asks rbacr about admin only on the routes that need it', async () => {
    const asked: string[] = [];
    const counting = new Auth({
      store: store.asStore(),
      verify: async () => ({ subject: 'https://accounts.google.com#42', email: 'ada@example.com', emailVerified: true }),
      config: { devMode: false, isAdmin: async (email) => (asked.push(email), false) },
      clock: () => now,
    });
    const { token } = await counting.signIn({ idToken: 'a.b.c' });
    const send = async (method: string, path: string, body?: unknown) =>
      api.handle(method, path, { caller: await counting.caller({ authorization: `Bearer ${token}` }), body, query: {} });
    await send('PUT', '/api/me', profile('Ada'));
    await send('GET', '/api/plans');
    await send('GET', '/api/requests');
    expect(asked).toEqual([]);
    await send('GET', '/api/me');
    expect(asked).toEqual(['ada@example.com']);
    await expect(send('GET', '/api/admin/climbers')).rejects.toMatchObject({ status: 403 });
    expect(asked).toEqual(['ada@example.com', 'ada@example.com']);
  });
});

describe('the demo showcase', () => {
  it('is refreshed before the deck, and its failure never fails the deck', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    await call(ada, 'PUT', '/api/me', profile('Ada'));
    const asked: Date[] = [];
    const photos = { presign: async () => ({ url: '', fields: {} }), keep: async () => true, remove: async () => {} };
    const make = (showcase: (now: Date) => Promise<void>) =>
      new Api({ store: store.asStore(), photos, auth, showcase, config: { stage: 'local', version: '0.1.2' }, clock: () => now });
    await make(async (at) => { asked.push(at); }).handle('GET', '/api/discover', { caller: ada, body: undefined, query: {} });
    expect(asked).toEqual([now]);
    const deck = await make(async () => { throw new Error('table busy'); }).handle('GET', '/api/discover', { caller: ada, body: undefined, query: {} });
    expect(deck).toMatchObject({ plans: [] });
  });
});

describe('batched polls (specs/backend.md#what-a-poll-reads)', () => {
  let ids: Record<string, string>;
  let planId: string;
  let other: string;

  beforeEach(async () => {
    ids = {};
    for (const [c, name] of [[ada, 'Ada'], [ben, 'Ben'], [cy, 'Cy']] as const) {
      ids[name] = (await call(c, 'PUT', '/api/me', profile(name))).climber.id;
    }
    planId = (await call(ada, 'POST', '/api/plans', planBody)).plan.id;
    // Ben is in Ada's plan; Cy asks to join it, and Ada's other one.
    await call(ben, 'POST', `/api/plans/${planId}/join`);
    await call(ada, 'POST', `/api/requests/${planId}/${ids.Ben}/accept`);
    await call(cy, 'POST', `/api/plans/${planId}/join`);
    other = (await call(ada, 'POST', '/api/plans', { ...planBody, place: 'Elsewhere' })).plan.id;
    await call(cy, 'POST', `/api/plans/${other}/join`);
  });

  it('GET /api/updates answers what the three routes do, with one read of their climbers', async () => {
    for (const c of [ada, ben, cy]) {
      const plans = await call(c, 'GET', '/api/plans');
      const requests = await call(c, 'GET', '/api/requests');
      const notices = await call(c, 'GET', '/api/notices');
      const before = { ...store.reads };
      const updates = await call(c, 'GET', '/api/updates');
      // One read of the climbers, and of my plans (the requests reuse it).
      expect(store.reads.getClimbers - before.getClimbers).toBe(1);
      expect(store.reads.getPlans - before.getPlans).toBe(1);
      const { climbers: pc, ...plansBody } = plans;
      const { climbers: rc, ...requestsBody } = requests;
      const { climbers: nc, ...noticesBody } = notices;
      expect(updates.plans).toEqual(plansBody);
      expect(updates.requests).toEqual(requestsBody);
      expect(updates.notices).toEqual(noticesBody);
      expect(updates.climbers).toEqual({ ...pc, ...rc, ...nc });
    }
    expect((await call(ada, 'GET', '/api/updates')).requests.requests).toHaveLength(2);
  });

  it('GET /api/requests reads requests only on the plans I decide on, and answers the same', async () => {
    rbacr.give('ada@example.com', 'premium');
    const guided = (await call(ada, 'POST', '/api/plans', { ...planBody, type: 'guided', price: { amount: 45, currency: 'EUR' } })).plan.id;
    const open = (await call(ada, 'POST', '/api/plans', { ...planBody, type: 'open' })).plan.id;
    for (const p of [guided, open]) await call(ben, 'POST', `/api/plans/${p}/join`);
    await call(ada, 'POST', `/api/requests/${guided}/${ids.Ben}/accept`);
    await call(cy, 'POST', `/api/plans/${guided}/join`);
    // Ben: in Ada's private plan (decides), her guided one (doesn't) and her open one (nobody does).
    const before = { ...store.reads };
    const benReview = await call(ben, 'GET', '/api/requests');
    expect(store.reads.planRequests - before.planRequests).toBe(1);
    expect(store.reads.getPlans - before.getPlans).toBe(1);
    expect(store.reads.loadPlan - before.loadPlan).toBe(0);
    expect(benReview.requests.map((r: any) => r.id)).toEqual([`${planId}/${ids.Cy}`]);
    expect(Object.keys(benReview.plans)).toEqual([planId]);
    expect(Object.keys(benReview.climbers).sort()).toEqual([ids.Ada, ids.Ben, ids.Cy].sort());
    // Ada decides on all but the open one: Cy waits on three.
    const adaReview = await call(ada, 'GET', '/api/requests');
    expect(adaReview.requests.map((r: any) => r.planId).sort()).toEqual([planId, other, guided].sort());
  });

  it("a chat's poll for what's new has only its new messages' people; the whole chat has its members' too", async () => {
    const whole = await call(ada, 'GET', `/api/plans/${planId}/messages`);
    expect(Object.keys(whole.climbers).sort()).toEqual([ids.Ada, ids.Ben, ids.Cy].sort());
    const since = now.toISOString();
    now = new Date(now.getTime() + 1000);
    expect((await call(ada, 'GET', `/api/plans/${planId}/messages`, undefined, { after: since })).climbers).toEqual({});
    await call(ben, 'POST', `/api/plans/${planId}/messages`, { text: 'Rope is packed' });
    const fresh = await call(ada, 'GET', `/api/plans/${planId}/messages`, undefined, { after: since });
    expect(fresh.messages.map((m: any) => m.text)).toEqual(['Rope is packed']);
    expect(Object.keys(fresh.climbers)).toEqual([ids.Ben]);
  });

  it('GET /api/chats/messages answers every chat at once, as its own route would', async () => {
    const solo = (await call(ben, 'POST', '/api/plans', { ...planBody, place: 'Solo' })).plan.id;
    const since = now.toISOString();
    now = new Date(now.getTime() + 1000);
    await call(ada, 'POST', `/api/plans/${planId}/messages`, { text: 'See you at nine' });
    const theirs = (await call(cy, 'POST', '/api/plans', { ...planBody, place: 'Not mine' })).plan.id;
    const before = { ...store.reads };
    const both = await call(ben, 'GET', '/api/chats/messages', undefined, { chats: `${planId}~${since},${solo},${theirs},nosuchplan` });
    expect(store.reads.getPlans - before.getPlans).toBe(1);
    expect(store.reads.getPlan - before.getPlan).toBe(0);
    expect(store.reads.getClimbers - before.getClimbers).toBe(1);
    // Not Cy's plan (Ben isn't in it), nor one that isn't there.
    expect(Object.keys(both.chats).sort()).toEqual([planId, solo].sort());
    const one = await call(ben, 'GET', `/api/plans/${planId}/messages`, undefined, { after: since });
    const all = await call(ben, 'GET', `/api/plans/${solo}/messages`);
    expect(both.chats[planId]).toEqual(one.messages);
    expect(both.chats[planId].map((m: any) => m.text)).toEqual(['See you at nine']);
    expect(both.chats[solo]).toEqual(all.messages);
    expect(both.climbers).toEqual({ ...one.climbers, ...all.climbers });
    expect(await call(ben, 'GET', '/api/chats/messages')).toEqual({ chats: {}, climbers: {} });
    await fails(call(ben, 'GET', '/api/chats/messages', undefined, { chats: `${planId}~yesterday` }), 400);
    await fails(call(ben, 'GET', '/api/chats/messages', undefined, { chats: 'bad id!' }), 400);
    await fails(call(ben, 'GET', '/api/chats/messages', undefined, { chats: `${planId}~${since}~x` }), 400);
    const many = Array.from({ length: 51 }, (_, i) => `plan${i}`).join(',');
    await fails(call(ben, 'GET', '/api/chats/messages', undefined, { chats: many }), 400, /at most 50/);
  });

  it('notices: a poll with the stamp it has reads one item while nothing changed', async () => {
    // Older apps send no stamp: every notice, as ever, and no stamp.
    const old = await call(ada, 'GET', '/api/notices');
    expect(old).not.toHaveProperty('stamp');
    expect(old.notices.length).toBeGreaterThan(0);
    const first = await call(ada, 'GET', '/api/notices', undefined, { stamp: '0' });
    expect(first.notices).toEqual(old.notices);
    expect(first.climbers).toEqual(old.climbers);
    expect(first.stamp).toEqual(expect.any(String));
    let reads = store.reads.notices;
    expect(await call(ada, 'GET', '/api/notices', undefined, { stamp: first.stamp })).toEqual({ unchanged: true, stamp: first.stamp, climbers: {} });
    expect((await call(ada, 'GET', '/api/updates', undefined, { notices: first.stamp })).notices).toEqual({ unchanged: true, stamp: first.stamp });
    expect(store.reads.notices).toBe(reads);
    // A new notice: a new stamp, and every notice again.
    await call(cy, 'POST', `/api/plans/${planId}/nudge`);
    const nudged = await call(ada, 'GET', '/api/updates', undefined, { notices: first.stamp });
    expect(nudged.notices.stamp).not.toBe(first.stamp);
    expect(nudged.notices.notices.map((n: any) => n.kind)).toContain('nudge');
    expect(nudged.notices.notices).toEqual((await call(ada, 'GET', '/api/notices')).notices);
    // Marking them read changes it too; marking again (nothing unread) doesn't.
    await call(ada, 'POST', '/api/notices/read');
    const read = await call(ada, 'GET', '/api/notices', undefined, { stamp: nudged.notices.stamp });
    expect(read.notices.every((n: any) => n.read)).toBe(true);
    await call(ada, 'POST', '/api/notices/read');
    await call(ada, 'POST', '/api/team/read');
    reads = store.reads.notices;
    expect((await call(ada, 'GET', '/api/notices', undefined, { stamp: read.stamp })).unchanged).toBe(true);
    expect(store.reads.notices).toBe(reads);
    // Someone else's notice doesn't change mine.
    await call(ada, 'POST', `/api/requests/${planId}/${ids.Cy}/reject`);
    expect((await call(ada, 'GET', '/api/notices', undefined, { stamp: read.stamp })).unchanged).toBe(true);
    expect((await call(cy, 'GET', '/api/notices')).notices[0]).toMatchObject({ kind: 'declined' });
    await fails(call(ada, 'GET', '/api/notices', undefined, { stamp: 'not a stamp!' }), 400);
  });

  it('a first stamp is only kept when no delivery wrote one meanwhile', async () => {
    // Notices from before stamps: none kept for Ben yet.
    store.noticeStamps.delete(ids.Ben!);
    store.startNoticesStamp = async () => undefined;
    const first = await call(ben, 'GET', '/api/notices', undefined, { stamp: '0' });
    expect(first).not.toHaveProperty('stamp');
    expect(first.notices).toEqual((await call(ben, 'GET', '/api/notices')).notices);
  });
});
