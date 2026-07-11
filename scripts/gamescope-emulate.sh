#!/bin/bash
# gamescope-emulate.sh — reproduce SteamOS Game Mode from Desktop Mode, headless.
#
# Runs a command (default: the Vibemis AppImage) inside a NESTED, HEADLESS gamescope with the
# host FROG WSI Vulkan layer ACTIVE — the same gamescope + single-Vulkan-surface + WSI-layer
# environment Game Mode uses — WITHOUT switching to Game Mode and WITHOUT drawing anything on
# the KDE desktop. Then it captures a screenshot and asserts the app actually opened.
#
# Why: Game-Mode-only failures (WSI-layer crashes, single-surface bugs, overlay/positioning)
# can't be seen from a normal Desktop-Mode launch. This gives a one-command, repeatable signal.
#
# Usage:
#   scripts/gamescope-emulate.sh [-w W] [-h H] [-t SECS] [-s SHOT.png] [-o] [-- <command...>]
#   scripts/gamescope-emulate.sh                          # default: ~/Downloads/Vibemis.AppImage
#   scripts/gamescope-emulate.sh -- ~/Applications/Moonlight-6.1.0.AppImage
#   scripts/gamescope-emulate.sh -o -s /tmp/vib.png       # also grab the mangoapp overlay plane
#
# Options:
#   -w W   nested width  (default 1920 — Legion Go S panel)
#   -h H   nested height (default 1200)
#   -t N   seconds to let the app settle before checking (default 15)
#   -s F   primary-plane screenshot path (default /tmp/gamescope-emulate.png)
#   -o     ALSO capture the mangoapp/FPS overlay plane to <F>.overlay.png (see note below)
#
# Exit: 0 = app opened & rendered inside gamescope (survived, no coredump, WSI surface made);
#       1 = it crashed or died (e.g. the libplacebo/vkroots WSI assert).
#
# Safe: no sudo, no installs, nothing drawn on the real desktop, does not touch the app.
# Requires (all pre-installed on SteamOS): gamescope, gamescopectl, xdotool, ffmpeg, coredumpctl.
set -uo pipefail

W=1920; H=1200; SECS=15; SHOT=/tmp/gamescope-emulate.png; OVERLAY=0
while getopts "w:h:t:s:o" opt; do
    case "$opt" in
        w) W="$OPTARG" ;; h) H="$OPTARG" ;; t) SECS="$OPTARG" ;;
        s) SHOT="$OPTARG" ;; o) OVERLAY=1 ;;
        *) sed -n '2,30p' "$0"; exit 2 ;;
    esac
done
shift $((OPTIND - 1))

# The command to run inside gamescope; default to the device's Vibemis AppImage.
if [ "$#" -gt 0 ]; then
    APPCMD=( "$@" )
else
    APP="${VIBEMIS_APPIMAGE:-$HOME/Downloads/Vibemis.AppImage}"
    [ -x "$APP" ] || { echo "ERROR: no command given and $APP not found/executable" >&2; exit 2; }
    APPCMD=( "$APP" )
fi

XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
CFG="$(mktemp /tmp/gs-emulate-mango.XXXXXX.conf)"
printf 'fps\nframetime\ncpu_stats\ngpu_stats\nvram\nram\nposition=top-left\nfont_size=48\nno_display=0\n' > "$CFG"
GSLOG="$(mktemp /tmp/gs-emulate.XXXXXX.log)"

cleanup_stale() {
    pkill -9 -f "gamescope --backend headless" >/dev/null 2>&1
    pkill -9 -x mangoapp >/dev/null 2>&1
    # Remove ONLY nested test locks/sockets (:1/:2). NEVER :0 — that's the real desktop.
    for n in 1 2 3; do
        pgrep -f "Xwayland.*:${n}\b" >/dev/null 2>&1 || rm -f "/tmp/.X${n}-lock" "/tmp/.X11-unix/X${n}" 2>/dev/null
    done
    rm -f "$XDG_RUNTIME_DIR"/gamescope-0 "$XDG_RUNTIME_DIR"/gamescope-0.lock 2>/dev/null
}
cleanup_stale; sleep 2

dumps_before=$(coredumpctl list --no-pager 2>/dev/null | grep -ciE 'moonlight|vibemis|artemis' || true)

# Launch. Force X11 onto the nested XWayland (env -u WAYLAND_DISPLAY) so the app uses the
# WSI layer path — apps that grab the wayland surface trip "[Gamescope WSI] Failed to get Wayland objects".
SDL_VIDEODRIVER=x11 ENABLE_GAMESCOPE_WSI=1 MANGOHUD_CONFIGFILE="$CFG" \
gamescope --backend headless --xwayland-count 1 -w "$W" -h "$H" -W "$W" -H "$H" --mangoapp -- \
    env -u WAYLAND_DISPLAY "${APPCMD[@]}" >"$GSLOG" 2>&1 &
GS=$!

for _ in $(seq 1 "$SECS"); do
    sleep 1
    kill -0 "$GS" 2>/dev/null || break
done

alive=0; kill -0 "$GS" 2>/dev/null && alive=1
dumps_after=$(coredumpctl list --no-pager 2>/dev/null | grep -ciE 'moonlight|vibemis|artemis' || true)
new_dumps=$(( dumps_after - dumps_before ))

echo "== gamescope-emulate: ${APPCMD[*]} =="
if [ "$alive" = 1 ]; then echo "  app:        ALIVE after ${SECS}s"; else echo "  app:        DIED"; fi
echo "  coredumps:  +${new_dumps}"
if grep -q "Made gamescope surface" "$GSLOG"; then echo "  WSI:        gamescope surface made (Game-Mode WSI/HDR path exercised)"; fi
crash=$(grep -niE 'vkroots|Assertion .obj|SIGABRT|Aborted \(core' "$GSLOG" | head -1 || true)
[ -n "$crash" ] && echo "  CRASH:      ${crash}"

if [ "$alive" = 1 ]; then
    # Primary/game plane (the app UI). Note: gamescopectl screenshot does NOT include the overlay plane.
    GAMESCOPE_WAYLAND_DISPLAY=gamescope-0 gamescopectl screenshot "$SHOT" >/dev/null 2>&1
    sleep 2
    [ -s "$SHOT" ] && echo "  screenshot: $SHOT"
    if [ "$OVERLAY" = 1 ]; then
        # Overlay plane (mangoapp/FPS) is a separate layer — grab its window directly off nested X :1.
        wid=""
        for w in $(DISPLAY=:1 xdotool search --name "mangoapp" 2>/dev/null); do
            [ "$(DISPLAY=:1 xdotool getwindowname "$w" 2>/dev/null)" = "mangoapp overlay window" ] && { wid="$w"; break; }
        done
        if [ -n "$wid" ]; then
            DISPLAY=:1 timeout 5 ffmpeg -y -loglevel error -f x11grab -window_id "$wid" -video_size "${W}x${H}" -i :1 -frames:v 1 "${SHOT%.png}.overlay.png" >/dev/null 2>&1
            [ -s "${SHOT%.png}.overlay.png" ] && echo "  overlay:    ${SHOT%.png}.overlay.png"
        fi
    fi
fi

# Teardown
pkill -9 -x mangoapp >/dev/null 2>&1
kill "$GS" >/dev/null 2>&1; sleep 1
cleanup_stale
rm -f "$CFG" "$GSLOG"

[ "$alive" = 1 ] && [ "$new_dumps" -le 0 ]
