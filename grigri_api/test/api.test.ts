import { beforeEach, describe, expect, it } from 'vitest';
import { Api } from '../src/api.js';
import { type Caller, subjectHash } from '../src/auth.js';
import { ApiError } from '../src/domain/errors.js';
import { FakeStore } from './fake-store.js';

let now = new Date('2030-05-01T10:00:00.000Z');
let store: FakeStore;
let api: Api;

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

beforeEach(async () => {
  now = new Date('2030-05-01T10:00:00.000Z');
  store = new FakeStore();
  const photos = { presign: async (key: string) => ({ url: 'https://upload.example.com/', fields: { key: `photos/${key}` } }) };
  api = new Api({ store: store.asStore(), photos, config: { stage: 'local', version: '0.1.2' }, clock: () => now });
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
    expect(await call(ada, 'GET', '/api/me')).toEqual({ climber: null, admin: false });
    await fails(call(ada, 'GET', '/api/discover'), 409, /no profile/);
    await fails(call(ada, 'GET', '/api/plans'), 409, /no profile/);
    const photo = await call(ada, 'POST', '/api/photos', { kind: 'profile', contentType: 'image/jpeg' });
    expect(photo.key).toMatch(new RegExp(`^${subjectHash(ada.subject)}/profile/[A-Za-z0-9_-]{16}\\.jpg$`));
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
    const updated = await call(ada, 'PUT', '/api/me', { ...profile('Ada B'), photo: key });
    expect(updated.climber).toMatchObject({ id: climber.id, name: 'Ada B', photo: key });
    await call(ben, 'PUT', '/api/me', profile('Ben'));
    await fails(call(ben, 'PUT', '/api/me', { ...profile('Ben'), photo: key }), 400, /one of your photos/);
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

    // The organizer leaves: Ben organizes. Everyone leaves: it's gone.
    await call(ada, 'POST', `/api/plans/${planId}/leave`);
    expect((await call(ben, 'GET', `/api/plans/${planId}`)).plan).toMatchObject({ organizerId: ids.Ben, memberIds: [ids.Ben, ids.Cy] });
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
