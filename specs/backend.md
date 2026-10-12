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
| Sign-in | Google ID tokens (`GOOGLE_WEB_CLIENT_ID`) | Same | Google ID tokens when `.env` has `GOOGLE_WEB_CLIENT_ID`; otherwise **dev mode** |
| Admins | `GRIGRI_ADMIN_EMAILS` (repository secret) | Same | `GRIGRI_ADMIN_EMAILS` in `.env` |
| Backups | Point-in-time recovery (35 days), deletion protection | None | None |

Every environment behaves the same: nobody answers requests automatically.
The made-up climbers can't sign in (they have no Google account), so their
requests and the requests waiting on their plans are answered by testers
who are members, or by an admin.

## Architecture

- **One Lambda** (TypeScript, Node.js 22, arm64, 256 MB, 10 s timeout) with
  an internal router, behind **one HTTP API**. The HTTP API's JWT
  authorizer checks the Google ID token (issuer
  `https://accounts.google.com`, audience the web client ID) on every
  route but `GET /api/health`, before the function runs; the function
  reads the verified claims. Throttled at 50 requests/s (bursts of 100),
  which caps the bill if someone floods it.
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
  bucket's URL in `connect-src`. Nothing expires; only failed multipart
  uploads are cleaned up.
- **Identity**: a Google account (`<iss>#<sub>`) is linked to one climber
  id (random, made by the server at the first profile save). Emails are
  only used for the admin check and are never stored or returned.
- **Admin**: a signed-in caller whose verified email is in the stage's
  admin list. Admins see every open request (`GET /api/admin/requests`)
  and accept (they join at once, as if every member had said yes) or
  reject any.
- **Dev mode** (local only): without a Google client, the local API has
  no authorizer and the caller names themselves in an
  `X-Grigri-Dev-User: <email>` header. The template refuses `DevMode`
  unless `Stage` is `local` (a CloudFormation Rule), and the function
  ignores the header unless its stage is `local`, so neither RC nor GA can
  run it.

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
| DynamoDB, on demand | $0.625 per million writes, $0.125 per million reads, $0.25/GB-month (the first 25 GB free); point-in-time recovery $0.20/GB-month, prod only | $0 (a few cents of storage at most) | Pay per request with no minimum. **Aurora Serverless v2** costs about **$43/month** at its 0.5 ACU minimum (auto-pause to 0 ACU exists, but resuming takes seconds and storage and I/O still bill); **RDS** bills every hour (a db.t4g.micro is about $12/month plus storage) whether used or not. The access patterns (by plan, by climber, upcoming plans, open requests) fit key lookups, so a relational database buys nothing here. |
| HTTP API | $1.00 per million requests | $0 | REST APIs cost $3.50 per million; HTTP APIs have the JWT authorizer built in, so token checks need no Lambda authorizer (and rejected tokens never invoke the function). |
| One Lambda, arm64, 256 MB | $0.20 per million requests + $0.0000133 per GB-second (1 million requests and 400,000 GB-seconds a month free) | $0 | One function with an internal router: one cold start to warm, one log group, one role. arm64 is 20% cheaper than x86. 256 MB keeps a ~50 ms request at well under a cent per thousand. |
| S3 photos bucket | $0.023/GB-month, $0.005 per 1,000 uploads | $0 when empty | Photos stay out of DynamoDB (400 KB item limit, and storage there costs 10× more). Served by the CloudFront distribution the site already has, cached for a year. |
| CloudWatch Logs | $0.50/GB ingested; 14 days kept | $0 | The function logs only errors (plus Lambda's own lines per request), and the retention keeps storage near zero. |
| Artifact bucket (per stage) | S3 storage of each deploy's ~200 KB zip, expired after 30 days | ~$0 | Where `aws cloudformation package` uploads the code. |

No NAT gateways, VPCs, provisioned capacity, KMS keys (AWS-owned keys
encrypt the table and buckets) or always-on compute. A month with a few
thousand users' worth of requests (say a million API calls) costs about a
dollar for the API and a little more for DynamoDB.
