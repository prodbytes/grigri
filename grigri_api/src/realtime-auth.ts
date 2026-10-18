// The IoT Core custom authorizer (specs/live-updates.md): the app connects
// to MQTT over WebSocket with its API session token (unsigned: the
// authorizer has signing disabled, since the token itself is the secret
// and browsers can't set headers on a WebSocket). This looks the session
// up the way the API does (auth.ts) and answers a policy that allows only:
//   iot:Connect   as a client id starting with "<climberId>-"
//   iot:Subscribe to topic filters under grigri/<stage>/climbers/<climberId>/
//   iot:Receive   from topics under the same
// Nothing else: no Publish, no other climber's topics. Anything unexpected
// (no token, unknown or expired session, no profile, a lookup error) is a
// denial: it fails closed. Tokens are never logged.
import { createHash } from 'node:crypto';
import type { Caller } from './auth.js';
import { clientIdPrefix } from './realtime.js';

/** Re-checks the session this often while connected (signed out: dropped within the hour). */
export const REFRESH_SECONDS = 3600;
/** IoT Core's maximum: every connection reconnects (and is checked afresh) within a day. */
export const DISCONNECT_SECONDS = 86400;

/** The parts of IoT Core's authorizer event this uses. */
export interface AuthorizerEvent {
  token?: string;
  protocols?: string[];
  protocolData?: {
    http?: { headers?: Record<string, string>; queryString?: string };
    mqtt?: { username?: string; password?: string; clientId?: string };
  };
}

export interface AuthorizerResponse {
  isAuthenticated: boolean;
  principalId: string;
  disconnectAfterInSeconds: number;
  refreshAfterInSeconds: number;
  policyDocuments: PolicyDocument[];
}

interface PolicyDocument {
  Version: '2012-10-17';
  Statement: { Effect: 'Allow'; Action: string; Resource: string[] }[];
}

export interface AuthorizerDeps {
  /** The caller of a session token; throws for a bad, unknown or expired one. */
  caller(token: string): Promise<Caller>;
  climberIdFor(subject: string): Promise<string | undefined>;
  stage: string;
}

/** Where the policy's ARNs point: from the function's own ARN. */
export interface Scope {
  partition: string;
  region: string;
  account: string;
}

export function scopeFromFunctionArn(arn: string): Scope {
  const [, partition, , region, account] = arn.split(':');
  if (!partition || !region || !account) throw new Error('unexpected function ARN');
  return { partition, region, account };
}

/** The session token, from the event's token, the WebSocket URL's query, or the MQTT password. */
export function tokenOf(event: AuthorizerEvent): string | undefined {
  if (typeof event.token === 'string' && event.token) return event.token;
  const query = event.protocolData?.http?.queryString;
  if (query) {
    const token = new URLSearchParams(query.startsWith('?') ? query.slice(1) : query).get('token');
    if (token) return token;
  }
  const password = event.protocolData?.mqtt?.password;
  if (password) {
    // IoT Core passes the MQTT password base64-encoded.
    const decoded = Buffer.from(password, 'base64').toString('utf8');
    if (decoded) return decoded;
  }
  return undefined;
}

/** IoT principal ids are [A-Za-z0-9]{1,128}; climber ids also have - and _. */
function principalId(climberId: string): string {
  return createHash('sha256').update(climberId).digest('hex').slice(0, 32);
}

export function deny(): AuthorizerResponse {
  return {
    isAuthenticated: false,
    principalId: 'denied',
    disconnectAfterInSeconds: 300,
    refreshAfterInSeconds: 300,
    policyDocuments: [],
  };
}

/** Climber ids are 16 URL-safe characters: nothing that means anything in a policy or topic. */
const CLIMBER_ID = /^[A-Za-z0-9_-]{16}$/;

export function allowPolicy(climberId: string, stage: string, scope: Scope): PolicyDocument {
  const arn = (kind: string, rest: string) => `arn:${scope.partition}:iot:${scope.region}:${scope.account}:${kind}/${rest}`;
  const subtree = `grigri/${stage}/climbers/${climberId}`;
  return {
    Version: '2012-10-17',
    Statement: [
      { Effect: 'Allow', Action: 'iot:Connect', Resource: [arn('client', `${clientIdPrefix(climberId)}*`)] },
      {
        Effect: 'Allow',
        Action: 'iot:Subscribe',
        Resource: [arn('topicfilter', `${subtree}/#`), arn('topicfilter', `${subtree}/*`)],
      },
      { Effect: 'Allow', Action: 'iot:Receive', Resource: [arn('topic', `${subtree}/*`)] },
    ],
  };
}

export async function authorize(event: AuthorizerEvent, deps: AuthorizerDeps, scope: Scope): Promise<AuthorizerResponse> {
  try {
    const token = tokenOf(event);
    if (!token) return deny();
    const caller = await deps.caller(token);
    // The session keeps its account's climber once known (auth.ts); older
    // ones, and new accounts' first, look the link up.
    const climberId = caller.climberId ?? (await deps.climberIdFor(caller.subject));
    if (!climberId || !CLIMBER_ID.test(climberId)) return deny();
    // The policy enforces it too; refusing here saves a policy evaluation.
    const clientId = event.protocolData?.mqtt?.clientId;
    if (clientId !== undefined && !clientId.startsWith(clientIdPrefix(climberId))) return deny();
    return {
      isAuthenticated: true,
      principalId: principalId(climberId),
      disconnectAfterInSeconds: DISCONNECT_SECONDS,
      refreshAfterInSeconds: REFRESH_SECONDS,
      policyDocuments: [allowPolicy(climberId, deps.stage, scope)],
    };
  } catch (e) {
    // "signed out" is the usual reason; anything else is logged (no token).
    const message = String((e as Error)?.message ?? e);
    if (message !== 'signed out') console.error(JSON.stringify({ level: 'error', msg: 'authorizer failed', error: message }));
    return deny();
  }
}
