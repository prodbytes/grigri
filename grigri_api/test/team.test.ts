// The Grigri team chat (specs/team-chat.md): every climber writes to the
// team; admins read every team chat and answer as the team. Made-up
// people only.
import { beforeEach, describe, expect, it } from 'vitest';
import { Api } from '../src/api.js';
import { Auth, type Caller } from '../src/auth.js';
import { ApiError } from '../src/domain/errors.js';
import type { Delivery } from '../src/realtime.js';
import { FakeRbacr } from './fake-rbacr.js';
import { FakeStore } from './fake-store.js';

let now = new Date('2030-05-01T10:00:00.000Z');
let store: FakeStore;
let api: Api;
let rbacr: FakeRbacr;
let hints: Delivery[];

const who = (name: string, admin = false): Caller => ({ subject: `test#${name}`, email: `${name}@example.com`, isAdmin: async () => admin });
const ada = who('ada');
const ben = who('ben');
const root = who('root', true);
const sam = who('sam', true);

const call = async (c: Caller, method: string, path: string, body?: unknown, query: Record<string, string> = {}) =>
  (await api.handle(method, path, { caller: c, body, query })) as Record<string, any>;

async function fails(promise: Promise<unknown>, status: number, message?: RegExp) {
  const error = await promise.then(() => undefined, (e: unknown) => e);
  expect(error).toBeInstanceOf(ApiError);
  expect((error as ApiError).status).toBe(status);
  if (message) expect((error as ApiError).message).toMatch(message);
}

const profile = (name: string) => ({ name, bio: '', levels: {}, gear: [] });

let ids: Record<string, string>;

beforeEach(async () => {
  now = new Date('2030-05-01T10:00:00.000Z');
  store = new FakeStore();
  hints = [];
  rbacr = new FakeRbacr(() => now);
  rbacr.give('root@example.com', 'admin');
  rbacr.give('sam@example.com', 'admin');
  const photos = { presign: async () => ({ url: 'https://upload.example.com/', fields: {} }), keep: async () => true, remove: async () => {} };
  const auth = new Auth({ store: store.asStore(), verify: async () => { throw new Error('unused'); }, config: { devMode: false, isAdmin: async () => false }, clock: () => now });
  const realtime = { notify: async (d: Delivery[]) => { hints.push(...d); }, info: () => ({ url: null }) };
  api = new Api({
    store: store.asStore(), photos, auth, roles: rbacr.lookup, grants: rbacr.api, realtime: realtime as never,
    config: { stage: 'local', version: '0.1.0' }, clock: () => now, random: () => 0,
  });
  ids = {};
  for (const [c, name] of [[ada, 'Ada'], [ben, 'Ben'], [root, 'Root'], [sam, 'Sam']] as const) {
    ids[name] = (await call(c, 'PUT', '/api/me', profile(name))).climber.id;
  }
  // The admins' apps load: Grigri knows whom to tell.
  await call(root, 'GET', '/api/me');
  await call(sam, 'GET', '/api/me');
  hints = [];
});

const later = (minutes: number) => {
  now = new Date(now.getTime() + minutes * 60_000);
};

describe('my team chat', () => {
  it('is empty until I write: the welcome is the app’s, nothing is stored', async () => {
    expect((await call(ada, 'GET', '/api/team/messages')).messages).toEqual([]);
    expect(store.teamMsgs).toEqual([]);
    expect(store.teamChatMap.size).toBe(0);
  });

  it('takes my text and tells every admin, with a badge and a hint', async () => {
    const { message } = await call(ada, 'POST', '/api/team/messages', { text: '  Love the app!  ' });
    expect(message).toMatchObject({ climberId: ids.Ada, fromTeam: false, text: 'Love the app!' });
    expect((await call(ada, 'GET', '/api/team/messages')).messages).toHaveLength(1);
    for (const admin of [ids.Root, ids.Sam]) {
      expect(store.noticeMap.get(admin!)?.get('team')).toMatchObject({ kind: 'team', read: false });
      // The notice says nothing of whose chat.
      expect(store.noticeMap.get(admin!)?.get('team')?.climberId).toBeUndefined();
    }
    expect(hints).toEqual(expect.arrayContaining([
      { to: ids.Root, hint: { kind: 'team' } },
      { to: ids.Sam, hint: { kind: 'team' } },
    ]));
    expect(hints.some((h) => h.to === ids.Ben)).toBe(false);
  });

  it('follows the plan chat’s rules: the filter, the length, text only', async () => {
    await fails(call(ada, 'POST', '/api/team/messages', { text: 'what the fuck' }), 400);
    await fails(call(ada, 'POST', '/api/team/messages', { text: '   ' }), 400, /required/);
    await fails(call(ada, 'POST', '/api/team/messages', { text: 'x'.repeat(2001) }), 400, /2000/);
    await fails(call(ada, 'POST', '/api/team/messages', { text: 'look', attachment: 'chat/p/abcdefgh.jpg' }), 400, /text only/);
    expect(store.teamMsgs).toEqual([]);
  });

  it('fetches only what’s new with after=', async () => {
    await call(ada, 'POST', '/api/team/messages', { text: 'First' });
    const first = (await call(ada, 'GET', '/api/team/messages')).messages[0];
    later(1);
    await call(ada, 'POST', '/api/team/messages', { text: 'Second' });
    const newer = (await call(ada, 'GET', '/api/team/messages', undefined, { after: first.time })).messages;
    expect(newer.map((m: { text: string }) => m.text)).toEqual(['Second']);
  });

  it('is only mine: nobody else reads or lists it but the admins', async () => {
    await call(ada, 'POST', '/api/team/messages', { text: 'Just for the team' });
    // Ben's own team chat is his: Ada's isn't in it.
    expect((await call(ben, 'GET', '/api/team/messages')).messages).toEqual([]);
    await fails(call(ben, 'GET', '/api/admin/team'), 403, /admins only/);
    await fails(call(ben, 'GET', `/api/admin/team/${ids.Ada}/messages`), 403, /admins only/);
    await fails(call(ben, 'POST', `/api/admin/team/${ids.Ada}/messages`, { text: 'Hi, it’s the team' }), 403, /admins only/);
    await fails(call(ada, 'GET', '/api/admin/team'), 403);
  });
});

