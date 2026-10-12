// Who's calling. In AWS (and locally with a Google client), the HTTP API's
// JWT authorizer has already verified the Google ID token: the function
// reads its claims. In local dev mode only, there's no authorizer and the
// caller names themselves in the X-Grigri-Dev-User header.
import { createHash } from 'node:crypto';
import { ApiError } from './domain/errors.js';

export interface Caller {
  /** `<iss>#<sub>`: the signed-in account. */
  subject: string;
  /** Verified email, lowercased; only for the admin check, never returned. */
  email?: string;
  admin: boolean;
}

export interface AuthConfig {
  /** Local dev mode (template: DevMode, allowed only for Stage local). */
  devMode: boolean;
  adminEmails: ReadonlySet<string>;
}

export function parseAdminEmails(value: string | undefined): Set<string> {
  return new Set(
    (value ?? '')
      .split(',')
      .map((e) => e.trim().toLowerCase())
      .filter((e) => e.length > 0),
  );
}

const EMAIL = /^[^\s@,]{1,64}@[A-Za-z0-9.-]{1,253}\.[A-Za-z]{2,63}$/;

type Claims = Record<string, unknown>;

/** The caller, or a 401. */
export function caller(
  claims: Claims | undefined,
  headers: Record<string, string | undefined>,
  config: AuthConfig,
): Caller {
  if (claims && typeof claims.sub === 'string' && typeof claims.iss === 'string') {
    const verified = claims.email_verified === true || claims.email_verified === 'true';
    const email = verified && typeof claims.email === 'string' ? claims.email.toLowerCase() : undefined;
    return {
      subject: `${claims.iss}#${claims.sub}`,
      ...(email ? { email } : {}),
      admin: email !== undefined && config.adminEmails.has(email),
    };
  }
  if (config.devMode) {
    const dev = headers['x-grigri-dev-user']?.trim().toLowerCase();
    if (dev && EMAIL.test(dev)) {
      return { subject: `dev#${dev}`, email: dev, admin: config.adminEmails.has(dev) };
    }
    throw new ApiError(401, 'dev mode: send X-Grigri-Dev-User: <email>');
  }
  throw new ApiError(401, 'sign in first');
}

/** A stable, opaque folder name for the subject's photos. */
export function subjectHash(subject: string): string {
  return createHash('sha256').update(subject).digest('hex').slice(0, 32);
}
