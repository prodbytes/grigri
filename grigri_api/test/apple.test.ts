import { generateKeyPairSync, type webcrypto } from 'node:crypto';
import { createLocalJWKSet, decodeJwt, decodeProtectedHeader, exportJWK, generateKeyPair, type JWK, jwtVerify, SignJWT } from 'jose';
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { APPLE_REVOKE_URL, APPLE_TOKEN_URL, AppleTokens, appleVerifier, pkcs8Pem, sha256Hex } from '../src/apple.js';
import { Auth } from '../src/auth.js';
import { ApiError } from '../src/domain/errors.js';
import { InvalidIdToken } from '../src/google.js';
import { FakeStore } from './fake-store.js';

// Keys made here, and a JWKS standing in for Apple's: never real tokens.
const BUNDLE = 'com.nu01.grigri';
const NONCE = 'r4nd0m-n0nce-made-up-for-tests';
let appleKey: webcrypto.CryptoKey;
let otherKey: webcrypto.CryptoKey;
let jwks: ReturnType<typeof createLocalJWKSet>;

beforeAll(async () => {
  const apple = await generateKeyPair('RS256', { extractable: true });
  const other = await generateKeyPair('RS256', { extractable: true });
  appleKey = apple.privateKey;
  otherKey = other.privateKey;
  const jwk: JWK = { ...(await exportJWK(apple.publicKey)), kid: 'apple1', alg: 'RS256', use: 'sig' };
  jwks = createLocalJWKSet({ keys: [jwk] });
});

async function appleToken(
  claims: Record<string, unknown> = {},
  opts: { key?: webcrypto.CryptoKey; iss?: string; aud?: string; exp?: number | string; kid?: string; sub?: string } = {},
) {
  return new SignJWT({ email: 'Quill@privaterelay.appleid.com', email_verified: 'true', is_private_email: 'true', nonce: sha256Hex(NONCE), ...claims })
    .setProtectedHeader({ alg: 'RS256', kid: opts.kid ?? 'apple1' })
    .setIssuer(opts.iss ?? 'https://appleid.apple.com')
    .setAudience(opts.aud ?? BUNDLE)
    .setSubject(opts.sub ?? '000123.abcdef.0456')
    .setIssuedAt()
    .setExpirationTime(opts.exp ?? '10m')
    .sign(opts.key ?? appleKey);
}

describe('appleVerifier', () => {
  it('accepts a token Apple signed for the app, with this sign-in\'s nonce', async () => {
    const verify = appleVerifier(BUNDLE, jwks);
    expect(await verify(await appleToken(), NONCE)).toEqual({
      subject: 'apple#000123.abcdef.0456',
      email: 'quill@privaterelay.appleid.com',
      emailVerified: true,
    });
    // email_verified as a boolean too.
    expect((await verify(await appleToken({ email_verified: true }), NONCE)).emailVerified).toBe(true);
  });

  it('drops an unverified or missing email', async () => {
    const verify = appleVerifier(BUNDLE, jwks);
    expect(await verify(await appleToken({ email_verified: 'false' }), NONCE)).toEqual({
      subject: 'apple#000123.abcdef.0456',
      emailVerified: false,
    });
    expect(await verify(await appleToken({ email: undefined, email_verified: undefined }), NONCE)).toEqual({
      subject: 'apple#000123.abcdef.0456',
      emailVerified: false,
    });
  });

  it('refuses a wrong audience, a wrong issuer, an expired token, a bad signature and an unknown key', async () => {
    const verify = appleVerifier(BUNDLE, jwks);
    const refused = async (token: string | Promise<string>, nonce = NONCE) =>
      expect(verify(await token, nonce)).rejects.toBeInstanceOf(InvalidIdToken);
    await refused(appleToken({}, { aud: 'com.example.other' }));
    await refused(appleToken({}, { iss: 'https://accounts.google.com' }));
    await refused(appleToken({}, { exp: Math.floor(Date.now() / 1000) - 3600 }));
    await refused(appleToken({}, { key: otherKey }));
    await refused(appleToken({}, { kid: 'unknown' }));
    // A signature from Apple's key, on a payload changed afterwards.
    const [h, , sig] = (await appleToken()).split('.');
    const forged = Buffer.from(JSON.stringify({ ...decodeJwt(await appleToken()), sub: 'someone-else' })).toString('base64url');
    await refused(`${h}.${forged}.${sig}`);
    await refused('not-a-jwt');
    await refused(`${'a'.repeat(5000)}.b.c`);
    const none = `${Buffer.from('{"alg":"none"}').toString('base64url')}.${Buffer.from(JSON.stringify({ iss: 'https://appleid.apple.com', aud: BUNDLE, sub: '1', exp: 9999999999, iat: 1, nonce: sha256Hex(NONCE) })).toString('base64url')}.`;
    await refused(none);
  });

  it('refuses a nonce mismatch, or a token without a nonce', async () => {
    const verify = appleVerifier(BUNDLE, jwks);
    await expect(verify(await appleToken(), 'another-nonce-from-elsewhere')).rejects.toBeInstanceOf(InvalidIdToken);
    // The raw nonce itself in the token (not its hash) doesn't do.
    await expect(verify(await appleToken({ nonce: NONCE }), NONCE)).rejects.toBeInstanceOf(InvalidIdToken);
    await expect(verify(await appleToken({ nonce: undefined }), NONCE)).rejects.toBeInstanceOf(InvalidIdToken);
    await expect(verify(await appleToken(), '')).rejects.toBeInstanceOf(InvalidIdToken);
  });

  it('refuses everything without a bundle ID', async () => {
    await expect(appleVerifier('', jwks)(await appleToken(), NONCE)).rejects.toBeInstanceOf(InvalidIdToken);
  });
});

