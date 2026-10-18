import { beforeEach, describe, expect, it } from 'vitest';
import { Api } from '../src/api.js';
import { Auth, type Caller } from '../src/auth.js';
import { InvalidIdToken } from '../src/google.js';
import { connectPacket, DISCONNECT, publishPacket } from '../src/publishers.js';
import {
  type AuthorizerDeps,
  type AuthorizerEvent,
  DISCONNECT_SECONDS,
  REFRESH_SECONDS,
  authorize,
  scopeFromFunctionArn,
  tokenOf,
} from '../src/realtime-auth.js';
import { type Outgoing, type Publisher, Realtime, hintTopic } from '../src/realtime.js';
import { FakeStore } from './fake-store.js';

const scope = scopeFromFunctionArn('arn:aws:lambda:us-east-1:123456789012:function:grigri-api-realtime-auth');
const ADA = 'AdaAdaAdaAdaAda1';
const BEN = 'BenBenBenBenBen2';

describe('the authorizer', () => {
  let store: FakeStore;
  let auth: Auth;
  let deps: AuthorizerDeps;
  let token: string;

  beforeEach(async () => {
    store = new FakeStore();
    auth = new Auth({
      store: store.asStore(),
      verify: async () => {
        throw new InvalidIdToken('unused');
      },
      config: { devMode: true, isAdmin: async () => false },
    });
    token = (await auth.signIn({ devUser: 'ada@example.com' })).token;
    store.subjects.set('dev#ada@example.com', ADA);
    deps = {
      caller: (t) => auth.callerOfToken(t),
      climberIdFor: (subject) => store.climberIdFor(subject),
      stage: 'prod',
    };
  });

  const wss = (t: string, clientId = `${ADA}-web1`): AuthorizerEvent => ({
    protocols: ['tls', 'http', 'mqtt'],
    protocolData: {
      http: { headers: {}, queryString: `?x-amz-customauthorizer-name=grigri-api-realtime&token=${encodeURIComponent(t)}` },
      mqtt: { clientId },
    },
  });

  it('allows only my client ids, and subscribing to and receiving my own topics', async () => {
    const answer = await authorize(wss(token), deps, scope);
    expect(answer.isAuthenticated).toBe(true);
    expect(answer.principalId).toMatch(/^[A-Za-z0-9]{1,128}$/);
    expect(answer.refreshAfterInSeconds).toBe(REFRESH_SECONDS);
    expect(answer.disconnectAfterInSeconds).toBe(DISCONNECT_SECONDS);
    expect(answer.disconnectAfterInSeconds).toBeLessThanOrEqual(86400);
    expect(answer.policyDocuments).toEqual([
      {
        Version: '2012-10-17',
        Statement: [
          { Effect: 'Allow', Action: 'iot:Connect', Resource: [`arn:aws:iot:us-east-1:123456789012:client/${ADA}-*`] },
          {
            Effect: 'Allow',
            Action: 'iot:Subscribe',
            Resource: [
              `arn:aws:iot:us-east-1:123456789012:topicfilter/grigri/prod/climbers/${ADA}/#`,
              `arn:aws:iot:us-east-1:123456789012:topicfilter/grigri/prod/climbers/${ADA}/*`,
            ],
          },
          { Effect: 'Allow', Action: 'iot:Receive', Resource: [`arn:aws:iot:us-east-1:123456789012:topic/grigri/prod/climbers/${ADA}/*`] },
        ],
      },
    ]);
    // Nothing else: no publishing, no one else's topics, no wildcard climbers.
    const text = JSON.stringify(answer.policyDocuments);
    expect(text).not.toContain('iot:Publish');
    expect(text).not.toContain(BEN);
    expect(text).not.toContain('climbers/*');
    expect(text).not.toContain('climbers/#');
  });

  it('takes the token from the event, the query string or the MQTT password', async () => {
    expect(tokenOf({ token: 'a' })).toBe('a');
    expect(tokenOf({ protocolData: { http: { queryString: 'token=b&x=1' } } })).toBe('b');
    expect(tokenOf({ protocolData: { mqtt: { password: Buffer.from('c').toString('base64') } } })).toBe('c');
    expect(tokenOf({})).toBeUndefined();
    const viaPassword: AuthorizerEvent = { protocolData: { mqtt: { clientId: `${ADA}-x`, password: Buffer.from(token).toString('base64') } } };
    expect((await authorize(viaPassword, deps, scope)).isAuthenticated).toBe(true);
  });

  it('denies without a token, with an unknown or ended session, or without a profile', async () => {
    expect((await authorize({ protocolData: { mqtt: { clientId: `${ADA}-x` } } }, deps, scope)).isAuthenticated).toBe(false);
    expect((await authorize(wss('not-a-token'), deps, scope)).isAuthenticated).toBe(false);
    expect((await authorize(wss('A'.repeat(43)), deps, scope)).isAuthenticated).toBe(false);
    const other = (await auth.signIn({ devUser: 'nobody@example.com' })).token;
    expect((await authorize(wss(other, 'whoever-1'), deps, scope)).isAuthenticated).toBe(false);
    await auth.signOutEverywhere({ subject: 'dev#ada@example.com', isAdmin: async () => false });
    const denied = await authorize(wss(token), deps, scope);
    expect(denied.isAuthenticated).toBe(false);
    expect(denied.policyDocuments).toEqual([]);
  });

  it("denies another climber's client id", async () => {
    expect((await authorize(wss(token, `${BEN}-web1`), deps, scope)).isAuthenticated).toBe(false);
    expect((await authorize(wss(token, ADA), deps, scope)).isAuthenticated).toBe(false);
  });

  it("uses the climber the session keeps, without the lookup, still checked", async () => {
    const kept = (await auth.signIn({ devUser: 'ada@example.com' })).token;
    const broken = { ...deps, climberIdFor: async () => { throw new Error('not asked'); } };
    const answer = await authorize(wss(kept), broken, scope);
    expect(answer.isAuthenticated).toBe(true);
    expect(JSON.stringify(answer.policyDocuments)).toContain(`climbers/${ADA}/`);
    // Still only my own client ids.
    expect((await authorize(wss(kept, `${BEN}-web1`), broken, scope)).isAuthenticated).toBe(false);
  });

  it('fails closed when a lookup fails', async () => {
    const broken = { ...deps, climberIdFor: async () => { throw new Error('throttled'); } };
    expect((await authorize(wss(token), broken, scope)).isAuthenticated).toBe(false);
  });
});

