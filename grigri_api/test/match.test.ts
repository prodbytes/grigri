import { describe, expect, it } from 'vitest';
import { Api } from '../src/api.js';
import type { Caller } from '../src/auth.js';
import type { Climber, JoinRequest, Plan } from '../src/domain/model.js';
import { MATCH_MODEL, type MatchScorer, aityxScorer, parseAnswers, pooled } from '../src/match/aityx.js';
import { matchFacts } from '../src/match/facts.js';
import { openByPlan, othersWaiting, scoreAll } from '../src/match/run.js';
import type { ScoreRun, ScoredPair } from '../src/store/scores.js';
import { scoreItem } from '../src/store/scores.js';
import { FakeStore } from './fake-store.js';

const now = new Date('2030-05-01T10:00:00.000Z');

const climber = (id: string, extra: Partial<Climber> = {}): Climber => ({
  id,
  name: id,
  bio: '',
  levels: { sport: { scale: 'routes', min: 6, max: 10 } },
  gear: [],
  gearPhotos: [],
  location: { name: 'Home', lat: 41.0, lon: 1.0 },
  ...extra,
});

const plan = (id: string, extra: Partial<Plan> = {}): Plan => ({
  id,
  organizerId: 'org',
  discipline: 'sport',
  place: 'Crag',
  area: '',
  lat: 41.0,
  lon: 1.0,
  start: '2030-05-03T10:00:00.000Z',
  end: '2030-05-03T16:00:00.000Z',
  grades: { scale: 'routes', min: 8, max: 9 },
  memberIds: ['org'],
  notes: '',
  ...extra,
});

const answers = (score: number, level = 'good', reason = 'in_grades') => ({
  match_likelihood: { type: 'number', number: score },
  match_level: { type: 'score', score: 0.66, level },
  match_reason: { type: 'choice', choice: reason },
});

describe('matchFacts', () => {
  it('in grades, on the doorstep, a group of one, two days out', () => {
    expect(matchFacts(climber('a'), plan('p'), 0, now)).toEqual({
      discipline_climbed: true,
      grades_short: 0,
      grades_over: 0,
      distance_known: true,
      distance_km: 0,
      group_size: 1,
      open_requests: 0,
      days_until_start: 2,
    });
  });

  it('an undated plan is a month away', () => {
    expect(matchFacts(climber('a'), plan('p', { start: undefined, end: undefined }), 0, now).days_until_start).toBe(30);
  });

  it('grades short or over, by how many', () => {
    expect(matchFacts(climber('a'), plan('p', { grades: { scale: 'routes', min: 13, max: 15 } }), 0, now)).toMatchObject({ grades_short: 3, grades_over: 0 });
    expect(matchFacts(climber('a'), plan('p', { grades: { scale: 'routes', min: 1, max: 4 } }), 0, now)).toMatchObject({ grades_short: 0, grades_over: 2 });
  });

  it("a discipline I don't climb, an unknown distance, a past start", () => {
    const facts = matchFacts(
      climber('a', { location: undefined, areas: [] }),
      plan('p', { discipline: 'bouldering', grades: { scale: 'boulders', min: 2, max: 4 }, start: '2030-04-30T10:00:00.000Z', memberIds: ['org', 'b', 'c'] }),
      4,
      now,
    );
    expect(facts).toMatchObject({
      discipline_climbed: false,
      grades_short: 0,
      grades_over: 0,
      distance_known: false,
      distance_km: 0,
      group_size: 3,
      open_requests: 4,
      days_until_start: 0,
    });
  });
});

