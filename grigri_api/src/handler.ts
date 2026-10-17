// The Lambda entry point: HTTP API (payload 2.0) events to the router, and
// one direct-invoke event, {"grigriSeed": true}, that loads the made-up
// test data (RC and local only: refused in prod; see seed/seed.ts). The
// demo showcase (seed/showcase.ts) is on every stage, refreshed by the
// deck itself. The
// HTTP API can't send that event: its events always carry requestContext.
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DeleteObjectCommand, DeleteObjectTaggingCommand, GetObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import { createPresignedPost } from '@aws-sdk/s3-presigned-post';
import type { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { Api, type GrigriPics, type Photos } from './api.js';
import type { PicCatalog } from './domain/model.js';
import { Auth, type AuthConfig } from './auth.js';
import { REFUSED, originCheck } from './origin.js';
import { rbacrAdminCheck, rbacrGrants, rbacrRoles } from './rbacr.js';
import { ApiError } from './domain/errors.js';
import { APPLE_CALLBACK, AppleTokens, DEFAULT_APPLE_BUNDLE_ID, DEFAULT_APPLE_SERVICE_ID, appleCallbackIntent, appleVerifier } from './apple.js';
import { googleVerifier, parseClientIds } from './google.js';
import { iotDataPublisher, mqttWebSocketPublisher } from './publishers.js';
import { Realtime } from './realtime.js';
import { aityxScorer } from './match/aityx.js';
import { stripeBilling } from './stripe.js';
import { Store } from './store/store.js';
import { assertSeedable, seed, seedShowcase, showcaseIsStale } from '../seed/seed.js';

const MAX_BODY = 64 * 1024;
/** Stripe's events are bigger than the app's requests (a subscription with its items). */
const MAX_WEBHOOK_BODY = 512 * 1024;
const STRIPE_WEBHOOK = '/api/stripe/webhook';

const env = process.env;
const stage = env.STAGE ?? 'local';
const table = env.TABLE_NAME ?? '';

// Floci (the local stack) sets AWS_ENDPOINT_URL; its S3 is path-style.
const local = Boolean(env.AWS_ENDPOINT_URL);
const doc = DynamoDBDocumentClient.from(new DynamoDBClient({}), {
  marshallOptions: { removeUndefinedValues: true },
});
const s3 = new S3Client({ forcePathStyle: local });
const store = new Store(doc, table);
const bucket = env.PHOTOS_BUCKET ?? '';

// Every upload is tagged pending; the bucket's lifecycle rule (site.yaml,
// and 05-api.sh locally) expires pending photos after a day, so photos
// never saved to a profile, and chat media never sent, go away. PUT
// /api/me and POST /api/plans/{id}/messages clear the tag.
const PENDING_TAGGING = '<Tagging><TagSet><Tag><Key>grigri-pending</Key><Value>true</Value></Tag></TagSet></Tagging>';

const photos: Photos = {
  async presign(key, contentType, maxBytes) {
    const { url, fields } = await createPresignedPost(s3, {
      Bucket: bucket,
      Key: `photos/${key}`,
      Conditions: [
        ['content-length-range', 1, maxBytes],
        ['eq', '$Content-Type', contentType],
        ['eq', '$Cache-Control', 'public, max-age=31536000, immutable'],
        ['eq', '$tagging', PENDING_TAGGING],
      ],
      // Keys are never reused, so the photo can be cached for good.
      Fields: { 'Content-Type': contentType, 'Cache-Control': 'public, max-age=31536000, immutable', tagging: PENDING_TAGGING },
      // 15 minutes to start: room for a 50 MB video on a slow phone line.
      Expires: 900,
    });
    // Locally the browser can't reach the endpoint the function uses.
    return { url: env.PHOTOS_UPLOAD_URL || url, fields };
  },
  async keep(key) {
    try {
      await s3.send(new DeleteObjectTaggingCommand({ Bucket: bucket, Key: `photos/${key}` }));
      return true;
    } catch (e) {
      // Never uploaded, or expired. Without s3:ListBucket (not granted),
      // S3 may answer a missing key with 403 rather than 404.
      const status = (e as { $metadata?: { httpStatusCode?: number } }).$metadata?.httpStatusCode;
      if (status === 404 || status === 403) return false;
      throw e;
    }
  },
  async remove(keys) {
    // A few at a time (a profile: a photo and 6 gear photos; deleting an
    // account: up to 20 per call); S3 doesn't bill DELETEs.
    await Promise.all(keys.map((k) => s3.send(new DeleteObjectCommand({ Bucket: bucket, Key: `photos/${k}` }))));
  },
};

// GriGri Pics: the catalog the loader (pics/load.mjs) makes from the
// photos' S3 annotations, in its own bucket (never people's data). One
// GET, kept while the function stays warm (an hour at most), so a lookup
// costs nothing after the first. None yet (or no bucket): no GriGri Pics.
const picsBucket = env.PICS_BUCKET ?? '';
const CATALOG_TTL_MS = 60 * 60 * 1000;
const EMPTY_CATALOG: PicCatalog = { generatedAt: '', crags: [] };
let catalogCache: { at: number; catalog: Promise<PicCatalog> } | undefined;
const pics: GrigriPics = {
  catalog() {
    if (!picsBucket) return Promise.resolve(EMPTY_CATALOG);
    if (catalogCache && Date.now() - catalogCache.at < CATALOG_TTL_MS) return catalogCache.catalog;
    const catalog = readCatalog();
    catalogCache = { at: Date.now(), catalog };
    // A failed read isn't kept: the next lookup tries again.
    catalog.catch(() => {
      if (catalogCache?.catalog === catalog) catalogCache = undefined;
    });
    return catalog;
  },
};

async function readCatalog(): Promise<PicCatalog> {
  try {
    const out = await s3.send(new GetObjectCommand({ Bucket: picsBucket, Key: 'pics/catalog.json' }));
    const parsed = JSON.parse(await out.Body!.transformToString()) as PicCatalog;
    return Array.isArray(parsed.crags) ? parsed : EMPTY_CATALOG;
  } catch (e) {
    const status = (e as { $metadata?: { httpStatusCode?: number } }).$metadata?.httpStatusCode;
    // Not loaded yet (403 without s3:ListBucket): none, kept like a catalog.
    if (status === 404 || status === 403) return EMPTY_CATALOG;
    throw e;
  }
}

// rbacr, with a root's API token: admins, and my roles on my profile.
const rbacr = { url: env.RBACR_URL ?? '', token: env.RBACR_TOKEN ?? '' };
const authConfig: AuthConfig = {
  // The template refuses DevMode unless Stage is local; checked here too.
  devMode: env.DEV_MODE === 'true' && stage === 'local',
  // Admins are whoever rbacr says holds grigri's admin role.
  isAdmin: rbacrAdminCheck(rbacr),
};
// Sign in with Apple: tokens for the iOS app's bundle ID (Apple's sheet)
// or the Services ID (Apple's web flow, on the web and Android); with a
// Sign in with Apple key, refresh tokens are kept to revoke on account
// deletion (the key never leaves the function); no key: not kept.
const appleClientIds = [env.APPLE_BUNDLE_ID || DEFAULT_APPLE_BUNDLE_ID, env.APPLE_SERVICE_ID || DEFAULT_APPLE_SERVICE_ID];
const appleTokens = new AppleTokens(
  { clientIds: appleClientIds, teamId: env.APPLE_TEAM_ID ?? '', keyId: env.APPLE_KEY_ID ?? '', privateKey: env.APPLE_PRIVATE_KEY ?? '' },
  store,
);
const auth = new Auth({
  store,
  verify: googleVerifier(env.GOOGLE_WEB_CLIENT_ID ?? '', undefined, parseClientIds(env.GOOGLE_IOS_CLIENT_IDS)),
  apple: { verify: appleVerifier(appleClientIds), keepRefreshToken: (subject, code, clientId) => appleTokens.keepRefreshToken(subject, code, clientId) },
  config: authConfig,
});
// Live updates: hints to IoT Core in AWS; locally, over MQTT to Floci's
// broker (its HTTP Publish doesn't reach subscribers). IOT_ENDPOINT is
// where the app connects; empty: live updates off.
const iotEndpoint = env.IOT_ENDPOINT ?? '';
const publisher = !iotEndpoint
  ? null
  : local
    ? mqttWebSocketPublisher(`${env.AWS_ENDPOINT_URL!.replace(/^http/, 'ws').replace(/\/+$/, '')}/mqtt`)
    : iotDataPublisher(iotEndpoint);
const realtime = new Realtime({ stage, endpoint: iotEndpoint, authorizer: env.IOT_AUTHORIZER ?? '' }, publisher);
// The demo showcase, on every stage: re-dated when over 12 h old (one read
// per deck; a dozen writes twice a day).
const showcase = async (now: Date) => {
  if (await showcaseIsStale(store, now)) await seedShowcase(store, now);
};
// Match scores from aityx on admins' decks (the key never leaves the
// function); no key: none.
const matchScorer = aityxScorer({ url: env.AITYX_URL ?? '', key: env.AITYX_API_KEY ?? '' }) ?? undefined;
// Premium through Stripe (the keys never leave the function); no keys: no Premium.
const billing = stripeBilling({
  secretKey: env.STRIPE_SECRET_KEY ?? '',
  webhookSecret: env.STRIPE_WEBHOOK_SECRET ?? '',
  siteUrl: env.SITE_URL ?? '',
}) ?? undefined;
const api = new Api({
  store,
  photos,
  pics,
  auth,
  realtime,
  roles: rbacrRoles(rbacr),
  // Premium's role in rbacr, granted and revoked by the Stripe webhook.
  grants: rbacrGrants(rbacr) ?? undefined,
  matchScorer,
  billing,
  appleTokens,
  showcase,
  config: { stage, version: env.VERSION ?? 'dev', roleSuffix: env.ROLE_SUFFIX ?? '' },
});

// Only through the site's CloudFront (origin.ts); no secret: open (local).
const throughSite = originCheck(env.ORIGIN_SECRET ?? '');

type Event = APIGatewayProxyEventV2 | { grigriSeed?: boolean };

export async function handler(event: Event): Promise<APIGatewayProxyResultV2 | Record<string, unknown>> {
  if (!('requestContext' in event)) {
    if ((event as { grigriSeed?: boolean }).grigriSeed === true) {
      assertSeedable(stage, table);
      return { seeded: await seed(store, new Date()) };
    }
    return { error: 'unknown event' };
  }
  return http(event);
}

async function http(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const method = event.requestContext.http.method;
  const path = event.rawPath;
  try {
    const headers = lowercase(event.headers ?? {});
    // First: a request that skipped the site gets nothing else.
    if (!throughSite(headers)) throw new ApiError(403, REFUSED);
    // Stripe's webhook: verified against the raw body, so before any parsing.
    if (method === 'POST' && path === STRIPE_WEBHOOK) {
      const raw = event.body ? (event.isBase64Encoded ? Buffer.from(event.body, 'base64').toString('utf8') : event.body) : '';
      if (raw.length > MAX_WEBHOOK_BODY) throw new ApiError(413, 'body too large');
      return json(200, await api.stripeWebhook(raw, headers['stripe-signature']));
    }
    // Sign in with Apple's web flow on Android: Apple's form post (never
    // logged: it carries the identity token) goes back to the app.
    if (method === 'POST' && path === APPLE_CALLBACK) {
      const raw = event.body ? (event.isBase64Encoded ? Buffer.from(event.body, 'base64').toString('utf8') : event.body) : '';
      if (raw.length > MAX_BODY) throw new ApiError(413, 'body too large');
      if (!(headers['content-type'] ?? '').startsWith('application/x-www-form-urlencoded')) throw new ApiError(415, 'send a form');
      return {
        statusCode: 307,
        headers: { location: appleCallbackIntent(raw), 'cache-control': 'no-store', 'referrer-policy': 'no-referrer' },
        body: '',
      };
    }
    let body: unknown;
    if (event.body) {
      const raw = event.isBase64Encoded ? Buffer.from(event.body, 'base64').toString('utf8') : event.body;
      if (raw.length > MAX_BODY) throw new ApiError(413, 'body too large');
      const type = headers['content-type'] ?? '';
      if (!type.startsWith('application/json')) throw new ApiError(415, 'send application/json');
      try {
        body = JSON.parse(raw);
      } catch {
        throw new ApiError(400, 'body is not valid JSON');
      }
    }
    // The session lookup (one read) only for routes that need a caller.
    const who = api.access(method, path) === 'public' ? null : await auth.caller(headers);
    const result = await api.handle(method, path, {
      caller: who,
      query: event.queryStringParameters ?? {},
      body,
    });
    return json(200, result);
  } catch (e) {
    if (e instanceof ApiError) return json(e.status, { error: e.message });
    // Unexpected: logged (no request bodies, no tokens), and a plain 500.
    console.error(JSON.stringify({ level: 'error', method, path, error: String(e), stack: (e as Error)?.stack }));
    return json(500, { error: 'internal error' });
  }
}

function json(statusCode: number, body: unknown): APIGatewayProxyResultV2 {
  return {
    statusCode,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
      'x-content-type-options': 'nosniff',
    },
    body: JSON.stringify(body),
  };
}

function lowercase(headers: Record<string, string | undefined>): Record<string, string | undefined> {
  return Object.fromEntries(Object.entries(headers).map(([k, v]) => [k.toLowerCase(), v]));
}