/** Records what would be published; can be told to fail or hang. */
class FakePublisher implements Publisher {
  sent: Outgoing[] = [];
  mode: 'ok' | 'fail' | 'hang' = 'ok';
  async publish(messages: Outgoing[]) {
    if (this.mode === 'fail') throw new Error('IoT is down');
    if (this.mode === 'hang') return new Promise<void>(() => {});
    this.sent.push(...messages);
  }
  /** Who got which hint, as "climberId kind". */
  hints(): string[] {
    return this.sent
      .map((m) => `${m.topic.split('/')[3]} ${JSON.parse(m.payload).kind}`)
      .sort();
  }
}

describe('Realtime', () => {
  it('says where to connect, or that live updates are off', () => {
    const live = new Realtime({ stage: 'rc', endpoint: 'abc-ats.iot.us-east-1.amazonaws.com', authorizer: 'grigri-rc-api-realtime' }, new FakePublisher());
    expect(live.info(ADA)).toEqual({
      url: 'wss://abc-ats.iot.us-east-1.amazonaws.com/mqtt',
      authorizer: 'grigri-rc-api-realtime',
      topic: `grigri/rc/climbers/${ADA}/#`,
      clientIdPrefix: `${ADA}-`,
    });
    expect(new Realtime({ stage: 'rc', endpoint: '', authorizer: '' }, null).info(ADA)).toEqual({ url: null });
  });

  it('publishes each hint once, to the climber topic, and never throws', async () => {
    const pub = new FakePublisher();
    const rt = new Realtime({ stage: 'prod', endpoint: 'e', authorizer: 'a' }, pub, 50);
    await rt.notify([
      { to: ADA, hint: { kind: 'message', planId: 'p1' } },
      { to: ADA, hint: { kind: 'message', planId: 'p1' } },
      { to: BEN, hint: { kind: 'notice' } },
    ]);
    expect(pub.sent).toEqual([
      { topic: hintTopic('prod', ADA), payload: '{"kind":"message","planId":"p1"}' },
      { topic: `grigri/prod/climbers/${BEN}/hint`, payload: '{"kind":"notice"}' },
    ]);
    pub.mode = 'fail';
    await expect(rt.notify([{ to: ADA, hint: { kind: 'plan' } }])).resolves.toBeUndefined();
    pub.mode = 'hang';
    const started = Date.now();
    await expect(rt.notify([{ to: ADA, hint: { kind: 'plan' } }])).resolves.toBeUndefined();
    expect(Date.now() - started).toBeLessThan(1000);
  });
});

