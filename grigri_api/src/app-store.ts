// Apple's in-app purchase, for Premium on iOS (specs/premium.md, App Store
// guideline 3.1.1). The app buys an auto-renewable subscription through
// StoreKit 2 and sends the signed transaction (a JWS) to the API; the App
// Store sends App Store Server Notifications V2 (a JWS too) as it renews,
// lapses or is refunded. Both are verified offline, the way Apple's own
// app-store-server-library does it, with node:crypto only (no App Store
// Server API call, no key, no new dependency):
//
// - the header's alg is ES256 and its x5c holds three certificates;
// - the intermediate is issued and signed by a trusted root (Apple Root
//   CA - G3 only, apple-root.ts), the leaf by the intermediate;
// - the leaf carries Apple's OID 1.2.840.113635.100.6.11.1 and the
//   intermediate 1.2.840.113635.100.6.2.1;
// - all three certificates were valid when Apple signed it (its
//   signedDate, as Apple's library does offline);
// - the JWS's ES256 signature verifies with the leaf's P-256 key.
import { X509Certificate, createHash, verify as verifySignature } from 'node:crypto';
import { APPLE_ROOT_CA_G3 } from './apple-root.js';
import type { PremiumPlan, Subscription } from './premium.js';

/** Grigri's bundle id: only its transactions count. */
export const APPLE_BUNDLE_ID = 'com.nu01.grigri';

/** The two auto-renewable subscriptions (one group, "Grigri Premium"). */
export const APPLE_PRODUCTS: Readonly<Record<string, PremiumPlan>> = {
  'com.nu01.grigri.premium.monthly': 'monthly',
  'com.nu01.grigri.premium.yearly': 'yearly',
};

/** Apple's marker OIDs: the App Store receipt-signing leaf, and the WWDR intermediate. */
export const LEAF_OID = '1.2.840.113635.100.6.11.1';
export const INTERMEDIATE_OID = '1.2.840.113635.100.6.2.1';

/** Larger than any JWS Apple sends (a notification nests two JWS, each with three certificates). */
const MAX_JWS = 48 * 1024;

export class BadAppleSignature extends Error {}

/** Verifies an App Store JWS and answers its payload; throws BadAppleSignature. */
export type AppStoreVerify = (jws: unknown) => Record<string, unknown>;

/**
 * An App Store JWS verifier trusting `roots`: Apple Root CA - G3 alone in
 * production (handler.ts passes nothing); tests pass a made-up root.
 */
export function appStoreVerifier(roots: readonly X509Certificate[] = [APPLE_ROOT_CA_G3]): AppStoreVerify {
  if (roots.length === 0) throw new Error('no trusted roots');
  return (jws) => {
    if (typeof jws !== 'string' || jws.length > MAX_JWS) throw new BadAppleSignature('not a JWS');
    const parts = jws.split('.');
    if (parts.length !== 3 || !parts.every((p) => /^[A-Za-z0-9_-]+$/.test(p))) throw new BadAppleSignature('not a JWS');
    const [h, p, s] = parts as [string, string, string];
    const header = jsonPart(h);
    const payload = jsonPart(p);
    // Only ES256: no "none", no HMAC with a public key, no other curve.
    if (header.alg !== 'ES256') throw new BadAppleSignature('alg must be ES256');
    if (header.crit !== undefined) throw new BadAppleSignature('unexpected crit');
    const x5c = header.x5c;
    if (!Array.isArray(x5c) || x5c.length !== 3 || !x5c.every((c) => typeof c === 'string')) {
      throw new BadAppleSignature('x5c must hold three certificates');
    }
    let leaf: X509Certificate;
    let intermediate: X509Certificate;
    try {
      leaf = new X509Certificate(Buffer.from(x5c[0] as string, 'base64'));
      intermediate = new X509Certificate(Buffer.from(x5c[1] as string, 'base64'));
    } catch {
      throw new BadAppleSignature('bad certificate');
    }
    // x5c[2] is the root the signer names; only ours is trusted, so the
    // intermediate must chain to it whatever x5c[2] says.
    const root = roots.find((r) => intermediate.checkIssued(r) && intermediate.verify(r.publicKey));
    if (!root) throw new BadAppleSignature('not issued by a trusted root');
    if (!intermediate.ca) throw new BadAppleSignature('intermediate is not a CA');
    if (!leaf.checkIssued(intermediate) || !leaf.verify(intermediate.publicKey)) throw new BadAppleSignature('leaf not issued by the intermediate');
    if (!extensionOids(leaf).has(LEAF_OID)) throw new BadAppleSignature("leaf lacks Apple's OID");
    if (!extensionOids(intermediate).has(INTERMEDIATE_OID)) throw new BadAppleSignature("intermediate lacks Apple's OID");
    const signedDate = payload.signedDate;
    if (typeof signedDate !== 'number' || !Number.isFinite(signedDate)) throw new BadAppleSignature('no signedDate');
    for (const cert of [leaf, intermediate, root]) {
      if (!(Date.parse(cert.validFrom) <= signedDate && signedDate <= Date.parse(cert.validTo))) {
        throw new BadAppleSignature('certificate not valid when signed');
      }
    }
    const key = leaf.publicKey;
    if (key.asymmetricKeyType !== 'ec' || key.asymmetricKeyDetails?.namedCurve !== 'prime256v1') {
      throw new BadAppleSignature('leaf key is not P-256');
    }
    const signature = Buffer.from(s, 'base64url');
    if (signature.length !== 64) throw new BadAppleSignature('bad signature');
    const ok = verifySignature('sha256', Buffer.from(`${h}.${p}`, 'ascii'), { key, dsaEncoding: 'ieee-p1363' }, signature);
    if (!ok) throw new BadAppleSignature('signature mismatch');
    return payload;
  };
}

