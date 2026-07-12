# Vibemis test automation — platform matrix & robust input/stream harness

This directory holds the **automated** test-platform tooling for the Legion Go S Z2 (SteamOS,
AMD Ryzen Z2 Go). It exists because a maintainer + test-agent RCA found two recurring gaps:

1. The full-fidelity **mock-Vibepollo** streaming validation was only ever done *by hand*.
2. The headless **uinput input** daemons (mouse/keyboard) "wouldn't reach ready", blocking all
   automated UI navigation and in-stream gamepad tests — but the *actual* fault was in the
   **launchers**, not the daemons (see RCA below).

## The test-platform matrix — pick the right target for what you're proving

| Target | What it can prove | What it CANNOT prove | Use for |
|---|---|---|---|
| **Headless gamescope** (`scripts/gamescope-emulate.sh`) | App launches, renders a surface, Game-Mode WSI/HDR path, UI layout, decode of a *real* remote stream | Nothing that needs a physical seat's Steam Input | Render/crash gates, screenshot diffs, decode gates |
| **Self-host Sunshine** (`127.0.0.1`) | Control plane only — pairing, serverinfo, applist, RTSP/launch negotiation (~25-30% fidelity) | **No video** — the loopback host has no GPU encoder, so no frames ever decode | Control-plane regression only. **Never** cite it as a streaming/decode pass |
| **Mock Vibepollo** (`100.127.67.80` "hearth", ports 48900/48895/48901) | **Full real fidelity** — real Vibepollo 1.18 + SudoVDA Virtual Display + `-1` no-state. Actually **encodes + streams**, so the client HEVC/VAAPI **decode + EGL render** path runs for real | Physical controller routing (that's Game Mode + Steam Input) | The definitive streaming/decode validation (`mock-vibepollo-smoke.sh`) |
| **Real host** (Navid-PC `192.168.4.78`, Apollo 7.1.x) | Same as mock, plus real-app launch | — | Final acceptance; when the mock is offline |
| **Physical device, Game Mode** | Steam Input → virtual gamepad routing, host-display restore | Can't be driven headlessly/unattended | Manual controller + display-restore tests (test9 lesson) |

**Rule of thumb:** headless = *render* only; self-host = *control-plane* only; **mock/real-host =
the only targets that prove streaming + decode.** Don't conflate them — a green self-host run says
nothing about whether video decodes.

## Contents

### `vinput.py` — robust uinput virtual input (mouse / gamepad / keyboard)
Supersedes the throwaway `/tmp/vmouse-daemon.py` + `/tmp/vkbd.py`. One tool, three device types,
with `--selftest` for each.

```bash
# self-tests (create device, verify kernel enumeration + handler class, inject, destroy)
python3 vinput.py mouse   --selftest      # -> mouseN pointer
python3 vinput.py gamepad --selftest      # -> jsN joystick (Xbox-360 layout)
python3 vinput.py key     --selftest

# run a daemon — ALWAYS detached (</dev/null so it can't hold the caller's stdout), then POLL .ready
python3 vinput.py mouse start --fifo /tmp/vmouse.cmd --pidfile /tmp/vmouse.pid </dev/null >/tmp/vmouse.boot 2>&1 &
until [ -f /tmp/vmouse.cmd.ready ]; do sleep 0.2; done

# send commands — never hangs (opens O_WRONLY|O_NONBLOCK; instant ENXIO if the daemon is dead)
python3 vinput.py mouse   send --fifo /tmp/vmouse.cmd "MC 640 400"          # move+click
python3 vinput.py gamepad send --fifo /tmp/vpad.cmd   "PRESS BTN_SOUTH"
python3 vinput.py gamepad send --fifo /tmp/vpad.cmd   "PRESS PADDLE_BACK"   # test36 quick-menu paddle

# stop — by PID from the pidfile (safe; never a `-f` pattern that can self-match, see RCA)
python3 vinput.py mouse stop --pidfile /tmp/vmouse.pid
```

Gamepad buttons: `BTN_SOUTH/EAST/WEST/NORTH` (A/B/X/Y), `BTN_TL/TR` (LB/RB), `SELECT/START/MODE`,
`BTN_THUMBL/THUMBR`, and `PADDLE_BACK` (the Legion back paddle — defaults to `BTN_TRIGGER_HAPPY1`
at the evdev level; override with `VINPUT_PADDLE_CODE=0x13a` to map it to SELECT, etc.).

### `mock-vibepollo-smoke.sh` — automated full-fidelity streaming validation
Three phases: (1) TCP reachability of the mock's 3 ports, (2) applist over paired HTTPS,
(3) a gamescope-hosted `stream ... "Virtual Display"` that captures a frame and greps for the real
decode signals. Serialized on `scripts/gamescope-lease.sh`; every app run is `timeout -s KILL`
guarded (the CLI hangs headless and ignores SIGTERM).

```bash
testing/automation/mock-vibepollo-smoke.sh              # full run (needs the gamescope lease)
testing/automation/mock-vibepollo-smoke.sh --reach-only # just phase 1 (no gamescope, safe anytime)
```

Validated 2026-07-12 on `Vibemis.AppImage`: **3/3 core decode signals** —
`Output frame with POC`, VAAPI `Decode to surface`, `EGLRenderer` — HEVC hardware-decoded via
VAAPI (Mesa radeonsi, Ryzen Z2 Go) with a captured 1920x1200 frame.

## RCA — why the headless input "wouldn't reach ready" (it was never the daemon)

The daemon *code* (device creation, `UI_DEV_CREATE`, FIFO loop) works perfectly — proven by
`vinput.py <kind> --selftest` and by launching the original daemon detached (it prints
`vmouse ready`, enumerates as `event/mouse/js`, and consumes its FIFO). Every reported failure came
from the **launcher**, and there are three distinct traps — all now designed out of `vinput.py`
and `mock-vibepollo-smoke.sh`:

1. **Self-killing process cleanup (the big one).** Launch scripts began with
   `pkill -9 -f vmouse-daemon`. `pkill -f` / `pgrep -f` match the **entire command line**. When the
   whole launcher runs inline (`bash -c '…long script mentioning vmouse-daemon…'`), that command
   line *contains the pattern*, so pkill **SIGKILLs its own shell** before the daemon starts.
   Result = the exact reported triad: empty daemon log ("never prints ready"), FIFO never consumed
   (no reader), and every `echo > fifo` hangs forever (open-for-write blocks with no reader). The
   same trap fires via `scripts/gamescope-lease.sh`'s `gs_clean` (`pgrep -f 'gamescope --backend
   headless'`) against any caller whose command line contains that literal.
   **Design-out:** stop daemons **by PID** (pidfile); invoke helper scripts **by path**, never
   inline a launch string that a downstream `pkill/pgrep -f` will match.

2. **Inherited stdout pipe.** A daemon backgrounded as `python3 daemon.py &` inherits the launcher's
   stdout/stderr, then blocks forever in its command loop holding that pipe open — so the launcher's
   harness never sees EOF and the whole call hangs.
   **Design-out:** always start detached `</dev/null >LOG 2>&1 &`; signal readiness with a `.ready`
   **sentinel file** the caller **polls**, never by reading an inherited pipe.

3. **FIFO writer hang.** A plain read-only FIFO server leaves windows where a writer blocks.
   **Design-out:** the daemon holds the FIFO **`O_RDWR`** (it owns a write end too) so external
   writers never block on open; and `send` opens **`O_WRONLY|O_NONBLOCK`** so a *dead* daemon makes
   the write fail instantly (`ENXIO`) instead of hanging.

### Known limitation — event-readback needs the `input` group
`--selftest` Tier 1 (device enumeration + correct handler class + accepted injection) runs
unprivileged. Tier 2 (reading the injected events back off `/dev/input/eventN` to prove
registration) needs read on the event node — which requires membership in group `input` or a
per-seat logind ACL. On this box `deck` has neither (fresh uinput nodes get no seat ACL, and adding
a group / sudo is out of scope), so Tier 2 auto-**skips**. The definitive "input actually reaches
the app" proof is therefore the **integration screenshot-diff** (drive `vinput.py` against the app
inside `gamescope-emulate.sh` and diff the frame), not a unit readback.

## Safety
uinput devices and gamepad presses are **system-wide** (they move the real cursor / press real
buttons). Keep runtime brief, always `stop` (or rely on `--selftest`'s guaranteed `UI_DEV_DESTROY`),
and serialize every gamescope/uinput run on `scripts/gamescope-lease.sh` so you don't collide with
the other test agent on the same physical device.
