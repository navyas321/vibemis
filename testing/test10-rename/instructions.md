# Test10 Instructions — Rename Verification (artemis → vibemis)

**AppImage:** `Vibemis-0.6.7-vibemis-test10-rename-x86_64.AppImage`
**md5:** `3901f49f64fdaf3424284d3de03aabc4`
**Branch:** `feat/rename-artemis-to-vibemis`
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5
**Purpose:** Confirm the rename PR (PR #22) has no regressions — app still launches, streams, and all renamed identifiers are visible at runtime

---

## Setup

```bash
chmod +x Vibemis-0.6.7-vibemis-test10-rename-x86_64.AppImage
./Vibemis-0.6.7-vibemis-test10-rename-x86_64.AppImage > ~/test10.log 2>&1
```

---

## Check 1 — App launches without crash

The app should open to the PC list as normal. No crash on startup.

**Pass:** PC list appears.
**Fail:** Crash or black screen — note any error in `~/test10.log`.

---

## Check 2 — Log file uses new name

In a second terminal, immediately after launch:

```bash
ls /tmp/Vibemis-*.log 2>/dev/null && echo "PASS: Vibemis log found" || echo "FAIL: no Vibemis log"
ls /tmp/Artemis-*.log 2>/dev/null && echo "FAIL: old Artemis log still being created" || echo "PASS: no old Artemis log"
```

**Expected:** First line prints PASS, second line prints PASS.

---

## Check 3 — Renamed identifiers appear in the runtime log

The "device name" shown in Vibepollo's client list comes from the machine hostname set at pairing time — it is not the app brand name. The rename is visible in the debug log instead. Run this after the app has started (before or after streaming):

```bash
grep -E "VibemisSettings|Current Vibemis version" ~/test10.log | head -5
```

**Expected output (both lines must appear):**
```
VibemisSettings: Initialized with config at ...
Current Vibemis version: 0.6.7
```

These confirm the renamed class (`VibemisSettings`) and the renamed update checker string are active at runtime.

---

## Check 4 — Basic stream regression

Connect to Navid-PC and launch Desktop (Game Mode).

**Expected:** Stream starts normally, video renders, input works, clean disconnect.

After disconnecting, grep the log:

```bash
grep "VIBEMIS: Requesting" ~/test10.log
```

**Expected:** Line shows the resolution being requested (same as test9).

---

## Check 5 — No "Artemis" in runtime log

```bash
grep -i "artemis" ~/test10.log | grep -v "artemis_qt_clipboard_sync"
```

**Expected:** No output. The only permitted `artemis` string in the codebase is the protocol-level `artemis_qt_clipboard_sync` clipboard identifier — everything else was renamed.

If you see output, paste the lines in the report.

---

## What to include in the test10 report

1. Check 1 result — did it launch? (pass/fail)
2. Check 2 result — paste output of both `ls` commands
3. Check 3 result — paste the output of the `grep -E "VibemisSettings|Current Vibemis version"` command
4. Check 4 result — did the stream work? Paste the `grep "VIBEMIS: Requesting"` output
5. Check 5 result — paste the grep output (expected: empty)
