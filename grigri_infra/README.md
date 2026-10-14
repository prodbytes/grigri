# grigri_infra

The production (and release-candidate) infrastructure, as CloudFormation
templates.

| Template | Stack | Holds |
|---|---|---|
| [site.yaml](site.yaml) | `grigri-web` | https://grigri.nu01.com: the ACM certificate (DNS-validated in the `nu01.com` zone), a private S3 bucket, the private photos bucket (`grigri-web-photos-<account>`), and a CloudFront distribution with its response headers policies (CSP, Permissions-Policy). No DNS records: the site's A/AAAA aliases are the nu01 repo's (see [DNS](#dns)). Uptime (`/app/version.json`, `/api/health`) is checked from outside by the central `nu01-monitor` stack (nu01 repo), not here |
| [../grigri_api/template.yaml](../grigri_api/template.yaml) | `grigri-api` | The API: its Lambda (which verifies Google ID tokens and issues the API's own sessions), HTTP API, DynamoDB table (with TTL) and log group ([specs/backend.md](../specs/backend.md)) |
| [github-deploy.yaml](github-deploy.yaml) | `grigri-github-deploy` | The `grigri-github-deploy` role (Deploy workflow, `*GA` tags) and the `grigri-github-deploy-rc` role (Deploy RC workflow: `*RC*` tags and manual runs from `main`), trusting GitHub's OIDC provider; per stage, from one `Fn::ForEach` definition: the deploy policies (site, its Route 53 records, API), the permissions boundary of the stage's roles (`<prefix>-app-boundary`) and the artifact bucket (`<prefix>-artifacts-<account>`) |

`scripts/deploy.sh` deploys `grigri-api`, then `grigri-web`. With
`STAGE=rc` it deploys the release candidate's own copies, `grigri-rc-api`
(seeded with made-up test data) and `grigri-rc-web`, for
https://rc.grigri.nu01.com; `*RC*` tags do that through
[deploy-rc.yml](../.github/workflows/deploy-rc.yml).

Every stack carries the cost-allocation stack tags `project=grigri` and
`tenancy` (`GA` for `grigri-*`, `RC` for `grigri-rc-*`, `shared` for
`grigri-github-deploy`), which CloudFormation copies onto its resources.

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

grigri's DNS lives in the **nu01 repo**: the apex zone `nu01.com`
(`Z04838091YTBIM6PNI1XK`, stack `nu01-route53-zone`) holds every name, and
its `nu01-dns` stack owns the A/AAAA aliases of `grigri.nu01.com` and
`rc.grigri.nu01.com` (to each stage's distribution) and
`local.grigri.nu01.com` (127.0.0.1 and ::1, for local HTTPS). This repo
only validates the site certificates there: `site.yaml`'s
`ValidationZoneId` (which `scripts/deploy.sh` passes as
`Z04838091YTBIM6PNI1XK`) makes CloudFormation write each certificate's
`_<token>` CNAME into `nu01.com`, and the deploy roles may change only
those (`_*.grigri.nu01.com` for production, which also covers the RC's;
`_*.rc.grigri.nu01.com` for the RC; CNAMEs only).

`grigri.nu01.com` used to have its own zone (`Z087054988V7QH92N1FX`,
created with the CLI), delegated from `nu01.com`. It's being merged into
`nu01.com` (to save its $0.50/month) in two rounds:

1. **Round 1** (an administrator, nu01 repo: `scripts/migrate-subzone.sh`
   then a deploy of `nu01-dns`): removes the `grigri.nu01.com` NS
   delegation from `nu01.com`, copies the validation CNAMEs there, and
   adds the aliases. The old zone stays, untouched, while resolvers may
   still cache its NS records.
2. **Round 2** (this repo, the first release with this `site.yaml`):
   each stage's certificate moves to `nu01.com` and the site stacks
   delete their old aliases from the old zone. **Don't release it
   before round 1 + 48 hours** (`migrate-subzone.sh` prints the exact
   time). Before releasing, check that round 1 happened (the `nu01-dns`
   stack exists, and `nu01.com` has `grigri.nu01.com`'s A/AAAA and no NS):

   ```bash
   aws route53 list-resource-record-sets --hosted-zone-id Z04838091YTBIM6PNI1XK \
     --query "ResourceRecordSets[?ends_with(Name, 'grigri.nu01.com.')].[Name,Type]" --output text
   ```

   Then, in this order:
   1. an administrator redeploys `grigri-github-deploy` (the command in
      [One-time setup](#one-time-setup), step 1), so the deploy roles may
      write the validation records in `nu01.com`;
   2. release an RC, then a GA. Each site stack's certificate is
      **replaced** (changing its validation zone requires it):
      CloudFormation requests a new one, validates it through `nu01.com`
      with the same deterministic `_<token>` CNAME round 1 already copied
      (it UPSERTs it, so it's already there and resolving), points the
      distribution at it, then deletes the old certificate. The
      distribution and its domain name stay, so the aliases in `nu01-dns`
      keep working. The stacks' `DnsRecordA`/`DnsRecordAAAA` are deleted
      from the old zone, which nobody asks anymore.

### Retiring the old zone (after round 2, on both stages)

Once both `grigri-web` and `grigri-rc-web` have deployed round 2 and
https://grigri.nu01.com and https://rc.grigri.nu01.com work, an
administrator deletes the old zone. It was created with the CLI (no
stack), so empty it first: Route 53 deletes only a zone with nothing but
its NS and SOA records. What's left are the `local.grigri.nu01.com`
records and the old validation CNAMEs (if CloudFormation didn't delete
them):

```bash
ZONE=Z087054988V7QH92N1FX
# 1. Check: what's left (expect local.grigri.nu01.com A/AAAA and the two
#    _<token> CNAMEs; no grigri.nu01.com or rc.grigri.nu01.com A/AAAA).
aws route53 list-resource-record-sets --hosted-zone-id "$ZONE" \
  --query "ResourceRecordSets[?Type!='NS' && Type!='SOA'].[Name,Type]" --output text
# 2. Delete every record but the NS and SOA, in one batch.
aws route53 list-resource-record-sets --hosted-zone-id "$ZONE" --output json \
  | python3 -c 'import json,sys; r=json.load(sys.stdin)["ResourceRecordSets"]; print(json.dumps({"Changes": [{"Action": "DELETE", "ResourceRecordSet": x} for x in r if x["Type"] not in ("NS", "SOA")]}))' \
  > /tmp/grigri-zone-delete.json
aws route53 change-resource-record-sets --hosted-zone-id "$ZONE" \
  --change-batch file:///tmp/grigri-zone-delete.json
# 3. Delete the zone.
aws route53 delete-hosted-zone --id "$ZONE"
```

Then drop the old zone from the deploy roles (`github-deploy.yaml`: the
`OldZoneRecords` statement, the old zone's ARN in `Zone`, and the
`HostedZoneId` parameter), redeploy `grigri-github-deploy` without
`HostedZoneId`, and delete the repository variable `HOSTED_ZONE_ID`
(`gh variable delete HOSTED_ZONE_ID`), which nothing reads anymore.

## One-time setup

0. DNS: nothing to do here. The site's names are in the `nu01.com`
   zone, managed by the nu01 repo (see [DNS](#dns)).

1. Deploy the GitHub roles. They're IAM resources, so an administrator
   deploys them, once. The account already has GitHub's OIDC provider
   (from `presence-github-deploy`); in an account without it, add
   `CreateOidcProvider=true`:

   ```bash
   aws cloudformation deploy --region us-east-1 \
     --stack-name grigri-github-deploy \
     --template-file grigri_infra/github-deploy.yaml \
     --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
     --parameter-overrides "HostedZoneId=Z087054988V7QH92N1FX" \
     --tags project=grigri tenancy=shared
   ```

   The prod role trusts only tokens for `*GA` tags, the RC role `*RC*`
   tags and `main`, each in both subject forms: `repo:prodbytes/grigri:ref:…`
   and the immutable `repo:prodbytes@288014477/grigri@1415803699:ref:…`
   (`GitHubImmutableRepository`; the repository uses immutable OIDC
   subject claims). Each stage's policies cover its own `<prefix>-*`
   stacks, buckets, alarms and topics; CloudFront distributions and ACM
   certificates only with its `grigri:stage` tag; and, in Route 53
   (`DnsDeployPolicy`, `<prefix>-github-deploy-dns`), only its
   certificate's validation CNAMEs in `nu01.com` (`_*.<its domain>`),
   plus, until round 2 has deployed on both stages, its records in the
   old `grigri.nu01.com` zone (`HostedZoneId`; drop it once the zone is
   retired, see [DNS](#dns)). For the API (`ApiDeployPolicy`): its `<prefix>-*`
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

2. The local development name, `local.grigri.nu01.com` (127.0.0.1 and
   `::1`, for local HTTPS through Floci, [grigri_floci/](../grigri_floci),
   and OAuth origins that need a public top-level domain), is the nu01
   repo's `nu01-dns` stack's, like the site's names.

3. Set the repository variables and secrets:

   ```bash
   gh variable set AWS_DEPLOY_ROLE_ARN --body "<DeployRoleArn>"
   gh variable set AWS_DEPLOY_RC_ROLE_ARN --body "<RcDeployRoleArn>"
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
   # An API token owned by an rbacr root (rbacr.nu01.com > Global > API
   # tokens), with which the API asks rbacr who holds grigri's admin role.
   gh secret set GRIGRI_RBACR_TOKEN
   ```

   In rbacr, a root creates the `grigri` system with an `admin` role and
   grants it to whoever may approve or reject any join request (rbacr's
   roots are admins already).
