import { createHash, createPrivateKey, sign } from 'node:crypto';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { Api } from '../src/api.js';
import {
  APPLE_BUNDLE_ID,
  BadAppleSignature,
  INTERMEDIATE_OID,
  LEAF_OID,
  appleAccountToken,
  appStoreVerifier,
  extensionOids,
} from '../src/app-store.js';
import { APPLE_ROOT_CA_G3, APPLE_ROOT_CA_G3_SHA256 } from '../src/apple-root.js';
import { Auth, type Caller } from '../src/auth.js';
import { ApiError } from '../src/domain/errors.js';
import { type Chains, jws, makeChains } from './apple-chain.js';
import { FakeRbacr } from './fake-rbacr.js';
import { FakeStore } from './fake-store.js';

const now = new Date('2030-05-01T10:00:00.000Z');
const at = (iso: string) => Date.parse(iso);
const MONTHLY = 'com.nu01.grigri.premium.monthly';
const YEARLY = 'com.nu01.grigri.premium.yearly';

let chains: Chains;
beforeAll(() => {
  chains = makeChains();
});

/** Signed by the made-up chain, as Apple signs. */
const signed = (payload: Record<string, unknown>) => jws(payload, chains.leaf, [chains.leaf, chains.intermediate, chains.root]);

describe("Apple's root", () => {
  it('is Apple Root CA - G3, by its published SHA-256 fingerprint', () => {
    expect(APPLE_ROOT_CA_G3.fingerprint256).toBe(APPLE_ROOT_CA_G3_SHA256);
    expect(createHash('sha256').update(APPLE_ROOT_CA_G3.raw).digest('hex').toUpperCase().match(/../g)!.join(':')).toBe(APPLE_ROOT_CA_G3_SHA256);
    expect(APPLE_ROOT_CA_G3.subject).toContain('CN=Apple Root CA - G3');
    expect(APPLE_ROOT_CA_G3.ca).toBe(true);
    expect(APPLE_ROOT_CA_G3.checkIssued(APPLE_ROOT_CA_G3)).toBe(true);
    expect(APPLE_ROOT_CA_G3.verify(APPLE_ROOT_CA_G3.publicKey)).toBe(true);
  });

  it('production trusts only it: a made-up chain is refused', () => {
    const payload = { signedDate: at('2030-05-01T09:00:00Z') };
    expect(() => appStoreVerifier()(signed(payload))).toThrow(/trusted root/);
  });
});

