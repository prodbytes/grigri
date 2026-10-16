import { describe, expect, it, vi } from 'vitest';
import { rbacrAdminCheck, rbacrGrants, rbacrRoles } from '../src/rbacr.js';

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

describe('rbacr admin check', () => {
  it('asks rbacr about grigri\'s admin role with the root token', async () => {
    const fetch = vi.fn(async () => json(200, { allowed: true }));
    const isAdmin = rbacrAdminCheck({ url: 'https://rbacr.example.com/', token: 'rbacr_abc', fetch });
    expect(await isAdmin('Admin@Example.com')).toBe(true);
    const [url, init] = fetch.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe('https://rbacr.example.com/api/check');
    expect(init.method).toBe('POST');
    expect((init.headers as Record<string, string>).authorization).toBe('Bearer rbacr_abc');
    expect(JSON.parse(init.body as string)).toEqual({ email: 'admin@example.com', systemId: 'grigri', role: 'admin' });
  });

  it('caches answers for a minute, per email', async () => {
    let now = 0;
    const fetch = vi.fn(async () => json(200, { allowed: false }));
    const isAdmin = rbacrAdminCheck({ url: 'https://r', token: 't', fetch, clock: () => now });
    await isAdmin('a@example.com');
    await isAdmin('A@example.com');
    expect(fetch).toHaveBeenCalledTimes(1);
    await isAdmin('b@example.com');
    expect(fetch).toHaveBeenCalledTimes(2);
    now = 60_001;
    await isAdmin('a@example.com');
    expect(fetch).toHaveBeenCalledTimes(3);
  });

  it('fails closed, and never caches a failure', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    const fetch = vi.fn(async () => json(503, { error: 'down' }));
    const isAdmin = rbacrAdminCheck({ url: 'https://r', token: 't', fetch });
    expect(await isAdmin('a@example.com')).toBe(false);
    expect(await isAdmin('a@example.com')).toBe(false);
    expect(fetch).toHaveBeenCalledTimes(2);
    const throwing = rbacrAdminCheck({ url: 'https://r', token: 't', fetch: async () => { throw new Error('timeout'); } });
    expect(await throwing('a@example.com')).toBe(false);
    // A 200 without allowed: true isn't a yes.
    expect(await rbacrAdminCheck({ url: 'https://r', token: 't', fetch: async () => json(200, { allowed: 'yes' }) })('a@example.com')).toBe(false);
  });

  it('caches rbacr not knowing grigri (404) as no', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    const fetch = vi.fn(async () => json(404, { error: 'no such system' }));
    const isAdmin = rbacrAdminCheck({ url: 'https://r', token: 't', fetch });
    expect(await isAdmin('a@example.com')).toBe(false);
    expect(await isAdmin('a@example.com')).toBe(false);
    expect(fetch).toHaveBeenCalledTimes(1);
  });

  it('without a token or URL nobody is an admin, and rbacr is never called', async () => {
    const fetch = vi.fn(async () => json(200, { allowed: true }));
    expect(await rbacrAdminCheck({ url: 'https://r', token: ' ', fetch })('a@example.com')).toBe(false);
    expect(await rbacrAdminCheck({ url: '', token: 't', fetch })('a@example.com')).toBe(false);
    expect(fetch).not.toHaveBeenCalled();
  });
});

describe('rbacr roles', () => {
  it('asks rbacr for my roles: grigri\'s and the global ones, sorted', async () => {
    const fetch = vi.fn(async () =>
      json(200, { email: 'a@example.com', globalRoles: ['root'], roles: { grigri: ['admin', 'member'], other: ['boss'] } }),
    );
    const roles = rbacrRoles({ url: 'https://rbacr.example.com/', token: 'rbacr_abc', fetch });
    expect(await roles('A@Example.com')).toEqual(['admin', 'member', 'root']);
    const [url, init] = fetch.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe('https://rbacr.example.com/api/roles');
    expect((init.headers as Record<string, string>).authorization).toBe('Bearer rbacr_abc');
    expect(JSON.parse(init.body as string)).toEqual({ email: 'a@example.com' });
  });

  it('caches for a minute; a failure is null and never cached', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    let now = 0;
    const ok = vi.fn(async () => json(200, { globalRoles: [], roles: {} }));
    const roles = rbacrRoles({ url: 'https://r', token: 't', fetch: ok, clock: () => now });
    expect(await roles('a@example.com')).toEqual([]);
    await roles('a@example.com');
    expect(ok).toHaveBeenCalledTimes(1);
    now = 60_001;
    await roles('a@example.com');
    expect(ok).toHaveBeenCalledTimes(2);
    const down = vi.fn(async () => json(503, {}));
    const failing = rbacrRoles({ url: 'https://r', token: 't', fetch: down });
    expect(await failing('a@example.com')).toBeNull();
    expect(await failing('a@example.com')).toBeNull();
    expect(down).toHaveBeenCalledTimes(2);
  });

  it('without a token or URL it can\'t say, and rbacr is never called', async () => {
    const fetch = vi.fn(async () => json(200, {}));
    expect(await rbacrRoles({ url: 'https://r', token: '', fetch })('a@example.com')).toBeNull();
    expect(await rbacrRoles({ url: '', token: 't', fetch })('a@example.com')).toBeNull();
    expect(fetch).not.toHaveBeenCalled();
  });
});

describe('rbacr grants (Premium, from the Stripe webhook)', () => {
  const asked: { method: string; url: string; auth: string; body: unknown }[] = [];
  const answering = (status: number) =>
    (async (url: string, init: RequestInit) => {
      asked.push({ method: String(init.method), url: String(url), auth: String((init.headers as Record<string, string>).authorization), body: JSON.parse(String(init.body)) });
      return new Response(status === 204 ? null : '{}', { status });
    }) as typeof fetch;

  it('grants with an end, and revokes, in the grigri system with the root token', async () => {
    asked.length = 0;
    const grants = rbacrGrants({ url: 'https://rbacr.example.com/', token: 'rbacr_made_up', fetch: answering(201) })!;
    await grants.grant('Ada@Example.com', 'premium', '2030-06-03T10:00:00.000Z');
    expect(asked[0]).toEqual({
      method: 'POST',
      url: 'https://rbacr.example.com/api/systems/grigri/grants',
      auth: 'Bearer rbacr_made_up',
      body: { role: 'premium', grantee: 'ada@example.com', endsAt: '2030-06-03T10:00:00.000Z' },
    });
    const revoking = rbacrGrants({ url: 'https://rbacr.example.com', token: 'rbacr_made_up', fetch: answering(204) })!;
    await revoking.revoke('ada@example.com', 'premium');
    expect(asked[1]).toMatchObject({ method: 'DELETE', body: { role: 'premium', grantee: 'ada@example.com' } });
  });

  it('nothing to revoke is fine; other failures are errors; no token: none', async () => {
    await rbacrGrants({ url: 'https://r.example.com', token: 't', fetch: answering(404) })!.revoke('a@example.com', 'premium');
    await expect(rbacrGrants({ url: 'https://r.example.com', token: 't', fetch: answering(404) })!.grant('a@example.com', 'premium')).rejects.toThrow(/404/);
    await expect(rbacrGrants({ url: 'https://r.example.com', token: 't', fetch: answering(500) })!.revoke('a@example.com', 'premium')).rejects.toThrow(/500/);
    expect(rbacrGrants({ url: 'https://r.example.com', token: '' })).toBeNull();
  });
});
