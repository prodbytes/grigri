#!/bin/sh
# Creates the Grigri CloudFront distribution in Floci. It only routes, as
# the deployed CloudFront would; the index and the app run on their own dev
# servers:
#   /app/*, /app -> Flutter dev server  (http://$GRIGRI_ORIGIN_HOST:$FLUTTER_WEB_PORT)
#   /api/*    -> the local API       (Floci's HTTP API, from 05-api.sh)
#   /photos/* -> the photos bucket   (Floci's S3, grigri-local-photos)
#   /pics/*   -> GriGri Pics' bucket (Floci's S3, grigri-local-pics)
#   *         -> grigri_index       (http://$GRIGRI_ORIGIN_HOST:$INDEX_PORT),
#                whose / redirects to /app/
# Paths are forwarded as is (CloudFront can't strip a prefix), so the app is
# served under /app/ (--base-href /app/).
#
# Nothing is cached. Every viewer header except Host, plus all cookies and
# query strings, is forwarded (like AWS's managed AllViewerExceptHostHeader
# policy). The origins therefore see Host: $GRIGRI_ORIGIN_HOST:<port>,
# which the Flutter dev server writes into its debug-channel (hot reload)
# URL. Floci can't carry that WebSocket, so the origin host is a *.localhost
# name: the browser resolves it to loopback and connects to the dev server
# directly, while compose.yaml maps it to the Docker host inside this
# container.
set -eu

ORIGIN_HOST="${GRIGRI_ORIGIN_HOST:-dev.grigri.localhost}"
ALIAS="${GRIGRI_CDN_ALIAS:-grigri.localhost}"
# A public name for the same machine (A record to 127.0.0.1 in Route 53), for
# origins that must end in a public TLD, such as Google sign-in's.
PUBLIC_HOST="${GRIGRI_PUBLIC_HOST:-local.grigri.nu01.com}"
WEB_PORT="${FLUTTER_WEB_PORT:-7189}"
INDEX_PORT="${INDEX_PORT:-2113}"
# The local API's host, deployed into this Floci by 05-api.sh. Missing (no
# build): no /api/*, /photos/* or /pics/* routes.
API_HOST="$(cat /tmp/grigri-api-host 2>/dev/null || true)"
PHOTOS_BUCKET=grigri-local-photos
PICS_BUCKET=grigri-local-pics

cache_policy=$(aws cloudfront create-cache-policy \
  --query CachePolicy.Id --output text \
  --cache-policy-config '{
    "Name": "grigri-no-cache",
    "MinTTL": 0, "DefaultTTL": 0, "MaxTTL": 0,
    "ParametersInCacheKeyAndForwardedToOrigin": {
      "EnableAcceptEncodingGzip": false,
      "EnableAcceptEncodingBrotli": false,
      "HeadersConfig": {"HeaderBehavior": "none"},
      "CookiesConfig": {"CookieBehavior": "none"},
      "QueryStringsConfig": {"QueryStringBehavior": "none"}
    }
  }')

origin_request_policy=$(aws cloudfront create-origin-request-policy \
  --query OriginRequestPolicy.Id --output text \
  --origin-request-policy-config '{
    "Name": "grigri-all-viewer-except-host",
    "HeadersConfig": {"HeaderBehavior": "allExcept", "Headers": {"Quantity": 1, "Items": ["Host"]}},
    "CookiesConfig": {"CookieBehavior": "all"},
    "QueryStringsConfig": {"QueryStringBehavior": "all"}
  }')

origin() {
  printf '{"Id": "%s", "DomainName": "%s", "CustomOriginConfig": {"HTTPPort": %s, "HTTPSPort": 443, "OriginProtocolPolicy": "http-only"}}' \
    "$1" "$ORIGIN_HOST" "$2"
}

behavior() {
  printf '"TargetOriginId": "%s", "ViewerProtocolPolicy": "allow-all", "CachePolicyId": "%s", "OriginRequestPolicyId": "%s", "AllowedMethods": {"Quantity": 7, "Items": ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"], "CachedMethods": {"Quantity": 2, "Items": ["GET", "HEAD"]}}' \
    "$1" "$cache_policy" "$origin_request_policy"
}

origin_count=2
behavior_count=2
api_origins=""
api_behaviors=""
if [ -n "$API_HOST" ]; then
  origin_count=5
  behavior_count=5
  # The API: Floci itself, on its own port, over HTTP (inside the
  # container). Photos and GriGri Pics: Floci's in-process S3.
  api_origins=$(printf ', {"Id": "api", "DomainName": "%s", "CustomOriginConfig": {"HTTPPort": 4566, "HTTPSPort": 443, "OriginProtocolPolicy": "http-only"}}, {"Id": "photos", "DomainName": "%s.s3.amazonaws.com", "S3OriginConfig": {"OriginAccessIdentity": ""}}, {"Id": "pics", "DomainName": "%s.s3.amazonaws.com", "S3OriginConfig": {"OriginAccessIdentity": ""}}' "$API_HOST" "$PHOTOS_BUCKET" "$PICS_BUCKET")
  api_behaviors=", {\"PathPattern\": \"/api/*\", $(behavior api)}, {\"PathPattern\": \"/photos/*\", $(behavior photos)}, {\"PathPattern\": \"/pics/*\", $(behavior pics)}"
fi

distribution=$(aws cloudfront create-distribution \
  --query 'Distribution.Id' --output text \
  --distribution-config "{
    \"CallerReference\": \"grigri-local\",
    \"Comment\": \"Grigri local CDN\",
    \"Enabled\": true,
    \"Aliases\": {\"Quantity\": 2, \"Items\": [\"$ALIAS\", \"$PUBLIC_HOST\"]},
    \"Origins\": {\"Quantity\": $origin_count, \"Items\": [$(origin app "$WEB_PORT"), $(origin index "$INDEX_PORT")$api_origins]},
    \"DefaultCacheBehavior\": {$(behavior index)},
    \"CacheBehaviors\": {\"Quantity\": $behavior_count, \"Items\": [
      {\"PathPattern\": \"/app/*\", $(behavior app)},
      {\"PathPattern\": \"/app\", $(behavior app)}$api_behaviors
    ]}
  }")

echo "grigri: CloudFront distribution $distribution serves $ALIAS and $PUBLIC_HOST (index, /app/${API_HOST:+, /api/, /photos/, /pics/})"
