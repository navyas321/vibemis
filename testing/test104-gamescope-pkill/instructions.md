# Test104 Instructions — gamescope-emulate.sh must kill ONLY its own processes (BL-1536)

**Branch:** `test104-gamescope-pkill`
**Device:** Lenovo Legion Go S Z2, SteamOS (Desktop Mode — this is a Desktop-Mode tool)
**Artifact:** none (this is a **shell-script behavior** test — no AppImage needed)
**File under test:** `scripts/gamescope-emulate.sh`

## What changed and why

`gamescope-emulate.sh` used to run broad, machine-wide kills during setup and teardown:

- `pkill -9 -f "gamescope --backend headless"`
- `pkill -9 -x mangoapp`
- `pkill`/`pgrep | kill -9` of any nested Xwayland on `:1/:2/:3`

Those match **every** such process on the machine, not just the ones this run spawned — so
running the harness while another headless-gamescope test (or a real Game Mode `mangoapp`) was
active would kill it mid-run (BL-1536).

**The fix:** the harness now launches gamescope in its **own process group** (`set -m`, so the
captured `$GS` PID is also the group id) and on teardown signals **only that group**
(`kill -- -"$GS"`, guarded by `kill -0`). The broad system-wide kills are moved behind an
explicit **`-F` / `--force-cleanup`** opt-in and are **off by default**.

Goal of this test: prove (1) a **default** run does NOT touch unrelated look-alike processes,
(2) the harness still cleans up **its own** gamescope tree on exit, and (3) `-F` still performs
the broad cleanup when explicitly requested.

---

## Setup

```bash
cd ~/vibemis            # your Vibemis checkout
git fetch origin
git checkout test104-gamescope-pkill
git pull --ff-only

bash -n scripts/gamescope-emulate.sh && echo "PASS: syntax OK"
```

**Clear any pre-existing leftovers ONCE (with -F), before starting the decoys** so the decoy
test starts from a clean slate:

```bash
scripts/gamescope-emulate.sh -F -t 2 -- true ; echo "force-clear exit=$?"
```

Now start two **decoy** processes engineered to match the OLD broad matchers exactly:

```bash
# Decoy A: full-cmdline match for `pkill -f "gamescope --backend headless"`.
#   exec -a sets argv[0] to the whole spoofed string; sleep still gets a valid numeric arg.
bash -c 'exec -a "gamescope --backend headless" sleep 9999' & DECOY_GS=$!

# Decoy B: exact-name (comm) match for `pkill -x mangoapp`.
#   `pkill -x` matches /proc/PID/comm, so the executable's basename must be `mangoapp`.
ln -sf "$(command -v sleep)" /tmp/mangoapp
/tmp/mangoapp 9999 & DECOY_MANGO=$!

sleep 1
echo "decoys: gamescope=$DECOY_GS mangoapp=$DECOY_MANGO"
# Sanity — the broad matchers DO see the decoys (so the test is meaningful):
pgrep -f "gamescope --backend headless"   # must list $DECOY_GS
pgrep -x mangoapp                          # must list $DECOY_MANGO
```

---

## Check 1 — a DEFAULT run must NOT kill the unrelated decoys (the BL-1536 regression)

```bash
# Default mode (NO -F). Trivial inner command so no AppImage is required.
scripts/gamescope-emulate.sh -t 5 -- sleep 8 ; echo "harness exit=$?"

# The decoys must still be alive:
kill -0 "$DECOY_GS"    2>/dev/null && echo "PASS: gamescope decoy survived" || echo "FAIL: gamescope decoy was killed"
kill -0 "$DECOY_MANGO" 2>/dev/null && echo "PASS: mangoapp decoy survived"  || echo "FAIL: mangoapp decoy was killed"
```

**Pass:** both lines say `PASS: ... survived`.
**Fail:** either decoy was killed (that is the exact BL-1536 bug — a default run must never
broad-kill). Note: this assertion holds **even if** the inner emulation itself did not fully
start, because the default path no longer contains any system-wide kill.

---

## Check 2 — the harness DID clean up its OWN gamescope tree on exit

```bash
# After Check 1's harness has exited, the ONLY remaining "gamescope --backend headless"
# match should be the decoy — the harness's own gamescope must be gone.
pgrep -f "gamescope --backend headless"
```

**Pass:** exactly one PID is listed, and it equals `$DECOY_GS` (run `echo "$DECOY_GS"` to
compare). The harness's own gamescope (and its mangoapp/Xwayland children) were reaped.
**Fail:** a second, non-decoy `gamescope --backend headless` PID is still present (the harness
leaked its own process group).

---

## Check 3 — `-F` / `--force-cleanup` STILL performs the broad cleanup (opt-in works)

This confirms the broad kill was not deleted, only gated behind the explicit flag.

```bash
# With the decoys still running, run the harness WITH -F:
scripts/gamescope-emulate.sh -F -t 3 -- true ; echo "harness(-F) exit=$?"

kill -0 "$DECOY_GS"    2>/dev/null && echo "note: gamescope decoy still alive" || echo "EXPECTED: -F cleaned the gamescope decoy"
kill -0 "$DECOY_MANGO" 2>/dev/null && echo "note: mangoapp decoy still alive"  || echo "EXPECTED: -F cleaned the mangoapp decoy"
```

**Pass:** both lines say `EXPECTED: -F cleaned ...` — i.e. the broad, machine-wide cleanup is
still available, but only when the operator explicitly asks for it with `-F`.
(The long form `--force-cleanup` is accepted as an alias and should behave identically.)

---

## Check 4 (optional) — real emulation smoke still works

Only if `~/Downloads/Vibemis.AppImage` is present. Confirms the harness still starts gamescope +
the app + mangoapp and tears them down cleanly.

```bash
scripts/gamescope-emulate.sh -t 15 ; echo "harness exit=$?"
# Expect the normal report: "app: ALIVE ...", ideally "WSI: gamescope surface made",
# and "screenshot: /tmp/gamescope-emulate.png". After exit, no harness gamescope should linger:
pgrep -f "gamescope --backend headless"   # (only the decoy, if you have not cleaned it up yet)
```

**Pass:** normal report prints and exit code is `0` (app opened, no new coredump). No leftover
harness gamescope after exit.

---

## Teardown (always run at the end)

```bash
kill "$DECOY_GS" "$DECOY_MANGO" 2>/dev/null
rm -f /tmp/mangoapp
```

## Scorecard summary

| # | Check | Pass condition |
|---|-------|----------------|
| 1 | Default run leaves unrelated look-alikes alone | both decoys survive a no-`-F` run |
| 2 | Harness cleans up its own tree | only the decoy `gamescope --backend headless` remains after exit |
| 3 | `-F` still does the broad cleanup | `-F` run kills the decoys (opt-in confirmed) |
| 4 | Real emulation smoke (optional) | normal report, exit 0, no leaked harness gamescope |

Report `PASS`/`FAIL` per row on `diagnostic/test104-gamescope-pkill-report`.
