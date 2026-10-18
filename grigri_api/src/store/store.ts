// DynamoDB access: the single table's items to and from the domain's
// shapes. Writes that race (membership, answers, a double join) are
// transactions conditioned on the plan's version, which every change to a
// plan's members or requests increments. Every write of a plan, an ad,
// the ads' setting or a profile also adds an entry to the change log
// (CHANGES), which the decks' caches read (src/deck-cache.ts).
import { randomBytes } from 'node:crypto';
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
import type { AppleTokenStore, KeptAppleToken } from '../apple.js';
import type { SessionRecord, SessionStore } from '../auth.js';
import type { Subscription } from '../premium.js';
import { type Ad, type AdSettings, type AdStatus, DEFAULT_AD_SETTINGS } from '../domain/ads.js';
import type { Report } from '../domain/moderation.js';
import type { Delivery, Effects } from '../domain/rules.js';
import { type Attachment, type Climber, type DayWindow, type JoinRequest, type Location, type Message, type Notice, type Plan, type PlanPic, type Price, isOpen } from '../domain/model.js';
import type { TeamChat, TeamMessage } from '../domain/team.js';
import type { Wall } from '../domain/walls.js';
import { TEAM_NOTICE_ID, TEAM_PREVIEW } from '../domain/team.js';
import { index, key, prefix } from './keys.js';

type Item = Record<string, unknown>;
type TransactItem = NonNullable<TransactWriteCommandInput['TransactItems']>[number];

/** What a change-log entry says changed: a plan, an ad, the ads' setting, or a profile (or its kept email). */
export type ChangeKind = 'plan' | 'ad' | 'adSettings' | 'climber';

/** An entry in the change log: `key` is its sort key (its time first). */
export interface Change {
  key: string;
  kind: ChangeKind;
  id: string;
}

/** How long the log keeps an entry (TTL): the caches only look a few minutes back. */
export const CHANGE_TTL_S = 86_400;

/** A conditional write lost a race: reload and try again. */
export class Conflict extends Error {}

export interface VersionedPlan {
  plan: Plan;
  version: number;
}

export interface LoadedPlan extends VersionedPlan {
  requests: JoinRequest[];
}

export class Store implements SessionStore, AppleTokenStore {
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
        ...(s.climberId ? { climberId: s.climberId } : {}),
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
      ...(typeof Item.climberId === 'string' ? { climberId: Item.climberId } : {}),
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

  async rememberClimberId(id: string, subject: string, climberId: string): Promise<void> {
    try {
      await this.doc.send(new UpdateCommand({
        TableName: this.table,
        Key: key.session(id),
        UpdateExpression: 'SET climberId = :climberId',
        // Not if it was revoked meanwhile; only ever the session's own account's.
        ConditionExpression: 'attribute_exists(pk) AND subject = :subject',
        ExpressionAttributeValues: { ':climberId': climberId, ':subject': subject },
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
  async getClimbers(ids: Iterable<string>, consistent = false): Promise<Record<string, Climber>> {
    const items = await this.batchGet([...new Set(ids)].map((id) => key.climber(id)), consistent);
    return Object.fromEntries(items.map((i) => {
      const c = toClimber(i);
      return [c.id, c];
    }));
  }

  /**
   * Every profile (the CLIMBERS index partition). Profiles saved before
   * the index existed show once saved again, or after
   * scripts/index-climbers.sh.
   */
  async allClimbers(): Promise<Climber[]> {
    const items = await this.query({
      IndexName: index.climbers.name,
      KeyConditionExpression: 'gsi1pk = :pk',
      ExpressionAttributeValues: { ':pk': index.climbers.pk },
    });
    return items.map(toClimber);
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
          this.logged('climber', climber.id),
        ],
      }));
    } catch (e) {
      throw asConflict(e);
    }
  }

  /** Saves a profile whole. (Blocked is rbacr's role, not the profile's.) */
  async saveProfile(climber: Climber, subject: string | undefined, now: Date): Promise<void> {
    await this.doc.send(new PutCommand({ TableName: this.table, Item: climberItem(climber, subject, now) }));
    await this.noteChanges([{ kind: 'climber', id: climber.id }]);
  }

  /** The subject a profile was created for (its sign-in account). */
  async subjectOf(climberId: string): Promise<string | undefined> {
    const { Item } = await this.doc.send(new GetCommand({ TableName: this.table, Key: key.climber(climberId), ProjectionExpression: 'subject' }));
    return Item?.subject as string | undefined;
  }

  // --- Apple refresh tokens (src/apple.ts) ------------------------------------

  async putAppleToken(subject: string, token: KeptAppleToken, now: Date): Promise<void> {
    await this.doc.send(new PutCommand({
      TableName: this.table,
      Item: { ...key.appleToken(subject), type: 'appleToken', ...token, updatedAt: now.toISOString() },
    }));
  }

