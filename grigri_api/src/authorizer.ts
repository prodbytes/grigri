// The live updates' IoT Core custom authorizer, a Lambda of its own
// (<stack>-realtime-auth): see realtime-auth.ts. It only reads sessions
// and the subject-to-climber link from the API's table (and slides a
// session, as any use does); its role allows nothing else.
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import type { Context } from 'aws-lambda';
import { Auth } from './auth.js';
import { InvalidIdToken } from './google.js';
import { type AuthorizerEvent, type AuthorizerResponse, authorize, scopeFromFunctionArn } from './realtime-auth.js';
import { Store } from './store/store.js';

const env = process.env;
const store = new Store(DynamoDBDocumentClient.from(new DynamoDBClient({})), env.TABLE_NAME ?? '');
const auth = new Auth({
  store,
  // Never signs anyone in: only reads existing sessions.
  verify: async () => {
    throw new InvalidIdToken('not here');
  },
  config: { devMode: false, adminEmails: new Set() },
});

export async function handler(event: AuthorizerEvent, context: Context): Promise<AuthorizerResponse> {
  return authorize(
    event,
    {
      caller: (token) => auth.callerOfToken(token),
      climberIdFor: (subject) => store.climberIdFor(subject),
      stage: env.STAGE ?? 'local',
    },
    scopeFromFunctionArn(context.invokedFunctionArn),
  );
}
