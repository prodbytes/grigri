// Reports, personal blocks and the objectionable-words filter
// (specs/moderation.md). Made-up people only.
import { beforeEach, describe, expect, it } from 'vitest';
import { Api, CANT_ASK } from '../src/api.js';
import { Auth, type Caller } from '../src/auth.js';
import { ApiError } from '../src/domain/errors.js';
import { BLOCKED_WORDS, assertClean, isObjectionable, normalize } from '../src/domain/filter.js';
import { reportId, reportInput } from '../src/domain/moderation.js';
import type { Delivery } from '../src/realtime.js';
import { FakeRbacr } from './fake-rbacr.js';
import { FakeStore } from './fake-store.js';

let now = new Date('2030-05-01T10:00:00.000Z');
let store: FakeStore;
let api: Api;
let rbacr: FakeRbacr;
let objects: Map<string, boolean>;
let removed: string[];
let hints: Delivery[];

const who = (name: string, admin = false): Caller => ({ subject: `test#${name}`, email: `${name}@example.com`, admin });
const ada = who('ada');
const ben = who('ben');
const cy = who('cy');
const root = who('root', true);

const call = async (c: Caller, method: string, path: string, body?: unknown, query: Record<string, string> = {}) =>
  (await api.handle(method, path, { caller: c, body, query })) as Record<string, any>;

async function fails(promise: Promise<unknown>, status: number, message?: RegExp) {
  const error = await promise.then(() => undefined, (e: unknown) => e);
  expect(error).toBeInstanceOf(ApiError);
  expect((error as ApiError).status).toBe(status);
  if (message) expect((error as ApiError).message).toMatch(message);
}

const profile = (name: string, more: Record<string, unknown> = {}) => ({
  name, bio: '', levels: { sport: { scale: 'routes', min: 6, max: 10 } }, gear: ['rope'], ...more,
});
const planBody = {
  discipline: 'sport', place: 'Somewhere', area: 'Nowhere', start: '2030-05-10T08:00:00Z', end: '2030-05-10T14:00:00Z',
  grades: { scale: 'routes', min: 6, max: 10 }, notes: '',
};

let ids: Record<string, string>;

beforeEach(async () => {
  now = new Date('2030-05-01T10:00:00.000Z');
  store = new FakeStore();
  objects = new Map();
  removed = [];
  hints = [];
  rbacr = new FakeRbacr(() => now);
  rbacr.give('root@example.com', 'admin');
  const photos = {
    presign: async (key: string) => {
      objects.set(key, true);
      return { url: 'https://upload.example.com/', fields: {} };
    },
    keep: async (key: string) => {
      if (!objects.has(key)) return false;
      objects.set(key, false);
      return true;
    },
    remove: async (keys: string[]) => {
      removed.push(...keys);
    },
  };
  const auth = new Auth({ store: store.asStore(), verify: async () => { throw new Error('unused'); }, config: { devMode: false, isAdmin: async () => false }, clock: () => now });
  const realtime = { notify: async (d: Delivery[]) => { hints.push(...d); }, info: () => ({ url: null }) };
  api = new Api({
    store: store.asStore(), photos, auth, roles: rbacr.lookup, grants: rbacr.api, realtime: realtime as never,
    config: { stage: 'local', version: '0.1.0' }, clock: () => now, random: () => 0,
  });
  ids = {};
  for (const [c, name] of [[ada, 'Ada'], [ben, 'Ben'], [cy, 'Cy'], [root, 'Root']] as const) {
    ids[name] = (await call(c, 'PUT', '/api/me', profile(name))).climber.id;
  }
  // The admin's app loads: Grigri now knows to tell them of reports.
  await call(root, 'GET', '/api/me');
});

