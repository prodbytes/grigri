// Google ID tokens, verified in the function (POST /api/session is the only
// route that takes one): RS256 signature against Google's published keys,
// issuer, audience (the web client ID) and expiry. The key set is fetched
// once and cached by jose across warm invocations (refetched when Google
// rotates its keys: an unknown key ID triggers a refetch, rate-limited).
import { createRemoteJWKSet, errors, jwtVerify, type JWTVerifyGetKey } from 'jose';

export const GOOGLE_JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs';
/** Google issues tokens with either issuer; both mean the same accounts. */
export const GOOGLE_ISSUERS = ['https://accounts.google.com', 'accounts.google.com'];

/** A verified Google account. */
export interface GoogleIdentity {
  /** `https://accounts.google.com#<sub>`, whichever issuer spelling the token had. */
  subject: string;
  /** Lowercased; only when Google says it's verified. */
  email?: string;
  emailVerified: boolean;
}

export type IdTokenVerifier = (idToken: string) => Promise<GoogleIdentity>;

/** A bad, expired or foreign token. */
export class InvalidIdToken extends Error {}

/** Module scope: one key set per warm Lambda container. */
let remoteKeys: JWTVerifyGetKey | undefined;
function googleKeys(): JWTVerifyGetKey {
  remoteKeys ??= createRemoteJWKSet(new URL(GOOGLE_JWKS_URL), { timeoutDuration: 3000 });
  return remoteKeys;
}

/**
 * A verifier for ID tokens issued to `audience`. `keys` defaults to
 * Google's JWKS (tests pass a local key set). No audience: every token is
 * refused (dev mode without a Google client).
 */
export function googleVerifier(audience: string, keys: JWTVerifyGetKey = googleKeys()): IdTokenVerifier {
  return async (idToken) => {
    if (!audience) throw new InvalidIdToken('no Google client configured');
    if (idToken.length > 4096 || idToken.split('.').length !== 3) throw new InvalidIdToken('not a JWT');
    let payload;
    try {
      ({ payload } = await jwtVerify(idToken, keys, {
        issuer: GOOGLE_ISSUERS,
        audience,
        algorithms: ['RS256'],
        requiredClaims: ['sub', 'exp', 'iat'],
        clockTolerance: 30,
      }));
    } catch (e) {
      // Google's key endpoint unreachable: our fault, not the token's.
      if (e instanceof errors.JWKSTimeout || (e instanceof Error && e.name === 'TypeError')) throw e;
      throw new InvalidIdToken(e instanceof Error ? e.message : String(e));
    }
    if (typeof payload.sub !== 'string' || payload.sub.length === 0 || payload.sub.length > 255) {
      throw new InvalidIdToken('bad sub');
    }
    const verified = payload.email_verified === true || payload.email_verified === 'true';
    const email = verified && typeof payload.email === 'string' ? payload.email.toLowerCase() : undefined;
    return {
      // One spelling, the one the HTTP API's authorizer used before, so
      // existing sign-in links (SUB#<subject>) still match.
      subject: `https://accounts.google.com#${payload.sub}`,
      ...(email ? { email } : {}),
      emailVerified: email !== undefined,
    };
  };
}