describe('POST /api/session with Apple', () => {
  let store: FakeStore;
  let kept: Array<[string, string]>;
  const make = (apple = true) =>
    new Auth({
      store: store.asStore(),
      verify: async () => {
        throw new InvalidIdToken('no Google here');
      },
      ...(apple
        ? {
            apple: {
              verify: appleVerifier(BUNDLE, jwks),
              keepRefreshToken: async (subject: string, code: string) => {
                kept.push([subject, code]);
              },
            },
          }
        : {}),
      config: { devMode: false, isAdmin: async () => false },
      clock: () => new Date(),
    });
  const status = async (p: Promise<unknown>) => ((await p.then(() => undefined, (e) => e)) as ApiError)?.status;

  beforeEach(() => {
    store = new FakeStore();
    kept = [];
  });

  it('starts a session for apple#<sub>, with the name the app sends, and keeps the code\'s token', async () => {
    const { token } = await make().signIn({ appleIdToken: await appleToken(), nonce: NONCE, authorizationCode: 'c0de.made-up', name: '  Pat   Quill ' });
    const caller = await make().caller({ authorization: `Bearer ${token}` });
    expect(caller.subject).toBe('apple#000123.abcdef.0456');
    expect(caller.name).toBe('Pat Quill');
    expect(caller.email).toBe('quill@privaterelay.appleid.com');
    expect(kept).toEqual([['apple#000123.abcdef.0456', 'c0de.made-up']]);
  });

  it('needs no name or code (later sign-ins)', async () => {
    const { token } = await make().signIn({ appleIdToken: await appleToken(), nonce: NONCE });
    expect((await make().caller({ authorization: `Bearer ${token}` })).name).toBeUndefined();
    expect(kept).toEqual([]);
  });

  it('401s a bad token or a nonce mismatch, 400s a missing nonce', async () => {
    expect(await status(make().signIn({ appleIdToken: await appleToken({}, { aud: 'com.example.other' }), nonce: NONCE }))).toBe(401);
    expect(await status(make().signIn({ appleIdToken: await appleToken(), nonce: 'a-different-nonce-entirely' }))).toBe(401);
    expect(await status(make().signIn({ appleIdToken: await appleToken() }))).toBe(400);
    expect(await status(make().signIn({ appleIdToken: await appleToken(), nonce: 'short' }))).toBe(400);
    // No Apple sign-in configured: refused.
    expect(await status(make(false).signIn({ appleIdToken: await appleToken(), nonce: NONCE }))).toBe(401);
    expect(store.sessions.size).toBe(0);
    expect(kept).toEqual([]);
  });

  it('never takes an Apple token as a Google one', async () => {
    expect(await status(make().signIn({ idToken: await appleToken(), nonce: NONCE }))).toBe(401);
  });
});

