// The Lambda entry point: HTTP API (payload 2.0) events to the router, and
// one direct-invoke event, {"grigriSeed": true}, that loads the made-up
// test data (RC and local only: refused in prod; see seed/seed.ts). The
// HTTP API can't send that event: its events always carry requestContext.
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DeleteObjectCommand, DeleteObjectTaggingCommand, S3Client } from '@aws-sdk/client-s3';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import { createPresignedPost } from '@aws-sdk/s3-presigned-post';
import type { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { Api, type Photos } from './api.js';
import { Auth, type AuthConfig } from './auth.js';
import { rbacrAdminCheck, rbacrRoles } from './rbacr.js';
import { ApiError } from './domain/errors.js';
import { googleVerifier, parseClientIds } from './google.js';
import { iotDataPublisher, mqttWebSocketPublisher } from './publishers.js';
import { Realtime } from './realtime.js';
import { Store } from './store/store.js';
import { assertSeedable, seed } from '../seed/seed.js';

const MAX_BODY = 64 * 1024;

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
    // At most 7 (a photo and 6 gear photos); S3 doesn't bill DELETEs.
    await Promise.all(keys.map((k) => s3.send(new DeleteObjectCommand({ Bucket: bucket, Key: `photos/${k}` }))));
  },
};

// rbacr, with a root's API token: admins, and my roles on my profile.
const rbacr = { url: env.RBACR_URL ?? '', token: env.RBACR_TOKEN ?? '' };
const authConfig: AuthConfig = {
  // The template refuses DevMode unless Stage is local; checked here too.
  devMode: env.DEV_MODE === 'true' && stage === 'local',
  // Admins are whoever rbacr says holds grigri's admin role.
  isAdmin: rbacrAdminCheck(rbacr),
};
const auth = new Auth({ store, verify: googleVerifier(env.GOOGLE_WEB_CLIENT_ID ?? '', undefined, parseClientIds(env.GOOGLE_IOS_CLIENT_IDS)), config: authConfig });
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
const api = new Api({ store, photos, auth, realtime, roles: rbacrRoles(rbacr), config: { stage, version: env.VERSION ?? 'dev' } });

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
