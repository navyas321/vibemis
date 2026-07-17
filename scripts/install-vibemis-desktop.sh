#!/bin/bash
# install-vibemis-desktop.sh — Vibemis desktop & Steam integration
#
# Problem: when you right-click an AppImage and choose "Add to Steam", Steam names the
# shortcut after the *filename* (e.g. "Vibemis-0.6.7-...-x86_64.AppImage"). This installs
# Vibemis to a stable path with a clean name so it shows as just "Vibemis" everywhere —
# in your application launcher and when added to Steam.
#
# Usage:
#   ./install-vibemis-desktop.sh /path/to/Vibemis-<version>-x86_64.AppImage
#   (if no path is given, it looks for a Vibemis*.AppImage next to this script / in the CWD)
#
# Safe + idempotent: copies to ~/Applications/Vibemis.AppImage and writes a .desktop file
# under ~/.local/share/applications. No sudo, no system files touched.

set -e

SRC="$1"
if [ -z "$SRC" ]; then
    SRC="$(ls -1 ./Vibemis*.AppImage 2>/dev/null | head -1 || true)"
fi
if [ -z "$SRC" ] || [ ! -f "$SRC" ]; then
    echo "ERROR: pass the path to a Vibemis AppImage, e.g.:" >&2
    echo "  $0 ~/Downloads/Vibemis-0.6.7-x86_64.AppImage" >&2
    exit 1
fi

APP_DIR="$HOME/Applications"
DEST="$APP_DIR/Vibemis.AppImage"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/vibemis.desktop"

mkdir -p "$APP_DIR" "$ICON_DIR" "$DESKTOP_DIR"

echo "Installing Vibemis to $DEST ..."
cp -f "$SRC" "$DEST"
chmod +x "$DEST"

# Best-effort: extract the bundled icon so launchers/Steam show artwork.
ICON_LINE="vibemis"
if "$DEST" --appimage-extract 'usr/share/icons/hicolor/256x256/apps/vibemis.png' >/dev/null 2>&1 \
   && [ -f squashfs-root/usr/share/icons/hicolor/256x256/apps/vibemis.png ]; then
    cp -f squashfs-root/usr/share/icons/hicolor/256x256/apps/vibemis.png "$ICON_DIR/vibemis.png"
    rm -rf squashfs-root
    ICON_LINE="$ICON_DIR/vibemis.png"
fi

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Vibemis
GenericName=Game Streaming Client
Comment=Stream games from your Apollo/Vibepollo/Sunshine host
Exec="$DEST" %U
Icon=$ICON_LINE
Categories=Game;
Keywords=moonlight;apollo;vibepollo;streaming;steam;
Terminal=false
StartupWMClass=Vibemis
EOF
chmod +x "$DESKTOP_FILE"

# Refresh the desktop database if the tool is available (non-fatal if not).
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
fi

echo ""
echo "Done. Vibemis is installed as a clean desktop entry named 'Vibemis'."
echo ""
echo "To add it to Steam with the right name:"
echo "  1. In Steam (Desktop Mode): Games -> Add a Non-Steam Game to My Library"
echo "  2. Tick 'Vibemis' in the list (it appears via the desktop entry), or Browse to:"
echo "       $DEST"
echo "  3. The shortcut will be named 'Vibemis' (not the AppImage filename)."
echo "  4. Switch to Game Mode -> Vibemis appears under Non-Steam Games."
