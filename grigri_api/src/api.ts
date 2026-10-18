// The routes (specs/api.md): authorization, then the domain rules, then the
// store. Every route but GET /api/health and POST /api/session needs a
// caller (handler.ts finds it from the session token); most also need the
// caller's profile (409 "no profile" until GET /api/me creates it, from the
// Google account's name, or PUT /api/me saves it).
import { randomBytes } from 'node:crypto';
import { APPLE_SUBJECT_PREFIX, type AppleTokens, type RevokeOutcome } from './apple.js';
import { type Auth, type Caller, subjectHash } from './auth.js';
import { ApiError, badRequest, conflict, forbidden, notFound, unavailable } from './domain/errors.js';
import {
  type Climber,
  type JoinRequest,
  type PicCatalog,
  type Plan,
  type PlanPic,
  type PlanType,
  type PublicClimber,
  type Message,
  deciders,
  isOpen,
  planType,
  publicClimber,
  requestId,
  requestJson,
} from './domain/model.js';
import { type Ad, AD_STATUSES, type AdStatus, MAX_ADS_PER_OWNER, adInput, adSettingsInput, deckAds } from './domain/ads.js';
import { assertClean } from './domain/filter.js';
import { type Report, type ReportContent, reportId, reportInput } from './domain/moderation.js';
import { type PicWithCrag, type Where, picsFor } from './domain/pics.js';
import * as rules from './domain/rules.js';
import {
  IDENTITY,
  MAX_ROUTES,
  type Wall,
  addView,
  homography,
  routeInput,
  viewInput,
  wallInput,
  wallsNear,
} from './domain/walls.js';
import { MAX_TEAM_CHATS, TEAM_NOTICE_ID, type TeamMessage, forClimber } from './domain/team.js';
import { asObject, id, messageInput, parseDate, planInput, planPicKey, profileInput, teamMessageInput } from './domain/validate.js';
import { type MatchScore, type MatchScorer, pooled } from './match/aityx.js';
import { PREMIUM_PRICES, type PremiumPlan, type Subscription, isPaid, premiumOf, premiumUntil, premiumView } from './premium.js';
import { MAX_PLACE_QUERY, type PlaceSearch } from './places.js';
import { BadSignature, type Billing, subscriptionIdOf } from './stripe.js';
import {
  type AppleStatus,
  type AppleTransaction,
  type AppStoreVerify,
  APPLE_BUNDLE_ID,
  BadAppleSignature,
  NotGrigriPremium,
  appleAccountToken,
  appleRenewal,
  appleSubscription,
  appleTransaction,
} from './app-store.js';
import { matchFacts } from './match/facts.js';
import { openByPlan, othersWaiting } from './match/run.js';
import { ADMIN_ROLE, BLOCKED_ROLE, PREMIUM_ROLE, type RoleGrants, type RolesLookup } from './rbacr.js';
import { type Params, Router } from './router.js';
import { type Delivery, type Realtime, hintsFor } from './realtime.js';
import { Conflict, type LoadedPlan, type Store } from './store/store.js';

/** Why someone can't ask to join a plan with a block between them and its group: says nothing of the block. */
export const CANT_ASK = "you can't ask to join this plan";

/** The one notice each admin gets about reports (replaced by each new one, unread again). */
export const REPORTS_NOTICE_ID = 'reports';

/** Most requests a plan keeps waiting: bounds its transactions (DynamoDB takes 100 items; each join writes 3). */
export const MAX_OPEN_REQUESTS = 30;

/** A new profile's name when Google didn't give one (sessions from before names were kept). */
export const NO_NAME = 'Climber';

/** Who left, in the chat's note, when an account is deleted: never their name. */
export const DELETED_CLIMBER = 'A climber';

/** The account DELETE /api/me is deleting, as Deps.onDeleteAccount gets it. */
export interface DeletingAccount {
  /** The sign-in subject, `<iss>#<sub>` (Sign in with Apple's issuer is https://appleid.apple.com). */
  subject: string;
  /** Its climber; undefined when the profile was already gone (or never made). */
  climberId?: string;
  /** Its verified email, when known. */
  email?: string;
}

/** The deck's plans an admin's deck scores (the best first), and how many at once. */
export const SCORED_DECK = 30;
const SCORE_CONCURRENCY = 10;
/**
 * No new call to aityx after this long: with one call's own timeout (3 s),
 * the deck answers within about 7 s, under the HTTP API's 10.
 */
const SCORE_BUDGET_MS = 4000;

/** Largest photo upload (profile, gear, chat): the app downsizes them well under it. */
export const MAX_PHOTO_BYTES = 2 * 1024 * 1024;
/** Largest chat video upload. */
export const MAX_VIDEO_BYTES = 50 * 1024 * 1024;

/** Most photos a plan's "Your Pics" keeps (chat photos past it stay in the chat only). */
export const MAX_PLAN_PICS = 100;

export interface Photos {
  /**
   * A presigned POST for `key` (S3 object photos/<key>) of `contentType`,
   * at most `maxBytes`. The object is tagged pending: the bucket expires it
   * after a day unless kept.
   */
  presign(key: string, contentType: string, maxBytes: number): Promise<{ url: string; fields: Record<string, string> }>;
  /** Clears the pending tag of photos a profile or a chat message now uses; false for one that isn't there. */
  keep(key: string): Promise<boolean>;
  /** Deletes photos a profile no longer uses. */
  remove(keys: string[]): Promise<void>;
}

/** A plan's cover on the deck: a GriGri Pics photo, its crag and its credit. */
export interface DeckCover {
  key: string;
  crag: string;
  author: string;
  license: string;
}

/** GriGri Pics: Grigri's own crag photos (specs/pics.md). */
export interface GrigriPics {
  /** The catalog (pics/catalog.json); empty when there's none yet. */
  catalog(): Promise<PicCatalog>;
}

export interface Config {
  stage: string;
  version: string;
  /**
   * The stage's suffix for its own roles in rbacr: none (production,
   * local) or `-rc` (the RC, which asks production's rbacr too: its test
   * payments and test blocks must never reach production), so `premium`
   * or `premium-rc`, `blocked` or `blocked-rc`. Admin is one role for both.
   */
  roleSuffix?: string;
}

export interface Deps {
  store: Store;
  photos: Photos;
  /** GriGri Pics' catalog; none: no GriGri Pics. */
  pics?: GrigriPics;
  auth: Pick<Auth, 'signIn' | 'signOut' | 'signOutEverywhere'>;
  config: Config;
  /** Live updates' hints (realtime.ts); none: off. */
  realtime?: Realtime;
  /** My roles in Grigri, from rbacr (rbacr.ts); none: unknown. */
  roles?: RolesLookup;
  /** Grants and revokes roles in rbacr (the Stripe webhook's Premium); none: no rbacr. */
  grants?: RoleGrants;
  /** Match scores from aityx (match/aityx.ts), on admins' decks; none: off. */
  matchScorer?: MatchScorer;
  /** Stripe, for Premium (stripe.ts); none: no Premium through Stripe (no keys). */
  billing?: Billing;
  /** The App Store's JWS verifier, for Premium on iOS (app-store.ts); none: no App Store purchases. */
  appStore?: AppStoreVerify;
  /** Revokes Sign in with Apple's tokens (apple.ts); none: nothing to revoke. */
  appleTokens?: Pick<AppleTokens, 'revoke'>;
  /**
   * Runs while DELETE /api/me deletes an account, after Premium is
   * cancelled and before any of its data is deleted: where an identity
   * provider's grants are revoked (Sign in with Apple's tokens, which
   * Apple requires revoking). It must be idempotent: a retry after a
   * failure runs it again; throwing stops the deletion, to be retried.
   */
  onDeleteAccount?: (account: DeletingAccount) => Promise<void>;
  /** Finds places for ads' regions (places.ts); none: GET /api/places answers 503. */
  places?: PlaceSearch;
  /** Keeps the demo showcase upcoming (seed/seed.ts); runs before the deck. */
  showcase?: (now: Date) => Promise<void>;
  clock?: () => Date;
  /** In [0, 1): picks a new organizer when one leaves; default Math.random. */
  random?: () => number;
}

export interface Request {
  caller: Caller | null;
  params: Params;
  query: Record<string, string | undefined>;
  body: unknown;
}

/**
 * public: anyone; session: a caller, nothing loaded; caller: plus their
 * profile if any; profile: must have one; premium: and be premium (or an
 * admin); admin: and be one.
 */
export type Access = 'public' | 'session' | 'caller' | 'profile' | 'premium' | 'admin';


interface Session {
  caller: Caller;
  /** The caller's profile ('profile' and 'admin' routes always have one). */
  me: Climber;
  now: Date;
  ctx: rules.Context;
  /** Names known so far, for the chat's notes. */
  names: Map<string, string>;
}

type Handler = (req: Request, s: Session) => Promise<unknown>;

interface Route {
  access: Access;
  handler: Handler;
}

function photosOf(c: Pick<Climber, 'photo' | 'gearPhotos'>): string[] {
  return [...(c.photo ? [c.photo] : []), ...c.gearPhotos];
}

/** A URL-safe random id (16 characters, 96 bits). */
export function newId(): string {
  return randomBytes(12).toString('base64url');
}

/** Message ids that sort in creation order within one request. */
function messageIds(): () => string {
  let n = 0;
  return () => `${(n++).toString().padStart(3, '0')}${randomBytes(6).toString('base64url')}`;
}

const CONTENT_TYPES: Record<string, string> = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' };
/** What a chat can carry: photos as above, and MP4 or QuickTime videos. Nothing else. */
const VIDEO_TYPES: Record<string, string> = { 'video/mp4': 'mp4', 'video/quicktime': 'mov' };
const CHAT_TYPES: Record<string, string> = { ...CONTENT_TYPES, ...VIDEO_TYPES };

export class Api {
  private readonly router = new Router<Route>();
  private readonly store: Store;
  private readonly clock: () => Date;
  private readonly random: () => number;
  private readonly premiumRole: string;
  private readonly blockedRole: string;

