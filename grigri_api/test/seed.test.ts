import { afterEach, describe, expect, it, vi } from 'vitest';
import { planInput, profileInput } from '../src/domain/validate.js';
import { seedData } from '../seed/data.js';
import { SEED_ADVERTISER, seedAds, seedAdvertiser } from '../seed/ads.js';
import { adLink, MAX_AD_TEXT } from '../src/domain/ads.js';
import { assertSeedable, writeAds } from '../seed/seed.js';
import type { Store } from '../src/store/store.js';
import { FakeStore } from './fake-store.js';
import { showcaseData } from '../seed/showcase.js';

describe('seed data', () => {
  const now = new Date('2030-05-01T10:00:00.000Z');
  const data = seedData(now);

  it('only seed- ids', () => {
    for (const c of data.climbers) expect(c.id).toMatch(/^seed-/);
    for (const p of data.plans) expect(p.id).toMatch(/^seed-/);
    for (const m of data.messages) expect(m.id).toMatch(/^seed-/);
  });

  it('passes the same validation as real input, with upcoming dates', () => {
    for (const { id: _id, ...c } of data.climbers) expect(() => profileInput(c, [])).not.toThrow();
    for (const { id: _id, organizerId: _o, memberIds: _m, ...p } of data.plans) {
      expect(() => planInput(p, now)).not.toThrow();
      expect(planInput(p, now)).toEqual(p);
    }
  });

  it('references only seed climbers and plans, with open requests', () => {
    const climbers = new Set(data.climbers.map((c) => c.id));
    const plans = new Map(data.plans.map((p) => [p.id, p]));
    for (const p of data.plans) for (const m of p.memberIds) expect(climbers.has(m)).toBe(true);
    for (const r of data.requests) {
      const plan = plans.get(r.planId)!;
      expect(plan.memberIds).not.toContain(r.climberId);
      // Not already accepted by everyone (nobody answers automatically).
      expect(plan.memberIds.every((m) => r.acceptedBy.includes(m))).toBe(false);
    }
  });
});

