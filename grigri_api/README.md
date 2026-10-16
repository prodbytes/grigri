# grigri_api

Grigri's backend: one TypeScript Lambda (Node.js 22, arm64, 256 MB) with
an internal router, behind one API Gateway HTTP API, and one on-demand
DynamoDB table. The function authenticates every request: it trades a
Google ID token (verified with [jose](https://github.com/panva/jose)) for
its own session token, good until sign-out or 365 days without use. The site's
CloudFront serves it under `/api/*`. For live updates it publishes hints
to AWS IoT Core MQTT topics, and a second small Lambda is the IoT custom
authorizer that lets the app subscribe to its own topic with its session
token ([specs/live-updates.md](../specs/live-updates.md)). The contract is
[specs/api.md](../specs/api.md); the architecture, environments and costs
are in [specs/backend.md](../specs/backend.md).

## Layout

| Path | Holds |
|---|---|
| [template.yaml](template.yaml) | The `<prefix>-api` stack: function, its role and log group, HTTP API (routes, stage; no authorizer), table (with TTL); live updates: the authorizer function (`<stack>-realtime-auth`), its role and log group, the `AWS::IoT::Authorizer` (`<stack>-realtime`, not locally) and IoT's permission to invoke it |
| [src/handler.ts](src/handler.ts) | Lambda entry: HTTP API events to the caller (unless the route is public) and the router; the photos bucket (presigned POSTs tagged pending, clearing the tag, deletes); the `{"grigriSeed": true}` direct invoke to the seed |
| [src/api.ts](src/api.ts) | The routes: who may call each (public, any session, signed in, with a profile, admin), then the rules, then the store |
| [src/auth.ts](src/auth.ts) | Sessions: sign-in (a Google ID token, or `devUser` in local dev mode), the caller from `Authorization: Bearer <session token>` (or, local dev mode only, `X-Grigri-Dev-User`), sliding expiry, sign-out; admins by verified email |
| [src/realtime.ts](src/realtime.ts) | Live updates: hint topics, `GET /api/realtime`'s answer, best-effort fan-out (deduplicated, at most 1.5 s, never failing a request) |
| [src/publishers.ts](src/publishers.ts) | How hints leave: `iot-data:Publish` in AWS; locally a minimal MQTT 3.1.1 client over WebSocket to Floci's broker |
| [src/realtime-auth.ts](src/realtime-auth.ts), [src/authorizer.ts](src/authorizer.ts) | The IoT custom authorizer: the session token (from the WebSocket URL's query or the MQTT password) to a policy allowing only `<climberId>-*` client ids and that climber's own topics; denies on anything else |
| [src/google.ts](src/google.ts) | Google ID token verification (jose: Google's JWKS, cached; RS256, issuer, audience, expiry) |
| [src/domain/](src/domain) | Pure, unit-tested rules: the shapes (`model.ts`), input validation (`validate.ts`), and matchmaking (`rules.ts`: deck sorting, unanimous yes, one no, leave and organizer handover, notices, chat notes, admin accept/reject, nudges) |
| [src/store/](src/store) | DynamoDB access (`store.ts`) and the table's keys (`keys.ts`) |
| [seed/](seed) | The made-up test data for RC and local (`data.ts`) and its idempotent loader (`seed.ts`), which refuses prod |
| [test/](test) | vitest: rules, validation, token verification (locally made keys, never real tokens), sessions and routing, the seed, every route against an in-memory store (`fake-store.ts`), and live updates (authorizer policies, hint fan-out, publish failures, MQTT packets) |
| [build.mjs](build.mjs) | esbuild: `src/handler.ts` to `dist/index.mjs` and `src/authorizer.ts` to `dist/authorizer.mjs`, with the AWS SDK bundled (pinned by `package-lock.json`) |

## Commands

```bash
npm ci
npm run typecheck   # tsc --noEmit
npm test            # vitest run
npm run build       # dist/index.mjs
npm run check       # all three
```

Inside devbox (`devbox shell`), which has Node.js 22. `devbox services up`
builds it (`scripts/build-api.sh`) and deploys it into Floci with the seed
([grigri_floci/](../grigri_floci)); `scripts/deploy.sh` tests, builds and
deploys it to AWS.

## Data model

One table, `<stack name>` (`grigri-api`, `grigri-rc-api`,
`grigri-local-api`), keys `pk` and `sk`, three sparse global secondary
indexes (gsi1 and gsi2 project everything, gsi3 only keys), and TTL on
`ttl` (only sessions have it). The match scores live in their own table,
`<stack name>-scores` ([specs/match-scores.md](../specs/match-scores.md)):

| Item | pk | sk | Index keys | Holds |
|---|---|---|---|---|
| Session | `SESSION#<sha256 of the token>` | `SESSION` | gsi3: `SESSIONS#<subject>`, `<createdAt>` | `subject`, `email` (only if verified), `emailVerified`, `createdAt`, `lastUsedAt`, `ttl` (epoch seconds, lastUsedAt + 365 days) |
| Sign-in link | `SUB#<iss>#<sub>` | `SUB` | | `climberId` |
| Profile | `CLIMBER#<id>` | `PROFILE` | gsi1: `CLIMBERS`, `<id>` | the Climber, plus `subject` (never returned; none for the seed's) |
| Membership | `CLIMBER#<id>` | `MEMBER#<planId>` | | "plans I'm in" |
| Pass | `CLIMBER#<id>` | `PASS#<planId>` | | out of my deck (swiped left, left, or dismissed) |
| Notice | `CLIMBER#<id>` | `NOTICE#<noticeId>` | | the Notice |
| Plan | `PLAN#<id>` | `PLAN` | gsi1: `PLANS`, `<start>#<id>` | the Plan, and `version` (incremented by every change to its members or requests) |
| Join request | `PLAN#<id>` | `REQ#<climberId>` | gsi2: `ASKED#<climberId>`, `<time>#<planId>`; gsi1 while open: `OPENREQ`, `<time>#<planId>#<climberId>` | the JoinRequest (with `nudgedAt` once nudged), plus `joined` and `dismissed` |
| Message | `PLAN#<id>` | `MSG#<time>#<messageId>` | | the Message |

Access patterns: every authenticated request gets its session (an
eventually consistent read, retried consistently on a miss, so a session
made a moment ago is found), and writes it at most once a day to slide
it; sign-out everywhere queries gsi3 for the subject's sessions. The deck queries gsi1 `PLANS` for starts after now; "my
requests" queries gsi2; the match scoring run lists every profile from gsi1
`CLIMBERS`; the admin's open requests query gsi1 `OPENREQ`
(only open requests carry those keys); a plan's requests and chat are one
partition (`begins_with` on `REQ#` / `MSG#`, `after` as a key range). A
climber's memberships, passes and notices are one partition.

Races: accept, reject, leave, admin answers and plan edits write the plan
(version check), its changed requests, memberships and notes in one
transaction, retried on a lost race; a join is a transaction of a version
check on the plan plus a conditional put of the request (no double join).
At most 30 requests wait on a plan, so a transaction stays under
DynamoDB's 100 items. Notices are put after the transaction.

## Configuration

Environment (set by the template): `STAGE`, `VERSION`, `TABLE_NAME`,
`PHOTOS_BUCKET`, `PHOTOS_UPLOAD_URL` (local only), `RBACR_URL` and
`RBACR_TOKEN` (who holds grigri's admin role: [src/rbacr.ts](src/rbacr.ts)),
`GOOGLE_WEB_CLIENT_ID` (the ID tokens' audience; none: no Google sign-in),
`DEV_MODE` (honored only when `STAGE` is `local`), `IOT_ENDPOINT` (where
the app connects for live updates, host[:port]; empty: off) and
`IOT_AUTHORIZER` (the custom authorizer's name; empty locally). Floci sets
`AWS_ENDPOINT_URL`; S3 is then path-style, and hints go over MQTT to
Floci's broker instead of `iot-data:Publish`. The authorizer function gets
`STAGE` and `TABLE_NAME`.