  constructor(private readonly deps: Deps) {
    this.store = deps.store;
    this.clock = deps.clock ?? (() => new Date());
    this.random = deps.random ?? Math.random;
    this.premiumRole = PREMIUM_ROLE + (deps.config.roleSuffix ?? '');
    this.blockedRole = BLOCKED_ROLE + (deps.config.roleSuffix ?? '');
    const r = (pattern: string, access: Access, handler: Handler) => this.router.add(pattern, { access, handler });

    r('GET /api/health', 'public', async () => ({ ok: true, stage: deps.config.stage, version: deps.config.version }));

    r('POST /api/session', 'public', (req) => deps.auth.signIn(req.body));
    r('DELETE /api/session', 'session', async (_req, s) => {
      await deps.auth.signOut(s.caller);
      return {};
    });
    r('DELETE /api/sessions', 'session', async (_req, s) => {
      await deps.auth.signOutEverywhere(s.caller);
      return {};
    });

    r('GET /api/me', 'caller', async (_req, s) => {
      const email = s.caller.email;
      const [climber, roles] = await Promise.all([
        this.myProfile(s),
        email && deps.roles ? deps.roles(email) : Promise.resolve(null),
      ]);
      const [sub] = await Promise.all([this.store.getSubscription(climber.id), this.rememberEmail(climber.id, email)]);
      // roles: my roles in Grigri from rbacr, or null when it can't say;
      // Premium is one of them (and its billing details are my subscription's).
      const premium = premiumView(holdsPremium(roles, this.premiumRole), sub, s.now);
      // Admins are told of new reports: remembered here (best effort).
      if (s.caller.admin) await this.rememberAdmin(climber.id);
      return { climber, admin: s.caller.admin, roles, premium };
    });
    r('PUT /api/me', 'caller', (req, s) => this.saveProfile(req, s));
    // A session route: a blocked climber may delete their account too.
    r('DELETE /api/me', 'session', (req, s) => this.deleteAccount(req, s));
    r('POST /api/photos', 'caller', (req, s) => this.presignPhoto(req, s));
    r('GET /api/realtime', 'profile', async (_req, s) => deps.realtime?.info(s.me.id) ?? { url: null });

    r('GET /api/premium', 'profile', (_req, s) => this.premium(s));
    r('POST /api/premium/checkout', 'profile', (req, s) => this.checkout(req, s));
    r('POST /api/premium/portal', 'profile', (_req, s) => this.portal(s));
    r('POST /api/premium/apple', 'profile', (req, s) => this.appleTransaction(req, s));
    // The App Store's notifications: public, Apple's signature is the gate.
    r('POST /api/apple/notifications', 'public', (req) => this.appleNotification(req));

    r('GET /api/ads', 'profile', (_req, s) => this.myAds(s));
    r('POST /api/ads/media', 'profile', (req, s) => this.presignAdMedia(req, s));
    r('POST /api/ads', 'profile', (req, s) => this.createAd(req, s));
    r('DELETE /api/ads/{id}', 'profile', (req, s) => this.deleteAd(req, s));
    r('POST /api/ads/{id}/skip', 'profile', (req, s) => this.skipAd(req, s));
    r('GET /api/places', 'profile', (req, s) => this.searchPlaces(req, s));

    r('GET /api/discover', 'profile', (_req, s) => this.discover(s));
    r('POST /api/plans', 'profile', (req, s) => this.createPlan(req, s));
    r('GET /api/plans', 'profile', (_req, s) => this.myPlans(s));
    r('GET /api/plans/{id}', 'profile', (req, s) => this.getPlan(req, s));
    r('PUT /api/plans/{id}', 'profile', (req, s) => this.updatePlan(req, s));
    r('POST /api/plans/{id}/leave', 'profile', (req, s) => this.leave(req, s));
    r('POST /api/plans/{id}/join', 'profile', (req, s) => this.join(req, s));
    r('POST /api/plans/{id}/nudge', 'profile', (req, s) => this.nudge(req, s));
    r('POST /api/plans/{id}/pass', 'profile', (req, s) => this.pass(req, s));
    r('DELETE /api/passes', 'profile', (_req, s) => this.clearPasses(s));
    r('GET /api/plans/{id}/messages', 'profile', (req, s) => this.messages(req, s));
    r('POST /api/plans/{id}/messages', 'profile', (req, s) => this.send(req, s));
    r('POST /api/plans/{id}/media', 'profile', (req, s) => this.presignChatMedia(req, s));
    r('GET /api/plans/{id}/pics', 'profile', (req, s) => this.planPics(req, s));
    r('POST /api/plans/{id}/pics/upload', 'profile', (req, s) => this.presignPlanPic(req, s));
    r('POST /api/plans/{id}/pics', 'profile', (req, s) => this.addPlanPic(req, s));
    r('DELETE /api/plans/{id}/pics/{picId}', 'profile', (req, s) => this.deletePlanPic(req, s));
    r('GET /api/pics', 'profile', async (req) => ({ pics: await this.grigriPics(whereFrom(req.query)) }));

    r('GET /api/requests', 'profile', (_req, s) => this.toReview(s));
    r('POST /api/requests/{planId}/{climberId}/accept', 'profile', (req, s) => this.answer(req, s, 'accept'));
    r('POST /api/requests/{planId}/{climberId}/reject', 'profile', (req, s) => this.answer(req, s, 'reject'));
    r('POST /api/requests/{planId}/{climberId}/dismiss', 'profile', (req, s) => this.dismiss(req, s));

    r('POST /api/reports', 'profile', (req, s) => this.report(req, s));
    r('GET /api/blocks', 'profile', (_req, s) => this.myBlocks(s));
    r('POST /api/blocks/{id}', 'profile', (req, s) => this.blockSomeone(req, s));
    r('DELETE /api/blocks/{id}', 'profile', (req, s) => this.unblockSomeone(req, s));

    // The Grigri team chat (specs/team-chat.md): mine, and, for admins, everyone's.
    r('GET /api/team/messages', 'profile', (req, s) => this.myTeamMessages(req, s));
    r('POST /api/team/messages', 'profile', (req, s) => this.writeToTeam(req, s));
    r('POST /api/team/read', 'profile', async (_req, s) => {
      await this.store.markNoticeRead(s.me.id, TEAM_NOTICE_ID);
      return {};
    });

    r('GET /api/notices', 'profile', (_req, s) => this.notices(s));
    r('POST /api/notices/read', 'profile', async (_req, s) => {
      await this.store.markNoticesRead(s.me.id);
      return {};
    });

    r('GET /api/walls', 'premium', (req) => this.walls(req));
    r('POST /api/walls/photo', 'premium', (req, s) => this.presignWallPhoto(req, s));
    r('POST /api/walls', 'premium', (req, s) => this.createWall(req, s));
    r('POST /api/walls/{id}/routes', 'premium', (req, s) => this.addRoute(req, s));
    r('DELETE /api/walls/{id}/routes/{routeId}', 'premium', (req, s) => this.deleteRoute(req, s));
    r('POST /api/walls/{id}/views', 'premium', (req, s) => this.addWallView(req, s));

    r('GET /api/admin/climbers', 'admin', () => this.adminClimbers());
    r('GET /api/admin/ads', 'admin', (req) => this.adminAds(req));
    r('POST /api/admin/ads/{id}/approve', 'admin', (req, s) => this.reviewAd(req, s, 'approved'));
    r('POST /api/admin/ads/{id}/reject', 'admin', (req, s) => this.reviewAd(req, s, 'rejected'));
    r('PUT /api/admin/ads/settings', 'admin', async (req) => {
      const settings = adSettingsInput(req.body);
      await this.store.putAdSettings(settings);
      return settings;
    });
    r('POST /api/admin/climbers/{id}/block', 'admin', (req, s) => this.block(id(req.params.id, 'climber id'), s, true));
    r('POST /api/admin/climbers/{id}/unblock', 'admin', (req, s) => this.block(id(req.params.id, 'climber id'), s, false));
    r('GET /api/admin/team', 'admin', () => this.teamChats());
    r('GET /api/admin/team/{id}/messages', 'admin', (req) => this.teamChatOf(req));
    r('POST /api/admin/team/{id}/messages', 'admin', (req, s) => this.answerAsTeam(req, s));
    r('GET /api/admin/reports', 'admin', () => this.adminReports());
    r('POST /api/admin/reports/{id}/dismiss', 'admin', (req, s) => this.resolveReport(req, s, 'dismissed'));
    r('POST /api/admin/reports/{id}/remove', 'admin', (req, s) => this.resolveReport(req, s, 'removed'));
    r('POST /api/admin/reports/{id}/block', 'admin', (req, s) => this.resolveReport(req, s, 'blocked'));
  }

  /** Who may call a route (404 for no such route). */
  access(method: string, path: string): Access {
    return this.router.match(method, path).handler.access;
  }

  /** Runs a request: the route's access rule, then its handler. */
  async handle(method: string, path: string, req: Omit<Request, 'params'>): Promise<unknown> {
    const { handler: route, params } = this.router.match(method, path);
    const full: Request = { ...req, params };
    if (route.access === 'public') return route.handler(full, undefined as never);
    if (!req.caller) throw new ApiError(401, 'signed out');
    const now = this.clock();
    if (route.access === 'session') {
      const names = new Map<string, string>();
      const ctx = { now, newId: messageIds(), name: (cid: string) => names.get(cid) ?? 'Someone', random: this.random };
      return route.handler(full, { caller: req.caller, me: undefined as never, now, ctx, names });
    }
    const climberId = await this.store.climberIdFor(req.caller.subject);
    const me = climberId ? await this.store.getClimber(climberId) : undefined;
    if (!me && route.access !== 'caller') throw conflict('no profile');
    // Blocked (rbacr's role): nothing but signing out ('session' routes, above).
    if (me && (await this.isBlocked(req.caller.email))) throw forbidden('blocked');
    if (route.access === 'admin' && !req.caller.admin) throw forbidden('admins only');
    // Premium routes: rbacr's premium role (specs/premium.md; admins hold it too).
    if (route.access === 'premium' && !(await this.isPremium(req.caller.email))) throw forbidden('premium only');
    const names = new Map<string, string>();
    const session: Session = {
      caller: req.caller,
      // Undefined only on 'caller' routes, before the first GET or PUT /api/me.
      me: me as Climber,
      now,
      ctx: { now, newId: messageIds(), name: (cid) => names.get(cid) ?? 'Someone', random: this.random },
      names,
    };
    if (me) names.set(me.id, me.name);
    return route.handler(full, session);
  }

  /**
   * Revokes the climber's Sign in with Apple tokens at Apple (App Store
   * guideline 5.1.1(v)): for account deletion, before the profile (whose
   * subject it reads) is deleted. Never throws; see AppleTokens.revoke.
   */
  async revokeAppleTokens(climberId: string): Promise<RevokeOutcome> {
    return this.deps.appleTokens ? this.deps.appleTokens.revoke(climberId) : 'none';
  }

  // --- Profile and photos --------------------------------------------------

  /**
   * GET /api/me: my profile, created the first time from my Google account
   * (its name; the rest empty, for me to fill in).
   */
  private async myProfile(s: Session): Promise<Climber> {
    if (s.me) return s.me;
    const starter: Climber = {
      id: newId(),
      name: s.caller.name ?? NO_NAME,
      bio: '',
      levels: {},
      gear: [],
      gearPhotos: [],
    };
    try {
      await this.store.createProfile(s.caller.subject, starter, s.now);
      return starter;
    } catch (e) {
      if (!(e instanceof Conflict)) throw e;
      // Created meanwhile (two first loads at once): that one.
      const existing = await this.store.climberIdFor(s.caller.subject);
      const climber = existing ? await this.store.getClimber(existing) : undefined;
      if (!climber) throw e;
      return climber;
    }
  }

  private async saveProfile(req: Request, s: Session) {
    const owners = [subjectHash(s.caller.subject), ...(s.me ? [s.me.id] : [])];
    const input = profileInput(req.body, owners);
    assertClean({ name: input.name, bio: input.bio });
    // Photos: new ones lose their pending tag before the profile points at
    // them (else the bucket would expire them); ones it no longer uses are
    // deleted after it's saved.
    const before = new Set(s.me ? photosOf(s.me) : []);
    const after = new Set(photosOf(input));
    for (const key of after) {
      if (before.has(key)) continue;
      if (!(await this.deps.photos.keep(key))) throw badRequest(`photo ${key} isn't uploaded (or expired): upload it again`);
    }
    // Only ever my own folder's (defense in depth: saved keys were checked).
    const unused = [...before].filter((key) => !after.has(key) && owners.includes(key.split('/')[0]!));
    let saved: Climber;
    if (s.me) {
      saved = { id: s.me.id, ...input };
      await this.store.saveProfile(saved, s.caller.subject, s.now);
    } else {
      saved = { id: newId(), ...input };
      try {
        await this.store.createProfile(s.caller.subject, saved, s.now);
      } catch (e) {
        if (!(e instanceof Conflict)) throw e;
        // Created meanwhile (two first saves at once): update that one.
        const existing = await this.store.climberIdFor(s.caller.subject);
        if (!existing) throw e;
        saved = { ...saved, id: existing };
        await this.store.saveProfile(saved, s.caller.subject, s.now);
      }
    }
    if (unused.length > 0) {
      // Best effort: a leftover only costs storage.
      await this.deps.photos.remove(unused).catch((e: unknown) => {
        console.error(JSON.stringify({ level: 'warn', msg: 'photo cleanup failed', error: String(e) }));
      });
    }
    await this.rememberEmail(saved.id, s.caller.email);
    return { climber: saved };
  }

  private async presignPhoto(req: Request, s: Session) {
    const o = asObject(req.body);
    if (o.kind !== 'profile' && o.kind !== 'gear') throw badRequest('kind must be profile or gear');
    const ext = typeof o.contentType === 'string' && Object.hasOwn(CONTENT_TYPES, o.contentType) ? CONTENT_TYPES[o.contentType] : undefined;
    if (!ext) throw badRequest(`contentType must be one of ${Object.keys(CONTENT_TYPES).join(', ')}`);
    const key = `${subjectHash(s.caller.subject)}/${o.kind}/${newId()}.${ext}`;
    const { url, fields } = await this.deps.photos.presign(key, o.contentType as string, MAX_PHOTO_BYTES);
    return { key, url, fields };
  }

