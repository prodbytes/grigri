import type { webcrypto } from 'node:crypto';
import { createLocalJWKSet, exportJWK, generateKeyPair, type JWK, SignJWT } from 'jose';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { Auth, type AuthConfig, hashToken, subjectHash } from '../src/auth.js';
import { ApiError } from '../src/domain/errors.js';
import { type GoogleIdentity, googleVerifier, InvalidIdToken, parseClientIds } from '../src/google.js';
import { Router } from '../src/router.js';
import { FakeStore } from './fake-store.js';

// Keys made here, and a JWKS standing in for Google's: never real tokens.
const AUD = '123456789-test.apps.googleusercontent.com';
let googleKey: webcrypto.CryptoKey;
let otherKey: webcrypto.CryptoKey;
let jwks: ReturnType<typeof createLocalJWKSet>;

beforeAll(async () => {
  const google = await generateKeyPair('RS256', { extractable: true });
  const other = await generateKeyPair('RS256', { extractable: true });
  googleKey = google.privateKey;
  otherKey = other.privateKey;
  const jwk: JWK = { ...(await exportJWK(google.publicKey)), kid: 'k1', alg: 'RS256', use: 'sig' };
  jwks = createLocalJWKSet({ keys: [jwk] });
});

async function idToken(
  claims: Record<string, unknown> = {},
  opts: { key?: webcrypto.CryptoKey; iss?: string; aud?: string; exp?: number | string; kid?: string } = {},
) {
  return new SignJWT({ email: 'Ada@Example.com', email_verified: true, ...claims })
    .setProtectedHeader({ alg: 'RS256', kid: opts.kid ?? 'k1' })
    .setIssuer(opts.iss ?? 'https://accounts.google.com')
    .setAudience(opts.aud ?? AUD)
    .setSubject('1001')
    .setIssuedAt()
    .setExpirationTime(opts.exp ?? '1h')
    .sign(opts.key ?? googleKey);
}

describe('googleVerifier', () => {
  it('accepts a token Google signed for our client, either issuer spelling', async () => {
    const verify = googleVerifier(AUD, jwks);
    const expected: GoogleIdentity = { subject: 'https://accounts.google.com#1001', email: 'ada@example.com', emailVerified: true };
    expect(await verify(await idToken())).toEqual(expected);
    expect(await verify(await idToken({}, { iss: 'accounts.google.com' }))).toEqual(expected);
  });

  it('also accepts tokens issued to the iOS clients (an iPhone\'s), and only those', async () => {
    const IOS = '123456789-ios.apps.googleusercontent.com';
    const verify = googleVerifier(AUD, jwks, [IOS]);
    expect((await verify(await idToken({}, { aud: IOS }))).subject).toBe('https://accounts.google.com#1001');
    expect((await verify(await idToken())).subject).toBe('https://accounts.google.com#1001');
    await expect(verify(await idToken({}, { aud: 'someone-else.apps.googleusercontent.com' }))).rejects.toBeInstanceOf(
      InvalidIdToken,
    );
    // Without the iOS client, its tokens are refused.
    await expect(googleVerifier(AUD, jwks)(await idToken({}, { aud: IOS }))).rejects.toBeInstanceOf(InvalidIdToken);
    // No web client (dev mode): nothing is accepted, iOS clients or not.
    await expect(googleVerifier('', jwks, [IOS])(await idToken({}, { aud: IOS }))).rejects.toBeInstanceOf(InvalidIdToken);
  });

  it('reads client IDs from a comma-separated setting', () => {
    expect(parseClientIds(' a.apps.googleusercontent.com, ,b.apps.googleusercontent.com,')).toEqual([
      'a.apps.googleusercontent.com',
      'b.apps.googleusercontent.com',
    ]);
    expect(parseClientIds(undefined)).toEqual([]);
  });

  it('keeps the account name, tidied, for a new profile', async () => {
    const verify = googleVerifier(AUD, jwks);
    expect((await verify(await idToken({ name: '  Ada   Example ' }))).name).toBe('Ada Example');
    expect((await verify(await idToken({ name: 'x'.repeat(80) }))).name).toBe('x'.repeat(60));
    expect(await verify(await idToken({ name: '   ' }))).not.toHaveProperty('name');
    expect(await verify(await idToken({ name: 42 }))).not.toHaveProperty('name');
  });

  it('drops an unverified email', async () => {
    const verify = googleVerifier(AUD, jwks);
    expect(await verify(await idToken({ email_verified: false }))).toEqual({
      subject: 'https://accounts.google.com#1001',
      emailVerified: false,
    });
  });

  it('refuses forged, foreign, expired and malformed tokens', async () => {
    const verify = googleVerifier(AUD, jwks);
    const refused = async (token: string | Promise<string>) =>
      expect(verify(await token)).rejects.toBeInstanceOf(InvalidIdToken);
    await refused(idToken({}, { key: otherKey }));
    await refused(idToken({}, { aud: 'someone-else.apps.googleusercontent.com' }));
    await refused(idToken({}, { iss: 'https://evil.example.com' }));
    await refused(idToken({}, { exp: Math.floor(Date.now() / 1000) - 3600 }));
    await refused(idToken({}, { kid: 'unknown' }));
    await refused('not-a-jwt');
    await refused(`${'a'.repeat(5000)}.b.c`);
    const none = `${Buffer.from('{"alg":"none"}').toString('base64url')}.${Buffer.from(JSON.stringify({ iss: 'https://accounts.google.com', aud: AUD, sub: '1', exp: 9999999999, iat: 1 })).toString('base64url')}.`;
    await refused(none);
  });

  it('refuses everything without a client ID', async () => {
    await expect(googleVerifier('', jwks)(await idToken())).rejects.toBeInstanceOf(InvalidIdToken);
  });
});

