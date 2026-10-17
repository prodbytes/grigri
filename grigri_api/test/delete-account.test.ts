// DELETE /api/me: deleting my account from inside the app (App Store
// guideline 5.1.1(v)). Made-up people throughout.
import { beforeEach, describe, expect, it } from 'vitest';
import { Api, DELETED_CLIMBER, type DeletingAccount } from '../src/api.js';
import { Auth, type Caller } from '../src/auth.js';
import { ApiError } from '../src/domain/errors.js';
import type { Ad } from '../src/domain/ads.js';
import type { Subscription } from '../src/premium.js';
import type { Delivery, Realtime } from '../src/realtime.js';
import type { Billing, StripeEvent } from '../src/stripe.js';
import { FakeRbacr } from './fake-rbacr.js';
import { FakeStore } from './fake-store.js';

const now = new Date('2030-05-01T10:00:00.000Z');
let store: FakeStore;
let api: Api;
let auth: Auth;
let rbacr: FakeRbacr;
/** S3 as the fake photos see it: key -> pending tag. */
let objects: Map<string, boolean>;
let removed: string[];
/** The next photos.remove fails (S3 down). */
let failRemove: boolean;
let cancelled: string[];
/** The next Stripe cancel fails. */
let failCancel: boolean;
/** Stripe's subscriptions, as the fake billing reads them back. */
let stripeSubs: Map<string, Subscription>;
let hints: Delivery[];
let deleting: DeletingAccount[];
/** Climbers whose Sign in with Apple tokens were revoked, and whether their profile still existed then. */
let appleRevoked: { climberId: string; profileThere: boolean }[];

const billing: Billing = {
  checkout: async () => 'https://checkout.example.com/',
  portal: async () => 'https://portal.example.com/',
  event: (raw) => JSON.parse(raw) as StripeEvent,
  subscription: async (id) => stripeSubs.get(id),
  cancel: async (id) => {
    if (failCancel) {
      failCancel = false;
      throw new Error('stripe DELETE /subscriptions: down');
    }
    cancelled.push(id);
    const s = stripeSubs.get(id);
    if (s) stripeSubs.set(id, { ...s, status: 'canceled' });
  },
};

/** Signs in as a made-up Google account: a real session token. */
async function signIn(name: string): Promise<{ token: string; caller: Caller }> {
  const { token } = await auth.signIn({ idToken: name });
  return { token, caller: await auth.caller({ authorization: `Bearer ${token}` }) };
}

async function call(c: Caller, method: string, path: string, body?: unknown) {
  return (await api.handle(method, path, { caller: c, body, query: {} })) as Record<string, any>;
}

async function status(p: Promise<unknown>): Promise<number> {
  return p.then(() => 200, (e: unknown) => (e instanceof ApiError ? e.status : 500));
}

const profile = (name: string) => ({ name, bio: '', levels: { sport: { scale: 'routes', min: 6, max: 10 } }, gear: ['rope'] });
const planBody = (place: string, type?: string) => ({
  discipline: 'sport',
  place,
  area: 'Nowhere',
  start: '2030-05-10T08:00:00Z',
  end: '2030-05-10T14:00:00Z',
  grades: { scale: 'routes', min: 6, max: 10 },
  notes: '',
  ...(type ? { type } : {}),
});

beforeEach(() => {
  store = new FakeStore();
  objects = new Map();
  removed = [];
  failRemove = false;
  cancelled = [];
  failCancel = false;
  stripeSubs = new Map();
  hints = [];
  deleting = [];
  appleRevoked = [];
  const photos = {
    presign: async () => ({ url: 'https://upload.example.com/', fields: {} }),
    keep: async (key: string) => {
      if (!objects.has(key)) return false;
      objects.set(key, false);
      return true;
    },
    remove: async (keys: string[]) => {
      if (failRemove) {
        failRemove = false;
        throw new Error('S3 answered 503');
      }
      removed.push(...keys);
      for (const k of keys) objects.delete(k);
    },
  };
  auth = new Auth({
    store: store.asStore(),
    verify: async (idToken) => ({ subject: `https://accounts.google.com#${idToken}`, email: `${idToken}@example.com`, emailVerified: true, name: idToken }),
    config: { devMode: false, isAdmin: async () => false },
    clock: () => now,
  });
  rbacr = new FakeRbacr(() => now);
  const realtime = { notify: async (ds: Delivery[]) => void hints.push(...ds), info: async () => ({ url: null }) } as unknown as Realtime;
  api = new Api({
    store: store.asStore(),
    photos,
    auth,
    realtime,
    billing,
    roles: rbacr.lookup,
    grants: rbacr.api,
    onDeleteAccount: async (account) => void deleting.push(account),
    appleTokens: {
      revoke: async (climberId: string) => {
        appleRevoked.push({ climberId, profileThere: (await store.asStore().getClimber(climberId)) !== undefined });
        return 'none' as const;
      },
    },
    config: { stage: 'local', version: 'test' },
    clock: () => now,
    random: () => 0,
  });
});