function jsonPart(part: string): Record<string, unknown> {
  let parsed: unknown;
  try {
    parsed = JSON.parse(Buffer.from(part, 'base64url').toString('utf8'));
  } catch {
    throw new BadAppleSignature('not a JWS');
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new BadAppleSignature('not a JWS');
  return parsed as Record<string, unknown>;
}

// --- DER: a certificate's extension OIDs ------------------------------------

interface Tlv {
  tag: number;
  start: number;
  end: number;
}

function tlv(der: Buffer, at: number, limit: number): Tlv {
  if (at + 2 > limit) throw new BadAppleSignature('bad certificate');
  const tag = der[at]!;
  let len = der[at + 1]!;
  let start = at + 2;
  if (len & 0x80) {
    const n = len & 0x7f;
    if (n === 0 || n > 4 || start + n > limit) throw new BadAppleSignature('bad certificate');
    len = 0;
    for (let i = 0; i < n; i++) len = len * 256 + der[start + i]!;
    start += n;
  }
  const end = start + len;
  if (end > limit) throw new BadAppleSignature('bad certificate');
  return { tag, start, end };
}

function children(der: Buffer, parent: Tlv): Tlv[] {
  const out: Tlv[] = [];
  for (let at = parent.start; at < parent.end; ) {
    const t = tlv(der, at, parent.end);
    out.push(t);
    at = t.end;
  }
  return out;
}

function oidString(bytes: Buffer): string {
  const arcs: number[] = [];
  let value = 0;
  for (const b of bytes) {
    value = value * 128 + (b & 0x7f);
    if (!(b & 0x80)) {
      if (arcs.length === 0) arcs.push(value < 80 ? Math.floor(value / 40) : 2, value < 80 ? value % 40 : value - 80);
      else arcs.push(value);
      value = 0;
    }
  }
  return arcs.join('.');
}

/** The OIDs of a certificate's X.509 v3 extensions. */
export function extensionOids(cert: X509Certificate): Set<string> {
  const der = cert.raw;
  const certificate = tlv(der, 0, der.length);
  const tbs = children(der, certificate)[0];
  if (!tbs) throw new BadAppleSignature('bad certificate');
  const oids = new Set<string>();
  // tbsCertificate's [3] EXPLICIT Extensions: SEQUENCE OF Extension.
  for (const field of children(der, tbs)) {
    if (field.tag !== 0xa3) continue;
    const list = children(der, field)[0];
    if (!list) continue;
    for (const ext of children(der, list)) {
      const id = children(der, ext)[0];
      if (id?.tag === 0x06) oids.add(oidString(der.subarray(id.start, id.end)));
    }
  }
  return oids;
}

// --- Transactions and notifications ------------------------------------------

/** A signed transaction's fields Grigri uses (JWSTransactionDecodedPayload). */
export interface AppleTransaction {
  transactionId: string;
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  plan: PremiumPlan;
  /** Milliseconds since the epoch. */
  expiresDate: number;
  revocationDate?: number;
  /** Lowercase UUID; absent when bought without one. */
  appAccountToken?: string;
  environment: 'Production' | 'Sandbox';
  signedDate: number;
}

/** A signed renewal info's fields Grigri uses (JWSRenewalInfoDecodedPayload). */
export interface AppleRenewal {
  originalTransactionId: string;
  /** 1: renews; 0: turned off (cancelled, ends at expiresDate). */
  autoRenewStatus?: number;
  gracePeriodExpiresDate?: number;
}

/** Thrown for a verified JWS that isn't a Grigri Premium subscription. */
export class NotGrigriPremium extends Error {}

const str = (v: unknown) => (typeof v === 'string' && v.length > 0 && v.length <= 200 ? v : undefined);
const num = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : undefined);

