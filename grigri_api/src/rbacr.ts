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

/** My roles in Grigri, sorted; null when rbacr can't say (no token, an error). */
export type RolesLookup = (email: string) => Promise<string[] | null>;

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

  return async (email: string) => {
    const key = email.toLowerCase();
    const hit = cache.get(key);
    if (hit && hit.until > clock()) return hit.roles;
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
