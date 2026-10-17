import { beforeEach, describe, expect, it } from 'vitest';
import { Api } from '../src/api.js';
import { Auth, type Caller } from '../src/auth.js';
import { type AdRegion, adInput, adLink, adReaches, adRegions, adSettingsInput, regionCovers } from '../src/domain/ads.js';
import type { Place } from '../src/places.js';
import { ApiError } from '../src/domain/errors.js';
import { seedAds, seedAdvertiser } from '../seed/ads.js';
import { FakeRbacr } from './fake-rbacr.js';
import { FakeStore } from './fake-store.js';

let now = new Date('2030-05-01T10:00:00.000Z');
let store: FakeStore;
let api: Api;
/** S3 as the fake photos see it: key -> pending. */
let objects: Map<string, boolean>;
let removed: string[];

const who = (name: string, admin = false): Caller => ({ subject: `test#${name}`, email: `${name}@example.com`, admin });
const ada = who('ada');
const ben = who('ben');
const root = who('root', true);

const call = async (c: Caller, method: string, path: string, body?: unknown, query: Record<string, string> = {}) =>
  (await api.handle(method, path, { caller: c, body, query })) as Record<string, any>;
const status = (p: Promise<unknown>) => p.then(() => 200, (e: unknown) => (e as ApiError).status);

/** Makes the caller's profile; Premium unless `premium` is false. */
async function climber(c: Caller, premium = true): Promise<string> {
  if (premium) rbacr.give(c.email!, 'premium', '2030-06-03T00:00:00.000Z');
  const { climber: me } = await call(c, 'GET', '/api/me');
  return me.id as string;
}

const plan = {
  discipline: 'sport', place: 'Somewhere', area: 'Nowhere', start: '2030-05-10T08:00:00Z', end: '2030-05-10T14:00:00Z',
  grades: { scale: 'routes', min: 6, max: 10 }, notes: '',
};

let rbacr: FakeRbacr;
let searches: string[];

// Made-up points: a village by Siurana's crags, two nearby towns, and further away.
const CORNUDELLA = { name: 'Cornudella de Montsant', lat: 41.2633, lon: 0.9056 };
const TARRAGONA = { lat: 41.1189, lon: 1.2445 };
const MADRID = { lat: 40.4168, lon: -3.7038 };
const SIURANA: AdRegion = { name: 'Siurana, España', south: 41.2383112, west: 0.9125259, north: 41.2783112, east: 0.9525259 };
const SPAIN: AdRegion = { name: 'España', south: 27.4335426, west: -18.3936845, north: 43.9933088, east: 4.5918885 };

/** Puts a climber at a point (their profile's private location). */
function placeAt(id: string, at: { lat: number; lon: number }) {
  const c = store.climbers.get(id)!;
  store.climbers.set(id, { ...c, location: { name: 'Here', ...at } });
}

beforeEach(() => {
  now = new Date('2030-05-01T10:00:00.000Z');
  rbacr = new FakeRbacr(() => now);
  rbacr.give('root@example.com', 'admin');
  store = new FakeStore();
  objects = new Map();
  removed = [];
  const photos = {
    presign: async (key: string) => {
      objects.set(key, true);
      return { url: 'https://upload.example.com/', fields: {} };
    },
    keep: async (key: string) => {
      if (!objects.has(key)) return false;
      objects.set(key, false);
      return true;
    },
    remove: async (keys: string[]) => {
      removed.push(...keys);
    },
  };
  const auth = new Auth({ store: store.asStore(), verify: async () => { throw new Error('unused'); }, config: { devMode: false, isAdmin: async () => false }, clock: () => now });
  searches = [];
  const places = async (q: string, lang: string): Promise<Place[]> => {
    searches.push(`${q}|${lang}`);
    return [{ ...SIURANA, label: 'Siurana, Cornudella de Montsant, Priorat, Tarragona, Catalunya, España' }];
  };
  api = new Api({ store: store.asStore(), photos, auth, roles: rbacr.lookup, grants: rbacr.api, places, config: { stage: 'local', version: 'test' }, clock: () => now });
});

