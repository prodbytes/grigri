// The match scoring function: scores every profile against every upcoming
// plan with aityx and writes the scores table (src/match/run.ts). Invoked
// directly, on demand (scripts/score-matches.sh); any event runs it. Its
// own Lambda, with a long timeout, so the API's stays short.
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import { aityxScorer } from './match/aityx.js';
import { scoreAll } from './match/run.js';
import { ScoresStore } from './store/scores.js';
import { Store } from './store/store.js';

const env = process.env;
const doc = DynamoDBDocumentClient.from(new DynamoDBClient({}), {
  marshallOptions: { removeUndefinedValues: true },
});
const store = new Store(doc, env.TABLE_NAME ?? '');
const scores = new ScoresStore(doc, env.SCORES_TABLE ?? '');
// A run waits longer per call than the deck does: nobody is waiting on it.
const scorer = aityxScorer({ url: env.AITYX_URL ?? '', key: env.AITYX_API_KEY ?? '', timeoutMs: 10_000 });

export async function handler(): Promise<Record<string, unknown>> {
  if (!scorer) return { error: 'no aityx key: AITYX_API_KEY is empty' };
  const run = await scoreAll({ source: store, scores, scorer, now: new Date() });
  console.log(JSON.stringify({ level: 'info', msg: 'match scores run', ...run }));
  return { run };
}
