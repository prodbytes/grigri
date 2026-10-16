import { beforeEach, describe, expect, it } from 'vitest';
import { Api } from '../src/api.js';
import { Auth, type Caller, subjectHash } from '../src/auth.js';
import { ApiError } from '../src/domain/errors.js';
import { MAX_VIEWS } from '../src/domain/walls.js';
import type { Subscription } from '../src/premium.js';
import { FakeStore } from './fake-store.js';

const now = new Date('2030-05-01T10:00:00.000Z');
let store: FakeStore;
let api: Api;
/** S3 as the fake photos see it: key -> pending tag. */
let objects: Map<string, boolean>;
let removed: string[];

const who = (name: string, admin = false): Caller => ({ subject: `test#${name}`, email: `${name}@example.com`, admin });
const ada = who('ada');
const ben = who('ben');
const free = who('free');
const root = who('root', true);

async function call(c: Caller, method: string, path: string, body?: unknown, query: Record<string, string> = {}) {
  return (await api.handle(method, path, { caller: c, body, query })) as Record<string, any>;
}

async function fails(promise: Promise<unknown>, status: number, message?: RegExp) {
  const error = await promise.then(() => undefined, (e: unknown) => e);
  expect(error).toBeInstanceOf(ApiError);
  expect((error as ApiError).status).toBe(status);
  if (message) expect((error as ApiError).message).toMatch(message);
}

/** A wall photo of [c]'s, uploaded. */
async function uploaded(c: Caller): Promise<string> {
  const { key } = await call(c, 'POST', '/api/walls/photo', { contentType: 'image/jpeg' });
  objects.set(key, true);
  return key;
}

const route = { name: 'Made-up Line', grade: { scale: 'routes', grade: 8 }, bolts: [[0.5, 0.9], [0.52, 0.6], [0.55, 0.3]] };

beforeEach(async () => {
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
  const auth = new Auth({
    store: store.asStore(),
    verify: async () => ({ subject: 'x', email: 'x@example.com', emailVerified: true }),
    config: { devMode: false, isAdmin: async () => false },
    clock: () => now,
  });
  api = new Api({
    store: store.asStore(),
    photos,
    auth,
    config: { stage: 'local', version: '0' },
    clock: () => now,
  });
  // Ada and Ben subscribe to Premium; Free doesn't; Root is an admin.
  for (const c of [ada, ben, free, root]) {
    const { climber } = await call(c, 'GET', '/api/me');
    if (c !== ada && c !== ben) continue;
    const sub: Subscription = {
      climberId: climber.id, customerId: 'cus', subscriptionId: `sub_${climber.id}`, status: 'active', plan: 'monthly',
      periodEnd: '2030-06-01T00:00:00.000Z', cancelAtPeriodEnd: false, updatedAt: now.toISOString(),
    };
    await store.putSubscription(sub);
  }
});