  /**
   * POST /api/plans/{id}/media: where a member uploads a photo or video for
   * the plan's chat (key `chat/<planId>/<id>.<ext>`, pending until a
   * message uses it).
   */
  private async presignChatMedia(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    const o = asObject(req.body);
    const contentType = typeof o.contentType === 'string' ? o.contentType : '';
    const ext = Object.hasOwn(CHAT_TYPES, contentType) ? CHAT_TYPES[contentType] : undefined;
    if (!ext) throw badRequest(`contentType must be one of ${Object.keys(CHAT_TYPES).join(', ')}`);
    const current = await this.store.getPlan(planId);
    if (!current) throw notFound('no such plan');
    if (!current.plan.memberIds.includes(s.me.id)) throw forbidden("you're not in this plan");
    const key = `chat/${planId}/${newId()}.${ext}`;
    const maxBytes = Object.hasOwn(VIDEO_TYPES, contentType) ? MAX_VIDEO_BYTES : MAX_PHOTO_BYTES;
    const { url, fields } = await this.deps.photos.presign(key, contentType, maxBytes);
    return { key, url, fields, maxBytes };
  }

  // --- Plan pics: "Your Pics" and GriGri Pics ----------------------------------

  /**
   * GET /api/plans/{id}/pics: the plan's GriGri Pics (anyone who can see
   * the plan) and, for members, its "Your Pics".
   */
  private async planPics(req: Request, s: Session) {
    const current = await this.store.getPlan(id(req.params.id, 'plan id'));
    if (!current) throw notFound('no such plan');
    const { plan } = current;
    const member = plan.memberIds.includes(s.me.id);
    const [yours, grigri] = await Promise.all([
      member ? this.store.planPics(plan.id) : Promise.resolve([] as PlanPic[]),
      this.grigriPics({ sectorId: plan.sectorId, lat: plan.lat, lon: plan.lon, place: plan.place, area: plan.area }),
    ]);
    return { yours, grigri, member, climbers: await this.publicClimbers(new Set(yours.map((p) => p.uploaderId))) };
  }

  /** GriGri Pics for a place; none (never an error) when the catalog can't be read. */
  private async grigriPics(where: Where): Promise<PicWithCrag[]> {
    if (!this.deps.pics) return [];
    try {
      return picsFor(await this.deps.pics.catalog(), where);
    } catch (e) {
      console.error(JSON.stringify({ level: 'warn', msg: 'pics catalog failed', error: String(e) }));
      return [];
    }
  }

  /** POST /api/plans/{id}/pics/upload: where a member uploads a photo for the plan (`plans/<planId>/<id>.<ext>`, pending until added). */
  private async presignPlanPic(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    const o = asObject(req.body);
    const ext = typeof o.contentType === 'string' && Object.hasOwn(CONTENT_TYPES, o.contentType) ? CONTENT_TYPES[o.contentType] : undefined;
    if (!ext) throw badRequest(`contentType must be one of ${Object.keys(CONTENT_TYPES).join(', ')}`);
    await this.memberPlan(planId, s);
    const key = `plans/${planId}/${newId()}.${ext}`;
    const { url, fields } = await this.deps.photos.presign(key, o.contentType as string, MAX_PHOTO_BYTES);
    return { key, url, fields, maxBytes: MAX_PHOTO_BYTES };
  }

  /** POST /api/plans/{id}/pics: a member adds an uploaded photo to the plan. */
  private async addPlanPic(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    const key = planPicKey(asObject(req.body).key, planId);
    const plan = await this.memberPlan(planId, s);
    const pics = await this.store.planPics(planId);
    if (pics.length >= MAX_PLAN_PICS) throw conflict(`a plan keeps at most ${MAX_PLAN_PICS} photos; delete one first`);
    const existing = pics.find((p) => p.key === key);
    if (existing) return { pic: existing };
    if (!(await this.deps.photos.keep(key))) throw badRequest("the photo isn't uploaded (or expired): upload it again");
    const pic: PlanPic = { id: newId(), planId, key, uploaderId: s.me.id, time: s.now.toISOString(), fromChat: false };
    await this.store.putPlanPic(pic);
    await this.hint(hintsFor(plan.memberIds, { kind: 'pics', planId }, s.me.id));
    return { pic };
  }

  /**
   * DELETE /api/plans/{id}/pics/{picId}: whoever added it, the organizer or
   * an admin. A photo added here is deleted; a chat photo stays in the chat.
   */
  private async deletePlanPic(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    const picId = id(req.params.picId, 'pic id');
    const current = await this.store.getPlan(planId);
    if (!current) throw notFound('no such plan');
    const { plan } = current;
    if (!plan.memberIds.includes(s.me.id) && !s.caller.admin) throw forbidden("you're not in this plan");
    const pic = (await this.store.planPics(planId)).find((p) => p.id === picId);
    if (!pic) throw notFound('no such photo');
    if (pic.uploaderId !== s.me.id && plan.organizerId !== s.me.id && !s.caller.admin) {
      throw forbidden('only whoever added it, or the organizer, can delete it');
    }
    await this.store.deletePlanPic(planId, picId);
    if (!pic.fromChat) {
      // Best effort: a leftover only costs storage, and expires anyway.
      await this.deps.photos.remove([pic.key]).catch((e: unknown) => {
        console.error(JSON.stringify({ level: 'warn', msg: 'plan pic cleanup failed', error: String(e) }));
      });
    }
    await this.hint(hintsFor(plan.memberIds, { kind: 'pics', planId }, s.me.id));
    return {};
  }

  /** A plan I'm in (404: none; 403: not mine). */
  private async memberPlan(planId: string, s: Session): Promise<Plan> {
    const current = await this.store.getPlan(planId);
    if (!current) throw notFound('no such plan');
    if (!current.plan.memberIds.includes(s.me.id)) throw forbidden("you're not in this plan");
    return current.plan;
  }

  // --- The route finder: walls and their routes ------------------------------------

  /** GET /api/walls?lat=&lon=: the walls near a point, nearest first. */
  private async walls(req: Request) {
    const where = whereFrom(req.query);
    if (where.lat === undefined || where.lon === undefined) throw badRequest('lat and lon are required');
    const walls = wallsNear(await this.store.allWalls(), { lat: where.lat, lon: where.lon });
    const ids = new Set(walls.flatMap((w) => [w.createdBy, ...w.routes.map((r) => r.addedBy)]));
    return { walls, climbers: await this.publicClimbers(ids) };
  }

  /** My own folder's key prefixes (wall photos are `walls/<owner>/...`). */
  private owners(s: Session): string[] {
    return [subjectHash(s.caller.subject), s.me.id];
  }

  /** POST /api/walls/photo: where to upload a wall's reference photo (pending until a wall or view uses it). */
  private async presignWallPhoto(req: Request, s: Session) {
    const o = asObject(req.body);
    const ext = typeof o.contentType === 'string' && Object.hasOwn(CONTENT_TYPES, o.contentType) ? CONTENT_TYPES[o.contentType] : undefined;
    if (!ext) throw badRequest(`contentType must be one of ${Object.keys(CONTENT_TYPES).join(', ')}`);
    const key = `walls/${subjectHash(s.caller.subject)}/${newId()}.${ext}`;
    const { url, fields } = await this.deps.photos.presign(key, o.contentType as string, MAX_PHOTO_BYTES);
    return { key, url, fields, maxBytes: MAX_PHOTO_BYTES };
  }

  /** POST /api/walls: a new wall, from its first reference photo. */
  private async createWall(req: Request, s: Session) {
    const input = wallInput(req.body, this.owners(s));
    await this.keepPhoto(input.view.key);
    const time = s.now.toISOString();
    const wall: Wall = {
      id: newId(),
      name: input.name,
      ...(input.cragId ? { cragId: input.cragId } : {}),
      lat: input.lat,
      lon: input.lon,
      views: [{ ...input.view, h: IDENTITY, addedBy: s.me.id, time }],
      routes: [],
      createdBy: s.me.id,
      createdAt: time,
    };
    await this.store.saveWall(wall, null);
    return { wall };
  }

  /** POST /api/walls/{id}/routes: a route drawn on the wall, bolt by bolt. */
  private async addRoute(req: Request, s: Session) {
    const input = routeInput(req.body);
    return this.changeWall(req.params.id, (wall) => {
      if (wall.routes.length >= MAX_ROUTES) throw conflict(`a wall keeps at most ${MAX_ROUTES} routes`);
      const route = { id: newId(), ...input, addedBy: s.me.id, time: s.now.toISOString() };
      return { ...wall, routes: [...wall.routes, route] };
    });
  }

  /** DELETE /api/walls/{id}/routes/{routeId}: whoever drew it, or an admin. */
  private async deleteRoute(req: Request, s: Session) {
    const routeId = id(req.params.routeId, 'route id');
    return this.changeWall(req.params.id, (wall) => {
      const route = wall.routes.find((r) => r.id === routeId);
      if (!route) throw notFound('no such route');
      if (route.addedBy !== s.me.id && !s.caller.admin) throw forbidden('only whoever drew it can delete it');
      return { ...wall, routes: wall.routes.filter((r) => r.id !== routeId) };
    });
  }

  /**
   * POST /api/walls/{id}/views: the app learns the wall: a photo of it
   * seen and confirmed, with its transform to the first view, so it's
   * recognized from there (another angle, other light) too. Past
   * MAX_VIEWS the oldest learned view goes.
   */
  private async addWallView(req: Request, s: Session) {
    const o = asObject(req.body);
    const view = viewInput(o, this.owners(s));
    const h = homography(o.h);
    await this.keepPhoto(view.key);
    let dropped: string | undefined;
    const result = await this.changeWall(req.params.id, (wall) => {
      const out = addView(wall, { ...view, h, addedBy: s.me.id, time: s.now.toISOString() });
      dropped = out.dropped?.key;
      return out.wall;
    });
    if (dropped) {
      await this.deps.photos.remove([dropped]).catch((e: unknown) => {
        console.error(JSON.stringify({ level: 'warn', msg: 'wall view cleanup failed', error: String(e) }));
      });
    }
    return result;
  }

  private async keepPhoto(key: string): Promise<void> {
    if (!(await this.deps.photos.keep(key))) throw badRequest("the photo isn't uploaded (or expired): upload it again");
  }

  /** Reads, changes and saves a wall, again if someone changed it meanwhile. */
  private async changeWall(rawId: string | undefined, change: (wall: Wall) => Wall) {
    const wallId = id(rawId, 'wall id');
    return this.retry(async () => {
      const current = await this.store.getWall(wallId);
      if (!current) throw notFound('no such wall');
      const wall = change(current.wall);
      await this.store.saveWall(wall, current.version);
      return { wall };
    });
  }

  // --- Deleting my account (specs/sign-in.md#deleting-my-account) -----------

  /**
   * DELETE /api/me {"confirm": true}: deletes my account for good. Each
   * step can run again, so a retry after a failure finishes the job; the
   * sign-in subject's link to my climber and my sessions go last, so a
   * retry still finds what's left.
   */
  private async deleteAccount(req: Request, s: Session) {
    if (asObject(req.body).confirm !== true) throw badRequest('send {"confirm": true} to delete your account for good');
    const subject = s.caller.subject;
    const climberId = await this.store.climberIdFor(subject);
    if (climberId) {
      await this.deleteClimber(climberId, s);
    } else {
      await this.deps.onDeleteAccount?.({ subject, ...(s.caller.email ? { email: s.caller.email } : {}) });
    }
    await this.store.deleteSubject(subject);
    // A Sign in with Apple refresh token kept for revocation goes with it.
    if (subject.startsWith(APPLE_SUBJECT_PREFIX)) await this.store.deleteAppleToken(subject);
    // Signed out everywhere, this device too.
    await this.deps.auth.signOutEverywhere(s.caller);
    console.log(JSON.stringify({ level: 'info', msg: 'account deleted' }));
    return {};
  }

