# Backend

All of Grigri's data comes from the backend: profiles, plans, join
requests, notices, chats and photos. The app keeps no data of its own and
has no built-in demo data. The routes and JSON shapes are in
[api.md](api.md); the code, data model and commands in
[grigri_api/README.md](../grigri_api/README.md).

## Environments

| | Production (GA) | Release candidate | Local |
|---|---|---|---|
| Site | https://grigri.nu01.com | https://rc.grigri.nu01.com | https://local.grigri.nu01.com:2543 |
| API stack | `grigri-api` | `grigri-rc-api` | `grigri-local-api`, in Floci |
| Data | **Starts empty: only real people's data.** Never seeded | Made-up test data, re-seeded after each RC deploy, beside testers' real data | Made-up test data, seeded on every Floci start (Floci keeps nothing) |
| Sign-in | A Google ID token (`GOOGLE_WEB_CLIENT_ID`) for the API's own session | Same | Same when `.env` has `GOOGLE_WEB_CLIENT_ID`; otherwise **dev mode** |
| Admins | rbacr's `grigri` `admin` role, asked with `GRIGRI_RBACR_TOKEN` (repository secret) | Same | The local rbacr's, asked with `RBACR_TOKEN` in `.env` |
| Backups | Point-in-time recovery (35 days), deletion protection | None | None |

Every environment behaves the same: nobody answers requests automatically.
The made-up climbers can't sign in (they have no Google account), so their
requests and the requests waiting on their plans are answered by testers
who are members, or by an admin.

## Architecture

- **One Lambda** (TypeScript, Node.js 22, arm64, 256 MB, 10 s timeout) with
  an internal router, behind **one HTTP API** (no authorizer). Throttled
  at 50 requests/s (bursts of 100), which caps the bill if someone floods
  it.
- The site's **CloudFront** distribution serves the API under `/api/*`
  (no caching, every viewer header but `Host`, all methods) and photos
  under `/photos/*`, so the web app calls its own origin: no CORS for the
  API.
- **DynamoDB**, one table, on demand, single-table design.
- **Photos** in a private S3 bucket in the site stack
  (`<site stack>-photos-<account>`), uploaded straight from the app with
  presigned POSTs (≤ 2 MB, JPEG/PNG/WebP, 5 minutes) that the API issues
  for the caller's own folder, and read through CloudFront with origin
  access control. Keys are random and never reused, so photos are cached
  at the edge and in browsers for a year. The bucket allows POST uploads
  from the stage's site origin (CORS); the web app's CSP allows the
  bucket's URL in `connect-src`. Uploads arrive tagged
  `grigri-pending=true` (a field of the presigned POST); saving a profile
  clears the tag of its new photos and deletes the photos it no longer
  uses, and a lifecycle rule expires pending photos after a day, so photos
  never saved to a profile go away. Saved photos stay until replaced;
  failed multipart uploads are cleaned up too.
