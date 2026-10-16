#!/usr/bin/env bash
# Scores every profile against every upcoming plan it isn't in, with aityx,
# into the stage's match scores table (specs/match-scores.md), by invoking
# the stage's scoring function (<stack>-scorer). Prints the run's summary.
# A run replaces the previous one; the Admin tab previews its best scores.
#
#   STAGE=prod bash scripts/score-matches.sh
#   STAGE=rc bash scripts/score-matches.sh
#   STAGE=local bash scripts/score-matches.sh   # Floci
#
# Costs aityx credits: about $0.33 for the largest run (5,000 pairs, the
# function's cap). The stage needs an aityx key (GRIGRI_AITYX_API_KEY at
# deploy), or the function refuses. Needs the AWS CLI and credentials that
# may invoke the function (an administrator's; the deploy roles may not).
set -euo pipefail

STAGE="${STAGE:-}"
case "$STAGE" in
  prod) function_name=grigri-api-scorer; aws=(aws) ;;
  rc) function_name=grigri-rc-api-scorer; aws=(aws) ;;
  local)
    function_name=grigri-local-api-scorer
    aws=(env AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1
      AWS_ENDPOINT_URL="http://localhost:${FLOCI_PORT:-2114}" aws)
    ;;
  *)
    echo "error: STAGE must be prod, rc or local (got '$STAGE')" >&2
    exit 2
    ;;
esac
export AWS_REGION="${AWS_REGION:-us-east-1}"

out="$(mktemp -t grigri-scores.XXXXXX)"
trap 'rm -f "$out"' EXIT
# A run may take minutes: wait for it (the CLI's default read timeout is 60 s).
error="$("${aws[@]}" lambda invoke --function-name "$function_name" \
  --cli-read-timeout 900 --cli-binary-format raw-in-base64-out --payload '{}' \
  --query FunctionError --output text "$out")"
if [[ -n "$error" && "$error" != None ]]; then
  echo "error: $function_name failed ($error): $(head -c 500 "$out")" >&2
  exit 1
fi
if grep -q '"error"' "$out"; then
  echo "error: $function_name refused: $(head -c 500 "$out")" >&2
  exit 1
fi
echo "grigri: $function_name: $(cat "$out")"
