// The match scores table (<stack>-scores): every climber's score against
// every upcoming plan, written by the scoring function (src/scorer.ts) and
// not read by the app for now. Its own table, apart from the app's data:
// it's derived, rewritten whole by each run, and can be dropped any time.
//
//   pk CLIMBER#<climberId>, sk PLAN#<planId>   one climber's score for one
//                                              plan: one GetItem; a
//                                              climber's all: one Query
//   pk META, sk RUN                            the latest run's summary
//   gsi1: gsi1pk RUN#<runId>, gsi1sk <score>#<climberId>#<planId>
//                                              a run's scores, best first
//
// Scores expire (the table's ttl) a day after their plan starts. A pair a
// run no longer scores (the climber joined the plan) keeps its old score,
// under the old run's index partition, until then.
import { BatchWriteCommand, type DynamoDBDocumentClient, GetCommand, PutCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { MATCH_LEVELS, MATCH_REASONS, type MatchLevel, type MatchReason, type MatchScore } from '../match/aityx.js';

type Item = Record<string, unknown>;

export interface ScoredPair extends MatchScore {
  climberId: string;
  planId: string;
  /** The run that scored it. */
  runId: string;
  scoredAt: string;
}

/** What a run did. */
export interface ScoreRun {
  runId: string;
  startedAt: string;
  finishedAt: string;
  climbers: number;
  plans: number;
  /** Climber-plan pairs to score (not members already). */
  pairs: number;
  scored: number;
  failed: number;
  /** Pairs left out past the run's cap. */
  skipped: number;
  inputTokens: number;
}

const DAY_S = 24 * 60 * 60;

export class ScoresStore {
  constructor(
    readonly doc: DynamoDBDocumentClient,
    readonly table: string,
  ) {}

  /** One climber's score for one plan, from the latest run that scored the pair. */
  async score(climberId: string, planId: string): Promise<ScoredPair | undefined> {
    const { Item } = await this.doc.send(new GetCommand({ TableName: this.table, Key: scoreKey(climberId, planId) }));
    return Item ? toScored(Item) : undefined;
  }

  /** A run's best scores, best first. */
  async top(runId: string, limit: number): Promise<ScoredPair[]> {
    const page = await this.doc.send(new QueryCommand({
      TableName: this.table,
      IndexName: 'gsi1',
      KeyConditionExpression: 'gsi1pk = :pk',
      ExpressionAttributeValues: { ':pk': `RUN#${runId}` },
      ScanIndexForward: false,
      Limit: limit,
    }));
    return ((page.Items ?? []) as Item[]).flatMap((i) => toScored(i) ?? []);
  }

  async latestRun(): Promise<ScoreRun | undefined> {
    const { Item } = await this.doc.send(new GetCommand({ TableName: this.table, Key: { pk: 'META', sk: 'RUN' } }));
    return Item ? (Item.run as ScoreRun) : undefined;
  }

  async saveRun(run: ScoreRun): Promise<void> {
    await this.doc.send(new PutCommand({ TableName: this.table, Item: { pk: 'META', sk: 'RUN', run } }));
  }

  /** Writes scores; [startsAt]: each plan's start, for its scores' expiry. */
  async put(scores: ScoredPair[], startsAt: Map<string, string>): Promise<void> {
    const requests = scores.map((s) => ({ PutRequest: { Item: scoreItem(s, startsAt.get(s.planId)) } }));
    for (let i = 0; i < requests.length; i += 25) {
      let pending: Item[] | undefined = requests.slice(i, i + 25);
      for (let attempt = 0; pending?.length; attempt++) {
        if (attempt > 0) await new Promise((resolve) => setTimeout(resolve, Math.min(1000, 25 * 2 ** attempt)));
        const res = await this.doc.send(new BatchWriteCommand({ RequestItems: { [this.table]: pending as never } }));
        pending = res.UnprocessedItems?.[this.table] as Item[] | undefined;
        if (attempt > 8 && pending?.length) throw new Error('DynamoDB kept score writes unprocessed');
      }
    }
  }
}

function scoreKey(climberId: string, planId: string) {
  return { pk: `CLIMBER#${climberId}`, sk: `PLAN#${planId}` };
}

export function scoreItem(s: ScoredPair, startsAt: string | undefined): Item {
  const start = startsAt ? Math.floor(Date.parse(startsAt) / 1000) : NaN;
  return {
    ...scoreKey(s.climberId, s.planId),
    gsi1pk: `RUN#${s.runId}`,
    // Sorts by score (0.00 to 1.00), then by pair.
    gsi1sk: `${s.score.toFixed(2)}#${s.climberId}#${s.planId}`,
    climberId: s.climberId,
    planId: s.planId,
    score: s.score,
    level: s.level,
    reason: s.reason,
    runId: s.runId,
    scoredAt: s.scoredAt,
    ...(Number.isFinite(start) ? { ttl: start + DAY_S } : {}),
  };
}

function toScored(i: Item): ScoredPair | undefined {
  if (typeof i.score !== 'number') return undefined;
  if (!MATCH_LEVELS.includes(i.level as MatchLevel) || !MATCH_REASONS.includes(i.reason as MatchReason)) return undefined;
  return {
    climberId: i.climberId as string,
    planId: i.planId as string,
    score: i.score,
    level: i.level as MatchLevel,
    reason: i.reason as MatchReason,
    runId: i.runId as string,
    scoredAt: i.scoredAt as string,
  };
}