describe('the JWS verifier', () => {
  const payload = { hello: 'climbers', signedDate: at('2030-05-01T09:00:00Z') };
  let verify: ReturnType<typeof appStoreVerifier>;
  beforeAll(() => {
    verify = appStoreVerifier([chains.root.cert]);
  });
  const refuses = (token: unknown, why: RegExp) => {
    expect(() => verify(token)).toThrow(BadAppleSignature);
    expect(() => verify(token)).toThrow(why);
  };

  it("reads Apple's OIDs off the certificates", () => {
    expect(extensionOids(chains.leaf.cert).has(LEAF_OID)).toBe(true);
    expect(extensionOids(chains.intermediate.cert).has(INTERMEDIATE_OID)).toBe(true);
    expect(extensionOids(chains.leafNoOid.cert).has(LEAF_OID)).toBe(false);
    // Basic constraints and key usage, as every certificate has.
    expect(extensionOids(chains.root.cert)).toEqual(new Set(['2.5.29.19', '2.5.29.15', '2.5.29.14']));
  });

  it('accepts a JWS signed by the leaf of a trusted chain', () => {
    expect(verify(signed(payload))).toEqual(payload);
  });

  it('refuses anything that is not a compact JWS', () => {
    refuses(undefined, /not a JWS/);
    refuses(42, /not a JWS/);
    refuses('a.b', /not a JWS/);
    refuses('a.b.c.d', /not a JWS/);
    refuses('a.b+.c', /not a JWS/);
    refuses(`${Buffer.from('[1]').toString('base64url')}.e30.AA`, /not a JWS/);
    refuses('x'.repeat(60_000), /not a JWS/);
  });

  it('refuses other algorithms: none, HMAC, ES384', () => {
    const [, p, s] = signed(payload).split('.');
    for (const alg of ['none', 'HS256', 'ES384', 'RS256', 'es256']) {
      const h = Buffer.from(JSON.stringify({ alg, x5c: [chains.leaf.der, chains.intermediate.der, chains.root.der] })).toString('base64url');
      refuses(`${h}.${p}.${s}`, /alg must be ES256/);
    }
    refuses(jws(payload, chains.leaf, [chains.leaf, chains.intermediate, chains.root], { crit: ['b64'] }), /crit/);
  });

  it('refuses a missing or short x5c', () => {
    refuses(jws(payload, chains.leaf, []), /three certificates/);
    refuses(jws(payload, chains.leaf, [chains.leaf, chains.intermediate]), /three certificates/);
    refuses(jws(payload, chains.leaf, [chains.leaf, chains.intermediate, chains.root], { x5c: undefined }), /three certificates/);
    refuses(jws(payload, chains.leaf, [chains.leaf, chains.intermediate, chains.root], { x5c: [1, 2, 3] }), /three certificates/);
    refuses(jws(payload, chains.leaf, [chains.leaf, chains.intermediate, chains.root], { x5c: ['AAAA', 'AAAA', 'AAAA'] }), /bad certificate/);
  });

  it('refuses a chain to an untrusted root, even one naming the trusted root as x5c[2]', () => {
    refuses(jws(payload, chains.evilLeaf, [chains.evilLeaf, chains.evilIntermediate, chains.evilRoot]), /trusted root/);
    refuses(jws(payload, chains.evilLeaf, [chains.evilLeaf, chains.evilIntermediate, chains.root]), /trusted root/);
    // A trusted intermediate over someone else's leaf.
    refuses(jws(payload, chains.evilLeaf, [chains.evilLeaf, chains.intermediate, chains.root]), /leaf not issued/);
  });

  it("refuses certificates without Apple's OIDs, or an intermediate that isn't a CA", () => {
    refuses(jws(payload, chains.leafNoOid, [chains.leafNoOid, chains.intermediate, chains.root]), /leaf lacks/);
    refuses(jws(payload, chains.leafUnderNoOid, [chains.leafUnderNoOid, chains.intermediateNoOid, chains.root]), /intermediate lacks/);
    refuses(jws(payload, chains.leafUnderNotCa, [chains.leafUnderNotCa, chains.intermediateNotCa, chains.root]), /not a CA/);
    // The root itself as the intermediate: no intermediate OID.
    refuses(jws(payload, chains.leafFromRoot, [chains.leafFromRoot, chains.root, chains.root]), /intermediate lacks/);
  });

  it("refuses a JWS signed when the certificates weren't valid, or without a date", () => {
    refuses(signed({ signedDate: at('1999-01-01T00:00:00Z') }), /not valid when signed/);
    refuses(signed({ signedDate: at('2099-01-01T00:00:00Z') }), /not valid when signed/);
    refuses(signed({ hello: 'climbers' }), /no signedDate/);
    refuses(signed({ signedDate: '2030-05-01' }), /no signedDate/);
  });

  it('refuses a P-384 leaf', () => {
    refuses(jws(payload, chains.leaf384, [chains.leaf384, chains.intermediate, chains.root]), /P-256/);
  });

  it('refuses a tampered payload or signature, a DER signature, or another key', () => {
    const [h, p, s] = signed(payload).split('.') as [string, string, string];
    const forged = Buffer.from(JSON.stringify({ ...payload, hello: 'admins' })).toString('base64url');
    refuses(`${h}.${forged}.${s}`, /signature mismatch/);
    const sig = Buffer.from(s, 'base64url');
    sig[10] = sig[10]! ^ 1;
    refuses(`${h}.${p}.${sig.toString('base64url')}`, /signature mismatch/);
    const der = sign('sha256', Buffer.from(`${h}.${p}`), createPrivateKey(chains.leaf.key));
    refuses(`${h}.${p}.${der.toString('base64url')}`, /bad signature|mismatch/);
    // Signed by the intermediate's key, presenting the leaf.
    refuses(jws(payload, chains.intermediate, [chains.leaf, chains.intermediate, chains.root]), /signature mismatch|P-256/);
  });
});

