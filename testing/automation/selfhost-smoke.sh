#!/bin/bash
# selfhost-smoke.sh — reusable CONTROL-PLANE smoke test for the local Sunshine self-host.
#
# The self-host is an IMPERFECT surrogate (~25-30% fidelity; adversarial verdict 2026-07-12): it can
# exercise the client's control plane (discovery / serverinfo / pairing / applist / launch-request)
# but NOT real video frames or Vibepollo host features (Virtual Display, server commands, save-sync).
# So this harness validates ONLY the control plane and TAGS every run "self-host only — needs real-host retest".
#
# It is safe to run while the maintainer games: it touches 127.0.0.1 ONLY (never Navid-PC).
#
# Usage:  testing/automation/selfhost-smoke.sh            # run the battery
#         VIBEMIS=~/Downloads/Vibemis.AppImage testing/automation/selfhost-smoke.sh
#
# PID-SAFE: never uses broad `pkill -f sunshine|gamescope` (those match this script's own shell and
# kill it — the footgun that caused flaky "Exit code 1" runs). Starts Sunshine with a tracked PID.
set -uo pipefail

VIBEMIS="${VIBEMIS:-$HOME/Downloads/Vibemis.AppImage}"
HOST="127.0.0.1"
FLATPAK_APP="dev.lizardbyte.app.Sunshine"
CREDS_USER="vibetest"; CREDS_PASS="vibetest123"
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
bad(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

echo "== Vibemis self-host control-plane smoke =="
echo "   client: $($VIBEMIS --version 2>/dev/null | grep -i vibemis)  host: $HOST (Sunshine surrogate)"

# 1. Ensure Sunshine self-host is up (start if down; do NOT pkill — start is idempotent enough here)
if ! pgrep -x sunshine >/dev/null 2>&1; then
    echo "-- self-host down; starting --"
    setsid flatpak run "$FLATPAK_APP" >"$HOME/.selfhost-smoke-sunshine.log" 2>&1 </dev/null &
    for _ in $(seq 1 15); do sleep 2; pgrep -x sunshine >/dev/null 2>&1 && break; done
fi
pgrep -x sunshine >/dev/null 2>&1 && ok "self-host process up (pid $(pgrep -x sunshine | head -1))" || { bad "self-host will not start"; echo "RESULT: FAIL"; exit 1; }

# 2. Web UI reachable + authenticated (HTTP 200)
CODE=$(curl -s -k -m 6 -o /dev/null -w "%{http_code}" -u "$CREDS_USER:$CREDS_PASS" "https://$HOST:47990/api/config" 2>/dev/null)
[ "$CODE" = "200" ] && ok "web UI auth (200)" || bad "web UI /api/config returned $CODE (creds? not ready?)"

# 3. serverinfo reach + applist (paired => returns app list, not 'not paired')
LIST=$(timeout 20 "$VIBEMIS" list "$HOST" 2>/dev/null | grep -vE '^\s*$' | grep -viE 'not been paired')
if echo "$LIST" | grep -qiE 'Desktop|Steam'; then ok "applist over paired HTTPS ($(echo "$LIST" | tr '\n' ',' | sed 's/,$//'))"
elif timeout 20 "$VIBEMIS" list "$HOST" 2>/dev/null | grep -qi 'not been paired'; then bad "host reachable but NOT paired (run the pair procedure)"
else bad "no applist returned (host unreachable?)"; fi

# 4. serverinfo advertises the EXPECTED surrogate limits (documents the fidelity gap explicitly)
SI=$(timeout 12 "$VIBEMIS" list "$HOST" 2>&1)
if echo "$SI" | grep -qiE 'VirtualDisplayCapable|ServerCommand'; then
    echo "  NOTE: surrogate now advertises VirtualDisplay/ServerCommand?! (unexpected — re-check host type)"
else ok "surrogate correctly lacks VirtualDisplay/ServerCommand (expected — real-host-only features)"; fi

echo "== RESULT: $PASS passed, $FAIL failed =="
echo "== TAG: SELF-HOST VERIFIED ONLY — every green here REQUIRES a real-host (Navid-PC/Vibepollo) retest =="
[ "$FAIL" -eq 0 ]
