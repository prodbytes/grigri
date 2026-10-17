#!/usr/bin/env bash
# Serves the Flutter app in web mode on http://localhost:${FLUTTER_WEB_PORT}/app/.
# The /app/ base href matches the path the CloudFront distribution routes to
# the app (see grigri_infra/site.yaml).
# Runs via `devbox services up` (see process-compose.yaml) or `devbox run web`.
# Uses the web-server device, so no Chrome is needed; open the URL in any browser.
set -euo pipefail

PORT="${FLUTTER_WEB_PORT:-7189}"
# 127.0.0.1, not localhost: Dart binds "localhost" to IPv6 [::1] only.
# GRIGRI_BIND_HOST=0.0.0.0 serves other devices on the network (a phone's
# browser, say).
HOST="${GRIGRI_BIND_HOST:-127.0.0.1}"

cd "$(dirname "$0")/../grigri_app"
# This app is the local site's (https://local.grigri.nu01.com:2543/app/), so
# it signs in with the local Google web client, whose JavaScript origins are
# the local site's; Google refuses the RC's or GA's client there
# (origin_mismatch). The local API checks the same client (process-compose.yaml).
_local_client="${GOOGLE_WEB_CLIENT_ID_LOCAL:-$(sed -n 's/^GOOGLE_WEB_CLIENT_ID_LOCAL=//p' ../.env 2>/dev/null | tail -1)}"
[[ -n "$_local_client" ]] && export GOOGLE_WEB_CLIENT_ID="$_local_client"
source ../scripts/dart-defines.sh
source ../scripts/version.sh
flutter pub get
# The About dialog shows X.Y.Z, Z being when this server started.
exec flutter run -d web-server --web-hostname "$HOST" --web-port "$PORT" \
  --base-href /app/ \
  ${DART_DEFINES[@]+"${DART_DEFINES[@]}"} --dart-define="GRIGRI_VERSION=$VERSION"
