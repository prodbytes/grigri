#!/usr/bin/env bash
# Once per stage: adds every existing profile to the table's CLIMBERS index
# partition (gsi1), which the match scoring run lists profiles from
# (specs/match-scores.md). Profiles saved since that index came in are in
# it already; this covers the older ones. Idempotent.
#
#   STAGE=prod bash scripts/index-climbers.sh
#   STAGE=rc bash scripts/index-climbers.sh
#
# Scans the table (the API's roles may not), so it needs an
# administrator's credentials. Reads only profile keys (pk CLIMBER#…,
# sk PROFILE) and writes only gsi1pk and gsi1sk on them. Needs the AWS CLI.
set -euo pipefail

STAGE="${STAGE:-}"
case "$STAGE" in
  prod) table=grigri-api ;;
  rc) table=grigri-rc-api ;;
  *)
    echo "error: STAGE must be prod or rc (got '$STAGE'); Floci starts empty each time" >&2
    exit 2
    ;;
esac
export AWS_REGION="${AWS_REGION:-us-east-1}"

ids="$(aws dynamodb scan --table-name "$table" \
  --filter-expression 'sk = :profile AND begins_with(pk, :climber) AND attribute_not_exists(gsi1pk)' \
  --expression-attribute-values '{":profile":{"S":"PROFILE"},":climber":{"S":"CLIMBER#"}}' \
  --projection-expression pk --query 'Items[].pk.S' --output text)"
count=0
for pk in $ids; do
  [[ "$pk" =~ ^CLIMBER#[A-Za-z0-9_-]+$ ]] || continue
  id="${pk#CLIMBER#}"
  aws dynamodb update-item --table-name "$table" \
    --key "{\"pk\":{\"S\":\"$pk\"},\"sk\":{\"S\":\"PROFILE\"}}" \
    --update-expression 'SET gsi1pk = :pk, gsi1sk = :id' \
    --condition-expression 'attribute_exists(pk)' \
    --expression-attribute-values "{\":pk\":{\"S\":\"CLIMBERS\"},\":id\":{\"S\":\"$id\"}}" >/dev/null
  count=$((count + 1))
done
echo "grigri: indexed $count profiles in $table"