describe('the filter', () => {
  it('finds whole words, ignoring case, accents, repeats, leetspeak and spacing', () => {
    expect(isObjectionable('what the FUCK')).toBe(true);
    expect(isObjectionable('fuuuuck')).toBe(true);
    expect(isObjectionable('f4ck')).toBe(false); // f4ck is "fack": not a word on the list
    expect(isObjectionable('fvck you')).toBe(false);
    expect(isObjectionable('fu(k')).toBe(false);
    expect(isObjectionable('$lut')).toBe(true);
    expect(isObjectionable('5LUT')).toBe(true);
    expect(isObjectionable('f u c k')).toBe(true);
    expect(isObjectionable('f.u.c.k off')).toBe(true);
    expect(isObjectionable('MARICÓN')).toBe(true);
    expect(isObjectionable('enculé')).toBe(true);
    expect(isObjectionable('Schlampe!')).toBe(true);
    expect(isObjectionable('caralho')).toBe(true);
    expect(isObjectionable('ets un maricó')).toBe(true);
  });

  it('lets ordinary climbing talk through, in every language', () => {
    for (const ok of [
      'Sport climbing at Siurana, 6a+ to 7a, bring a 70 m rope',
      'Class at the gym; assassin crack; Scunthorpe',
      'Escalada en Montserrat, vía de 6b',
      'Klettern im Frankenjura, 7- bis 8',
      "Grimpe à Fontainebleau, retard d'une heure",
      'Escalada na Serra do Cipó; ele pede corda',
      'Escalada a Margalef amb la colla; el negre i la polla',
      'Bouldering 7A+/V7, ass-saving spot',
      '',
    ]) {
      expect(isObjectionable(ok), ok).toBe(false);
    }
  });

  it('normalizes accents and leetspeak; every listed word is caught', () => {
    expect(normalize('Ça 3st Ñ0')).toBe('ca est no');
    for (const word of Object.values(BLOCKED_WORDS).flat()) expect(isObjectionable(word), word).toBe(true);
  });

  it('assertClean answers a 400 starting objectionable:, naming the field', () => {
    expect(() => assertClean({ bio: 'hello' })).not.toThrow();
    try {
      assertClean({ bio: 'hi', notes: 'whore' });
      expect.unreachable();
    } catch (e) {
      expect((e as ApiError).status).toBe(400);
      expect((e as ApiError).message).toMatch(/^objectionable: notes/);
    }
  });

  it('every posting route refuses objectionable text', async () => {
    await fails(call(ada, 'PUT', '/api/me', profile('Fucker')), 400, /^objectionable: name/);
    await fails(call(ada, 'PUT', '/api/me', profile('Ada', { bio: 'no sluts' })), 400, /^objectionable: bio/);
    await fails(call(ada, 'POST', '/api/plans', { ...planBody, notes: 'p.u.t.a' }), 400, /^objectionable: notes/);
    // A place typed by hand is checked; one from the sector index isn't.
    await fails(call(ada, 'POST', '/api/plans', { ...planBody, place: 'Cunt Crag' }), 400, /^objectionable: place/);
    const plan = (await call(ada, 'POST', '/api/plans', planBody)).plan;
    await fails(call(ada, 'PUT', `/api/plans/${plan.id}`, { ...planBody, notes: 'ficken' }), 400, /^objectionable/);
    await fails(call(ada, 'POST', `/api/plans/${plan.id}/messages`, { text: 'you n1gger' }), 400, /^objectionable: text/);
    rbacr.give('ada@example.com', 'premium');
    await fails(call(ada, 'POST', '/api/ads', { text: 'porn here', link: 'https://example.com/' }), 400, /^objectionable: text/);
    // Friendly text goes through.
    await call(ada, 'POST', `/api/plans/${plan.id}/messages`, { text: 'See you at the crag' });
  });
});

