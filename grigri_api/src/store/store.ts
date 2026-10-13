// DynamoDB access: the single table's items to and from the domain's
// shapes. Writes that race (membership, answers, a double join) are
// transactions conditioned on the plan's version, which every change to a
// plan's members or requests increments.
import {
  BatchGetCommand,
  BatchWriteCommand,
  DeleteCommand,
  type DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
  QueryCommand,
  type QueryCommandInput,
  TransactWriteCommand,
  type TransactWriteCommandInput,
  UpdateCommand,
} from '@aws-sdk/lib-dynamodb';
import type { SessionRecord, SessionStore } from '../auth.js';
import type { Delivery, Effects } from '../domain/rules.js';
import { type Climber, type JoinRequest, type Location, type Message, type Notice, type Plan, isOpen } from '../domain/model.js';
import { index, key, prefix } from './keys.js';

type Item = Record<string, unknown>;
type TransactItem = NonNullable<TransactWriteCommandInput['TransactItems']>[number];

/** A conditional write lost a race: reload and try again. */
export class Conflict extends Error {}

export interface VersionedPlan {
  plan: Plan;
  version: number;
}

export interface LoadedPlan extends VersionedPlan {
  requests: JoinRequest[];
}

export class Store implements SessionStore {
  constructor(
    readonly doc: DynamoDBDocumentClient,
    readonly table: string,
  ) {}

  // --- Sessions (src/auth.ts) -----------------------------------------------

  async putSession(s: SessionRecord): Promise<void> {
    await this.doc.send(new PutCommand({
      TableName: this.table,
      Item: {
        ...key.session(s.id),
        type: 'session',
        subject: s.subject,
        ...(s.email ? { email: s.email } : {}),
        emailVerified: s.emailVerified,
        ...(s.name ? { name: s.name } : {}),
        createdAt: s.createdAt,
        lastUsedAt: s.lastUsedAt,
        // The table's TTL attribute: DynamoDB deletes the item after it.
        ttl: s.ttl,
        // Keys-only index: sliding lastUsedAt and ttl never writes to it.
        gsi3pk: index.sessions.pk(s.subject),
        gsi3sk: s.createdAt,
      },
      ConditionExpression: 'attribute_not_exists(pk)',
    }));
  }

  async getSession(id: string): Promise<SessionRecord | undefined> {
    const get = (consistent: boolean) =>
      this.doc.send(new GetCommand({ TableName: this.table, Key: key.session(id), ConsistentRead: consistent }));
    // Eventually consistent reads cost half; a session created a moment
    // ago may not show yet, so a miss is read again, consistently.
    const Item = (await get(false)).Item ?? (await get(true)).Item;
    if (!Item) return undefined;
    return {
      id,
      subject: Item.subject as string,
      ...(typeof Item.email === 'string' ? { email: Item.email } : {}),
      emailVerified: Item.emailVerified === true,
      ...(typeof Item.name === 'string' ? { name: Item.name } : {}),
      createdAt: Item.createdAt as string,
      lastUsedAt: Item.lastUsedAt as string,
      ttl: Item.ttl as number,
    };
  }

  async touchSession(id: string, previous: string, lastUsedAt: string, ttl: number): Promise<void> {
    try {
      await this.doc.send(new UpdateCommand({
        TableName: this.table,
        Key: key.session(id),
        UpdateExpression: 'SET lastUsedAt = :now, #ttl = :ttl',
        // Not if it was revoked meanwhile, or another request moved it.
        ConditionExpression: 'attribute_exists(pk) AND lastUsedAt = :previous',
        ExpressionAttributeNames: { '#ttl': 'ttl' },
        ExpressionAttributeValues: { ':now': lastUsedAt, ':ttl': ttl, ':previous': previous },
      }));
    } catch (e) {
      if (!isConditionFailure(e)) throw e;
    }
  }