describe('the model', () => {
  it('declares every input matchFacts sends, and the answers parseAnswers reads', () => {
    const facts = matchFacts(climber('a'), plan('p'), 0, now);
    expect(Object.keys(MATCH_MODEL.inputs).sort()).toEqual(Object.keys(facts).sort());
    expect(Object.keys(MATCH_MODEL.decisions)).toEqual(expect.arrayContaining(['match_likelihood', 'match_level', 'match_reason']));
  });

  it('has a type, a description, and a reason on every table row (strict mode)', () => {
    for (const [name, d] of Object.entries(MATCH_MODEL.decisions) as [string, Record<string, unknown>][]) {
      expect(d.type, name).toBeTypeOf('string');
      expect(d.desc, name).toBeTypeOf('string');
      const table = d.table as string[][] | undefined;
      if (!table) continue;
      expect(table[0]!.at(-1), name).toBe('# why');
      for (const row of table.slice(1)) expect(row.at(-1)!.length, `${name}: ${row}`).toBeGreaterThan(10);
      // The last row is the else row: any value in every input cell.
      const inputs = table[0]!.findIndex((h) => h.startsWith('=>'));
      expect(table.at(-1)!.slice(0, inputs).every((c) => c === '-'), name).toBe(true);
    }
  });
});

describe('parseAnswers', () => {
  it('reads the score, its level and its reason', () => {
    expect(parseAnswers(answers(0.723, 'great', 'in_grades_nearby'))).toEqual({ score: 0.72, level: 'great', reason: 'in_grades_nearby' });
  });

  it('refuses anything unexpected', () => {
    expect(parseAnswers(undefined)).toBeNull();
    expect(parseAnswers({ ...answers(0.5), match_level: { level: 'amazing' } })).toBeNull();
    expect(parseAnswers({ ...answers(0.5), match_reason: { choice: 'vibes' } })).toBeNull();
    expect(parseAnswers({ ...answers(0.5), match_likelihood: { number: 'high' } })).toBeNull();
  });
});

describe('aityxScorer', () => {
  it('is off without a key', () => {
    expect(aityxScorer({ url: 'https://api.aityx.ai', key: '' })).toBeNull();
    expect(aityxScorer({ url: '', key: 'aityx_sk_x' })).toBeNull();
  });

  it('posts the model and the facts to System One with the key', async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    const scorer = aityxScorer({
      url: 'https://api.aityx.ai/',
      key: 'aityx_sk_test',
      fetch: (async (url: string, init: RequestInit) => {
        calls.push({ url, init });
        return new Response(JSON.stringify({ answers: answers(0.5), usage: { input_tokens: 2100, output_tokens: 300 } }), { status: 200 });
      }) as typeof fetch,
    })!;
    const facts = matchFacts(climber('a'), plan('p'), 0, now);
    expect(await scorer(facts)).toEqual({ score: { score: 0.5, level: 'good', reason: 'in_grades' }, usage: { inputTokens: 2100, outputTokens: 300 } });
    expect(calls[0]!.url).toBe('https://api.aityx.ai/v1/systemone');
    expect((calls[0]!.init.headers as Record<string, string>).authorization).toBe('Bearer aityx_sk_test');
    expect(JSON.parse(calls[0]!.init.body as string)).toEqual({ decision: MATCH_MODEL, state: facts });
  });

  it('answers null on an error, never throws, and never logs the key', async () => {
    const logged: string[] = [];
    const error = console.error;
    console.error = (m: string) => logged.push(m);
    try {
      const failing = aityxScorer({
        url: 'https://api.aityx.ai',
        key: 'aityx_sk_secret',
        fetch: (async () => new Response(JSON.stringify({ code: 'invalid_state' }), { status: 422 })) as typeof fetch,
      })!;
      expect(await failing(matchFacts(climber('a'), plan('p'), 0, now))).toBeNull();
      const throwing = aityxScorer({ url: 'https://api.aityx.ai', key: 'aityx_sk_secret', fetch: (async () => { throw new Error('down'); }) as typeof fetch })!;
      expect(await throwing(matchFacts(climber('a'), plan('p'), 0, now))).toBeNull();
    } finally {
      console.error = error;
    }
    expect(logged.join('\n')).toContain('422 invalid_state');
    expect(logged.join('\n')).not.toContain('aityx_sk_secret');
  });
});