- **Auth: the API's own sessions** ([api.md](api.md#sessions)). Sign-in
  sends a Google ID token once to `POST /api/session`; the function
  verifies it (with [jose](https://github.com/panva/jose): RS256 against
  Google's keys, cached while the function stays warm; issuer, audience
  the web client ID, expiry) and returns an opaque session token (32
  random bytes), stored only as its SHA-256 hash. Every other route but
  `GET /api/health` sends it as a bearer token, and the function reads
  the session (one DynamoDB read) before routing; a missing, unknown or
  expired one is 401 `signed out`. A session slides: used more than a day
  after its last use, it moves forward (at most one write a day), and it
  expires after **365 days without use** (DynamoDB's TTL deletes it). No
  absolute limit: people stay signed in until they sign out
  (`DELETE /api/session`, or `DELETE /api/sessions` everywhere). Google ID
  tokens last an hour and can't be refreshed quietly on the web, which
  had signed people out hourly.
- **Identity**: a Google account (`https://accounts.google.com#<sub>`) is
  linked to one climber id (random, made by the server at the first
  profile save). Emails are only used for the admin check: kept on the
  session (only when verified), never on a profile, never returned.
- **Admin**: a signed-in caller whose session's verified email is in the
  stage's current admin list, checked on every request (so removing
  someone from the list takes effect at once). Admins see every open request (`GET /api/admin/requests`)
  and accept (they join at once, as if every member had said yes) or
  reject any.
- **Live updates** ([live-updates.md](live-updates.md)): after a change,
  the function publishes a tiny hint (`{"kind", "planId"}`, never data)
  to each affected climber's MQTT topic on **AWS IoT Core**
  (`iot-data:Publish`, QoS 0, at most 1.5 s, never failing the request);
  its role may publish only to `topic/grigri/<stage>/climbers/*`. The app
  subscribes over WebSocket with its session token, checked by an IoT
  **custom authorizer** (`<prefix>-api-realtime`, unsigned) backed by a
  second small function, `<prefix>-api-realtime-auth` (128 MB, its role
  reads sessions and subjects from the table and nothing else), whose
  policy allows connecting as `<climberId>-…` and subscribing to and
  receiving only `grigri/<stage>/climbers/<climberId>/…`. `GET
  /api/realtime` tells the app where to connect; the endpoint (the
  account's IoT Data-ATS endpoint) is a template parameter that
  `scripts/deploy.sh` looks up, and the site's CSP allows
  `wss://<it>` in `connect-src`. Locally, Floci's MQTT broker stands in
  ([dev-environment.md](dev-environment.md#live-updates)).
- **Dev mode** (local only): without a Google client, the caller names
  themselves in an `X-Grigri-Dev-User: <email>` header, or gets a session
  from `POST /api/session` with `{"devUser": "<email>"}`. The template
  refuses `DevMode` unless `Stage` is `local` (a CloudFormation Rule), and
  the function ignores the header and refuses `devUser` unless its stage
  is `local`, so neither RC nor GA can run it.

## The seed

[grigri_api/seed/](../grigri_api/seed): nine made-up climbers (never real
people), seven plans relative to now (always upcoming) and three open
requests between them, ported from the app's former on-device demo
without its answer "policies". Ids start with `seed-`. It runs inside the
stage's function, invoked directly with `{"grigriSeed": true}` (the HTTP
API can't send that event) by [scripts/seed.sh](../scripts/seed.sh):

- RC: `scripts/deploy.sh` runs it after deploying `grigri-rc-api`.
- Local: Floci's ready hook runs it after deploying the API.
- Production: never. `scripts/seed.sh` refuses `STAGE=prod`, the function
  refuses unless its stage is `rc` or `local` *and* its table is
  `grigri-rc-api` or `grigri-local-api`, and the production deploy role
  may only invoke the RC function.

It's idempotent: re-running rewrites the seed's own profiles, plans,
requests and chat lines with fresh dates. Real people's data stays: their
profiles, requests, notices and messages, and their membership of a seed
plan.

## Cost

Cost comes first: **nothing new costs anything while nobody uses it**,
and use is billed per request. Prices are us-east-1's.

| Resource | Price | Idle | Why this one |
|---|---|---|---|
| DynamoDB, on demand | $0.625 per million writes, $0.125 per million reads, $0.25/GB-month (the first 25 GB free); point-in-time recovery $0.20/GB-month, prod only; TTL deletes free | $0 (a few cents of storage at most) | Pay per request with no minimum. **Aurora Serverless v2** costs about **$43/month** at its 0.5 ACU minimum (auto-pause to 0 ACU exists, but resuming takes seconds and storage and I/O still bill); **RDS** bills every hour (a db.t4g.micro is about $12/month plus storage) whether used or not. The access patterns (by plan, by climber, upcoming plans, open requests) fit key lookups, so a relational database buys nothing here. |
| HTTP API | $1.00 per million requests | $0 | REST APIs cost $3.50 per million. No authorizer: the function checks sessions itself. |
| Sessions (in the table) | One eventually consistent read per request (about $0.06 per million requests), one write per session per day of use, a write to sign in or out; the subject index is keys-only, so the daily slide doesn't write to it | $0 | An HTTP API JWT authorizer would be free per request, but it can only check Google's one-hour tokens. A Lambda authorizer would add a second invocation per request; Cognito would add a service and its own pricing beyond its free tier. |
| One Lambda, arm64, 256 MB | $0.20 per million requests + $0.0000133 per GB-second (1 million requests and 400,000 GB-seconds a month free) | $0 | One function with an internal router: one cold start to warm, one log group, one role. arm64 is 20% cheaper than x86. 256 MB keeps a ~50 ms request at well under a cent per thousand. |
| S3 photos bucket | $0.023/GB-month, $0.005 per 1,000 uploads (and per 1,000 tag clears, one per new photo saved); deletes and lifecycle expirations free | $0 when empty | Photos stay out of DynamoDB (400 KB item limit, and storage there costs 10× more). Served by the CloudFront distribution the site already has, cached for a year. Unsaved uploads expire after a day, so they don't pile up. |
| CloudWatch Logs | $0.50/GB ingested; 14 days kept | $0 | The function logs only errors (plus Lambda's own lines per request), and the retention keeps storage near zero. |
| Artifact bucket (per stage) | S3 storage of each deploy's ~200 KB zip, expired after 30 days | ~$0 | Where `aws cloudformation package` uploads the code. |
| IoT Core (live updates) | Connectivity $0.08 per million connection-minutes; messaging $1.00 per million messages (metered in 5 KB units; a hint is under 100 bytes, so 1 unit), counted once when the API publishes and once per delivery (so about $2 per million hints), plus a few messages per connection (connect, subscribe); no charge for the custom authorizer itself; no endpoint or broker fee | $0 | See [Live updates' cost](#live-updates-cost). |
| Authorizer Lambda, arm64, 128 MB | $0.20 per million invocations + GB-seconds: one at each connect and one an hour per open connection (`refreshAfterInSeconds` 3600), ~30 ms each | $0 | A separate tiny function: the API's 256 MB bundle and role would be more than it needs. Hourly refresh, not every few minutes: sign-out reaches open connections within the hour at a twelfth of the invocations of a 5-minute refresh. |

No NAT gateways, VPCs, provisioned capacity, KMS keys (AWS-owned keys
encrypt the table and buckets) or always-on compute. A month with a few
thousand users' worth of requests (say a million API calls) costs about a
dollar for the API and a little more for DynamoDB.

### Live updates' cost

Per person with the app open for an hour: 60 connection-minutes
($0.0000048), one or two authorizer invocations (~$0.0000003), and the
hints about them (a busy chat, 100 hints an hour: $0.0002). About **half
a cent per thousand person-hours online**, before hints.

What it replaces: the app polled every 15 s (my plans, requests,
notifications and the open tab: ~4 API calls) and an open chat every
3 s, about **1,000–2,200 requests per person-hour**. Each request costs
about $2 per million all told (HTTP API $1, Lambda ~$0.4, a session read
and the route's reads in DynamoDB ~$0.6), so **$0.002–0.004 per
person-hour**. With live updates the safety-net polling (2 minutes; a
chat every minute) is ~30–90 requests an hour (~$0.0001), plus the IoT
cost above: roughly **20–30× cheaper per open hour**, and changes show in
well under a second instead of up to 15 s. Idle (nobody online), it's $0,
like everything else here.

Alternatives considered:

- **API Gateway WebSocket APIs**: $1 per million messages (32 KB units)
  and **$0.25 per million connection-minutes** (3× IoT's), and the API
  would have to keep its own connection table (a DynamoDB write on every
  connect and disconnect, a query per fan-out) and post to each
  connection through the `@connections` API. IoT Core does the topic
  fan-out and the per-topic authorization itself.
- **Cloudflare Durable Objects** (WebSocket hibernation): cheap per
  request, but a second platform and account, a cross-cloud hop from the
  Lambda for every hint, and its own auth to keep in step with the API's
  sessions.
- **AppSync Events**: priced like IoT Core ($1 per million operations,
  $0.08 per million connection-minutes); IoT Core's custom authorizer
  returns an explicit per-climber policy (connect, subscribe, receive),
  which keeps the "only my own topic" rule in one small, tested place.
- **Polling faster** instead: costs grow with every second of every open
  app, whether anything changed or not.
