// The match score from aityx (https://aityx.ai): POST <url>/v1/systemone
// {decision, state} runs model.json on one climber's and one plan's facts
// (facts.ts), deterministically and without AI, and answers with typed
// answers. The model travels with every call (aityx keeps none). The key is
// a secret: it stays in the function's environment, never reaches the app,
// and is never logged.
//
// Best effort: no key, a timeout, an error or an unexpected answer is null
// (no score), never a failed request.
import model from './model.json' with { type: 'json' };
import type { MatchFacts } from './facts.js';

export const MATCH_LEVELS = ['long_shot', 'possible', 'good', 'great'] as const;
export type MatchLevel = (typeof MATCH_LEVELS)[number];

export const MATCH_REASONS = [
  'other_discipline',
  'too_hard',
  'too_easy',
  'starts_soon',
  'far',
  'big_group',
  'crowded',
  'in_grades_nearby',
  'in_grades',
  'close_grades',
] as const;
export type MatchReason = (typeof MATCH_REASONS)[number];

/** How likely a climber and a plan end in a match. */
export interface MatchScore {
  /** 0 to 1, two decimals. */
  score: number;
  level: MatchLevel;
  /** The main reason, the first that applies (model.json, match_reason). */
  reason: MatchReason;
}

/** What one call cost, in aityx's billable tokens. */
export interface Usage {
  inputTokens: number;
  outputTokens: number;
}

export type MatchScorer = (facts: MatchFacts) => Promise<{ score: MatchScore; usage: Usage } | null>;

export const MATCH_MODEL = model;

export interface AityxConfig {
  /** aityx's API, e.g. https://api.aityx.ai. */
  url: string;
  /** The API key (aityx_sk_...); empty: no scores. */
  key: string;
  timeoutMs?: number;
  fetch?: typeof fetch;
}

const DEFAULT_TIMEOUT_MS = 3000;

/** A scorer, or null when there's no key (scores off). */
export function aityxScorer(config: AityxConfig): MatchScorer | null {
  const url = config.url.replace(/\/+$/, '');
  const key = config.key.trim();
  if (!url || !key) return null;
  const doFetch = config.fetch ?? fetch;
  const timeoutMs = config.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  return async (facts) => {
    try {
      const res = await doFetch(`${url}/v1/systemone`, {
        method: 'POST',
        headers: { authorization: `Bearer ${key}`, 'content-type': 'application/json' },
        body: JSON.stringify({ decision: model, state: facts }),
        signal: AbortSignal.timeout(timeoutMs),
      });
      const body = (await res.json().catch(() => ({}))) as Record<string, unknown>;
      if (!res.ok) {
        // Problem details carry a stable code; never the key.
        const code = typeof body.code === 'string' ? body.code : '';
        throw new Error(`aityx answered ${res.status} ${code}`.trim());
      }
      const score = parseAnswers(body.answers);
      if (!score) throw new Error('aityx answered without a match score');
      return { score, usage: parseUsage(body.usage) };
    } catch (e) {
      console.error(JSON.stringify({ level: 'warn', msg: 'aityx match score failed', error: String(e) }));
      return null;
    }
  };
}

/** The model's answers as a MatchScore; null for anything unexpected. */
export function parseAnswers(answers: unknown): MatchScore | null {
  if (!answers || typeof answers !== 'object') return null;
  const a = answers as Record<string, Record<string, unknown> | undefined>;
  const score = a.match_likelihood?.number;
  const level = a.match_level?.level;
  const reason = a.match_reason?.choice;
  if (typeof score !== 'number' || !Number.isFinite(score)) return null;
  if (!MATCH_LEVELS.includes(level as MatchLevel)) return null;
  if (!MATCH_REASONS.includes(reason as MatchReason)) return null;
  return {
    score: Math.round(Math.min(1, Math.max(0, score)) * 100) / 100,
    level: level as MatchLevel,
    reason: reason as MatchReason,
  };
}

function parseUsage(usage: unknown): Usage {
  const u = (usage ?? {}) as Record<string, unknown>;
  const n = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : 0);
  return { inputTokens: n(u.input_tokens), outputTokens: n(u.output_tokens) };
}

/**
 * Runs [work] on every item, at most [concurrency] at once, keeping the
 * order of the results.
 */
export async function pooled<T, R>(items: T[], concurrency: number, work: (item: T) => Promise<R>): Promise<R[]> {
  const out = new Array<R>(items.length);
  let next = 0;
  const worker = async () => {
    while (next < items.length) {
      const i = next++;
      out[i] = await work(items[i]!);
    }
  };
  await Promise.all(Array.from({ length: Math.min(concurrency, items.length) }, worker));
  return out;
}