  private async deleteClimber(climberId: string, s: Session): Promise<void> {
    const subject = s.caller.subject;
    const [me, sub, kept] = await Promise.all([
      this.store.getClimber(climberId),
      this.store.getSubscription(climberId),
      this.store.getEmails([climberId]),
    ]);
    const email = s.caller.email ?? kept[climberId];
    // 1. Premium: Stripe stops charging at once (no refund of the period
    // paid), then rbacr's role goes. Either failing stops here: nothing is
    // deleted while I could still be charged.
    // An App Store subscription can't be cancelled by Grigri (the person
    // does, in iOS Settings, as the confirmation says): it's untied from
    // this account, so a new one can restore it.
    if (sub?.source === 'apple') {
      await this.store.releaseAppleSubscription(sub.subscriptionId, climberId);
    } else if (sub && sub.status !== 'canceled' && sub.status !== 'incomplete_expired') {
      if (!this.deps.billing) throw unavailable("your Premium subscription can't be cancelled right now; try again later");
      await this.deps.billing.cancel(sub.subscriptionId);
      // So a retry doesn't ask Stripe again.
      await this.store.putSubscription({ ...sub, status: 'canceled', updatedAt: s.now.toISOString() });
    }
    const grants = this.deps.grants;
    if (grants) {
      for (const e of new Set([email, sub?.email].filter((x): x is string => !!x))) await grants.revoke(e, this.premiumRole);
    }
    // 2. The sign-in provider's own grants: Sign in with Apple's tokens,
    // which Apple requires revoking (never throws: a failure is logged, and
    // the account is still deleted), then any other provider's.
    await this.revokeAppleTokens(climberId);
    await this.deps.onDeleteAccount?.({ subject, climberId, ...(email ? { email } : {}) });
    // 3. What I wrote and added in every plan I'm in, left or asked to join.
    const [memberOf, left, asked] = await Promise.all([
      this.store.memberPlanIds(climberId),
      this.store.leftPlanIds(climberId),
      this.store.askedRequests(climberId),
    ]);
    for (const planId of new Set([...memberOf, ...left, ...asked.map((r) => r.planId)])) {
      await this.eraseFromPlan(planId, climberId);
    }
    // 4. Out of my plans, as leaving does: the organizer hands over, or the
    // last member ends the plan. The note doesn't name me.
    s.names.set(climberId, DELETED_CLIMBER);
    for (const planId of memberOf) await this.leaveForGood(planId, climberId, s);
    // 5. My join requests, whatever became of them.
    for (const r of await this.store.askedRequests(climberId)) await this.withdraw(r, climberId);
    // 6. My ads, with their media.
    for (const ad of await this.store.adsBy(climberId)) {
      if (ad.media) await this.deps.photos.remove([ad.media.key]);
      await this.store.deleteAd(ad.id);
    }
    // 7. Blocks, both ways (specs/moderation.md): the mirror items live in
    // the other climbers' partitions, so nobody's list keeps me. I'm no
    // longer a known admin either.
    const blocks = await this.store.blocksOf(climberId);
    for (const other of blocks.blocked) await this.store.removeBlock(climberId, other);
    for (const other of blocks.blockedBy) await this.store.removeBlock(other, climberId);
    await this.store.removeAdmins([climberId]);
    // 8. My Grigri team chat: what I wrote and the team's answers.
    await this.store.deleteTeamChat(climberId);
    // 9. My profile's photos (only ever my own folder's), then everything
    // keyed to me: profile, memberships, passes, notices, email, Premium.
    if (me) {
      const owners = [subjectHash(subject), climberId];
      const photos = photosOf(me).filter((k) => owners.includes(k.split('/')[0]!));
      if (photos.length > 0) await this.deps.photos.remove(photos);
    }
    await this.store.deleteClimberItems(climberId);
  }

  /** My messages (and their media), my request's note and my photos in a plan's chat and Your Pics. */
  private async eraseFromPlan(planId: string, climberId: string): Promise<void> {
    const current = await this.store.getPlan(planId);
    if (!current) return;
    const [messages, pics] = await Promise.all([this.store.messages(planId), this.store.planPics(planId)]);
    const myRequest = requestId(planId, climberId);
    const mine = messages.filter((m) => m.authorId === climberId || m.requestId === myRequest);
    const myPics = pics.filter((p) => p.uploaderId === climberId);
    const keys = [...new Set([...mine.flatMap((m) => (m.attachment ? [m.attachment.key] : [])), ...myPics.map((p) => p.key)])];
    for (let i = 0; i < keys.length; i += 20) await this.deps.photos.remove(keys.slice(i, i + 20));
    for (const p of myPics) await this.store.deletePlanPic(planId, p.id);
    if (mine.length > 0) await this.store.deleteMessages(mine);
    const others = current.plan.memberIds;
    await this.hint([
      ...(mine.length > 0 ? hintsFor(others, { kind: 'message', planId }, climberId) : []),
      ...(myPics.length > 0 ? hintsFor(others, { kind: 'pics', planId }, climberId) : []),
    ]);
  }

  /** Leaves a plan as POST /api/plans/{id}/leave does (none: not in it any more). */
  private async leaveForGood(planId: string, climberId: string, s: Session): Promise<void> {
    const members = await this.retry(async () => {
      const loaded = await this.store.loadPlan(planId);
      if (!loaded || !loaded.plan.memberIds.includes(climberId)) return null;
      await this.loadNames(s, loaded.plan.memberIds, loaded.requests.map((r) => r.climberId));
      const effects = rules.leave(loaded, climberId, s.ctx);
      await this.store.apply(loaded, effects, s.now);
      return effects.plan?.memberIds ?? [];
    });
    if (members) await this.hint(hintsFor(members, { kind: 'plan', planId }, climberId));
  }

  /** Withdraws my request: gone, and an answer racing it fails (the plan's version moves on). */
  private async withdraw(request: JoinRequest, climberId: string): Promise<void> {
    await this.retry(async () => {
      const current = await this.store.getPlan(request.planId);
      if (!current) return this.store.deleteRequest(request.planId, climberId);
      await this.store.withdrawRequest(current, climberId);
      if (isOpen(request)) await this.hint(hintsFor(current.plan.memberIds, { kind: 'request', planId: request.planId }, climberId));
    });
  }

  // --- Premium (specs/premium.md) --------------------------------------------

  /**
   * GET /api/premium: mine, Stripe's prices (null when Premium can't be
   * bought through Stripe here: no keys), and the appAccountToken the iOS
   * app buys with (null without App Store purchases).
   */
  private async premium(s: Session) {
    // Fresh from rbacr: the app asks right after paying.
    const [roles, sub] = await Promise.all([this.rolesOf(s.caller.email, true), this.store.getSubscription(s.me.id)]);
    const premium = premiumView(holdsPremium(roles, this.premiumRole), sub, s.now);
    return {
      premium,
      prices: this.deps.billing ? PREMIUM_PRICES : null,
      appleAccountToken: this.deps.appStore ? appleAccountToken(s.me.id) : null,
    };
  }

  /** POST /api/premium/checkout {plan}: Stripe Checkout's page for it, to open in a browser. */
  private async checkout(req: Request, s: Session) {
    const billing = this.deps.billing;
    if (!billing) throw unavailable("Premium isn't available yet");
    const plan = asObject(req.body).plan;
    if (plan !== 'monthly' && plan !== 'yearly') throw badRequest('plan must be monthly or yearly');
    // Premium is a role in rbacr, by email: no verified email, no Premium.
    const email = s.caller.email;
    if (!email) throw badRequest('Premium needs a verified email');
    const current = await this.store.getSubscription(s.me.id);
    if (premiumOf(current, s.now).active) throw conflict("you're already Premium");
    return { url: await billing.checkout(s.me.id, plan as PremiumPlan, current?.customerId || undefined, email) };
  }

  /** POST /api/premium/portal: Stripe's billing portal, to cancel or change the card. */
  private async portal(s: Session) {
    const billing = this.deps.billing;
    if (!billing) throw unavailable("Premium isn't available yet");
    const current = await this.store.getSubscription(s.me.id);
    if (current?.source === 'apple') throw notFound('no Stripe subscription: manage it in the App Store');
    if (!current?.customerId) throw notFound('no subscription');
    return { url: await billing.portal(current.customerId) };
  }

  /**
   * POST /api/premium/apple {transaction}: a StoreKit 2 transaction the
   * iOS app bought or restored (its signed JWS). Verified offline
   * (app-store.ts); it must be Grigri's, one of the two products, bought with
   * my appAccountToken, and its subscription not tied to another account.
   * Saved as my subscription, and rbacr's role follows. → GET /api/premium.
   */
  private async appleTransaction(req: Request, s: Session) {
    const verify = this.deps.appStore;
    if (!verify) throw unavailable("Premium isn't available yet");
    let tx: AppleTransaction;
    try {
      tx = appleTransaction(verify(asObject(req.body).transaction));
    } catch (e) {
      if (e instanceof BadAppleSignature) throw badRequest('bad signature');
      if (e instanceof NotGrigriPremium) throw badRequest(e.message);
      throw e;
    }
    if (tx.appAccountToken !== appleAccountToken(s.me.id)) {
      throw conflict('this App Store purchase was made from another Grigri account');
    }
    const owner = await this.store.claimAppleSubscription(tx.originalTransactionId, s.me.id, s.now);
    if (owner !== s.me.id) throw conflict('this App Store subscription belongs to another Grigri account');
    const current = await this.store.getSubscription(s.me.id);
    const same = current?.source === 'apple' && current.subscriptionId === tx.originalTransactionId;
    const sub = appleSubscription(s.me.id, tx, {
      now: s.now,
      signedDate: tx.signedDate,
      // A transaction doesn't say whether it renews; the last notification did.
      cancelAtPeriodEnd: same ? current.cancelAtPeriodEnd : false,
      email: s.caller.email ?? (same ? current.email : undefined),
    });
    await this.saveApple(sub, current, s.now);
    return this.premium(s);
  }

  /**
   * POST /api/apple/notifications {signedPayload}: App Store Server
   * Notifications V2. Public: Apple's signature, checked offline, is the
   * only gate. The subscription's state comes from the signed transaction
   * and renewal info inside; an older notification never overwrites a
   * newer one (Apple's signedDate), and the same one twice changes
   * nothing. One about a subscription Grigri doesn't know yet is
   * acknowledged and left: the app sends the transaction itself.
   */
  private async appleNotification(req: Request) {
    const verify = this.deps.appStore;
    if (!verify) throw unavailable('no App Store purchases');
    const now = this.clock();
    let type = '';
    let subtype = '';
    const ignore = (reason: string) => {
      console.error(JSON.stringify({ level: 'info', msg: 'apple notification ignored', type, subtype, reason }));
      return { received: true };
    };
    let notification: Record<string, unknown>;
    let tx: AppleTransaction;
    let renewal;
    try {
      notification = verify(asObject(req.body).signedPayload);
      type = String(notification.notificationType ?? '');
      subtype = String(notification.subtype ?? '');
      const data = (notification.data ?? {}) as Record<string, unknown>;
      if (data.bundleId !== APPLE_BUNDLE_ID) return ignore('another app');
      // TEST, and notifications about no transaction.
      if (typeof data.signedTransactionInfo !== 'string') return ignore('no transaction');
      tx = appleTransaction(verify(data.signedTransactionInfo));
      renewal = typeof data.signedRenewalInfo === 'string' ? appleRenewal(verify(data.signedRenewalInfo)) : undefined;
    } catch (e) {
      if (e instanceof BadAppleSignature) throw badRequest('bad signature');
      if (e instanceof NotGrigriPremium) return ignore(e.message);
      throw e;
    }
    if (renewal && renewal.originalTransactionId !== tx.originalTransactionId) throw badRequest('renewal info for another subscription');
    const climberId = await this.store.appleOwner(tx.originalTransactionId);
    if (!climberId) return ignore('unknown subscription');
    // Bought for another account than the one it's tied to: never theirs.
    if (tx.appAccountToken && tx.appAccountToken !== appleAccountToken(climberId)) return ignore('account token mismatch');
    const data = notification.data as Record<string, unknown>;
    const status = [1, 2, 3, 4, 5].includes(Number(data.status)) ? (Number(data.status) as AppleStatus) : undefined;
    const forced =
      type === 'REFUND' || type === 'REVOKE' ? 'canceled' : type === 'EXPIRED' || type === 'GRACE_PERIOD_EXPIRED' ? 'expired' : undefined;
    const signedDate = typeof notification.signedDate === 'number' ? notification.signedDate : tx.signedDate;
    const current = await this.store.getSubscription(climberId);
    const same = current?.source === 'apple' && current.subscriptionId === tx.originalTransactionId;
    const sub = appleSubscription(climberId, tx, {
      now,
      signedDate,
      status,
      renewal,
      forced,
      cancelAtPeriodEnd: same ? current.cancelAtPeriodEnd : false,
      email: same ? current.email : undefined,
    });
    await this.saveApple(sub, current, now);
    return { received: true };
  }