  async deleteSession(id: string): Promise<void> {
    await this.doc.send(new DeleteCommand({ TableName: this.table, Key: key.session(id) }));
  }

  async deleteSessions(subject: string): Promise<void> {
    const items = await this.query({
      IndexName: index.sessions.name,
      KeyConditionExpression: 'gsi3pk = :pk',
      ExpressionAttributeValues: { ':pk': index.sessions.pk(subject) },
    });
    await this.batchWrite(items.map((i) => ({ DeleteRequest: { Key: { pk: i.pk, sk: i.sk } } })));
  }

  // --- Identity and profiles ----------------------------------------------

  async climberIdFor(subject: string): Promise<string | undefined> {
    const { Item } = await this.doc.send(new GetCommand({ TableName: this.table, Key: key.subject(subject) }));
    return Item?.climberId as string | undefined;
  }

  async getClimber(id: string): Promise<Climber | undefined> {
    const { Item } = await this.doc.send(new GetCommand({ TableName: this.table, Key: key.climber(id) }));
    return Item ? toClimber(Item) : undefined;
  }

  /** Profiles by id (missing ones left out). */
  async getClimbers(ids: Iterable<string>): Promise<Record<string, Climber>> {
    const items = await this.batchGet([...new Set(ids)].map((id) => key.climber(id)));
    return Object.fromEntries(items.map((i) => {
      const c = toClimber(i);
      return [c.id, c];
    }));
  }

  /** The first profile of a subject: links it to the new climber id. */
  async createProfile(subject: string, climber: Climber, now: Date): Promise<void> {
    try {
      await this.doc.send(new TransactWriteCommand({
        TransactItems: [
          {
            Put: {
              TableName: this.table,
              Item: { ...key.subject(subject), type: 'subject', climberId: climber.id, createdAt: now.toISOString() },
              ConditionExpression: 'attribute_not_exists(pk)',
            },
          },
          {
            Put: {
              TableName: this.table,
              Item: climberItem(climber, subject, now),
              ConditionExpression: 'attribute_not_exists(pk)',
            },
          },
        ],
      }));
    } catch (e) {
      throw asConflict(e);
    }
  }

  async saveProfile(climber: Climber, subject: string | undefined, now: Date): Promise<void> {
    await this.doc.send(new PutCommand({ TableName: this.table, Item: climberItem(climber, subject, now) }));
  }

  // --- Plans ----------------------------------------------------------------

  async getPlan(planId: string): Promise<VersionedPlan | undefined> {
    const { Item } = await this.doc.send(new GetCommand({ TableName: this.table, Key: key.plan(planId) }));
    return Item ? { plan: toPlan(Item), version: Item.version as number } : undefined;
  }

  async getPlans(ids: Iterable<string>): Promise<Plan[]> {
    const items = await this.batchGet([...new Set(ids)].map((id) => key.plan(id)));
    return items.map(toPlan);
  }

  /** A plan with its requests (not its messages). */
  async loadPlan(planId: string): Promise<LoadedPlan | undefined> {
    const [plan, requests] = await Promise.all([this.getPlan(planId), this.planRequests(planId)]);
    return plan ? { ...plan, requests } : undefined;
  }

