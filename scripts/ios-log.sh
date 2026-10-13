#!/usr/bin/env bash
# Shows the app's log from the iPhone attached by USB (specs/logging.md):
# the log file the app keeps in its container (Library/Application
# Support/grigri.log), copied off the phone with devicectl, from any build,
# debug or release, and kept across app restarts.
# `bash scripts/ios-log.sh` or `devbox run ios-log`; IOS_DEVICE=<udid> with
# several iPhones.
#
# Options: --follow keeps copying it and prints the new lines (Ctrl-C to
# stop); --previous shows the older file (grigri.log.1) instead.
set -euo pipefail

follow=false
name=grigri.log
while [[ $# -gt 0 ]]; do
  case "$1" in
    --follow) follow=true ;;
    --previous) name=grigri.log.1 ;;
    *) echo "usage: $0 [--follow] [--previous]" >&2; exit 2 ;;
  esac
  shift
done

bundle=com.nu01.grigri
device="${IOS_DEVICE:-}"
if [[ -z "$device" ]]; then
  json="$(mktemp -t grigri-devices.XXXXXX)"
  trap 'rm -f "$json"' EXIT
  xcrun devicectl list devices --quiet --json-output "$json" >/dev/null 2>&1 || true
  device="$(python3 - "$json" <<'EOF'
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    devices = []
for d in devices:
    hw, props = d.get("hardwareProperties", {}), d.get("connectionProperties", {})
    if hw.get("platform") == "iOS" and hw.get("reality") == "physical" \
            and props.get("pairingState") == "paired":
        print(hw.get("udid", ""))
        break
EOF
)"
fi
if [[ -z "$device" ]]; then
  echo "error: no paired iPhone (USB, unlocked, trusted); or set IOS_DEVICE" >&2
  exit 1
fi

out="$(mktemp -d -t grigri-ios-log.XXXXXX)"
trap 'rm -rf "$out"' EXIT
copy() { # copies the log file to $out/$name; fails when it can't
  xcrun devicectl device copy from --device "$device" \
    --domain-type appDataContainer --domain-identifier "$bundle" \
    --source "Library/Application Support/$name" \
    --destination "$out/$name" >/dev/null 2>&1
}

if ! copy; then
  echo "error: no $name in $bundle on $device (is the app installed, and was it started?)" >&2
  exit 1
fi
cat "$out/$name"
$follow || exit 0

echo "--- following $name on $device; Ctrl-C to stop" >&2
shown="$(wc -l <"$out/$name")"
while sleep 2; do
  copy || continue
  lines="$(wc -l <"$out/$name")"
  # A smaller file: the app rotated it on a restart.
  if ((lines < shown)); then shown=0; fi
  if ((lines > shown)); then
    tail -n +"$((shown + 1))" "$out/$name"
    shown="$lines"
  fi
done