describe('reports', () => {
  it('validates the body', () => {
    expect(() => reportInput({ kind: 'nope', targetId: 'x', reason: 'spam' })).toThrow(/kind/);
    expect(() => reportInput({ kind: 'plan', targetId: 'x', reason: 'rude' })).toThrow(/reason/);
    expect(() => reportInput({ kind: 'message', targetId: 'x', reason: 'spam' })).toThrow(/planId/);
    expect(() => reportInput({ kind: 'plan', targetId: 'x', reason: 'spam', text: 'x'.repeat(501) })).toThrow(/500/);
    expect(reportInput({ kind: 'plan', targetId: 'x', reason: 'other', text: '  why  ' })).toEqual({ kind: 'plan', targetId: 'x', reason: 'other', text: 'why' });
    expect(reportId('a', 'plan', 'x')).toBe(reportId('a', 'plan', 'x'));
    expect(reportId('a', 'plan', 'x')).not.toBe(reportId('b', 'plan', 'x'));
  });

  it('anyone reports a profile; admins see it, are told, and only they', async () => {
    await call(ben, 'PUT', '/api/me', profile('Ben', { bio: 'Rude bio' }));
    expect(await call(ada, 'POST', '/api/reports', { kind: 'profile', targetId: ids.Ben, reason: 'harassment', text: 'Mean to me' })).toEqual({});
    await fails(call(ada, 'POST', '/api/reports', { kind: 'profile', targetId: ids.Ada, reason: 'spam' }), 400, /your own/);
    await fails(call(ada, 'POST', '/api/reports', { kind: 'profile', targetId: 'nobody', reason: 'spam' }), 404);

    // The admin's notice and hint; nobody else's.
    const notices = (await call(root, 'GET', '/api/notices')).notices;
    expect(notices).toEqual([expect.objectContaining({ id: 'reports', kind: 'report', read: false })]);
    expect(hints).toContainEqual({ to: ids.Root, hint: { kind: 'notice' } });
    expect((await call(ben, 'GET', '/api/notices')).notices).toEqual([]);

    await fails(call(ada, 'GET', '/api/admin/reports'), 403);
    await fails(call(ben, 'POST', '/api/admin/reports/x/dismiss'), 403);
    const { reports, climbers } = await call(root, 'GET', '/api/admin/reports');
    expect(reports).toEqual([expect.objectContaining({
      kind: 'profile', targetId: ids.Ben, subjectId: ids.Ben, reporterId: ids.Ada, reason: 'harassment', text: 'Mean to me',
      content: { title: 'Ben', text: 'Rude bio' }, status: 'open',
    })]);
    expect(Object.keys(climbers).sort()).toEqual([ids.Ada, ids.Ben].sort());

    // Reporting it again replaces it.
    await call(ada, 'POST', '/api/reports', { kind: 'profile', targetId: ids.Ben, reason: 'fake' });
    expect((await call(root, 'GET', '/api/admin/reports')).reports.map((r: any) => r.reason)).toEqual(['fake']);
  });

  it("a former admin isn't told, and is forgotten", async () => {
    rbacr.grants.get('root@example.com')!.delete('admin');
    await call(ada, 'POST', '/api/reports', { kind: 'profile', targetId: ids.Ben, reason: 'spam' });
    expect((await call(root, 'GET', '/api/notices')).notices).toEqual([]);
    expect(store.admins.size).toBe(0);
  });

  it('dismiss closes it; it leaves the list and can\'t be handled twice', async () => {
    await call(ada, 'POST', '/api/reports', { kind: 'profile', targetId: ids.Ben, reason: 'spam' });
    const [report] = (await call(root, 'GET', '/api/admin/reports')).reports;
    const { report: done } = await call(root, 'POST', `/api/admin/reports/${report.id}/dismiss`);
    expect(done).toMatchObject({ status: 'dismissed', resolvedBy: ids.Root });
    expect((await call(root, 'GET', '/api/admin/reports')).reports).toEqual([]);
    await fails(call(root, 'POST', `/api/admin/reports/${report.id}/remove`), 409);
    await fails(call(root, 'POST', '/api/admin/reports/nothing/dismiss'), 404);
  });

  it('remove: a profile loses its bio and photos', async () => {
    const photo = `${ids.Ben}/profile/abcdefghijklmnop.jpg`;
    objects.set(photo, true);
    await call(ben, 'PUT', '/api/me', profile('Ben', { bio: 'Rude', photo }));
    await call(ada, 'POST', '/api/reports', { kind: 'profile', targetId: ids.Ben, reason: 'inappropriate' });
    const [report] = (await call(root, 'GET', '/api/admin/reports')).reports;
    expect(report.content.media).toEqual([{ key: photo, kind: 'image' }]);
    await call(root, 'POST', `/api/admin/reports/${report.id}/remove`);
    expect(store.climbers.get(ids.Ben!)).toMatchObject({ name: 'Ben', bio: '', gearPhotos: [] });
    expect(store.climbers.get(ids.Ben!)!.photo).toBeUndefined();
    expect(removed).toEqual([photo]);
  });

  it("remove: a plan's notes are cleared", async () => {
    const plan = (await call(ben, 'POST', '/api/plans', { ...planBody, notes: 'Spammy notes' })).plan;
    await call(ada, 'POST', '/api/reports', { kind: 'plan', targetId: plan.id, reason: 'spam' });
    const [report] = (await call(root, 'GET', '/api/admin/reports')).reports;
    expect(report).toMatchObject({ subjectId: ids.Ben, content: { title: 'Somewhere, Nowhere', text: 'Spammy notes' } });
    await call(root, 'POST', `/api/admin/reports/${report.id}/remove`);
    expect(store.plans.get(plan.id)!.plan.notes).toBe('');
  });

  it('a chat message: members only report it; remove deletes it and its photo', async () => {
    const plan = (await call(ada, 'POST', '/api/plans', { ...planBody, type: 'open' })).plan;
    await call(ben, 'POST', `/api/plans/${plan.id}/join`);
    const { key } = await call(ben, 'POST', `/api/plans/${plan.id}/media`, { contentType: 'image/jpeg' });
    const { message } = await call(ben, 'POST', `/api/plans/${plan.id}/messages`, { text: 'Look', attachment: key });
    expect(store.pics.map((p) => p.key)).toEqual([key]);

    const body = { kind: 'message', targetId: message.id, planId: plan.id, reason: 'inappropriate' };
    await fails(call(cy, 'POST', '/api/reports', body), 403);
    await fails(call(ada, 'POST', '/api/reports', { ...body, targetId: 'nothing' }), 404);
    const note = store.msgs.find((m) => m.planId === plan.id && m.authorId === null)!;
    await fails(call(ada, 'POST', '/api/reports', { ...body, targetId: note.id }), 400, /notes/);
    await call(ada, 'POST', '/api/reports', body);

    const [report] = (await call(root, 'GET', '/api/admin/reports')).reports;
    expect(report).toMatchObject({ subjectId: ids.Ben, planId: plan.id, content: { text: 'Look', media: [{ key, kind: 'image' }] } });
    await call(root, 'POST', `/api/admin/reports/${report.id}/remove`);
    expect(store.msgs.find((m) => m.id === message.id)).toBeUndefined();
    expect(store.pics).toEqual([]);
    expect(removed).toEqual([key]);
  });

  it('a plan photo: remove deletes it', async () => {
    const plan = (await call(ada, 'POST', '/api/plans', { ...planBody, type: 'open' })).plan;
    await call(ben, 'POST', `/api/plans/${plan.id}/join`);
    const { key } = await call(ben, 'POST', `/api/plans/${plan.id}/pics/upload`, { contentType: 'image/png' });
    const { pic } = await call(ben, 'POST', `/api/plans/${plan.id}/pics`, { key });
    await fails(call(cy, 'POST', '/api/reports', { kind: 'pic', targetId: pic.id, planId: plan.id, reason: 'other' }), 403);
    await call(ada, 'POST', '/api/reports', { kind: 'pic', targetId: pic.id, planId: plan.id, reason: 'other' });
    const [report] = (await call(root, 'GET', '/api/admin/reports')).reports;
    await call(root, 'POST', `/api/admin/reports/${report.id}/remove`);
    expect(store.pics).toEqual([]);
    expect(removed).toEqual([key]);
  });

  it('an ad: remove deletes it', async () => {
    rbacr.give('ben@example.com', 'premium');
    const { ad } = await call(ben, 'POST', '/api/ads', { text: 'Buy my rope', link: 'https://example.com/' });
    await call(ada, 'POST', '/api/reports', { kind: 'ad', targetId: ad.id, reason: 'spam' });
    const [report] = (await call(root, 'GET', '/api/admin/reports')).reports;
    expect(report.content).toEqual({ text: 'Buy my rope', link: 'https://example.com/' });
    await call(root, 'POST', `/api/admin/reports/${report.id}/remove`);
    expect(store.ads.size).toBe(0);
  });

  it("block: the reported climber is blocked app-wide (rbacr's role), as Admin → Users does", async () => {
    await call(ada, 'POST', '/api/reports', { kind: 'profile', targetId: ids.Ben, reason: 'harassment' });
    const [report] = (await call(root, 'GET', '/api/admin/reports')).reports;
    expect((await call(root, 'POST', `/api/admin/reports/${report.id}/block`)).report.status).toBe('blocked');
    expect(rbacr.calls).toEqual(['grant blocked ben@example.com']);
    await fails(call(ben, 'GET', '/api/discover'), 403, /blocked/);
  });
});