  async planRequests(planId: string): Promise<JoinRequest[]> {
    const items = await this.query({
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :sk)',
      ExpressionAttributeValues: { ':pk': prefix.plan(planId), ':sk': prefix.request },
    });
    return items.map(toRequest);
  }

  async getRequest(planId: string, climberId: string): Promise<JoinRequest | undefined> {
    const { Item } = await this.doc.send(new GetCommand({ TableName: this.table, Key: key.request(planId, climberId) }));
    return Item ? toRequest(Item) : undefined;
  }

  /** Plans that start after `afterIso` (the deck's candidates). */
  async upcomingPlans(afterIso: string): Promise<Plan[]> {
    const items = await this.query({
      IndexName: index.byStart.name,
      KeyConditionExpression: 'gsi1pk = :pk AND gsi1sk > :after',
      ExpressionAttributeValues: { ':pk': index.byStart.pk, ':after': afterIso },
    });
    return items.map(toPlan);
  }

  async memberPlanIds(climberId: string): Promise<string[]> {
    return this.climberChildren(climberId, prefix.member);
  }

  async passedPlanIds(climberId: string): Promise<string[]> {
    return this.climberChildren(climberId, prefix.pass);
  }

  async addPass(climberId: string, planId: string, now: Date): Promise<void> {
    await this.doc.send(new PutCommand({
      TableName: this.table,
      Item: { ...key.pass(climberId, planId), type: 'pass', planId, time: now.toISOString() },
    }));
  }

  /** The climber's own requests (any state). */
  async askedRequests(climberId: string): Promise<JoinRequest[]> {
    const items = await this.query({
      IndexName: index.asked.name,
      KeyConditionExpression: 'gsi2pk = :pk',
      ExpressionAttributeValues: { ':pk': index.asked.pk(climberId) },
    });
    return items.map(toRequest);
  }

  /** Every open request (the admin's view). */
  async openRequests(): Promise<JoinRequest[]> {
    const items = await this.query({
      IndexName: index.openRequests.name,
      KeyConditionExpression: 'gsi1pk = :pk',
      ExpressionAttributeValues: { ':pk': index.openRequests.pk },
    });
    return items.map(toRequest);
  }

  /** The requester dismisses a declined request. */
  async saveDismissed(request: JoinRequest): Promise<void> {
    try {
      await this.doc.send(new PutCommand({
        TableName: this.table,
        Item: requestItem(request),
        ConditionExpression: 'rejected = :true',
        ExpressionAttributeValues: { ':true': true },
      }));
    } catch (e) {
      throw asConflict(e);
    }
  }

  // --- Writing effects ------------------------------------------------------

  /**
   * Writes what an operation changed, in one transaction conditioned on the
   * plan's version (`previous` null: a new plan). Notices go out after it
   * commits (they're idempotent puts).
   */
  async apply(previous: VersionedPlan | null, effects: Effects, now: Date): Promise<void> {
    const items: TransactItem[] = [];
    const before = new Set(previous?.plan.memberIds ?? []);
    const planId = previous?.plan.id ?? effects.plan!.id;
    if (effects.plan) {
      items.push({
        Put: {
          TableName: this.table,
          Item: planItem(effects.plan, (previous?.version ?? 0) + 1),
          ...(previous
            ? { ConditionExpression: 'version = :v', ExpressionAttributeValues: { ':v': previous.version } }
            : { ConditionExpression: 'attribute_not_exists(pk)' }),
        },
      });
    } else if (previous) {
      items.push({
        Delete: {
          TableName: this.table,
          Key: key.plan(planId),
          ConditionExpression: 'version = :v',
          ExpressionAttributeValues: { ':v': previous.version },
        },
      });
    }
    const after = new Set(effects.plan?.memberIds ?? []);
    for (const m of after) {
      if (!before.has(m)) {
        items.push({ Put: { TableName: this.table, Item: { ...key.member(m, planId), type: 'member', planId, time: now.toISOString() } } });
      }
    }
    for (const m of before) {
      if (!after.has(m)) items.push({ Delete: { TableName: this.table, Key: key.member(m, planId) } });
    }
    if (effects.plan) {
      for (const r of effects.requests) items.push({ Put: { TableName: this.table, Item: requestItem(r) } });
      for (const m of effects.messages) items.push({ Put: { TableName: this.table, Item: messageItem(m) } });
    }
    await this.transact(items);
    if (!effects.plan) await this.deletePlanItems(planId);
    await this.deliver(effects.notices);
  }

  /**
   * A new join request: only if I haven't asked (no request yet) and the
   * plan hasn't changed since it was read (its members are who's notified).
   */
  async ask(previous: VersionedPlan, effects: Effects): Promise<void> {
    const [request] = effects.requests;
    const items: TransactItem[] = [
      {
        ConditionCheck: {
          TableName: this.table,
          Key: key.plan(previous.plan.id),
          ConditionExpression: 'version = :v',
          ExpressionAttributeValues: { ':v': previous.version },
        },
      },
      { Put: { TableName: this.table, Item: requestItem(request!), ConditionExpression: 'attribute_not_exists(pk)' } },
      ...effects.messages.map((m): TransactItem => ({ Put: { TableName: this.table, Item: messageItem(m) } })),
    ];
    await this.transact(items);
    await this.deliver(effects.notices);
  }

  /** Puts notices (best effort after the change itself committed). */
  async deliver(deliveries: Delivery[]): Promise<void> {
    await this.batchWrite(deliveries.map((d) => ({
      PutRequest: { Item: { ...key.notice(d.to, d.notice.id), type: 'notice', ...d.notice } },
    })));
  }

  // --- Notices ----------------------------------------------------------------

  async notices(climberId: string): Promise<Notice[]> {
    const items = await this.query({
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :sk)',
      ExpressionAttributeValues: { ':pk': prefix.climber(climberId), ':sk': prefix.notice },
    });
    return items.map(toNotice).sort((a, b) => (a.time > b.time ? -1 : a.time < b.time ? 1 : 0));
  }

  async markNoticesRead(climberId: string): Promise<void> {
    const unread = (await this.notices(climberId)).filter((n) => !n.read);
    await Promise.all(unread.map((n) => this.doc.send(new UpdateCommand({
      TableName: this.table,
      Key: key.notice(climberId, n.id),
      UpdateExpression: 'SET #read = :true',
      ConditionExpression: 'attribute_exists(pk)',
      ExpressionAttributeNames: { '#read': 'read' },
      ExpressionAttributeValues: { ':true': true },
    })).catch((e: unknown) => {
      if (!isConditionFailure(e)) throw e;
    })));
  }

  // --- Messages ---------------------------------------------------------------

  /** A plan's chat, oldest first; only those after `afterIso` when given. */
  async messages(planId: string, afterIso?: string): Promise<Message[]> {
    const input: Omit<QueryCommandInput, 'TableName'> = afterIso
      ? {
          KeyConditionExpression: 'pk = :pk AND sk BETWEEN :from AND :to',
          ExpressionAttributeValues: {
            ':pk': prefix.plan(planId),
            ':from': `${prefix.message}${afterIso}#￿`,
            ':to': `${prefix.message}￿`,
          },
        }
      : {
          KeyConditionExpression: 'pk = :pk AND begins_with(sk, :sk)',
          ExpressionAttributeValues: { ':pk': prefix.plan(planId), ':sk': prefix.message },
        };
    return (await this.query(input)).map(toMessage);
  }

  async putMessage(message: Message): Promise<void> {
    await this.doc.send(new PutCommand({ TableName: this.table, Item: messageItem(message) }));
  }

  // --- Plumbing ---------------------------------------------------------------

  /** Everything left in a plan's partition (requests, messages). */
  async deletePlanItems(planId: string): Promise<void> {
    const items = await this.query({
      KeyConditionExpression: 'pk = :pk',
      ExpressionAttributeValues: { ':pk': prefix.plan(planId) },
      ProjectionExpression: 'pk, sk',
    });
    await this.batchWrite(items.map((i) => ({ DeleteRequest: { Key: { pk: i.pk, sk: i.sk } } })));
  }

  private async climberChildren(climberId: string, childPrefix: string): Promise<string[]> {
    const items = await this.query({
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :sk)',
      ExpressionAttributeValues: { ':pk': prefix.climber(climberId), ':sk': childPrefix },
      ProjectionExpression: 'sk',
    });
    return items.map((i) => (i.sk as string).slice(childPrefix.length));
  }

  async query(input: Omit<QueryCommandInput, 'TableName'>): Promise<Item[]> {
    const out: Item[] = [];
    let start: Record<string, unknown> | undefined;
    do {
      const page = await this.doc.send(new QueryCommand({ ...input, TableName: this.table, ExclusiveStartKey: start }));
      out.push(...((page.Items ?? []) as Item[]));
      start = page.LastEvaluatedKey;
    } while (start);
    return out;
  }

  private async batchGet(keys: Item[]): Promise<Item[]> {
    const out: Item[] = [];
    for (let i = 0; i < keys.length; i += 100) {
      let pending: Item[] | undefined = keys.slice(i, i + 100);
      for (let attempt = 0; pending?.length; attempt++) {
        if (attempt > 0) await backoff(attempt);
        const res = await this.doc.send(new BatchGetCommand({ RequestItems: { [this.table]: { Keys: pending } } }));
        out.push(...((res.Responses?.[this.table] ?? []) as Item[]));
        pending = res.UnprocessedKeys?.[this.table]?.Keys as Item[] | undefined;
        if (attempt > 8 && pending?.length) throw new Error('DynamoDB kept keys unprocessed');
      }
    }
    return out;
  }

  async batchWrite(requests: Item[]): Promise<void> {
    for (let i = 0; i < requests.length; i += 25) {
      let pending: Item[] | undefined = requests.slice(i, i + 25);
      for (let attempt = 0; pending?.length; attempt++) {
        if (attempt > 0) await backoff(attempt);
        const res = await this.doc.send(new BatchWriteCommand({ RequestItems: { [this.table]: pending as never } }));
        pending = res.UnprocessedItems?.[this.table] as Item[] | undefined;
        if (attempt > 8 && pending?.length) throw new Error('DynamoDB kept writes unprocessed');
      }
    }
  }

  private async transact(items: TransactItem[]): Promise<void> {
    if (items.length > 100) throw new Error(`a transaction of ${items.length} items (at most 100)`);
    try {
      await this.doc.send(new TransactWriteCommand({ TransactItems: items }));
    } catch (e) {
      throw asConflict(e);
    }
  }
}