describe('the route finder (premium)', () => {
  it('only Premium climbers (and admins) use it', async () => {
    expect((await call(ada, 'GET', '/api/me')).premium.active).toBe(true);
    expect((await call(free, 'GET', '/api/me')).premium.active).toBe(false);
    await fails(call(free, 'GET', '/api/walls', undefined, { lat: '41.26', lon: '0.93' }), 403, /premium/);
    await fails(call(free, 'POST', '/api/walls/photo', { contentType: 'image/jpeg' }), 403);
    expect((await call(root, 'GET', '/api/walls', undefined, { lat: '41.26', lon: '0.93' })).walls).toEqual([]);
  });

  it('a wall from a photo; routes drawn on it, bolt by bolt; found nearby', async () => {
    const key = await uploaded(ada);
    expect(key).toMatch(new RegExp(`^walls/${subjectHash(ada.subject)}/[A-Za-z0-9_-]{16}\\.jpg$`));
    const { wall } = await call(ada, 'POST', '/api/walls', {
      name: 'Made-up Wall', cragId: 'osm:n1', lat: 41.25771234, lon: 0.93181234, view: { key, width: 1600, height: 1200 },
    });
    expect(wall).toMatchObject({ name: 'Made-up Wall', cragId: 'osm:n1', lat: 41.2577, lon: 0.9318, routes: [] });
    expect(wall.views).toEqual([{ key, width: 1600, height: 1200, h: [1, 0, 0, 0, 1, 0, 0, 0, 1], addedBy: expect.any(String), time: now.toISOString() }]);
    expect(objects.get(key)).toBe(false);

    const added = (await call(ben, 'POST', `/api/walls/${wall.id}/routes`, route)).wall;
    expect(added.routes).toEqual([expect.objectContaining({ name: 'Made-up Line', grade: { scale: 'routes', grade: 8 }, bolts: route.bolts })]);

    // 2 km away: here. 10 km away: not.
    const near = await call(ben, 'GET', '/api/walls', undefined, { lat: '41.27', lon: '0.94' });
    expect(near.walls.map((w: any) => w.id)).toEqual([wall.id]);
    expect(Object.keys(near.climbers).length).toBe(2);
    expect((await call(ben, 'GET', '/api/walls', undefined, { lat: '41.35', lon: '0.93' })).walls).toEqual([]);
    await fails(call(ben, 'GET', '/api/walls'), 400);

    // Only whoever drew a route deletes it (or an admin).
    const routeId = added.routes[0].id;
    await fails(call(ada, 'DELETE', `/api/walls/${wall.id}/routes/${routeId}`), 403);
    expect((await call(ben, 'DELETE', `/api/walls/${wall.id}/routes/${routeId}`)).wall.routes).toEqual([]);
    await fails(call(ben, 'DELETE', `/api/walls/${wall.id}/routes/${routeId}`), 404);
  });

  it('refuses bad input: photos not mine or not uploaded, bad bolts and grades', async () => {
    const key = await uploaded(ada);
    const body = { name: 'W', lat: 41.2, lon: 0.9, view: { key, width: 1600, height: 1200 } };
    await fails(call(ben, 'POST', '/api/walls', body), 400, /yours/);
    const pending = (await call(ada, 'POST', '/api/walls/photo', { contentType: 'image/png' })).key;
    await fails(call(ada, 'POST', '/api/walls', { ...body, view: { ...body.view, key: pending } }), 400, /uploaded/);
    await fails(call(ada, 'POST', '/api/walls', { ...body, lat: undefined }), 400, /lat/);
    const { wall } = await call(ada, 'POST', '/api/walls', body);
    const path = `/api/walls/${wall.id}/routes`;
    await fails(call(ada, 'POST', path, { ...route, bolts: [[0.5, 0.5]] }), 400, /bolts/);
    await fails(call(ada, 'POST', path, { ...route, bolts: [[0.5, 1.5], [0.5, 0.2]] }), 400, /0–1/);
    await fails(call(ada, 'POST', path, { ...route, grade: { scale: 'boulders', grade: 15 } }), 400, /0–14/);
    await fails(call(ada, 'POST', path, { ...route, name: ' ' }), 400);
    await fails(call(ada, 'POST', '/api/walls/nope/routes', route), 404);
  });

  it('learns views: each confirmed sighting is a view; past the cap the oldest learned one goes', async () => {
    const first = await uploaded(ada);
    const { wall } = await call(ada, 'POST', '/api/walls', { name: 'W', lat: 41.2, lon: 0.9, view: { key: first, width: 1600, height: 1200 } });
    const h = [2, 0.1, 10, 0, 2, 4, 0, 0, 2];
    const keys: string[] = [];
    for (let i = 0; i < MAX_VIEWS; i++) {
      const key = await uploaded(ben);
      keys.push(key);
      const out = await call(ben, 'POST', `/api/walls/${wall.id}/views`, { key, width: 960, height: 720, h });
      expect(out.wall.views.at(-1)).toMatchObject({ key, h: [1, 0.05, 5, 0, 1, 2, 0, 0, 1] });
    }
    const after = (await store.getWall(wall.id))!.wall;
    expect(after.views).toHaveLength(MAX_VIEWS);
    // The first view stays (routes are drawn on it); the oldest learned one went, and its photo.
    expect(after.views[0]!.key).toBe(first);
    expect(after.views[1]!.key).toBe(keys[1]);
    expect(removed).toEqual([keys[0]]);
    await fails(call(ben, 'POST', `/api/walls/${wall.id}/views`, { key: await uploaded(ben), width: 960, height: 720, h: [1, 2, 3] }), 400, /9 numbers/);
  });
});