describe('ad input', () => {
  it('takes text, an http(s) link and my own uploaded media', () => {
    expect(adInput({ text: '  Rope sale  ', link: 'https://shop.example.com/ropes' }, 'c1')).toEqual({ text: 'Rope sale', link: 'https://shop.example.com/ropes' });
    expect(adInput({ link: 'https://example.com', media: { key: 'ads/c1/AAAAAAAAAAAAAAAA.mp4' } }, 'c1').media).toEqual({ kind: 'video', key: 'ads/c1/AAAAAAAAAAAAAAAA.mp4' });
    expect(() => adInput({ link: 'https://example.com', media: { key: 'ads/c2/AAAAAAAAAAAAAAAA.jpg' } }, 'c1')).toThrow(/media.key/);
    expect(() => adInput({ link: 'https://example.com' }, 'c1')).toThrow(/needs text/);
    expect(() => adInput({ text: 'x'.repeat(201), link: 'https://example.com' }, 'c1')).toThrow(/200/);
  });

  it('takes up to 10 named regions with boxes', () => {
    expect(adInput({ text: 'x', link: 'https://example.com', regions: [SIURANA] }, 'c1').regions).toEqual([SIURANA]);
    expect(adInput({ text: 'x', link: 'https://example.com', regions: [] }, 'c1')).not.toHaveProperty('regions');
    expect(() => adRegions('Spain')).toThrow(/list/);
    expect(() => adRegions(Array(11).fill(SIURANA))).toThrow(/10/);
    expect(() => adRegions([{ ...SIURANA, name: ' ' }])).toThrow(/name/);
    expect(() => adRegions([{ ...SIURANA, north: 91 }])).toThrow(/north/);
    expect(() => adRegions([{ ...SIURANA, west: '0' }])).toThrow(/west/);
    expect(() => adRegions([{ ...SIURANA, south: 42 }])).toThrow(/south/);
  });

  it('a region reaches a bit past its box: a town about 50 km, a country past its borders', () => {
    expect(regionCovers(SIURANA, CORNUDELLA)).toBe(true);
    expect(regionCovers(SIURANA, TARRAGONA)).toBe(true);
    expect(regionCovers(SIURANA, { lat: 41.3874, lon: 2.1686 })).toBe(false); // Barcelona, ~100 km
    expect(regionCovers(SIURANA, MADRID)).toBe(false);
    expect(regionCovers(SPAIN, MADRID)).toBe(true);
    expect(regionCovers(SPAIN, { lat: 42.6887, lon: 2.8948 })).toBe(true); // Perpignan, just over the border
    expect(regionCovers(SPAIN, { lat: 48.8566, lon: 2.3522 })).toBe(false); // Paris
    // Across the antimeridian (Fiji's box runs from 177°E to 178°W).
    const fiji: AdRegion = { name: 'Fiji', south: -21, west: 177, north: -12, east: -178 };
    expect(regionCovers(fiji, { lat: -17.8, lon: 179.9 })).toBe(true);
    expect(regionCovers(fiji, { lat: -17.8, lon: -179.5 })).toBe(true);
    expect(regionCovers(fiji, { lat: -17.8, lon: 160 })).toBe(false);
  });

  it('an ad without regions reaches everyone; with them, only climbers in one', () => {
    expect(adReaches({}, [])).toBe(true);
    expect(adReaches({ regions: [SIURANA] }, [])).toBe(false);
    expect(adReaches({ regions: [SPAIN, SIURANA] }, [MADRID])).toBe(true);
    expect(adReaches({ regions: [SIURANA] }, [MADRID, CORNUDELLA])).toBe(true);
  });

  it('links must be web addresses', () => {
    expect(adLink('http://example.com/a?b=c')).toBe('http://example.com/a?b=c');
    for (const bad of ['', 'example.com', 'javascript:alert(1)', 'ftp://example.com', 'https://localhost', 'https://user:pw@example.com', `https://example.com/${'a'.repeat(500)}`]) {
      expect(() => adLink(bad), bad).toThrow();
    }
  });

  it('settings: a whole number from 0 to 50', () => {
    expect(adSettingsInput({ every: 0 })).toEqual({ every: 0 });
    expect(adSettingsInput({ every: 7 })).toEqual({ every: 7 });
    for (const every of [-1, 51, 2.5, '5', null]) expect(() => adSettingsInput({ every })).toThrow();
  });
});