function backoff(attempt: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, Math.min(1000, 25 * 2 ** attempt)));
}

function isConditionFailure(e: unknown): boolean {
  const name = (e as { name?: string })?.name;
  if (name === 'ConditionalCheckFailedException') return true;
  if (name === 'TransactionCanceledException') {
    const reasons = (e as { CancellationReasons?: { Code?: string }[] }).CancellationReasons ?? [];
    // Some emulators leave the reasons out; a cancellation is a lost race.
    return reasons.length === 0 || reasons.some((r) => r.Code === 'ConditionalCheckFailed' || r.Code === 'TransactionConflict');
  }
  return false;
}

function asConflict(e: unknown): unknown {
  return isConditionFailure(e) ? new Conflict('changed meanwhile') : e;
}

// --- Items <-> shapes -----------------------------------------------------------

export function climberItem(c: Climber, subject: string | undefined, now: Date): Item {
  return {
    ...key.climber(c.id),
    type: 'climber',
    id: c.id,
    name: c.name,
    ...(c.age === undefined ? {} : { age: c.age }),
    bio: c.bio,
    ...(c.photo ? { photo: c.photo } : {}),
    levels: c.levels,
    gear: c.gear,
    gearPhotos: c.gearPhotos,
    ...(c.location ? { location: c.location } : {}),
    areas: c.areas ?? [],
    ...(c.demo ? { demo: true } : {}),
    // Who signs in as this climber (never returned); none for the seed's.
    ...(subject ? { subject } : {}),
    updatedAt: now.toISOString(),
  };
}