  /**
   * Saves an App Store subscription unless what's saved is newer: the same
   * subscription signed later by Apple, or another one still paid while
   * this one isn't. Then rbacr's role follows (an error answers 500, so
   * Apple sends the notification again).
   */
  private async saveApple(sub: Subscription, current: Subscription | undefined, now: Date): Promise<void> {
    const same = current?.source === 'apple' && current.subscriptionId === sub.subscriptionId;
    if (same && current.appleSignedAt && Date.parse(current.appleSignedAt) > Date.parse(sub.appleSignedAt!)) return;
    // Paid now, not merely a paying status: an old grace period long over
    // never displaces a live subscription.
    if (current && !same && premiumOf(current, now).active && !premiumOf(sub, now).active) return;
    await this.store.putSubscription(sub);
    await this.syncPremium(sub, now);
  }

  /**
   * POST /api/stripe/webhook (handler.ts passes the raw body): a signed
   * event from Stripe. The subscription it's about is read back from
   * Stripe and saved, so the copy is Stripe's latest whatever the order of
   * events. An older subscription never overwrites a newer paid one.
   */
  async stripeWebhook(rawBody: string, signature: string | undefined): Promise<unknown> {
    const billing = this.deps.billing;
    if (!billing) throw unavailable('no billing');
    const now = this.clock();
    let event;
    try {
      event = billing.event(rawBody, signature, now);
    } catch (e) {
      if (e instanceof BadSignature || e instanceof SyntaxError) throw badRequest('bad signature');
      throw e;
    }
    const subscriptionId = subscriptionIdOf(event);
    if (!subscriptionId) return { received: true };
    const sub = await billing.subscription(subscriptionId, now);
    // Not Grigri Premium (another product on the account): nothing to do.
    if (!sub) return { received: true };
    // Its account was deleted (which cancelled it and revoked the role):
    // nothing of theirs is kept again.
    if (!(await this.store.getClimber(sub.climberId))) return { received: true };
    const current = await this.store.getSubscription(sub.climberId);
    const stale = current && current.subscriptionId !== sub.subscriptionId && isPaid(current.status) && !isPaid(sub.status);
    if (stale) return { received: true };
    const saved: Subscription = { ...sub, ...(sub.email || !current?.email ? {} : { email: current.email }) };
    await this.store.putSubscription(saved);
    // The role in rbacr follows (an error here answers 500: Stripe sends
    // the event again).
    await this.syncPremium(saved, now);
    return { received: true };
  }

  /**
   * rbacr's premium role for a subscription: granted until its paid
   * period's end plus the grace while paid (each renewal moves the end),
   * revoked once it isn't.
   */
  private async syncPremium(sub: Subscription, now: Date): Promise<void> {
    const grants = this.deps.grants;
    const email = sub.email ?? (await this.store.getEmails([sub.climberId]))[sub.climberId];
    if (!grants || !email) {
      console.error(JSON.stringify({ level: 'warn', msg: 'premium not synced to rbacr', reason: grants ? 'no email' : 'no rbacr', climberId: sub.climberId }));
      return;
    }
    if (premiumOf(sub, now).active) await grants.grant(email, this.premiumRole, premiumUntil(sub));
    else await grants.revoke(email, this.premiumRole);
  }

  /** My (or someone's) roles in Grigri, from rbacr; null when it can't say. */
  private async rolesOf(email: string | undefined, fresh = false): Promise<string[] | null> {
    if (!email || !this.deps.roles) return null;
    return this.deps.roles(email, { fresh });
  }

  /** Whether rbacr says this email holds Premium (fails closed). */
  private async isPremium(email: string | undefined, fresh = false): Promise<boolean> {
    return holdsPremium(await this.rolesOf(email, fresh), this.premiumRole);
  }

  /** Keeps my verified email (private), so Grigri can ask rbacr about me when I'm not the caller. */
  private async rememberEmail(climberId: string, email: string | undefined): Promise<void> {
    if (!email) return;
    const known = (await this.store.getEmails([climberId]))[climberId];
    if (known !== email) await this.store.putEmail(climberId, email);
  }

  // --- Ads (specs/ads.md) ------------------------------------------------------

  /** GET /api/ads: my ads, newest first, and whether I'm Premium (to add more). */
  private async myAds(s: Session) {
    const [ads, premium] = await Promise.all([this.store.adsBy(s.me.id), this.isPremium(s.caller.email)]);
    return { ads, premium };
  }

  /** POST /api/ads/media {contentType}: where a Premium climber uploads an ad's photo or video (`ads/<me>/<id>.<ext>`, pending until the ad is saved). */
  private async presignAdMedia(req: Request, s: Session) {
    const contentType = asObject(req.body).contentType;
    const ext = typeof contentType === 'string' && Object.hasOwn(CHAT_TYPES, contentType) ? CHAT_TYPES[contentType] : undefined;
    if (!ext) throw badRequest(`contentType must be one of ${Object.keys(CHAT_TYPES).join(', ')}`);
    if (!(await this.isPremium(s.caller.email))) throw forbidden('ads are for Premium');
    const key = `ads/${s.me.id}/${newId()}.${ext}`;
    const maxBytes = Object.hasOwn(VIDEO_TYPES, contentType as string) ? MAX_VIDEO_BYTES : MAX_PHOTO_BYTES;
    const { url, fields } = await this.deps.photos.presign(key, contentType as string, maxBytes);
    return { key, url, fields, maxBytes };
  }

  /** POST /api/ads {text, link, media?}: a Premium climber's new ad, waiting for an admin. */
  private async createAd(req: Request, s: Session) {
    const input = adInput(req.body, s.me.id);
    assertClean({ text: input.text, regions: input.regions?.map((r) => r.name).join('\n') });
    if (!(await this.isPremium(s.caller.email))) throw forbidden('ads are for Premium');
    if ((await this.store.adsBy(s.me.id)).length >= MAX_ADS_PER_OWNER) {
      throw conflict(`you can keep at most ${MAX_ADS_PER_OWNER} ads; delete one first`);
    }
    if (input.media && !(await this.deps.photos.keep(input.media.key))) {
      throw badRequest("the photo or video isn't uploaded (or expired): upload it again");
    }
    const ad: Ad = { id: newId(), ownerId: s.me.id, ...input, status: 'pending', createdAt: s.now.toISOString() };
    await this.store.putAd(ad);
    return { ad };
  }

  /** GET /api/places?q=&lang=: places for an ad's regions (Premium only: only advertisers need it). */
  private async searchPlaces(req: Request, s: Session) {
    const q = (req.query.q ?? '').trim();
    if (q.length < 2 || q.length > MAX_PLACE_QUERY) throw badRequest(`q must be 2 to ${MAX_PLACE_QUERY} characters`);
    const lang = /^[a-z]{2}$/.test(req.query.lang ?? '') ? req.query.lang! : 'en';
    if (!(await this.isPremium(s.caller.email))) throw forbidden('ads are for Premium');
    if (!this.deps.places) throw unavailable('place search is off');
    try {
      return { places: await this.deps.places(q, lang) };
    } catch (e) {
      console.error(JSON.stringify({ level: 'warn', msg: 'place search failed', error: String(e) }));
      throw unavailable("the place search didn't answer; try again");
    }
  }

  /** DELETE /api/ads/{id}: its owner (or an admin) takes it down for good, with its media. */
  private async deleteAd(req: Request, s: Session) {
    const ad = await this.store.getAd(id(req.params.id, 'ad id'));
    if (!ad) throw notFound('no such ad');
    if (ad.ownerId !== s.me.id && !s.caller.admin) throw forbidden('not your ad');
    await this.store.deleteAd(ad.id);
    if (ad.media) {
      // Best effort: a leftover only costs storage.
      await this.deps.photos.remove([ad.media.key]).catch((e: unknown) => {
        console.error(JSON.stringify({ level: 'warn', msg: 'ad media cleanup failed', error: String(e) }));
      });
    }
    return {};
  }

  /**
   * POST /api/ads/{id}/skip: I skipped an ad on the deck, so it never
   * shows to me again. One write, no read: a skip of an ad that isn't
   * there only sits in my own partition.
   */
  private async skipAd(req: Request, s: Session) {
    await this.store.skipAd(s.me.id, id(req.params.id, 'ad id'), s.now);
    return {};
  }

  /** GET /api/admin/ads?status=pending|approved|rejected: newest first, with their owners and the deck's setting. */
  private async adminAds(req: Request) {
    const status = (req.query.status ?? 'pending') as AdStatus;
    if (!AD_STATUSES.includes(status)) throw badRequest(`status must be one of ${AD_STATUSES.join(', ')}`);
    const [ads, settings] = await Promise.all([this.store.adsByStatus(status), this.store.getAdSettings()]);
    return { ads, climbers: await this.publicClimbers(ads.map((a) => a.ownerId)), every: settings.every };
  }

  /** POST /api/admin/ads/{id}/approve or /reject. */
  private async reviewAd(req: Request, s: Session, status: 'approved' | 'rejected') {
    const ad = await this.store.getAd(id(req.params.id, 'ad id'));
    if (!ad) throw notFound('no such ad');
    const reviewed: Ad = { ...ad, status, reviewedAt: s.now.toISOString() };
    await this.store.putAd(reviewed);
    return { ad: reviewed };
  }

  /**
   * The deck's ads: approved, not mine, not one I skipped, their owner
   * Premium (or the seed's made-up advertiser) and not blocked, reaching
   * my location or areas when they're limited to regions; and how
   * often to show one. Never fails the deck.
   */
  private async deckAds(s: Session, apart: Set<string>): Promise<{ ads: Ad[]; adEvery: number; adOwners: Record<string, PublicClimber> }> {
    try {
      const settings = await this.store.getAdSettings();
      if (settings.every === 0) return { ads: [], adEvery: 0, adOwners: {} };
      const [approved, skipped] = await Promise.all([this.store.adsByStatus('approved'), this.store.skippedAdIds(s.me.id)]);
      const owners = [...new Set(approved.map((a) => a.ownerId))];
      const [emails, climbers, blocked] = await Promise.all([this.store.getEmails(owners), this.store.getClimbers(owners), this.blockedEmails()]);
      // Owners still Premium in rbacr (each answer kept a minute).
      const premium = new Set<string>();
      await Promise.all(owners.map(async (o) => {
        if (await this.isPremium(emails[o])) premium.add(o);
      }));
      // Demo owners (the showcase's sample advertiser) advertise without Premium.
      const ok = (ownerId: string) =>
        (premium.has(ownerId) || climbers[ownerId]?.demo === true) && climbers[ownerId] !== undefined && !blocked.has(emails[ownerId] ?? '') && !apart.has(ownerId);
      // Region-limited ads reach where I am and where I'd climb.
      const points = [...(s.me.location ? [s.me.location] : []), ...(s.me.areas ?? [])];
      const ads = deckAds(approved, s.me.id, ok, new Set(skipped), points);
      const adOwners = Object.fromEntries(ads.map((a) => [a.ownerId, publicClimber(climbers[a.ownerId]!)]));
      return { ads, adEvery: settings.every, adOwners };
    } catch (e) {
      console.error(JSON.stringify({ level: 'warn', msg: 'deck ads failed', error: String(e) }));
      return { ads: [], adEvery: 0, adOwners: {} };
    }
  }

  // --- Decks and plans ------------------------------------------------------

