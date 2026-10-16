// The API answers only through the site's CloudFront (specs/origin-check.md):
// CloudFront adds a secret header to every request it sends here, and a
// request without it (straight to the execute-api host) is refused. The
// secret never leaves AWS; no client holds it.
import { createHash, timingSafeEqual } from 'node:crypto';

export const ORIGIN_HEADER = 'x-grigri-origin-verify';

/** What a request that skipped the site gets. */
export const REFUSED = 'use the site';

/**
 * Whether a request came through the site: its [ORIGIN_HEADER] is
 * [secret]. No secret (local, or before the site sends it): every request.
 * [headers] are lowercased.
 */
export function originCheck(secret: string): (headers: Record<string, string | undefined>) => boolean {
  if (!secret.trim()) return () => true;
  const want = digest(secret);
  return (headers) => {
    const got = headers[ORIGIN_HEADER];
    // In constant time (equal-length digests): a wrong guess says nothing
    // of how close it was.
    return typeof got === 'string' && timingSafeEqual(digest(got), want);
  };
}

function digest(s: string): Buffer {
  return createHash('sha256').update(s, 'utf8').digest();
}
