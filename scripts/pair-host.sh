#!/bin/bash
# pair-host.sh — pair Vibemis with a host from the command line
#
# Thin wrapper around the Vibemis CLI `pair` verb. Prints the PIN Vibemis generates so you
# can enter it in the Vibepollo/Apollo/Sunshine "Pair" web UI. Handy for scripted setup or
# when you don't want to navigate the GUI.
#
# Usage:
#   ./pair-host.sh "<HostName-or-IP>"
#   ./pair-host.sh "192.168.1.50"
#   ./pair-host.sh "myhost.tailnet.ts.net"     # works over Tailscale too
#
# Requires ~/Applications/Vibemis.AppImage (run install-vibemis-desktop.sh first) or set
# VIBEMIS_APPIMAGE=/path/to/Vibemis.AppImage. No sudo.

set -euo pipefail

HOST="${1:-}"
if [ -z "$HOST" ]; then
    echo "Usage: $0 \"<HostName-or-IP>\"" >&2
    echo "  e.g. $0 192.168.1.50" >&2
    exit 1
fi

APPIMAGE="${VIBEMIS_APPIMAGE:-$HOME/Applications/Vibemis.AppImage}"
if [ ! -x "$APPIMAGE" ]; then
    echo "ERROR: Vibemis AppImage not found/executable at: $APPIMAGE" >&2
    echo "  Run scripts/install-vibemis-desktop.sh first, or set VIBEMIS_APPIMAGE=..." >&2
    exit 1
fi

echo "Pairing with host: $HOST"
echo "When a PIN appears, enter it in the host's Pair-Client web UI (Vibepollo/Apollo/Sunshine)."
echo "------------------------------------------------------------------"
exec "$APPIMAGE" pair "$HOST"
