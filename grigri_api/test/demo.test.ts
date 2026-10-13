import { describe, expect, it } from 'vitest';
import { publicClimber } from '../src/domain/model.js';
import { profileInput, planInput } from '../src/domain/validate.js';
import { climberItem, planItem, toClimber, toPlan } from '../src/store/store.js';
import { seedData } from '../seed/data.js';

const now = new Date('2030-05-01T10:00:00Z');

describe('demo data', () => {
  it('a demo profile and plan keep the mark through the table, and others see it', () => {
    const [climber] = seedData(now).climbers;
    const [plan] = seedData(now).plans;
    const c = toClimber(climberItem({ ...climber!, demo: true }, undefined, now));
    expect(c.demo).toBe(true);
    expect(publicClimber(c).demo).toBe(true);
    expect(toPlan(planItem({ ...plan!, demo: true }, 1)).demo).toBe(true);
    // Unmarked stays unmarked (no attribute at all).
    expect(climberItem(climber!, undefined, now)).not.toHaveProperty('demo');
    expect(toClimber(climberItem(climber!, undefined, now))).not.toHaveProperty('demo');
    expect(toPlan(planItem(plan!, 1))).not.toHaveProperty('demo');
  });

  it("can't be set through the API's input", () => {
    const profile = profileInput({ name: 'Ada', bio: '', levels: {}, gear: [], demo: true }, ['me']);
    expect(profile).not.toHaveProperty('demo');
    const plan = planInput(
      {
        discipline: 'sport',
        place: 'Somewhere',
        area: 'Nowhere',
        start: '2030-05-10T08:00:00Z',
        end: '2030-05-10T14:00:00Z',
        grades: { scale: 'routes', min: 6, max: 10 },
        notes: '',
        demo: true,
      },
      now,
    );
    expect(plan).not.toHaveProperty('demo');
  });
});