describe('blocking someone', () => {
  it('lists, refuses myself and nobody, and unblocks', async () => {
    expect(await call(ada, 'POST', `/api/blocks/${ids.Ben}`)).toEqual({ blocked: true });
    await fails(call(ada, 'POST', `/api/blocks/${ids.Ada}`), 400);
    await fails(call(ada, 'POST', '/api/blocks/nobody'), 404);
    const mine = await call(ada, 'GET', '/api/blocks');
    expect(mine.blocked).toEqual([ids.Ben]);
    expect(mine.climbers[ids.Ben!].name).toBe('Ben');
    // Ben never learns who blocked him.
    expect((await call(ben, 'GET', '/api/blocks')).blocked).toEqual([]);
    expect(await call(ada, 'DELETE', `/api/blocks/${ids.Ben}`)).toEqual({ blocked: false });
    expect((await call(ada, 'GET', '/api/blocks')).blocked).toEqual([]);
  });

  it("hides plans both ways on the deck, and neither can ask to join the other's", async () => {
    const adas = (await call(ada, 'POST', '/api/plans', planBody)).plan;
    const bens = (await call(ben, 'POST', '/api/plans', { ...planBody, place: 'Elsewhere' })).plan;
    // Cy's plan, with Ben in it: off Ada's deck too.
    const cys = (await call(cy, 'POST', '/api/plans', { ...planBody, place: 'Third', type: 'open' })).plan;
    await call(ben, 'POST', `/api/plans/${cys.id}/join`);
    expect((await call(ada, 'GET', '/api/discover')).plans.map((p: any) => p.id).sort()).toEqual([bens.id, cys.id].sort());

    await call(ada, 'POST', `/api/blocks/${ids.Ben}`);
    expect((await call(ada, 'GET', '/api/discover')).plans).toEqual([]);
    expect((await call(ben, 'GET', '/api/discover')).plans).toEqual([]);
    await fails(call(ben, 'POST', `/api/plans/${adas.id}/join`), 409, new RegExp(`^${CANT_ASK}$`));
    await fails(call(ada, 'POST', `/api/plans/${bens.id}/join`), 409, new RegExp(`^${CANT_ASK}$`));
    await fails(call(ada, 'POST', `/api/plans/${cys.id}/join`), 409, new RegExp(`^${CANT_ASK}$`));
    // Cy is untouched.
    expect((await call(cy, 'GET', '/api/discover')).plans.map((p: any) => p.id)).toContain(adas.id);

    await call(ada, 'DELETE', `/api/blocks/${ids.Ben}`);
    expect((await call(ben, 'GET', '/api/discover')).plans.map((p: any) => p.id)).toEqual([adas.id]);
    await call(ben, 'POST', `/api/plans/${adas.id}/join`);
  });

  it("declines their open requests on plans I decide on, and not on others'", async () => {
    const adas = (await call(ada, 'POST', '/api/plans', planBody)).plan;
    rbacr.give('cy@example.com', 'premium');
    const guided = (await call(cy, 'POST', '/api/plans', { ...planBody, type: 'guided', price: { amount: 30, currency: 'EUR' } })).plan;
    await call(ada, 'POST', `/api/plans/${guided.id}/join`);
    await call(cy, 'POST', `/api/requests/${guided.id}/${ids.Ada}/accept`);
    await call(ben, 'POST', `/api/plans/${adas.id}/join`);
    await call(ben, 'POST', `/api/plans/${guided.id}/join`);

    await call(ada, 'POST', `/api/blocks/${ids.Ben}`);
    expect(store.requests.get(`${adas.id}/${ids.Ben}`)).toMatchObject({ rejected: true });
    // A neutral "Not this time", as any no.
    expect((await call(ben, 'GET', '/api/notices')).notices).toContainEqual(expect.objectContaining({ kind: 'declined', planId: adas.id }));
    // Cy's guided plan: Cy decides, not Ada; Ben's request waits.
    expect(store.requests.get(`${guided.id}/${ids.Ben}`)).toMatchObject({ rejected: false });
    expect((await call(ada, 'GET', '/api/requests')).requests).toEqual([]);
  });
});
