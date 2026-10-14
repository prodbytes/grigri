# Deploy

The web app is served at https://grigri.nu01.com/app/ (production) and
https://rc.grigri.nu01.com/app/ (release candidate), from a private S3
bucket behind CloudFront ([grigri_infra/site.yaml](../grigri_infra/site.yaml)).
The same distribution serves the [API](api.md) under `/api/*` (the
`<prefix>-api` stack's HTTP API, [grigri_api/template.yaml](../grigri_api/template.yaml))
and people's photos under `/photos/*` (a private bucket); see
[backend.md](backend.md).
Both names live in the apex Route 53 zone `nu01.com`, which the nu01
repo manages (stacks `nu01-route53-zone` and `nu01-dns`, which owns their
A/AAAA aliases and `local.grigri.nu01.com`'s); see [DNS](#dns). `/` is the [index page](../grigri_index), which redirects to
`/app/`.

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
   with TTL; admins from rbacr, asked with `GRIGRI_RBACR_TOKEN`, optional:
   without it the deploy warns and nobody is an admin; the live updates'
   IoT custom authorizer and its function), with the stage's permissions
   boundary on the functions' roles, and the account's IoT Data-ATS
   endpoint, looked up with
   `aws iot describe-endpoint --endpoint-type iot:Data-ATS` and passed to
   both stacks. Production never gets the test seed (it holds real people's data and the demo showcase, which the API writes itself, see [backend](backend.md#the-demo-showcase));
3. deploys the `grigri-web` stack: certificate (validated in
   `nu01.com`), site and photos buckets, and CloudFront (with `/api/*` to
   the API's domain);
4. uploads the index page and the web build (`Cache-Control: no-cache`,
   Flutter's files aren't content-hashed) and invalidates `/*`;
5. checks, for up to 10 minutes, that `/app/version.json` reports the
   version, `/` is the index page, `/app/` answers, and `/api/health`
   reports the stage and version.

If a step fails, it says which version was live before and how to put it
back (re-run the workflow for its tag, or deploy it by hand). One
production deploy runs at a time; a newer tag waits. A stack whose first
create failed (`ROLLBACK_COMPLETE`, empty) is deleted before the next
deploy creates it again.

Both stacks are deployed with the cost-allocation stack tags
`project=grigri` and `tenancy=GA` (`tenancy=RC` for the RC), which
CloudFormation copies onto every resource that takes tags, so Cost
Explorer can split the bill by product and stage; `grigri-github-deploy`,
which serves both stages, carries `tenancy=shared`.

## DNS

grigri has no Route 53 zone of its own anymore: `grigri.nu01.com`'s
(`Z087054988V7QH92N1FX`) is being merged into the apex zone `nu01.com`
(`Z04838091YTBIM6PNI1XK`) to save its $0.50/month. Round 1, in the nu01
repo (`scripts/migrate-subzone.sh`, then the `nu01-dns` stack), removed
the delegation and put the site's aliases and the certificates'
validation CNAMEs in `nu01.com`. Round 2 is this repo's: `site.yaml`
validates the certificate in `nu01.com` (the `ValidationZoneId`
parameter, which `scripts/deploy.sh` passes; changing it replaces each
stage's certificate, validated with the same `_<token>` CNAME round 1
copied) and holds no DNS records. Round 2 must not be released before
round 1 + 48 hours (`migrate-subzone.sh` prints the exact time), while
resolvers may still cache the old zone's NS records; an administrator
redeploys `grigri-github-deploy` first. After round 2 has deployed on
both stages, an administrator empties and deletes the old zone and drops
it from the deploy roles: the steps are in
[grigri_infra/README.md](../grigri_infra/README.md#dns).

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

- `/app*`: scripts from the site and CanvasKit
  (`www.gstatic.com/flutter-canvaskit/`) with `'wasm-unsafe-eval'`, inline
  styles (Flutter injects them), fonts from `fonts.gstatic.com`, Google
  Identity Services (`accounts.google.com/gsi/`: script, style, frame and
  calls) and Google account pictures (`lh3.googleusercontent.com`), the
  API, photos and chat videos from the site itself (`'self'`; videos
  fall back to `default-src`), photo and video uploads to the
  photos bucket (`https://<bucket>.s3.us-east-1.amazonaws.com`), [live
  updates](live-updates.md) over WebSocket to the account's IoT endpoint
  (`wss://<id>-ats.iot.us-east-1.amazonaws.com`, the `IotEndpoint`
  parameter), and no framing. `Permissions-Policy` denies the camera and
  microphone, and allows location to the app itself (`geolocation=(self)`),
  which fills in [where I climb](matching.md) from the browser.
- `/`: only the index page's redirect script, by its hash.
- `/api/*` and `/photos/*`: AWS's managed security headers policy.

## Access

AWS access is keyless: GitHub's OIDC token is exchanged for
`grigri-github-deploy` (only `*GA` tags) or `grigri-github-deploy-rc`
(`*RC*` tags and manual runs from `main`)
([grigri_infra/github-deploy.yaml](../grigri_infra/github-deploy.yaml)).
Each may only touch its stage's `<prefix>-*` stacks, buckets, alarms and
topics, CloudFront distributions and ACM certificates tagged with its
`grigri:stage`, and in Route 53 only its certificate's validation CNAMEs
in `nu01.com` (`_*.grigri.nu01.com` for production, which covers the
RC's too; `_*.rc.grigri.nu01.com` for the RC), plus its old records in
the retired `grigri.nu01.com` zone until round 2 has deployed on both
stages; for the API, its
`<prefix>-*` Lambda functions, DynamoDB tables (create and update only:
never delete, never read or write items), `/aws/lambda/<prefix>-*` log
groups, and `<prefix>-*` IAM roles, which it may only create or change
with the stage's permissions boundary (`<prefix>-app-boundary`: the
stage's tables' items, its function logs and photo uploads) on them, so a
deploy can't make a role more powerful than that. It can't remove a
boundary, change the artifact buckets' settings, or touch the photos
buckets' objects. Origin access controls, response headers policies and
HTTP APIs have only IDs (no names or tags to scope by), so they can't be
separated by stage. The RC seed is the only invoke allowed
(`grigri-rc-api`). Repository variables: `AWS_DEPLOY_ROLE_ARN`,
`AWS_DEPLOY_RC_ROLE_ARN`, `GOOGLE_WEB_CLIENT_ID`
(production's Google web client) and `GOOGLE_WEB_CLIENT_ID_RC` (the
RC's);
repository secret: `GRIGRI_RBACR_TOKEN` (a secret because the
repository is public and run logs show variables). One-time setup:
[grigri_infra/README.md](../grigri_infra/README.md).

By hand, with admin credentials: `TAG=0.1.<Z>-GA bash scripts/deploy.sh`
(`STAGE=rc` for the RC; `SKIP_BUILD=1` to reuse a build).
