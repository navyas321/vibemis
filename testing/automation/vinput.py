#!/usr/bin/env python3
# vinput.py — robust pure-Python /dev/uinput virtual input for Vibemis headless UI automation.
#
# Supersedes the ad-hoc /tmp/vmouse-daemon.py + /tmp/vkbd.py. Provides three device types:
#   mouse    — absolute pointer (a real libinput pointer the gamescope seat enumerates)
#   gamepad  — Xbox-360-style pad (BTN_SOUTH/EAST/WEST/NORTH/TL/TR/SELECT/START/... + back-paddle)
#   key      — keyboard (one-shot key taps)
#
# ================================ WHY THIS REWRITE ==================================
# RCA (2026-07-12): the old daemon *code* was fine — device creation, DEV_CREATE and
# FIFO handling all work. The init failures blamed on it were caused by the LAUNCHER,
# not the daemon:
#
#   1. SELF-KILLING CLEANUP.  The launch scripts began with
#          pkill -9 -f vmouse-daemon        (see scripts' old vmouse-test.sh)
#      `pkill -f` / `pgrep -f` match the FULL command line. When the whole launcher is
#      run inline (bash -c '...long script...'), that command line CONTAINS the string
#      "vmouse-daemon", so pkill SIGKILLs its own shell before the daemon ever starts.
#      Result: empty daemon log ("never prints ready"), no reader on the FIFO, and every
#      subsequent `echo > fifo` hangs forever (open-for-write blocks with no reader).
#      -> FIX: never kill by a `-f` pattern that can appear in the caller. We track a
#         PIDFILE and stop by PID only.
#
#   2. INHERITED STDOUT PIPE.  A daemon backgrounded as `python3 daemon.py &` inherits the
#      launcher's stdout/stderr. It then blocks forever in its command loop while holding
#      that pipe open, so the launcher's harness never sees EOF and hangs the whole call.
#      -> FIX: always start detached: `</dev/null >LOG 2>&1 &`. Readiness is signalled by
#         a READY sentinel FILE that the launcher POLLS — never by reading an inherited pipe.
#
#   3. FIFO WRITER HANG.  A plain read-only FIFO server churns open()/close() per command and
#      leaves windows where a writer blocks.
#      -> FIX: the daemon holds the FIFO open O_RDWR (it owns a write end too), so external
#         `echo > fifo` writers never block on open, and the reader never spuriously hits EOF.
#         The `send` subcommand additionally opens O_WRONLY|O_NONBLOCK so a *dead* daemon makes
#         the write fail instantly (ENXIO) instead of hanging.
#
# ================================ USAGE ============================================
#   Start a detached daemon (ALWAYS redirect + </dev/null; poll the .ready file):
#     python3 vinput.py mouse   start  --fifo /tmp/vmouse.cmd --log /tmp/vmouse.log --pidfile /tmp/vmouse.pid </dev/null >/tmp/vmouse.boot 2>&1 &
#     python3 vinput.py gamepad start  --fifo /tmp/vpad.cmd   --log /tmp/vpad.log   --pidfile /tmp/vpad.pid   </dev/null >/tmp/vpad.boot   2>&1 &
#   Wait for readiness:
#     until [ -f /tmp/vmouse.cmd.ready ]; do sleep 0.2; done
#   Send commands (never hangs — fails fast if daemon is dead):
#     python3 vinput.py mouse   send --fifo /tmp/vmouse.cmd "MC 640 400"     # move+click
#     python3 vinput.py gamepad send --fifo /tmp/vpad.cmd   "PRESS BTN_SOUTH"
#     python3 vinput.py gamepad send --fifo /tmp/vpad.cmd   "PRESS PADDLE_BACK"   # test36 quick-menu paddle
#   Stop (by PID — safe, never self-matches):
#     python3 vinput.py mouse   stop --pidfile /tmp/vmouse.pid
#   Self-tests (create device, inject, READ THE EVENTS BACK to prove they registered, destroy):
#     python3 vinput.py mouse   --selftest
#     python3 vinput.py gamepad --selftest
#     python3 vinput.py key     --selftest
#
# NOTE: uinput devices are SYSTEM-WIDE. `mouse` moves the real cursor and `gamepad` presses real
# buttons. Keep runtime brief and always `stop` / rely on --selftest's guaranteed DEV_DESTROY.

