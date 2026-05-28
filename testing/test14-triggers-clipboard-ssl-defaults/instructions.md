# Test14 Instructions — Quick Menu Triggers, Clipboard SSL, OTP, Server Commands

**Branch:** `fix/quickmenu-triggers-clipboard-ssl-defaults` (PR #36)  
**Device:** Lenovo Legion Go S Z2, SteamOS Desktop Mode  
**Host:** Navid-PC running Vibepollo  
**Builds on:** PR #33 fixes (thread safety, OTP detection) + PR #36 fixes below

## What changed since test13

| Fix | Was broken | Now |
|---|---|---|
| **Quick Menu keyboard trigger** | Silent — no overlay, no log | Qt event loop pumped every 50ms during streaming so QueuedConnection fires |
| **Quick Menu gamepad trigger** | Silent — no overlay, no log | Same polling fix |
| **Clipboard SSL** | Every transfer failed: "SSL handshake failed: hostname mismatch" | VerifyNone on clipboard endpoints — peer already trusted via pairing cert |
| **textonly setting persistence** | Reset to `true` on every app restart | Saved to `[ClipboardSync] textonly=` in INI on change; loaded on startup |
| **OTPPairing.enabled default** | `false` — always fell back to PIN | `true` — OTP dialog shown for Apollo/Vibepollo servers |
| **ServerCommands.enabled default** | `false` — panel hidden | `true` — Server Commands accessible by default |

**Note on existing settings:** If you have a `vibemis-settings.ini` from a prior test run, the old `enabled=false` values are already written to disk. Delete the settings file before this test so the new defaults apply:

```bash
rm -f ~/.config/"Vibemis Project"/Vibemis/vibemis-settings.ini
```

---

## Setup

```bash
pkill -f Vibemis || true

# Delete stale settings so new defaults take effect
rm -f ~/.config/"Vibemis Project"/Vibemis/vibemis-settings.ini

# Download latest AppImage (includes prereleases — fix/* branch builds)
wget -O ~/Vibemis-test14.AppImage \
  "$(curl -s https://api.github.com/repos/navyas321/vibemis/releases \
     | python3 -c "import sys,json; releases=json.load(sys.stdin); \
       urls=[a['browser_download_url'] for r in releases \
             for a in r['assets'] if 'AppImage' in a['name']]; \
       print(urls[0] if urls else '')")"
chmod +x ~/Vibemis-test14.AppImage
md5sum ~/Vibemis-test14.AppImage

# Confirm it's from PR #36 (commit ca827fdf or later)
./Vibemis-test14.AppImage --version

# Launch with log
~/Vibemis-test14.AppImage > ~/test14.log 2>&1 &
sleep 4
```

---

## Check 1 — Regression: video renders

Connect to Navid-PC → launch Desktop. Video must be visible (not black).

```bash
grep -E "FORCE_VAAPI|EGLRenderer|video stream is" ~/test14.log | head -5
```

**Pass:** `FORCE_VAAPI=1` present, no shader errors, video on screen.  
**Stop and report if this fails** — all other checks depend on a working stream.

---

## Check 2 — Quick Menu keyboard trigger *(was silent in test13)*

While streaming, press **`Ctrl + Alt + Shift + \`**

**Expected:** Quick Menu overlay appears immediately.  
**test13 result:** completely silent.

```bash
grep -i "quickmenu\|QuickMenu\|toggle" ~/test14.log | head -10
```

**Report:** Did overlay appear? Any log entry for the shortcut? PASS/FAIL.

---

## Check 3 — Quick Menu gamepad trigger *(was silent in test13)*

While streaming, press **`Select + L1 + R1 + Y`** simultaneously.

**Expected:** Quick Menu overlay appears.  
**test13 result:** completely silent (was SIGSEGV in test12 before thread fix).

**Report:** Did overlay appear? PASS/FAIL.

---

## Check 4 — Quick Menu actions (if Check 2 or 3 passes)

With the Quick Menu open:

| Step | Action | Expected |
|---|---|---|
| 4a | **Toggle Performance Stats** | Perf overlay (bitrate/FPS/latency) appears; select again → gone |
| 4b | **Toggle Fullscreen** | Window switches between fullscreen / windowed |
| 4c | **Dismiss** (Escape or X) | Menu closes, stream continues |

**Report:** Which actions worked? Which didn't?

---

## Check 5 — Clipboard sync *(SSL fix)*

### 5a — Enable clipboard sync
Settings → Clipboard → enable **"Enable clipboard synchronization"**.

Confirm in log after a stream:
```bash
grep -i "clipboard\|ClipboardManager" ~/test14.log | head -15
```

**Expected:** No more `SSL handshake failed` errors. Should see `sync.*completed` or a 200 HTTP status.

### 5b — Client → Host upload
Start a stream. On the Z2, copy some text (terminal → highlight → Ctrl+C).  
Open Quick Menu → **Clipboard Upload**.  
On Navid-PC, paste (Ctrl+V in Notepad/terminal).

**Expected:** Z2 text appears on host.  
**test13 result:** Failed — SSL hostname mismatch.

### 5c — Host → Client fetch
On Navid-PC, copy some text.  
Open Quick Menu → **Fetch Clipboard**.  
On Z2, paste in terminal.

**Expected:** Host text appears on Z2.

### 5d — textonly persistence *(was not persisted in test13)*
1. Settings → Clipboard → uncheck **"Text content only"**
2. Close Vibemis completely (`pkill -f Vibemis`)
3. Relaunch: `~/Vibemis-test14.AppImage > ~/test14.log 2>&1 &`
4. Open Settings → Clipboard

**Expected:** "Text content only" is still unchecked.  
**test13 result:** Reset to checked on every restart.

```bash
grep "textOnly\|textonly\|text-only\|Text-only" ~/test14.log | head -5
cat ~/.config/"Vibemis Project"/Vibemis/vibemis-settings.ini | grep -A5 ClipboardSync
```

**Report:** Upload worked? Fetch worked? textonly persisted across restart? Paste grep + INI output.

---

## Check 6 — OTP Pairing *(was blocked in test13 — default was false)*

> Only do 6a/6b if comfortable unpairing. Use 6c (fallback) otherwise.

### 6a — Unpair
PC list → long-press Navid-PC → Unpair.

### 6b — Re-pair
Click Navid-PC.

**Expected:** OTP dialog appears (not classic PIN dialog).  
**test13 result:** PIN dialog appeared — `OTPPairing.enabled` was `false`.

Enter the OTP from Vibepollo's web UI → pairing completes.

### 6c — Fallback (no unpair)
Click an already-paired Navid-PC and note what dialog appears.

```bash
grep -i "otp\|OTPPairing\|pairing\|pair" ~/test14.log | head -10
cat ~/.config/"Vibemis Project"/Vibemis/vibemis-settings.ini | grep -A3 OTPPairing
```

**Report:** OTP dialog appeared? Pairing succeeded? Paste grep + INI section.

---

## Check 7 — Server Commands *(was blocked in test13 — default was false)*

Start a stream → open Quick Menu → **Server Commands**.

**Expected:** Server Commands panel is accessible (not greyed out). Command list shows (e.g. "Bubbles"). Select Bubbles → confirm it executes on Navid-PC.

**test13 result:** `ServerCommands.enabled=false` in settings — panel hidden.

```bash
grep -i "servercommand\|CommandManager\|Bubbles\|executeCommand" ~/test14.log | head -10
cat ~/.config/"Vibemis Project"/Vibemis/vibemis-settings.ini | grep -A3 ServerCommands
```

**Report:** Server Commands panel accessible? Bubbles executed? Paste grep + INI section.

---

## If the app crashes at any point

```bash
journalctl -b | grep -E "coredump|Vibemis|SIGABRT|SIGSEGV" | tail -10
```

---

## What to include in the report

Create `testing/test14-triggers-clipboard-ssl-defaults/report.md` on branch  
`diagnostic/test14-triggers-clipboard-ssl-defaults-report` with:

1. **AppImage version** — full filename and MD5
2. **Check 1** — video regression: PASS/FAIL + grep
3. **Check 2** — keyboard trigger: PASS/FAIL + log entry (or absence)
4. **Check 3** — gamepad trigger: PASS/FAIL
5. **Check 4** — Quick Menu actions: which worked (perf stats / fullscreen / dismiss)
6. **Check 5** — Clipboard:
   - Upload PASS/FAIL
   - Fetch PASS/FAIL
   - textonly persisted PASS/FAIL
   - grep output + INI `[ClipboardSync]` section
7. **Check 6** — OTP: dialog appeared PASS/FAIL, INI `[OTPPairing]` section
8. **Check 7** — Server Commands: panel accessible PASS/FAIL, Bubbles ran PASS/FAIL, INI `[ServerCommands]` section

For any **FAIL or crash**: exact error line, which step, expected vs actual.
