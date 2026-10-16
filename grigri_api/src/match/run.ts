// A scoring run: every profile against every upcoming plan it isn't in,
// each pair scored by aityx (System One) and written to the scores table
// (store/scores.ts), then the run's summary. Run by the scoring function
// (src/scorer.ts) on demand.
import type { Climber, JoinRequest, Plan } from '../domain/model.js';
import { isOpen } from '../domain/model.js';
import { soonestFirst } from '../domain/rules.js';
import type { ScoreRun, ScoredPair, ScoresStore } from '../store/scores.js';
import { type MatchScorer, pooled } from './aityx.js';
import { matchFacts } from './facts.js';

/** What a run reads from the app's table. */
export interface RunSource {
  allClimbers(): Promise<Climber[]>;
  upcomingPlans(afterIso: string): Promise<Plan[]>;
  openRequests(): Promise<JoinRequest[]>;
}

export interface RunOptions {
  source: RunSource;
  scores: Pick<ScoresStore, 'put' | 'saveRun'>;
  scorer: MatchScorer;
  now: Date;
  /** Most pairs a run scores (the soonest plans' first): caps its cost. */
  maxPairs?: number;
  /** Calls to aityx at once. */
  concurrency?: number;
}

/** At about 1,600 input tokens a call (the model travels with each; measured 2026-10-16), about $0.33 at System One's price. */
export const MAX_PAIRS = 5000;
const CONCURRENCY = 8;

/** Open requests waiting on each plan, by climber. */
export function openByPlan(requests: JoinRequest[]): Map<string, Set<string>> {
  const out = new Map<string, Set<string>>();
  for (const r of requests) {
    if (!isOpen(r)) continue;
    const set = out.get(r.planId) ?? new Set<string>();
    set.add(r.climberId);
    out.set(r.planId, set);
  }
  return out;
}

/** The requests waiting on [plan], the climber's own left out. */
export function othersWaiting(open: Map<string, Set<string>>, planId: string, climberId: string): number {
  const set = open.get(planId);
  if (!set) return 0;
  return set.size - (set.has(climberId) ? 1 : 0);
}

export async function scoreAll(o: RunOptions): Promise<ScoreRun> {
  const startedAt = o.now.toISOString();
  const runId = startedAt;
  const [climbers, plans, requests] = await Promise.all([
    o.source.allClimbers(),
    o.source.upcomingPlans(startedAt),
    o.source.openRequests(),
  ]);
  // Real people only: the demo showcase's made-up climbers never swipe.
  const people = climbers.filter((c) => !c.demo);
  const soonest = soonestFirst(plans);
  const open = openByPlan(requests);
  const all: { climber: Climber; plan: Plan }[] = [];
  for (const plan of soonest) {
    for (const climber of people) {
      if (!plan.memberIds.includes(climber.id)) all.push({ climber, plan });
    }
  }
  const max = o.maxPairs ?? MAX_PAIRS;
  const pairs = all.slice(0, max);
  let inputTokens = 0;
  let failed = 0;
  const results = await pooled(pairs, o.concurrency ?? CONCURRENCY, async ({ climber, plan }) => {
    const facts = matchFacts(climber, plan, othersWaiting(open, plan.id, climber.id), o.now);
    const out = await o.scorer(facts);
    if (!out) {
      failed++;
      return null;
    }
    inputTokens += out.usage.inputTokens;
    const scored: ScoredPair = { ...out.score, climberId: climber.id, planId: plan.id, runId, scoredAt: startedAt };
    return scored;
  });
  const scored = results.filter((r): r is ScoredPair => r !== null);
  await o.scores.put(scored, new Map(plans.map((p) => [p.id, p.start])));
  const run: ScoreRun = {
    runId,
    startedAt,
    finishedAt: new Date().toISOString(),
    climbers: people.length,
    plans: plans.length,
    pairs: all.length,
    scored: scored.length,
    failed,
    skipped: all.length - pairs.length,
    inputTokens,
  };
  await o.scores.saveRun(run);
  return run;
}
