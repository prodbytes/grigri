import { describe, expect, it } from 'vitest';
import { ORIGIN_HEADER, originCheck } from '../src/origin.js';

describe('origin check', () => {
  const secret = 'made-up-origin-secret-0123456789abcdef';
  const check = originCheck(secret);

  it('takes a request through the site: the header is the secret', () => {
    expect(check({ [ORIGIN_HEADER]: secret })).toBe(true);
  });

  it('refuses one without it, or with another value', () => {
    expect(check({})).toBe(false);
    expect(check({ [ORIGIN_HEADER]: '' })).toBe(false);
    expect(check({ [ORIGIN_HEADER]: `${secret}x` })).toBe(false);
    expect(check({ [ORIGIN_HEADER]: secret.slice(0, -1) })).toBe(false);
    expect(check({ authorization: secret })).toBe(false);
  });

  it('without a secret (local, or before the site sends it) takes everything', () => {
    for (const none of ['', '  ']) {
      expect(originCheck(none)({})).toBe(true);
    }
  });
});
