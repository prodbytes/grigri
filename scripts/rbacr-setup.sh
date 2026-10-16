#!/usr/bin/env bash
# Sets up Grigri's roles in rbacr (specs/roles.md), idempotently: the
# `grigri` system with its roles, `admin`, `premium` and `blocked`
# (production's), `premium-rc` and `blocked-rc` (the RC's, which asks
# production's rbacr too), and admin implying both Premiums, so admins have Premium
# through rbacr. Roles already there, and implications admin has besides,
# are kept.
#
# Run by scripts/deploy.sh (with GRIGRI_RBACR_TOKEN, production's rbacr)
# and, locally, by process-compose's 7-rbacr-setup (the local rbacr, with
# .env's RBACR_TOKEN). Settings, from the environment:
#   RBACR_URL    rbacr's site (default https://rbacr.nu01.com)
#   RBACR_TOKEN  an rbacr API token owned by a root (required)
set -euo pipefail

url="${RBACR_URL:-https://rbacr.nu01.com}"
url="${url%/}"
token="${RBACR_TOKEN:-}"
if [[ -z "$token" ]]; then
  echo "error: RBACR_TOKEN isn't set (an rbacr root's API token)" >&2
  exit 2
fi
# The token goes to curl in a private headers file, never on its command
# line (where other processes could read it).
headers="$(mktemp)"
chmod 600 "$headers"
trap 'rm -f "$headers"' EXIT
printf 'Authorization: Bearer %s\nContent-Type: application/json\n' "$token" >"$headers"
system=grigri
roles=(admin premium premium-rc blocked blocked-rc)
implied_by_admin=(premium premium-rc)

# api <method> <path> [json]: the answer's body; fails on anything but 2xx.
api() {
  local method="$1" path="$2" body="${3:-}" out status
  out="$(mktemp)"
  status="$(curl -sS -o "$out" -w '%{http_code}' -X "$method" "$url/api$path" \
    -H "@$headers" ${body:+--data "$body"})"
  if [[ "$status" != 2* ]]; then
    echo "error: rbacr $method $path answered $status: $(head -c 300 "$out")" >&2
    rm -f "$out"
    return 1
  fi
  cat "$out"
  rm -f "$out"
}

status="$(curl -sS -o /dev/null -w '%{http_code}' "$url/api/systems/$system" -H "@$headers")"
if [[ "$status" == 404 ]]; then
  roles_json="$(printf '%s\n' "${roles[@]}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')"
  api POST /systems "{\"id\": \"$system\", \"name\": \"Grigri\", \"roles\": $roles_json}" >/dev/null
  echo "rbacr: made the $system system"
elif [[ "$status" != 200 ]]; then
  echo "error: rbacr GET /systems/$system answered $status" >&2
  exit 1
fi

current="$(api GET "/systems/$system")"
for role in "${roles[@]}"; do
  if ! python3 -c 'import json,sys; sys.exit(0 if sys.argv[1] in json.load(sys.stdin)["roles"] else 1)' "$role" <<<"$current"; then
    api POST "/systems/$system/roles" "{\"role\": \"$role\"}" >/dev/null
    echo "rbacr: added the $role role"
  fi
done

# admin implies Premium (both stages'), keeping what else it implies.
current="$(api GET "/systems/$system")"
wanted="$(SYSTEM_JSON="$current" python3 -c '
import json, os, sys
system = json.loads(os.environ["SYSTEM_JSON"])
have = sorted(set((system.get("implies") or {}).get("admin", [])))
want = sorted(set(have) | set(sys.argv[1:]))
print(json.dumps(want) if want != have else "")
' "${implied_by_admin[@]}")"
if [[ -n "$wanted" ]]; then
  api PUT "/systems/$system/roles/admin" "{\"implies\": $wanted}" >/dev/null
  echo "rbacr: admin implies $wanted"
fi
echo "rbacr: $system is set up ($url)"
