#!/bin/bash
# vibemis-update.sh — fetch the latest Vibemis AppImage from GitHub Releases (P3.10)
#
# SteamOS has no package manager for this, so this script self-updates: it queries the
# GitHub Releases API for the newest published AppImage and downloads it to the stable
# install path (~/Applications/Vibemis.AppImage, matching install-vibemis-desktop.sh).
#
# Usage:
#   ./vibemis-update.sh            # download the latest release/beta AppImage
#   ./vibemis-update.sh --check    # just print the latest version, don't download
#
# Safe: only downloads to ~/Applications and uses curl. No sudo.

set -euo pipefail

REPO="navyas321/vibemis"
API="https://api.github.com/repos/$REPO/releases/latest"
DEST_DIR="$HOME/Applications"
DEST="$DEST_DIR/Vibemis.AppImage"

command -v curl >/dev/null 2>&1 || { echo "ERROR: curl is required." >&2; exit 1; }

echo "Querying latest Vibemis release..."
JSON=$(curl -fsSL -H "Accept: application/vnd.github+json" "$API") || {
    echo "ERROR: failed to query $API (network/offline?)." >&2; exit 1; }

# Parse the release tag and the first .AppImage asset URL (no jq dependency).
TAG=$(printf '%s' "$JSON" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
URL=$(printf '%s' "$JSON" | grep -oE '"browser_download_url": *"[^"]+\.AppImage"' \
        | head -1 | sed -E 's/.*"(https[^"]+)"/\1/')

if [ -z "$URL" ]; then
    echo "ERROR: no .AppImage asset found in the latest release ($TAG)." >&2
    exit 1
fi

echo "Latest release: ${TAG:-unknown}"
echo "AppImage:       $URL"

if [ "${1:-}" = "--check" ]; then
    exit 0
fi

mkdir -p "$DEST_DIR"
TMP=$(mktemp "$DEST_DIR/.vibemis-update.XXXXXX")
echo "Downloading to $DEST ..."
if curl -fL --progress-bar -o "$TMP" "$URL"; then
    chmod +x "$TMP"
    mv -f "$TMP" "$DEST"
    echo "Done. Updated $DEST to $TAG."
    echo "(If you added Vibemis to Steam via ~/Applications/Vibemis.AppImage, the shortcut now uses the new build.)"
else
    rm -f "$TMP"
    echo "ERROR: download failed." >&2
    exit 1
fi
