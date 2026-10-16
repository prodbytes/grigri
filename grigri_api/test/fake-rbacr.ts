// rbacr as Grigri's API sees it: grants by email, with an optional end,
// and admin implying premium (as scripts/rbacr-setup.sh sets it up).
import type { RoleGrants, RolesLookup } from '../src/rbacr.js';

export class FakeRbacr {
  constructor(private readonly clock: () => Date) {}

  /** email -> role -> when it ends (null: never). */
  readonly grants = new Map<string, Map<string, string | null>>();
  /** Every grant and revoke asked for, as "grant premium a@x until …" / "revoke premium a@x". */
  readonly calls: string[] = [];
  /** The next grant or revoke fails (rbacr down). */
  failNext = false;

  give(email: string, role: string, endsAt: string | null = null) {
    const key = email.toLowerCase();
    if (!this.grants.has(key)) this.grants.set(key, new Map());
    this.grants.get(key)!.set(role, endsAt);
  }

  /** Effective roles: grants not yet ended, plus what they imply. */
  rolesOf(email: string): string[] {
    const now = this.clock().getTime();
    const held = [...(this.grants.get(email.toLowerCase()) ?? new Map<string, string | null>())]
      .filter(([, ends]) => ends === null || Date.parse(ends) > now)
      .map(([role]) => role);
    if (held.includes('admin')) held.push('premium');
    return [...new Set(held)].sort();
  }

  readonly lookup: RolesLookup = async (email) => this.rolesOf(email);

  readonly api: RoleGrants = {
    grant: async (email, role, endsAt) => {
      this.check();
      this.calls.push(`grant ${role} ${email}${endsAt ? ` until ${endsAt}` : ''}`);
      this.give(email, role, endsAt ?? null);
    },
    revoke: async (email, role) => {
      this.check();
      this.calls.push(`revoke ${role} ${email}`);
      this.grants.get(email.toLowerCase())?.delete(role);
    },
    holders: async (role) => {
      this.check();
      const now = this.clock().getTime();
      return new Set(
        [...this.grants].filter(([, roles]) => roles.has(role) && (roles.get(role) === null || Date.parse(roles.get(role)!) > now)).map(([email]) => email),
      );
    },
  };

  private check() {
    if (this.failNext) {
      this.failNext = false;
      throw new Error('rbacr answered 503');
    }
  }
}
