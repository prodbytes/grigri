# Deploy

The web app is served at https://grigri.nu01.com/app/ (production) and
https://rc.grigri.nu01.com/app/ (release candidate), from a private S3
bucket behind CloudFront ([grigri_infra/site.yaml](../grigri_infra/site.yaml)).
The same distribution serves the [API](api.md) under `/api/*` (the
`<prefix>-api` stack's HTTP API, [grigri_api/template.yaml](../grigri_api/template.yaml))
and people's photos under `/photos/*` (a private bucket); see
[backend.md](backend.md).
Both names live in the `grigri.nu01.com` Route 53 zone, delegated from
`nu01.com`. `/` is the [landing page](landing.md) ([grigri_index](../grigri_index)),
which sends signed-in climbers on to `/app/`.

## Production

A pushed `*GA` tag runs the [Deploy workflow](../.github/workflows/deploy.yml).
It first checks the tag is `X.Y.Z-GA` and its commit is on `main` (and
warns if GitHub can't verify its signature), then runs `scripts/deploy.sh`
for that tag:

1. builds the web app for `/app/` with the tag's version
   (`GRIGRI_STAGE=prod`);
2. type-checks, tests and builds the API (`grigri_api`: `npm ci`,
   `npm run typecheck`, `npm test`, `npm run build`), uploads it to the
   stage's artifact bucket (`aws cloudformation package`) and deploys the
   `grigri-api` stack (function, which verifies Google ID tokens for
   `GOOGLE_WEB_CLIENT_ID` and issues sessions; HTTP API; DynamoDB table
   with TTL; the [origin check](origin-check.md)'s secret, `GRIGRI_ORIGIN_SECRET`
   or derived per stage from `GRIGRI_RBACR_TOKEN`, demanded by the API only
   once the site already sends it (so turning it on takes two deploys);
   admins from rbacr, asked with `GRIGRI_RBACR_TOKEN`, optional:
   without it the deploy warns and nobody is an admin; the
   [match scores](match-scores.md) table and scoring function, with
   `GRIGRI_AITYX_API_KEY` (and `GRIGRI_AITYX_URL`), optional: without it
   the deploy warns and there are no scores; [Premium](premium.md) with
   `GRIGRI_STRIPE_SECRET_KEY` and `GRIGRI_STRIPE_WEBHOOK_SECRET`, and
   `SiteUrl` (`https://<domain>`), optional: without both the deploy
   warns and there's no Premium; the live updates'
   IoT custom authorizer and its function), with the stage's permissions
   boundary on the functions' roles, and the account's IoT Data-ATS
   endpoint, looked up with
   `aws iot describe-endpoint --endpoint-type iot:Data-ATS` and passed to
   both stacks. Production never gets the test seed (it holds real people's data and the demo showcase, which the API writes itself, see [backend](backend.md#the-demo-showcase));
   Before the API, it sets up Grigri's roles in production's rbacr
   ([scripts/rbacr-setup.sh](../scripts/rbacr-setup.sh), with
   `GRIGRI_RBACR_TOKEN`; idempotent), and passes `RoleSuffix` (`-rc` for
   the RC: its own `premium-rc` and `blocked-rc`);
3. deploys the `grigri-web` stack: certificate, site, photos and GriGri
   Pics buckets, CloudFront (with `/api/*` to the API's domain and
   `/pics/*` to GriGri Pics) and DNS records, then loads
   [GriGri Pics](pics.md) (`grigri_api/pics/load.mjs`: only new photos);
4. uploads the index page and the web build (`Cache-Control: no-cache`,
   Flutter's files aren't content-hashed), invalidates `/*` and waits for
   the invalidation, so the new release is live at once (see
   [Caching](#caching));
5. checks, for up to 10 minutes, that `/app/version.json` reports the
   version, `/` is the index page, `/app/` answers, `/api/health`
   reports the stage and version, and `/api/apple/callback` sends a
   form post back to the Android app (a 307 to its intent).

If a step fails, it says which version was live before and how to put it
back (re-run the workflow for its tag, or deploy it by hand). One
production deploy runs at a time; a newer tag waits. A stack whose first
create failed (`ROLLBACK_COMPLETE`, empty) is deleted before the next
deploy creates it again.

Both stacks are deployed with the cost-allocation stack tags
`project=grigri` and `tenancy=GA` (`tenancy=RC` for the RC), which
CloudFormation copies onto every resource that takes tags, so Cost
Explorer can split the bill by product and stage; `grigri-github-deploy`
and the `grigri.nu01.com` zone, which serve both stages, carry
`tenancy=shared`.

## Monitoring

The stacks hold no health checks or alarms. One central monitor for all
nu01 projects, the `nu01-monitor` stack in the nu01 repository, requests
each stage's `/app/version.json` (the web app) and `/api/health` (the
API) every 5 minutes and emails julio+health@nu01.com when one fails.
Both endpoints stay public for it. (Each site stack had two Route 53
HTTPS string-match health checks with CloudWatch alarms and an SNS email
topic; the next deploy of each stage deletes them, and the deploy roles
keep the permissions to do so until then.)

## Release candidates (rc.grigri.nu01.com)

A pushed `*RC*` tag, or a manual run, runs the
[Deploy RC workflow](../.github/workflows/deploy-rc.yml): the same script
with `STAGE=rc`, into its own stacks, `grigri-rc-api` and
`grigri-rc-web`. After deploying `grigri-rc-api` it loads the made-up
test data ([scripts/seed.sh](../scripts/seed.sh), idempotent). A tag must be
`X.Y.Z-RC` or `X.Y.Z-RC<n>` on `main`; a manual run deploys an RC tag, or
with none, `main`'s commit. The RC's title is "🧪 Grigri RC" in the
browser and the app, so it never passes for production.

## Response headers

CloudFront adds HSTS, `nosniff`, `Referrer-Policy`, `X-Frame-Options: DENY`
and a Content Security Policy:

- `/app/*` and `/app`: scripts from the site and CanvasKit
  (`www.gstatic.com/flutter-canvaskit/`) with `'wasm-unsafe-eval'`, inline
  styles (Flutter injects them), fonts from `fonts.gstatic.com`, Google
  Identity Services (`accounts.google.com/gsi/`: script, style, frame and
  calls), Sign in with Apple's JS
  (`appleid.cdn-apple.com/appleauth/static/jsapi/`; its popup is a
  window, so nothing more) and Google account pictures (`lh3.googleusercontent.com`), the
  API, photos and chat videos from the site itself (`'self'`; videos
  fall back to `default-src`), photo and video uploads to the
  photos bucket (`https://<bucket>.s3.us-east-1.amazonaws.com`), [live
  updates](live-updates.md) over WebSocket to the account's IoT endpoint
  (`wss://<id>-ats.iot.us-east-1.amazonaws.com`, the `IotEndpoint`
  parameter), and no framing. `Permissions-Policy` denies the
  microphone, and allows the camera (the [route finder](route-finder.md))
  and location (which fills in [where I climb](matching.md) from the
  browser) to the app itself (`camera=(self)`, `geolocation=(self)`).
- `/`: the [landing page](landing.md)'s own script, stylesheet, images and
  the GriGri Pics catalog (`'self'`, no inline code), and location for
  the page itself (`geolocation=(self)`).
- `/api/*`, `/photos/*` and `/pics/*`: AWS's managed security headers policy.

## Access

AWS access is keyless: GitHub's OIDC token is exchanged for
`grigri-github-deploy` (only `*GA` tags) or `grigri-github-deploy-rc`
(`*RC*` tags and manual runs from `main`)
([grigri_infra/github-deploy.yaml](../grigri_infra/github-deploy.yaml)).
Each may only touch its stage's `<prefix>-*` stacks, buckets, alarms and
topics, CloudFront distributions and ACM certificates tagged with its
`grigri:stage`, and DNS records under its domain; for the API, its
`<prefix>-*` Lambda functions, DynamoDB tables (create and update only:
never delete, never read or write items), `/aws/lambda/<prefix>-*` log
groups, and `<prefix>-*` IAM roles, which it may only create or change
with the stage's permissions boundary (`<prefix>-app-boundary`: the
stage's tables' items, its function logs, photo uploads and reading
GriGri Pics' catalog) on them, so a
deploy can't make a role more powerful than that. It can't remove a
boundary, change the artifact buckets' settings, or touch the photos
buckets' objects. Origin access controls, response headers policies,
cache policies and HTTP APIs have only IDs (no names or tags to scope by), so they can't be
separated by stage. The RC seed is the only invoke allowed
(`grigri-rc-api`). Repository variables: `AWS_DEPLOY_ROLE_ARN`,
`AWS_DEPLOY_RC_ROLE_ARN`, `HOSTED_ZONE_ID`, `GOOGLE_WEB_CLIENT_ID`
(production's Google web client) and `GOOGLE_WEB_CLIENT_ID_RC` (the
RC's);
repository secrets: `GRIGRI_RBACR_TOKEN`, `GRIGRI_AITYX_API_KEY`,
`GRIGRI_STRIPE_SECRET_KEY` and `GRIGRI_STRIPE_WEBHOOK_SECRET` (Stripe's
live mode), and `GRIGRI_STRIPE_SECRET_KEY_RC` and
`GRIGRI_STRIPE_WEBHOOK_SECRET_RC` (test mode, for the RC), and
`GRIGRI_APPLE_PRIVATE_KEY` (the Sign in with Apple key's `.p8`, for both
stages) (secrets because the repository is public and run logs show
variables); optional variables `GRIGRI_AITYX_URL` (aityx's stage, for a
stage key), and `GRIGRI_APPLE_TEAM_ID` and `GRIGRI_APPLE_KEY_ID` (with
the key: revoking Apple tokens on account deletion,
[sign-in.md](sign-in.md#configuration-the-owner-does); without all
three the deploy warns and Apple tokens aren't revoked). One-time setup:
[grigri_infra/README.md](../grigri_infra/README.md).

By hand, with admin credentials: `TAG=0.1.<Z>-GA bash scripts/deploy.sh`
(`STAGE=rc` for the RC; `SKIP_BUILD=1` to reuse a build).

## Caching

The index page (`/`) and the web app (`/app/*`, `/app`) are uploaded with
`Cache-Control: no-cache`: browsers revalidate every file each time the
app opens (~35 files), so they never run a stale build. CloudFront keeps
them anyway, with the site's own cache policy (`SiteFilesCachePolicy`:
MinTTL and DefaultTTL a day, no cookies, headers or query strings in the
key, gzip and Brotli). MinTTL overrides `no-cache` at the edge only;
CloudFront passes the header on to browsers unchanged, so their
revalidations get a 304 from the edge instead of a GET to S3 each. Every
deploy invalidates `/*` and waits for it, so the new release, its
`version.json` included, is what the edge serves from then on. Anything
that changes the site bucket's files must invalidate them too.

Cost: the cache policy is free. S3 sees at most one GET per file per
edge location a day (was one per file per app open, $0.0004 per 1,000:
~$0.014 per 1,000 opens). Invalidating `/*` is one path, inside the
1,000 free a month. The browsers' revalidations are still CloudFront
requests (free up to 10 million a month, then $1 per million), as they
were.

Photos (`/photos/*`) and GriGri Pics (`/pics/*`) keep
Managed-CachingOptimized: their keys are never reused, so they follow
their own `max-age` (people's uploads a year, the sample ads' photos a
day). The API (`/api/*`) is never cached.
