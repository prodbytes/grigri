# Deploy

The web app is served at https://grigri.nu01.com/app/ (production) and
https://rc.grigri.nu01.com/app/ (release candidate), from a private S3
bucket behind CloudFront ([grigri_infra/site.yaml](../grigri_infra/site.yaml)).
Both names live in the `grigri.nu01.com` Route 53 zone, delegated from
`nu01.com`. `/` is the [index page](../grigri_index), which redirects to
`/app/`.

## Production

A pushed `*GA` tag runs the [Deploy workflow](../.github/workflows/deploy.yml).
It first checks the tag is `X.Y.Z-GA` and its commit is on `main` (and
warns if GitHub can't verify its signature), then runs `scripts/deploy.sh`
for that tag:

1. builds the web app for `/app/` with the tag's version
   (`GRIGRI_STAGE=prod`);
2. deploys the `grigri-web` stack: certificate, bucket, CloudFront, DNS
   records, and a Route 53 health check of `/app/version.json` (it must
   name `grigri_app`) whose alarm emails `GRIGRI_HEALTH_EMAILS`;
3. uploads the index page and the web build (`Cache-Control: no-cache`,
   Flutter's files aren't content-hashed) and invalidates `/*`;
4. checks, for up to 10 minutes, that `/app/version.json` reports the
   version, `/` is the index page and `/app/` answers.

If a step fails, it says which version was live before and how to put it
back (re-run the workflow for its tag, or deploy it by hand). One
production deploy runs at a time; a newer tag waits.

## Release candidates (rc.grigri.nu01.com)

A pushed `*RC*` tag, or a manual run, runs the
[Deploy RC workflow](../.github/workflows/deploy-rc.yml): the same script
with `STAGE=rc`, into its own stack, `grigri-rc-web`. A tag must be
`X.Y.Z-RC` or `X.Y.Z-RC<n>` on `main`; a manual run deploys an RC tag, or
with none, `main`'s commit. The RC's title is "🧪 Grigri RC" in the
browser and the app, so it never passes for production.

## Response headers

CloudFront adds HSTS, `nosniff`, `Referrer-Policy`, `X-Frame-Options: DENY`
and a Content Security Policy:

- `/app*`: scripts from the site and CanvasKit
  (`www.gstatic.com/flutter-canvaskit/`) with `'wasm-unsafe-eval'`, inline
  styles (Flutter injects them), fonts from `fonts.gstatic.com`, and no
  framing. `Permissions-Policy` denies the camera, microphone and
  location until a feature needs them.
- `/`: only the index page's redirect script, by its hash.

## Access

AWS access is keyless: GitHub's OIDC token is exchanged for
`grigri-github-deploy` (only `*GA` tags) or `grigri-github-deploy-rc`
(`*RC*` tags and manual runs from `main`)
([grigri_infra/github-deploy.yaml](../grigri_infra/github-deploy.yaml)).
Each may only touch its stage's `<prefix>-*` stacks, buckets, alarms and
topics, CloudFront distributions and ACM certificates tagged with its
`grigri:stage`, and DNS records under its domain. Origin access controls
and response headers policies take no tags, so they can't be separated by
stage. Repository variables: `AWS_DEPLOY_ROLE_ARN`,
`AWS_DEPLOY_RC_ROLE_ARN`, `HOSTED_ZONE_ID`; repository secret:
`GRIGRI_HEALTH_EMAILS` (a secret because the repository is public and run
logs show variables). One-time setup:
[grigri_infra/README.md](../grigri_infra/README.md).

By hand, with admin credentials: `TAG=0.1.<Z>-GA bash scripts/deploy.sh`
(`STAGE=rc` for the RC; `SKIP_BUILD=1` to reuse a build).