import os, sys, struct, fcntl, time, errno, select, glob, argparse, signal

# ---------------------------------------------------------------- event codes
EV_SYN, EV_KEY, EV_ABS = 0x00, 0x01, 0x03
SYN_REPORT = 0
ABS_X, ABS_Y = 0x00, 0x01
ABS_RX, ABS_RY = 0x03, 0x04
ABS_Z, ABS_RZ = 0x02, 0x05
ABS_HAT0X, ABS_HAT0Y = 0x10, 0x11
BTN_LEFT, BTN_RIGHT, BTN_MIDDLE = 0x110, 0x111, 0x112
BTN_TOOL_PEN = 0x140
# gamepad (Linux "gamepad" button page, what SDL/evdev map for an Xbox-style pad)
BTN_SOUTH, BTN_EAST, BTN_C, BTN_NORTH, BTN_WEST = 0x130, 0x131, 0x132, 0x133, 0x134
BTN_TL, BTN_TR, BTN_TL2, BTN_TR2 = 0x136, 0x137, 0x138, 0x139
BTN_SELECT, BTN_START, BTN_MODE = 0x13a, 0x13b, 0x13c
BTN_THUMBL, BTN_THUMBR = 0x13d, 0x13e
BTN_TRIGGER_HAPPY1 = 0x2c0   # extra buttons — where back paddles typically live at evdev level

# ---------------------------------------------------------------- uinput ioctls (base 'U'=0x55)
UINPUT_IOCTL_BASE = ord('U')
def _IOW(nr, size): return (1 << 30) | (UINPUT_IOCTL_BASE << 8) | nr | (size << 16)
def _IO(nr):        return (UINPUT_IOCTL_BASE << 8) | nr
UI_DEV_CREATE  = _IO(1)
UI_DEV_DESTROY = _IO(2)
UI_SET_EVBIT   = _IOW(100, 4)
UI_SET_KEYBIT  = _IOW(101, 4)
UI_SET_ABSBIT  = _IOW(103, 4)

W, H = 1920, 1200   # panel — absolute mouse coordinate space

# back paddle: at the evdev level physical paddles show up as extra buttons; the exact code the
# app reads varies, so make it overridable. VINPUT_PADDLE_CODE=0x13a would map the paddle to SELECT.
_paddle_env = os.environ.get("VINPUT_PADDLE_CODE", "")
PADDLE_BACK_CODE = int(_paddle_env, 0) if _paddle_env else BTN_TRIGGER_HAPPY1

# gamepad button name -> code
PAD_BUTTONS = {
    "BTN_SOUTH": BTN_SOUTH, "A": BTN_SOUTH,
    "BTN_EAST": BTN_EAST,   "B": BTN_EAST,
    "BTN_NORTH": BTN_NORTH, "Y": BTN_NORTH,
    "BTN_WEST": BTN_WEST,   "X": BTN_WEST,
    "BTN_TL": BTN_TL, "LB": BTN_TL,
    "BTN_TR": BTN_TR, "RB": BTN_TR,
    "BTN_SELECT": BTN_SELECT, "SELECT": BTN_SELECT, "BACK": BTN_SELECT,
    "BTN_START": BTN_START, "START": BTN_START,
    "BTN_MODE": BTN_MODE, "GUIDE": BTN_MODE,
    "BTN_THUMBL": BTN_THUMBL, "BTN_THUMBR": BTN_THUMBR,
    "PADDLE_BACK": PADDLE_BACK_CODE,
}

