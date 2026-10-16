import { describe, expect, it } from 'vitest';
import { planInput, profileInput } from '../src/domain/validate.js';
import { seedData } from '../seed/data.js';
import { assertSeedable } from '../seed/seed.js';
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
