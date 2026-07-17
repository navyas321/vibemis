#!/bin/bash
# vibemis-update.sh — fetch the latest Vibemis AppImage from GitHub Releases
#
# SteamOS has no package manager for this, so this script self-updates: it queries the
# GitHub Releases API for the newest published AppImage and REPLACES YOUR EXISTING
# INSTALL WHEREVER IT LIVES (no hardcoded install location — the previous
# version updated only ~/Applications, silently missing installs in ~/Downloads etc.).
#
# Install-path resolution order:
#   1. --path <file>            explicit target
#   2. $VIBEMIS_APPIMAGE        environment override
#   3. an EXISTING Vibemis.AppImage in the usual spots (~/Applications, ~/Downloads,
#      ~/Desktop, ~/.local/bin, ~) — newest one wins if several exist
#   4. fresh install fallback: ~/Applications/Vibemis.AppImage
#
# Usage:
#   ./vibemis-update.sh                  # newest build INCLUDING betas (default)
#   ./vibemis-update.sh --stable         # newest STABLE (non-prerelease) build only
#   ./vibemis-update.sh --check          # just print the version that would be installed
#   ./vibemis-update.sh --launch         # after updating, launch Vibemis (Steam-shortcut friendly)
#   ./vibemis-update.sh --path <file>    # update a specific AppImage path
#
# The previous build is kept next to the install as Vibemis.AppImage.old (rollback).
# Add this as a non-Steam shortcut ("Update Vibemis") to update from Game Mode in one tap.
# Safe: writes only to the resolved install path and uses curl. No sudo.

set -euo pipefail

REPO="navyas321/vibemis"

CHANNEL_STABLE=0
CHANNEL_RC=0
CHECK_ONLY=0
LAUNCH_AFTER=0
DEST_OVERRIDE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --stable) CHANNEL_STABLE=1 ;;
        --rc)     CHANNEL_RC=1 ;;    # newest release candidate (-rc.NNN, the proposed next stable)
        --check)  CHECK_ONLY=1 ;;
        --launch) LAUNCH_AFTER=1 ;;
        --path)   shift; DEST_OVERRIDE="${1:-}"; [ -n "$DEST_OVERRIDE" ] || { echo "ERROR: --path needs a file argument." >&2; exit 2; } ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

command -v curl >/dev/null 2>&1 || { echo "ERROR: curl is required." >&2; exit 1; }

# ---- Resolve where the install actually lives (never assume one folder) ----
DEST=""
if [ -n "$DEST_OVERRIDE" ]; then
    DEST="$DEST_OVERRIDE"
elif [ -n "${VIBEMIS_APPIMAGE:-}" ]; then
    DEST="$VIBEMIS_APPIMAGE"
else
    newest_mtime=0
    for cand in "$HOME/Applications/Vibemis.AppImage" \
                "$HOME/Downloads/Vibemis.AppImage" \
                "$HOME/Desktop/Vibemis.AppImage" \
                "$HOME/.local/bin/Vibemis.AppImage" \
                "$HOME/Vibemis.AppImage"; do
        if [ -f "$cand" ]; then
            m=$(stat -c %Y "$cand" 2>/dev/null || stat -f %m "$cand" 2>/dev/null || echo 0)
            if [ "$m" -gt "$newest_mtime" ]; then
                newest_mtime=$m
                DEST="$cand"
            fi
        fi
    done
    if [ -z "$DEST" ]; then
        DEST="$HOME/Applications/Vibemis.AppImage"
        echo "No existing install found — fresh install to $DEST"
    else
        echo "Found existing install: $DEST"
    fi
fi
DEST_DIR=$(dirname "$DEST")

# Semantic Versioning: stable = bare X.Y.Z (or the frozen four-part
# 0.4.0.0); beta/alpha/rc/dev are -suffixed and never stable. Historical catalog
# markers are prerelease-flagged and assetless (see docs/RELEASE_HISTORY.md) — the
# prerelease check below skips them, so structural filtering stays correct.
API="https://api.github.com/repos/$REPO/releases"
if [ "$CHANNEL_STABLE" -eq 1 ]; then
    echo "Channel: stable"
