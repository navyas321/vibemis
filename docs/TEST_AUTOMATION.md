# Automating verification on the Legion Go S Z2 test agent

Concrete, in-constraints ways to automate test cycles on SteamOS — **Desktop Mode (KDE)** and
**Game Mode (Gamescope)** — without breaking the test agent's hard rules (no `sudo` beyond
read-only, no package installs, don't modify the AppImage). The aim: turn launcher-side Tier-1
checks into a one-command script, and make Game-Mode checks repeatable.

## 1. Headless self-test (the fastest signal) — `vibemis selftest`
Once **test52** merges, the client supports a scriptable, non-destructive smoke test that needs no
host, stream, or window and runs before GUI init:

```bash
APP=~/Downloads/Vibemis-x86_64.AppImage
"$APP" selftest > /tmp/vibemis-selftest.log 2>&1; echo "exit=$?"
grep -q "SELFTEST RESULT: PASS" /tmp/vibemis-selftest.log && echo "SMOKE OK" || echo "SMOKE FAIL"
```
- Exit code `0` = all checks PASS, `1` = a failure. Each check prints `SELFTEST <name>: PASS|FAIL`.
- **Machine-readable:** `"$APP" selftest --json 2>/dev/null` prints a single JSON object
  `{"result","failures","checks":{…}}`. Use `2>/dev/null` (the AppRun hook + Qt platform warnings
  go to **stderr**) so the stdout is pure JSON for `python3 -c 'import json,sys;json.load(sys.stdin)'`.
- Use this as the first step of every cycle: if the build can't even initialise its prefs on the
  device, stop and report before doing anything else.

## 2. Log-driven assertions (works today, any mode)
Run the app for a bounded time, then grep the log for expected signals — no GUI scraping needed.

```bash
APP=~/Downloads/Vibemis-x86_64.AppImage
timeout 25s "$APP" > /tmp/vibemis-run.log 2>&1 &
PID=$!; sleep 20; kill $PID 2>/dev/null; wait $PID 2>/dev/null
grep -iE "EGLRenderer|renderer selected|overlay|error|FFmpeg" /tmp/vibemis-run.log
```
Good signals to assert on: the active renderer (expect **EGLRenderer** on this AMD APU), absence of
`SEGV`/`Critical`, decoder selection, overlay init. Quote the 2–3 lines that answer the question.

## 3. Screenshots (visual checks)
- **Game Mode (Gamescope):** press **Super + S** → saves to `/tmp/gamescope_<date>.png`. From a
  shell you can list/pull the newest: `ls -t /tmp/gamescope_*.png | head -1`.
- **Driving value-bound UI on Wayland (test agent tip, from the test53 cycle):** KWin (Plasma
  Wayland) silently drops synthetic XTEST clicks into native-Wayland surfaces, so `xdotool`
  click/type won't land. Two reliable workarounds with no installs/sudo: (a) launch with
  `QT_QPA_PLATFORM=xcb ./Vibemis-x86_64.AppImage` → it's a real **XWayland** window `xdotool` can
  warp/click/type; (b) for settings that are **value-bound** (render from the current pref, not an
  `onActivated` event), pre-seed the keys in `~/.config/Vibemis Project/Vibemis.conf` (back it up
  first) and relaunch — this reproduces the exact UI state a dropdown/slider change produces.
- **Desktop Mode (KDE):** Spectacle has a CLI —
  `spectacle -b -n -a -o /tmp/vibemis-shot.png` (`-b` background, `-n` no notify, `-a` active
  window). Pre-installed on SteamOS. Use it to capture the launcher/Settings to confirm a control
  is present (e.g. the perf-overlay dropdown, the Tailscale checkbox).
- Compare against the previous build's screenshot to spot UI regressions; attach the image path in
  the report.

## 4. Headless host/discovery checks via existing CLI
The client already ships these CLI verbs (no GUI):
- `vibemis list <host>` — list a host's apps (also proves pairing/reachability). `--csv` for parsing.
- `vibemis quit <host>` — quit the running app.
These let you assert host reachability / app presence in a script without opening the UI. (Don't
`pair`/`stream` unless the instructions say to.)

