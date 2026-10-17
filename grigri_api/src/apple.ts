// Sign in with Apple (specs/sign-in.md): the identity token the iPhone app
// gets from Apple, verified in the function like Google's (POST
// /api/session): RS256 signature against Apple's published keys, issuer
// https://appleid.apple.com, audience the app's bundle ID, expiry, and the
// nonce (Apple's token carries the SHA-256 of the app's random nonce, which
// the app sends along). The key set is fetched once and cached by jose
// across warm invocations (an unknown key ID triggers a rate-limited
// refetch).
//
// Revocation (Apple requires it when an account is deleted): with a Sign
// in with Apple key configured, the authorization code that comes with a
// sign-in is exchanged for a refresh token, kept with the account (never
// logged), and revokeAppleTokens revokes it. Without the key, both are
// skipped with a warning.
import { createHash } from 'node:crypto';
import { createRemoteJWKSet, decodeJwt, errors, importPKCS8, jwtVerify, type JWTVerifyGetKey, SignJWT } from 'jose';
import { type GoogleIdentity, InvalidIdToken } from './google.js';

export const APPLE_ISSUER = 'https://appleid.apple.com';
export const APPLE_JWKS_URL = 'https://appleid.apple.com/auth/keys';
export const APPLE_TOKEN_URL = 'https://appleid.apple.com/auth/token';
export const APPLE_REVOKE_URL = 'https://appleid.apple.com/auth/revoke';
/** The app's bundle ID: the audience of its identity tokens. */
export const DEFAULT_APPLE_BUNDLE_ID = 'com.nu01.grigri';
/** Subjects of Apple accounts: `apple#<sub>`. */
export const APPLE_SUBJECT_PREFIX = 'apple#';

/** A verified Apple account (the same shape as a Google one). */
export type AppleIdentity = GoogleIdentity;

/** Verifies an identity token issued with the SHA-256 of `rawNonce`. */
export type AppleTokenVerifier = (idToken: string, rawNonce: string) => Promise<AppleIdentity>;

/** Module scope: one key set per warm Lambda container. */
let remoteKeys: JWTVerifyGetKey | undefined;
function appleKeys(): JWTVerifyGetKey {
  remoteKeys ??= createRemoteJWKSet(new URL(APPLE_JWKS_URL), { timeoutDuration: 3000 });
  return remoteKeys;
}