  private async discover(s: Session) {
    // The demo plans' dates move with time: re-dated twice a day, by the
    // first deck asked for after that. Never fails the deck.
    await this.deps.showcase?.(s.now).catch((e: unknown) => {
      console.error(JSON.stringify({ level: 'warn', msg: 'showcase refresh failed', error: String(e) }));
    });
    const [upcoming, passed, asked, apart] = await Promise.all([
      this.store.upcomingPlans(s.now.toISOString()),
      this.store.passedPlanIds(s.me.id),
      this.store.askedRequests(s.me.id),
      this.apart(s.me.id),
    ]);
    const deck = rules.discover(upcoming, s.me, new Set(passed), new Set(asked.map((r) => r.planId)), s.now);
    // Blocked organizers' plans leave the deck.
    const [everyone, blocked] = await Promise.all([
      this.store.getClimbers(deck.plans.flatMap((p) => [p.organizerId, ...p.memberIds])),
      this.blockedIds(deck.plans.map((p) => p.organizerId)),
    ]);
    // So do plans with someone I blocked, or who blocked me, in the group.
    const plans = deck.plans.filter((p) => !blocked.has(p.organizerId) && !p.memberIds.some((m) => apart.has(m)));
    const distanceKm = Object.fromEntries(Object.entries(deck.distanceKm).filter(([pid]) => plans.some((p) => p.id === pid)));
    const climbers = Object.fromEntries(
      plans.flatMap((p) => [p.organizerId, ...p.memberIds]).flatMap((cid) => (everyone[cid] ? [[cid, publicClimber(everyone[cid])]] : [])),
    );
    const [covers, scores, ads] = await Promise.all([
      this.deckCovers(plans),
      s.caller.admin ? this.deckScores(plans, s) : Promise.resolve(undefined),
      this.deckAds(s, apart),
    ]);
    return {
      plans,
      distanceKm,
      climbers: { ...ads.adOwners, ...climbers },
      covers,
      ads: ads.ads,
      adEvery: ads.adEvery,
      ...(scores ? { scores } : {}),
    };
  }

  /**
   * Each plan's cover on the deck: its best GriGri Pics photo, with its
   * crag and credit. From the catalog the function keeps (no extra
   * reads); a plan without one has none, and never fails the deck.
   */
  private async deckCovers(plans: Plan[]): Promise<Record<string, DeckCover>> {
    if (!this.deps.pics || plans.length === 0) return {};
    try {
      const catalog = await this.deps.pics.catalog();
      const covers: Record<string, DeckCover> = {};
      for (const p of plans) {
        const best = picsFor(catalog, { sectorId: p.sectorId, lat: p.lat, lon: p.lon, place: p.place, area: p.area })[0];
        if (best) covers[p.id] = { key: best.key, crag: best.crag, author: best.author, license: best.license };
      }
      return covers;
    } catch (e) {
      console.error(JSON.stringify({ level: 'warn', msg: 'deck covers failed', error: String(e) }));
      return {};
    }
  }

  /**
   * Admins only: how likely each of the deck's best plans ends in a match
   * for me, from aityx, live. Best effort: a plan aityx didn't score (or
   * not in time) has no score; never fails the deck.
   */
  private async deckScores(plans: Plan[], s: Session): Promise<Record<string, MatchScore> | undefined> {
    const scorer = this.deps.matchScorer;
    if (!scorer || plans.length === 0) return undefined;
    try {
      const open = openByPlan(await this.store.openRequests());
      const top = plans.slice(0, SCORED_DECK);
      const deadline = Date.now() + SCORE_BUDGET_MS;
      const results = await pooled(top, SCORE_CONCURRENCY, async (plan) =>
        Date.now() > deadline ? null : scorer(matchFacts(s.me, plan, othersWaiting(open, plan.id, s.me.id), s.now)),
      );
      const scores: Record<string, MatchScore> = {};
      top.forEach((plan, i) => {
        const out = results[i];
        if (out) scores[plan.id] = out.score;
      });
      return scores;
    } catch (e) {
      console.error(JSON.stringify({ level: 'warn', msg: 'deck scores failed', error: String(e) }));
      return undefined;
    }
  }

  private async createPlan(req: Request, s: Session) {
    const input = cleanPlan(planInput(req.body, s.now));
    await this.mayGuide(req, input.type);
    const effects = rules.createPlan(newId(), s.me.id, input, s.ctx);
    await this.store.apply(null, effects, s.now);
    return { plan: effects.plan };
  }

  /** Guided plans are made by Premium climbers only (specs/premium.md; admins hold it too). */
  private async mayGuide(req: Request, type: PlanType | undefined): Promise<void> {
    if (type === 'guided' && !(await this.isPremium(req.caller?.email))) {
      throw forbidden('guided plans are for Premium climbers');
    }
  }

  private async myPlans(s: Session) {
    const [memberOf, asked, passed] = await Promise.all([
      this.store.memberPlanIds(s.me.id),
      this.store.askedRequests(s.me.id),
      this.store.passedPlanIds(s.me.id),
    ]);
    const passedSet = new Set(passed);
    const waiting = asked.filter((r) => !r.joined && !r.dismissed && (!r.rejected || !passedSet.has(r.planId)));
    const plans = await this.store.getPlans([...memberOf, ...waiting.map((r) => r.planId)]);
    const byId = new Map(plans.map((p) => [p.id, p]));
    const mine = rules.soonestFirst(plans.filter((p) => p.memberIds.includes(s.me.id)));
    const askedOut = waiting
      .filter((r) => byId.has(r.planId) && !byId.get(r.planId)!.memberIds.includes(s.me.id))
      .sort((a, b) => (a.time > b.time ? -1 : 1))
      .map((r) => ({ request: requestJson(r), plan: byId.get(r.planId)! }));
    return {
      plans: mine,
      asked: askedOut,
      climbers: await this.climbersOf([...mine, ...askedOut.map((a) => a.plan)]),
    };
  }

  private async getPlan(req: Request, s: Session) {
    const loaded = await this.loadPlan(req.params.id);
    const member = loaded.plan.memberIds.includes(s.me.id);
    const requests = member ? loaded.requests.filter((r) => isOpen(r) && !loaded.plan.memberIds.includes(r.climberId)) : [];
    return {
      plan: loaded.plan,
      requests: requests.map(requestJson),
      climbers: await this.climbersOf([loaded.plan], requests),
    };
  }

  private async updatePlan(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    return this.retry(async () => {
      const current = await this.loadPlan(planId);
      const input = cleanPlan(planInput(req.body, s.now));
      // A plan that's guided already stays editable after Premium ends.
      if (planType(current.plan) !== 'guided') await this.mayGuide(req, input.type);
      const changed = rules.updatePlan(current.plan, s.me.id, input);
      // A new type may need fewer yeses (open: none): who now has them joins.
      await this.loadNames(s, changed.memberIds, current.requests.map((r) => r.climberId));
      const effects = rules.settle({ plan: changed, requests: current.requests }, s.ctx);
      const plan = effects.plan!;
      await this.store.apply(current, effects, s.now);
      await this.hint(hintsFor(plan.memberIds, { kind: 'plan', planId }, s.me.id));
      return { plan };
    });
  }

  private async leave(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    const members = await this.retry(async () => {
      const loaded = await this.loadPlan(planId);
      await this.loadNames(s, loaded.plan.memberIds, loaded.requests.map((r) => r.climberId));
      const effects = rules.leave(loaded, s.me.id, s.ctx);
      await this.store.apply(loaded, effects, s.now);
      return effects.plan?.memberIds ?? [];
    });
    // Out of my deck for good, now that I've left it (a refresh keeps it out).
    await this.store.addPass(s.me.id, planId, s.now, true);
    await this.hint(hintsFor(members, { kind: 'plan', planId }, s.me.id));
    return {};
  }

  private async join(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    const asked = await this.ask(planId, s);
    if (!asked.demo && !asked.open) return { request: requestJson(asked.request) };
    // A demo plan's made-up members can't answer: the group says yes at
    // once, as an admin's yes would, and I match. An open plan lets me in
    // at once: nobody decides.
    return this.retry(async () => {
      const loaded = await this.loadPlan(planId);
      await this.loadNames(s, loaded.plan.memberIds, loaded.requests.map((r) => r.climberId));
      const effects = asked.demo
        ? rules.accept(loaded, { id: loaded.plan.organizerId, admin: true }, s.me.id, s.ctx)
        : rules.settle(loaded, s.ctx);
      await this.store.apply(loaded, effects, s.now);
      await this.hint(answerHints(loaded, effects, 'accept', s.me.id, s.me.id));
      const request = effects.requests.find((r) => r.climberId === s.me.id) ?? asked.request;
      return { request: requestJson(request) };
    });
  }

  /** My join request, saved; whether the plan is a demo, or open. */
  private async ask(planId: string, s: Session): Promise<{ request: JoinRequest; demo: boolean; open: boolean }> {
    const apart = await this.apart(s.me.id);
    return this.retry(async () => {
      const loaded = await this.loadPlan(planId);
      // Someone in the group blocked me, or I blocked them: no request, and
      // nothing says which (the plan is off my deck anyway).
      if (loaded.plan.memberIds.some((m) => apart.has(m))) throw conflict(CANT_ASK);
      if (loaded.requests.filter(isOpen).length >= MAX_OPEN_REQUESTS) {
        throw conflict('the plan has too many requests waiting; try again later');
      }
      const existing = loaded.requests.find((r) => r.climberId === s.me.id);
      const effects = rules.ask(loaded.plan, s.me.id, existing, s.ctx);
      try {
        await this.store.ask(loaded, effects);
      } catch (e) {
        // My request appeared meanwhile (a double swipe): already asked.
        if (e instanceof Conflict && (await this.store.getRequest(planId, s.me.id))) {
          throw conflict('you already asked to join this plan');
        }
        throw e;
      }
      await this.hint(hintsFor(loaded.plan.memberIds, { kind: 'request', planId }, s.me.id));
      return { request: effects.requests[0]!, demo: loaded.plan.demo === true, open: planType(loaded.plan) === 'open' };
    });
  }

  /**
   * I nudge the members who haven't answered my open request on this plan:
   * each gets a nudge notice and a notice hint. Once per 12 hours (429).
   */
  private async nudge(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    return this.retry(async () => {
      const loaded = await this.loadPlan(planId);
      const before = loaded.requests.find((r) => r.climberId === s.me.id);
      const effects = rules.nudge(loaded, s.me.id, s.ctx);
      const request = effects.requests[0]!;
      await this.store.nudge(request, before?.nudgedAt, effects.notices);
      const nudged = effects.notices.map((d) => d.to);
      await this.hint(hintsFor(nudged, { kind: 'notice', planId }, s.me.id));
      return { request: requestJson(request), nudged: nudged.length };
    });
  }

  /**
   * Discover's refresh: the plans I passed on come back (I may have changed
   * my mind). Not the ones I asked to join (a dismissed "no" stays hidden)
   * or left (cancelled).
   */
  private async clearPasses(s: Session) {
    const [passed, asked, left] = await Promise.all([
      this.store.passedPlanIds(s.me.id),
      this.store.askedRequests(s.me.id),
      this.store.leftPlanIds(s.me.id),
    ]);
    const keep = new Set([...asked.map((r) => r.planId), ...left]);
    await this.store.deletePasses(s.me.id, passed.filter((p) => !keep.has(p)));
    return {};
  }

  private async pass(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    if (!(await this.store.getPlan(planId))) throw notFound('no such plan');
    await this.store.addPass(s.me.id, planId, s.now);
    return {};
  }

  // --- Requests -------------------------------------------------------------

  private async toReview(s: Session) {
    const planIds = await this.store.memberPlanIds(s.me.id);
    const loaded = (await Promise.all(planIds.map((p) => this.store.loadPlan(p)))).filter(
      (l): l is LoadedPlan => l !== undefined,
    );
    const requests = rules.toReview(loaded, s.me.id);
    const plans = loaded.map((l) => l.plan).filter((p) => requests.some((r) => r.planId === p.id));
    return {
      requests: requests.map(requestJson),
      plans: Object.fromEntries(plans.map((p) => [p.id, p])),
      climbers: await this.climbersOf(plans, requests),
    };
  }

  private async answer(req: Request, s: Session, kind: 'accept' | 'reject') {
    const planId = id(req.params.planId, 'plan id');
    const climberId = id(req.params.climberId, 'climber id');
    const actor = { id: s.me.id };
    return this.retry(async () => {
      const loaded = await this.loadPlan(planId);
      await this.loadNames(s, loaded.plan.memberIds, loaded.requests.map((r) => r.climberId));
      const effects =
        kind === 'accept' ? rules.accept(loaded, actor, climberId, s.ctx) : rules.reject(loaded, actor, climberId, s.ctx);
      await this.store.apply(loaded, effects, s.now);
      await this.hint(answerHints(loaded, effects, kind, climberId, s.me.id));
      if (kind === 'reject') return {};
      return { match: effects.matches.find((m) => m.newcomerId === climberId) ?? null };
    });
  }

