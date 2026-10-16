// Who is a Grigri admin: rbacr (https://rbacr.nu01.com, prodbytes' role
// manager) decides, not the API. Asks POST <url>/api/check
// {email, systemId: "grigri", role: "admin"} with an rbacr API token owned
// by an rbacr root (only roots may ask about other people); rbacr's roots
// hold every role, so they're admins too. Fails closed: no token, a
// timeout, an error or an unexpected answer means "not an admin". Answers
// are cached for CACHE_MS (errors never are), so a role change shows
// within a minute and most requests cost no call.

export const RBACR_SYSTEM = 'grigri';
export const ADMIN_ROLE = 'admin';
/** Premium (specs/premium.md): granted while paid, by the Stripe webhook; admins have it too (rbacr: admin implies premium). */
export const PREMIUM_ROLE = 'premium';
/** Blocked by an admin (specs/admin.md): nothing but signing out. */
export const BLOCKED_ROLE = 'blocked';
const TIMEOUT_MS = 2000;
const CACHE_MS = 60_000;

export type AdminCheck = (email: string) => Promise<boolean>;

export interface RbacrConfig {
  /** rbacr's site, e.g. https://rbacr.nu01.com. */
  url: string;
  /** An rbacr API token owned by a root; empty: nobody is an admin. */
  token: string;
  fetch?: typeof fetch;
  clock?: () => number;
}

export function rbacrAdminCheck(config: RbacrConfig): AdminCheck {
  const url = config.url.replace(/\/+$/, '');
  const token = config.token.trim();
  if (!url || !token) return async () => false;
  const doFetch = config.fetch ?? fetch;
  const clock = config.clock ?? Date.now;
  const cache = new Map<string, { admin: boolean; until: number }>();

  return async (email: string) => {
    const key = email.toLowerCase();
    const hit = cache.get(key);
    if (hit && hit.until > clock()) return hit.admin;
    try {
      const res = await doFetch(`${url}/api/check`, {
        method: 'POST',
        headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
        body: JSON.stringify({ email: key, systemId: RBACR_SYSTEM, role: ADMIN_ROLE }),
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
      let admin = false;
      if (res.status === 404) {
        // No grigri system or admin role in rbacr: nobody is one (cached).
        console.error(JSON.stringify({ level: 'warn', msg: `rbacr has no ${RBACR_SYSTEM} system or ${ADMIN_ROLE} role` }));
      } else if (!res.ok) {
        throw new Error(`rbacr answered ${res.status}`);
      } else {
        admin = ((await res.json()) as { allowed?: unknown }).allowed === true;
      }
      cache.set(key, { admin, until: clock() + CACHE_MS });
      return admin;
    } catch (e) {
      console.error(JSON.stringify({ level: 'warn', msg: 'rbacr admin check failed', error: String(e) }));
      return false;
    }
  };
}

/**
 * My roles in Grigri, sorted; null when rbacr can't say (no token, an
 * error). `fresh`: ask rbacr even when an answer is kept (right after
 * paying, say).
 */
export type RolesLookup = (email: string, options?: { fresh?: boolean }) => Promise<string[] | null>;

// The roles someone holds in Grigri, for their own profile: POST
// <url>/api/roles {email} with the same root token; their effective roles
// in the grigri system plus their global ones (`root`), sorted, without
// duplicates. Cached like the admin check; errors (null) never are.
export function rbacrRoles(config: RbacrConfig): RolesLookup {
  const url = config.url.replace(/\/+$/, '');
  const token = config.token.trim();
  if (!url || !token) return async () => null;
  const doFetch = config.fetch ?? fetch;
  const clock = config.clock ?? Date.now;
  const cache = new Map<string, { roles: string[]; until: number }>();

  return async (email: string, options?: { fresh?: boolean }) => {
    const key = email.toLowerCase();
    const hit = cache.get(key);
    if (hit && hit.until > clock() && !options?.fresh) return hit.roles;
    try {
      const res = await doFetch(`${url}/api/roles`, {
        method: 'POST',
        headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
        body: JSON.stringify({ email: key }),
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
      if (!res.ok) throw new Error(`rbacr answered ${res.status}`);
      const body = (await res.json()) as { globalRoles?: unknown; roles?: Record<string, unknown> };
      const strings = (v: unknown) => (Array.isArray(v) ? v.filter((r): r is string => typeof r === 'string') : []);
      const roles = [...new Set([...strings(body.roles?.[RBACR_SYSTEM]), ...strings(body.globalRoles)])].sort();
      cache.set(key, { roles, until: clock() + CACHE_MS });
      return roles;
    } catch (e) {
      console.error(JSON.stringify({ level: 'warn', msg: 'rbacr roles lookup failed', error: String(e) }));
      return null;
    }
  };
}

/**
 * Grants and revokes Grigri's roles in rbacr (roots only, so the same
 * root token): `POST /api/systems/grigri/grants {role, grantee, endsAt?}`
 * (a grant again with another end replaces it) and `DELETE` with
 * `{role, grantee}`. Unlike the lookups these fail loudly: the Stripe
 * webhook answers an error, so Stripe sends the event again.
 */
export interface RoleGrants {
  grant(email: string, role: string, endsAt?: string): Promise<void>;
  /** Nothing to revoke (no such grant) is fine. */
  revoke(email: string, role: string): Promise<void>;
  /**
   * Everyone a role is granted to now (by email; direct grants, not
   * implied ones or roots'): `GET /api/systems/grigri/grants`, one call for
   * all of them, kept a minute (and dropped by this instance's own grants
   * and revokes). Errors throw; they're never kept.
   */
  holders(role: string): Promise<Set<string>>;
}

export function rbacrGrants(config: RbacrConfig): RoleGrants | null {
  const url = config.url.replace(/\/+$/, '');
  const token = config.token.trim();
  if (!url || !token) return null;
  const doFetch = config.fetch ?? fetch;
  const call = (method: 'POST' | 'DELETE', body: Record<string, string>) =>
    doFetch(`${url}/api/systems/${RBACR_SYSTEM}/grants`, {
      method,
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(TIMEOUT_MS * 2),
    });
  const clock = config.clock ?? Date.now;
  const held = new Map<string, { emails: Set<string>; until: number }>();
  return {
    async grant(email, role, endsAt) {
      held.delete(role);
      const res = await call('POST', { role, grantee: email.toLowerCase(), ...(endsAt ? { endsAt } : {}) });
      if (!res.ok) throw new Error(`rbacr grant of ${role} answered ${res.status}`);
    },
    async revoke(email, role) {
      held.delete(role);
      const res = await call('DELETE', { role, grantee: email.toLowerCase() });
      if (!res.ok && res.status !== 404) throw new Error(`rbacr revoke of ${role} answered ${res.status}`);
    },
    async holders(role) {
      const hit = held.get(role);
      if (hit && hit.until > clock()) return hit.emails;
      const res = await doFetch(`${url}/api/systems/${RBACR_SYSTEM}/grants`, {
        headers: { authorization: `Bearer ${token}` },
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
      if (!res.ok) throw new Error(`rbacr grants answered ${res.status}`);
      const body = (await res.json()) as { grants?: { role?: unknown; grantee?: unknown; status?: unknown }[] };
      const emails = new Set(
        (body.grants ?? [])
          .filter((g) => g.role === role && g.status === 'active' && typeof g.grantee === 'string')
          .map((g) => (g.grantee as string).toLowerCase()),
      );
      held.set(role, { emails, until: clock() + CACHE_MS });
      return emails;
    },
  };
}