elif [ "$CHANNEL_RC" -eq 1 ]; then
    echo "Channel: release candidate"
else
    echo "Channel: latest (includes betas)"
fi

echo "Querying $REPO releases..."
JSON=$(curl -fsSL -H "Accept: application/vnd.github+json" "$API") || {
    echo "ERROR: failed to query $API (network/offline?)." >&2; exit 1; }

is_stable_tag() {
    # Stable: no -suffix AND (W.X.0.Z four-part with Y==0 — Z is the hotfix patch
    # counter, e.g. 0.3.0.1 — or legacy bare three-part like 1.0.1). The prerelease
    # flag is checked separately by the caller (parked stables / alphas are skipped).
    case "$1" in
        *-*) return 1 ;;
    esac
    n=$(printf '%s' "$1" | awk -F. '{print NF}')
    if [ "$n" = "4" ]; then
        y=$(printf '%s' "$1" | cut -d. -f3)
        [ "$y" = "0" ]
    else
        [ "$n" = "3" ]
    fi
}

TAG=""
if [ "$CHANNEL_STABLE" -eq 1 ]; then
    # Newest-first list: take the first structurally-stable tag whose release is NOT
    # flagged prerelease (a parked/pulled stable gets flipped to prerelease and must
    # be skipped — e.g. the parked 1.0.0/1.0.1).
    URL=""
    for t in $(printf '%s' "$JSON" | grep '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'); do
        is_stable_tag "$t" || continue
        REL_JSON=$(curl -fsSL -H "Accept: application/vnd.github+json" \
            "https://api.github.com/repos/$REPO/releases/tags/$t") || continue
        if printf '%s' "$REL_JSON" | grep -q '"prerelease": *true'; then
            echo "  (skipping parked stable $t)"
            continue
        fi
        TAG="$t"
        URL=$(printf '%s' "$REL_JSON" | grep -oE '"browser_download_url": *"[^"]+\.AppImage"' \
                | head -1 | sed -E 's/.*"(https[^"]+)"/\1/')
        break
    done
    if [ -z "$TAG" ]; then
        echo "ERROR: no stable release published yet (channel: stable)." >&2; exit 1
    fi
elif [ "$CHANNEL_RC" -eq 1 ]; then
    # Newest -rc.NNN tag that actually carries an AppImage (historical rc markers may not).
    URL=""
    for t in $(printf '%s' "$JSON" | grep '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'); do
        case "$t" in
            *-rc.*) ;;
            *) continue ;;
        esac
        REL_JSON=$(curl -fsSL -H "Accept: application/vnd.github+json" \
            "https://api.github.com/repos/$REPO/releases/tags/$t") || continue
        U=$(printf '%s' "$REL_JSON" | grep -oE '"browser_download_url": *"[^"]+\.AppImage"' \
                | head -1 | sed -E 's/.*"(https[^"]+)"/\1/')
        [ -n "$U" ] || { echo "  (skipping artifact-less rc $t)"; continue; }
        TAG="$t"; URL="$U"
        break
    done
    if [ -z "$TAG" ]; then
        echo "ERROR: no release candidate with an AppImage found (channel: rc)." >&2; exit 1
    fi
else
    # First tag_name / first .AppImage asset = the newest release (list is newest-first).
    TAG=$(printf '%s' "$JSON" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
    URL=$(printf '%s' "$JSON" | grep -oE '"browser_download_url": *"[^"]+\.AppImage"' \
            | head -1 | sed -E 's/.*"(https[^"]+)"/\1/')
fi

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
    # Keep the previous build for rollback (same contract as the in-app updater)
    if [ -f "$DEST" ]; then
        mv -f "$DEST" "$DEST.old"
    fi
    mv -f "$TMP" "$DEST"
    echo "Done. Updated $DEST to $TAG (previous kept at $DEST.old)."
    echo "(Your Steam shortcut keeps working if it points at $DEST — the path didn't change.)"
else
    rm -f "$TMP"
    echo "ERROR: download failed." >&2
    exit 1
fi

if [ "$LAUNCH_AFTER" -eq 1 ]; then
    echo "Launching Vibemis..."
    exec "$DEST"
fi
