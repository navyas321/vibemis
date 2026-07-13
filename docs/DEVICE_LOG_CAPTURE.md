# Device log capture — the Steam logged-launch wrapper trick

A proven trick (used through the 1.0.x stable-gate cycles, e.g. the BL-1619 input-lag flood
capture) for grabbing Vibemis's full stdout/stderr from **Steam Game Mode launches** on the
test device, where there is no terminal to read from.

## The problem

In Game Mode (gamescope) the app's console output goes nowhere. Steam's own logs don't carry
the app's Qt/SDL diagnostics, and `/tmp` is a RAM tmpfs on SteamOS, so anything dropped there
dies with the session. When a bug only reproduces from a real Steam launch (Steam Input
routing, gamescope WSI, controller mapping), you need the launch itself to write a log.

## The trick

A tiny wrapper script lives OUTSIDE the AppImage's directory (so AppImage updates never
clobber it), e.g. `/home/deck/vibemis-logged-launch.sh`:

```bash
#!/bin/bash
# Vibemis logging launch wrapper.
LOG=/home/deck/vibemis-device.log

# Rotate: keep the previous run as .1 so a good capture isn't lost on the next launch.
[ -f "$LOG" ] && mv -f "$LOG" "$LOG.1" 2>/dev/null

{
  echo "===== vibemis launch $(date '+%Y-%m-%d %H:%M:%S %Z') ====="
  echo "cmd: $*"
  echo "======================================================"
} >"$LOG" 2>/dev/null

# If Steam somehow passed nothing, fall back to the AppImage directly.
if [ "$#" -eq 0 ]; then
  set -- /home/deck/Downloads/Vibemis.AppImage
fi

# exec so Steam/gamescope tracks the real process (suspend/resume, overlay, exit detection).
exec "$@" >>"$LOG" 2>&1
```

Wire-up in Steam (Desktop or Game Mode → Vibemis → Properties → Launch Options):

```
/home/deck/vibemis-logged-launch.sh %command%
```

Steam expands `%command%` to the real AppImage invocation (path + any args), the wrapper
receives it as `"$@"`, stamps a wall-clock header (lines up "burst after a button press"
reports), and `exec`s it with all output appended to the log.

## Why each piece matters

- **`%command%` in Launch Options, Target untouched** — the shortcut keeps pointing at the
  stable AppImage path, so build updates (overwrite-in-place) never break the wiring.
- **`exec`** — Steam/gamescope must track the real app PID, not a bash parent, or exit
  detection and the Steam overlay misbehave.
- **One-deep rotation (`.log` → `.log.1`)** — a good capture isn't lost when someone
  relaunches before the log is pulled; deeper rotation is noise for a test device.
- **Log in `$HOME`, wrapper in `$HOME`** — survives reboots (tmpfs `/tmp` doesn't) and
  survives AppImage replacement.
- **Fallback when `$#` is 0** — a bare double-click of the wrapper still launches the app.

## Current status on the test device (2026-07-13)

The wrapper file is kept at `/home/deck/vibemis-logged-launch.sh` but is **detached** — the
Steam shortcut's Launch Options are empty for normal day-to-day use. Re-attach the one
Launch Options line above when a Game-Mode launch needs to be captured, and detach it again
after the capture. Editing Launch Options via the Steam UI is safe while Steam runs; editing
`shortcuts.vdf` directly requires Steam to be fully closed first (it rewrites the file on
exit) and restarted after.
