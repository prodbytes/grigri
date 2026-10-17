// Loads the made-up test data (seed/data.ts) into an RC or local table,
// plus the demo showcase and sample ads that every stage has.
// Idempotent: re-running refreshes the seed's own records and dates. Real
// people's data is never touched: their profiles, requests, notices and
// messages stay, and a real member of a seed plan stays a member.
// Refuses prod (by stage and by table name).
import { DeleteCommand, GetCommand, PutCommand } from '@aws-sdk/lib-dynamodb';
import { isOpen } from '../src/domain/model.js';
import { key, prefix } from '../src/store/keys.js';
import { Conflict, type Store, messageItem, planItem, requestItem, toPlan, toRequest } from '../src/store/store.js';
import type { Ad } from '../src/domain/ads.js';
import type { Climber, Plan } from '../src/domain/model.js';
import { type SeedAd, seedAdvertiser, seedAds } from './ads.js';
import { seedData } from './data.js';
import { showcaseData } from './showcase.js';

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
  ads: number;
}

/** Puts a photo at photos/<key> in the photos bucket. */
export type PutPhoto = (key: string, body: Uint8Array, contentType: string) => Promise<void>;

export async function seed(store: Store, now: Date, putPhoto?: PutPhoto): Promise<SeedCounts> {
  const data = seedData(now);
  const { doc, table } = store;
  await writeClimbers(store, data.climbers, now);
  await writePlans(store, data.plans, now);
  // RC and local show the demo showcase too, with its sample ads.
  const { ads } = await seedShowcase(store, now, putPhoto);

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
    ads,
  };
}

/**
 * The sample ads, approved, with their photos copied into the photos
 * bucket. An ad already saved keeps its status (an admin may have
 * rejected it) and its dates (so it never moves ahead of real
 * advertisers' ads), and its photo isn't copied again. An ad whose photo
 * can't be copied is saved with its text alone, and tried again next time.
 */
export async function writeAds(store: Store, ads: SeedAd[], putPhoto?: PutPhoto): Promise<number> {
  await Promise.all(ads.map(async ({ ad, photoSource }) => {
    const existing = await store.getAd(ad.id);
    let saved: Ad = existing ? { ...ad, status: existing.status, createdAt: existing.createdAt, reviewedAt: existing.reviewedAt } : ad;
    if (ad.media && existing?.media?.key !== ad.media.key) {
      try {
        if (!putPhoto || !photoSource) throw new Error('no photo store');
        const res = await fetch(photoSource, { signal: AbortSignal.timeout(10_000) });
        const type = res.headers.get('content-type') ?? '';
        if (!res.ok || !/^image\/(jpeg|png|webp)$/.test(type)) throw new Error(`${res.status} ${type}`);
        await putPhoto(ad.media.key, new Uint8Array(await res.arrayBuffer()), type);
      } catch (e) {
        console.error(JSON.stringify({ level: 'warn', msg: 'seed ad photo not copied', ad: ad.id, error: String(e) }));
        const { media: _media, ...rest } = saved;
        saved = rest;
      }
    }
    await store.putAd(saved);
  }));
  return ads.length;
}

/** The seed's climbers, marked demo (all of them are made up). One an admin blocked stays as it is. */
async function writeClimbers(store: Store, climbers: Climber[], now: Date): Promise<void> {
  for (const c of climbers) {
    try {
      await store.saveProfile({ ...c, demo: true }, undefined, now);
    } catch (e) {
      if (!(e instanceof Conflict)) throw e;
    }
  }
}

/**
 * The seed's plans, marked demo, with fresh dates and the seed's chat
 * lines. Real people who joined one stay members; seed climbers who
 * joined since (accepted by testers) back out.
 */
async function writePlans(store: Store, plans: Plan[], now: Date): Promise<void> {
  const { doc, table } = store;
  const nowIso = now.toISOString();
  for (const p of plans) {
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
}

const SHOWCASE_EVERY_MS = 12 * 3_600_000;
/** Bumped when showcase.ts changes, so stages rewrite it at once, not up to 12 hours later. */
export const SHOWCASE_VERSION = 6;

/**
 * The demo showcase (seed/showcase.ts), on every stage: its climbers and
 * plans, re-dated, and the sample ads (seed/ads.ts) with their photos. It
 * writes only `seed-` records (and the ads' photos), so it's safe in
 * production. Records when, so [showcaseIsStale] can tell.
 */
export async function seedShowcase(store: Store, now: Date, putPhoto?: PutPhoto): Promise<{ climbers: number; plans: number; ads: number }> {
  const data = showcaseData(now);
  await writeClimbers(store, [...data.climbers, seedAdvertiser], now);
  await writePlans(store, data.plans, now);
  const ads = await writeAds(store, seedAds(now), putPhoto);
  await store.doc.send(new PutCommand({ TableName: store.table, Item: { ...key.showcase(), type: 'showcase', time: now.toISOString(), version: SHOWCASE_VERSION } }));
  return { climbers: data.climbers.length, plans: data.plans.length, ads };
}

/** Whether the showcase was last written over 12 hours ago, by an older showcase.ts, or never. */
export async function showcaseIsStale(store: Store, now: Date): Promise<boolean> {
  const { Item } = await store.doc.send(new GetCommand({ TableName: store.table, Key: key.showcase() }));
  const time = typeof Item?.time === 'string' ? Date.parse(Item.time) : NaN;
  return Item?.version !== SHOWCASE_VERSION || !(now.getTime() - time < SHOWCASE_EVERY_MS);
}
