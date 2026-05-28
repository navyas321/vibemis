# Test12 Instructions — EGL Fix Verification + Full Apollo Feature Matrix

**AppImage:** Download the latest release AppImage from:
https://github.com/navyas321/vibemis/releases/latest

Pick the file named `Vibemis-*-x86_64.AppImage` (most recent release — must be from commit `7b752ab8` or later, i.e. released after 2026-05-28 08:00 UTC).

**Branch:** `verify/test12-egl-fix-apollo-rerun`
**Device:** Lenovo Legion Go S Z2, SteamOS Desktop Mode
**Host:** Navid-PC running Vibepollo
**Purpose:**
1. Confirm the EGLRenderer shader fix (PR #30) actually produces visible video (resolves the black-screen bug from test11).
2. Run the full Apollo feature matrix (Checks 2–6) that was blocked in test11.

---

## Quick context (what changed since test11)

- **PR #29** (`+c6efc5c`): Added `FORCE_VAAPI=1` to AppRun hook → fixed the hevc_cuvid SEGV.
- **PR #30** (`7b752ab8`): Fixed `EGLRenderer::compileShaders()` to use `"egl.vert"` instead of non-existent `"egl_nv12.vert"` / `"egl_opaque.vert"` / `"egl_overlay.vert"` → should fix the black screen / infinite recreate loop.

Both fixes are in the AppImage you download. The test11 report diagnosed both bugs precisely — this run confirms the fixes.

---

## Setup

```bash
# Download the AppImage (replace URL with latest from releases page)
wget -O ~/Vibemis-test12.AppImage \
  "$(curl -s https://api.github.com/repos/navyas321/vibemis/releases/latest \
     | grep browser_download_url | grep AppImage | cut -d'"' -f4)"
chmod +x ~/Vibemis-test12.AppImage

# Launch and redirect logs
./Vibemis-test12.AppImage > ~/test12.log 2>&1 &
sleep 3
```

Record the exact AppImage filename and MD5:
```bash
md5sum ~/Vibemis-test12.AppImage
ls -la ~/Vibemis-test12.AppImage
```

---

## Check 1 — EGL fix: visible video (primary validation)

Connect to Navid-PC and launch Desktop. Confirm the stream starts **and video actually renders** (no black screen).

**Expected:**
- Log shows `FORCE_VAAPI=1` hook firing and VAAPI initialising.
- Log does **not** show `EGLRenderer: Cannot load shader` errors.
- Log does **not** show repeated `Recreating renderer by internal request` lines.
- Video is visible on screen.

After connecting:
```bash
grep -E "FORCE_VAAPI|compileShader|Recreating renderer|EGLRenderer|VAAPI.*Mesa|video stream is" ~/test12.log | head -20
```

**Pass criteria:** `FORCE_VAAPI=1` line present, no shader errors, no recreate loop, video visible.

**Pass / Fail + paste the grep output.**

---

## Check 2 — Quick Menu

Start a stream to Navid-PC. Once streaming:

### 2a — Trigger via keyboard
Press `Ctrl + Alt + Shift + \`

**Expected:** Quick Menu overlay appears with these options visible:
- Disconnect
- Quit
- Server Commands
- Clipboard Upload
- Fetch Clipboard
- Toggle Performance Stats
- Toggle Mouse Capture
- Toggle Keyboard Capture
- Toggle Fullscreen

### 2b — Toggle Performance Stats
With Quick Menu open, select **Toggle Performance Stats**.

**Expected:** Performance overlay appears on screen (bitrate, FPS, latency). Select again → overlay disappears.

### 2c — Toggle Fullscreen
Open Quick Menu → **Toggle Fullscreen**.

**Expected:** Window toggles between fullscreen and windowed.

### 2d — Trigger via gamepad (Legion Go S Z2)
Press `Select + L1 + R1 + Y` simultaneously.

**Expected:** Quick Menu appears.

### 2e — Dismiss
Press Escape or close button.

**Expected:** Quick Menu closes, stream continues.

**Report:** Did the Quick Menu appear? List which actions you tested and whether they worked.

---

## Check 3 — Clipboard Sync

### 3a — Enable in settings
Before streaming, go to Settings → (scroll to) Clipboard section.

**Expected:** "Enable clipboard synchronization" toggle is present. Enable it.

### 3b — Client → Host (Upload)
Start a stream. On the Z2, copy some text (e.g. right-click → copy in a terminal). Open Quick Menu → **Clipboard Upload**.

On Navid-PC, try to paste (Ctrl+V in Notepad or terminal).

**Expected:** The text you copied on the Z2 appears on the host.

### 3c — Host → Client (Fetch)
On Navid-PC, copy some text. Open Quick Menu → **Fetch Clipboard**.

On the Z2, open a terminal and try Ctrl+V.

**Expected:** The text from the host appears on the Z2.

### 3d — Toast notification
If the "Display toast notifications" option is enabled in Clipboard settings, uploading or fetching should show a brief on-screen toast.

After the checks:
```bash
grep -i "clipboard\|CLIPBOARD" ~/test12.log | grep -v "^#" | head -10
```

**Report:** Did bidirectional clipboard sync work? Paste the grep output.

---

## Check 4 — Server Commands

### 4a — Check permission
Go to Settings → Server Commands (or open it during a stream).

**Expected:** If Navid-PC has granted the "Execute Commands" permission, commands should be listed and enabled. If not, buttons should be greyed out.

**Report the permission state you see.**

### 4b — Execute a command (if permission granted)
Open Quick Menu → **Server Commands**. Select a command from the list.

**Expected:** Command executes on the host, success toast appears.

```bash
grep -i "servercommand\|executeCommand\|CommandManager" ~/test12.log | head -10
```

**Report:** Permission state, whether commands executed, any errors. Paste the grep output.

---

## Check 5 — OTP Pairing

> Only do this if you're comfortable unpairing and re-pairing.

### 5a — Unpair
In the PC list, long-press or right-click Navid-PC → Unpair.

### 5b — Re-pair with OTP
Click Navid-PC. The app should show an **OTP Pairing** dialog.
On Navid-PC in Vibepollo's web UI, enter the OTP shown in the dialog.

**Expected:** Pairing completes. Navid-PC appears as paired again.

### 5c — Fallback (if 5a/5b is too risky)
Note what dialog appears when you click an already-paired Apollo server — it should mention "OTP" as an option.

```bash
grep -i "otp\|pairing\|OTPPairing" ~/test12.log | head -10
```

**Report:** OTP pairing pass/fail (or "OTP option visible, pairing not re-attempted"). Paste the grep output.

---

## Check 6 — Bitrate and Refresh Rate Settings

### 6a — Custom bitrate
In Settings → Streaming, set the bitrate slider to a specific value (e.g. 50 Mbps). Start a stream.

**Expected:** Performance overlay (from Check 2b) shows bitrate near 50 Mbps.

### 6b — Refresh rate
In Settings → Streaming, enter a refresh rate (e.g. `120`). Start a stream.

**Expected:** Stream runs at the configured refresh rate.

```bash
grep "VIBEMIS: Requesting\|bitrate\|fps\|refresh" ~/test12.log | head -5
```

**Report:** Configured vs observed values. Paste the grep output.

---

## What to include in the test12 report

Create `testing/test12-egl-fix-and-apollo/report.md` with:

1. **AppImage version** — the full filename and MD5 of the AppImage you tested
2. **Check 1** — EGL fix: does video render? Paste the grep output. PASS/FAIL.
3. **Check 2** — Quick Menu: which options appeared, which actions worked, gamepad trigger
4. **Check 3** — Clipboard sync: bidirectional result, toast observed, grep output
5. **Check 4** — Server Commands: permission state, any commands executed, grep output
6. **Check 5** — OTP Pairing: pass/fail or "OTP option visible", grep output
7. **Check 6** — Bitrate/refresh rate: configured values, observed values from log

For any **FAIL**, include:
- The exact error message (from log or UI)
- Which step failed
- What you expected vs. what happened
