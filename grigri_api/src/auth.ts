// Who's calling. The API issues its own sessions (specs/api.md, "Sessions"):
// POST /api/session trades a Google ID token, verified here, for an opaque
// session token; every other route but GET /api/health sends it as
// `Authorization: Bearer <token>`. Only the token's SHA-256 hash is stored.
// A session lasts until sign-out, or SESSION_DAYS without use: each use
// more than a day after the last one slides it forward (at most one write
// per session per day). In local dev mode only, the caller may instead
// name themselves in the X-Grigri-Dev-User header, or POST
// {"devUser": "<email>"} to /api/session.
import { createHash, randomBytes } from 'node:crypto';
import { ApiError, badRequest } from './domain/errors.js';
import { type IdTokenVerifier, InvalidIdToken } from './google.js';
import type { AdminCheck } from './rbacr.js';

export const SESSION_DAYS = 365;
const DAY_MS = 24 * 60 * 60 * 1000;

export interface Caller {
  /** `<iss>#<sub>` (or `dev#<email>` in dev mode): the signed-in account. */
  subject: string;
  /** Verified email, lowercased; only for the admin check (rbacr), never returned. */
  email?: string;
  admin: boolean;
  /** The session's id (its token's hash); none for the dev header. */
  sessionId?: string;
}

/** A stored session (item `SESSION#<id>`). */
export interface SessionRecord {
  /** SHA-256 of the token, hex. */
  id: string;
  subject: string;
  /** Lowercased, and only when verified. */
  email?: string;
  emailVerified: boolean;
  createdAt: string;
  lastUsedAt: string;
  /** Epoch seconds: lastUsedAt + SESSION_DAYS (the table's TTL attribute). */
  ttl: number;
}

/** What the sessions need from the store (Store implements it). */
export interface SessionStore {
  putSession(session: SessionRecord): Promise<void>;
  getSession(id: string): Promise<SessionRecord | undefined>;
  /** Moves lastUsedAt and ttl forward, if it's still there and unchanged since `previous`. */
  touchSession(id: string, previous: string, lastUsedAt: string, ttl: number): Promise<void>;
  deleteSession(id: string): Promise<void>;
  deleteSessions(subject: string): Promise<void>;
}

export interface AuthConfig {
  /** Local dev mode (template: DevMode, allowed only for Stage local). */
  devMode: boolean;
  /** Whether a verified email is a Grigri admin: rbacr's answer (rbacr.ts). */
  isAdmin: AdminCheck;
}

export interface AuthDeps {
  store: SessionStore;
  verify: IdTokenVerifier;
  config: AuthConfig;
  clock?: () => Date;
}

const EMAIL = /^[^\s@,]{1,64}@[A-Za-z0-9.-]{1,253}\.[A-Za-z]{2,63}$/;
/** 32 bytes, base64url without padding. */
const TOKEN = /^[A-Za-z0-9_-]{43}$/;

const signedOut = () => new ApiError(401, 'signed out');

export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export class Auth {
  private readonly clock: () => Date;

  constructor(private readonly deps: AuthDeps) {
    this.clock = deps.clock ?? (() => new Date());
  }

  /** POST /api/session: a Google ID token (or, dev mode only, devUser) for a new session. */
  async signIn(body: unknown): Promise<{ token: string; expiresAt: string }> {
    if (typeof body !== 'object' || body === null || Array.isArray(body)) throw badRequest('send {"idToken"}');
    const { idToken, devUser } = body as Record<string, unknown>;
    let identity: { subject: string; email?: string; emailVerified: boolean };
    if (typeof idToken === 'string' && idToken.length > 0) {
      try {
        identity = await this.deps.verify(idToken);
      } catch (e) {
        if (e instanceof InvalidIdToken) throw new ApiError(401, 'invalid Google ID token');
        throw e;
      }
    } else if (devUser !== undefined) {
      if (!this.deps.config.devMode) throw new ApiError(401, 'dev sign-in is local only');
      const email = typeof devUser === 'string' ? devUser.trim().toLowerCase() : '';
      if (!EMAIL.test(email)) throw badRequest('devUser must be an email');
      identity = { subject: `dev#${email}`, email, emailVerified: true };
    } else {
      throw badRequest('send {"idToken"}');
    }
    const token = randomBytes(32).toString('base64url');
    const now = this.clock();
    const session: SessionRecord = {
      id: hashToken(token),
      subject: identity.subject,
      ...(identity.emailVerified && identity.email ? { email: identity.email } : {}),
      emailVerified: identity.emailVerified,
      createdAt: now.toISOString(),
      lastUsedAt: now.toISOString(),
      ttl: expiry(now),
    };
    await this.deps.store.putSession(session);
    return { token, expiresAt: new Date(session.ttl * 1000).toISOString() };
  }

  /** The caller of a non-public route, or 401 "signed out". */
  async caller(headers: Record<string, string | undefined>): Promise<Caller> {
    const authorization = headers.authorization?.trim();
    if (authorization) {
      const match = /^Bearer\s+(\S+)$/i.exec(authorization);
      // Not a session token's shape (an old Google ID token, say): no read.
      if (!match) throw signedOut();
      return this.callerOfToken(match[1]!);
    }
    if (this.deps.config.devMode) {
      const dev = headers['x-grigri-dev-user']?.trim().toLowerCase();
      if (dev && EMAIL.test(dev)) return { subject: `dev#${dev}`, email: dev, admin: await this.deps.config.isAdmin(dev) };
    }
    throw signedOut();
  }

  /**
   * The caller of a bare session token (the live updates' authorizer,
   * realtime-auth.ts), or 401 "signed out". Never the dev header.
   */
  async callerOfToken(token: string): Promise<Caller> {
    if (!TOKEN.test(token)) throw signedOut();
    return this.fromSession(hashToken(token));
  }

  /** DELETE /api/session: this session ends. */
  async signOut(caller: Caller): Promise<void> {
    if (caller.sessionId) await this.deps.store.deleteSession(caller.sessionId);
  }

  /** DELETE /api/sessions: every session of the caller's account ends. */
  async signOutEverywhere(caller: Caller): Promise<void> {
    await this.deps.store.deleteSessions(caller.subject);
  }

  private async fromSession(id: string): Promise<Caller> {
    const session = await this.deps.store.getSession(id);
    const now = this.clock();
    // DynamoDB deletes expired items within days, not at once: checked here.
    if (!session || session.ttl * 1000 <= now.getTime()) throw signedOut();
    if (now.getTime() - Date.parse(session.lastUsedAt) > DAY_MS) {
      // Best effort: a failed slide (throttled, say) is retried on the next
      // request; the session is still good for months.
      await this.deps.store.touchSession(id, session.lastUsedAt, now.toISOString(), expiry(now)).catch((e: unknown) => {
        console.error(JSON.stringify({ level: 'warn', msg: 'session slide failed', error: String(e) }));
      });
    }
    const email = session.emailVerified ? session.email : undefined;
    return {
      subject: session.subject,
      ...(email ? { email } : {}),
      admin: email !== undefined && (await this.deps.config.isAdmin(email)),
      sessionId: id,
    };
  }
}

function expiry(from: Date): number {
  return Math.floor((from.getTime() + SESSION_DAYS * DAY_MS) / 1000);
}

/** A stable, opaque folder name for the subject's photos. */
export function subjectHash(subject: string): string {
  return createHash('sha256').update(subject).digest('hex').slice(0, 32);
}
