// Premium (specs/premium.md): a subscription, paid through Stripe. Who is
// Premium is rbacr's: its `premium` role, which the Stripe webhook grants
// while the subscription is paid (and admins hold through rbacr's
// implication). The subscription's billing state is Stripe's; the API
// keeps a copy, refreshed from Stripe on every webhook event about it
// (stripe.ts), for the plan, the renewal date and the billing portal.

export type PremiumPlan = 'monthly' | 'yearly';

/** What each plan costs, in cents (US dollars). */
export const PREMIUM_PRICES: Record<PremiumPlan, { amount: number; currency: 'usd' }> = {
  monthly: { amount: 2000, currency: 'usd' },
  yearly: { amount: 20000, currency: 'usd' },
};

/** A climber's subscription, as last read from Stripe. */
export interface Subscription {
  climberId: string;
  customerId: string;
  subscriptionId: string;
  /** Stripe's status: active, trialing, past_due, canceled, unpaid, incomplete… */
  status: string;
  plan: PremiumPlan;
  /** When the paid period ends (ISO 8601). */
  periodEnd: string;
  /** Cancelled: it ends at periodEnd and won't renew. */
  cancelAtPeriodEnd: boolean;
  updatedAt: string;
  /** Whose it is in rbacr: the subscriber's verified email, from checkout (the subscription's metadata). */
  email?: string;
}

/** Premium as the app sees it. */
export interface Premium {
  active: boolean;
  plan?: PremiumPlan;
  /** Paid until (ISO 8601). */
  until?: string;
  /** Won't renew: ends at `until`. */
  ending?: boolean;
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
    ? { active, plan: sub.plan, until: sub.periodEnd, ...(sub.cancelAtPeriodEnd ? { ending: true } : {}) }
    : { active: false };
}
