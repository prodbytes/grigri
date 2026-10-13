// Loads the made-up test data (seed/data.ts) into an RC or local table.
// Idempotent: re-running refreshes the seed's own records and dates. Real
// people's data is never touched: their profiles, requests, notices and
// messages stay, and a real member of a seed plan stays a member.
// Refuses prod (by stage and by table name).
import { DeleteCommand, GetCommand, PutCommand } from '@aws-sdk/lib-dynamodb';
import { isOpen } from '../src/domain/model.js';
import { key, prefix } from '../src/store/keys.js';
import { type Store, messageItem, planItem, requestItem, toPlan, toRequest } from '../src/store/store.js';
import { seedData } from './data.js';

export const SEED_PREFIX = 'seed-';
const isSeed = (id: string) => id.startsWith(SEED_PREFIX);

/** Throws unless this is an RC or local table: never prod's. */
export function assertSeedable(stage: string, table: string): void {
  if (stage !== 'rc' && stage !== 'local') throw new Error(`refusing to seed stage '${stage}': only rc and local`);
  if (!/^grigri-(rc|local)-api$/.test(table)) throw new Error(`refusing to seed table '${table}': only grigri-rc-api or grigri-local-api`);
}

export interface SeedCounts {
  climbers: number;
  plans: number;
  requests: number;
  messages: number;
}

export async function seed(store: Store, now: Date): Promise<SeedCounts> {
  const data = seedData(now);
  const { doc, table } = store;
  const nowIso = now.toISOString();

  // All of it is made up: marked demo, so the app says so.
  for (const c of data.climbers) await store.saveProfile({ ...c, demo: true }, undefined, now);

  for (const p of data.plans) {
    const { Item } = await doc.send(new GetCommand({ TableName: table, Key: key.plan(p.id) }));
    const existing = Item ? toPlan(Item) : undefined;
    // Real people who joined stay (after the seed's members).
    const real = (existing?.memberIds ?? []).filter((m) => !isSeed(m) && !p.memberIds.includes(m));
    const memberIds = [...p.memberIds, ...real];
    const plan = { ...p, memberIds, demo: true as const };
    await doc.send(new PutCommand({ TableName: table, Item: planItem(plan, ((Item?.version as number) ?? 0) + 1) }));
    for (const m of p.memberIds) {
      await doc.send(new PutCommand({ TableName: table, Item: { ...key.member(m, p.id), type: 'member', planId: p.id, time: nowIso } }));
    }
    // Seed climbers who joined since (accepted by testers): back out.
    for (const m of existing?.memberIds ?? []) {
      if (isSeed(m) && !p.memberIds.includes(m)) {
        await doc.send(new DeleteCommand({ TableName: table, Key: key.member(m, p.id) }));
      }
    }
    // The seed's own chat lines, with fresh times.
    const old = await store.query({
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :sk)',
      ExpressionAttributeValues: { ':pk': prefix.plan(p.id), ':sk': prefix.message },
      ProjectionExpression: 'pk, sk, id',
    });
    await store.batchWrite(
      old.filter((m) => isSeed(String(m.id))).map((m) => ({ DeleteRequest: { Key: { pk: m.pk, sk: m.sk } } })),
    );
  }

  for (const r of data.requests) {
    const { Item } = await doc.send(new GetCommand({ TableName: table, Key: key.request(r.planId, r.climberId) }));
    const plan = data.plans.find((p) => p.id === r.planId)!;
    // Testers' yeses on a still-open seed request stay.
    const kept = Item && isOpen(toRequest(Item)) ? toRequest(Item).acceptedBy.filter((a) => !isSeed(a)) : [];
    const acceptedBy = [...new Set([...r.acceptedBy, ...kept])].filter((a) => isSeed(a) ? plan.memberIds.includes(a) : true);
    await doc.send(new PutCommand({ TableName: table, Item: requestItem({ ...r, acceptedBy }) }));
  }

  await store.batchWrite(data.messages.map((m) => ({ PutRequest: { Item: messageItem(m) } })));

  return {
    climbers: data.climbers.length,
    plans: data.plans.length,
    requests: data.requests.length,
    messages: data.messages.length,
  };
}