describe('ads', () => {
  it('only Premium climbers add ads; they wait for an admin', async () => {
    await climber(ben, false);
    expect(await status(call(ben, 'POST', '/api/ads', { text: 'Hi', link: 'https://example.com' }))).toBe(403);
    expect(await status(call(ben, 'POST', '/api/ads/media', { contentType: 'image/jpeg' }))).toBe(403);
    expect((await call(ben, 'GET', '/api/ads')).premium).toBe(false);

    const adaId = await climber(ada);
    const upload = await call(ada, 'POST', '/api/ads/media', { contentType: 'video/mp4' });
    expect(upload.key).toMatch(new RegExp(`^ads/${adaId}/[A-Za-z0-9_-]{16}\\.mp4$`));
    expect(upload.maxBytes).toBe(50 * 1024 * 1024);
    const { ad } = await call(ada, 'POST', '/api/ads', { text: 'New crag guide', link: 'https://guide.example.com', media: { key: upload.key } });
    expect(ad).toMatchObject({ ownerId: adaId, status: 'pending', media: { kind: 'video', key: upload.key } });
    expect(objects.get(upload.key)).toBe(false);
    const mine = await call(ada, 'GET', '/api/ads');
    expect(mine.premium).toBe(true);
    expect(mine.ads.map((a: { id: string }) => a.id)).toEqual([ad.id]);

    // Media not uploaded: refused.
    expect(await status(call(ada, 'POST', '/api/ads', { link: 'https://example.com', media: { key: `ads/${adaId}/BBBBBBBBBBBBBBBB.jpg` } }))).toBe(400);
  });

  it('admins approve or reject, and set how often the deck shows ads', async () => {
    await climber(ada);
    await climber(ben, false);
    await call(root, 'GET', '/api/me');
    const { ad } = await call(ada, 'POST', '/api/ads', { text: 'Chalk', link: 'https://chalk.example.com' });
    expect(await status(call(ada, 'GET', '/api/admin/ads'))).toBe(403);
    const pending = await call(root, 'GET', '/api/admin/ads');
    expect(pending.ads.map((a: { id: string }) => a.id)).toEqual([ad.id]);
    expect(Object.keys(pending.climbers)).toEqual([ad.ownerId]);
    expect(pending.every).toBe(10);

    // Pending ads never reach a deck.
    expect((await call(ben, 'GET', '/api/discover')).ads).toEqual([]);
    now = new Date('2030-05-01T11:00:00.000Z');
    expect((await call(root, 'POST', `/api/admin/ads/${ad.id}/approve`)).ad).toMatchObject({ status: 'approved', reviewedAt: now.toISOString() });
    expect((await call(root, 'GET', '/api/admin/ads')).ads).toEqual([]);
    expect((await call(root, 'GET', '/api/admin/ads', undefined, { status: 'approved' })).ads).toHaveLength(1);
    expect(await status(call(root, 'GET', '/api/admin/ads', undefined, { status: 'nope' }))).toBe(400);

    const deck = await call(ben, 'GET', '/api/discover');
    expect(deck.ads.map((a: { id: string }) => a.id)).toEqual([ad.id]);
    expect(deck.adEvery).toBe(10);
    expect(deck.climbers[ad.ownerId].name).toBeDefined();
    // Never my own.
    expect((await call(ada, 'GET', '/api/discover')).ads).toEqual([]);

    expect(await call(root, 'PUT', '/api/admin/ads/settings', { every: 2 })).toEqual({ every: 2 });
    expect((await call(ben, 'GET', '/api/discover')).adEvery).toBe(2);
    await call(root, 'PUT', '/api/admin/ads/settings', { every: 0 });
    expect((await call(ben, 'GET', '/api/discover')).ads).toEqual([]);
    await call(root, 'PUT', '/api/admin/ads/settings', { every: 3 });

    await call(root, 'POST', `/api/admin/ads/${ad.id}/reject`);
    expect((await call(ben, 'GET', '/api/discover')).ads).toEqual([]);
  });

  it('an ad leaves decks when its owner stops being Premium or is blocked', async () => {
    const adaId = await climber(ada);
    await climber(ben, false);
    await call(root, 'GET', '/api/me');
    const { ad } = await call(ada, 'POST', '/api/ads', { text: 'Gear swap', link: 'https://swap.example.com' });
    await call(root, 'POST', `/api/admin/ads/${ad.id}/approve`);
    await call(ben, 'POST', '/api/plans', plan);
    expect((await call(ben, 'GET', '/api/discover')).ads).toHaveLength(1);

    // Her Premium ends in rbacr: her ad leaves the decks; back, it's back.
    rbacr.grants.get('ada@example.com')!.delete('premium');
    expect((await call(ben, 'GET', '/api/discover')).ads).toEqual([]);
    rbacr.give('ada@example.com', 'premium');
    expect((await call(ben, 'GET', '/api/discover')).ads).toHaveLength(1);
    await call(root, 'POST', `/api/admin/climbers/${adaId}/block`);
    expect((await call(ben, 'GET', '/api/discover')).ads).toEqual([]);
  });

  it('an ad I skip never shows to me again; others still see it', async () => {
    await climber(ada);
    await climber(ben, false);
    await climber(who('cy'), false);
    await call(root, 'GET', '/api/me');
    const { ad } = await call(ada, 'POST', '/api/ads', { text: 'Rope sale', link: 'https://rope.example.com' });
    await call(root, 'POST', `/api/admin/ads/${ad.id}/approve`);
    expect((await call(ben, 'GET', '/api/discover')).ads).toHaveLength(1);
    expect(await call(ben, 'POST', `/api/ads/${ad.id}/skip`)).toEqual({});
    expect((await call(ben, 'GET', '/api/discover')).ads).toEqual([]);
    // Not even after refreshing the deck (which brings passed plans back).
    await call(ben, 'DELETE', '/api/passes');
    expect((await call(ben, 'GET', '/api/discover')).ads).toEqual([]);
    expect((await call(who('cy'), 'GET', '/api/discover')).ads).toHaveLength(1);
    expect(await status(call(ben, 'POST', '/api/ads/bad id!/skip'))).toBe(400);
  });

  it("the seed's made-up advertiser shows ads without Premium", async () => {
    placeAt(await climber(ben, false), CORNUDELLA);
    await store.saveProfile({ ...seedAdvertiser, demo: true });
    for (const { ad } of seedAds(now)) await store.putAd(ad);
    expect((await call(ben, 'GET', '/api/discover')).ads).toHaveLength(seedAds(now).length);
    // A real climber without Premium doesn't.
    await store.saveProfile({ ...seedAdvertiser, demo: undefined } as never);
    expect((await call(ben, 'GET', '/api/discover')).ads).toEqual([]);
  });

  it('owners (or admins) delete ads, with their media', async () => {
    const adaId = await climber(ada);
    await climber(ben);
    const upload = await call(ada, 'POST', '/api/ads/media', { contentType: 'image/png' });
    const { ad } = await call(ada, 'POST', '/api/ads', { link: 'https://example.com', media: { key: upload.key } });
    expect(await status(call(ben, 'DELETE', `/api/ads/${ad.id}`))).toBe(403);
    await call(ada, 'DELETE', `/api/ads/${ad.id}`);
    expect(removed).toEqual([upload.key]);
    expect((await call(ada, 'GET', '/api/ads')).ads).toEqual([]);
    expect(await status(call(ada, 'DELETE', `/api/ads/${ad.id}`))).toBe(404);
    expect(adaId).toBeTruthy();
  });

  it('a climber keeps at most 20 ads', async () => {
    await climber(ada);
    for (let i = 0; i < 20; i++) await call(ada, 'POST', '/api/ads', { text: `Ad ${i}`, link: 'https://example.com' });
    expect(await status(call(ada, 'POST', '/api/ads', { text: 'One more', link: 'https://example.com' }))).toBe(409);
  });

  it('region-limited ads show to climbers there, or with an area there', async () => {
    await climber(ada);
    const benId = await climber(ben);
    const { ad } = await call(ada, 'POST', '/api/ads', { text: 'Guided days', link: 'https://example.com', regions: [SIURANA] });
    expect(ad.regions).toEqual([SIURANA]);
    await climber(root, false);
    await call(root, 'POST', `/api/admin/ads/${ad.id}/approve`);
    // Nowhere known: only ads for everywhere.
    expect((await call(ben, 'GET', '/api/discover')).ads).toEqual([]);
    placeAt(benId, MADRID);
    expect((await call(ben, 'GET', '/api/discover')).ads).toEqual([]);
    placeAt(benId, TARRAGONA);
    expect((await call(ben, 'GET', '/api/discover')).ads.map((a: { id: string }) => a.id)).toEqual([ad.id]);
    // From Madrid, with an area by Siurana.
    store.climbers.set(benId, { ...store.climbers.get(benId)!, location: { name: 'Madrid', ...MADRID }, areas: [CORNUDELLA] });
    expect((await call(ben, 'GET', '/api/discover')).ads).toHaveLength(1);
  });

  it('Premium climbers search places for regions', async () => {
    await climber(ada);
    await climber(ben, false);
    const { places } = await call(ada, 'GET', '/api/places', undefined, { q: ' Siurana ', lang: 'es' });
    expect(places[0].name).toBe('Siurana, España');
    expect(searches).toEqual(['Siurana|es']);
    expect(await status(call(ada, 'GET', '/api/places', undefined, { q: 'S' }))).toBe(400);
    expect(await status(call(ben, 'GET', '/api/places', undefined, { q: 'Siurana' }))).toBe(403);
    expect(searches).toHaveLength(1);
  });
});
