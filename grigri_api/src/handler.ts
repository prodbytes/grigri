// The Lambda entry point: HTTP API (payload 2.0) events to the router, and
// one direct-invoke event, {"grigriSeed": true}, that loads the made-up
// test data (RC and local only: refused in prod; see seed/seed.ts). The
// HTTP API can't send that event: its events always carry requestContext.
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { S3Client } from '@aws-sdk/client-s3';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import { createPresignedPost } from '@aws-sdk/s3-presigned-post';
import type { APIGatewayProxyEventV2WithJWTAuthorizer, APIGatewayProxyResultV2 } from 'aws-lambda';
import { Api, type Photos } from './api.js';
import { type AuthConfig, caller, parseAdminEmails } from './auth.js';
import { ApiError } from './domain/errors.js';
import { Store } from './store/store.js';
import { assertSeedable, seed } from '../seed/seed.js';

const MAX_BODY = 64 * 1024;
const MAX_PHOTO = 2 * 1024 * 1024;

const env = process.env;
const stage = env.STAGE ?? 'local';
const table = env.TABLE_NAME ?? '';
const auth: AuthConfig = {
  // The template refuses DevMode unless Stage is local; checked here too.
  devMode: env.DEV_MODE === 'true' && stage === 'local',
  adminEmails: parseAdminEmails(env.ADMIN_EMAILS),
};

// Floci (the local stack) sets AWS_ENDPOINT_URL; its S3 is path-style.
const local = Boolean(env.AWS_ENDPOINT_URL);
const doc = DynamoDBDocumentClient.from(new DynamoDBClient({}), {
  marshallOptions: { removeUndefinedValues: true },
});
const s3 = new S3Client({ forcePathStyle: local });
const store = new Store(doc, table);

const photos: Photos = {
  async presign(key, contentType) {
    const { url, fields } = await createPresignedPost(s3, {
      Bucket: env.PHOTOS_BUCKET ?? '',
      Key: `photos/${key}`,
      Conditions: [
        ['content-length-range', 1, MAX_PHOTO],
        ['eq', '$Content-Type', contentType],
        ['eq', '$Cache-Control', 'public, max-age=31536000, immutable'],
      ],
      // Keys are never reused, so the photo can be cached for good.
      Fields: { 'Content-Type': contentType, 'Cache-Control': 'public, max-age=31536000, immutable' },
      Expires: 300,
    });
    // Locally the browser can't reach the endpoint the function uses.
    return { url: env.PHOTOS_UPLOAD_URL || url, fields };
  },
};

const api = new Api({ store, photos, config: { stage, version: env.VERSION ?? 'dev' } });

type Event = APIGatewayProxyEventV2WithJWTAuthorizer | { grigriSeed?: boolean };

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

async function http(event: APIGatewayProxyEventV2WithJWTAuthorizer): Promise<APIGatewayProxyResultV2> {
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
    const isPublic = method === 'GET' && path === '/api/health';
    const who = isPublic ? null : caller(event.requestContext.authorizer?.jwt?.claims, headers, auth);
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
