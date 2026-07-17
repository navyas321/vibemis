#!/bin/bash
# vibemis-setup.sh — guided one-command Vibemis setup for SteamOS / Linux
#
# The "single guided flow" that ties the individual helper scripts together so a new user can go
# from nothing to streaming with one command. It runs, in order:
#   1. vibemis-doctor.sh        — read-only environment check (GPU/VAAPI/FUSE/install state)
#   2. vibemis-update.sh        — download the latest Vibemis AppImage to ~/Applications
#   3. install-vibemis-desktop.sh — install to a stable path + clean "Vibemis" desktop/Steam entry
#   4. (if --host) pair-host.sh <host>            — pair (prints the PIN to enter in the host web UI)
#   5. (if --host) add-all-games-to-steam.sh <host> --confirm — per-game Steam launchers
#
# It only orchestrates the existing scripts — no new privileged behavior. No sudo; everything stays
# under $HOME. Idempotent: safe to re-run.
#
# Usage:
#   ./vibemis-setup.sh                      # doctor + update + install (no host steps)
#   ./vibemis-setup.sh --host 100.x.y.z     # also pair + add that host's games
#   ./vibemis-setup.sh --host myhost.ts.net --yes   # non-interactive (skip confirmations)
#   ./vibemis-setup.sh --dry-run            # print the exact plan; run nothing
#   ./vibemis-setup.sh --update-only        # just steps 1-2 (check env + fetch newest AppImage)
#   ./vibemis-setup.sh --help
#
# Exit codes: 0 ok · 1 a step failed · 2 bad usage.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST=""
DRY=0
YES=0
UPDATE_ONLY=0

say()  { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ok]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit "${2:-1}"; }

usage() { sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
    case "$1" in
        --host)        HOST="${2:-}"; shift 2 || die "--host needs a value" 2 ;;
        --host=*)      HOST="${1#*=}"; shift ;;
        --dry-run|-n)  DRY=1; shift ;;
        --yes|-y)      YES=1; shift ;;
        --update-only) UPDATE_ONLY=1; shift ;;
        -h|--help)     usage; exit 0 ;;
        *)             warn "Unknown option: $1"; usage; exit 2 ;;
    esac
done

# run <description> <cmd...> — echo it; execute unless --dry-run; stop on failure.
run() {
    local desc="$1"; shift
    say "$desc"
    printf '    $ %s\n' "$*"
    if [ "$DRY" = 1 ]; then printf '    (dry-run: not executed)\n'; return 0; fi
    "$@" || die "Step failed: $desc (exit $?). Fix the issue above and re-run."
    ok "$desc"
}

confirm() {
    [ "$YES" = 1 ] && return 0
    [ "$DRY" = 1 ] && return 0
    local reply
    printf '\n%s [y/N] ' "$1"
    read -r reply 2>/dev/null || reply=""
    case "$reply" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

require_script() { [ -f "$SCRIPT_DIR/$1" ] || die "Missing helper: scripts/$1 (incomplete checkout?)"; }

# ---- Preflight -----------------------------------------------------------------------------
for s in vibemis-doctor.sh vibemis-update.sh install-vibemis-desktop.sh; do require_script "$s"; done
[ -n "$HOST" ] && { require_script pair-host.sh; require_script add-all-games-to-steam.sh; }

say "Vibemis guided setup"
echo "    Plan:"
echo "      1. Check environment (vibemis-doctor.sh)"
echo "      2. Download latest AppImage (vibemis-update.sh)"
[ "$UPDATE_ONLY" = 1 ] || echo "      3. Install desktop/Steam entry (install-vibemis-desktop.sh)"
if [ -n "$HOST" ] && [ "$UPDATE_ONLY" = 0 ]; then
    echo "      4. Pair host '$HOST' (pair-host.sh)"
    echo "      5. Add '$HOST' games to Steam (add-all-games-to-steam.sh --confirm)"
fi
[ "$DRY" = 1 ] && echo "    (dry-run — nothing will be executed)"

# ---- 1) Environment ------------------------------------------------------------------------
run "Checking environment" bash "$SCRIPT_DIR/vibemis-doctor.sh"

# ---- 2) Download latest --------------------------------------------------------------------
run "Downloading the latest Vibemis AppImage" bash "$SCRIPT_DIR/vibemis-update.sh"

if [ "$UPDATE_ONLY" = 1 ]; then
    say "Update-only requested — done."; exit 0
fi

# ---- 3) Install desktop/Steam integration --------------------------------------------------
run "Installing desktop & Steam integration" bash "$SCRIPT_DIR/install-vibemis-desktop.sh"

if [ -z "$HOST" ]; then
    say "Base setup complete."
    echo "    Vibemis is installed at ~/Applications/Vibemis.AppImage and added to your launcher."
    echo "    Next: launch Vibemis, or re-run with --host <name-or-IP> to pair a host and add its games."
    echo "    For remote play, see scripts/setup-tailscale.sh and docs/REMOTE_PLAY_TAILSCALE.md."
    exit 0
fi

# ---- 4) Pair host --------------------------------------------------------------------------
say "Pairing with host: $HOST"
echo "    pair-host.sh will print a PIN. Enter that PIN in your host's Apollo/Sunshine 'Pair' web UI"
echo "    (usually https://<host>:47990) to complete pairing."
if confirm "Start pairing with '$HOST' now?"; then
    run "Pairing with $HOST" bash "$SCRIPT_DIR/pair-host.sh" "$HOST"
else
    warn "Skipped pairing. Re-run with --host $HOST when ready."; exit 0
fi

# ---- 5) Add games --------------------------------------------------------------------------
if confirm "Add all of '$HOST' games to Steam as launchers?"; then
    run "Adding $HOST games to Steam" bash "$SCRIPT_DIR/add-all-games-to-steam.sh" "$HOST" --confirm
else
    warn "Skipped adding games. You can run: scripts/add-all-games-to-steam.sh \"$HOST\" --confirm"
fi

say "All done — Vibemis is set up for '$HOST'. Launch from Steam or your app menu and start streaming."