describe('the admins', () => {
  it('list every team chat with a message, the latest first', async () => {
    await call(ada, 'POST', '/api/team/messages', { text: 'From Ada' });
    later(1);
    await call(ben, 'POST', '/api/team/messages', { text: 'From Ben' });
    const { chats, climbers } = await call(sam, 'GET', '/api/admin/team');
    expect(chats.map((c: { climberId: string }) => c.climberId)).toEqual([ids.Ben, ids.Ada]);
    expect(chats[0]).toMatchObject({ lastText: 'From Ben', lastFromTeam: false });
    expect(Object.keys(climbers).sort()).toEqual([ids.Ada, ids.Ben].sort());
  });

  it('answer as the Grigri team: the climber never sees which admin', async () => {
    await call(ada, 'POST', '/api/team/messages', { text: 'Can I add a crag?' });
    later(1);
    hints = [];
    const { message } = await call(root, 'POST', `/api/admin/team/${ids.Ada}/messages`, { text: 'Sure, tell us which' });
    expect(message).toMatchObject({ climberId: ids.Ada, fromTeam: true, adminId: ids.Root });

    const mine = (await call(ada, 'GET', '/api/team/messages')).messages;
    expect(mine.map((m: { fromTeam: boolean }) => m.fromTeam)).toEqual([false, true]);
    expect(mine[1]).not.toHaveProperty('adminId');
    expect(JSON.stringify(mine)).not.toContain(ids.Root);

    // The admins see who answered.
    const seen = await call(sam, 'GET', `/api/admin/team/${ids.Ada}/messages`);
    expect(seen.messages[1].adminId).toBe(ids.Root);
    expect(Object.keys(seen.climbers).sort()).toEqual([ids.Ada, ids.Root].sort());
    expect((await call(sam, 'GET', '/api/admin/team')).chats[0]).toMatchObject({ climberId: ids.Ada, lastFromTeam: true });

    // Ada gets a badge and a hint; Sam a hint for an open chat.
    expect(store.noticeMap.get(ids.Ada!)?.get('team')).toMatchObject({ kind: 'team', read: false });
    expect(hints).toEqual(expect.arrayContaining([
      { to: ids.Ada, hint: { kind: 'team' } },
      { to: ids.Sam, hint: { kind: 'team' } },
    ]));
    expect(hints.some((h) => h.to === ids.Root)).toBe(false);
  });

  it('answer through the filter, and only to someone who exists', async () => {
    await fails(call(root, 'POST', `/api/admin/team/${ids.Ada}/messages`, { text: 'what the FUCK' }), 400);
    await fails(call(root, 'POST', '/api/admin/team/nobody123/messages', { text: 'Hello' }), 404);
  });
});

describe('the team chat’s badge', () => {
  it('is cleared by opening the chat, not by reading Notifications', async () => {
    await call(root, 'POST', `/api/admin/team/${ids.Ada}/messages`, { text: 'Welcome aboard' });
    await call(ada, 'POST', '/api/notices/read');
    expect(store.noticeMap.get(ids.Ada!)?.get('team')?.read).toBe(false);
    await call(ada, 'POST', '/api/team/read');
    expect(store.noticeMap.get(ids.Ada!)?.get('team')?.read).toBe(true);
  });
});

describe('deleting my account', () => {
  it('deletes my team chat, the team’s answers too', async () => {
    await call(ada, 'POST', '/api/team/messages', { text: 'Bye for now' });
    await call(root, 'POST', `/api/admin/team/${ids.Ada}/messages`, { text: 'Come back soon' });
    await call(ben, 'POST', '/api/team/messages', { text: 'Still here' });
    await call(ada, 'DELETE', '/api/me', { confirm: true });
    expect(store.teamMsgs.map((m) => m.climberId)).toEqual([ids.Ben]);
    expect((await call(root, 'GET', '/api/admin/team')).chats.map((c: { climberId: string }) => c.climberId)).toEqual([ids.Ben]);
  });
});