export function sha256Hex(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

/**
 * A verifier for identity tokens Apple issued to `bundleId` (the iOS app).
 * `keys` defaults to Apple's JWKS (tests pass a local key set). No bundle
 * ID: every token is refused.
 */
export function appleVerifier(bundleId: string, keys: JWTVerifyGetKey = appleKeys()): AppleTokenVerifier {
  return async (idToken, rawNonce) => {
    if (!bundleId) throw new InvalidIdToken('no Apple client configured');
    if (idToken.length > 4096 || idToken.split('.').length !== 3) throw new InvalidIdToken('not a JWT');
    if (rawNonce.length === 0) throw new InvalidIdToken('no nonce');
    let payload;
    try {
      ({ payload } = await jwtVerify(idToken, keys, {
        issuer: APPLE_ISSUER,
        audience: bundleId,
        algorithms: ['RS256'],
        requiredClaims: ['sub', 'exp', 'iat', 'nonce'],
        clockTolerance: 30,
      }));
    } catch (e) {
      // Apple's key endpoint unreachable: our fault, not the token's.
      if (e instanceof errors.JWKSTimeout || (e instanceof Error && e.name === 'TypeError')) throw e;
      throw new InvalidIdToken(e instanceof Error ? e.message : String(e));
    }
    if (typeof payload.sub !== 'string' || payload.sub.length === 0 || payload.sub.length > 255) {
      throw new InvalidIdToken('bad sub');
    }
    // The token was issued for this sign-in: Apple signed the nonce's hash.
    if (payload.nonce !== sha256Hex(rawNonce)) throw new InvalidIdToken('nonce mismatch');
    // Apple's email (maybe a private relay address) is always verified,
    // and said so as a boolean or a string.
    const verified = payload.email_verified === true || payload.email_verified === 'true';
    const email = verified && typeof payload.email === 'string' ? payload.email.toLowerCase() : undefined;
    return {
      subject: `${APPLE_SUBJECT_PREFIX}${payload.sub}`,
      ...(email ? { email } : {}),
      emailVerified: email !== undefined,
    };
  };
}

// --- Refresh tokens and revocation ----------------------------------------------

/** What the Apple tokens need from the store (Store implements it). */
export interface AppleTokenStore {
  putAppleToken(subject: string, refreshToken: string, now: Date): Promise<void>;
  getAppleToken(subject: string): Promise<string | undefined>;
  deleteAppleToken(subject: string): Promise<void>;
  /** The subject a profile was created for, if any. */
  subjectOf(climberId: string): Promise<string | undefined>;
}

export interface AppleKeyConfig {
  /** The client ID the codes and tokens belong to: the bundle ID. */
  clientId: string;
  /** The Apple Developer team ID (10 characters). */
  teamId: string;
  /** The Sign in with Apple key's ID (10 characters). */
  keyId: string;
  /** The key's .p8 file: PEM, or its base64 body alone. A secret. */
  privateKey: string;
}

/** What became of a revocation. */
export type RevokeOutcome = 'revoked' | 'none' | 'skipped' | 'failed';

type Fetch = typeof fetch;

const warn = (msg: string, extra: Record<string, unknown> = {}) =>
  console.error(JSON.stringify({ level: 'warn', msg, ...extra }));

/** PKCS#8 PEM from a .p8 file's text or its base64 body; undefined if neither. */
export function pkcs8Pem(raw: string): string | undefined {
  const body = raw.replace(/-----(BEGIN|END) PRIVATE KEY-----/g, '').replace(/\s+/g, '');
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(body)) return undefined;
  return `-----BEGIN PRIVATE KEY-----\n${body.match(/.{1,64}/g)!.join('\n')}\n-----END PRIVATE KEY-----\n`;
}

/**
 * Apple's token endpoints for one client: trades a sign-in's authorization
 * code for a refresh token (kept per subject) and revokes it. Needs the
 * Sign in with Apple key; without it, `configured` is false and both are
 * skipped with a warning.
 */
export class AppleTokens {
  readonly configured: boolean;
  private readonly pem: string | undefined;
  private key: ReturnType<typeof importPKCS8> | undefined;
  private warned = false;

  constructor(
    private readonly config: AppleKeyConfig,
    private readonly store: AppleTokenStore,
    private readonly http: Fetch = fetch,
    private readonly clock: () => Date = () => new Date(),
  ) {
    this.pem = config.privateKey ? pkcs8Pem(config.privateKey) : undefined;
    this.configured =
      config.clientId.length > 0 &&
      /^[A-Z0-9]{10}$/.test(config.teamId) &&
      /^[A-Z0-9]{10}$/.test(config.keyId) &&
      this.pem !== undefined;
  }

  /**
   * After an Apple sign-in: trades its authorization code for a refresh
   * token and keeps it with `subject`. Best effort: a failure is logged
   * (never the code or the token) and the sign-in goes on.
   */
  async keepRefreshToken(subject: string, code: string): Promise<void> {
    if (!this.configured) {
      if (!this.warned) warn('Sign in with Apple key not configured: Apple refresh tokens are not kept, so they cannot be revoked');
      this.warned = true;
      return;
    }
    try {
      const res = await this.post(APPLE_TOKEN_URL, { code, grant_type: 'authorization_code' });
      if (!res.ok) {
        warn('Apple refused the authorization code', { status: res.status, error: await appleError(res) });
        return;
      }
      const body = (await res.json()) as { refresh_token?: unknown; id_token?: unknown };
      if (typeof body.refresh_token !== 'string' || body.refresh_token.length === 0) {
        warn('Apple answered no refresh token');
        return;
      }
      // The code must be this account's (not someone else's sent along
      // with my identity token): Apple's own ID token, straight from Apple
      // over TLS, says whose it is.
      const sub = typeof body.id_token === 'string' ? safeSub(body.id_token) : undefined;
      if (`${APPLE_SUBJECT_PREFIX}${sub}` !== subject) {
        warn('Apple authorization code is for another account: not kept');
        return;
      }
      await this.store.putAppleToken(subject, body.refresh_token, this.clock());
    } catch (e) {
      warn('Apple authorization code exchange failed', { error: errorName(e) });
    }
  }

