import { describe, expect, it } from 'vitest';
import { caller, parseAdminEmails, subjectHash } from '../src/auth.js';
import { Router } from '../src/router.js';

const admins = parseAdminEmails(' Admin@Example.com, ,other@example.com');

describe('caller', () => {
  it('reads the verified token claims', () => {
    const c = caller({ iss: 'https://accounts.google.com', sub: '123', email: 'admin@example.com', email_verified: 'true' }, {}, { devMode: false, adminEmails: admins });
    expect(c).toEqual({ subject: 'https://accounts.google.com#123', email: 'admin@example.com', admin: true });
  });

  it('is never admin with an unverified email', () => {
    const c = caller({ iss: 'i', sub: 's', email: 'admin@example.com', email_verified: false }, {}, { devMode: false, adminEmails: admins });
    expect(c.admin).toBe(false);
    expect(c.email).toBeUndefined();
  });

  it('ignores the dev header outside dev mode', () => {
    expect(() => caller(undefined, { 'x-grigri-dev-user': 'admin@example.com' }, { devMode: false, adminEmails: admins })).toThrow(/sign in/);
  });

  it('takes the dev header in dev mode', () => {
    expect(caller(undefined, { 'x-grigri-dev-user': 'Admin@Example.com' }, { devMode: true, adminEmails: admins })).toEqual({
      subject: 'dev#admin@example.com',
      email: 'admin@example.com',
      admin: true,
    });
    expect(() => caller(undefined, { 'x-grigri-dev-user': 'not an email' }, { devMode: true, adminEmails: admins })).toThrow(/X-Grigri-Dev-User/);
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