  async getAppleToken(subject: string): Promise<KeptAppleToken | undefined> {
    const { Item } = await this.doc.send(new GetCommand({ TableName: this.table, Key: key.appleToken(subject), ConsistentRead: true }));
    if (typeof Item?.refreshToken !== 'string') return undefined;
    return { refreshToken: Item.refreshToken, ...(typeof Item.clientId === 'string' ? { clientId: Item.clientId } : {}) };
  }

  async deleteAppleToken(subject: string): Promise<void> {
    await this.doc.send(new DeleteCommand({ TableName: this.table, Key: key.appleToken(subject) }));
  }

  /**
   * A climber's verified email from their sign-in sessions (the newest
   * that has one), for climbers whose email Grigri hasn't kept yet.
   */
  async sessionEmail(climberId: string): Promise<string | undefined> {
    const { Item } = await this.doc.send(new GetCommand({ TableName: this.table, Key: key.climber(climberId), ProjectionExpression: 'subject' }));
    const subject = Item?.subject as string | undefined;
    if (!subject) return undefined;
    const keys = await this.query({
      IndexName: index.sessions.name,
      KeyConditionExpression: 'gsi3pk = :pk',
      ExpressionAttributeValues: { ':pk': index.sessions.pk(subject) },
      ScanIndexForward: false,
    });
    const sessions = await this.batchGet(keys.map((k) => ({ pk: k.pk, sk: k.sk })));
    const withEmail = sessions
      .filter((x) => typeof x.email === 'string' && x.emailVerified === true)
      .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
    return withEmail[0]?.email as string | undefined;
  }

  // --- Premium ----------------------------------------------------------------

  async getSubscription(climberId: string): Promise<Subscription | undefined> {
    const { Item } = await this.doc.send(new GetCommand({ TableName: this.table, Key: key.premium(climberId) }));
    if (!Item) return undefined;
    const { pk: _pk, sk: _sk, type: _type, ...sub } = Item;
    return sub as unknown as Subscription;
  }

  /** Climbers' verified emails (for rbacr), by climber id; missing ones left out. */
  async getEmails(climberIds: Iterable<string>, consistent = false): Promise<Record<string, string>> {
    const items = await this.batchGet([...new Set(climberIds)].map((id) => key.email(id)), consistent);
    return Object.fromEntries(items.map((i) => [(i.pk as string).slice('CLIMBER#'.length), i.email as string]));
  }

  async putEmail(climberId: string, email: string): Promise<void> {
    await this.doc.send(new PutCommand({ TableName: this.table, Item: { ...key.email(climberId), type: 'email', email } }));
    await this.noteChanges([{ kind: 'climber', id: climberId }]);
  }

  /** Several climbers' subscriptions (missing ones left out). */
  async getSubscriptions(climberIds: Iterable<string>): Promise<Record<string, Subscription>> {
    const items = await this.batchGet([...new Set(climberIds)].map((id) => key.premium(id)));
    return Object.fromEntries(items.map((i) => [i.climberId as string, i as unknown as Subscription]));
  }

  /** Saves Stripe's or Apple's latest copy of a subscription (a climber has one at a time: the newest wins). */
  async putSubscription(sub: Subscription): Promise<void> {
    await this.doc.send(new PutCommand({ TableName: this.table, Item: { ...key.premium(sub.climberId), type: 'premium', ...sub } }));
  }

  /**
   * Ties an App Store subscription (its original transaction id) to a
   * climber, the first time it's seen; answers whose it is (the climber
   * it was first tied to: one subscription, one account).
   */
  async claimAppleSubscription(originalTransactionId: string, climberId: string, now: Date): Promise<string> {
    try {
      await this.doc.send(new PutCommand({
        TableName: this.table,
        Item: { ...key.apple(originalTransactionId), type: 'apple', climberId, createdAt: now.toISOString() },
        ConditionExpression: 'attribute_not_exists(pk)',
      }));
      return climberId;
    } catch (e) {
      if ((e as { name?: string }).name !== 'ConditionalCheckFailedException') throw e;
      const owner = await this.appleOwner(originalTransactionId);
      if (!owner) throw new Conflict('apple claim vanished');
      return owner;
    }
  }

  /**
   * Unties an App Store subscription from a deleted account (only if it's
   * still that account's), so a new account can restore it.
   */
  async releaseAppleSubscription(originalTransactionId: string, climberId: string): Promise<void> {
    try {
      await this.doc.send(new DeleteCommand({
        TableName: this.table,
        Key: key.apple(originalTransactionId),
        ConditionExpression: 'climberId = :c',
        ExpressionAttributeValues: { ':c': climberId },
      }));
    } catch (e) {
      if ((e as { name?: string }).name !== 'ConditionalCheckFailedException') throw e;
    }
  }

  /** The climber an App Store subscription is tied to, if any. */
  async appleOwner(originalTransactionId: string): Promise<string | undefined> {
    const { Item } = await this.doc.send(new GetCommand({ TableName: this.table, Key: key.apple(originalTransactionId), ConsistentRead: true }));
    return typeof Item?.climberId === 'string' ? Item.climberId : undefined;
  }