  private async dismiss(req: Request, s: Session) {
    const planId = id(req.params.planId, 'plan id');
    const climberId = id(req.params.climberId, 'climber id');
    if (climberId !== s.me.id) throw forbidden('only the requester can dismiss it');
    const request = rules.dismiss(await this.store.getRequest(planId, climberId), s.me.id);
    try {
      await this.store.saveDismissed(request);
    } catch (e) {
      if (e instanceof Conflict) throw conflict('changed meanwhile');
      throw e;
    }
    await this.store.addPass(s.me.id, planId, s.now);
    return {};
  }

  /** GET /api/admin/climbers: everyone, by name, with whether they're blocked. */
  private async adminClimbers() {
    const all = await this.store.allClimbers();
    const blocked = await this.blockedIds(all.map((c) => c.id));
    const climbers = all
      .map((c) => ({ ...publicClimber(c), blocked: blocked.has(c.id) }))
      .sort((a, b) => a.name.localeCompare(b.name) || a.id.localeCompare(b.id));
    return { climbers };
  }

  /**
   * POST /api/admin/climbers/{id}/block and /unblock: rbacr's `blocked`
   * role, granted or revoked by their verified email. Never myself: I'd
   * lock myself out.
   */
  private async block(climberId: string, s: Session, blocked: boolean) {
    if (blocked && climberId === s.me.id) throw badRequest("you can't block yourself");
    if (!(await this.store.getClimber(climberId))) throw notFound('no such climber');
    const grants = this.deps.grants;
    if (!grants) throw unavailable("rbacr isn't set up here: nobody can be blocked");
    const email = await this.emailOf(climberId);
    if (!email) throw conflict('Grigri has no verified email for them, so rbacr can\'t block them');
    if (blocked) await grants.grant(email, this.blockedRole);
    else await grants.revoke(email, this.blockedRole);
    return { blocked };
  }

  /** Who's blocked (rbacr's role), by email; none when rbacr can't say (logged). */
  private async blockedEmails(): Promise<Set<string>> {
    if (!this.deps.grants) return new Set();
    try {
      return await this.deps.grants.holders(this.blockedRole);
    } catch (e) {
      console.error(JSON.stringify({ level: 'warn', msg: 'rbacr blocked list failed', error: String(e) }));
      return new Set();
    }
  }

  private async isBlocked(email: string | undefined): Promise<boolean> {
    return email !== undefined && (await this.blockedEmails()).has(email.toLowerCase());
  }

  /** Which of these climbers are blocked. */
  private async blockedIds(climberIds: string[]): Promise<Set<string>> {
    const blocked = await this.blockedEmails();
    if (blocked.size === 0) return new Set();
    const emails = await this.store.getEmails(climberIds);
    return new Set(climberIds.filter((c) => emails[c] !== undefined && blocked.has(emails[c]!.toLowerCase())));
  }

  /** A climber's verified email: the one kept, or else their sessions' (then kept). */
  private async emailOf(climberId: string): Promise<string | undefined> {
    const known = (await this.store.getEmails([climberId]))[climberId];
    if (known) return known;
    const fromSession = await this.store.sessionEmail(climberId);
    if (fromSession) await this.store.putEmail(climberId, fromSession);
    return fromSession;
  }

  // --- Moderation: reports and blocks (specs/moderation.md) ---------------------

  /**
   * POST /api/reports: I report something objectionable I can see. Kept
   * with a copy of the content (for the admin), and the admins are told
   * (a notice and a hint). Reporting it again replaces the report.
   */
  private async report(req: Request, s: Session) {
    const input = reportInput(req.body);
    const { subjectId, content } = await this.reported(input.kind, input.targetId, input.planId, s);
    if (subjectId === s.me.id) throw badRequest("you can't report your own");
    const report: Report = {
      id: reportId(s.me.id, input.kind, input.targetId),
      kind: input.kind,
      targetId: input.targetId,
      ...(input.planId ? { planId: input.planId } : {}),
      subjectId,
      reporterId: s.me.id,
      reason: input.reason,
      text: input.text,
      content,
      status: 'open',
      time: s.now.toISOString(),
    };
    await this.store.putReport(report);
    await this.tellAdmins(s);
    return {};
  }

  /** What a report is about (as I can see it: 404 when there's no such thing, 403 when it isn't mine to see), and whose it is. */
  private async reported(
    kind: Report['kind'],
    targetId: string,
    planId: string | undefined,
    s: Session,
  ): Promise<{ subjectId: string; content: ReportContent }> {
    switch (kind) {
      case 'profile': {
        const c = await this.store.getClimber(targetId);
        if (!c) throw notFound('no such climber');
        const media = photosOf(c).map((key) => ({ key, kind: 'image' as const }));
        return { subjectId: c.id, content: { title: c.name, text: c.bio, ...(media.length ? { media } : {}) } };
      }
      case 'plan': {
        const current = await this.store.getPlan(targetId);
        if (!current) throw notFound('no such plan');
        const { plan } = current;
        return { subjectId: plan.organizerId, content: { title: plan.area ? `${plan.place}, ${plan.area}` : plan.place, text: plan.notes } };
      }
      case 'message': {
        await this.memberPlan(planId!, s);
        const message = (await this.store.messages(planId!)).find((m) => m.id === targetId);
        if (!message) throw notFound('no such message');
        if (!message.authorId) throw badRequest("the chat's own notes can't be reported");
        return {
          subjectId: message.authorId,
          content: { text: message.text, ...(message.attachment ? { media: [message.attachment] } : {}) },
        };
      }
      case 'pic': {
        await this.memberPlan(planId!, s);
        const pic = (await this.store.planPics(planId!)).find((p) => p.id === targetId);
        if (!pic) throw notFound('no such photo');
        return { subjectId: pic.uploaderId, content: { media: [{ key: pic.key, kind: 'image' }] } };
      }
      case 'ad': {
        const ad = await this.store.getAd(targetId);
        if (!ad) throw notFound('no such ad');
        return {
          subjectId: ad.ownerId,
          content: { text: ad.text, link: ad.link, ...(ad.media ? { media: [{ key: ad.media.key, kind: ad.media.kind }] } : {}) },
        };
      }
    }
  }

  /**
   * Tells the admins there are reports to review: one notice each
   * (replaced, unread again) and a hint. Only climbers rbacr still says
   * are admins (others are forgotten). Best effort: the report is saved.
   */
  private async tellAdmins(s: Session): Promise<void> {
    try {
      const known = await this.store.adminIds();
      if (known.length === 0) return;
      const emails = await this.store.getEmails(known);
      const admins: string[] = [];
      const former: string[] = [];
      await Promise.all(known.map(async (cid) => {
        const roles = await this.rolesOf(emails[cid]);
        if (roles === null) return;
        if (roles.includes(ADMIN_ROLE) || roles.includes('root')) admins.push(cid);
        else former.push(cid);
      }));
      await this.store.removeAdmins(former);
      const notice = { id: REPORTS_NOTICE_ID, kind: 'report' as const, planId: '', planTitle: '', time: s.now.toISOString(), read: false };
      await this.store.deliver(admins.map((to) => ({ to, notice })));
      await this.hint(hintsFor(admins, { kind: 'notice' }, s.me.id));
    } catch (e) {
      console.error(JSON.stringify({ level: 'warn', msg: 'telling admins of a report failed', error: String(e) }));
    }
  }

  /** Remembers that this climber is an admin, to tell them of reports (once). */
  private async rememberAdmin(climberId: string): Promise<void> {
    try {
      if (!(await this.store.adminIds()).includes(climberId)) await this.store.addAdmin(climberId);
    } catch (e) {
      console.error(JSON.stringify({ level: 'warn', msg: 'remembering an admin failed', error: String(e) }));
    }
  }

  /** GET /api/admin/reports: the open reports, oldest first, with everyone they mention. */
  private async adminReports() {
    const reports = await this.store.openReports();
    const ids = reports.flatMap((r) => [r.subjectId, r.reporterId]);
    return { reports, climbers: await this.publicClimbers(ids) };
  }

  /**
   * POST /api/admin/reports/{id}/dismiss, /remove (the content: a message,
   * photo or ad is deleted; a plan's notes, or a profile's bio and photos,
   * cleared) or /block (its climber, as Admin → Users does).
   */
  private async resolveReport(req: Request, s: Session, status: 'dismissed' | 'removed' | 'blocked') {
    const report = await this.store.getReport(id(req.params.id, 'report id'));
    if (!report) throw notFound('no such report');
    if (report.status !== 'open') throw conflict('that report was already handled');
    if (status === 'removed') await this.removeReported(report, s);
    if (status === 'blocked') await this.block(report.subjectId, s, true);
    const resolved: Report = { ...report, status, resolvedAt: s.now.toISOString(), resolvedBy: s.me.id };
    await this.store.putReport(resolved);
    return { report: resolved };
  }

  /** Takes reported content down (what's already gone is fine). */
  private async removeReported(report: Report, s: Session): Promise<void> {
    const cleanup = (keys: string[]) =>
      keys.length === 0
        ? Promise.resolve()
        : this.deps.photos.remove(keys).catch((e: unknown) => {
            console.error(JSON.stringify({ level: 'warn', msg: 'removed content cleanup failed', error: String(e) }));
          });
    switch (report.kind) {
      case 'profile': {
        const c = await this.store.getClimber(report.targetId);
        if (!c) return;
        await this.store.clearProfileContent(c.id);
        await cleanup(photosOf(c));
        return;
      }
      case 'plan': {
        const current = await this.store.getPlan(report.targetId);
        if (!current) return;
        await this.store.clearPlanNotes(report.targetId);
        await this.hint(hintsFor(current.plan.memberIds, { kind: 'plan', planId: report.targetId }, s.me.id));
        return;
      }
      case 'message': {
        const planId = report.planId!;
        const message = (await this.store.messages(planId)).find((m) => m.id === report.targetId);
        if (!message) return;
        await this.removeMessages([message], planId, cleanup);
        await this.hint(await this.membersHint(planId, 'message', s));
        return;
      }
      case 'pic': {
        const planId = report.planId!;
        const pic = (await this.store.planPics(planId)).find((p) => p.id === report.targetId);
        if (!pic) return;
        await this.store.deletePlanPic(planId, pic.id);
        // A chat photo goes from the chat too.
        const sent = pic.fromChat ? (await this.store.messages(planId)).filter((m) => m.attachment?.key === pic.key) : [];
        if (sent.length) await this.removeMessages(sent, planId, cleanup);
        else await cleanup([pic.key]);
        await this.hint(await this.membersHint(planId, 'pics', s));
        return;
      }
      case 'ad': {
        const ad = await this.store.getAd(report.targetId);
        if (!ad) return;
        await this.store.deleteAd(ad.id);
        await cleanup(ad.media ? [ad.media.key] : []);
        return;
      }
    }
  }

  /** Deletes chat messages, their media and the plan photos they made. */
  private async removeMessages(messages: Message[], planId: string, cleanup: (keys: string[]) => Promise<void>): Promise<void> {
    const keys = messages.flatMap((m) => (m.attachment ? [m.attachment.key] : []));
    for (const m of messages) await this.store.deleteMessage(m);
    for (const pic of await this.store.planPics(planId)) {
      if (pic.fromChat && keys.includes(pic.key)) await this.store.deletePlanPic(planId, pic.id);
    }
    await cleanup(keys);
  }

  private async membersHint(planId: string, kind: 'pics' | 'message', s: Session) {
    const current = await this.store.getPlan(planId);
    return current ? hintsFor(current.plan.memberIds, { kind, planId }, s.me.id) : [];
  }

  /** Everyone with a block between them and me, either way (one query of my partition). */
  private async apart(climberId: string): Promise<Set<string>> {
    const { blocked, blockedBy } = await this.store.blocksOf(climberId);
    return new Set([...blocked, ...blockedBy]);
  }

  /** GET /api/blocks: the people I blocked (never who blocked me). */
  private async myBlocks(s: Session) {
    const { blocked } = await this.store.blocksOf(s.me.id);
    return { blocked, climbers: await this.publicClimbers(blocked) };
  }

