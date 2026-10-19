#!/usr/bin/env bash
# Builds the app binaries. Run through the Makefile (`make`, `make web`, ...)
# or directly: `bash scripts/make.sh <target>...`.
#
# Targets: web, android, aab (the release bundle for Google Play, signed
# with the upload key in grigri_app/android/key.properties), ios, ipa (a
# signed release archive for App Store Connect; macOS only), all (every platform this host can build; never
# ipa), clean. Settings, from the environment or `make VAR=value`:
#   MODE          release (default), profile or debug
#   IOS_CODESIGN  1 to sign the iOS build (needs a signing team in Xcode);
#                 unsigned by default
#   WEB_BASE_HREF the web build's base href, e.g. /app/ for the deployed site
#                 (where CloudFront serves the app); / by default
# Build settings come from the repo's .env (see .env.example), through the
# same allowlist as the run scripts (scripts/dart-defines.sh).
#
# The version is X.Y.Z: X and Y from version.X.txt and version.Y.txt, Z the
# build time as YYYYMMDDHHMM (UTC); the build number is the same time in
# Unix seconds. Set VERSION_Z and BUILD_NUMBER to override them (see
# scripts/version.sh).
set -euo pipefail

MODE="${MODE:-release}"
case "$MODE" in
  release | profile | debug) ;;
  *) echo "error: MODE must be release, profile or debug (got '$MODE')" >&2; exit 2 ;;
esac

cd "$(dirname "$0")/../grigri_app"
source ../scripts/dart-defines.sh
source ../scripts/version.sh
# GRIGRI_VERSION: X.Y.Z, shown in the About dialog.
BUILD_ARGS=(--build-name "$VERSION" --build-number "$BUILD_NUMBER" ${DART_DEFINES[@]+"${DART_DEFINES[@]}"}
  --dart-define="GRIGRI_VERSION=$VERSION")

# can_build <target>: whether this host's OS can build the target.
can_build() {
  case "$1" in
    ios | ipa) [[ "$(uname -s)" == Darwin ]] ;;
    *) return 0 ;;
  esac
}

build() {
  local target="$1"
  if ! can_build "$target"; then
    echo "error: $target can't be built on $(uname -s)" >&2
    return 1
  fi
  echo "==> $target ($MODE, version $VERSION, build $BUILD_NUMBER)"
  case "$target" in
    web)
      local base=()
      [[ -n "${WEB_BASE_HREF:-}" ]] && base=(--base-href "$WEB_BASE_HREF")
      flutter build web "--$MODE" ${base[@]+"${base[@]}"} "${BUILD_ARGS[@]}"
      echo "==> web: grigri_app/build/web/"
      ;;
    android)
      flutter build apk "--$MODE" "${BUILD_ARGS[@]}"
      echo "==> android: grigri_app/build/app/outputs/flutter-apk/app-$MODE.apk"
      ;;
    aab)
      # For Google Play: always release, and never with the debug key
      # (specs/play-store.md).
      if [[ ! -f android/key.properties ]]; then
        echo "error: no android/key.properties: Play's upload key is needed (specs/play-store.md)" >&2
        return 1
      fi
      flutter build appbundle --release "${BUILD_ARGS[@]}"
      echo "==> aab: grigri_app/build/app/outputs/bundle/release/app-release.aab (upload in Play Console)"
      ;;
    ios)
      check_ios_version || return 1
      local sign=--no-codesign
      [[ "${IOS_CODESIGN:-}" == 1 ]] && sign=--codesign
      flutter build ios "--$MODE" "$sign" "${BUILD_ARGS[@]}"
      echo "==> ios: grigri_app/build/ios/iphoneos/Runner.app"
      ;;
    ipa)
      # For App Store Connect (TestFlight, then the App Store): always a
      # release build, signed for distribution with the team in
      # Private.xcconfig (specs/app-store.md).
      check_ios_version || return 1
      flutter build ipa --release "${BUILD_ARGS[@]}"
      echo "==> ipa: grigri_app/build/ios/ipa/ (upload with Transporter or xcrun altool)"
      ;;
  esac
}

# check_ios_version: the App Store takes a CFBundleShortVersionString and
# a CFBundleVersion of at most three period-separated integers and 18
# characters (Apple's TN2420; specs/app-store.md). Fails otherwise.
check_ios_version() {
  local v
  for v in "$VERSION" "$BUILD_NUMBER"; do
    if [[ ! "$v" =~ ^[0-9]+(\.[0-9]+){0,2}$ || ${#v} -gt 18 ]]; then
      echo "error: iOS version '$v' isn't up to three integers in 18 characters" >&2
      return 1
    fi
  done
}

[[ $# -gt 0 ]] || set -- all
for arg in "$@"; do
  case "$arg" in
    web | android | aab | ios | ipa) build "$arg" ;;
    all)
      for target in web android ios; do
        if can_build "$target"; then
          build "$target"
        else
          echo "==> skipping $target: can't be built on $(uname -s)"
        fi
      done
      ;;
    clean) flutter clean ;;
    *) echo "error: unknown target '$arg' (web, android, aab, ios, ipa, all, clean)" >&2; exit 2 ;;
  esac
done
