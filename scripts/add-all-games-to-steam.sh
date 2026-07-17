#!/bin/bash
# add-all-games-to-steam.sh — make direct-launch shortcuts for every app on a host
#
# Lists the host's apps via the Vibemis CLI (`vibemis list <host>`) and creates a per-game
# .desktop launcher for each (delegating to add-game-to-steam.sh). Dry-run by default — it
# prints the parsed app list and what it WOULD create — so you can confirm the parse before
# anything is written. Re-run with --confirm to actually create the launchers.
#
# Deliberately uses .desktop entries (safe) rather than editing Steam's binary shortcuts.vdf.
#
# Usage:
#   ./add-all-games-to-steam.sh "<HostName>"            # dry run (parse + preview)
#   ./add-all-games-to-steam.sh "<HostName>" --confirm  # create the .desktop launchers
#
# Requires ~/Applications/Vibemis.AppImage (or VIBEMIS_APPIMAGE) and a paired host. No sudo.

set -euo pipefail

HOST="${1:-}"
CONFIRM=0
[ "${2:-}" = "--confirm" ] && CONFIRM=1
if [ -z "$HOST" ]; then
    echo "Usage: $0 \"<HostName>\" [--confirm]" >&2
    exit 1
fi

APPIMAGE="${VIBEMIS_APPIMAGE:-$HOME/Applications/Vibemis.AppImage}"
if [ ! -x "$APPIMAGE" ]; then
    echo "ERROR: Vibemis AppImage not found/executable at: $APPIMAGE" >&2
    echo "  Run scripts/install-vibemis-desktop.sh first, or set VIBEMIS_APPIMAGE=..." >&2
    exit 1
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADD_ONE="$HERE/add-game-to-steam.sh"
if [ ! -f "$ADD_ONE" ]; then
    echo "ERROR: add-game-to-steam.sh not found next to this script." >&2
    exit 1
fi

echo "Listing apps on host: $HOST"
# `vibemis list <host>` prints the host's apps. We treat each non-empty, trimmed line as an
# app name. If the CLI adds headers/decoration, adjust the filter below (verify via dry run).
RAW=$("$APPIMAGE" list "$HOST" 2>/dev/null || true)
mapfile -t APPS < <(printf '%s\n' "$RAW" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$')

if [ "${#APPS[@]}" -eq 0 ]; then
    echo "No apps returned for \"$HOST\". Is the host paired and reachable?" >&2
    echo "Try: \"$APPIMAGE\" list \"$HOST\"" >&2
    exit 1
fi

echo "Parsed ${#APPS[@]} app(s):"
printf '  - %s\n' "${APPS[@]}"
echo ""

if [ "$CONFIRM" -eq 0 ]; then
    echo "Dry run. Re-run with --confirm to create a .desktop launcher for each app:"
    echo "  $0 \"$HOST\" --confirm"
    echo "(Verify the list above matches the host's real apps before confirming.)"
    exit 0
fi

for app in "${APPS[@]}"; do
    echo ">> creating shortcut for: $app"
    bash "$ADD_ONE" "$HOST" "$app" || echo "   (skipped: $app)"
done
echo "Done. Add the new \"<App> (Vibemis)\" entries to Steam from Desktop Mode."
