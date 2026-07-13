#!/bin/bash
# vibemis-update.sh — fetch the latest Vibemis AppImage from GitHub Releases (P3.10)
#
# SteamOS has no package manager for this, so this script self-updates: it queries the
# GitHub Releases API for the newest published AppImage and downloads it to the stable
# install path (~/Applications/Vibemis.AppImage, matching install-vibemis-desktop.sh).
#
# Usage:
#   ./vibemis-update.sh              # download the newest build INCLUDING betas (default)
#   ./vibemis-update.sh --stable     # download the newest STABLE (non-prerelease) build only
#   ./vibemis-update.sh --check      # just print the version that would be installed
#   ./vibemis-update.sh --launch     # after updating, launch Vibemis (handy as a Steam shortcut)
#
# Add this as a non-Steam shortcut ("Update Vibemis") to update from Game Mode in one tap.
# Safe: only downloads to ~/Applications and uses curl. No sudo.

set -euo pipefail

REPO="navyas321/vibemis"
DEST_DIR="$HOME/Applications"
DEST="$DEST_DIR/Vibemis.AppImage"

CHANNEL_STABLE=0
CHECK_ONLY=0
LAUNCH_AFTER=0
for a in "$@"; do
    case "$a" in
        --stable) CHANNEL_STABLE=1 ;;
        --check)  CHECK_ONLY=1 ;;
        --launch) LAUNCH_AFTER=1 ;;
        *) echo "Unknown option: $a" >&2; exit 2 ;;
    esac
done

command -v curl >/dev/null 2>&1 || { echo "ERROR: curl is required." >&2; exit 1; }

# Betas are published as GitHub PRE-RELEASES. /releases/latest returns ONLY the newest
# non-prerelease, so it can never see a beta — the default channel must list ALL releases
# (newest first) and take the first AppImage. --stable uses /releases/latest instead.
if [ "$CHANNEL_STABLE" -eq 1 ]; then
    API="https://api.github.com/repos/$REPO/releases/latest"
    echo "Channel: stable"
else
    API="https://api.github.com/repos/$REPO/releases"
    echo "Channel: latest (includes betas)"
fi

echo "Querying $REPO releases..."
JSON=$(curl -fsSL -H "Accept: application/vnd.github+json" "$API") || {
    echo "ERROR: failed to query $API (network/offline?)." >&2; exit 1; }

# First tag_name / first .AppImage asset = the newest release (the list endpoint is newest-first).
TAG=$(printf '%s' "$JSON" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
URL=$(printf '%s' "$JSON" | grep -oE '"browser_download_url": *"[^"]+\.AppImage"' \
        | head -1 | sed -E 's/.*"(https[^"]+)"/\1/')

if [ -z "$URL" ]; then
    echo "ERROR: no .AppImage asset found in the newest release (${TAG:-unknown})." >&2
    exit 1
fi

echo "Newest release: ${TAG:-unknown}"
echo "AppImage:       $URL"

if [ "$CHECK_ONLY" -eq 1 ]; then
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

if [ "$LAUNCH_AFTER" -eq 1 ]; then
    echo "Launching Vibemis..."
    exec "$DEST"
fi
