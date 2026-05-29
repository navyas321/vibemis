#!/bin/bash
# uninstall-vibemis-desktop.sh — remove Vibemis desktop integration (P3.10)
#
# Cleanly undoes what install-vibemis-desktop.sh and add-game-to-steam.sh created:
#   ~/Applications/Vibemis.AppImage
#   ~/.local/share/applications/vibemis.desktop
#   ~/.local/share/applications/vibemis-game-*.desktop  (per-game launchers)
#   ~/.local/share/icons/hicolor/256x256/apps/vibemis.png
#
# Does NOT touch Steam shortcuts (remove those in Steam) or your settings
# (~/.config/Vibemis). No sudo.
#
# Usage:
#   ./uninstall-vibemis-desktop.sh           # show what would be removed (dry run)
#   ./uninstall-vibemis-desktop.sh --yes     # actually remove

set -euo pipefail

DRY=1
[ "${1:-}" = "--yes" ] && DRY=0

APPIMAGE="$HOME/Applications/Vibemis.AppImage"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON="$HOME/.local/share/icons/hicolor/256x256/apps/vibemis.png"

# Build the list of targets that exist.
TARGETS=()
[ -e "$APPIMAGE" ] && TARGETS+=("$APPIMAGE")
[ -e "$DESKTOP_DIR/vibemis.desktop" ] && TARGETS+=("$DESKTOP_DIR/vibemis.desktop")
for f in "$DESKTOP_DIR"/vibemis-game-*.desktop; do
    [ -e "$f" ] && TARGETS+=("$f")
done
[ -e "$ICON" ] && TARGETS+=("$ICON")

if [ "${#TARGETS[@]}" -eq 0 ]; then
    echo "Nothing to remove — no Vibemis desktop integration found."
    exit 0
fi

if [ "$DRY" -eq 1 ]; then
    echo "These would be removed (re-run with --yes to delete):"
    printf '  %s\n' "${TARGETS[@]}"
    echo ""
    echo "Note: this does not remove Steam shortcuts or your settings (~/.config/Vibemis)."
    exit 0
fi

for t in "${TARGETS[@]}"; do
    rm -f "$t"
    echo "removed: $t"
done

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
fi
echo "Done. (Remove any Vibemis Steam shortcuts from Steam manually; settings kept.)"