/** Ada (organizing two plans, in a third she left, asking to join a fourth), Ben and Cy, with all that's hers. */
async function world() {
  const ada = await signIn('ada');
  const adaPhone = await signIn('ada');
  const ben = await signIn('ben');
  const cy = await signIn('cy');
  // Ada's profile photo.
  const photo = (await call(ada.caller, 'POST', '/api/photos', { kind: 'profile', contentType: 'image/jpeg' })).key as string;
  objects.set(photo, true);
  const { climber: me } = await call(ada.caller, 'PUT', '/api/me', { ...profile('Ada'), photo });
  const { climber: benMe } = await call(ben.caller, 'PUT', '/api/me', profile('Ben'));
  const { climber: cyMe } = await call(cy.caller, 'PUT', '/api/me', profile('Cy'));

  // Shared: Ada organizes, Ben joins (open), both chat; Ada sends a photo.
  const shared = (await call(ada.caller, 'POST', '/api/plans', planBody('Shared crag', 'open'))).plan.id as string;
  await call(ben.caller, 'POST', `/api/plans/${shared}/join`);
  await call(ada.caller, 'POST', `/api/plans/${shared}/messages`, { text: 'Bring a 70 m rope' });
  await call(ben.caller, 'POST', `/api/plans/${shared}/messages`, { text: 'Will do' });
  const media = (await call(ada.caller, 'POST', `/api/plans/${shared}/media`, { contentType: 'image/jpeg' })).key as string;
  objects.set(media, true);
  await call(ada.caller, 'POST', `/api/plans/${shared}/messages`, { attachment: media });
  const benMedia = (await call(ben.caller, 'POST', `/api/plans/${shared}/media`, { contentType: 'image/jpeg' })).key as string;
  objects.set(benMedia, true);
  await call(ben.caller, 'POST', `/api/plans/${shared}/messages`, { attachment: benMedia });
  const pic = (await call(ada.caller, 'POST', `/api/plans/${shared}/pics/upload`, { contentType: 'image/png' })).key as string;
  objects.set(pic, true);
  await call(ada.caller, 'POST', `/api/plans/${shared}/pics`, { key: pic });

  // Alone: Ada's own plan, nobody else in it.
  const alone = (await call(ada.caller, 'POST', '/api/plans', planBody('Lonely wall'))).plan.id as string;

  // Left: Cy's plan, Ada joined, chatted, then left.
  const left = (await call(cy.caller, 'POST', '/api/plans', planBody('Left crag', 'open'))).plan.id as string;
  await call(ada.caller, 'POST', `/api/plans/${left}/join`);
  await call(ada.caller, 'POST', `/api/plans/${left}/messages`, { text: 'See you there' });
  await call(ada.caller, 'POST', `/api/plans/${left}/leave`);

  // Asked: Ben's private plan, Ada's request still open.
  const asked = (await call(ben.caller, 'POST', '/api/plans', planBody('Asked crag'))).plan.id as string;
  await call(ada.caller, 'POST', `/api/plans/${asked}/join`);

  // A pass, Premium and an ad.
  await call(ada.caller, 'POST', `/api/plans/${(await call(cy.caller, 'POST', '/api/plans', planBody('Passed crag'))).plan.id}/pass`);
  const sub: Subscription = {
    climberId: me.id, customerId: 'cus_made_up', subscriptionId: 'sub_made_up', status: 'active', plan: 'monthly',
    periodEnd: '2030-06-01T10:00:00.000Z', cancelAtPeriodEnd: false, updatedAt: now.toISOString(), email: 'ada@example.com',
  };
  stripeSubs.set(sub.subscriptionId, sub);
  await store.putSubscription(sub);
  rbacr.give('ada@example.com', 'premium', '2030-06-03T10:00:00.000Z');
  const ad: Ad = { id: 'ad_made_up', ownerId: me.id, text: 'Rope for sale', link: 'https://example.com/', media: { key: `ads/${me.id}/abcdefgh.jpg`, kind: 'image' }, status: 'approved', createdAt: now.toISOString() };
  await store.putAd(ad);
  return { ada, adaPhone, ben, cy, me, benMe, cyMe, shared, alone, left, asked, photo, media, benMedia, pic, ad };
}