// Stands in for rbacr: who holds grigri's admin role.
const admins = new Set(['admin@example.com', 'other@example.com']);
const DAY = 24 * 60 * 60 * 1000;

describe('Auth sessions', () => {
  let store: FakeStore;
  let now: Date;
  let identity: GoogleIdentity;
  const make = (config: Partial<AuthConfig> = {}) =>
    new Auth({
      store: store.asStore(),
      verify: async (token) => {
        if (token !== 'good') throw new InvalidIdToken('bad');
        return identity;
      },
      config: { devMode: false, isAdmin: async (email) => admins.has(email), ...config },
      clock: () => now,
    });
  const bearer = (token: string) => ({ authorization: `Bearer ${token}` });
  const status = async (p: Promise<unknown>) => ((await p.then(() => undefined, (e) => e)) as ApiError)?.status;

  beforeEach(() => {
    store = new FakeStore();
    now = new Date('2030-01-01T00:00:00.000Z');
    identity = { subject: 'https://accounts.google.com#7', email: 'admin@example.com', emailVerified: true };
  });

  it('creates a session stored only as its hash', async () => {
    const { token, expiresAt } = await make().signIn({ idToken: 'good' });
    expect(token).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(expiresAt).toBe('2031-01-01T00:00:00.000Z');
    expect([...store.sessions.keys()]).toEqual([hashToken(token)]);
    expect(JSON.stringify([...store.sessions.values()])).not.toContain(token);
    expect(store.sessions.get(hashToken(token))).toEqual({
      id: hashToken(token),
      subject: 'https://accounts.google.com#7',
      email: 'admin@example.com',
      emailVerified: true,
      createdAt: '2030-01-01T00:00:00.000Z',
      lastUsedAt: '2030-01-01T00:00:00.000Z',
      ttl: Date.parse('2031-01-01T00:00:00.000Z') / 1000,
    });
  });

  it('401s a bad Google token, 400s a body without one', async () => {
    expect(await status(make().signIn({ idToken: 'bad' }))).toBe(401);
    expect(await status(make().signIn({}))).toBe(400);
    expect(await status(make().signIn('good'))).toBe(400);
    expect(store.sessions.size).toBe(0);
  });

  it('looks the caller up, admin from rbacr\'s answer for the verified email', async () => {
    const { token } = await make().signIn({ idToken: 'good' });
    const caller = await make().caller(bearer(token));
    expect(caller).toEqual({ subject: 'https://accounts.google.com#7', email: 'admin@example.com', admin: true, sessionId: hashToken(token) });
    // rbacr says no now: no longer admin, same session.
    expect((await make({ isAdmin: async () => false }).caller(bearer(token))).admin).toBe(false);
  });

  it('keeps the Google name with the session, for the caller', async () => {
    identity = { ...identity, name: 'Ada Example' };
    const { token } = await make().signIn({ idToken: 'good' });
    expect((await make().caller(bearer(token))).name).toBe('Ada Example');
  });

  it('is never admin with an unverified email', async () => {
    identity = { subject: 'https://accounts.google.com#8', emailVerified: false };
    const { token } = await make().signIn({ idToken: 'good' });
    const caller = await make().caller(bearer(token));
    expect(caller.admin).toBe(false);
    expect(caller.email).toBeUndefined();
  });

  it('slides at most once a day, and lasts 365 days without use', async () => {
    const auth = make();
    const { token } = await auth.signIn({ idToken: 'good' });
    const id = hashToken(token);
    expect(store.sessionWrites).toBe(1);
    now = new Date(now.getTime() + DAY - 1000);
    await auth.caller(bearer(token));
    await auth.caller(bearer(token));
    expect(store.sessionWrites).toBe(1); // under a day: no write
    now = new Date(now.getTime() + 2000);
    await auth.caller(bearer(token));
    await auth.caller(bearer(token));
    expect(store.sessionWrites).toBe(2); // one slide
    expect(store.sessions.get(id)!.lastUsedAt).toBe(now.toISOString());
    expect(store.sessions.get(id)!.ttl).toBe(Math.floor((now.getTime() + 365 * DAY) / 1000));
    // 364 days later: still signed in, and slid again.
    now = new Date(now.getTime() + 364 * DAY);
    await auth.caller(bearer(token));
    // Then 365 days unused: signed out, even before DynamoDB deletes it.
    now = new Date(now.getTime() + 365 * DAY);
    expect(await status(auth.caller(bearer(token)))).toBe(401);
  });

  it('signs out one session, or all of an account', async () => {
    const auth = make();
    const a = (await auth.signIn({ idToken: 'good' })).token;
    const b = (await auth.signIn({ idToken: 'good' })).token;
    identity = { subject: 'https://accounts.google.com#9', emailVerified: false };
    const other = (await auth.signIn({ idToken: 'good' })).token;
    await auth.signOut(await auth.caller(bearer(a)));
    expect(await status(auth.caller(bearer(a)))).toBe(401);
    await auth.caller(bearer(b));
    await auth.signOutEverywhere(await auth.caller(bearer(b)));
    expect(await status(auth.caller(bearer(b)))).toBe(401);
    expect((await auth.caller(bearer(other))).subject).toBe('https://accounts.google.com#9');
  });

  it('401s missing, malformed and unknown tokens', async () => {
    const auth = make();
    for (const headers of [{}, { authorization: 'Bearer' }, { authorization: 'Basic abc' }, bearer('x.y.z'), bearer('A'.repeat(43))]) {
      const error = await auth.caller(headers).then(() => undefined, (e) => e);
      expect(error).toBeInstanceOf(ApiError);
      expect(error).toMatchObject({ status: 401, message: 'signed out' });
    }
  });

  it('dev mode: the header, and devUser sign-in; refused outside dev mode', async () => {
    const dev = make({ devMode: true });
    expect(await dev.caller({ 'x-grigri-dev-user': 'Admin@Example.com' })).toEqual({ subject: 'dev#admin@example.com', email: 'admin@example.com', admin: true, name: 'admin' });
    expect(await status(dev.caller({ 'x-grigri-dev-user': 'not an email' }))).toBe(401);
    const { token } = await dev.signIn({ devUser: 'Admin@Example.com' });
    expect(await dev.caller(bearer(token))).toMatchObject({ subject: 'dev#admin@example.com', admin: true, name: 'admin' });
    expect(await status(dev.signIn({ devUser: 'nope' }))).toBe(400);

    const prod = make();
    expect(await status(prod.caller({ 'x-grigri-dev-user': 'admin@example.com' }))).toBe(401);
    expect(await status(prod.signIn({ devUser: 'admin@example.com' }))).toBe(401);
  });

  it('hashes subjects to a stable folder name', () => {
    expect(subjectHash('a#b')).toMatch(/^[0-9a-f]{32}$/);
    expect(subjectHash('a#b')).toBe(subjectHash('a#b'));
    expect(subjectHash('a#b')).not.toBe(subjectHash('a#c'));
  });
});

describe('Router', () => {
  const router = new Router<string>().add('GET /api/plans/{id}', 'get').add('PUT /api/plans/{id}', 'put').add('GET /api/plans', 'list');

  it('matches methods and parameters', () => {
    expect(router.match('GET', '/api/plans/abc')).toEqual({ handler: 'get', params: { id: 'abc' } });
    expect(router.match('PUT', '/api/plans/a%2Fb')).toEqual({ handler: 'put', params: { id: 'a/b' } });
    expect(router.match('GET', '/api/plans/')).toEqual({ handler: 'list', params: {} });
  });

  it('404s unknown paths and methods', () => {
    expect(() => router.match('GET', '/api/nope')).toThrow(/no such route/);
    expect(() => router.match('DELETE', '/api/plans/abc')).toThrow(/isn't supported/);
    expect(() => router.match('GET', '/api/plans/%E0%A4%A')).toThrow();
  });
});
