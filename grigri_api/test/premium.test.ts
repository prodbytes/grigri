import { createHmac } from 'node:crypto';
import { beforeEach, describe, expect, it } from 'vitest';
import { Api } from '../src/api.js';
import { Auth, type Caller } from '../src/auth.js';
import { ApiError } from '../src/domain/errors.js';
import { type Subscription, premiumOf } from '../src/premium.js';
import { type Billing, stripeBilling, subscriptionIdOf, toSubscription } from '../src/stripe.js';
import { FakeRbacr } from './fake-rbacr.js';
import { FakeStore } from './fake-store.js';

const now = new Date('2030-05-01T10:00:00.000Z');
const secret = 'whsec_test_made_up';
const sign = (body: string, t = Math.floor(now.getTime() / 1000), key = secret) =>
  `t=${t},v1=${createHmac('sha256', key).update(`${t}.${body}`).digest('hex')}`;

/** Stripe's API, faked: what was asked, and subscriptions by id. */
function fakeStripe() {
  const calls: { method: string; url: string; body: string }[] = [];
  const subscriptions = new Map<string, Record<string, unknown>>();
  const fetchFn = (async (url: string, init: RequestInit) => {
    calls.push({ method: String(init.method), url: String(url), body: String(init.body ?? '') });
    const sub = /\/subscriptions\/(.+)$/.exec(String(url));
    if (sub) {
      const s = subscriptions.get(decodeURIComponent(sub[1]!));
      return new Response(JSON.stringify(s ?? { error: { message: 'No such subscription' } }), { status: s ? 200 : 404 });
    }
    if (String(url).endsWith('/checkout/sessions')) return new Response(JSON.stringify({ url: 'https://checkout.stripe.com/c/pay/cs_test_1' }));
    if (String(url).endsWith('/billing_portal/sessions')) return new Response(JSON.stringify({ url: 'https://billing.stripe.com/p/session/1' }));
    return new Response('{}', { status: 404 });
  }) as typeof fetch;
  const billing = stripeBilling({ secretKey: 'sk_test_made_up', webhookSecret: secret, siteUrl: 'https://grigri.example.com/' }, fetchFn)!;
  return { billing, calls, subscriptions };
}

const stripeSub = (id: string, climberId: string, over: Record<string, unknown> = {}) => ({
  id,
  customer: 'cus_1',
  status: 'active',
  cancel_at_period_end: false,
  metadata: { climberId, app: 'grigri', email: 'ada@example.com' },
  items: { data: [{ current_period_end: Math.floor(Date.parse('2030-06-01T10:00:00Z') / 1000), price: { recurring: { interval: 'month' } } }] },
  ...over,
});