KEYS = {'ESC':1,'1':2,'N':49,'ENTER':28,'CTRL':29,'F1':59,'LEFT':105,'RIGHT':106,
        'UP':103,'DOWN':108,'MENU':139,'BACKSLASH':43,'M':50,'A':30,'B':48,'X':45,
        'Y':21,'TAB':15,'SPACE':57,'ESCAPE':1}

# input_event struct: timeval(2*long) + type(H) + code(H) + value(i) = 24 bytes on 64-bit
_EV = struct.Struct("@llHHi")
def _emit(fd, t, c, v): os.write(fd, _EV.pack(0, 0, t, c, v))
def _syn(fd): _emit(fd, EV_SYN, SYN_REPORT, 0)

# uinput_user_dev: name[80] + input_id(HHHH) + ff_effects_max(I) + abs{max,min,fuzz,flat}[64]
def _pack_user_dev(name, bus, vendor, product, version, absmax=None, absmin=None):
    absmax = absmax or {}
    absmin = absmin or {}
    mx = [0]*64
    mn = [0]*64
    for a, v in absmax.items(): mx[a] = v
    for a, v in absmin.items(): mn[a] = v
    blob = name.encode().ljust(80, b"\0")
    blob += struct.pack("<HHHH", bus, vendor, product, version) + struct.pack("<I", 0)
    blob += struct.pack("<64i", *mx) + struct.pack("<64i", *mn)
    blob += struct.pack("<64i", *[0]*64) + struct.pack("<64i", *[0]*64)
    assert len(blob) == 1116, len(blob)
    return blob

def _open_uinput():
    return os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)

