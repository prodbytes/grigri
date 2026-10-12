#!/usr/bin/env bash
# Loads Grigri's made-up test data (grigri_api/seed/: climbers who are
# nobody real, their plans and a few open requests) into the RC or the
# local stack, by invoking the stage's API function with
# {"grigriSeed": true}. Idempotent: re-running refreshes the seed's own
# records and their dates; real people's data is never touched.
#
# Never production: GA starts empty and holds only real data. This script
# refuses STAGE=prod, and so does the function (by its stage and its
# table's name), and the production deploy role may not invoke it.
#
#   STAGE=rc bash scripts/seed.sh      # run by scripts/deploy.sh after RC deploys
#   STAGE=local bash scripts/seed.sh   # Floci (its ready hook seeds on start too)
#
# Needs the AWS CLI. Local: Floci on FLOCI_PORT (2114), with its test
# credentials; RC: credentials that may invoke grigri-rc-api.
set -euo pipefail

STAGE="${STAGE:-}"
case "$STAGE" in
  rc)
    function_name=grigri-rc-api
    export AWS_REGION="${AWS_REGION:-us-east-1}"
    aws=(aws)
    ;;
  local)
    function_name=grigri-local-api
    aws=(env AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1
      AWS_ENDPOINT_URL="http://localhost:${FLOCI_PORT:-2114}" aws)
    ;;
  prod)
    echo "error: production is never seeded: it starts empty and holds only real people's data" >&2
    exit 2
    ;;
  *)
    echo "error: STAGE must be rc or local (got '$STAGE')" >&2
    exit 2
    ;;
esac

out="$(mktemp -t grigri-seed.XXXXXX)"
trap 'rm -f "$out"' EXIT
error="$("${aws[@]}" lambda invoke --function-name "$function_name" \
  --cli-binary-format raw-in-base64-out --payload '{"grigriSeed":true}' \
  --query FunctionError --output text "$out")"
if [[ -n "$error" && "$error" != None ]]; then
  echo "error: seeding $function_name failed ($error): $(head -c 500 "$out")" >&2
  exit 1
fi
echo "grigri: seeded $function_name: $(cat "$out")"
