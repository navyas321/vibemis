# test113 Instructions -- Bubbles in-session server-command E2E (BL-1850)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Branch:** `test113-bubbles-e2e` - **Base:** `vibemis-main`
**Report:** `testing/test113-bubbles-e2e/report.md` on `diagnostic/bubbles-e2e-report`
**Prior report:** N/A (BL-1850 device-validation residual; RCA/mitigations closed on BL-1811)
**Goal:** Prove the ONE unverified link end-to-end: stream to the Vibepollo host, trigger the
**Bubbles** Server Command in-session ONCE from the real client, and confirm the host display
issue does NOT return (Bubbles self-terminates; host screen stays healthy and can still idle-sleep).

---

## SAFETY -- READ FIRST

- **HOST SCREEN MUST BE ON before you start the live stream test.** The physical display on the
  **Vibepollo streaming host (Navid-PC)** must be awake/ON at the start -- this is the **host
  operator's responsibility** (confirm with the host operator before Tier 1; do not begin with the
  host screen blanked/asleep). The whole point of BL-1850 is to observe host display health across
  the Bubbles trigger, so it must start healthy.
- **The user is physically present at the Legion Go** for all client-side steps (launch, pair,
  stream, open the Quick Menu, trigger Bubbles, quit) -- drive those from the device as normal.
- Trigger Bubbles **exactly once**. Do not loop it. This is a controlled one-shot validation.
- This cycle DOES pair and stream and DOES launch a host-side Server Command -- that is explicitly
  authorised here (it overrides the standing "do not pair/stream/launch unless told to" default).
- Host-side teardown is **mandatory** (BL-1821): the Bubbles command is self-terminating (~15 s
  wrapper); you must confirm and timestamp its death before filing the report (see Teardown below).

---

## Background -- why this cycle exists

**The display bug (BL-1811, closed).** The Vibepollo host's Windows display stopped ever
idle-sleeping for days. Corrected RCA: Vibepollo's display-helper runtime invisibly re-armed the
Windows display-idle countdown whenever it had (or believed it had) virtual displays to manage --
no input event, no power request, invisible to `powercfg /requests`. Trigger condition: the retired
vibemis mock-host had installed the **SudoVDA** virtual-display driver and left virtual-display
registrations in `vibeshine_state.json`. Compounding factor during the 48h test marathon: continuous
streaming + input injection **plus a `server_cmd` (Bubbles screensaver) that had NO harness
teardown**, so Bubbles ran until physical input and the display never reached its 900s idle timeout.

**Host-side mitigations -- ALREADY PROVEN (do not re-verify these; they are done):**
- Bubbles `server_cmd` rewritten as a **self-terminating wrapper (~15 s)** with the corrected kill
  matcher `Stop-Process -Name 'Bubbles*'` (the first attempt used `bubbles` and never matched the
  real `Bubbles.scr` -- caught and fixed live). Command entry+name KEPT (test13/test20/CHECKLIST
  depend on it).