export function toClimber(i: Item): Climber {
  return {
    id: i.id as string,
    name: i.name as string,
    ...(typeof i.age === 'number' ? { age: i.age } : {}),
    bio: (i.bio as string) ?? '',
    ...(i.photo ? { photo: i.photo as string } : {}),
    levels: (i.levels as Climber['levels']) ?? {},
    gear: (i.gear as Climber['gear']) ?? [],
    gearPhotos: (i.gearPhotos as string[]) ?? [],
    ...(i.location ? { location: i.location as Location } : {}),
    areas: (i.areas as Location[]) ?? [],
    ...(i.demo === true ? { demo: true as const } : {}),
  };
}

export function planItem(p: Plan, version: number): Item {
  return {
    ...key.plan(p.id),
    type: 'plan',
    gsi1pk: index.byStart.pk,
    gsi1sk: `${p.start}#${p.id}`,
    version,
    id: p.id,
    organizerId: p.organizerId,
    discipline: p.discipline,
    place: p.place,
    area: p.area,
    ...(p.sectorId ? { sectorId: p.sectorId } : {}),
    ...(p.lat !== undefined && p.lon !== undefined ? { lat: p.lat, lon: p.lon } : {}),
    start: p.start,
    end: p.end,
    grades: p.grades,
    memberIds: p.memberIds,
    notes: p.notes,
    ...(p.demo ? { demo: true } : {}),
  };
}

