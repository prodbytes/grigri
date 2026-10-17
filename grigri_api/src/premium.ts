// Premium (specs/premium.md): a subscription, paid through Stripe (Android
// and the web) or Apple's in-app purchase (iOS). Who is Premium is rbacr's:
// its `premium` role, which the Stripe webhook and the App Store's signed
// transactions and notifications grant while the subscription is paid (and
// admins hold through rbacr's implication). The billing state is Stripe's
// or Apple's; the API keeps a copy, refreshed on every webhook event or
// notification about it (stripe.ts, app-store.ts), for the plan, the renewal
// date and where it's managed.

export type PremiumPlan = 'monthly' | 'yearly';

/** What each plan costs through Stripe, in cents (US dollars). The App Store's prices are set in App Store Connect. */
export const PREMIUM_PRICES: Record<PremiumPlan, { amount: number; currency: 'usd' }> = {
  monthly: { amount: 2000, currency: 'usd' },
  yearly: { amount: 20000, currency: 'usd' },
};

/** Who sells it: Stripe (Android and the web) or the App Store (iOS). */
export type PremiumSource = 'stripe' | 'apple';

/** A climber's subscription, as last read from Stripe or signed by Apple. */
export interface Subscription {
  climberId: string;
  /** Stripe's customer; empty for the App Store's. */
  customerId: string;
  /** Stripe's subscription id, or the App Store's original transaction id. */
  subscriptionId: string;
  /** Absent: Stripe (saved before the App Store sold it). */
  source?: PremiumSource;
  /**
   * Stripe's status: active, trialing, past_due, canceled, unpaid,
   * incomplete…; the App Store's are mapped onto them (app-store.ts): active,
   * past_due (billing retry or grace period), expired, canceled (refunded
   * or revoked).
   */
  status: string;
  plan: PremiumPlan;
  /** When the paid period ends (ISO 8601). */
  periodEnd: string;
  /** Cancelled: it ends at periodEnd and won't renew. */
  cancelAtPeriodEnd: boolean;
  updatedAt: string;
  /** Whose it is in rbacr: the subscriber's verified email (Stripe: from checkout, in the subscription's metadata; the App Store: the buyer's session). */
  email?: string;
  /** The App Store's: Production, or Sandbox (App Review, TestFlight, sandbox testers). */
  environment?: 'Production' | 'Sandbox';
  /** The App Store's: when Apple signed the copy saved (ISO 8601); an older one never overwrites it. */
  appleSignedAt?: string;
}

/** Premium as the app sees it. */
export interface Premium {
  active: boolean;
  plan?: PremiumPlan;
  /** Paid until (ISO 8601). */
  until?: string;
  /** Won't renew: ends at `until`. */
  ending?: boolean;
  /** Who sells it, so the app knows where it's managed. */
  source?: PremiumSource;
}

/**
 * Stripe's statuses that keep premium: paid (active, trialing) and a
 * failed renewal Stripe is still retrying (past_due), a grace period.
 */
const PAID = new Set(['active', 'trialing', 'past_due']);

/** Whether a Stripe status keeps premium (before its period's end). */
export function isPaid(status: string): boolean {
  return PAID.has(status);
}

/** Past the period's end, premium lasts this much longer: a late renewal webhook doesn't cut it off. */
const GRACE_MS = 2 * 86_400_000;

/** Until when a paid subscription keeps the role: its period's end plus the grace. */
export function premiumUntil(sub: Subscription): string {
  return new Date(Date.parse(sub.periodEnd) + GRACE_MS).toISOString();
}

/**
 * Premium as the app sees it: whether rbacr says I hold the role, and,
 * from my subscription when it's paid, its plan and dates (none for
 * admins, or Premium granted in rbacr by hand).
 */
export function premiumView(holdsRole: boolean, sub: Subscription | undefined, now: Date): Premium {
  if (!holdsRole) return { active: false };
  const paid = premiumOf(sub, now);
  return paid.active ? paid : { active: true };
}

export function premiumOf(sub: Subscription | undefined, now: Date): Premium {
  if (!sub) return { active: false };
  const active = PAID.has(sub.status) && Date.parse(sub.periodEnd) + GRACE_MS > now.getTime();
  return active
    ? {
        active,
        plan: sub.plan,
        until: sub.periodEnd,
        ...(sub.cancelAtPeriodEnd ? { ending: true } : {}),
        source: sub.source ?? 'stripe',
      }
    : { active: false };
}
