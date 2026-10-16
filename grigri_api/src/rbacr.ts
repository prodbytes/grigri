// Grigri's roles are rbacr's (specs/roles.md): rbacr (https://rbacr.nu01.com,
// prodbytes' role manager) decides who is an admin, Premium or blocked,
// and the API asks it, and grants and revokes Premium and blocked, with an
// rbacr API token owned by an rbacr root (only roots may ask about other
// people, or grant). Calls go through rbacr's client library, rbacr-lib:
// answers kept a minute (a "yes" never past its grant's end), failures
// never; checks fail closed. One client per configuration, so a grant
// drops what the same function instance kept about that person.
import { RbacrClient } from 'rbacr-lib';

export const RBACR_SYSTEM = 'grigri';
export const ADMIN_ROLE = 'admin';
/** Premium (specs/premium.md): granted while paid, by the Stripe webhook; admins have it too (rbacr: admin implies premium). */
export const PREMIUM_ROLE = 'premium';
/** Blocked by an admin (specs/admin.md): nothing but signing out. */
export const BLOCKED_ROLE = 'blocked';
const TIMEOUT_MS = 3000;
const CACHE_MS = 60_000;

export type AdminCheck = (email: string) => Promise<boolean>;

export interface RbacrConfig {
  /** rbacr's site, e.g. https://rbacr.nu01.com. */
  url: string;
  /** An rbacr API token owned by a root; empty: no rbacr (nobody is an admin). */
  token: string;
  fetch?: typeof fetch;
  clock?: () => number;
}

const clients = new WeakMap<RbacrConfig, RbacrClient | null>();

/** The rbacr client for a configuration (shared by its checks, lookups and grants); null without a URL or token. */
export function rbacrClient(config: RbacrConfig): RbacrClient | null {
  if (clients.has(config)) return clients.get(config)!;
  const url = config.url.trim();
  const token = config.token.trim();
  let client: RbacrClient | null = null;
  if (url && token) {
    const doFetch = config.fetch ?? fetch;
    client = new RbacrClient({
      url,
      token,
      cacheMs: CACHE_MS,
      timeoutMs: TIMEOUT_MS,
      clock: config.clock,
      // rbacr-lib keeps failures to itself; the function's log hears of them.
      fetch: (async (input: Parameters<typeof fetch>[0], init?: Parameters<typeof fetch>[1]) => {
        try {
          const res = await doFetch(input, init);
          if (res.status >= 500 || res.status === 401 || res.status === 403) {
            console.error(JSON.stringify({ level: 'warn', msg: 'rbacr answered an error', status: res.status, path: new URL(String(input)).pathname }));
          }
          return res;
        } catch (e) {
          console.error(JSON.stringify({ level: 'warn', msg: 'rbacr unreachable', error: String(e) }));
          throw e;
        }
      }) as typeof fetch,
    });
  }
  clients.set(config, client);
  return client;
}

/** Whether a verified email is a Grigri admin: rbacr's `grigri` `admin` role (roots hold every role). Fails closed. */
export function rbacrAdminCheck(config: RbacrConfig): AdminCheck {
  return async (email) => rbacrClient(config)?.allows(email, RBACR_SYSTEM, ADMIN_ROLE) ?? false;
}

/**
 * My roles in Grigri, sorted; null when rbacr can't say (no token, an
 * error). `fresh`: ask rbacr even when an answer is kept (right after
 * paying, say).
 */
export type RolesLookup = (email: string, options?: { fresh?: boolean }) => Promise<string[] | null>;

/** The roles someone holds in Grigri: their effective roles in the grigri system plus their global ones (`root`), sorted. */
export function rbacrRoles(config: RbacrConfig): RolesLookup {
  return async (email, options) => rbacrClient(config)?.rolesOf(email, RBACR_SYSTEM, options) ?? null;
}

/**
 * Grants and revokes Grigri's roles in rbacr (roots only, so the same
 * root token). Unlike the lookups these fail loudly: the Stripe webhook
 * answers an error, so Stripe sends the event again.
 */
export interface RoleGrants {
  /** Grants a role, until `endsAt` (again with another end replaces it). */
  grant(email: string, role: string, endsAt?: string): Promise<void>;
  /** Nothing to revoke (no such grant) is fine. */
  revoke(email: string, role: string): Promise<void>;
  /**
   * Everyone a role is granted to now (by email; direct grants, not
   * implied ones or roots'): one call for all of them, kept a minute (and
   * dropped by this instance's own grants and revokes). Errors throw.
   */
  holders(role: string): Promise<Set<string>>;
}

export function rbacrGrants(config: RbacrConfig): RoleGrants | null {
  const client = rbacrClient(config);
  if (!client) return null;
  return {
    async grant(email, role, endsAt) {
      await client.grant({ systemId: RBACR_SYSTEM, role, grantee: email, ...(endsAt ? { endsAt } : {}) });
    },
    async revoke(email, role) {
      await client.revoke({ systemId: RBACR_SYSTEM, role, grantee: email });
    },
    holders: (role) => client.holders(RBACR_SYSTEM, role),
  };
}