/** A verified transaction payload as Grigri's subscription transaction; throws NotGrigriPremium. */
export function appleTransaction(payload: Record<string, unknown>): AppleTransaction {
  const bundleId = str(payload.bundleId);
  if (bundleId !== APPLE_BUNDLE_ID) throw new NotGrigriPremium("not Grigri's app");
  const productId = str(payload.productId);
  const plan = productId ? APPLE_PRODUCTS[productId] : undefined;
  if (!productId || !plan) throw new NotGrigriPremium('not a Grigri Premium product');
  if (payload.type !== undefined && payload.type !== 'Auto-Renewable Subscription') throw new NotGrigriPremium('not a subscription');
  const environment = payload.environment;
  if (environment !== 'Production' && environment !== 'Sandbox') throw new NotGrigriPremium('unknown environment');
  const transactionId = str(payload.transactionId);
  const originalTransactionId = str(payload.originalTransactionId);
  const expiresDate = num(payload.expiresDate);
  const signedDate = num(payload.signedDate);
  if (!transactionId || !originalTransactionId || expiresDate === undefined || signedDate === undefined) {
    throw new NotGrigriPremium('incomplete transaction');
  }
  const token = str(payload.appAccountToken)?.toLowerCase();
  const revocationDate = num(payload.revocationDate);
  return {
    transactionId,
    originalTransactionId,
    bundleId,
    productId,
    plan,
    expiresDate,
    ...(revocationDate !== undefined ? { revocationDate } : {}),
    ...(token ? { appAccountToken: token } : {}),
    environment,
    signedDate,
  };
}

/** A verified renewal info payload. */
export function appleRenewal(payload: Record<string, unknown>): AppleRenewal {
  const originalTransactionId = str(payload.originalTransactionId);
  if (!originalTransactionId) throw new NotGrigriPremium('incomplete renewal info');
  const autoRenewStatus = num(payload.autoRenewStatus);
  const gracePeriodExpiresDate = num(payload.gracePeriodExpiresDate);
  return {
    originalTransactionId,
    ...(autoRenewStatus !== undefined ? { autoRenewStatus } : {}),
    ...(gracePeriodExpiresDate !== undefined ? { gracePeriodExpiresDate } : {}),
  };
}

/**
 * The appAccountToken the app buys with: a UUID derived from the climber
 * (SHA-256, formatted as an RFC 9562 version 8 UUID), so a transaction
 * names the Grigri account it was bought for. Not a secret: a transaction
 * bought with someone else's only ever makes them Premium.
 */
export function appleAccountToken(climberId: string): string {
  const b = createHash('sha256').update(`grigri apple account ${climberId}`).digest().subarray(0, 16);
  b[6] = (b[6]! & 0x0f) | 0x80;
  b[8] = (b[8]! & 0x3f) | 0x80;
  const hex = b.toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

/** What a notification's subscription state is, when Apple says (its data.status). */
export type AppleStatus = 1 | 2 | 3 | 4 | 5;

/**
 * The App Store's subscription as Grigri keeps it. Its status in Stripe's
 * words: refunded or revoked → canceled; Apple's billing retry or grace
 * period → past_due (paid until the grace period's end, if any);
 * expired → expired; otherwise active until expiresDate (expired once
 * past it).
 */
export function appleSubscription(
  climberId: string,
  tx: AppleTransaction,
  opts: { now: Date; signedDate: number; status?: AppleStatus; renewal?: AppleRenewal; forced?: 'expired' | 'canceled'; cancelAtPeriodEnd?: boolean; email?: string },
): Subscription {
  const { now } = opts;
  let periodEnd = tx.expiresDate;
  let status: string;
  if (opts.forced) status = opts.forced;
  else if (tx.revocationDate !== undefined || opts.status === 5) status = 'canceled';
  else if (opts.status === 2) status = 'expired';
  else if (opts.status === 3 || opts.status === 4) {
    status = 'past_due';
    if (opts.renewal?.gracePeriodExpiresDate) periodEnd = Math.max(periodEnd, opts.renewal.gracePeriodExpiresDate);
  } else status = tx.expiresDate > now.getTime() ? 'active' : 'expired';
  const cancelAtPeriodEnd = opts.renewal?.autoRenewStatus !== undefined ? opts.renewal.autoRenewStatus === 0 : (opts.cancelAtPeriodEnd ?? false);
  return {
    climberId,
    customerId: '',
    subscriptionId: tx.originalTransactionId,
    source: 'apple',
    status,
    plan: tx.plan,
    periodEnd: new Date(periodEnd).toISOString(),
    cancelAtPeriodEnd,
    updatedAt: now.toISOString(),
    ...(opts.email ? { email: opts.email } : {}),
    environment: tx.environment,
    appleSignedAt: new Date(opts.signedDate).toISOString(),
  };
}
