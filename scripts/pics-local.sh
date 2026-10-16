#!/usr/bin/env bash
# Keeps GriGri Pics loaded in the local Floci (specs/pics.md): Floci keeps
# nothing between starts, so whenever its pics bucket (grigri-local-pics,
# made by grigri_floci/init/ready.d/05-api.sh) has no catalog, this loads
# it with grigri_api/pics/load.mjs, from the host: downloads are cached in
# grigri_api/pics/.cache, so only the first run fetches them. Run by
# `devbox services up` (process-compose's 6-pics).
set -euo pipefail

cd "$(dirname "$0")/.."
export AWS_ENDPOINT_URL="http://localhost:${FLOCI_PORT:-2114}"
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1
export PICS_BUCKET=grigri-local-pics
interval="${PICS_CHECK_INTERVAL:-30}"

while true; do
  if aws s3api head-bucket --bucket "$PICS_BUCKET" >/dev/null 2>&1 \
    && ! aws s3api head-object --bucket "$PICS_BUCKET" --key pics/catalog.json >/dev/null 2>&1; then
    node grigri_api/pics/load.mjs || echo "pics: loading failed; retrying in $interval s" >&2
  fi
  sleep "$interval"
done
