#!/bin/bash
# vibemis-doctor.sh — quick environment diagnostics for Vibemis (P3.10)
#
# Read-only checks that help diagnose the most common Vibemis problems on SteamOS / Linux
# (VAAPI/Mesa, FUSE, GPU, install state, host reachability). Paste the output into a bug
# report. No sudo, no changes made.
#
# Usage:
#   ./vibemis-doctor.sh                 # environment checks
#   ./vibemis-doctor.sh <host-or-ip>    # also test reachability of a host

set -uo pipefail

ok()   { echo "  [ok]   $*"; }
warn() { echo "  [warn] $*"; }
info() { echo "  [info] $*"; }

echo "=== Vibemis doctor ==="
echo ""

echo "OS / kernel:"
( . /etc/os-release 2>/dev/null && info "${PRETTY_NAME:-unknown}" ) || info "unknown distro"
info "$(uname -srm)"
echo ""

echo "GPU / Mesa:"
if command -v glxinfo >/dev/null 2>&1; then
    glxinfo 2>/dev/null | grep -E 'OpenGL renderer|OpenGL version' | sed 's/^/  /' || warn "glxinfo gave no GL info"
else
    info "glxinfo not present (mesa-utils); skipping GL renderer check"
fi
if command -v lspci >/dev/null 2>&1; then
    lspci 2>/dev/null | grep -iE 'vga|3d|display' | sed 's/^/  /' || true
fi
echo ""

echo "VAAPI (hardware decode):"
if command -v vainfo >/dev/null 2>&1; then
    if vainfo 2>/dev/null | grep -qiE 'VAProfile'; then
        ok "vainfo reports VAAPI profiles (HW decode available)"
        vainfo 2>/dev/null | grep -iE 'Driver version' | sed 's/^/  /' || true
    else
        warn "vainfo present but reported no profiles — VAAPI may not be working"
    fi
else
    info "vainfo not present (libva-utils); Vibemis bundles its own libva handling"
fi
for d in /usr/lib/x86_64-linux-gnu/dri /usr/lib64/dri /usr/lib/dri; do
    [ -d "$d" ] && info "DRI drivers dir: $d"
done
echo ""

echo "FUSE (needed to run AppImages without --appimage-extract-and-run):"
if ldconfig -p 2>/dev/null | grep -q 'libfuse.so.2'; then
    ok "libfuse2 present — AppImages run directly"
else
    warn "libfuse2 NOT found — run the AppImage with --appimage-extract-and-run (normal on SteamOS)"
fi
echo ""

echo "Vibemis install state:"
if [ -x "$HOME/Applications/Vibemis.AppImage" ]; then
    ok "~/Applications/Vibemis.AppImage present"
else
    info "~/Applications/Vibemis.AppImage not installed (run scripts/install-vibemis-desktop.sh)"
fi
[ -f "$HOME/.local/share/applications/vibemis.desktop" ] && ok "desktop entry present" || info "no desktop entry"
if [ -f "$HOME/.config/Vibemis Project/Vibemis.conf" ]; then
    ok "settings present (~/.config/Vibemis Project/Vibemis.conf)"
else
    info "no settings yet (first run)"
fi
echo ""

HOST="${1:-}"
if [ -n "$HOST" ]; then
    echo "Host reachability ($HOST):"
    if ping -c1 -W2 "$HOST" >/dev/null 2>&1; then
        ok "ping reachable"
    else
        warn "ping failed (host may block ICMP, or be unreachable / wrong address)"
    fi
    # Sunshine/Apollo HTTPS pairing port
    if command -v curl >/dev/null 2>&1; then
        if curl -ksS --connect-timeout 3 "https://$HOST:47984" >/dev/null 2>&1; then
            ok "host streaming port 47984 reachable"
        else
            warn "port 47984 not reachable (host not running / firewall / wrong address)"
        fi
    fi
    echo ""
fi

echo "=== done ==="