## 5. Running in Game Mode repeatably
Game Mode runs under Gamescope (single Vulkan surface). To exercise it:
1. Add the AppImage as a non-Steam game once (see `scripts/add-game-to-steam.sh`).
2. From Game Mode you can launch it via Steam; for headless commands (like `selftest`) a Konsole/
   SSH shell in the Game Mode session works too.
3. For overlay/positioning features, capture with **Super+S** and inspect the PNG — Game Mode is the
   authoritative result (a feature that only works in Desktop Mode is not done).

## 6. Emulating Game Mode from Desktop Mode (nested gamescope) — `scripts/gamescope-emulate.sh`
Section 5 needs you to actually be in Game Mode. You can instead **emulate** that environment from
a Desktop-Mode shell: a nested, **headless** gamescope with the host FROG WSI Vulkan layer active
(`ENABLE_GAMESCOPE_WSI=1`) reproduces the same gamescope + single-Vulkan-surface + WSI-layer stack
Game Mode uses — so Game-Mode-only failures (WSI-layer crashes, surface creation, overlay) show up
without switching modes and without drawing anything on the KDE desktop.

```bash
scripts/gamescope-emulate.sh                                   # default: ~/Downloads/Vibemis.AppImage
scripts/gamescope-emulate.sh -o -s /tmp/vib.png               # + capture the mangoapp/FPS overlay plane
scripts/gamescope-emulate.sh -- ~/Applications/Vibemis.AppImage selftest
echo "opened in gamescope: exit=$?"                            # 0 = opened & rendered, 1 = crashed/died
```
It launches the app inside `gamescope --backend headless -w 1920 -h 1200 --mangoapp`, waits, then
reports: **ALIVE/DIED**, new **coredumps**, whether `[Gamescope WSI] Made gamescope surface` appeared
(the WSI/HDR path was exercised), and any `vkroots`/`Assertion 'obj'`/SIGABRT crash line — and saves a
screenshot. Two gotchas the script handles for you:
- **Force X11.** The app must render on the nested XWayland, not the wayland surface, or the WSI layer
  logs `Failed to get Wayland objects`. The script wraps the command in `env -u WAYLAND_DISPLAY`
  (for flatpak, add `--socket=x11 --nosocket=wayland`).
- **Two planes.** `gamescopectl screenshot` captures only the primary/game plane (the app UI). The
  **mangoapp/FPS overlay is a separate layer** it doesn't include — `-o` grabs the overlay window
  (`GAMESCOPE_EXTERNAL_OVERLAY=1`, named `mangoapp overlay window`) directly off nested X `:1` with
  `ffmpeg -window_id`, and forces a visible `MANGOHUD_CONFIGFILE` (default is `no_display`).

Between runs a crashed nested gamescope leaves stale `/tmp/.X{1,2}-lock` + `gamescope-0` sockets and
the next run dies with `XIO: fatal IO error 17 (File exists) on X server :1`; the script cleans these
(never touching `:0`, the real desktop). Real Game Mode (section 5) is still the authoritative result —
this is the fast pre-check and the way to reproduce a Game-Mode-only bug on demand.

## 7. Putting it together — a cycle skeleton
```bash
#!/bin/bash
APP=~/Downloads/Vibemis-x86_64.AppImage
md5sum "$APP"
echo "== env =="; grep VERSION= /etc/os-release; glxinfo 2>/dev/null | grep "OpenGL version"
echo "== smoke =="; "$APP" selftest; echo "exit=$?"
echo "== run/log =="; timeout 25s "$APP" >/tmp/run.log 2>&1 & sleep 20; kill %1 2>/dev/null
grep -iE "EGLRenderer|error|SEGV|overlay" /tmp/run.log
# (feature-specific Desktop/Game-Mode screenshot + assertion goes here per instructions.md)
```
Keep raw logs in `/tmp/`; paste only the 10–20 lines that answer each check into `report.md`.

## What still needs a human / can't be auto-asserted yet
Frame pacing feel, HDR color accuracy, input latency, and "does the picture look right" are
subjective — capture a screenshot + the stats overlay and describe, don't pretend a script decided.
End-to-end **stream** correctness still needs a paired host and remains a guided (not fully
automated) step. A future enhancement could add `--selftest=render` to validate the offscreen
Quick-Menu surface headlessly; tracked in `docs/PHASE_STATUS.md`.