  // --- Ads --------------------------------------------------------------------

  async getAd(adId: string, consistent = false): Promise<Ad | undefined> {
    const { Item } = await this.doc.send(new GetCommand({ TableName: this.table, Key: key.ad(adId), ConsistentRead: consistent }));
    return Item ? toAd(Item) : undefined;
  }

  async putAd(ad: Ad): Promise<void> {
    await this.doc.send(new PutCommand({ TableName: this.table, Item: adItem(ad) }));
    await this.noteChanges([{ kind: 'ad', id: ad.id }]);
  }

  async deleteAd(adId: string): Promise<void> {
    await this.doc.send(new DeleteCommand({ TableName: this.table, Key: key.ad(adId) }));
    await this.noteChanges([{ kind: 'ad', id: adId }]);
  }

  /** A climber's ads, newest first. */
  async adsBy(ownerId: string): Promise<Ad[]> {
    const items = await this.query({
      IndexName: index.adsBy.name,
      KeyConditionExpression: 'gsi2pk = :pk',
      ExpressionAttributeValues: { ':pk': index.adsBy.pk(ownerId) },
      ScanIndexForward: false,
    });
    return items.map(toAd);
  }

  /** Ads in a status, newest first. */
  async adsByStatus(status: AdStatus): Promise<Ad[]> {
    const items = await this.query({
      IndexName: index.adsByStatus.name,
      KeyConditionExpression: 'gsi1pk = :pk',
      ExpressionAttributeValues: { ':pk': index.adsByStatus.pk(status) },
      ScanIndexForward: false,
    });
    return items.map(toAd);
  }

  /** The ads I skipped on the deck. */
  async skippedAdIds(climberId: string): Promise<string[]> {
    return this.climberChildren(climberId, prefix.adSkip);
  }

  /** I skipped an ad: it never shows to me again. */
  async skipAd(climberId: string, adId: string, now: Date): Promise<void> {
    await this.doc.send(new PutCommand({ TableName: this.table, Item: { ...key.adSkip(climberId, adId), type: 'adSkip', adId, time: now.toISOString() } }));
  }

  async getAdSettings(consistent = false): Promise<AdSettings> {
    const { Item } = await this.doc.send(new GetCommand({ TableName: this.table, Key: key.adSettings(), ConsistentRead: consistent }));
    return typeof Item?.every === 'number' ? { every: Item.every } : DEFAULT_AD_SETTINGS;
  }

  async putAdSettings(settings: AdSettings): Promise<void> {
    await this.doc.send(new PutCommand({ TableName: this.table, Item: { ...key.adSettings(), type: 'adSettings', ...settings } }));
    await this.noteChanges([{ kind: 'adSettings', id: 'ads' }]);
  }

  // --- Moderation: reports, blocks (specs/moderation.md) ----------------------

  async getReport(reportId: string): Promise<Report | undefined> {
    const { Item } = await this.doc.send(new GetCommand({ TableName: this.table, Key: key.report(reportId) }));
    return Item ? toReport(Item) : undefined;
  }

  /** Saves a report whole: open ones are in the open-reports index; handled ones expire a year later. */
  async putReport(report: Report): Promise<void> {
    await this.doc.send(new PutCommand({ TableName: this.table, Item: reportItem(report) }));
  }

  /** Open reports, oldest first (the first to answer). */
  async openReports(): Promise<Report[]> {
    const items = await this.query({
      IndexName: index.openReports.name,
      KeyConditionExpression: 'gsi1pk = :pk',
      ExpressionAttributeValues: { ':pk': index.openReports.pk },
    });
    return items.map(toReport);
  }