  /**
   * POST /api/blocks/{id}: I block someone. Their plans leave my deck and
   * mine theirs, neither can ask to join a plan the other is in, and their
   * open requests on plans I decide on are declined (as my no). Nothing
   * tells them.
   */
  private async blockSomeone(req: Request, s: Session) {
    const them = id(req.params.id, 'climber id');
    if (them === s.me.id) throw badRequest("you can't block yourself");
    if (!(await this.store.getClimber(them))) throw notFound('no such climber');
    await this.store.addBlock(s.me.id, them, s.now);
    const open = (await this.store.askedRequests(them)).filter(isOpen);
    for (const r of open) {
      await this.retry(async () => {
        const loaded = await this.store.loadPlan(r.planId);
        if (!loaded || !deciders(loaded.plan).includes(s.me.id)) return;
        const still = loaded.requests.find((x) => x.climberId === them);
        if (!still || !isOpen(still)) return;
        await this.loadNames(s, loaded.plan.memberIds, [them]);
        const effects = rules.reject(loaded, { id: s.me.id }, them, s.ctx);
        await this.store.apply(loaded, effects, s.now);
        await this.hint(answerHints(loaded, effects, 'reject', them, s.me.id));
      });
    }
    return { blocked: true };
  }

  /** DELETE /api/blocks/{id}: I unblock them (declined requests stay declined). */
  private async unblockSomeone(req: Request, s: Session) {
    const them = id(req.params.id, 'climber id');
    await this.store.removeBlock(s.me.id, them);
    return { blocked: false };
  }

  // --- Notices and chat -------------------------------------------------------

  private async notices(s: Session) {
    const notices = await this.store.notices(s.me.id);
    const ids = notices.flatMap((n) => (n.climberId ? [n.climberId] : []));
    return { notices, climbers: await this.publicClimbers(ids) };
  }

  private async messages(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    const current = await this.store.getPlan(planId);
    if (!current) throw notFound('no such plan');
    if (!current.plan.memberIds.includes(s.me.id)) throw forbidden("you're not in this plan");
    const after = req.query.after ? parseDate(req.query.after, 'after').toISOString() : undefined;
    const messages = await this.store.messages(planId, after);
    const ids = new Set<string>(current.plan.memberIds);
    for (const m of messages) {
      if (m.authorId) ids.add(m.authorId);
      if (m.requestId) ids.add(m.requestId.split('/')[1]!);
    }
    return { messages, climbers: await this.publicClimbers(ids) };
  }

  private async send(req: Request, s: Session) {
    const planId = id(req.params.id, 'plan id');
    const input = messageInput(req.body, planId);
    assertClean({ text: input.text });
    const current = await this.store.getPlan(planId);
    if (!current) throw notFound('no such plan');
    const message = rules.chatMessage(current.plan, s.me.id, input.text, s.ctx, input.attachment);
    // The upload loses its pending tag (else the bucket would expire it)
    // only once I'm known to be a member; one that isn't there is refused.
    if (input.attachment && !(await this.deps.photos.keep(input.attachment.key))) {
      throw badRequest("the attachment isn't uploaded (or expired): upload it again");
    }
    await this.store.putMessage(message);
    // A chat photo goes to the plan's "Your Pics" too.
    if (input.attachment?.kind === 'image') await this.chatPhotoToPics(planId, input.attachment.key, s);
    await this.hint(hintsFor(current.plan.memberIds, { kind: 'message', planId }, s.me.id));
    return { message };
  }

  // --- The Grigri team chat (specs/team-chat.md) ------------------------------

  /**
   * GET /api/team/messages[?after=]: my team chat, oldest first, never
   * saying which admin answered. Its welcome is the app's own: none stored.
   */
  private async myTeamMessages(req: Request, s: Session) {
    const after = req.query.after ? parseDate(req.query.after, 'after').toISOString() : undefined;
    const messages = await this.store.teamMessages(s.me.id, after);
    return { messages: messages.map(forClimber) };
  }

  /** POST /api/team/messages: I write to the Grigri team. Every known admin gets a badge and a hint. */
  private async writeToTeam(req: Request, s: Session) {
    const { text } = teamMessageInput(req.body);
    assertClean({ text });
    const message: TeamMessage = { id: s.ctx.newId(), climberId: s.me.id, fromTeam: false, text, time: s.now.toISOString() };
    await this.store.putTeamMessage(message);
    await this.tellTeam(s);
    return { message };
  }

  /**
   * The admins hear of a climber's message: the "team" notice (one each,
   * replaced, unread again; it says nothing of whose) and a hint. The
   * admins Grigri knows (one read), without asking rbacr about each:
   * neither carries anything of the message. Best effort: it's saved.
   */
  private async tellTeam(s: Session): Promise<void> {
    try {
      const admins = (await this.store.adminIds()).filter((cid) => cid !== s.me.id);
      if (admins.length === 0) return;
      const notice = { id: TEAM_NOTICE_ID, kind: 'team' as const, planId: '', planTitle: '', time: s.now.toISOString(), read: false };
      await this.store.deliver(admins.map((to) => ({ to, notice })));
      await this.hint(hintsFor(admins, { kind: 'team' }, s.me.id));
    } catch (e) {
      console.error(JSON.stringify({ level: 'warn', msg: 'telling the team failed', error: String(e) }));
    }
  }

  /** GET /api/admin/team: the team chats with a message, the latest first (at most MAX_TEAM_CHATS), and whose. */
  private async teamChats() {
    const chats = await this.store.teamChats(MAX_TEAM_CHATS);
    return { chats, climbers: await this.publicClimbers(chats.map((c) => c.climberId)) };
  }

  /** GET /api/admin/team/{id}/messages[?after=]: a climber's team chat, with which admin wrote each answer. */
  private async teamChatOf(req: Request) {
    const climberId = id(req.params.id, 'climber id');
    const after = req.query.after ? parseDate(req.query.after, 'after').toISOString() : undefined;
    const messages = await this.store.teamMessages(climberId, after);
    const ids = new Set<string>([climberId]);
    for (const m of messages) if (m.adminId) ids.add(m.adminId);
    return { messages, climbers: await this.publicClimbers(ids) };
  }

  /**
   * POST /api/admin/team/{id}/messages: an admin answers as the Grigri
   * team (the climber never sees who). The climber gets the "team"
   * notice and a hint; the other admins a hint, for their open chat.
   */
  private async answerAsTeam(req: Request, s: Session) {
    const climberId = id(req.params.id, 'climber id');
    const { text } = teamMessageInput(req.body);
    assertClean({ text });
    if (!(await this.store.getClimber(climberId))) throw notFound('no such climber');
    const message: TeamMessage = {
      id: s.ctx.newId(), climberId, fromTeam: true, text, time: s.now.toISOString(), adminId: s.me.id,
    };
    await this.store.putTeamMessage(message);
    try {
      const notice = { id: TEAM_NOTICE_ID, kind: 'team' as const, planId: '', planTitle: '', time: s.now.toISOString(), read: false };
      if (climberId !== s.me.id) await this.store.deliver([{ to: climberId, notice }]);
      const admins = await this.store.adminIds();
      await this.hint(hintsFor([climberId, ...admins], { kind: 'team' }, s.me.id));
    } catch (e) {
      console.error(JSON.stringify({ level: 'warn', msg: 'telling of a team answer failed', error: String(e) }));
    }
    return { message };
  }

  /** Best effort: the message is sent either way; a full plan keeps it in the chat only. */
  private async chatPhotoToPics(planId: string, key: string, s: Session): Promise<void> {
    try {
      if ((await this.store.planPics(planId)).length >= MAX_PLAN_PICS) return;
      await this.store.putPlanPic({ id: newId(), planId, key, uploaderId: s.me.id, time: s.now.toISOString(), fromChat: true });
    } catch (e) {
      console.error(JSON.stringify({ level: 'warn', msg: 'chat photo to pics failed', error: String(e) }));
    }
  }

  // --- Helpers ------------------------------------------------------------------

  /** Live updates: best effort, never fails the request (Realtime.notify). */
  private async hint(deliveries: Delivery[]): Promise<void> {
    await this.deps.realtime?.notify(deliveries);
  }

  private async loadPlan(rawId: string | undefined): Promise<LoadedPlan> {
    const planId = id(rawId, 'plan id');
    const loaded = await this.store.loadPlan(planId);
    if (!loaded) throw notFound('no such plan');
    return loaded;
  }

  /** Names for the chat's notes. */
  private async loadNames(s: Session, ...groups: string[][]): Promise<void> {
    const { names } = s;
    const missing = groups.flat().filter((cid) => !names.has(cid));
    const climbers = await this.store.getClimbers(missing);
    for (const c of Object.values(climbers)) names.set(c.id, c.name);
  }

  /** Every climber the plans and requests mention. */
  private climbersOf(plans: Plan[], requests: JoinRequest[] = []): Promise<Record<string, PublicClimber>> {
    const ids = new Set<string>();
    for (const p of plans) {
      ids.add(p.organizerId);
      for (const m of p.memberIds) ids.add(m);
    }
    for (const r of requests) {
      ids.add(r.climberId);
      for (const a of r.acceptedBy) ids.add(a);
    }
    return this.publicClimbers(ids);
  }

  /** Other people's profiles, without where they are (location and areas are only mine to see). */
  private async publicClimbers(ids: Iterable<string>): Promise<Record<string, PublicClimber>> {
    const climbers = await this.store.getClimbers(ids);
    return Object.fromEntries(Object.entries(climbers).map(([cid, c]) => [cid, publicClimber(c)]));
  }

  /** Runs a read-decide-write step again when a conditional write lost a race. */
  private async retry<T>(step: () => Promise<T>): Promise<T> {
    for (let attempt = 1; ; attempt++) {
      try {
        return await step();
      } catch (e) {
        if (!(e instanceof Conflict)) throw e;
        if (attempt >= 4) throw conflict('changed meanwhile; try again');
        await new Promise((resolve) => setTimeout(resolve, 20 * attempt + Math.random() * 30));
      }
    }
  }
}

/**
 * Who hears about an answer: a newcomer (everyone said yes) gets a match
 * and the members a plan change; a partial yes is a request change for
 * the members; a no tells the requester (a notice) and the members.
 */
export function answerHints(
  before: { plan: Plan },
  effects: rules.Effects,
  kind: 'accept' | 'reject',
  climberId: string,
  actorId: string,
): Delivery[] {
  const planId = before.plan.id;
  const members = effects.plan?.memberIds ?? before.plan.memberIds;
  if (kind === 'reject') {
    return [
      ...hintsFor([climberId], { kind: 'notice', planId }, actorId),
      ...hintsFor(before.plan.memberIds, { kind: 'request', planId }, actorId),
    ];
  }
  const newcomers = new Set(effects.matches.map((m) => m.newcomerId));
  if (newcomers.size === 0) return hintsFor(members, { kind: 'request', planId }, actorId);
  return [
    ...hintsFor(newcomers, { kind: 'match', planId }, actorId),
    ...hintsFor(members.filter((m) => !newcomers.has(m)), { kind: 'plan', planId }, actorId),
  ];
}

/** A plan's text, through the filter: its notes, and its place and area when typed by hand (the sector index's are fine). */
function cleanPlan<T extends { notes: string; place: string; area: string; sectorId?: string }>(input: T): T {
  assertClean({ notes: input.notes, ...(input.sectorId ? {} : { place: input.place, area: input.area }) });
  return input;
}

/** GET /api/pics's query: `sector`, `lat` and `lon` (both or neither), `place`, `area`. */
export function whereFrom(query: Record<string, string | undefined>): Where {
  const where: Where = {};
  if (query.sector) where.sectorId = query.sector.slice(0, 64);
  if (query.place) where.place = query.place.slice(0, 120);
  if (query.area) where.area = query.area.slice(0, 120);
  if (query.lat !== undefined || query.lon !== undefined) {
    const lat = Number(query.lat);
    const lon = Number(query.lon);
    if (!Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) {
      throw badRequest('lat and lon must be numbers (both or neither)');
    }
    where.lat = lat;
    where.lon = lon;
  }
  return where;
}

/** Premium: rbacr's premium role (the stage's), or root (roots hold every role). */
export function holdsPremium(roles: string[] | null, role: string = PREMIUM_ROLE): boolean {
  return (roles ?? []).some((r) => r === role || r === 'root');
}