describe('pooled', () => {
  it('keeps the order and the concurrency', async () => {
    let running = 0;
    let peak = 0;
    const out = await pooled([5, 1, 3, 2, 4], 2, async (n) => {
      running++;
      peak = Math.max(peak, running);
      await new Promise((r) => setTimeout(r, n));
      running--;
      return n * 10;
    });
    expect(out).toEqual([50, 10, 30, 20, 40]);
    expect(peak).toBe(2);
  });
});

describe('scoreAll', () => {
  const request = (planId: string, climberId: string, extra: Partial<JoinRequest> = {}): JoinRequest => ({
    id: `${planId}/${climberId}`, planId, climberId, acceptedBy: [], rejected: false, time: now.toISOString(), joined: false, dismissed: false, ...extra,
  });

  it('scores every real profile against every upcoming plan it isn\'t in, and saves the run', async () => {
    const seen: { climber: string; open: number; group: number }[] = [];
    const scorer: MatchScorer = async (f) => {
      seen.push({ climber: f.discipline_climbed ? 'climbs' : 'not', open: f.open_requests, group: f.group_size });
      return { score: { score: 0.4, level: 'possible', reason: 'in_grades' }, usage: { inputTokens: 100, outputTokens: 0 } };
    };
    const written: ScoredPair[] = [];
    let saved: ScoreRun | undefined;
    const run = await scoreAll({
      source: {
        allClimbers: async () => [climber('a'), climber('b'), climber('demo', { demo: true })],
        upcomingPlans: async () => [plan('p1', { memberIds: ['org', 'a'] }), plan('p2')],
        openRequests: async () => [request('p2', 'a'), request('p2', 'x'), request('p2', 'y', { rejected: true })],
      },
      scores: {
        put: async (s) => { written.push(...s); },
        saveRun: async (r) => { saved = r; },
      },
      scorer,
      now,
    });
    // a is in p1: pairs b-p1, a-p2, b-p2; the demo climber never.
    expect(written.map((w) => `${w.climberId}-${w.planId}`).sort()).toEqual(['a-p2', 'b-p1', 'b-p2']);
    expect(written.every((w) => w.runId === now.toISOString())).toBe(true);
    // On p2, a's own request doesn't count against a; x's does.
    expect(seen.map((s) => s.open).sort()).toEqual([0, 1, 2]);
    expect(run).toMatchObject({ climbers: 2, plans: 2, pairs: 3, scored: 3, failed: 0, skipped: 0, inputTokens: 300 });
    expect(saved).toEqual(run);
  });

  it('caps the pairs (the soonest plans first) and counts failures', async () => {
    let n = 0;
    const run = await scoreAll({
      source: {
        allClimbers: async () => [climber('a')],
        upcomingPlans: async () => [plan('late', { start: '2030-06-01T10:00:00.000Z' }), plan('soon'), plan('mid', { start: '2030-05-10T10:00:00.000Z' })],
        openRequests: async () => [],
      },
      scores: { put: async () => {}, saveRun: async () => {} },
      scorer: async () => (n++ === 0 ? null : { score: { score: 0.1, level: 'long_shot', reason: 'far' }, usage: { inputTokens: 0, outputTokens: 0 } }),
      now,
      maxPairs: 2,
    });
    expect(run).toMatchObject({ pairs: 3, scored: 1, failed: 1, skipped: 1 });
  });

  it('counts the others waiting on a plan', () => {
    const open = openByPlan([request('p', 'a'), request('p', 'b'), request('q', 'a', { joined: true })]);
    expect(othersWaiting(open, 'p', 'a')).toBe(1);
    expect(othersWaiting(open, 'p', 'z')).toBe(2);
    expect(othersWaiting(open, 'q', 'z')).toBe(0);
  });
});