- SudoVDA devnode removed and the driver PACKAGE purged (`oem48.inf`); `vibeshine_state`
  virtual-display registrations cleared; ApolloService restarted; the mock-Vibepollo target retired
  at all layers (BL-1858/BL-1860, PR #195); host-side teardown made mandatory (BL-1821, PR #194).
- Host-side proof: **five consecutive natural 900s display-off cycles**, each exact to ~0.1s,
  dual-watcher corroborated -- with Apollo running and with the full stack restored.

**The one UNVERIFIED link (this cycle).** All of the above was proven **host-side, in isolation**.
What has NOT been exercised is the actual **client-driven in-session path**: a real Vibemis client
streaming to the host, and a human/agent opening the in-stream Quick Menu and firing the **Bubbles
Server Command once**, under live streaming load. BL-1850 is the "under-load device test" residual
(tracked alongside BL-1875). This cycle closes it: does triggering Bubbles from the real client, in
a live session, leave the host display healthy (Bubbles dies on its own, no re-armed idle countdown,
host can still sleep) -- or does the client path resurrect the bug? That is the whole question.

---

## Artifact -- CURRENT BETA (this branch ships NO new AppImage)

This is a **device-validation cycle against the current BETA**. This branch **intentionally ships NO
new AppImage and NO alpha** -- there is nothing to build. Use the beta you already pull via
`vibemis-update.sh` (default channel includes betas) at `~/Downloads/Vibemis.AppImage`.

| Field | Value |
|-------|-------|
| Release tag | `0.2.0-beta.013` |
| Version | `0.2.0-beta.013` (numeric `0.2.0.554`, commit `83eac67`) |
| Asset | `Vibemis-0.2.0-beta.013-x86_64.AppImage` |
| Size | 91404792 bytes |
| **md5** | **`ee4874851d3c9644a355c3fa7be71028`** |
| sha256 | `2fe084c00b2245d89800e440c2ef286b6e8d79344e07e182096ad53c82040454` |

**Do NOT use `run-cycle.sh test113-bubbles-e2e`** for artifact fetch -- it only knows how to fetch a
committed `testing/<slug>/*.AppImage` or a branch alpha release, neither of which exists for a beta
cycle, so it will exit 1 ("no AppImage"). Pull the beta directly instead:

```bash
cd ~/vibemis && git fetch origin && git checkout test113-bubbles-e2e && git pull
# Pull / confirm the current beta into your usual install path:
bash scripts/vibemis-update.sh --check          # should report 0.2.0-beta.013
bash scripts/vibemis-update.sh                  # updates ~/Downloads/Vibemis.AppImage to the beta
APP="$HOME/Downloads/Vibemis.AppImage"
chmod +x "$APP"
md5sum "$APP"                                    # MUST equal ee4874851d3c9644a355c3fa7be71028
```

If the md5 does NOT match `ee4874851d3c9644a355c3fa7be71028`, **stop and report** -- do not run an
unverified or wrong-version build. (A newer beta may have shipped; if so, note the tag/md5 you got
and confirm with the build agent before proceeding.)

---

## Test procedure

### Tier 0 -- smoke (no host)
```bash
"$APP" selftest --json ; echo "selftest exit=$?"
```
1. `md5sum "$APP"` equals `ee4874851d3c9644a355c3fa7be71028`.
2. `selftest --json` returns valid JSON and exit 0 (build is healthy and is the beta under test).

### Tier 1 -- pair + live stream (host required; HOST SCREEN ON)
1. Confirm the Vibepollo host **Navid-PC** physical display is **ON/awake**. Note the wall-clock
   time you confirmed it (report it).
2. Launch Vibemis, ensure **Navid-PC** is paired (pair if needed), and **start a stream** to its
   Desktop. Confirm live video is up (EGLRenderer active; no decode errors).
3. Leave the stream running for the trigger in Tier 2. Capture the client log:
   ```bash
   "$APP" > /tmp/vibemis-test113.log 2>&1 &   # or your normal launch; keep the log
   ```

### Tier 2 -- trigger Bubbles ONCE + confirm host display stays healthy
1. In the live session open the **Quick Menu** (`Ctrl+Alt+Shift+\` or `Select+L1+R1+Y`), go to
   **Server Commands**, and select **Bubbles** -- **exactly once**.
2. **Confirm it executed:** the host launches the Bubbles screensaver (`Bubbles.scr`). Note the
   timestamp. (Host-side, the wrapper starts `Bubbles.scr` ~+4 s.)
3. **Teardown / self-termination (mandatory, BL-1821):** the Bubbles wrapper is **self-terminating
   in ~15 s**. Confirm `Bubbles.scr` is GONE ~+15-18 s after the trigger and record both timestamps
   (start + gone). You should NOT have to move a mouse/kbd to kill it.
4. **Confirm the display issue does NOT return:** after Bubbles ends, the host physical display is
   healthy and NOT stuck awake by a re-armed idle countdown. If you have host access, capture
   `powercfg /requests` = None (no DISPLAY holder) after the trigger. If a natural idle-sleep is
   observable within the session window (host untouched ~900s), note it as the strongest evidence;
   otherwise record `powercfg /requests` None as the mechanism-level pass and flag the full 900s
   idle-sleep as a follow-up observation.
5. **Quit the stream cleanly** and close Vibemis. Confirm no client crash / stuck input.

---

## What to check and report

1. **md5** of `~/Downloads/Vibemis.AppImage` == `ee4874851d3c9644a355c3fa7be71028`.
2. **selftest** exit 0 + valid JSON.
3. **Stream up** to Navid-PC (video live, renderer + no decode errors) -- paste the renderer log line.
4. **Bubbles executed once** -- host launched `Bubbles.scr`; report the trigger timestamp.
5. **Self-termination** -- `Bubbles.scr` GONE ~15-18 s later with NO manual input; report start+gone
   timestamps (this is the teardown evidence BL-1821 requires).
6. **Display stays healthy** -- `powercfg /requests` shows no DISPLAY holder after the trigger (and,
   if observed, a natural idle-sleep). Host screen NOT stuck awake.
7. **Clean quit** -- stream stopped, app closed, no crash/coredump, no stuck keys.
8. **Nothing left running on the host** -- explicitly state teardown status (BL-1821). If anything
   is still running and you cannot stop it, post it on the coordination bus + `TEST_AGENT_OUTBOX.md`
   BEFORE filing the report so the build agent can kill it.

Overall verdict: **PASS** only if Bubbles fired once from the client, self-terminated, and the host
display stayed healthy with no re-armed idle countdown. **PARTIAL** if the mechanism passed
(`powercfg` None) but the full natural 900s idle-sleep was not observed in-window. **FAIL** if the
display got stuck awake again after the client-triggered Bubbles.

---

## Report format

- Write `testing/test113-bubbles-e2e/report.md` on branch **`diagnostic/bubbles-e2e-report`** and
  open a **PR against `vibemis-main`**.
- Required sections: TL;DR table (goal / status / one-line), Tier 0/1/2 results with the timestamps
  and log excerpts above, explicit **Teardown status** (what launched on the host + evidence it
  stopped, per BL-1821), and a Recommendation (MERGE-verdict = close BL-1850 / ITERATE / ESCALATE).
- Append a short digest to **`testing/TEST_AGENT_OUTBOX.md`** (newest on top, dated UTC, signed
  `-- test agent`): the verdict, the Bubbles start+gone timestamps, and the display-health result.

---

## Safety rules (standing)
- No package installs, no `sudo` outside read-only inspection. Do not modify the AppImage.
- Pairing / streaming / the Bubbles Server Command are authorised **for this cycle only**.
- Trigger Bubbles **once**; never leave a host-side process you started running (BL-1821).
- If a step needs a permission or capability outside these rules, stop and ask.
