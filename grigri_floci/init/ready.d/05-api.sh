#!/bin/sh
# Deploys the Grigri API (grigri_api/template.yaml, built on the host by
# scripts/build-api.sh and mounted at /opt/grigri-api) into Floci as the
# stack grigri-local-api: the same Lambda, HTTP API and DynamoDB table as
# in AWS, plus the photos bucket (site.yaml's, in AWS, with the same
# lifecycle rule for photos never saved to a profile). Floci runs the
# function in a Docker container (hence the Docker socket in compose.yaml);
# the function verifies Google ID tokens itself (POST /api/session) against
# Google's keys and issues its own sessions. Then it loads the made-up test
# data (the seed: grigri_api/seed/), as RC has; production never gets it.
#
# CloudFront only reaches private origins allowlisted by exact name
# (compose.yaml), so the HTTP API gets the fixed ID "grigri" (the
# template's floci:override-id tag, local only): its host,
# grigri.execute-api.localhost.floci.io, is written to
# /tmp/grigri-api-host, which 10-cloudfront.sh routes /api/* to.
#
# Without GOOGLE_WEB_CLIENT_ID (.env) the API runs in dev mode: the caller
# is whoever X-Grigri-Dev-User names, or a session from POST /api/session
# with {"devUser": "<email>"}. The template refuses dev mode outside
# Stage=local. Admins: GRIGRI_ADMIN_EMAILS from .env.
#
# Live updates: the app connects to Floci's own MQTT broker over WebSocket,
# wss://<public host>:<HTTPS port>/mqtt (the same port and certificate as
# the site), and the function publishes hints to it over MQTT. Floci has
# no IoT custom authorizers, so the local broker is open, like dev mode
# (specs/dev-environment.md, "Live updates").
set -eu

SRC=/opt/grigri-api
STACK=grigri-local-api
PHOTOS=grigri-local-photos
ARTIFACTS=grigri-local-artifacts
API_ID=grigri
rm -f /tmp/grigri-api-host

if [ ! -f "$SRC/template.yaml" ] || [ ! -f "$SRC/dist/index.mjs" ]; then
  echo "grigri: no API build in $SRC (scripts/build-api.sh); no local API" >&2
  exit 0
fi

CLIENT_ID="${GOOGLE_WEB_CLIENT_ID:-}"
DEV_MODE=false
if [ -z "$CLIENT_ID" ]; then
  DEV_MODE=true
  echo "grigri: GOOGLE_WEB_CLIENT_ID isn't set (.env); API in dev mode (X-Grigri-Dev-User, devUser sessions)" >&2
fi
# Spaces dropped: the parameter takes a bare comma-separated list.
ADMINS="$(printf '%s' "${GRIGRI_ADMIN_EMAILS:-}" | tr -d ' ')"

# The host's CPU, so Floci runs the Lambda without emulation (arm64 on
# Apple silicon, x86_64 elsewhere).
case "$(uname -m)" in
  aarch64 | arm64) ARCH=arm64 ;;
  *) ARCH=x86_64 ;;
esac

# Starts Floci's MQTT broker (live updates), if it isn't already.
aws iot describe-endpoint --endpoint-type iot:Data-ATS >/dev/null
aws s3 mb "s3://$ARTIFACTS" >/dev/null
aws s3 mb "s3://$PHOTOS" >/dev/null
# The local web app's origins post uploads to Floci's S3 directly.
aws s3api put-bucket-cors --bucket "$PHOTOS" --cors-configuration "{
  \"CORSRules\": [{
    \"AllowedOrigins\": [\"https://${GRIGRI_PUBLIC_HOST:-local.grigri.nu01.com}:${FLOCI_HTTPS_PORT_HOST:-2543}\",
                         \"https://${GRIGRI_CDN_ALIAS:-grigri.localhost}:${FLOCI_HTTPS_PORT_HOST:-2543}\",
                         \"http://${GRIGRI_CDN_ALIAS:-grigri.localhost}:${FLOCI_PORT_HOST:-2114}\",
                         \"http://localhost:${FLUTTER_WEB_PORT:-7189}\"],
    \"AllowedMethods\": [\"POST\", \"GET\", \"HEAD\"],
    \"AllowedHeaders\": [\"*\"],
    \"MaxAgeSeconds\": 3000
  }]
}"
# As in AWS (site.yaml): uploads are tagged pending until a profile saves
# them; pending ones expire after a day.
aws s3api put-bucket-lifecycle-configuration --bucket "$PHOTOS" --lifecycle-configuration '{
  "Rules": [{
    "ID": "expire-pending-photos",
    "Status": "Enabled",
    "Filter": {"And": {"Prefix": "photos/", "Tags": [{"Key": "grigri-pending", "Value": "true"}]}},
    "Expiration": {"Days": 1}
  }]
}'

aws cloudformation package --template-file "$SRC/template.yaml" \
  --s3-bucket "$ARTIFACTS" --output-template-file /tmp/grigri-api.yaml >/dev/null
set -- "Stage=local" "DevMode=$DEV_MODE" "PhotosBucket=$PHOTOS" "Architecture=$ARCH" "Version=local" \
  "PhotosUploadUrl=https://localhost:${FLOCI_HTTPS_PORT_HOST:-2543}/$PHOTOS" \
  "IotEndpoint=${GRIGRI_PUBLIC_HOST:-local.grigri.nu01.com}:${FLOCI_HTTPS_PORT_HOST:-2543}"
[ -n "$CLIENT_ID" ] && set -- "$@" "GoogleWebClientId=$CLIENT_ID"
[ -n "$ADMINS" ] && set -- "$@" "AdminEmails=$ADMINS"
aws cloudformation deploy --stack-name "$STACK" --template-file /tmp/grigri-api.yaml \
  --capabilities CAPABILITY_NAMED_IAM --parameter-overrides "$@" >/dev/null

# Floci's CloudFormation skips the table's TimeToLiveSpecification; its
# DynamoDB takes the call itself. (The function checks expiry anyway.)
aws dynamodb update-time-to-live --table-name "$STACK" \
  --time-to-live-specification Enabled=true,AttributeName=ttl >/dev/null

api=$(aws cloudformation describe-stacks --stack-name "$STACK" \
  --query "Stacks[0].Outputs[?OutputKey=='ApiId'].OutputValue" --output text)
if [ "$api" != "$API_ID" ]; then
  echo "grigri: the API got ID $api, not $API_ID; CloudFront won't reach it" >&2
  exit 1
fi

# The made-up test data (also the first call, which starts the function's
# container). Floci keeps nothing between starts, so it's fresh each time.
aws lambda invoke --function-name "$STACK" --cli-binary-format raw-in-base64-out \
  --payload '{"grigriSeed":true}' /tmp/grigri-seed.json >/dev/null
if ! grep -q '"seeded"' /tmp/grigri-seed.json; then
  echo "grigri: seeding failed: $(head -c 500 /tmp/grigri-seed.json)" >&2
  exit 1
fi
echo "grigri: seeded: $(cat /tmp/grigri-seed.json)"

echo "$api.execute-api.localhost.floci.io" > /tmp/grigri-api-host
mode=google; [ "$DEV_MODE" = true ] && mode=dev
echo "grigri: API $api deployed ($STACK, $mode mode)"