describe('scoreItem', () => {
  it('indexes a run best first, and expires a day after the plan starts', () => {
    const item = scoreItem({ climberId: 'a', planId: 'p', score: 0.5, level: 'good', reason: 'in_grades', runId: 'r1', scoredAt: 'r1' }, '2030-05-03T10:00:00.000Z');
    expect(item).toMatchObject({
      pk: 'CLIMBER#a',
      sk: 'PLAN#p',
      gsi1pk: 'RUN#r1',
      gsi1sk: '0.50#a#p',
      ttl: Date.parse('2030-05-04T10:00:00.000Z') / 1000,
    });
  });

  it("an undated plan's expires a month (and a day) after the run", () => {
    const item = scoreItem({ climberId: 'a', planId: 'p', score: 0.5, level: 'good', reason: 'in_grades', runId: 'r1', scoredAt: '2030-05-01T10:00:00.000Z' }, undefined);
    expect(item.ttl).toBe(Date.parse('2030-06-01T10:00:00.000Z') / 1000);
  });
});

describe('the API', () => {
  const ada: Caller = { subject: 'test#ada', email: 'ada@example.com', isAdmin: async () => false };
  const root: Caller = { subject: 'test#root', email: 'root@example.com', isAdmin: async () => true };

  function setup(scorer?: MatchScorer) {
    const store = new FakeStore();
    const api = new Api({
      store: store.asStore(),
      photos: { presign: async () => ({ url: '', fields: {} }), keep: async () => true, remove: async () => {} },
      auth: { signIn: async () => ({}), signOut: async () => {}, signOutEverywhere: async () => {} } as never,
      matchScorer: scorer,
      config: { stage: 'local', version: 'test' },
      clock: () => now,
    });
    const call = async (c: Caller, method: string, path: string, body?: unknown) =>
      (await api.handle(method, path, { caller: c, body, query: {} })) as Record<string, any>;
    return { store, call };
  }

  const profile = { name: 'X', bio: '', levels: { sport: { scale: 'routes', min: 6, max: 10 } }, gear: [] };
  const planBody = {
    discipline: 'sport', place: 'Crag', area: '', start: '2030-05-03T10:00:00Z', end: '2030-05-03T16:00:00Z',
    grades: { scale: 'routes', min: 8, max: 9 }, notes: '',
  };

  it("scores an admin's deck, and nobody else's", async () => {
    const asked: number[] = [];
    const { call } = setup(async (f) => {
      asked.push(f.group_size);
      return { score: { score: 0.81, level: 'great', reason: 'in_grades' }, usage: { inputTokens: 1, outputTokens: 0 } };
    });
    const ben: Caller = { subject: 'test#ben', email: 'ben@example.com', isAdmin: async () => false };
    await call(ben, 'PUT', '/api/me', profile);
    const { plan: p } = await call(ben, 'POST', '/api/plans', planBody);
    await call(ada, 'PUT', '/api/me', profile);
    await call(root, 'PUT', '/api/me', profile);
    const mine = await call(ada, 'GET', '/api/discover');
    expect(mine.plans).toHaveLength(1);
    expect(mine.scores).toBeUndefined();
    expect(asked).toEqual([]);
    const admins = await call(root, 'GET', '/api/discover');
    expect(admins.scores).toEqual({ [p.id]: { score: 0.81, level: 'great', reason: 'in_grades' } });
  });

  it("leaves a plan aityx didn't score without one, and the deck as it was", async () => {
    const { call } = setup(async () => null);
    await call(root, 'PUT', '/api/me', profile);
    const ben: Caller = { subject: 'test#ben', email: 'ben@example.com', isAdmin: async () => false };
    await call(ben, 'PUT', '/api/me', profile);
    await call(ben, 'POST', '/api/plans', planBody);
    const deck = await call(root, 'GET', '/api/discover');
    expect(deck.plans).toHaveLength(1);
    expect(deck.scores).toEqual({});
  });
});
