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
| Data | **Real people's data, plus the demo showcase** (fictional, marked demo). Never gets the test seed | Made-up test data, re-seeded after each RC deploy, beside testers' real data | Made-up test data, seeded on every Floci start (Floci keeps nothing) |
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
  presigned POSTs (≤ 2 MB, JPEG/PNG/WebP, 15 minutes) that the API issues
  for the caller's own folder, and read through CloudFront with origin
  access control. The chat's photos and videos live there too
  ([chat media](#chat-media)). Keys are random and never reused, so photos are cached
  at the edge and in browsers for a year. The bucket allows POST uploads
  from the stage's site origin (CORS); the web app's CSP allows the
  bucket's URL in `connect-src`. Uploads arrive tagged
  `grigri-pending=true` (a field of the presigned POST); saving a profile
  clears the tag of its new photos and deletes the photos it no longer
  uses, and a lifecycle rule expires pending photos after a day, so photos
  never saved to a profile go away. Saved photos stay until replaced;
  failed multipart uploads are cleaned up too.
- **Chat media**: see [below](#chat-media).
- **Plan photos** ([pics.md](pics.md)): a plan's Your Pics live in the
  photos bucket under `photos/plans/<planId>/` (uploaded like chat media,
  kept 400 days by a lifecycle rule) and as `PIC#` items in the plan's
  partition; photos sent in the chat join them. **GriGri Pics**, Grigri's
  own crag photos, have their own bucket in the site stack
  (`<site stack>-pics-<account>`, never people's data), served at
  `/pics/*`, with each photo's metadata in an S3 annotation; the function
  reads only its catalog, `pics/catalog.json`, once per warm instance.
- **Auth: the API's own sessions** ([api.md](api.md#sessions)). Sign-in
  sends a Google ID token once to `POST /api/session`; the function
  verifies it (with [jose](https://github.com/panva/jose): RS256 against
  Google's keys, cached while the function stays warm; issuer, audience
  the web client ID or, for iPhones, one of the stage's iOS client IDs,
  expiry) and returns an opaque session token (32
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
  `GET /api/me`, which starts the profile with the account's Google
  name). Emails are only used for the admin check: kept on the session
  (only when verified), never on a profile, never returned. The Google
  name is kept on the session only to start the profile.
- **Admin**: a signed-in caller whose session's verified email holds
  rbacr's `grigri` `admin` role ([roles](roles.md)), checked on every
  request (rbacr's answer is kept 60 s). Admins list everyone and block
  or unblock them ([admin.md](admin.md)): a profile item's `blocked`
  attribute, which shuts its climber out of every route but signing
  out.
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
without its answer "policies". Ids start with `seed-`, and every seed
profile and plan is marked `"demo": true` (stored on the item; the API
never takes it from a request), so the app shows it as a demonstration. It runs inside the
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
plan. It writes the demo showcase too.

## The demo showcase

[grigri_api/seed/showcase.ts](../grigri_api/seed/showcase.ts): eleven
fictional climbers organizing twenty plans, one to seven days ahead, so
the app has plans to show while there are few real ones. Six names nod to
late climbing legends without being them (Wolf Gullick, Patrice Edlin,
Kurt Alberts, Roy Robbin, Uli Stack, Dean Potts), five are made up (Nora
Vilaró, Teo Marlin, Anouk Veld, Lars Brekkum, Mei Tanabe); nobody real is
portrayed, and their bios are made up. Six plans are at well-known crags
around the world (Frankenjura, Buoux, Kalymnos, Yosemite, Rio de Janeiro,
Fontainebleau); **seven are in Siurana and seven in Margalef**, at their
sectors' points (sport over a spread of grades, and Margalef's boulders),
so there's plenty to explore there. On **every stage,
production included**; all marked `demo`, with `seed-` ids.

The API keeps it upcoming itself: before building a deck
(`GET /api/discover`), it reads one marker item (`META#SHOWCASE`) and, when
it's over 12 hours old or was written by an older showcase
(`SHOWCASE_VERSION` in [seed.ts](../grigri_api/seed/seed.ts), bumped with
every change to the showcase, so a deploy shows it at once), rewrites the
showcase's climbers and plans with fresh dates (as the seed does: real members stay). A failure is logged and
never fails the deck. No scheduler or new resource: one extra read per
deck and about 35 writes twice a day, well under a cent a month.

## Cost

Cost comes first: **nothing new costs anything while nobody uses it**,
and use is billed per request. Prices are us-east-1's.

| Resource | Price | Idle | Why this one |
|---|---|---|---|
| DynamoDB, on demand | $0.625 per million writes, $0.125 per million reads, $0.25/GB-month (the first 25 GB free); point-in-time recovery $0.20/GB-month, prod only; TTL deletes free | $0 (a few cents of storage at most) | Pay per request with no minimum. **Aurora Serverless v2** costs about **$43/month** at its 0.5 ACU minimum (auto-pause to 0 ACU exists, but resuming takes seconds and storage and I/O still bill); **RDS** bills every hour (a db.t4g.micro is about $12/month plus storage) whether used or not. The access patterns (by plan, by climber, upcoming plans, open requests) fit key lookups, so a relational database buys nothing here. |
| HTTP API | $1.00 per million requests | $0 | REST APIs cost $3.50 per million. No authorizer: the function checks sessions itself. |
| Sessions (in the table) | One eventually consistent read per request (about $0.06 per million requests), one write per session per day of use, a write to sign in or out; the subject index is keys-only, so the daily slide doesn't write to it | $0 | An HTTP API JWT authorizer would be free per request, but it can only check Google's one-hour tokens. A Lambda authorizer would add a second invocation per request; Cognito would add a service and its own pricing beyond its free tier. |
| One Lambda, arm64, 256 MB | $0.20 per million requests + $0.0000133 per GB-second (1 million requests and 400,000 GB-seconds a month free) | $0 | One function with an internal router: one cold start to warm, one log group, one role. arm64 is 20% cheaper than x86. 256 MB keeps a ~50 ms request at well under a cent per thousand. |
| S3 photos bucket | $0.023/GB-month, $0.005 per 1,000 uploads (and per 1,000 tag clears, one per new photo saved or chat attachment sent); deletes and lifecycle expirations free | $0 when empty | Photos and chat media stay out of DynamoDB (400 KB item limit, and storage there costs 10× more). Served by the CloudFront distribution the site already has, cached for a year. Unsaved uploads expire after a day, so they don't pile up; chat media after 400 days. See [chat media](#chat-media). |
| GriGri Pics bucket ([pics.md](pics.md#cost)) | $0.023/GB-month (now ~6 MB: $0.0001); one catalog GET per warm function ($0.0004 per 1,000); loading on deploy, under $0.0001 | ~$0 | Its own bucket keeps app content apart from people's data. A catalog made from the photos' S3 annotations, read once and kept in memory, beats querying: S3 Select is closed to new accounts, and annotation tables with Athena lag up to an hour, take seconds and bill per query. |
| CloudWatch Logs | $0.50/GB ingested; 14 days kept | $0 | The function logs only errors (plus Lambda's own lines per request), and the retention keeps storage near zero. |
| Artifact bucket (per stage) | S3 storage of each deploy's ~200 KB zip, expired after 30 days | ~$0 | Where `aws cloudformation package` uploads the code. |
| IoT Core (live updates) | Connectivity $0.08 per million connection-minutes; messaging $1.00 per million messages (metered in 5 KB units; a hint is under 100 bytes, so 1 unit), counted once when the API publishes and once per delivery (so about $2 per million hints), plus a few messages per connection (connect, subscribe); no charge for the custom authorizer itself; no endpoint or broker fee | $0 | See [Live updates' cost](#live-updates-cost). |
| Premium payments ([premium.md](premium.md#cost)) | Stripe: 2.9% + $0.30 per charge, plus 0.7% Billing; no monthly fee | $0 | Pay per payment; merchants of record take 5% + $0.50, the app stores 15–30%. One subscription item per subscriber in the table. |
| Ads ([ads.md](ads.md#cost)) | Two reads and a small batch read per deck; media as chat media | $0 | In the table and the photos bucket already there; videos load only when played. |
| Match scores ([match-scores.md](match-scores.md#cost)) | aityx System One: $0.042 per million input tokens (about $0.00007 a call, ~1,600 tokens); the scores table on demand; the scoring function only when run by hand | $0 | A decision API keeps the score's weights as data, each rule with its reason; it's called only for admins' decks and on-demand runs. |
| Authorizer Lambda, arm64, 128 MB | $0.20 per million invocations + GB-seconds: one at each connect and one an hour per open connection (`refreshAfterInSeconds` 3600), ~30 ms each | $0 | A separate tiny function: the API's 256 MB bundle and role would be more than it needs. Hourly refresh, not every few minutes: sign-out reaches open connections within the hour at a twelfth of the invocations of a 5-minute refresh. |

No NAT gateways, VPCs, provisioned capacity, KMS keys (AWS-owned keys
encrypt the table and buckets) or always-on compute. A month with a few
thousand users' worth of requests (say a million API calls) costs about a
dollar for the API and a little more for DynamoDB.

### Chat media

A chat message can carry **one photo or one video**, nothing else: JPEG,
PNG or WebP photos (≤ 2 MB; the app downsizes them to 1600 px at 75%
quality, a few hundred KB) and MP4 or QuickTime (MOV) videos (≤ 50 MB;
the camera records at most 30 s where the device lets the app say).

- **Upload**: a member asks `POST /api/plans/{id}/media` (members only,
  only those types) for a presigned POST, as profile photos do. The
  policy fixes the content type and the size cap, so S3 itself refuses
  anything else. The object is `photos/chat/<planId>/<random>.<ext>`,
  tagged pending.
- **Send**: `POST /api/plans/{id}/messages` with the key, which must be
  this plan's; the API clears its pending tag (after checking membership)
  and saves the message. An upload never sent expires after a day (the
  same lifecycle rule as photos).
- **Serve**: like profile photos, through the site's CloudFront at
  `/photos/chat/...`: **public to whoever has the URL, and the URL is
  unguessable** (96 random bits). Only members learn keys, from the
  members-only messages route, but someone who left, or anyone a member
  passes the link to, can still open it until it expires. Objects are
  served with the content type the policy fixed and `nosniff`, so an
  upload can't pass for a page. Cached for a year (keys are never
  reused); videos stream with range requests.
- **Expire**: a lifecycle rule deletes everything under `photos/chat/` 400
  days after its upload. A plan starts at most a year after it's made, so
  that's at least a month after the plan is over. A plan whose last
  member leaves loses its messages at once; its media stays until then
  (deleting it would need list permission on the bucket, for a few cents).

**Why this way.** Serving through CloudFront costs nothing extra: its
always-free tier covers 1 TB out and 10 million requests a month, then
$0.085/GB; S3 to CloudFront is free. The alternatives cost more or add
moving parts: **presigned S3 GETs** pay S3's $0.09/GB beyond the 100 GB a
month AWS gives free, can't be cached at the edge or across loads (a new
URL each time), and need the app to refresh URLs as they expire;
**CloudFront signed URLs or cookies** are free, but need a key pair, its
private key kept as a secret for the function, and a key group in the
distribution, per stage and locally. Keeping chat media consistent with
profile photos was the cheapest option that meets "members see it".

**Estimate.** Say a plan's chat gets 5 photos (~300 KB each) and one
25 MB video, each seen by 4 members:

| | 100 plans a month | 1,000 plans a month |
|---|---|---|
| New storage | 2.7 GB/month | 27 GB/month |
| Storage at steady state (400 days kept) | ~35 GB: **~$0.80/month** | ~350 GB: **~$8/month** |
| Uploads + tag clears + presign requests | 1,200 each: ~$0.01 | ~$0.12 |
| CloudFront transfer (members viewing) | ~11 GB: $0 (free tier) | ~106 GB: $0 (free tier) |

Idle it costs only the storage already there. Pending uploads cost a
day's storage at most. A member flooding a chat with 50 MB videos costs
$0.00115 a month per video kept (the API's throttle caps the rate).

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
