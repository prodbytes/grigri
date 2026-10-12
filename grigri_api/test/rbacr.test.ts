import { describe, expect, it, vi } from 'vitest';
import { rbacrAdminCheck } from '../src/rbacr.js';

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
