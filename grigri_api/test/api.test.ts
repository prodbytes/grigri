import { beforeEach, describe, expect, it } from 'vitest';
import { Api, NO_NAME } from '../src/api.js';
import { Auth, type Caller, subjectHash } from '../src/auth.js';
import { ApiError } from '../src/domain/errors.js';
import { FakeStore } from './fake-store.js';

let now = new Date('2030-05-01T10:00:00.000Z');
let store: FakeStore;
let api: Api;
let auth: Auth;
/** S3 as the fake photos see it: key -> pending tag. */
let objects: Map<string, boolean>;
let removed: string[];

const who = (name: string, admin = false): Caller => ({ subject: `test#${name}`, email: `${name}@example.com`, admin });
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
  const photos = {
    presign: async (key: string) => ({ url: 'https://upload.example.com/', fields: { key: `photos/${key}` } }),
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
  api = new Api({ store: store.asStore(), photos, auth, config: { stage: 'local', version: '0.1.2' }, clock: () => now, random: () => random() });
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
    expect((await call(ada, 'GET', '/api/me')).roles).toBeNull();
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
    await call(ada, 'PUT', '/api/me', profile('Ada'));
    await fails(call(ada, 'GET', '/api/admin/requests'), 403);
    await call(root, 'PUT', '/api/me', profile('Root'));
    expect(await call(root, 'GET', '/api/admin/requests')).toEqual({ requests: [], plans: {}, climbers: {} });
    expect((await call(root, 'GET', '/api/me')).admin).toBe(true);
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

  it('only the organizer edits', async () => {
    await fails(call(ben, 'PUT', `/api/plans/${planId}`, planBody), 403);
    const { plan } = await call(ada, 'PUT', `/api/plans/${planId}`, { ...planBody, place: 'Elsewhere' });
    expect(plan.place).toBe('Elsewhere');
    await fails(call(ada, 'PUT', `/api/plans/${planId}`, { ...planBody, start: '2020-01-01T00:00:00Z' }), 400);
  });

  it('the admin lists every open request and accepts or rejects any', async () => {
    await call(ben, 'POST', `/api/plans/${planId}/join`);
    await call(cy, 'POST', `/api/plans/${planId}/join`);
    const list = await call(root, 'GET', '/api/admin/requests');
    expect(list.requests).toHaveLength(2);
    expect(Object.keys(list.plans)).toEqual([planId]);
    expect((await call(root, 'POST', `/api/admin/requests/${planId}/${ids.Ben}/accept`)).match.newcomerId).toBe(ids.Ben);
    expect(await call(root, 'POST', `/api/admin/requests/${planId}/${ids.Cy}/reject`)).toEqual({});
    expect((await call(root, 'GET', '/api/admin/requests')).requests).toEqual([]);
    await fails(call(ada, 'POST', `/api/admin/requests/${planId}/${ids.Cy}/accept`), 403);
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
});