describe('DELETE /api/me', () => {
  it('deletes everything of mine, hands my plans over and signs me out everywhere', async () => {
    const w = await world();
    hints = [];
    expect(await call(w.ada.caller, 'DELETE', '/api/me', { confirm: true })).toEqual({});

    // Premium: cancelled at Stripe, the role revoked in rbacr.
    expect(cancelled).toEqual(['sub_made_up']);
    expect(rbacr.calls).toContain('revoke premium ada@example.com');
    expect(rbacr.rolesOf('ada@example.com')).toEqual([]);
    // Apple's tokens revoked while the profile (its subject) was still there, then the hook.
    expect(appleRevoked).toEqual([{ climberId: w.me.id, profileThere: true }]);
    expect(deleting).toEqual([{ subject: 'https://accounts.google.com#ada', climberId: w.me.id, email: 'ada@example.com' }]);

    // Shared: handed over to Ben, with a note that doesn't name me; my
    // messages, chat photo and pic gone, Ben's kept.
    const shared = store.plans.get(w.shared)!.plan;
    expect(shared.organizerId).toBe(w.benMe.id);
    expect(shared.memberIds).toEqual([w.benMe.id]);
    const chat = await store.messages(w.shared);
    expect(chat.some((m) => m.authorId === w.me.id)).toBe(false);
    expect(chat.map((m) => m.text)).toContain('Will do');
    expect(chat.some((m) => m.attachment?.key === w.benMedia)).toBe(true);
    expect(chat.at(-1)!.text).toBe(`${DELETED_CLIMBER} left the plan; Ben organizes it now`);
    expect(chat.some((m) => m.text.includes('Ada') && m.text.includes('left'))).toBe(false);
    expect((await store.planPics(w.shared)).map((p) => p.uploaderId)).toEqual([w.benMe.id]);
    expect(hints).toContainEqual({ to: w.benMe.id, hint: { kind: 'plan', planId: w.shared } });
    expect(hints).toContainEqual({ to: w.benMe.id, hint: { kind: 'message', planId: w.shared } });

    // Alone: ended with me, the last member.
    expect(store.plans.has(w.alone)).toBe(false);
    // Left: my old messages there are gone too.
    expect((await store.messages(w.left)).some((m) => m.authorId === w.me.id)).toBe(false);
    // Asked: my request withdrawn, its note gone; Ben has nothing to review.
    expect(await store.askedRequests(w.me.id)).toEqual([]);
    expect((await store.messages(w.asked)).some((m) => m.requestId?.endsWith(`/${w.me.id}`))).toBe(false);
    expect((await call(w.ben.caller, 'GET', '/api/requests')).requests).toEqual([]);
    expect(hints).toContainEqual({ to: w.benMe.id, hint: { kind: 'request', planId: w.asked } });

    // S3: my profile photo, chat photo, pic and ad media; not Ben's.
    expect(removed).toEqual(expect.arrayContaining([w.photo, w.media, w.pic, w.ad.media!.key]));
    expect(removed).not.toContain(w.benMedia);

    // Everything keyed to me.
    expect(store.climbers.has(w.me.id)).toBe(false);
    expect(store.subjects.has(w.ada.caller.subject)).toBe(false);
    expect(store.ads.size).toBe(0);
    expect(store.subscriptions.has(w.me.id)).toBe(false);
    expect(store.emails.has(w.me.id)).toBe(false);
    expect(store.noticeMap.has(w.me.id)).toBe(false);
    expect(await store.passedPlanIds(w.me.id)).toEqual([]);
    expect(await store.memberPlanIds(w.me.id)).toEqual([]);

    // Signed out everywhere: both of my sessions; Ben's still works.
    expect(await status(auth.caller({ authorization: `Bearer ${w.ada.token}` }))).toBe(401);
    expect(await status(auth.caller({ authorization: `Bearer ${w.adaPhone.token}` }))).toBe(401);
    expect((await auth.caller({ authorization: `Bearer ${w.ben.token}` })).subject).toBe(w.ben.caller.subject);
    // Ben's view: my profile is gone from the shared plan.
    expect(Object.keys((await call(w.ben.caller, 'GET', `/api/plans/${w.shared}`)).climbers)).toEqual([w.benMe.id]);
  });

  it('takes my blocks with me, both ways', async () => {
    const w = await world();
    await call(w.ada.caller, 'POST', `/api/blocks/${w.benMe.id}`);
    await call(w.cy.caller, 'POST', `/api/blocks/${w.me.id}`);
    await call(w.ada.caller, 'DELETE', '/api/me', { confirm: true });
    expect(store.blocks.size).toBe(0);
    expect((await call(w.cy.caller, 'GET', '/api/blocks')).blocked).toEqual([]);
  });

  it('needs an explicit confirmation', async () => {
    const w = await world();
    expect(await status(call(w.ada.caller, 'DELETE', '/api/me'))).toBe(400);
    expect(await status(call(w.ada.caller, 'DELETE', '/api/me', { confirm: 'yes' }))).toBe(400);
    expect(store.climbers.has(w.me.id)).toBe(true);
    expect(cancelled).toEqual([]);
  });

  it('only ever deletes my own account', async () => {
    const w = await world();
    expect(await status(call(w.ben.caller, 'DELETE', `/api/me/${w.me.id}`, { confirm: true }))).toBe(404);
    await call(w.ben.caller, 'DELETE', '/api/me', { confirm: true });
    expect(store.climbers.has(w.me.id)).toBe(true);
    expect(store.climbers.has(w.benMe.id)).toBe(false);
    expect(cancelled).toEqual([]);
    expect((await auth.caller({ authorization: `Bearer ${w.ada.token}` })).subject).toBe(w.ada.caller.subject);
  });

  it('a failure stops it; a retry finishes the job', async () => {
    const w = await world();
    // Stripe down: nothing is deleted while I could still be charged.
    failCancel = true;
    expect(await status(call(w.ada.caller, 'DELETE', '/api/me', { confirm: true }))).toBe(500);
    expect(store.climbers.has(w.me.id)).toBe(true);
    expect(store.plans.has(w.alone)).toBe(true);
    // S3 down halfway: the retry starts again where it stopped.
    failRemove = true;
    expect(await status(call(w.ada.caller, 'DELETE', '/api/me', { confirm: true }))).toBe(500);
    expect(store.climbers.has(w.me.id)).toBe(true);
    expect(await call(w.ada.caller, 'DELETE', '/api/me', { confirm: true })).toEqual({});
    expect(store.climbers.has(w.me.id)).toBe(false);
    expect(store.plans.has(w.alone)).toBe(false);
    expect(store.plans.get(w.shared)!.plan.memberIds).toEqual([w.benMe.id]);
    expect(removed).toEqual(expect.arrayContaining([w.photo, w.media, w.pic]));
    // Cancelled once at Stripe; the retry sees it cancelled.
    expect(cancelled).toEqual(['sub_made_up']);
    expect(await status(auth.caller({ authorization: `Bearer ${w.ada.token}` }))).toBe(401);
    // Already deleted (a third try, the dev header's caller): nothing left, still fine.
    expect(await call(w.ada.caller, 'DELETE', '/api/me', { confirm: true })).toEqual({});
  });

  it('a second DELETE with the old token is signed out', async () => {
    const w = await world();
    await call(w.ada.caller, 'DELETE', '/api/me', { confirm: true });
    expect(await status(auth.caller({ authorization: `Bearer ${w.ada.token}` }))).toBe(401);
    expect(await status(api.handle('DELETE', '/api/me', { caller: null, body: { confirm: true }, query: {} }))).toBe(401);
  });

  it('a blocked climber can delete their account (rbacr keeps the block)', async () => {
    const w = await world();
    rbacr.give('ada@example.com', 'blocked');
    expect(await status(call(w.ada.caller, 'GET', '/api/plans'))).toBe(403);
    await call(w.ada.caller, 'DELETE', '/api/me', { confirm: true });
    expect(store.climbers.has(w.me.id)).toBe(false);
    expect(rbacr.rolesOf('ada@example.com')).toEqual(['blocked']);
  });

  it("Stripe's late events don't bring the deleted account's subscription back", async () => {
    const w = await world();
    await call(w.ada.caller, 'DELETE', '/api/me', { confirm: true });
    const calls = rbacr.calls.length;
    const body = JSON.stringify({ id: 'evt', type: 'customer.subscription.deleted', data: { object: { id: 'sub_made_up' } } });
    expect(await api.stripeWebhook(body, 'signed')).toEqual({ received: true });
    expect(store.subscriptions.has(w.me.id)).toBe(false);
    expect(rbacr.calls.length).toBe(calls);
  });

  it('signing in again with the same Google account starts afresh', async () => {
    const w = await world();
    await call(w.ada.caller, 'DELETE', '/api/me', { confirm: true });
    const again = await signIn('ada');
    const { climber } = await call(again.caller, 'GET', '/api/me');
    expect(climber.id).not.toBe(w.me.id);
    expect(climber.name).toBe('ada');
    expect((await call(again.caller, 'GET', '/api/plans')).plans).toEqual([]);
  });
});
