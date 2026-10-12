# grigri_infra

The production (and release-candidate) infrastructure, as CloudFormation
templates.

| Template | Stack | Holds |
|---|---|---|
| [site.yaml](site.yaml) | `grigri-web` | https://grigri.nu01.com: the ACM certificate (DNS-validated in the `grigri.nu01.com` zone), a private S3 bucket, the private photos bucket (`grigri-web-photos-<account>`), a CloudFront distribution with its response headers policies (CSP, Permissions-Policy), the Route 53 A/AAAA aliases, and Route 53 health checks of `/app/version.json` and `/api/health` whose alarms email `GRIGRI_HEALTH_EMAILS` when they fail |
| [../grigri_api/template.yaml](../grigri_api/template.yaml) | `grigri-api` | The API: its Lambda (which verifies Google ID tokens and issues the API's own sessions), HTTP API, DynamoDB table (with TTL) and log group ([specs/backend.md](../specs/backend.md)) |
| [github-deploy.yaml](github-deploy.yaml) | `grigri-github-deploy` | The `grigri-github-deploy` role (Deploy workflow, `*GA` tags) and the `grigri-github-deploy-rc` role (Deploy RC workflow: `*RC*` tags and manual runs from `main`), trusting GitHub's OIDC provider; per stage, from one `Fn::ForEach` definition: the deploy policies (site, API), the permissions boundary of the stage's roles (`<prefix>-app-boundary`) and the artifact bucket (`<prefix>-artifacts-<account>`) |

`scripts/deploy.sh` deploys `grigri-api`, then `grigri-web`. With
`STAGE=rc` it deploys the release candidate's own copies, `grigri-rc-api`
(seeded with made-up test data) and `grigri-rc-web`, for
https://rc.grigri.nu01.com; `*RC*` tags do that through
[deploy-rc.yml](../.github/workflows/deploy-rc.yml).

## The distribution

| Path | Origin |
|---|---|
| default (`/`) | S3 `index.html`, the [index page](../grigri_index) that redirects to `/app/` |
| `/app*` | S3 `app/`, the Flutter web build (`--base-href /app/`). A CloudFront Function redirects `/app` to `/app/` and maps directory URIs to `index.html` |
| `/api/*` | The `<prefix>-api` HTTP API: nothing cached, every viewer header but `Host` forwarded (`Authorization` included), all methods |
| `/photos/*` | The photos bucket's `photos/` (origin access control), cached at the edge (keys are never reused) |

Every file is uploaded with `Cache-Control: no-cache`, because Flutter's web
files aren't content-hashed. Each deploy also invalidates `/*`.

## Deploying

Push a GA tag (`bash scripts/release-ga.sh`, on `main`). The
[Deploy workflow](../.github/workflows/deploy.yml) checks the tag's commit
is on `main`, then runs [scripts/deploy.sh](../scripts/deploy.sh), which:

1. builds the web app for `/app/`;
2. tests, builds and deploys the API (`grigri_api/template.yaml`, stack
   `grigri-api`); never seeds production, seeds the RC;
3. deploys `site.yaml` (certificate and distribution tagged with the
   stage, `/api/*` to the API);
4. uploads the content and invalidates the cache;
5. checks that `https://grigri.nu01.com/app/version.json` reports the
   tag's version, `/` is the index page and `/api/health` reports the
   stage and version.

If any step fails it prints the version that was live before and how to
redeploy it. `scripts/deploy.sh` also runs by hand with admin credentials
(inside devbox): `TAG=0.1.<Z>-GA bash scripts/deploy.sh`.

## DNS

`grigri.nu01.com` has its own public Route 53 zone (`HOSTED_ZONE_ID`),
delegated from the `nu01.com` zone by an NS record (TTL 3600), like
`tabscan`, `rbacr` and `uplink`. Both stages' records live in it:
`grigri.nu01.com`, `rc.grigri.nu01.com`, and their ACM validation names.

## One-time setup

0. Create the zone and its delegation:

   ```bash
   aws route53 create-hosted-zone --name grigri.nu01.com --caller-reference "grigri-$(date -u +%s)"
   # then, in the nu01.com zone, an NS record for grigri.nu01.com with
   # the new zone's four name servers
   ```

1. Deploy the GitHub roles. They're IAM resources, so an administrator
   deploys them, once. The account already has GitHub's OIDC provider
   (from `presence-github-deploy`); in an account without it, add
   `CreateOidcProvider=true`:

   ```bash
   aws cloudformation deploy --region us-east-1 \
     --stack-name grigri-github-deploy \
     --template-file grigri_infra/github-deploy.yaml \
     --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
     --parameter-overrides "HostedZoneId=$HOSTED_ZONE_ID"
   ```

   The prod role trusts only tokens for `*GA` tags, the RC role `*RC*`
   tags and `main`, each in both subject forms: `repo:prodbytes/grigri:ref:…`
   and the immutable `repo:prodbytes@288014477/grigri@1415803699:ref:…`
   (`GitHubImmutableRepository`; the repository uses immutable OIDC
   subject claims). Each stage's policies cover its own `<prefix>-*`
   stacks, buckets, alarms and topics; CloudFront distributions and ACM
   certificates only with its `grigri:stage` tag; and DNS records only
   under its domain. For the API (`ApiDeployPolicy`): its `<prefix>-*`
   Lambda functions, DynamoDB tables (create, update and describe only:
   no deleting, no item access), `/aws/lambda/<prefix>-*` log groups, HTTP
   APIs (they have only IDs, so any in the account, as in presence), and
   `<prefix>-*` IAM roles, which it can create or give permissions only
   with the stage's permissions boundary, `<prefix>-app-boundary`, on
   them; for live updates, IoT custom authorizers named `<prefix>-*`
   (create, update, delete, describe, tags) and `iot:DescribeEndpoint`
   (the deploy looks the endpoint up). The boundary allows only the
   stage's tables' items, its function logs, uploads under its photos
   bucket's `photos/`, and publishing to its own climbers' MQTT topics
   (`grigri/<stage>/climbers/*`), so
   whatever a deploy writes into a role's policy, the role can't do more;
   removing a boundary is denied. Also denied: the artifact buckets'
   settings, and the photos buckets' objects (a deploy never reads or
   deletes people's photos). The only function a deploy role may invoke
   is `grigri-rc-api` (the RC seed). Run the same command again whenever
   `github-deploy.yaml` changes, before the next deploy. **Live updates
   need it** (the IoT permissions above): without it, the next deploy
   fails at the endpoint lookup or the authorizer. The deploy scripts
   also check that the boundary and the artifact bucket exist.

2. Add the local development name, `local.grigri.nu01.com`, pointing at
   this machine (`127.0.0.1` and `::1`), for local HTTPS through Floci
   ([grigri_floci/](../grigri_floci)) and OAuth origins that need a
   public top-level domain:

   ```bash
   aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" \
     --change-batch '{"Changes": [
       {"Action": "UPSERT", "ResourceRecordSet": {"Name": "local.grigri.nu01.com", "Type": "A", "TTL": 300, "ResourceRecords": [{"Value": "127.0.0.1"}]}},
       {"Action": "UPSERT", "ResourceRecordSet": {"Name": "local.grigri.nu01.com", "Type": "AAAA", "TTL": 300, "ResourceRecords": [{"Value": "::1"}]}}]}'
   ```

3. Set the repository variables and secrets:

   ```bash
   gh variable set AWS_DEPLOY_ROLE_ARN --body "<DeployRoleArn>"
   gh variable set AWS_DEPLOY_RC_ROLE_ARN --body "<RcDeployRoleArn>"
   gh variable set HOSTED_ZONE_ID --body "<the grigri.nu01.com zone ID>"
   # Each stage's Google web OAuth client (Google Cloud console >
   # Credentials), whose ID tokens its API trades for sessions; public
   # identifiers. Authorized JavaScript origins: https://grigri.nu01.com
   # for production's, https://rc.grigri.nu01.com for the RC's. The iOS
   # clients are optional until iOS releases sign in.
   gh variable set GOOGLE_WEB_CLIENT_ID --body "<number>-<id>.apps.googleusercontent.com"
   gh variable set GOOGLE_WEB_CLIENT_ID_RC --body "<number>-<id>.apps.googleusercontent.com"
   gh variable set GOOGLE_IOS_CLIENT_ID --body "<number>-<id>.apps.googleusercontent.com"
   gh variable set GOOGLE_IOS_CLIENT_ID_RC --body "<number>-<id>.apps.googleusercontent.com"
   # Secrets, not variables: the repository is public, and run logs show
   # variables.
   gh secret set GRIGRI_HEALTH_EMAILS --body "<who gets health alarms>"
   # Who may approve or reject any join request (verified Google emails).
   gh secret set GRIGRI_ADMIN_EMAILS --body "<admin emails, comma-separated>"
   ```
