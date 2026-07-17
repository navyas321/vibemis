#!/bin/bash
# add-game-to-steam.sh — make a direct-launch shortcut for one host game
#
# Creates a .desktop entry that launches Vibemis straight into a specific game's stream via
# the CLI (`vibemis stream "<host>" "<app>"`). Add that entry to Steam and the Steam Deck
# shortcut will boot directly into the game — no menus.
#
# Usage:
#   ./add-game-to-steam.sh "<HostName>" "<App or Game name>"
#   ./add-game-to-steam.sh "GLADOS" "Desktop"
#
# Tips:
#   - Host name + app name must match what Vibemis sees. List them with:
#       ~/Applications/Vibemis.AppImage list "<HostName>"
#   - Run install-vibemis-desktop.sh first so ~/Applications/Vibemis.AppImage exists
#     (override with VIBEMIS_APPIMAGE=/path/to/Vibemis.AppImage).
#
# Safe: writes only a .desktop under ~/.local/share/applications. No sudo.

set -euo pipefail

HOST="${1:-}"
APP="${2:-}"
if [ -z "$HOST" ] || [ -z "$APP" ]; then
    echo "Usage: $0 \"<HostName>\" \"<App/Game name>\"" >&2
    echo "  e.g. $0 \"GLADOS\" \"Portal 2\"" >&2
    exit 1
fi

APPIMAGE="${VIBEMIS_APPIMAGE:-$HOME/Applications/Vibemis.AppImage}"
if [ ! -x "$APPIMAGE" ]; then
    echo "ERROR: Vibemis AppImage not found/executable at: $APPIMAGE" >&2
    echo "  Run scripts/install-vibemis-desktop.sh first, or set VIBEMIS_APPIMAGE=/path/to/Vibemis.AppImage" >&2
    exit 1
fi

DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$DESKTOP_DIR"

# Sanitize the app name into a filename slug.
SLUG=$(echo "$APP" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//')
DESKTOP_FILE="$DESKTOP_DIR/vibemis-game-$SLUG.desktop"

# Escape double quotes inside Exec.
HOST_ESC=${HOST//\"/\\\"}
APP_ESC=${APP//\"/\\\"}

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=$APP (Vibemis)
GenericName=Streamed Game
Comment=Stream "$APP" from $HOST via Vibemis
Exec="$APPIMAGE" stream "$HOST_ESC" "$APP_ESC"
Icon=vibemis
Categories=Game;
Keywords=vibemis;moonlight;apollo;stream;$SLUG;
Terminal=false
StartupWMClass=Vibemis
EOF
chmod +x "$DESKTOP_FILE"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
fi

echo "Created: $DESKTOP_FILE"
echo "  launches: \"$APPIMAGE\" stream \"$HOST\" \"$APP\""
echo ""
echo "Add it to Steam (Desktop Mode):"
echo "  Steam -> Games -> Add a Non-Steam Game -> tick \"$APP (Vibemis)\" (or Browse to the AppImage)."
echo "  In Game Mode, launching that shortcut streams the game directly."
echo ""
echo "NOTE: the host must already be paired in Vibemis, and \"$APP\" must appear in:"
echo "  \"$APPIMAGE\" list \"$HOST\""
