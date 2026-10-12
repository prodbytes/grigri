#!/usr/bin/env bash
# Builds the API (grigri_api: npm ci, then the esbuild bundle in dist/) for
# the local stack, only when its sources changed since the last build. Runs
# before Floci starts (4-floci in process-compose.yaml), whose ready hook
# deploys grigri_api (mounted read-only) into Floci
# (grigri_floci/init/ready.d/05-api.sh).
set -euo pipefail

cd "$(dirname "$0")/../grigri_api"
built=dist/index.mjs

if ! command -v npm >/dev/null 2>&1; then
    echo "build-api: 'npm' is not on PATH; run inside devbox (devbox services up)" >&2
    exit 1
fi
if [[ ! -d node_modules || package-lock.json -nt node_modules ]]; then
    echo "build-api: npm ci"
    npm ci --no-audit --no-fund
    touch node_modules
fi
if [[ -f "$built" ]] && [[ -z "$(find src seed build.mjs package-lock.json template.yaml -newer "$built" -print -quit)" ]]; then
    echo "build-api: up to date"
    exit 0
fi
echo "build-api: npm run build"
npm run build
