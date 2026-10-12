# grigri_api

Grigri's backend: one TypeScript Lambda (Node.js 22, arm64, 256 MB) with
an internal router, behind one API Gateway HTTP API whose JWT authorizer
checks Google ID tokens, and one on-demand DynamoDB table. The site's
CloudFront serves it under `/api/*`. The contract is
[specs/api.md](../specs/api.md); the architecture, environments and costs
are in [specs/backend.md](../specs/backend.md).

## Layout

| Path | Holds |
|---|---|
| [template.yaml](template.yaml) | The `<prefix>-api` stack: function, its role and log group, HTTP API (authorizer, routes, stage), table |
| [src/handler.ts](src/handler.ts) | Lambda entry: HTTP API events to the router; the `{"grigriSeed": true}` direct invoke to the seed |
| [src/api.ts](src/api.ts) | The routes: who may call each (public, signed in, with a profile, admin), then the rules, then the store |
| [src/auth.ts](src/auth.ts) | The caller from the authorizer's claims (or, local dev mode only, `X-Grigri-Dev-User`); admins by verified email |
| [src/domain/](src/domain) | Pure, unit-tested rules: the shapes (`model.ts`), input validation (`validate.ts`), and matchmaking (`rules.ts`: deck sorting, unanimous yes, one no, leave and organizer handover, notices, chat notes, admin accept/reject) |
| [src/store/](src/store) | DynamoDB access (`store.ts`) and the table's keys (`keys.ts`) |
| [seed/](seed) | The made-up test data for RC and local (`data.ts`) and its idempotent loader (`seed.ts`), which refuses prod |
| [test/](test) | vitest: rules, validation, auth and routing, the seed, and every route against an in-memory store (`fake-store.ts`) |
| [build.mjs](build.mjs) | esbuild: `src/handler.ts` to `dist/index.mjs`, with the AWS SDK bundled (pinned by `package-lock.json`) |

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
`grigri-local-api`), keys `pk` and `sk`, two sparse global secondary
indexes (projecting everything):

| Item | pk | sk | Index keys | Holds |
|---|---|---|---|---|
| Sign-in link | `SUB#<iss>#<sub>` | `SUB` | | `climberId` |
| Profile | `CLIMBER#<id>` | `PROFILE` | | the Climber, plus `subject` (never returned; none for the seed's) |
| Membership | `CLIMBER#<id>` | `MEMBER#<planId>` | | "plans I'm in" |
| Pass | `CLIMBER#<id>` | `PASS#<planId>` | | out of my deck (swiped left, left, or dismissed) |
| Notice | `CLIMBER#<id>` | `NOTICE#<noticeId>` | | the Notice |
| Plan | `PLAN#<id>` | `PLAN` | gsi1: `PLANS`, `<start>#<id>` | the Plan, and `version` (incremented by every change to its members or requests) |
| Join request | `PLAN#<id>` | `REQ#<climberId>` | gsi2: `ASKED#<climberId>`, `<time>#<planId>`; gsi1 while open: `OPENREQ`, `<time>#<planId>#<climberId>` | the JoinRequest, plus `joined` and `dismissed` |
| Message | `PLAN#<id>` | `MSG#<time>#<messageId>` | | the Message |

Access patterns: the deck queries gsi1 `PLANS` for starts after now; "my
requests" queries gsi2; the admin's open requests query gsi1 `OPENREQ`
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
`PHOTOS_BUCKET`, `PHOTOS_UPLOAD_URL` (local only), `ADMIN_EMAILS`,
`DEV_MODE` (honored only when `STAGE` is `local`). Floci sets
`AWS_ENDPOINT_URL`; S3 is then path-style.