describe('stripe', () => {
  it('verifies webhook signatures: right key, recent, untampered', () => {
    const { billing } = fakeStripe();
    const body = JSON.stringify({ id: 'evt_1', type: 'customer.subscription.updated', data: { object: { id: 'sub_1' } } });
    expect(billing.event(body, sign(body), now).type).toBe('customer.subscription.updated');
    expect(() => billing.event(body, undefined, now)).toThrow(/no signature/);
    expect(() => billing.event(body, sign(body, undefined, 'whsec_other'), now)).toThrow(/mismatch/);
    expect(() => billing.event(`${body} `, sign(body), now)).toThrow(/mismatch/);
    expect(() => billing.event(body, sign(body, Math.floor(now.getTime() / 1000) - 600), now)).toThrow(/too old/);
    expect(() => billing.event(body, 'garbage', now)).toThrow(/malformed/);
  });

  it('checkout asks for a subscription at the plan\'s price, for the climber', async () => {
    const { billing, calls } = fakeStripe();
    expect(await billing.checkout('c1', 'yearly')).toBe('https://checkout.stripe.com/c/pay/cs_test_1');
    const form = new URLSearchParams(calls[0]!.body);
    expect(form.get('mode')).toBe('subscription');
    expect(form.get('client_reference_id')).toBe('c1');
    expect(form.get('line_items[0][price_data][unit_amount]')).toBe('20000');
    expect(form.get('line_items[0][price_data][currency]')).toBe('usd');
    expect(form.get('line_items[0][price_data][recurring][interval]')).toBe('year');
    expect(form.get('subscription_data[metadata][climberId]')).toBe('c1');
    expect(form.get('success_url')).toBe('https://grigri.example.com/app/premium.html?premium=done');
  });

  it('cancels a subscription at once (deleting an account); gone or cancelled already is fine', async () => {
    const { billing, calls, subscriptions } = fakeStripe();
    subscriptions.set('sub_1', stripeSub('sub_1', 'c1'));
    await billing.cancel('sub_1');
    expect(calls.at(-1)).toMatchObject({ method: 'DELETE', url: 'https://api.stripe.com/v1/subscriptions/sub_1' });
    await billing.cancel('sub_unknown');
    // Stripe refuses to cancel twice: fine once it reads back cancelled, else an error.
    const answers: Record<string, unknown>[] = [{ status: 'canceled' }, { status: 'active' }];
    const refusing = stripeBilling({ secretKey: 'sk_test_made_up', webhookSecret: secret, siteUrl: 'https://x' }, (async (_url: string, init: RequestInit) =>
      init.method === 'DELETE'
        ? new Response(JSON.stringify({ error: { message: 'already canceled' } }), { status: 400 })
        : new Response(JSON.stringify(answers.shift()))) as typeof fetch)!;
    await refusing.cancel('sub_1');
    await expect(refusing.cancel('sub_1')).rejects.toThrow(/already canceled/);
  });

  it('no keys, no billing', () => {
    expect(stripeBilling({ secretKey: '', webhookSecret: secret, siteUrl: 'https://x' })).toBeNull();
    expect(stripeBilling({ secretKey: 'sk', webhookSecret: '', siteUrl: 'https://x' })).toBeNull();
  });

  it('reads subscriptions old and new, and only Grigri\'s', () => {
    const s = toSubscription(stripeSub('sub_1', 'c1'), now)!;
    expect(s).toMatchObject({ climberId: 'c1', customerId: 'cus_1', status: 'active', plan: 'monthly', periodEnd: '2030-06-01T10:00:00.000Z' });
    const old = toSubscription({ ...stripeSub('sub_2', 'c1'), items: { data: [{ price: { recurring: { interval: 'year' } } }] }, current_period_end: 1906000000 }, now)!;
    expect(old.plan).toBe('yearly');
    expect(old.periodEnd).toBe(new Date(1906000000 * 1000).toISOString());
    expect(toSubscription({ ...stripeSub('sub_3', 'c1'), metadata: {} }, now)).toBeUndefined();
  });

  it('finds the subscription an event is about', () => {
    const ev = (type: string, object: Record<string, unknown>) => ({ id: 'e', type, data: { object } });
    expect(subscriptionIdOf(ev('customer.subscription.deleted', { id: 'sub_1' }))).toBe('sub_1');
    expect(subscriptionIdOf(ev('checkout.session.completed', { subscription: 'sub_2' }))).toBe('sub_2');
    expect(subscriptionIdOf(ev('invoice.paid', { parent: { subscription_details: { subscription: 'sub_3' } } }))).toBe('sub_3');
    expect(subscriptionIdOf(ev('charge.succeeded', {}))).toBeUndefined();
  });
});

describe('premiumOf', () => {
  const sub = (over: Partial<Subscription> = {}): Subscription => ({
    climberId: 'c1', customerId: 'cus_1', subscriptionId: 'sub_1', status: 'active', plan: 'monthly',
    periodEnd: '2030-05-20T00:00:00.000Z', cancelAtPeriodEnd: false, updatedAt: now.toISOString(), ...over,
  });
  it('is active while paid and within its period (plus two days\' grace)', () => {
    expect(premiumOf(undefined, now)).toEqual({ active: false });
    expect(premiumOf(sub(), now)).toEqual({ active: true, plan: 'monthly', until: '2030-05-20T00:00:00.000Z' });
    expect(premiumOf(sub({ status: 'past_due' }), now).active).toBe(true);
    expect(premiumOf(sub({ status: 'canceled' }), now).active).toBe(false);
    expect(premiumOf(sub({ periodEnd: '2030-04-30T00:00:00.000Z' }), now).active).toBe(true);
    expect(premiumOf(sub({ periodEnd: '2030-04-28T00:00:00.000Z' }), now).active).toBe(false);
    expect(premiumOf(sub({ cancelAtPeriodEnd: true }), now).ending).toBe(true);
  });
});

