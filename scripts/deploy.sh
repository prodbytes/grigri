#!/usr/bin/env bash
# Deploys the Grigri web app to production, https://grigri.nu01.com, or
# with STAGE=rc to the release-candidate site, https://rc.grigri.nu01.com
# (its own stack, grigri-rc-web):
#   1. builds the Flutter web app for /app/ (make web, WEB_BASE_HREF=/app/)
#   2. tests, builds and deploys the API (grigri_api/template.yaml, stack
#      grigri-api / grigri-rc-api: the Lambda, its HTTP API and the
#      DynamoDB table, and the live updates' IoT custom authorizer, with the
#      account's IoT Data-ATS endpoint). Production starts empty and is never seeded; the
#      RC is seeded with made-up test data after each deploy
#      (scripts/seed.sh)
#   3. deploys the site (CloudFormation grigri_infra/site.yaml:
#      grigri-web: certificate, buckets (site and photos), CloudFront with
#      /api/* to the API, DNS, and the Route 53 health check of
#      /app/version.json with its alarm emails)
#   4. uploads the index page (/) and the web build (/app/), and
#      invalidates the CloudFront cache
#   5. smoke-tests the live site: /app/version.json must report this
#      version, / must be the index page, and /api/health must report this
#      stage and version
# If the deploy fails, it prints the version that was live before and how
# to put it back.
#
# Run by .github/workflows/deploy.yml on *GA tags (deploy-rc.yml on *RC*
# tags, STAGE=rc), or by hand with admin credentials. Settings, from the
# environment:
#   TAG          the release tag, X.Y.Z-GA: its X.Y must match the version
#                files and its Z becomes the build's Z (default: none, so Z
#                is the current time)
#   STAGE        prod (default) or rc
#   AWS_REGION   default us-east-1 (CloudFront certificates live there)
#   SKIP_BUILD   1 to deploy an existing grigri_app/build/web
#   HOSTED_ZONE_ID       the Route 53 zone of grigri.nu01.com (default:
#                the repo's .env, from the private repo)
#   GRIGRI_HEALTH_EMAILS who is emailed when the health check fails or
#                recovers, comma-separated (also from .env). Each must
#                confirm AWS's subscription email.
#   GOOGLE_WEB_CLIENT_ID the Google web OAuth client whose ID tokens the
#                API accepts (also from .env; a public identifier)
#   GRIGRI_ADMIN_EMAILS who may approve or reject any join request,
#                comma-separated verified Google emails (also from .env;
#                a secret in CI, since the repository is public)
#   PERMISSIONS_BOUNDARY the API function role's boundary (default: the
#                stage's, arn:aws:iam::<account>:policy/<prefix>-app-boundary)
#   ARTIFACT_BUCKET where the API's code is uploaded (default: the stage's,
#                <prefix>-artifacts-<account>)
# Both come from grigri_infra/github-deploy.yaml.
# Needs the AWS CLI, Python 3, Node.js and Flutter (all in devbox).
set -euo pipefail

cd "$(dirname "$0")/.."
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
STAGE="${STAGE:-prod}"
case "$STAGE" in
  prod)
    stack_prefix=grigri
    DOMAIN=grigri.nu01.com
    ;;
  rc)
    stack_prefix=grigri-rc
    DOMAIN=rc.grigri.nu01.com
    ;;
  *) echo "error: STAGE must be prod or rc (got '$STAGE')" >&2; exit 2 ;;
esac
SITE_STACK=$stack_prefix-web
API_STACK=$stack_prefix-api

if [[ "${TAG:-}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-.*)?$ ]]; then
  export VERSION_Z="${BASH_REMATCH[3]}"
  tag_xy="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
elif [[ -n "${TAG:-}" ]]; then
  echo "error: TAG '$TAG' isn't X.Y.Z[-suffix]" >&2
  exit 2
fi
# Fixes the build number too, so the build and the check below agree.
export BUILD_NUMBER="${BUILD_NUMBER:-$(date -u +%s)}"
source scripts/version.sh
if [[ -n "${tag_xy:-}" && "$tag_xy" != "$VERSION_X.$VERSION_Y" ]]; then
  echo "error: tag $TAG is version $tag_xy, but version.X.txt/version.Y.txt say $VERSION_X.$VERSION_Y" >&2
  exit 1
fi
echo "==> deploying version $VERSION to https://$DOMAIN/ ($STAGE, $AWS_REGION)"

# live_version: what https://$DOMAIN/app/version.json says, or nothing.
live_version() {
  curl -fsS --max-time 20 "https://$DOMAIN/app/version.json?deploy=$BUILD_NUMBER-$1" 2>/dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])' 2>/dev/null
}