describe('seed ads', () => {
  const now = new Date('2030-05-01T10:00:00.000Z');
  const ads = seedAds(now);

  it("Climbing Siurana's: approved, valid, photos under the advertiser's folder", () => {
    expect(seedAdvertiser.id).toBe(SEED_ADVERTISER);
    expect(() => profileInput({ ...seedAdvertiser, id: undefined }, [])).not.toThrow();
    expect(ads.length).toBeGreaterThanOrEqual(3);
    for (const { ad, photoSource } of ads) {
      expect(ad.id).toMatch(/^seed-/);
      expect(ad.ownerId).toBe(SEED_ADVERTISER);
      expect(ad.status).toBe('approved');
      expect(ad.text.length).toBeLessThanOrEqual(MAX_AD_TEXT);
      expect(adLink(ad.link)).toBe(ad.link);
      expect(new URL(ad.link).host).toBe('www.climbingsiurana.com');
      expect(ad.media?.key).toMatch(new RegExp(`^ads/${SEED_ADVERTISER}/[a-z-]+\\.(jpg|webp)$`));
      expect(photoSource).toMatch(/^https:\/\/www\.climbingsiurana\.com\//);
      // Plans, not partners.
      expect(ad.text).not.toMatch(/partner/i);
    }
  });
});

describe('sample ads, written with the showcase', () => {
  afterEach(() => vi.unstubAllGlobals());
  const photo = () => new Response(new Uint8Array([1, 2, 3]), { headers: { 'content-type': 'image/jpeg' } });

  it('copies each photo once, and keeps an ad\'s status and dates', async () => {
    const store = new FakeStore();
    const fetch = vi.fn(async () => photo());
    vi.stubGlobal('fetch', fetch);
    const put: string[] = [];
    const putPhoto = async (key: string) => { put.push(key); };
    const first = new Date('2030-05-01T10:00:00.000Z');
    const ads = seedAds(first);
    await writeAds(store as unknown as Store, ads, putPhoto);
    expect([...store.ads.values()].every((a) => a.status === 'approved' && a.media)).toBe(true);
    expect(put).toHaveLength(ads.length);

    // An admin rejects one; the showcase runs again later.
    const rejected = ads[0]!.ad.id;
    store.ads.set(rejected, { ...store.ads.get(rejected)!, status: 'rejected' });
    await writeAds(store as unknown as Store, seedAds(new Date('2030-05-02T10:00:00.000Z')), putPhoto);
    expect(fetch).toHaveBeenCalledTimes(ads.length);
    expect(store.ads.get(rejected)!.status).toBe('rejected');
    for (const a of store.ads.values()) expect(a.createdAt).toBe(first.toISOString());
  });

  it('saves an ad without its photo when the copy fails, and tries again next time', async () => {
    const store = new FakeStore();
    vi.stubGlobal('fetch', vi.fn(async () => new Response('', { status: 404 })));
    const ads = seedAds(new Date('2030-05-01T10:00:00.000Z'));
    await writeAds(store as unknown as Store, ads, async () => {});
    expect([...store.ads.values()].every((a) => a.media === undefined)).toBe(true);
    vi.stubGlobal('fetch', vi.fn(async () => photo()));
    await writeAds(store as unknown as Store, ads, async () => {});
    expect([...store.ads.values()].every((a) => a.media !== undefined)).toBe(true);
  });
});

describe('demo showcase', () => {
  const now = new Date('2030-05-01T10:00:00.000Z');
  const data = showcaseData(now);

  it('seed- ids apart from the test seed\'s, organizers in their plans', () => {
    const test = new Set([...seedData(now).climbers, ...seedData(now).plans].map((x) => x.id));
    const climbers = new Set(data.climbers.map((c) => c.id));
    for (const x of [...data.climbers, ...data.plans]) {
      expect(x.id).toMatch(/^seed-/);
      expect(test.has(x.id)).toBe(false);
    }
    for (const p of data.plans) {
      expect(p.memberIds[0]).toBe(p.organizerId);
      for (const m of p.memberIds) expect(climbers.has(m)).toBe(true);
    }
    // Every showcase climber organizes something.
    for (const c of data.climbers) expect(data.plans.some((p) => p.organizerId === c.id)).toBe(true);
  });

  it('has plenty of plans in Siurana and in Margalef, all with a point', () => {
    for (const place of ['Siurana', 'Margalef']) {
      const there = data.plans.filter((p) => `${p.place} ${p.area}`.includes(place));
      expect(there.length).toBeGreaterThanOrEqual(6);
      for (const p of there) expect(p.lat !== undefined && p.lon !== undefined).toBe(true);
    }
  });

  it('passes the same validation as real input, upcoming within a week', () => {
    for (const { id: _id, ...c } of data.climbers) expect(() => profileInput(c, [])).not.toThrow();
    for (const { id: _id, organizerId: _o, memberIds: _m, ...p } of data.plans) {
      expect(planInput(p, now)).toEqual(p);
      expect(Date.parse(p.start!) - now.getTime()).toBeGreaterThan(0);
      expect(Date.parse(p.start!) - now.getTime()).toBeLessThan(8 * 86_400_000);
    }
  });
});

describe('assertSeedable', () => {
  it('refuses prod by stage and by table', () => {
    expect(() => assertSeedable('prod', 'grigri-api')).toThrow(/stage 'prod'/);
    expect(() => assertSeedable('rc', 'grigri-api')).toThrow(/table 'grigri-api'/);
    expect(() => assertSeedable('local', 'something-else')).toThrow(/table/);
    expect(() => assertSeedable('rc', 'grigri-rc-api')).not.toThrow();
    expect(() => assertSeedable('local', 'grigri-local-api')).not.toThrow();
  });
});