describe('MQTT packets (the local publisher)', () => {
  it('encodes CONNECT, PUBLISH (QoS 0) and DISCONNECT', () => {
    expect([...connectPacket('c')]).toEqual([0x10, 13, 0, 4, 77, 81, 84, 84, 4, 2, 0, 30, 0, 1, 99]);
    expect([...publishPacket('a/b', 'hi')]).toEqual([0x30, 7, 0, 3, 97, 47, 98, 104, 105]);
    const long = publishPacket('t', 'x'.repeat(200));
    expect([...long.subarray(0, 3)]).toEqual([0x30, 0xcb, 0x01]); // 203 = 0x4b | 0x80, 1
    expect([...DISCONNECT]).toEqual([0xe0, 0]);
  });
});

describe('hints from the API', () => {
  let now: Date;
  let store: FakeStore;
  let api: Api;
  let pub: FakePublisher;
  const who = (name: string, admin = false): Caller => ({ subject: `test#${name}`, email: `${name}@example.com`, isAdmin: async () => admin });
  const [ada, ben, cy, root] = [who('ada'), who('ben'), who('cy'), who('root', true)];
  const ids: Record<string, string> = {};
  let planId: string;

  const call = async (c: Caller, method: string, path: string, body?: unknown) =>
    (await api.handle(method, path, { caller: c, body, query: {} })) as Record<string, any>;
  const profile = (name: string) => ({ name, bio: '', levels: { sport: { scale: 'routes', min: 6, max: 10 } }, gear: ['rope'] });
  /** The hints sent by `step`, as "<name> <kind>". */
  async function hintsOf(step: () => Promise<unknown>): Promise<string[]> {
    pub.sent = [];
    await step();
    const names = Object.fromEntries(Object.entries(ids).map(([n, id]) => [id, n]));
    return pub.hints().map((h) => {
      const [id, kind] = h.split(' ');
      return `${names[id!]} ${kind}`;
    }).sort();
  }

  beforeEach(async () => {
    now = new Date('2030-05-01T10:00:00.000Z');
    store = new FakeStore();
    pub = new FakePublisher();
    const auth = new Auth({
      store: store.asStore(),
      verify: async () => ({ subject: 'x', emailVerified: false }),
      config: { devMode: false, isAdmin: async (email) => email === 'root@example.com' },
    });
    const photos = { presign: async () => ({ url: '', fields: {} }), keep: async () => true, remove: async () => {} };
    api = new Api({
      store: store.asStore(),
      photos,
      auth,
      realtime: new Realtime({ stage: 'local', endpoint: 'local.example.com:2543', authorizer: '' }, pub, 50),
      config: { stage: 'local', version: 'test' },
      clock: () => now,
    });
    for (const [name, c] of [['Ada', ada], ['Ben', ben], ['Cy', cy], ['Root', root]] as const) {
      ids[name] = (await call(c, 'PUT', '/api/me', profile(name))).climber.id;
    }
    planId = (
      await call(ada, 'POST', '/api/plans', {
        discipline: 'sport', place: 'Somewhere', area: 'Nowhere', start: '2030-05-10T08:00:00Z', end: '2030-05-10T14:00:00Z',
        grades: { scale: 'routes', min: 6, max: 10 }, notes: '',
      })
    ).plan.id;
  });

  it('GET /api/realtime says where my hints come from', async () => {
    expect(await call(ben, 'GET', '/api/realtime')).toEqual({
      url: 'wss://local.example.com:2543/mqtt',
      authorizer: '',
      topic: `grigri/local/climbers/${ids.Ben}/#`,
      clientIdPrefix: `${ids.Ben}-`,
    });
    await expect(api.handle('GET', '/api/realtime', { caller: who('nobody'), body: undefined, query: {} })).rejects.toThrow(/no profile/);
  });

  it('tells the members, never the one who acted', async () => {
    // A join request: every member.
    expect(await hintsOf(() => call(ben, 'POST', `/api/plans/${planId}/join`))).toEqual(['Ada request']);
    // Everyone said yes: a match for the newcomer.
    expect(await hintsOf(() => call(ada, 'POST', `/api/requests/${planId}/${ids.Ben}/accept`))).toEqual(['Ben match']);
    // A partial yes: the other members' requests changed.
    await call(cy, 'POST', `/api/plans/${planId}/join`);
    expect(await hintsOf(() => call(ada, 'POST', `/api/requests/${planId}/${ids.Cy}/accept`))).toEqual(['Ben request']);
    // The last yes: Cy's match, and the plan changed for the others.
    expect(await hintsOf(() => call(ben, 'POST', `/api/requests/${planId}/${ids.Cy}/accept`))).toEqual(['Ada plan', 'Cy match']);
    // Chat: the other members.
    expect(await hintsOf(() => call(cy, 'POST', `/api/plans/${planId}/messages`, { text: 'Hi' }))).toEqual(['Ada message', 'Ben message']);
    // Plan edits and leaving: the (remaining) members.
    const edit = (await call(ada, 'GET', `/api/plans/${planId}`)).plan;
    expect(await hintsOf(() => call(ada, 'PUT', `/api/plans/${planId}`, { ...edit, notes: 'Bring water' }))).toEqual(['Ben plan', 'Cy plan']);
    expect(await hintsOf(() => call(cy, 'POST', `/api/plans/${planId}/leave`))).toEqual(['Ada plan', 'Ben plan']);
  });

  it('a no tells the requester and the members', async () => {
    await call(ben, 'POST', `/api/plans/${planId}/join`);
    await call(cy, 'POST', `/api/plans/${planId}/join`);
    expect(await hintsOf(() => call(ada, 'POST', `/api/requests/${planId}/${ids.Ben}/reject`))).toEqual(['Ben notice']);
    expect(await hintsOf(() => call(ada, 'POST', `/api/plans/${planId}/pass`))).toEqual([]);
  });

  it('a nudge tells the members who have not said yes', async () => {
    await call(ben, 'POST', `/api/plans/${planId}/join`);
    await call(ada, 'POST', `/api/requests/${planId}/${ids.Ben}/accept`);
    await call(cy, 'POST', `/api/plans/${planId}/join`);
    await call(ben, 'POST', `/api/requests/${planId}/${ids.Cy}/accept`);
    expect(await hintsOf(() => call(cy, 'POST', `/api/plans/${planId}/nudge`))).toEqual(['Ada notice']);
  });

  it("a failed publish doesn't fail the request", async () => {
    pub.mode = 'fail';
    const { message } = await call(ada, 'POST', `/api/plans/${planId}/messages`, { text: 'Still works' });
    expect(message.text).toBe('Still works');
    pub.mode = 'hang';
    expect((await call(ben, 'POST', `/api/plans/${planId}/join`)).request.climberId).toBe(ids.Ben);
  });
});