def _find_device(devname, timeout=3.0):
    """Return (/dev/input/eventN, handlers_str) for a just-created uinput device by parsing sysfs."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        for np in glob.glob("/sys/class/input/input*/name"):
            try:
                with open(np) as f: nm = f.read().strip()
            except OSError: continue
            if nm == devname:
                base = os.path.dirname(np)
                ev = glob.glob(os.path.join(base, "event*"))
                node = "/dev/input/" + os.path.basename(ev[0]) if ev else None
                # handler classes live as sibling dirs: mouseN / jsN / eventN
                handlers = " ".join(sorted(os.path.basename(p)
                            for p in glob.glob(base + "/*")
                            if os.path.basename(p)[:1].isalpha() and
                               os.path.basename(p).rstrip("0123456789") in ("event","mouse","js")))
                return node, handlers
        time.sleep(0.1)
    return None, ""

# ============================================================ device builders
def build_mouse(fd):
    for e in (EV_KEY, EV_ABS, EV_SYN): fcntl.ioctl(fd, UI_SET_EVBIT, e)
    for b in (BTN_LEFT, BTN_RIGHT, BTN_MIDDLE, BTN_TOOL_PEN): fcntl.ioctl(fd, UI_SET_KEYBIT, b)
    for a in (ABS_X, ABS_Y): fcntl.ioctl(fd, UI_SET_ABSBIT, a)
    os.write(fd, _pack_user_dev("vibemis-autotest-mouse", 0x03, 0x1234, 0x5678, 1,
                                {ABS_X: W-1, ABS_Y: H-1}))
    fcntl.ioctl(fd, UI_DEV_CREATE)

def build_gamepad(fd):
    fcntl.ioctl(fd, UI_SET_EVBIT, EV_KEY); fcntl.ioctl(fd, UI_SET_EVBIT, EV_ABS)
    fcntl.ioctl(fd, UI_SET_EVBIT, EV_SYN)
    codes = set(PAD_BUTTONS.values())
    for b in codes: fcntl.ioctl(fd, UI_SET_KEYBIT, b)
    axes = {ABS_X: 32767, ABS_Y: 32767, ABS_RX: 32767, ABS_RY: 32767,
            ABS_Z: 255, ABS_RZ: 255, ABS_HAT0X: 1, ABS_HAT0Y: 1}
    axis_min = {ABS_X: -32768, ABS_Y: -32768, ABS_RX: -32768, ABS_RY: -32768,
                ABS_Z: 0, ABS_RZ: 0, ABS_HAT0X: -1, ABS_HAT0Y: -1}
    for a in axes: fcntl.ioctl(fd, UI_SET_ABSBIT, a)
    # Advertise as an Xbox 360 pad so SDL's gamepad DB maps BTN_SOUTH/EAST/... correctly.
    os.write(fd, _pack_user_dev("vibemis-autotest-gamepad", 0x03, 0x045e, 0x028e, 0x0110,
                                axes, axis_min))
    fcntl.ioctl(fd, UI_DEV_CREATE)

def build_keyboard(fd):
    fcntl.ioctl(fd, UI_SET_EVBIT, EV_KEY)
    for kc in set(KEYS.values()): fcntl.ioctl(fd, UI_SET_KEYBIT, kc)
    os.write(fd, _pack_user_dev("vibemis-autotest-kbd", 0x03, 0x1234, 0x5679, 1))
    fcntl.ioctl(fd, UI_DEV_CREATE)

# ============================================================ mouse actions
def mouse_moveto(fd, x, y):
    x = max(0, min(W-1, x)); y = max(0, min(H-1, y))
    _emit(fd, EV_KEY, BTN_TOOL_PEN, 1)     # identify as absolute pointer to libinput
    _emit(fd, EV_ABS, ABS_X, x); _emit(fd, EV_ABS, ABS_Y, y)
    _syn(fd); time.sleep(0.04)
def mouse_btn(fd, code, down): _emit(fd, EV_KEY, code, 1 if down else 0); _syn(fd); time.sleep(0.04)
def mouse_click(fd, code=BTN_LEFT): mouse_btn(fd, code, True); mouse_btn(fd, code, False)

def pad_press(fd, code, hold=0.08):
    _emit(fd, EV_KEY, code, 1); _syn(fd); time.sleep(hold)
    _emit(fd, EV_KEY, code, 0); _syn(fd); time.sleep(0.04)

def pad_dpad(fd, dx, dy, hold=0.12):
    # The resolved Xbox mapping uses HAT0. Do not also emit 0x220-0x223: SDL numbers those
    # experimental keys as unrelated buttons and the app may invoke actions instead of navigate.
    if dx: _emit(fd, EV_ABS, ABS_HAT0X, dx)
    if dy: _emit(fd, EV_ABS, ABS_HAT0Y, dy)
    _syn(fd); time.sleep(hold)
    if dx: _emit(fd, EV_ABS, ABS_HAT0X, 0)
    if dy: _emit(fd, EV_ABS, ABS_HAT0Y, 0)
    _syn(fd); time.sleep(0.06)

def pad_stick(fd, dx, dy, hold=0.16):
    # Left stick full-deflect + release (SDL menu nav). Signed range, centered at zero.
    _emit(fd, EV_ABS, ABS_X, int(dx*32000)); _emit(fd, EV_ABS, ABS_Y, int(dy*32000))
    _syn(fd); time.sleep(hold)
    _emit(fd, EV_ABS, ABS_X, 0); _emit(fd, EV_ABS, ABS_Y, 0)
    _syn(fd); time.sleep(0.06)

def key_tap(fd, codes):
    for c in codes: _emit(fd, EV_KEY, c, 1)
    _syn(fd)
    for c in reversed(codes): _emit(fd, EV_KEY, c, 0)
    _syn(fd)

# ============================================================ daemon lifecycle
def _write_pidfile(path):
    if path:
        with open(path, "w") as f: f.write(str(os.getpid()))
def _ready(fifo, log):
    open(fifo + ".ready", "w").close()
    msg = "%s ready\n" % os.path.basename(sys.argv[0])
    try:
        with open(log, "a") as f: f.write("vibemis-vinput ready pid=%d\n" % os.getpid())
    except OSError: pass
    sys.stdout.write("vmouse ready\n" if "mouse" in sys.argv[:3] else "vinput ready\n")
    sys.stdout.flush()

def run_daemon(kind, fifo, log, pidfile):
    """Detached command-loop daemon. Holds FIFO O_RDWR so external writers never block."""
    fd = _open_uinput()
    if kind == "mouse":   build_mouse(fd)
    elif kind == "gamepad": build_gamepad(fd)
    else: raise SystemExit("daemon kind must be mouse|gamepad")
    navfd = None
    if kind == "gamepad":
        navfd = _open_uinput()
        build_keyboard(navfd)
    time.sleep(1.0)  # let the gamescope/libinput seat enumerate the new device
    try: os.mkfifo(fifo)
    except OSError as e:
        if e.errno != errno.EEXIST: raise

    stop = {"v": False}
    def _sig(*_):
        stop["v"] = True
    signal.signal(signal.SIGTERM, _sig); signal.signal(signal.SIGINT, _sig)

    # O_RDWR: we own a write end too -> external `echo > fifo` never blocks on open,
    # and our read side never spuriously hits EOF between commands.
    rfd = os.open(fifo, os.O_RDWR | os.O_NONBLOCK)
    _write_pidfile(pidfile)
    _ready(fifo, log)
    buf = b""
    try:
        while not stop["v"]:
            r, _, _ = select.select([rfd], [], [], 0.5)
            if not r: continue
            try: chunk = os.read(rfd, 4096)
            except OSError as e:
                if e.errno in (errno.EAGAIN, errno.EWOULDBLOCK): continue
                raise
            if not chunk: continue
            buf += chunk
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                _dispatch(kind, fd, line.decode(errors="ignore").strip(), stop, navfd)
    finally:
        if navfd is not None:
            try: fcntl.ioctl(navfd, UI_DEV_DESTROY)
            except OSError: pass
            os.close(navfd)
        try: fcntl.ioctl(fd, UI_DEV_DESTROY)
        except OSError: pass
        os.close(fd)
        for p in (fifo, fifo + ".ready", pidfile):
            try:
                if p: os.remove(p)
            except OSError: pass

def _dispatch(kind, fd, line, stop, navfd=None):
    if not line: return
    p = line.split(); k = p[0].upper()
    if k == "Q" or k == "QUIT": stop["v"] = True; return
    if kind == "mouse":
        if k == "M" and len(p) >= 3: mouse_moveto(fd, int(p[1]), int(p[2]))
        elif k == "C": mouse_click(fd, BTN_LEFT)
        elif k == "R": mouse_click(fd, BTN_RIGHT)
        elif k == "MC" and len(p) >= 3:
            mouse_moveto(fd, int(p[1]), int(p[2])); time.sleep(0.12); mouse_click(fd, BTN_LEFT)
    elif kind == "gamepad":
        if k == "PRESS" and len(p) >= 2:
            name = p[1].upper()
            code = PAD_BUTTONS.get(name)
            if code is None:
                try: code = int(name, 0)
                except ValueError: return
            pad_press(fd, code)
        elif k == "HOLD" and len(p) >= 3:
            code = PAD_BUTTONS.get(p[1].upper());
            if code is not None: pad_press(fd, code, float(p[2]))
        elif k in ("DPAD", "DPADNAV", "LS") and len(p) >= 2:
            # BL-2013 post-mortem (2026-07-16): plain DPAD must emit ONLY the HAT event.
            # The old behavior ALSO tapped the matching arrow key on the companion nav
            # keyboard (navfd), so every DPAD press hit the app TWICE (gamepad + kbd) —
            # that double was misread as an app bug (the alpha.012 edge-filter chased it).
            # The dual-emit was a crutch for the old headless-gamescope rig where gamepad
            # events didn't navigate; if a harness still needs it, it must now ask
            # explicitly with DPADNAV.
            _dirs = {"UP": (0, -1), "DOWN": (0, 1), "LEFT": (-1, 0), "RIGHT": (1, 0),
                     "U": (0, -1), "D": (0, 1), "L": (-1, 0), "R": (1, 0)}
            v = _dirs.get(p[1].upper())
            if v:
                (pad_stick if k == "LS" else pad_dpad)(fd, v[0], v[1])
                if k == "DPADNAV" and navfd is not None:
                    arrow = {(0, -1): KEYS["UP"], (0, 1): KEYS["DOWN"],
                             (-1, 0): KEYS["LEFT"], (1, 0): KEYS["RIGHT"]}[v]
                    key_tap(navfd, [arrow])

# ============================================================ send / stop
def do_send(fifo, msg):
    """Open O_WRONLY|O_NONBLOCK: instant ENXIO if no daemon reader -> never hangs."""
    try:
        wfd = os.open(fifo, os.O_WRONLY | os.O_NONBLOCK)
    except OSError as e:
        if e.errno == errno.ENXIO:
            sys.stderr.write("vinput send: no daemon reading %s (ENXIO) — start the daemon first\n" % fifo)
            return 3
        if e.errno == errno.ENOENT:
            sys.stderr.write("vinput send: FIFO %s does not exist\n" % fifo)
            return 3
        raise
    try:
        os.write(wfd, (msg + "\n").encode())
    finally:
        os.close(wfd)
    return 0

def do_stop(pidfile):
    if not pidfile or not os.path.exists(pidfile):
        sys.stderr.write("vinput stop: no pidfile %s\n" % pidfile); return 0
    try:
        pid = int(open(pidfile).read().strip())
    except (OSError, ValueError):
        return 1
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    for _ in range(20):
        try: os.kill(pid, 0)
        except ProcessLookupError:
            break
        time.sleep(0.1)
    else:
        try: os.kill(pid, signal.SIGKILL)
        except ProcessLookupError: pass
    try: os.remove(pidfile)
    except OSError: pass
    return 0

# ============================================================ self-tests (read events back)
def _selftest(kind):
    """Prove the device works, in two tiers:
      TIER 1 (always, unprivileged): create the device, confirm the kernel enumerated it with the
              correct handler CLASS (pointer=>mouseN, gamepad=>jsN, keyboard=>eventN+EV_KEY), and
              inject a move/press with byte-accurate writes the kernel accepts. This proves a
              well-formed, seat-enumerable device that emits events.
      TIER 2 (only when /dev/input/eventN is READABLE — i.e. caller is in group 'input' or on a
              seat-ACL'd host): read the injected events back and match them, proving registration.
    On this test box deck is not in 'input' and fresh uinput nodes get no seat ACL, so Tier 2 is
    SKIPPED and the definitive end-to-end proof is the integration screenshot-diff in
    mock-vibepollo-smoke.sh / a gamescope run. See README."""
    names = {"mouse": "vibemis-autotest-mouse", "gamepad": "vibemis-autotest-gamepad",
             "key": "vibemis-autotest-kbd"}
    want_class = {"mouse": "mouse", "gamepad": "js", "key": "event"}
    fd = _open_uinput()
    try:
        if kind == "mouse": build_mouse(fd)
        elif kind == "gamepad": build_gamepad(fd)
        else: build_keyboard(fd)
        node, handlers = _find_device(names[kind])
        if not node:
            print("SELFTEST FAIL: device %s not enumerated by kernel" % names[kind]); return 1
        print("device created: %s -> %s  handlers=[%s]" % (names[kind], node, handlers))
        cls_ok = want_class[kind] in handlers
        print("TIER1 handler-class '%s' present: %s" % (want_class[kind], "PASS" if cls_ok else "FAIL"))

        # Prepare optional readback
        readable = os.access(node, os.R_OK)
        efd = None
        if readable:
            try:
                efd = os.open(node, os.O_RDONLY | os.O_NONBLOCK); time.sleep(0.2)
                while True: os.read(efd, 24*64)          # drain enumeration noise
            except OSError: pass

        # inject + count bytes written
        if kind == "mouse":
            mouse_moveto(fd, 640, 400); time.sleep(0.1); mouse_click(fd, BTN_LEFT)
            want = {("ABS", ABS_X): False, ("ABS", ABS_Y): False, ("KEY", BTN_LEFT): False}
        elif kind == "gamepad":
            pad_press(fd, BTN_SOUTH); pad_press(fd, PAD_BUTTONS["PADDLE_BACK"])
            want = {("KEY", BTN_SOUTH): False, ("KEY", PAD_BUTTONS["PADDLE_BACK"]): False}
        else:
            key_tap(fd, [KEYS["F1"]]); key_tap(fd, [KEYS["ENTER"]])
            want = {("KEY", KEYS["F1"]): False, ("KEY", KEYS["ENTER"]): False}
        print("TIER1 injection: writes accepted by kernel (no error)")

        tier2 = "SKIPPED (event node not readable: not in group 'input' / no seat ACL)"
        rc_ok = cls_ok
        if efd is not None:
            time.sleep(0.3)
            try:
                while True:
                    data = os.read(efd, 24)
                    if len(data) < 24: break
                    _, _, t, c, v = _EV.unpack(data)
                    key = ("ABS", c) if t == EV_ABS else (("KEY", c) if t == EV_KEY else None)
                    if key in want: want[key] = True
            except OSError: pass
            os.close(efd)
            got = all(want.values())
            tier2 = "%s (matched=%s)" % ("PASS" if got else "FAIL",
                     {("%s:0x%x"%(k[0],k[1])):v for k,v in want.items()})
            rc_ok = cls_ok and got
        print("TIER2 event-readback: %s" % tier2)
        print("SELFTEST %s: %s" % ("PASS" if rc_ok else "FAIL", kind))
        return 0 if rc_ok else 1
    finally:
        try: fcntl.ioctl(fd, UI_DEV_DESTROY)
        except OSError: pass
        os.close(fd)

# ============================================================ CLI
def main():
    ap = argparse.ArgumentParser(description="Vibemis robust uinput virtual input")
    ap.add_argument("kind", choices=["mouse", "gamepad", "key"])
    ap.add_argument("action", nargs="?", default=None,
                    help="start | send <cmd> | stop | tap <KEYS...>")
    ap.add_argument("cmd", nargs="*", help="command payload for send/tap")
    ap.add_argument("--fifo", default=None)
    ap.add_argument("--log", default="/tmp/vinput.log")
    ap.add_argument("--pidfile", default=None)
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()

    if a.selftest:
        return _selftest(a.kind)

    fifo = a.fifo or "/tmp/v%s.cmd" % a.kind
    pidfile = a.pidfile or "/tmp/v%s.pid" % a.kind

    if a.action == "start":
        return run_daemon(a.kind, fifo, a.log, pidfile) or 0
    if a.action == "send":
        return do_send(fifo, " ".join(a.cmd))
    if a.action == "stop":
        return do_stop(pidfile)
    if a.kind == "key" and a.action == "tap":
        codes = [KEYS[k.upper()] for k in a.cmd if k.upper() in KEYS]
        if not codes: print("no valid keys"); return 2
        fd = _open_uinput()
        try:
            build_keyboard(fd); time.sleep(0.5); key_tap(fd, codes); time.sleep(0.2)
            print("injected: %s" % " ".join(a.cmd))
        finally:
            fcntl.ioctl(fd, UI_DEV_DESTROY); os.close(fd)
        return 0
    ap.print_help(); return 2

if __name__ == "__main__":
    sys.exit(main() or 0)