export function toPlan(i: Item): Plan {
  return {
    id: i.id as string,
    organizerId: i.organizerId as string,
    discipline: i.discipline as Plan['discipline'],
    place: i.place as string,
    area: (i.area as string) ?? '',
    ...(i.sectorId ? { sectorId: i.sectorId as string } : {}),
    ...(typeof i.lat === 'number' && typeof i.lon === 'number' ? { lat: i.lat, lon: i.lon } : {}),
    start: i.start as string,
    end: i.end as string,
    grades: i.grades as Plan['grades'],
    memberIds: (i.memberIds as string[]) ?? [],
    notes: (i.notes as string) ?? '',
    ...(i.demo === true ? { demo: true as const } : {}),
  };
}

export function requestItem(r: JoinRequest): Item {
  return {
    ...key.request(r.planId, r.climberId),
    type: 'request',
    // The requester's own list (GET /api/plans: asked).
    gsi2pk: index.asked.pk(r.climberId),
    gsi2sk: `${r.time}#${r.planId}`,
    // Open requests only: the admin's list.
    ...(isOpen(r) ? { gsi1pk: index.openRequests.pk, gsi1sk: `${r.time}#${r.planId}#${r.climberId}` } : {}),
    id: r.id,
    planId: r.planId,
    climberId: r.climberId,
    acceptedBy: r.acceptedBy,
    rejected: r.rejected,
    time: r.time,
    joined: r.joined === true,
    dismissed: r.dismissed === true,
  };
}

export function toRequest(i: Item): JoinRequest {
  return {
    id: i.id as string,
    planId: i.planId as string,
    climberId: i.climberId as string,
    acceptedBy: (i.acceptedBy as string[]) ?? [],
    rejected: i.rejected === true,
    time: i.time as string,
    joined: i.joined === true,
    dismissed: i.dismissed === true,
  };
}

function toNotice(i: Item): Notice {
  return {
    id: i.id as string,
    kind: i.kind as Notice['kind'],
    planId: i.planId as string,
    planTitle: i.planTitle as string,
    ...(i.climberId ? { climberId: i.climberId as string } : {}),
    time: i.time as string,
    read: i.read === true,
  };
}

export function messageItem(m: Message): Item {
  return {
    ...key.message(m.planId, m.time, m.id),
    type: 'message',
    id: m.id,
    planId: m.planId,
    authorId: m.authorId,
    text: m.text,
    time: m.time,
    ...(m.requestId ? { requestId: m.requestId } : {}),
  };
}

function toMessage(i: Item): Message {
  return {
    id: i.id as string,
    planId: i.planId as string,
    authorId: (i.authorId as string | null) ?? null,
    text: i.text as string,
    time: i.time as string,
    ...(i.requestId ? { requestId: i.requestId as string } : {}),
  };
}