describe('AppleTokens', () => {
  const pem = generateKeyPairSync('ec', { namedCurve: 'P-256' }).privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();
  const config = { clientId: BUNDLE, teamId: 'TEAM123456', keyId: 'KEY1234567', privateKey: pem };
  let store: FakeStore;
  let calls: Array<{ url: string; form: URLSearchParams }>;
  let answer: (url: string) => Response;
  const http = (async (url: string, init?: RequestInit) => {
    calls.push({ url, form: new URLSearchParams(init!.body as URLSearchParams) });
    return answer(url);
  }) as typeof fetch;
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
  const appleIdTokenFor = (sub: string) =>
    `${Buffer.from('{"alg":"RS256"}').toString('base64url')}.${Buffer.from(JSON.stringify({ sub })).toString('base64url')}.sig`;
  const SUBJECT = 'apple#000123.abcdef.0456';

  beforeEach(() => {
    store = new FakeStore();
    calls = [];
    answer = () => json({ refresh_token: 'r3fresh-made-up', id_token: appleIdTokenFor('000123.abcdef.0456') });
    vi.spyOn(console, 'error').mockImplementation(() => {});
  });

  it('signs a short-lived ES256 client secret for the app', async () => {
    const tokens = new AppleTokens(config, store.asStore(), http);
    expect(tokens.configured).toBe(true);
    const secret = await tokens.clientSecret();
    expect(decodeProtectedHeader(secret)).toEqual({ alg: 'ES256', kid: 'KEY1234567' });
    const { createPublicKey } = await import('node:crypto');
    const { payload } = await jwtVerify(secret, createPublicKey(pem), { issuer: 'TEAM123456', audience: 'https://appleid.apple.com', subject: BUNDLE });
    expect(payload.exp! - payload.iat!).toBeLessThanOrEqual(300);
  });

  it('takes the key as its base64 body too', () => {
    const body = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
    expect(pkcs8Pem(body)).toBe(pkcs8Pem(pem));
    expect(new AppleTokens({ ...config, privateKey: body }, store.asStore(), http).configured).toBe(true);
    expect(pkcs8Pem('not a key!')).toBeUndefined();
  });

  it('trades the code for a refresh token and keeps it with the account', async () => {
    await new AppleTokens(config, store.asStore(), http).keepRefreshToken(SUBJECT, 'c0de');
    expect(calls).toHaveLength(1);
    expect(calls[0]!.url).toBe(APPLE_TOKEN_URL);
    expect(calls[0]!.form.get('client_id')).toBe(BUNDLE);
    expect(calls[0]!.form.get('code')).toBe('c0de');
    expect(calls[0]!.form.get('grant_type')).toBe('authorization_code');
    expect(calls[0]!.form.get('client_secret')).toMatch(/^ey/);
    expect(store.appleTokens.get(SUBJECT)).toBe('r3fresh-made-up');
  });

  it('keeps no token for a code of another account, or a refused code, and never logs one', async () => {
    const log = vi.mocked(console.error);
    answer = () => json({ refresh_token: 'r3fresh-made-up', id_token: appleIdTokenFor('someone-else') });
    await new AppleTokens(config, store.asStore(), http).keepRefreshToken(SUBJECT, 'c0de');
    answer = () => json({ error: 'invalid_grant' }, 400);
    await new AppleTokens(config, store.asStore(), http).keepRefreshToken(SUBJECT, 'c0de');
    expect(store.appleTokens.size).toBe(0);
    const logged = log.mock.calls.flat().join('\n');
    expect(logged).toContain('invalid_grant');
    expect(logged).not.toContain('r3fresh');
    expect(logged).not.toContain('c0de');
  });

  it('without a key: keeps nothing, calls no one, and warns', async () => {
    const tokens = new AppleTokens({ ...config, privateKey: '' }, store.asStore(), http);
    expect(tokens.configured).toBe(false);
    await tokens.keepRefreshToken(SUBJECT, 'c0de');
    store.subjects.set(SUBJECT, 'climber-1');
    expect(await tokens.revoke('climber-1')).toBe('skipped');
    expect(calls).toEqual([]);
    expect(vi.mocked(console.error)).toHaveBeenCalled();
  });

  it('revokes an Apple account\'s refresh token, then forgets it', async () => {
    store.subjects.set(SUBJECT, 'climber-1');
    store.appleTokens.set(SUBJECT, 'r3fresh-made-up');
    answer = () => new Response('', { status: 200 });
    const tokens = new AppleTokens(config, store.asStore(), http);
    expect(await tokens.revoke('climber-1')).toBe('revoked');
    expect(calls[0]!.url).toBe(APPLE_REVOKE_URL);
    expect(calls[0]!.form.get('token')).toBe('r3fresh-made-up');
    expect(calls[0]!.form.get('token_type_hint')).toBe('refresh_token');
    expect(calls[0]!.form.get('client_id')).toBe(BUNDLE);
    expect(store.appleTokens.size).toBe(0);
  });

  it('has nothing to revoke for Google accounts or unknown climbers; a refused revocation is reported, not thrown', async () => {
    const tokens = new AppleTokens(config, store.asStore(), http);
    store.subjects.set('https://accounts.google.com#7', 'climber-g');
    expect(await tokens.revoke('climber-g')).toBe('none');
    expect(await tokens.revoke('nobody')).toBe('none');
    expect(calls).toEqual([]);
    store.subjects.set(SUBJECT, 'climber-1');
    store.appleTokens.set(SUBJECT, 'r3fresh-made-up');
    answer = () => json({ error: 'invalid_client' }, 400);
    expect(await tokens.revoke('climber-1')).toBe('failed');
    expect(store.appleTokens.size).toBe(0);
    expect(vi.mocked(console.error).mock.calls.flat().join('\n')).not.toContain('r3fresh');
  });
});
