// Stripe, for Premium (specs/premium.md), over its REST API with fetch (no
// SDK: a few calls, and a smaller bundle). Checkout and the billing portal
// are Stripe's own pages: no card ever reaches Grigri. Webhook events are
// verified by their signature, then the subscription they're about is read
// back from Stripe, so its saved copy is always Stripe's latest, whatever
// order the events arrive in.
import { createHmac, timingSafeEqual } from 'node:crypto';
import { PREMIUM_PRICES, type PremiumPlan, type Subscription } from './premium.js';

const API = 'https://api.stripe.com/v1';

/** A signed event older than this is refused (Stripe's own default). */
export const SIGNATURE_TOLERANCE_S = 300;

export interface StripeConfig {
  /** The secret key (sk_live_… or sk_test_…, or a restricted rk_…). */
  secretKey: string;
  /** The webhook endpoint's signing secret (whsec_…). */
  webhookSecret: string;
  /** The site, where Checkout and the portal send people back: https://grigri.nu01.com. */
  siteUrl: string;
}

/** What the API needs from Stripe. */
export interface Billing {
  /** A Checkout page for the plan; Stripe sends them back to the app. */
  checkout(climberId: string, plan: PremiumPlan, customerId?: string): Promise<string>;
  /** The billing portal: cancel, change card, invoices. */
  portal(customerId: string): Promise<string>;
  /** A webhook's event, verified; throws BadSignature. */
  event(rawBody: string, signature: string | undefined, now: Date): StripeEvent;
  /** The subscription as Stripe has it now; undefined when it isn't one of Grigri's. */
  subscription(subscriptionId: string, now: Date): Promise<Subscription | undefined>;
}

export interface StripeEvent {
  id: string;
  type: string;
  data: { object: Record<string, unknown> };
}

export class BadSignature extends Error {}

type Fetch = typeof fetch;

/** Stripe for Premium; null without a secret key and a webhook secret (no Premium). */
export function stripeBilling(config: StripeConfig, fetchFn: Fetch = fetch): Billing | null {
  if (!config.secretKey || !config.webhookSecret || !config.siteUrl) return null;
  const site = config.siteUrl.replace(/\/+$/, '');

  async function call(method: 'GET' | 'POST', path: string, form?: Record<string, string>): Promise<Record<string, unknown>> {
    const res = await fetchFn(`${API}${path}`, {
      method,
      headers: {
        authorization: `Bearer ${config.secretKey}`,
        ...(form ? { 'content-type': 'application/x-www-form-urlencoded' } : {}),
      },
      body: form ? new URLSearchParams(form).toString() : undefined,
      signal: AbortSignal.timeout(8000),
    });
    const json = (await res.json().catch(() => ({}))) as Record<string, unknown>;
    if (!res.ok) {
      // Stripe's message, never the key or the request.
      const message = (json.error as { message?: string } | undefined)?.message ?? `HTTP ${res.status}`;
      throw new Error(`stripe ${method} ${path.split('?')[0]}: ${message}`);
    }
    return json;
  }

  return {
    async checkout(climberId, plan, customerId) {
      const price = PREMIUM_PRICES[plan];
      const session = await call('POST', '/checkout/sessions', {
        mode: 'subscription',
        client_reference_id: climberId,
        ...(customerId ? { customer: customerId } : {}),
        'line_items[0][quantity]': '1',
        'line_items[0][price_data][currency]': price.currency,
        'line_items[0][price_data][unit_amount]': String(price.amount),
        'line_items[0][price_data][recurring][interval]': plan === 'monthly' ? 'month' : 'year',
        'line_items[0][price_data][product_data][name]': 'Grigri Premium',
        // Which climber a subscription is for, on every event about it.
        'subscription_data[metadata][climberId]': climberId,
        'subscription_data[metadata][app]': 'grigri',
        success_url: `${site}/app/premium.html?premium=done`,
        cancel_url: `${site}/app/premium.html?premium=cancelled`,
      });
      return String(session.url);
    },

    async portal(customerId) {
      const session = await call('POST', '/billing_portal/sessions', {
        customer: customerId,
        return_url: `${site}/app/premium.html?premium=managed`,
      });
      return String(session.url);
    },

    event(rawBody, signature, now) {
      if (!signature) throw new BadSignature('no signature');
      const parts = signature.split(',').map((p) => p.split('=', 2) as [string, string]);
      const t = Number(parts.find(([k]) => k === 't')?.[1]);
      const sigs = parts.filter(([k]) => k === 'v1').map(([, v]) => v);
      if (!Number.isFinite(t) || sigs.length === 0) throw new BadSignature('malformed signature');
      if (Math.abs(now.getTime() / 1000 - t) > SIGNATURE_TOLERANCE_S) throw new BadSignature('signature too old');
      const expected = createHmac('sha256', config.webhookSecret).update(`${t}.${rawBody}`).digest();
      const ok = sigs.some((s) => {
        const got = Buffer.from(s, 'hex');
        return got.length === expected.length && timingSafeEqual(got, expected);
      });
      if (!ok) throw new BadSignature('signature mismatch');
      const parsed = JSON.parse(rawBody) as StripeEvent;
      if (typeof parsed?.type !== 'string' || typeof parsed?.data?.object !== 'object') throw new BadSignature('not an event');
      return parsed;
    },

    async subscription(subscriptionId, now) {
      const s = await call('GET', `/subscriptions/${encodeURIComponent(subscriptionId)}`);
      return toSubscription(s, now);
    },
  };
}

/** Stripe's subscription object as Grigri keeps it; undefined when it isn't Grigri Premium. */
export function toSubscription(s: Record<string, unknown>, now: Date): Subscription | undefined {
  const metadata = (s.metadata ?? {}) as Record<string, string>;
  const climberId = metadata.climberId;
  if (!climberId || typeof s.id !== 'string') return undefined;
  const item = ((s.items as { data?: Record<string, unknown>[] } | undefined)?.data ?? [])[0] ?? {};
  const interval = ((item.price as { recurring?: { interval?: string } } | undefined)?.recurring?.interval) ?? '';
  // Newer API versions keep the period on the item; older ones on the subscription.
  const end = Number(item.current_period_end ?? s.current_period_end);
  const customer = typeof s.customer === 'string' ? s.customer : String((s.customer as { id?: string } | null)?.id ?? '');
  return {
    climberId,
    customerId: customer,
    subscriptionId: s.id,
    status: String(s.status ?? ''),
    plan: interval === 'year' ? 'yearly' : 'monthly',
    periodEnd: Number.isFinite(end) && end > 0 ? new Date(end * 1000).toISOString() : now.toISOString(),
    cancelAtPeriodEnd: s.cancel_at_period_end === true,
    updatedAt: now.toISOString(),
  };
}

/** The subscription an event is about, if any. */
export function subscriptionIdOf(event: StripeEvent): string | undefined {
  const o = event.data.object;
  if (event.type.startsWith('customer.subscription.')) return typeof o.id === 'string' ? o.id : undefined;
  // checkout.session.completed, invoice.paid, invoice.payment_failed…
  const sub = o.subscription ?? (o.parent as { subscription_details?: { subscription?: unknown } } | undefined)?.subscription_details?.subscription;
  if (typeof sub === 'string') return sub;
  if (sub && typeof (sub as { id?: unknown }).id === 'string') return (sub as { id: string }).id;
  return undefined;
}