  /**
   * A climber's blocks, either way, in one query of their partition: who
   * they blocked, and who blocked them (never returned to anyone).
   */
  async blocksOf(climberId: string): Promise<{ blocked: string[]; blockedBy: string[] }> {
    const items = await this.query({
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :sk)',
      ExpressionAttributeValues: { ':pk': prefix.climber(climberId), ':sk': prefix.blocks },
      ProjectionExpression: 'sk',
    });
    const blocked: string[] = [];
    const blockedBy: string[] = [];
    for (const i of items) {
      const sk = i.sk as string;
      if (sk.startsWith(prefix.blockedBy)) blockedBy.push(sk.slice(prefix.blockedBy.length));
      else if (sk.startsWith(prefix.block)) blocked.push(sk.slice(prefix.block.length));
    }
    return { blocked, blockedBy };
  }

  /** I block them: my item and its mirror on their side, together. */
  async addBlock(blockerId: string, blockedId: string, now: Date): Promise<void> {
    const time = now.toISOString();
    await this.transact([
      { Put: { TableName: this.table, Item: { ...key.block(blockerId, blockedId), type: 'block', climberId: blockedId, time } } },
      { Put: { TableName: this.table, Item: { ...key.blockedBy(blockedId, blockerId), type: 'blockedBy', climberId: blockerId, time } } },
    ]);
  }

  async removeBlock(blockerId: string, blockedId: string): Promise<void> {
    await this.transact([
      { Delete: { TableName: this.table, Key: key.block(blockerId, blockedId) } },
      { Delete: { TableName: this.table, Key: key.blockedBy(blockedId, blockerId) } },
    ]);
  }

  /** The climbers known to be admins (each checked with rbacr before it's told anything). */
  async adminIds(): Promise<string[]> {
    const { Item } = await this.doc.send(new GetCommand({ TableName: this.table, Key: key.admins() }));
    return Item?.ids instanceof Set ? [...(Item.ids as Set<string>)] : Array.isArray(Item?.ids) ? (Item!.ids as string[]) : [];
  }

  /** Remembers an admin (a string set: adding one already there changes nothing). */
  async addAdmin(climberId: string): Promise<void> {
    await this.doc.send(new UpdateCommand({
      TableName: this.table,
      Key: key.admins(),
      UpdateExpression: 'ADD ids :id SET #type = :type',
      ExpressionAttributeNames: { '#type': 'type' },
      ExpressionAttributeValues: { ':id': new Set([climberId]), ':type': 'admins' },
    }));
  }

  /** Forgets climbers who aren't admins any more. */
  async removeAdmins(climberIds: string[]): Promise<void> {
    if (climberIds.length === 0) return;
    await this.doc.send(new UpdateCommand({
      TableName: this.table,
      Key: key.admins(),
      UpdateExpression: 'DELETE ids :ids',
      ExpressionAttributeValues: { ':ids': new Set(climberIds) },
    }));
  }

  /** An admin removes a profile's content: its bio, photo and gear photos (the name stays: the filter checks it). */
  async clearProfileContent(climberId: string): Promise<void> {
    try {
      await this.doc.send(new UpdateCommand({
        TableName: this.table,
        Key: key.climber(climberId),
        UpdateExpression: 'SET bio = :empty, gearPhotos = :none REMOVE photo',
        ConditionExpression: 'attribute_exists(pk)',
        ExpressionAttributeValues: { ':empty': '', ':none': [] },
      }));
    } catch (e) {
      if (!isConditionFailure(e)) throw e;
      return;
    }
    await this.noteChanges([{ kind: 'climber', id: climberId }]);
  }

  /** An admin clears a plan's notes (a new version, so a concurrent change reloads). */
  async clearPlanNotes(planId: string): Promise<void> {
    try {
      await this.doc.send(new TransactWriteCommand({
        TransactItems: [
          {
            Update: {
              TableName: this.table,
              Key: key.plan(planId),
              UpdateExpression: 'SET notes = :empty, version = version + :one',
              ConditionExpression: 'attribute_exists(pk)',
              ExpressionAttributeValues: { ':empty': '', ':one': 1 },
            },
          },
          this.logged('plan', planId),
        ],
      }));
    } catch (e) {
      // The plan is gone: nothing to clear.
      if (!isCheckFailure(e)) throw e;
    }
  }

  async deleteMessage(message: Message): Promise<void> {
    await this.doc.send(new DeleteCommand({ TableName: this.table, Key: key.message(message.planId, message.time, message.id) }));
  }

  // --- Plans ----------------------------------------------------------------

  async getPlan(planId: string): Promise<VersionedPlan | undefined> {
    const { Item } = await this.doc.send(new GetCommand({ TableName: this.table, Key: key.plan(planId) }));
    return Item ? { plan: toPlan(Item), version: Item.version as number } : undefined;
  }

  /** Plans by id (missing ones left out); `consistent`: strongly consistent reads. */
  async getPlans(ids: Iterable<string>, consistent = false): Promise<Plan[]> {
    const items = await this.batchGet([...new Set(ids)].map((id) => key.plan(id)), consistent);
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

  /** I passed on a plan; [left]: because I left (cancelled) it, which a refresh never undoes. */
  async addPass(climberId: string, planId: string, now: Date, left = false): Promise<void> {
    await this.doc.send(new PutCommand({
      TableName: this.table,
      Item: { ...key.pass(climberId, planId), type: 'pass', planId, time: now.toISOString(), ...(left ? { left: true } : {}) },
    }));
  }

  /** The plans I left (cancelled): passes a refresh keeps. */
  async leftPlanIds(climberId: string): Promise<string[]> {
    const items = await this.query({
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :sk)',
      FilterExpression: '#left = :yes',
      ExpressionAttributeNames: { '#left': 'left' },
      ExpressionAttributeValues: { ':pk': prefix.climber(climberId), ':sk': prefix.pass, ':yes': true },
      ProjectionExpression: 'planId',
    });
    return items.map((i) => i.planId as string);
  }

  /** Forgets the climber's passes on these plans: they're on the deck again. */
  async deletePasses(climberId: string, planIds: string[]): Promise<void> {
    await this.batchWrite(planIds.map((p) => ({ DeleteRequest: { Key: key.pass(climberId, p) } })));
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

  /**
   * The requester nudged the members: saves when, only while the request
   * is still open and nobody nudged meanwhile (`previous`: the nudgedAt it
   * was read with), so two nudges at once can't both pass the cooldown.
   * Then puts the notices.
   */
  async nudge(request: JoinRequest, previous: string | undefined, deliveries: Delivery[]): Promise<void> {
    try {
      await this.doc.send(new UpdateCommand({
        TableName: this.table,
        Key: key.request(request.planId, request.climberId),
        UpdateExpression: 'SET nudgedAt = :at',
        ConditionExpression:
          'attribute_exists(pk) AND #rejected = :false AND #joined = :false AND ' +
          (previous ? 'nudgedAt = :previous' : 'attribute_not_exists(nudgedAt)'),
        ExpressionAttributeNames: { '#rejected': 'rejected', '#joined': 'joined' },
        ExpressionAttributeValues: {
          ':at': request.nudgedAt,
          ':false': false,
          ...(previous ? { ':previous': previous } : {}),
        },
      }));
    } catch (e) {
      throw asConflict(e);
    }
    await this.deliver(deliveries);
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
    // The plan item changed (or went): the decks' caches read it again.
    items.push(this.logged('plan', planId));
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

  /** Marks my notifications read: all of them but the team chat's (opening that chat reads it). */
  async markNoticesRead(climberId: string): Promise<void> {
    const unread = (await this.notices(climberId)).filter((n) => !n.read && n.id !== TEAM_NOTICE_ID);
    await this.markRead(climberId, unread.map((n) => n.id));
  }

  /** Marks one notice read (none there: nothing). */
  async markNoticeRead(climberId: string, noticeId: string): Promise<void> {
    await this.markRead(climberId, [noticeId]);
  }

  private async markRead(climberId: string, noticeIds: string[]): Promise<void> {
    await Promise.all(noticeIds.map((noticeId) => this.doc.send(new UpdateCommand({
      TableName: this.table,
      Key: key.notice(climberId, noticeId),
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

  // --- The Grigri team chat (specs/team-chat.md) -----------------------------

  /** A climber's team chat, oldest first; only those after `afterIso` when given. */
  async teamMessages(climberId: string, afterIso?: string): Promise<TeamMessage[]> {
    const pk = prefix.team(climberId);
    const input: Omit<QueryCommandInput, 'TableName'> = afterIso
      ? {
          KeyConditionExpression: 'pk = :pk AND sk BETWEEN :from AND :to',
          ExpressionAttributeValues: { ':pk': pk, ':from': `${prefix.message}${afterIso}#\uffff`, ':to': `${prefix.message}\uffff` },
        }
      : {
          KeyConditionExpression: 'pk = :pk AND begins_with(sk, :sk)',
          ExpressionAttributeValues: { ':pk': pk, ':sk': prefix.message },
        };
    return (await this.query(input)).map(toTeamMessage);
  }

  /** Puts a team message and its chat's last message (the admins' list), in one batch: two writes. */
  async putTeamMessage(m: TeamMessage): Promise<void> {
    const chat = {
      ...key.teamChat(m.climberId),
      type: 'teamChat',
      climberId: m.climberId,
      lastTime: m.time,
      lastText: [...m.text].slice(0, TEAM_PREVIEW).join(''),
      lastFromTeam: m.fromTeam,
      gsi1pk: index.teamChats.pk,
      gsi1sk: `${m.time}#${m.climberId}`,
    };
    await this.batchWrite([{ PutRequest: { Item: teamMessageItem(m) } }, { PutRequest: { Item: chat } }]);
  }

  /** The team chats with a message, the latest first: one page of the index, at most `limit`. */
  async teamChats(limit: number): Promise<TeamChat[]> {
    const page = await this.doc.send(new QueryCommand({
      TableName: this.table,
      IndexName: index.teamChats.name,
      KeyConditionExpression: 'gsi1pk = :pk',
      ExpressionAttributeValues: { ':pk': index.teamChats.pk },
      ScanIndexForward: false,
      Limit: limit,
    }));
    return ((page.Items ?? []) as Item[]).map((i) => ({
      climberId: i.climberId as string,
      lastTime: i.lastTime as string,
      lastText: i.lastText as string,
      lastFromTeam: i.lastFromTeam === true,
    }));
  }

  /** Deletes a climber's whole team chat: its messages and its place in the admins' list. */
  async deleteTeamChat(climberId: string): Promise<void> {
    const items = await this.query({
      KeyConditionExpression: 'pk = :pk',
      ExpressionAttributeValues: { ':pk': prefix.team(climberId) },
      ProjectionExpression: 'pk, sk',
    });
    await this.batchWrite(items.map((i) => ({ DeleteRequest: { Key: { pk: i.pk, sk: i.sk } } })));
  }

  // --- Plan pics ("Your Pics") ------------------------------------------------

  /** A plan's photos, oldest first. */
  async planPics(planId: string): Promise<PlanPic[]> {
    const items = await this.query({
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :sk)',
      ExpressionAttributeValues: { ':pk': prefix.plan(planId), ':sk': prefix.pic },
    });
    return items.map(toPlanPic).sort((a, b) => (a.time < b.time ? -1 : a.time > b.time ? 1 : 0));
  }

  /** Saves a plan photo; it expires (TTL) with its object, PLAN_PIC_DAYS after it's added. */
  async putPlanPic(pic: PlanPic): Promise<void> {
    await this.doc.send(new PutCommand({ TableName: this.table, Item: planPicItem(pic) }));
  }

  async deletePlanPic(planId: string, picId: string): Promise<void> {
    await this.doc.send(new DeleteCommand({ TableName: this.table, Key: key.pic(planId, picId) }));
  }

  // --- Walls (the route finder) -----------------------------------------------

  async getWall(wallId: string): Promise<{ wall: Wall; version: number } | undefined> {
    const { Item } = await this.doc.send(new GetCommand({ TableName: this.table, Key: key.wall(wallId) }));
    return Item ? { wall: toWall(Item), version: Item.version as number } : undefined;
  }

  /**
   * Every wall (the WALLS index partition), for the lookup by distance.
   * Fine for a few thousand walls; past that, partition them by area.
   */
  async allWalls(): Promise<Wall[]> {
    const items = await this.query({
      IndexName: index.walls.name,
      KeyConditionExpression: 'gsi1pk = :pk',
      ExpressionAttributeValues: { ':pk': index.walls.pk },
    });
    return items.map(toWall);
  }

  /** Saves a wall: new (version 1), or over [previous] version (Conflict when it moved on). */
  async saveWall(wall: Wall, previous: number | null): Promise<void> {
    try {
      await this.doc.send(new PutCommand({
        TableName: this.table,
        Item: wallItem(wall, (previous ?? 0) + 1),
        ...(previous === null
          ? { ConditionExpression: 'attribute_not_exists(pk)' }
          : { ConditionExpression: 'version = :v', ExpressionAttributeValues: { ':v': previous } }),
      }));
    } catch (e) {
      throw asConflict(e);
    }
  }

  // --- Deleting an account (DELETE /api/me) ------------------------------------

  /** Deletes chat messages (by their keys). */
  async deleteMessages(messages: Pick<Message, 'planId' | 'time' | 'id'>[]): Promise<void> {
    await this.batchWrite(messages.map((m) => ({ DeleteRequest: { Key: key.message(m.planId, m.time, m.id) } })));
  }

  /**
   * Withdraws a join request: deletes it and moves the plan's version on,
   * in one transaction conditioned on the version it was read with, so an
   * answer racing it (read before) fails and reloads without it. Conflict
   * when the plan changed meanwhile.
   */
  async withdrawRequest(previous: VersionedPlan, climberId: string): Promise<void> {
    await this.transact([
      {
        Update: {
          TableName: this.table,
          Key: key.plan(previous.plan.id),
          UpdateExpression: 'SET version = :next',
          ConditionExpression: 'version = :v',
          ExpressionAttributeValues: { ':v': previous.version, ':next': previous.version + 1 },
        },
      },
      { Delete: { TableName: this.table, Key: key.request(previous.plan.id, climberId) } },
      this.logged('plan', previous.plan.id),
    ]);
  }

  /** Deletes a request item outright (its plan is gone). */
  async deleteRequest(planId: string, climberId: string): Promise<void> {
    await this.doc.send(new DeleteCommand({ TableName: this.table, Key: key.request(planId, climberId) }));
  }

  /**
   * Everything in a climber's partition: the profile, memberships, passes,
   * notices, the kept email, the Premium copy, and whatever else is ever
   * keyed to them there.
   */
  async deleteClimberItems(climberId: string): Promise<void> {
    const items = await this.query({
      KeyConditionExpression: 'pk = :pk',
      ExpressionAttributeValues: { ':pk': prefix.climber(climberId) },
      ProjectionExpression: 'pk, sk',
    });
    await this.batchWrite(items.map((i) => ({ DeleteRequest: { Key: { pk: i.pk, sk: i.sk } } })));
    // Their profile and email are gone (an ad owner's, perhaps).
    await this.noteChanges([{ kind: 'climber', id: climberId }]);
  }

  /** Unlinks a sign-in subject from its climber (the last step of deleting an account). */
  async deleteSubject(subject: string): Promise<void> {
    await this.doc.send(new DeleteCommand({ TableName: this.table, Key: key.subject(subject) }));
  }

  // --- The change log (src/deck-cache.ts) --------------------------------------

  /**
   * The log's entries after `afterIso` (a time), oldest first: one
   * strongly consistent query of its partition, so an entry is there as
   * soon as its write is.
   */
  async changesSince(afterIso: string): Promise<Change[]> {
    const items = await this.query({
      KeyConditionExpression: 'pk = :pk AND sk > :after',
      ExpressionAttributeValues: { ':pk': prefix.changes, ':after': afterIso },
      ConsistentRead: true,
    });
    return items.map((i) => ({ key: i.sk as string, kind: i.kind as ChangeKind, id: i.id as string }));
  }

  /** Adds entries to the log, after their writes (outside a transaction). */
  async noteChanges(changes: { kind: ChangeKind; id: string }[]): Promise<void> {
    await this.batchWrite(changes.map((c) => ({ PutRequest: { Item: changeItem(c.kind, c.id) } })));
  }

  /** A log entry, as part of a transaction. */
  private logged(kind: ChangeKind, id: string): TransactItem {
    return { Put: { TableName: this.table, Item: changeItem(kind, id) } };
  }

  // --- Plumbing ---------------------------------------------------------------

  /** Everything left in a plan's partition (requests, messages, pics). */
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

  private async batchGet(keys: Item[], consistent = false): Promise<Item[]> {
    const out: Item[] = [];
    for (let i = 0; i < keys.length; i += 100) {
      let pending: Item[] | undefined = keys.slice(i, i + 100);
      for (let attempt = 0; pending?.length; attempt++) {
        if (attempt > 0) await backoff(attempt);
        const res = await this.doc.send(new BatchGetCommand({ RequestItems: { [this.table]: { Keys: pending, ...(consistent ? { ConsistentRead: true } : {}) } } }));
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

/** A write's own condition failed (not a race with another transaction). */
function isCheckFailure(e: unknown): boolean {
  const name = (e as { name?: string })?.name;
  if (name === 'ConditionalCheckFailedException') return true;
  if (name !== 'TransactionCanceledException') return false;
  const reasons = (e as { CancellationReasons?: { Code?: string }[] }).CancellationReasons ?? [];
  return reasons.length === 0 || reasons.some((r) => r.Code === 'ConditionalCheckFailed');
}

function asConflict(e: unknown): unknown {
  return isConditionFailure(e) ? new Conflict('changed meanwhile') : e;
}

// --- Items <-> shapes -----------------------------------------------------------

/** A change-log entry, stamped now; expires (TTL) a day later. */
export function changeItem(kind: ChangeKind, id: string, now = new Date()): Item {
  return {
    ...key.change(now.toISOString(), kind, id, randomBytes(4).toString('hex')),
    type: 'change',
    kind,
    id,
    ttl: Math.floor(now.getTime() / 1000) + CHANGE_TTL_S,
  };
}

export function climberItem(c: Climber, subject: string | undefined, now: Date): Item {
  return {
    ...key.climber(c.id),
    type: 'climber',
    // Every profile, for the match scores' run (allClimbers).
    gsi1pk: index.climbers.pk,
    gsi1sk: c.id,
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

/** An undated plan's place in the by-start index: after every date. */
const UNDATED = '~';

export function planItem(p: Plan, version: number): Item {
  return {
    ...key.plan(p.id),
    type: 'plan',
    gsi1pk: index.byStart.pk,
    // Undated plans sort after every date ('~' after digits): always upcoming.
    gsi1sk: `${p.start ?? UNDATED}#${p.id}`,
    version,
    id: p.id,
    organizerId: p.organizerId,
    discipline: p.discipline,
    place: p.place,
    area: p.area,
    ...(p.sectorId ? { sectorId: p.sectorId } : {}),
    ...(p.lat !== undefined && p.lon !== undefined ? { lat: p.lat, lon: p.lon } : {}),
    ...(p.start && p.end ? { start: p.start, end: p.end } : {}),
    ...(p.moreDays?.length ? { moreDays: p.moreDays } : {}),
    // `type` is the item's kind, so the plan's type is `planType` (absent: private).
    ...(p.type && p.type !== 'private' ? { planType: p.type } : {}),
    ...(p.price ? { price: p.price } : {}),
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
    ...(typeof i.start === 'string' && typeof i.end === 'string' ? { start: i.start, end: i.end } : {}),
    ...(Array.isArray(i.moreDays) && i.moreDays.length ? { moreDays: i.moreDays as DayWindow[] } : {}),
    grades: i.grades as Plan['grades'],
    ...(i.planType === 'open' || i.planType === 'guided' ? { type: i.planType } : {}),
    ...(i.planType === 'guided' && i.price ? { price: i.price as Price } : {}),
    memberIds: (i.memberIds as string[]) ?? [],
    notes: (i.notes as string) ?? '',
    ...(i.demo === true ? { demo: true as const } : {}),
    ...(i.blocked === true ? { blocked: true as const } : {}),
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
    ...(r.nudgedAt ? { nudgedAt: r.nudgedAt } : {}),
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
    ...(typeof i.nudgedAt === 'string' ? { nudgedAt: i.nudgedAt } : {}),
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
    ...(m.attachment ? { attachment: { key: m.attachment.key, kind: m.attachment.kind } } : {}),
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
    ...(i.attachment ? { attachment: i.attachment as Attachment } : {}),
  };
}

export function teamMessageItem(m: TeamMessage): Item {
  return {
    ...key.teamMessage(m.climberId, m.time, m.id),
    type: 'teamMessage',
    id: m.id,
    climberId: m.climberId,
    fromTeam: m.fromTeam,
    text: m.text,
    time: m.time,
    ...(m.adminId ? { adminId: m.adminId } : {}),
  };
}

function toTeamMessage(i: Item): TeamMessage {
  return {
    id: i.id as string,
    climberId: i.climberId as string,
    fromTeam: i.fromTeam === true,
    text: i.text as string,
    time: i.time as string,
    ...(typeof i.adminId === 'string' ? { adminId: i.adminId } : {}),
  };
}

/**
 * How long a plan photo is kept: as long as chat media (the photos
 * bucket's lifecycle rules expire both 400 days after the upload).
 */
export const PLAN_PIC_DAYS = 400;

export function planPicItem(p: PlanPic): Item {
  return {
    ...key.pic(p.planId, p.id),
    type: 'pic',
    id: p.id,
    planId: p.planId,
    key: p.key,
    uploaderId: p.uploaderId,
    time: p.time,
    fromChat: p.fromChat,
    ttl: Math.floor(new Date(p.time).getTime() / 1000) + PLAN_PIC_DAYS * 86400,
  };
}

function toPlanPic(i: Item): PlanPic {
  return {
    id: i.id as string,
    planId: i.planId as string,
    key: i.key as string,
    uploaderId: i.uploaderId as string,
    time: i.time as string,
    fromChat: i.fromChat === true,
  };
}

export function wallItem(w: Wall, version: number): Item {
  return {
    ...key.wall(w.id),
    type: 'wall',
    version,
    gsi1pk: index.walls.pk,
    gsi1sk: `${w.createdAt}#${w.id}`,
    id: w.id,
    name: w.name,
    ...(w.cragId ? { cragId: w.cragId } : {}),
    lat: w.lat,
    lon: w.lon,
    views: w.views,
    routes: w.routes,
    createdBy: w.createdBy,
    createdAt: w.createdAt,
  };
}

function toWall(i: Item): Wall {
  return {
    id: i.id as string,
    name: i.name as string,
    ...(i.cragId ? { cragId: i.cragId as string } : {}),
    lat: i.lat as number,
    lon: i.lon as number,
    views: (i.views as Wall['views']) ?? [],
    routes: (i.routes as Wall['routes']) ?? [],
    createdBy: i.createdBy as string,
    createdAt: i.createdAt as string,
  };
}

/** How long a handled report is kept (TTL): a year after it was handled. */
export const REPORT_DAYS = 365;

export function reportItem(r: Report): Item {
  return {
    ...key.report(r.id),
    type: 'report',
    ...r,
    ...(r.status === 'open'
      ? { gsi1pk: index.openReports.pk, gsi1sk: `${r.time}#${r.id}` }
      : { ttl: Math.floor(new Date(r.resolvedAt ?? r.time).getTime() / 1000) + REPORT_DAYS * 86400 }),
  };
}

export function toReport(i: Item): Report {
  return {
    id: i.id as string,
    kind: i.kind as Report['kind'],
    targetId: i.targetId as string,
    ...(i.planId ? { planId: i.planId as string } : {}),
    subjectId: i.subjectId as string,
    reporterId: i.reporterId as string,
    reason: i.reason as Report['reason'],
    text: (i.text as string) ?? '',
    content: (i.content as Report['content']) ?? {},
    status: i.status as Report['status'],
    time: i.time as string,
    ...(i.resolvedAt ? { resolvedAt: i.resolvedAt as string } : {}),
    ...(i.resolvedBy ? { resolvedBy: i.resolvedBy as string } : {}),
  };
}

export function adItem(a: Ad): Item {
  return {
    ...key.ad(a.id),
    type: 'ad',
    ...a,
    gsi1pk: index.adsByStatus.pk(a.status),
    gsi1sk: `${a.createdAt}#${a.id}`,
    gsi2pk: index.adsBy.pk(a.ownerId),
    gsi2sk: `${a.createdAt}#${a.id}`,
  };
}

export function toAd(i: Item): Ad {
  return {
    id: i.id as string,
    ownerId: i.ownerId as string,
    text: (i.text as string) ?? '',
    link: i.link as string,
    ...(i.media ? { media: i.media as Ad['media'] } : {}),
    status: i.status as AdStatus,
    createdAt: i.createdAt as string,
    ...(i.reviewedAt ? { reviewedAt: i.reviewedAt as string } : {}),
  };
}