describe('appleAccountToken', () => {
  it('is a UUID derived from the climber: the same each time, different per climber', () => {
    const t = appleAccountToken('c1');
    expect(t).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-8[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
    expect(appleAccountToken('c1')).toBe(t);
    expect(appleAccountToken('c2')).not.toBe(t);
  });
});

describe('Premium through the App Store', () => {
  let store: FakeStore;
  let rbacr: FakeRbacr;
  let api: Api;
  const ada: Caller = { subject: 'test#ada', email: 'ada@example.com', isAdmin: async () => false };
  const bob: Caller = { subject: 'test#bob', email: 'bob@example.com', isAdmin: async () => false };

  const call = async (caller: Caller | null, method: string, path: string, body?: unknown) =>
    (await api.handle(method, path, { caller, body, query: {} })) as Record<string, any>;
  const status = (p: Promise<unknown>) => p.then(() => 200, (e: unknown) => (e as ApiError).status);

  /** A signed transaction: Ada's monthly, renewing on June 1st, unless changed. */
  const transaction = (over: Record<string, unknown> = {}) => ({
    transactionId: '2000000100',
    originalTransactionId: '2000000001',
    bundleId: APPLE_BUNDLE_ID,
    productId: MONTHLY,
    type: 'Auto-Renewable Subscription',
    purchaseDate: at('2030-05-01T09:00:00Z'),
    expiresDate: at('2030-06-01T09:00:00Z'),
    environment: 'Sandbox',
    signedDate: at('2030-05-01T09:00:01Z'),
    inAppOwnershipType: 'PURCHASED',
    ...over,
  });
  const renewalInfo = (over: Record<string, unknown> = {}) => ({
    originalTransactionId: '2000000001',
    autoRenewProductId: MONTHLY,
    autoRenewStatus: 1,
    signedDate: at('2030-05-01T09:00:01Z'),
    ...over,
  });
  const notify = (type: string, opts: { tx?: Record<string, unknown>; renewal?: Record<string, unknown> | null; status?: number; subtype?: string; signedDate?: string } = {}) => {
    const payload = {
      notificationType: type,
      ...(opts.subtype ? { subtype: opts.subtype } : {}),
      notificationUUID: `uuid-${Math.random()}`,
      version: '2.0',
      signedDate: at(opts.signedDate ?? '2030-05-01T10:00:00Z'),
      data: {
        appAppleId: 1234567890,
        bundleId: APPLE_BUNDLE_ID,
        environment: 'Sandbox',
        signedTransactionInfo: signed(opts.tx ?? transaction()),
        ...(opts.renewal === null ? {} : { signedRenewalInfo: signed(opts.renewal ?? renewalInfo()) }),
        ...(opts.status ? { status: opts.status } : {}),
      },
    };
    return call(null, 'POST', '/api/apple/notifications', { signedPayload: signed(payload) });
  };

  beforeEach(async () => {
    store = new FakeStore();
    rbacr = new FakeRbacr(() => now);
    const auth = new Auth({ store: store.asStore(), verify: async () => { throw new Error('unused'); }, config: { devMode: false, isAdmin: async () => false }, clock: () => now });
    const photos = { presign: async () => ({ url: '', fields: {} }), keep: async () => true, remove: async () => {} };
    api = new Api({
      store: store.asStore(), photos, auth, roles: rbacr.lookup, grants: rbacr.api,
      appStore: appStoreVerifier([chains.root.cert]),
      config: { stage: 'local', version: 'test' }, clock: () => now,
    });
  });

  /** Ada's climber id, and the transaction she buys (with her token). */
  const adaBuys = async (over: Record<string, unknown> = {}) => {
    const { climber } = await call(ada, 'GET', '/api/me');
    const { appleAccountToken: token } = await call(ada, 'GET', '/api/premium');
    expect(token).toBe(appleAccountToken(climber.id));
    const answer = await call(ada, 'POST', '/api/premium/apple', { transaction: signed(transaction({ appAccountToken: token.toUpperCase(), ...over })) });
    return { id: climber.id as string, answer };
  };

  it('buying on iOS: the signed transaction makes me Premium, from the App Store', async () => {
    const { id, answer } = await adaBuys();
    expect(answer.premium).toEqual({ active: true, plan: 'monthly', until: '2030-06-01T09:00:00.000Z', source: 'apple' });
    expect(rbacr.calls).toEqual(['grant premium ada@example.com until 2030-06-03T09:00:00.000Z']);
    expect(store.subscriptions.get(id)).toMatchObject({
      source: 'apple', subscriptionId: '2000000001', customerId: '', status: 'active', environment: 'Sandbox', email: 'ada@example.com',
    });
    expect(store.appleOwners.get('2000000001')).toBe(id);
    // Sending it again (a restore) changes nothing.
    await call(ada, 'POST', '/api/premium/apple', { transaction: signed(transaction({ appAccountToken: appleAccountToken(id) })) });
    expect((await call(ada, 'GET', '/api/me')).premium.source).toBe('apple');
    // Stripe's portal isn't where it's managed.
    expect(await status(call(ada, 'POST', '/api/premium/portal'))).toBe(503);
  });

  it('deleting my account unties my App Store subscription, without asking Stripe', async () => {
    const { id } = await adaBuys();
    expect(await call(ada, 'DELETE', '/api/me', { confirm: true })).toEqual({});
    expect(store.appleOwners.has('2000000001')).toBe(false);
    expect(store.subscriptions.has(id)).toBe(false);
    expect(rbacr.calls).toContain('revoke premium ada@example.com');
  });

  it('records the yearly plan and the Production environment', async () => {
    const { id } = await adaBuys({ productId: YEARLY, environment: 'Production', expiresDate: at('2031-05-01T09:00:00Z') });
    expect(store.subscriptions.get(id)).toMatchObject({ plan: 'yearly', environment: 'Production', periodEnd: '2031-05-01T09:00:00.000Z' });
  });

  it("refuses transactions that aren't Grigri Premium, or not Apple's", async () => {
    const { climber } = await call(ada, 'GET', '/api/me');
    const token = appleAccountToken(climber.id);
    const post = (transaction: unknown) => status(call(ada, 'POST', '/api/premium/apple', { transaction }));
    expect(await post(signed(transaction({ appAccountToken: token, bundleId: 'com.example.other' })))).toBe(400);
    expect(await post(signed(transaction({ appAccountToken: token, productId: 'com.nu01.grigri.premium.weekly' })))).toBe(400);
    expect(await post(signed(transaction({ appAccountToken: token, type: 'Consumable' })))).toBe(400);
    expect(await post(signed(transaction({ appAccountToken: token, environment: 'Xcode' })))).toBe(400);
    expect(await post(jws(transaction({ appAccountToken: token }), chains.evilLeaf, [chains.evilLeaf, chains.evilIntermediate, chains.root]))).toBe(400);
    expect(await post('not.a.jws')).toBe(400);
    expect(await post(undefined)).toBe(400);
    expect(store.subscriptions.size).toBe(0);
    expect(rbacr.calls).toEqual([]);
  });

  it("can't be replayed onto another account", async () => {
    const { id } = await adaBuys();
    await call(bob, 'GET', '/api/me');
    // Ada's transaction, sent by Bob: bought with Ada's token.
    const adas = signed(transaction({ appAccountToken: appleAccountToken(id) }));
    expect(await status(call(bob, 'POST', '/api/premium/apple', { transaction: adas }))).toBe(409);
    // No token at all.
    expect(await status(call(bob, 'POST', '/api/premium/apple', { transaction: signed(transaction()) }))).toBe(409);
    // Bob's token on Ada's subscription (Bob signed in to Grigri on Ada's Apple ID and bought again): it's Ada's.
    const bobId = (await call(bob, 'GET', '/api/me')).climber.id;
    const bobs = signed(transaction({ appAccountToken: appleAccountToken(bobId), transactionId: '2000000200' }));
    expect(await status(call(bob, 'POST', '/api/premium/apple', { transaction: bobs }))).toBe(409);
    expect((await call(bob, 'GET', '/api/me')).premium).toEqual({ active: false });
    expect(rbacr.calls).toEqual(['grant premium ada@example.com until 2030-06-03T09:00:00.000Z']);
  });

  it('without the verifier: unavailable', async () => {
    const auth = new Auth({ store: store.asStore(), verify: async () => { throw new Error('unused'); }, config: { devMode: false, isAdmin: async () => false }, clock: () => now });
    const photos = { presign: async () => ({ url: '', fields: {} }), keep: async () => true, remove: async () => {} };
    api = new Api({ store: store.asStore(), photos, auth, roles: rbacr.lookup, grants: rbacr.api, config: { stage: 'local', version: 'test' }, clock: () => now });
    await call(ada, 'GET', '/api/me');
    expect((await call(ada, 'GET', '/api/premium')).appleAccountToken).toBeNull();
    expect(await status(call(ada, 'POST', '/api/premium/apple', { transaction: 'x' }))).toBe(503);
    expect(await status(call(null, 'POST', '/api/apple/notifications', { signedPayload: 'x' }))).toBe(503);
  });

  describe('notifications', () => {
    it('are public: no session, Apple signs them', () => {
      expect(api.access('POST', '/api/apple/notifications')).toBe('public');
    });

    it('DID_RENEW moves the end; DID_CHANGE_RENEWAL_STATUS says it ends; EXPIRED ends it', async () => {
      const { id } = await adaBuys();
      const token = appleAccountToken(id);
      await notify('DID_RENEW', {
        tx: transaction({ appAccountToken: token, transactionId: '2000000101', expiresDate: at('2030-07-01T09:00:00Z'), signedDate: at('2030-06-01T09:00:00Z') }),
        status: 1,
        signedDate: '2030-06-01T09:00:00Z',
      });
      expect((await call(ada, 'GET', '/api/me')).premium).toEqual({ active: true, plan: 'monthly', until: '2030-07-01T09:00:00.000Z', source: 'apple' });
      expect(rbacr.calls.at(-1)).toBe('grant premium ada@example.com until 2030-07-03T09:00:00.000Z');

      await notify('DID_CHANGE_RENEWAL_STATUS', {
        subtype: 'AUTO_RENEW_DISABLED',
        tx: transaction({ appAccountToken: token, transactionId: '2000000101', expiresDate: at('2030-07-01T09:00:00Z') }),
        renewal: renewalInfo({ autoRenewStatus: 0 }),
        status: 1,
        signedDate: '2030-06-10T09:00:00Z',
      });
      expect((await call(ada, 'GET', '/api/me')).premium.ending).toBe(true);

      await notify('EXPIRED', {
        subtype: 'VOLUNTARY',
        tx: transaction({ appAccountToken: token, transactionId: '2000000101', expiresDate: at('2030-07-01T09:00:00Z') }),
        renewal: renewalInfo({ autoRenewStatus: 0 }),
        status: 2,
        signedDate: '2030-07-01T09:00:05Z',
      });
      expect(store.subscriptions.get(id)!.status).toBe('expired');
      expect(rbacr.calls.at(-1)).toBe('revoke premium ada@example.com');
      expect((await call(ada, 'GET', '/api/me')).premium).toEqual({ active: false });
    });

    it('REFUND and REVOKE end it at once', async () => {
      for (const type of ['REFUND', 'REVOKE']) {
        store.subscriptions.clear();
        store.appleOwners.clear();
        const { id } = await adaBuys();
        await notify(type, {
          tx: transaction({ appAccountToken: appleAccountToken(id), revocationDate: at('2030-05-01T09:30:00Z'), revocationReason: 0 }),
          signedDate: '2030-05-01T09:30:00Z',
        });
        expect(store.subscriptions.get(id)!.status).toBe('canceled');
        expect(rbacr.calls.at(-1)).toBe('revoke premium ada@example.com');
      }
    });

    it('a failed renewal in the grace period keeps it until the grace ends; GRACE_PERIOD_EXPIRED ends it', async () => {
      const { id } = await adaBuys({ expiresDate: at('2030-04-30T09:00:00Z'), signedDate: at('2030-03-30T09:00:00Z') });
      const token = appleAccountToken(id);
      await notify('DID_FAIL_TO_RENEW', {
        subtype: 'GRACE_PERIOD',
        tx: transaction({ appAccountToken: token, expiresDate: at('2030-04-30T09:00:00Z') }),
        renewal: renewalInfo({ gracePeriodExpiresDate: at('2030-05-16T09:00:00Z') }),
        status: 4,
        signedDate: '2030-04-30T09:00:10Z',
      });
      expect(store.subscriptions.get(id)).toMatchObject({ status: 'past_due', periodEnd: '2030-05-16T09:00:00.000Z' });
      expect((await call(ada, 'GET', '/api/me')).premium.active).toBe(true);
      await notify('GRACE_PERIOD_EXPIRED', {
        tx: transaction({ appAccountToken: token, expiresDate: at('2030-04-30T09:00:00Z') }),
        renewal: renewalInfo({ gracePeriodExpiresDate: at('2030-05-16T09:00:00Z') }),
        status: 3,
        signedDate: '2030-05-16T09:00:10Z',
      });
      expect(store.subscriptions.get(id)!.status).toBe('expired');
      expect(rbacr.calls.at(-1)).toBe('revoke premium ada@example.com');
    });

    it('SUBSCRIBED again after it lapsed (same subscription) makes me Premium again', async () => {
      const { id } = await adaBuys();
      const token = appleAccountToken(id);
      await notify('EXPIRED', { tx: transaction({ appAccountToken: token }), status: 2, signedDate: '2030-06-01T09:00:05Z' });
      expect(store.subscriptions.get(id)!.status).toBe('expired');
      await notify('SUBSCRIBED', {
        subtype: 'RESUBSCRIBE',
        tx: transaction({ appAccountToken: token, transactionId: '2000000300', expiresDate: at('2030-07-15T09:00:00Z') }),
        status: 1,
        signedDate: '2030-06-15T09:00:00Z',
      });
      expect(store.subscriptions.get(id)).toMatchObject({ status: 'active', periodEnd: '2030-07-15T09:00:00.000Z' });
    });

    it('out of order: an older notification never overwrites a newer one; the same one twice changes nothing', async () => {
      const { id } = await adaBuys();
      const token = appleAccountToken(id);
      const refund = () => notify('REFUND', { tx: transaction({ appAccountToken: token, revocationDate: at('2030-05-01T09:40:00Z') }), signedDate: '2030-05-01T09:40:00Z' });
      await refund();
      await refund();
      expect(store.subscriptions.get(id)!.status).toBe('canceled');
      // The SUBSCRIBED Apple sent first arrives late.
      await notify('SUBSCRIBED', { subtype: 'INITIAL_BUY', tx: transaction({ appAccountToken: token }), status: 1, signedDate: '2030-05-01T09:00:02Z' });
      expect(store.subscriptions.get(id)!.status).toBe('canceled');
      // And the app's cached transaction, signed before the refund.
      await call(ada, 'POST', '/api/premium/apple', { transaction: signed(transaction({ appAccountToken: token })) });
      expect(store.subscriptions.get(id)!.status).toBe('canceled');
      expect((await call(ada, 'GET', '/api/me')).premium).toEqual({ active: false });
    });

    it('a subscription Grigri never saw is acknowledged and left (the app sends it)', async () => {
      await call(ada, 'GET', '/api/me');
      expect(await notify('SUBSCRIBED', { subtype: 'INITIAL_BUY', status: 1 })).toEqual({ received: true });
      expect(store.subscriptions.size).toBe(0);
      expect(rbacr.calls).toEqual([]);
    });

    it("never grants Premium without Apple's signature", async () => {
      const { id } = await adaBuys();
      const token = appleAccountToken(id);
      rbacr.calls.length = 0;
      // A refund signed by someone else's chain, inner and outer.
      const evil = (p: Record<string, unknown>) => jws(p, chains.evilLeaf, [chains.evilLeaf, chains.evilIntermediate, chains.root]);
      const forged = {
        notificationType: 'DID_RENEW', notificationUUID: 'u', signedDate: at('2030-08-01T00:00:00Z'),
        data: { bundleId: APPLE_BUNDLE_ID, signedTransactionInfo: evil(transaction({ appAccountToken: token, expiresDate: at('2040-01-01T00:00:00Z') })), status: 1 },
      };
      expect(await status(call(null, 'POST', '/api/apple/notifications', { signedPayload: evil(forged) }))).toBe(400);
      // Apple's envelope, a forged transaction inside.
      expect(await status(call(null, 'POST', '/api/apple/notifications', { signedPayload: signed(forged) }))).toBe(400);
      expect(await status(call(null, 'POST', '/api/apple/notifications', { signedPayload: 'x.y.z' }))).toBe(400);
      expect(await status(call(null, 'POST', '/api/apple/notifications', {}))).toBe(400);
      expect(rbacr.calls).toEqual([]);
      expect(store.subscriptions.get(id)!.periodEnd).toBe('2030-06-01T09:00:00.000Z');
    });

    it("ignores other apps' and other products' notifications, and TEST", async () => {
      const { id } = await adaBuys();
      const token = appleAccountToken(id);
      rbacr.calls.length = 0;
      const send = (payload: Record<string, unknown>) => call(null, 'POST', '/api/apple/notifications', { signedPayload: signed(payload) });
      expect(await send({ notificationType: 'TEST', notificationUUID: 'u', signedDate: at('2030-05-01T10:00:00Z'), data: { bundleId: APPLE_BUNDLE_ID } })).toEqual({ received: true });
      expect(await send({ notificationType: 'DID_RENEW', notificationUUID: 'u', signedDate: at('2030-05-01T10:00:00Z'), data: { bundleId: 'com.example.other', signedTransactionInfo: signed(transaction({ appAccountToken: token })) } })).toEqual({ received: true });
      expect(await send({ notificationType: 'DID_RENEW', notificationUUID: 'u', signedDate: at('2030-05-01T10:00:00Z'), data: { bundleId: APPLE_BUNDLE_ID, signedTransactionInfo: signed(transaction({ appAccountToken: token, productId: 'com.nu01.grigri.coins' })) } })).toEqual({ received: true });
      // Renewal info about another subscription.
      expect(await status(notify('DID_RENEW', { tx: transaction({ appAccountToken: token }), renewal: renewalInfo({ originalTransactionId: '999' }) }))).toBe(400);
      // A transaction tied to Ada carrying someone else's token.
      await notify('REFUND', { tx: transaction({ appAccountToken: appleAccountToken('someone-else'), revocationDate: at('2030-05-01T09:40:00Z') }) });
      expect(store.subscriptions.get(id)!.status).toBe('active');
      expect(rbacr.calls).toEqual([]);
    });

    it('rbacr down: the notification fails, so Apple sends it again', async () => {
      const { id } = await adaBuys();
      rbacr.failNext = true;
      const renew = () => notify('DID_RENEW', {
        tx: transaction({ appAccountToken: appleAccountToken(id), transactionId: '2000000101', expiresDate: at('2030-07-01T09:00:00Z') }),
        status: 1, signedDate: '2030-06-01T09:00:00Z',
      });
      await expect(renew()).rejects.toThrow(/503/);
      await renew();
      expect(rbacr.calls.at(-1)).toBe('grant premium ada@example.com until 2030-07-03T09:00:00.000Z');
    });

    it("an App Store subscription's lapse never overwrites a paid Stripe one", async () => {
      const { id } = await adaBuys();
      store.subscriptions.set(id, {
        climberId: id, customerId: 'cus_1', subscriptionId: 'sub_1', status: 'active', plan: 'yearly',
        periodEnd: '2031-01-01T00:00:00.000Z', cancelAtPeriodEnd: false, updatedAt: now.toISOString(), email: 'ada@example.com',
      });
      await notify('EXPIRED', { tx: transaction({ appAccountToken: appleAccountToken(id) }), status: 2, signedDate: '2030-06-01T09:00:05Z' });
      expect(store.subscriptions.get(id)!.subscriptionId).toBe('sub_1');
      // A billing retry long over: a paying status, but not paid now.
      await notify('DID_FAIL_TO_RENEW', {
        tx: transaction({ appAccountToken: appleAccountToken(id), expiresDate: at('2030-03-01T09:00:00Z') }),
        status: 3,
        signedDate: '2030-03-01T09:00:05Z',
      });
      expect(store.subscriptions.get(id)!.subscriptionId).toBe('sub_1');
      expect(rbacr.calls.at(-1)).toBe('grant premium ada@example.com until 2030-06-03T09:00:00.000Z');
    });
  });
});