  /**
   * Revokes the Apple refresh token kept for the climber's account (an
   * Apple account's; Google ones have none), then forgets it. Never
   * throws: 'revoked', 'none' (not an Apple account, or no token kept),
   * 'skipped' (no key configured) or 'failed' (logged). The kept token is
   * deleted whatever the outcome, as the account is going.
   */
  async revoke(climberId: string): Promise<RevokeOutcome> {
    try {
      const subject = await this.store.subjectOf(climberId);
      if (!subject?.startsWith(APPLE_SUBJECT_PREFIX)) return 'none';
      const token = await this.store.getAppleToken(subject);
      if (!this.configured) {
        warn('Sign in with Apple key not configured: Apple tokens not revoked');
        if (token) await this.store.deleteAppleToken(subject);
        return 'skipped';
      }
      if (!token) return 'none';
      let outcome: RevokeOutcome = 'revoked';
      try {
        const res = await this.post(APPLE_REVOKE_URL, { token, token_type_hint: 'refresh_token' });
        if (!res.ok) {
          warn('Apple refused to revoke the token', { status: res.status, error: await appleError(res) });
          outcome = 'failed';
        }
      } catch (e) {
        warn('Apple token revocation failed', { error: errorName(e) });
        outcome = 'failed';
      }
      await this.store.deleteAppleToken(subject);
      return outcome;
    } catch (e) {
      warn('Apple token revocation failed', { error: errorName(e) });
      return 'failed';
    }
  }

  /** A form POST to Apple with this client's ID and secret. */
  private async post(url: string, form: Record<string, string>): Promise<Response> {
    const body = new URLSearchParams({ client_id: this.config.clientId, client_secret: await this.clientSecret(), ...form });
    return this.http(url, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body,
      signal: AbortSignal.timeout(3000),
    });
  }

  /** The client secret: a short-lived ES256 JWT signed with the key. */
  async clientSecret(): Promise<string> {
    this.key ??= importPKCS8(this.pem!, 'ES256');
    const now = Math.floor(this.clock().getTime() / 1000);
    return new SignJWT({})
      .setProtectedHeader({ alg: 'ES256', kid: this.config.keyId })
      .setIssuer(this.config.teamId)
      .setIssuedAt(now)
      .setExpirationTime(now + 300)
      .setAudience(APPLE_ISSUER)
      .setSubject(this.config.clientId)
      .sign(await this.key);
  }
}

function safeSub(jwt: string): string | undefined {
  try {
    const sub = decodeJwt(jwt).sub;
    return typeof sub === 'string' && sub.length > 0 ? sub : undefined;
  } catch {
    return undefined;
  }
}

/** Apple's error code (`invalid_grant`, say): never a token. */
async function appleError(res: Response): Promise<string | undefined> {
  try {
    const body = (await res.json()) as { error?: unknown };
    return typeof body.error === 'string' && /^[a-z_]{1,40}$/.test(body.error) ? body.error : undefined;
  } catch {
    return undefined;
  }
}

/** An error's kind and message, without anything a request carried. */
function errorName(e: unknown): string {
  return e instanceof Error ? `${e.name}: ${e.message}` : 'unknown';
}