describe('Premium routes', () => {
  let store: FakeStore;
  let stripe: ReturnType<typeof fakeStripe>;
  let rbacr: FakeRbacr;
  const ada: Caller = { subject: 'test#ada', email: 'ada@example.com', admin: false };

  const make = (billing?: Billing) => {
    const auth = new Auth({ store: store.asStore(), verify: async () => { throw new Error('unused'); }, config: { devMode: false, isAdmin: async () => false }, clock: () => now });
    const photos = { presign: async () => ({ url: '', fields: {} }), keep: async () => true, remove: async () => {} };
    return new Api({ store: store.asStore(), photos, auth, billing, roles: rbacr.lookup, grants: rbacr.api, config: { stage: 'local', version: 'test' }, clock: () => now });
  };
  const call = async (api: Api, method: string, path: string, body?: unknown) =>
    (await api.handle(method, path, { caller: ada, body, query: {} })) as Record<string, any>;
  const status = (p: Promise<unknown>) => p.then(() => 200, (e: unknown) => (e as ApiError).status);
  const deliver = (api: Api, type: string, object: Record<string, unknown>) => {
    const body = JSON.stringify({ id: 'evt', type, data: { object } });
    return api.stripeWebhook(body, sign(body));
  };

  beforeEach(() => {
    store = new FakeStore();
    stripe = fakeStripe();
    rbacr = new FakeRbacr(() => now);
  });

  it('without Stripe keys: no prices, and buying is unavailable', async () => {
    const api = make();
    const me = await call(api, 'GET', '/api/me');
    expect(me.premium).toEqual({ active: false });
    expect((await call(api, 'GET', '/api/premium')).prices).toBeNull();
    expect(await status(call(api, 'POST', '/api/premium/checkout', { plan: 'monthly' }))).toBe(503);
    expect(await status(api.stripeWebhook('{}', 'x'))).toBe(503);
  });

  it('subscribes through Checkout; the webhook makes me Premium', async () => {
    const api = make(stripe.billing);
    const { climber } = await call(api, 'GET', '/api/me');
    expect((await call(api, 'GET', '/api/premium')).prices.monthly).toEqual({ amount: 2000, currency: 'usd' });
    expect(await status(call(api, 'POST', '/api/premium/checkout', { plan: 'weekly' }))).toBe(400);
    expect((await call(api, 'POST', '/api/premium/checkout', { plan: 'monthly' })).url).toMatch(/^https:\/\/checkout\.stripe\.com\//);
    // Whose Premium it is in rbacr travels with the subscription.
    const form = new URLSearchParams(stripe.calls.at(-1)!.body);
    expect(form.get('subscription_data[metadata][email]')).toBe('ada@example.com');
    expect(form.get('customer_email')).toBe('ada@example.com');
    // No customer yet: no portal.
    expect(await status(call(api, 'POST', '/api/premium/portal'))).toBe(404);

    stripe.subscriptions.set('sub_1', stripeSub('sub_1', climber.id));
    await deliver(api, 'checkout.session.completed', { subscription: 'sub_1', client_reference_id: climber.id });
    // Paid: rbacr's premium role, until the period's end plus two days' grace.
    expect(rbacr.calls).toEqual(['grant premium ada@example.com until 2030-06-03T10:00:00.000Z']);
    expect((await call(api, 'GET', '/api/me')).premium).toEqual({ active: true, plan: 'monthly', until: '2030-06-01T10:00:00.000Z' });
    expect(await status(call(api, 'POST', '/api/premium/checkout', { plan: 'yearly' }))).toBe(409);
    expect((await call(api, 'POST', '/api/premium/portal')).url).toMatch(/^https:\/\/billing\.stripe\.com\//);

    // Cancelled in the portal: Stripe says it ends at the period's end.
    stripe.subscriptions.set('sub_1', stripeSub('sub_1', climber.id, { cancel_at_period_end: true }));
    await deliver(api, 'customer.subscription.updated', { id: 'sub_1' });
    expect((await call(api, 'GET', '/api/me')).premium.ending).toBe(true);
    stripe.subscriptions.set('sub_1', stripeSub('sub_1', climber.id, { status: 'canceled' }));
    await deliver(api, 'customer.subscription.deleted', { id: 'sub_1' });
    expect(rbacr.calls.at(-1)).toBe('revoke premium ada@example.com');
    expect((await call(api, 'GET', '/api/me')).premium).toEqual({ active: false });
  });

  it('rbacr down: the webhook fails, so Stripe sends the event again', async () => {
    const api = make(stripe.billing);
    const { climber } = await call(api, 'GET', '/api/me');
    stripe.subscriptions.set('sub_1', stripeSub('sub_1', climber.id));
    rbacr.failNext = true;
    await expect(deliver(api, 'customer.subscription.created', { id: 'sub_1' })).rejects.toThrow(/503/);
    expect((await call(api, 'GET', '/api/me')).premium.active).toBe(false);
    await deliver(api, 'customer.subscription.created', { id: 'sub_1' });
    expect((await call(api, 'GET', '/api/me')).premium.active).toBe(true);
  });

  it('a subscription without an email (from before) uses the one Grigri keeps', async () => {
    const api = make(stripe.billing);
    const { climber } = await call(api, 'GET', '/api/me');
    stripe.subscriptions.set('sub_1', { ...stripeSub('sub_1', climber.id), metadata: { climberId: climber.id, app: 'grigri' } });
    await deliver(api, 'customer.subscription.created', { id: 'sub_1' });
    expect(rbacr.calls).toEqual(['grant premium ada@example.com until 2030-06-03T10:00:00.000Z']);
  });

  it("the RC's Premium is its own role: production's doesn't count there", async () => {
    const auth = new Auth({ store: store.asStore(), verify: async () => { throw new Error('unused'); }, config: { devMode: false, isAdmin: async () => false }, clock: () => now });
    const photos = { presign: async () => ({ url: '', fields: {} }), keep: async () => true, remove: async () => {} };
    const rc = new Api({ store: store.asStore(), photos, auth, billing: stripe.billing, roles: rbacr.lookup, grants: rbacr.api, config: { stage: 'rc', version: 'test', roleSuffix: '-rc' }, clock: () => now });
    const { climber } = await call(rc, 'GET', '/api/me');
    rbacr.give('ada@example.com', 'premium');
    expect((await call(rc, 'GET', '/api/me')).premium.active).toBe(false);
    stripe.subscriptions.set('sub_1', stripeSub('sub_1', climber.id));
    await deliver(rc, 'customer.subscription.created', { id: 'sub_1' });
    expect(rbacr.calls).toEqual(['grant premium-rc ada@example.com until 2030-06-03T10:00:00.000Z']);
    expect((await call(rc, 'GET', '/api/me')).premium.active).toBe(true);
  });

  it('Premium is the role, however it came: an admin, or granted in rbacr by hand', async () => {
    const api = make(stripe.billing);
    await call(api, 'GET', '/api/me');
    rbacr.give('ada@example.com', 'admin');
    expect((await call(api, 'GET', '/api/me')).premium).toEqual({ active: true });
    expect((await call(api, 'GET', '/api/premium')).premium).toEqual({ active: true });
  });

  it('an old subscription\'s late event never overwrites a newer paid one', async () => {
    const api = make(stripe.billing);
    const { climber } = await call(api, 'GET', '/api/me');
    stripe.subscriptions.set('sub_new', stripeSub('sub_new', climber.id));
    stripe.subscriptions.set('sub_old', stripeSub('sub_old', climber.id, { status: 'canceled' }));
    await deliver(api, 'customer.subscription.created', { id: 'sub_new' });
    await deliver(api, 'customer.subscription.deleted', { id: 'sub_old' });
    expect(store.subscriptions.get(climber.id)!.subscriptionId).toBe('sub_new');
    expect((await call(api, 'GET', '/api/me')).premium.active).toBe(true);
  });

  it('refuses unsigned events, and ignores ones about nothing of Grigri\'s', async () => {
    const api = make(stripe.billing);
    expect(await status(api.stripeWebhook('{"type":"x","data":{"object":{}}}', 't=1,v1=00'))).toBe(400);
    stripe.subscriptions.set('sub_x', { ...stripeSub('sub_x', 'c1'), metadata: {} });
    expect(await deliver(api, 'customer.subscription.updated', { id: 'sub_x' })).toEqual({ received: true });
    expect(store.subscriptions.size).toBe(0);
  });
});
