# Test11 Instructions — Apollo Feature Verification

**AppImage:** Download the latest release AppImage from:
https://github.com/navyas321/vibemis/releases/latest

Pick the file named `Vibemis-*-x86_64.AppImage` (the most recent release).

**Branch:** `verify/apollo-features`  
**Device:** Lenovo Legion Go S Z2, SteamOS Desktop Mode  
**Host:** Navid-PC running Vibepollo  
**Purpose:** Confirm all inherited Artemis Qt Apollo-protocol features work correctly against Vibepollo on Linux.

---

## Setup

```bash
# Download the AppImage (replace URL with latest from releases page)
wget -O ~/Vibemis-test11.AppImage \
  "$(curl -s https://api.github.com/repos/navyas321/vibemis/releases/latest \
     | grep browser_download_url | grep AppImage | cut -d'"' -f4)"
chmod +x ~/Vibemis-test11.AppImage

# Launch and redirect logs
./Vibemis-test11.AppImage > ~/test11.log 2>&1 &
sleep 3
```

---

## Check 1 — Basic stream (regression baseline)

Connect to Navid-PC and launch Desktop. Confirm the stream starts, video renders, and input works. Disconnect cleanly.

**Expected:** Stream starts, video renders, input works, clean disconnect.

After disconnect:
```bash
grep "VIBEMIS: Requesting" ~/test11.log | tail -3
```
**Expected:** Resolution/refresh line visible (same as test10).

**Pass / Fail + paste the grep output.**

---

## Check 2 — Quick Menu

Start a stream to Navid-PC. Once streaming:

### 2a — Trigger via keyboard
Press `Ctrl + Alt + Shift + \`

**Expected:** Quick Menu overlay appears with these 8 options visible:
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

**Report:** Did the Quick Menu appear? List which actions you tested and whether they worked. Note anything missing or broken.

---

## Check 3 — Clipboard Sync

### 3a — Enable in settings
Before streaming, go to Settings → (scroll to) Clipboard section.

**Expected:** "Enable clipboard synchronization" toggle is present. Enable it.

### 3b — Client → Host (Upload)
Start a stream. On the Z2, copy some text to clipboard (e.g. right-click → copy in a terminal). Open Quick Menu → **Clipboard Upload**.

On Navid-PC, try to paste (Ctrl+V in Notepad or terminal).

**Expected:** The text you copied on the Z2 appears on the host.

### 3c — Host → Client (Fetch)
On Navid-PC, copy some text. Open Quick Menu → **Fetch Clipboard**.

On the Z2, open a terminal and try Ctrl+V.

**Expected:** The text from the host appears on the Z2.

### 3d — Toast notification
If the "Display toast notifications" option is enabled in Clipboard settings, uploading or fetching should show a brief on-screen toast.

**Expected:** Toast appears briefly confirming the sync.

After the checks:
```bash
grep -i "clipboard\|CLIPBOARD" ~/test11.log | grep -v "^#" | head -10
```

**Report:** Did bidirectional clipboard sync work? Paste the grep output. Note if the host reports any permission errors.

---

## Check 4 — Server Commands

### 4a — Check permission
Go to Settings → Server Commands (or open it during a stream).

**Expected:** If Navid-PC / Vibepollo has granted the "Execute Commands" permission to this client, commands should be listed and enabled. If not granted, the buttons should be greyed out with a "no permission" message.

**Report the permission state you see.**

### 4b — Execute a command (if permission granted and at least one command configured on Vibepollo)
Open Quick Menu → **Server Commands**. Select a command from the list.

**Expected:** Command executes on the host, success toast appears.

### 4c — Custom command
If visible, try the "Custom Command" field — type a simple command (e.g. `echo hello`) and execute it.

**Expected:** Either success (if permitted) or a clear error (if not permitted).

```bash
grep -i "servercommand\|executeCommand\|CommandManager" ~/test11.log | head -10
```

**Report:** Permission state, whether commands executed, any errors. Paste the grep output.

---

## Check 5 — OTP Pairing

> This check requires unpairing and re-pairing Navid-PC.
> **Only do this if you're comfortable re-pairing** — the current pairing will be lost and you'll need to complete the OTP flow on Navid-PC.

### 5a — Unpair
In the PC list, long-press or right-click Navid-PC → Unpair (or Forget).

### 5b — Re-pair with OTP
Click Navid-PC in the PC list. The app should detect it as an Apollo/Vibepollo server and show an **OTP Pairing** dialog instead of the PIN dialog.

On Navid-PC in Vibepollo's web UI, enter the OTP shown in the dialog.

**Expected:** Pairing completes successfully. Navid-PC appears as paired again.

### 5c — Fallback (if 5a/5b is too risky)
If you don't want to unpair, just note what dialog appears when you click an already-paired Apollo server — it should say "Pair using OTP" as an option.

```bash
grep -i "otp\|pairing\|OTPPairing" ~/test11.log | head -10
```

**Report:** Did OTP pairing work? Or did you see the OTP option? Paste the grep output.

---

## Check 6 — Bitrate and Refresh Rate Settings

### 6a — Custom bitrate
In Settings → Streaming, find the bitrate slider. Set it to a specific value (e.g. 50 Mbps). Start a stream.

**Expected:** Stream starts at the configured bitrate. Performance overlay (from Check 2b) should show bitrate near 50 Mbps.

### 6b — Fractional refresh rate
In Settings → Streaming, find the refresh rate field. Enter a fractional value like `90` or `120`.

Start a stream.

**Expected:** Stream runs at the configured refresh rate.

```bash
grep "VIBEMIS: Requesting\|bitrate\|fps\|refresh" ~/test11.log | head -5
```

**Report:** What bitrate and refresh rate did the log show? Did they match what you configured?

---

## What to include in the test11 report

Create `testing/test11-apollo-features/report.md` with:

1. **AppImage version** — the full filename of the AppImage you tested
2. **Check 1** — stream baseline: pass/fail + grep output
3. **Check 2** — Quick Menu: which options appeared, which worked, gamepad trigger result
4. **Check 3** — Clipboard sync: bidirectional result, toast observed, grep output
5. **Check 4** — Server Commands: permission state, any commands executed, grep output
6. **Check 5** — OTP Pairing: pass/fail (or "OTP option visible, pairing not re-attempted"), grep output
7. **Check 6** — Bitrate/refresh rate: configured values, observed values from log

For any **FAIL**, include:
- The exact error message (from log or UI)
- Which step failed
- What you expected vs. what happened