# What was live before, so a failed deploy can say how to put it back.
previous="$(live_version before)" || previous=""
if [[ ! "$previous" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  previous=""
fi
echo "    live before: ${previous:-none}"
on_exit() {
  local status=$?
  [[ $status -eq 0 ]] && return
  local kind=GA workflow=deploy.yml prefix=""
  if [[ "$STAGE" == rc ]]; then kind=RC workflow=deploy-rc.yml prefix="STAGE=rc "; fi
  local now
  now="$(live_version failed)" || now=""
  {
    echo
    echo "error: the deploy of $VERSION to https://$DOMAIN/ failed (exit $status)."
    echo "  live before this deploy: ${previous:-none}; live now: ${now:-none}"
    if [[ -n "$previous" ]]; then
      # The previous release's tag, if this checkout has it (CI's may not).
      local tag
      tag="$(git tag --list "$previous-$kind*" 2>/dev/null | tail -1)"
      tag="${tag:-$previous-$kind}"
      echo "  to put $previous back, re-run the $workflow workflow for its tag:"
      if [[ "$STAGE" == rc ]]; then
        echo "    gh workflow run $workflow -f tag=$tag"
      else
        echo "    gh run list --workflow $workflow --branch $tag   # then: gh run rerun <id>"
      fi
      echo "  or by hand, with admin credentials:"
      echo "    git checkout $tag && ${prefix}TAG=$tag bash scripts/deploy.sh"
    fi
  } >&2
}
trap on_exit EXIT

stack_output() { # stack_output <stack> <output key>
  aws cloudformation describe-stacks --stack-name "$1" \
    --query "Stacks[0].Outputs[?OutputKey=='$2'].OutputValue" --output text
}

# Private settings: from the environment, else the private .env.
for name in HOSTED_ZONE_ID GRIGRI_HEALTH_EMAILS GOOGLE_WEB_CLIENT_ID GRIGRI_ADMIN_EMAILS; do
  if [[ -z "${!name:-}" && -f .env ]]; then
    printf -v "$name" '%s' "$(sed -n "s/^$name=//p" .env | tail -1)"
  fi
  if [[ -z "${!name:-}" ]]; then
    echo "error: $name isn't set (environment or .env; see .env.example)" >&2
    exit 1
  fi
done
if [[ ! "$HOSTED_ZONE_ID" =~ ^Z[A-Z0-9]+$ ]]; then
  echo "error: HOSTED_ZONE_ID must be a Route 53 zone ID" >&2
  exit 1
fi
if [[ ! "$GRIGRI_HEALTH_EMAILS" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+(,[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+)*$ ]]; then
  echo "error: GRIGRI_HEALTH_EMAILS must be comma-separated emails" >&2
  exit 1
fi
if [[ ! "$GOOGLE_WEB_CLIENT_ID" =~ ^[0-9]+-[0-9a-z]+\.apps\.googleusercontent\.com$ ]]; then
  echo "error: GOOGLE_WEB_CLIENT_ID must be a Google OAuth client ID (<number>-<id>.apps.googleusercontent.com)" >&2
  exit 1
fi
if [[ ! "$GRIGRI_ADMIN_EMAILS" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+(,[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+)*$ ]]; then
  echo "error: GRIGRI_ADMIN_EMAILS must be comma-separated emails" >&2
  exit 1
fi
# Emails are people's: logged only as a count.
echo "    health alarm emails: $(tr ',' '\n' <<<"$GRIGRI_HEALTH_EMAILS" | grep -c .)"
echo "    admins: $(tr ',' '\n' <<<"$GRIGRI_ADMIN_EMAILS" | grep -c .)"

# The stage's permissions boundary and artifact bucket (grigri-github-deploy).
account="$(aws sts get-caller-identity --query Account --output text)"
PERMISSIONS_BOUNDARY="${PERMISSIONS_BOUNDARY:-arn:aws:iam::$account:policy/$stack_prefix-app-boundary}"
ARTIFACT_BUCKET="${ARTIFACT_BUCKET:-$stack_prefix-artifacts-$account}"
if ! aws iam get-policy --policy-arn "$PERMISSIONS_BOUNDARY" >/dev/null 2>&1; then
  echo "error: the permissions boundary $PERMISSIONS_BOUNDARY doesn't exist (or isn't readable)." >&2
  echo "  Redeploy grigri_infra/github-deploy.yaml (grigri_infra/README.md, one-time setup)." >&2
  exit 1
fi
if ! aws s3api head-bucket --bucket "$ARTIFACT_BUCKET" >/dev/null 2>&1; then
  echo "error: the artifact bucket $ARTIFACT_BUCKET doesn't exist (or isn't readable)." >&2
  echo "  Redeploy grigri_infra/github-deploy.yaml (grigri_infra/README.md, one-time setup)." >&2
  exit 1
fi
# Live updates: the account's IoT Data-ATS endpoint, where the app connects
# (MQTT over WebSocket). The API tells the app (GET /api/realtime) and the
# site's CSP allows it (connect-src).
IOT_ENDPOINT="$(aws iot describe-endpoint --endpoint-type iot:Data-ATS --query endpointAddress --output text)"
if [[ ! "$IOT_ENDPOINT" =~ ^[a-z0-9-]+\.iot\.[a-z0-9-]+\.amazonaws\.com$ ]]; then
  echo "error: unexpected IoT endpoint '$IOT_ENDPOINT'" >&2
  exit 1
fi
echo "    IoT endpoint: $IOT_ENDPOINT"
# The site stack's photos bucket (site.yaml names it so), which the API,
# deployed first, presigns uploads to.
PHOTOS_BUCKET="$SITE_STACK-photos-$account"

# 1. The web app
if [[ "${SKIP_BUILD:-}" != 1 ]]; then
  echo "==> building the web app for /app/"
  WEB_BASE_HREF=/app/ GRIGRI_STAGE="$STAGE" bash scripts/make.sh web
fi
# The RC's own title, so its tabs never pass for production's (the app
# sets the same one, AppVersion.title, once it starts).
if [[ "$STAGE" == rc ]]; then
  python3 - <<'PY'
import json
web = "grigri_app/build/web"
with open(f"{web}/index.html", encoding="utf-8") as f:
    html = f.read()
html = html.replace("<title>Grigri</title>", "<title>🧪 Grigri RC</title>")
with open(f"{web}/index.html", "w", encoding="utf-8") as f:
    f.write(html)
with open(f"{web}/manifest.json", encoding="utf-8") as f:
    manifest = json.load(f)
manifest["name"] = "🧪 Grigri RC"
manifest["short_name"] = "Grigri RC"
with open(f"{web}/manifest.json", "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=4)
PY
  grep -q '<title>🧪 Grigri RC</title>' grigri_app/build/web/index.html
  echo "    RC title in place"
fi
test -f grigri_app/build/web/index.html
built="$(python3 -c 'import json; print(json.load(open("grigri_app/build/web/version.json"))["version"])')"
if [[ "$built" != "$VERSION" ]]; then
  echo "error: grigri_app/build/web is version $built, not $VERSION" >&2
  exit 1
fi

# 2. The API, before the site, whose CloudFront routes /api/* to it.
echo "==> testing and building the API"
(cd grigri_api && npm ci --no-audit --no-fund && npm run typecheck && npm test && npm run build)
echo "==> deploying $API_STACK"
packaged="$(mktemp -t grigri-api.XXXXXX)"
aws cloudformation package --template-file grigri_api/template.yaml \
  --s3-bucket "$ARTIFACT_BUCKET" --s3-prefix "$API_STACK" \
  --output-template-file "$packaged" >/dev/null
# NAMED_IAM: the function's role is named <stack>-function (the deploy
# roles may only manage <prefix>-* roles, with the boundary).
aws cloudformation deploy --stack-name "$API_STACK" \
  --template-file "$packaged" --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides "Stage=$STAGE" "GoogleWebClientId=$GOOGLE_WEB_CLIENT_ID" \
    "AdminEmails=$GRIGRI_ADMIN_EMAILS" "PhotosBucket=$PHOTOS_BUCKET" \
    "Version=$VERSION" "PermissionsBoundary=$PERMISSIONS_BOUNDARY" \
    "DevMode=false" "Architecture=arm64" "PhotosUploadUrl=" \
    "IotEndpoint=$IOT_ENDPOINT" \
  --no-fail-on-empty-changeset
rm -f "$packaged"
api_domain="$(stack_output "$API_STACK" ApiDomain)"
echo "    API: $api_domain"
# Made-up test data: the RC only. Production starts empty and holds only
# real people's data, so it's never seeded (the function refuses anyway).
if [[ "$STAGE" == rc ]]; then
  echo "==> seeding the RC with made-up test data"
  STAGE=rc bash scripts/seed.sh
fi

# 3. The site
echo "==> deploying $SITE_STACK"
# AUTO_EXPAND: the template's Fn::ForEach (AWS::LanguageExtensions).
aws cloudformation deploy --stack-name "$SITE_STACK" \
  --template-file grigri_infra/site.yaml --capabilities CAPABILITY_AUTO_EXPAND \
  --parameter-overrides "DomainName=$DOMAIN" "Stage=$STAGE" \
    "HostedZoneId=$HOSTED_ZONE_ID" "ApiDomainName=$api_domain" \
    "HealthNotificationEmails=$GRIGRI_HEALTH_EMAILS" "IotEndpoint=$IOT_ENDPOINT" \
  --no-fail-on-empty-changeset
bucket="$(stack_output "$SITE_STACK" SiteBucketName)"
distribution="$(stack_output "$SITE_STACK" DistributionId)"
echo "    bucket: $bucket, distribution: $distribution"

# 4. The content. Flutter's web files aren't content-hashed, so browsers
# revalidate everything (no-cache); CloudFront is invalidated below.
echo "==> uploading"
# The site's own pages (grigri_index/site) at the root; never under app/,
# which is the app's.
aws s3 sync grigri_index/site/ "s3://$bucket/" --exclude "app/*" \
  --cache-control no-cache --only-show-errors
aws s3 sync grigri_app/build/web/ "s3://$bucket/app/" --delete --cache-control no-cache --only-show-errors
invalidation="$(aws cloudfront create-invalidation --distribution-id "$distribution" \
  --paths '/*' --query Invalidation.Id --output text)"
echo "    waiting for invalidation $invalidation"
aws cloudfront wait invalidation-completed --distribution-id "$distribution" --id "$invalidation"

# 5. Smoke test (retried: on a first deploy DNS and the edge take a moment)
echo "==> checking https://$DOMAIN/"
check() {
  local live
  live="$(curl -fsS --max-time 20 "https://$DOMAIN/app/version.json?deploy=$BUILD_NUMBER" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])')" || return 1
  [[ "$live" == "$VERSION" ]] || { echo "    /app/version.json says $live, want $VERSION"; return 1; }
  curl -fsS --max-time 20 "https://$DOMAIN/" | grep -q "location.replace('/app/'" || { echo "    / isn't the index page"; return 1; }
  curl -fsS --max-time 20 -o /dev/null "https://$DOMAIN/app/" || { echo "    /app/ failed"; return 1; }
  local health
  health="$(curl -fsS --max-time 20 "https://$DOMAIN/api/health?deploy=$BUILD_NUMBER" \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["stage"], d["version"])')" \
    || { echo "    /api/health failed"; return 1; }
  [[ "$health" == "$STAGE $VERSION" ]] || { echo "    /api/health says '$health', want '$STAGE $VERSION'"; return 1; }
}
for attempt in $(seq 1 30); do
  if check; then
    echo "==> https://$DOMAIN/ serves version $VERSION (API: $STAGE)"
    exit 0
  fi
  echo "    not yet (attempt $attempt/30); retrying in 20 s"
  sleep 20
done
echo "error: https://$DOMAIN/ didn't serve version $VERSION" >&2
exit 1
