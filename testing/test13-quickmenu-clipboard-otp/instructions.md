# Test13 Instructions — Quick Menu, Clipboard Sync, OTP Pairing

**AppImage:** Download the latest release AppImage from:
https://github.com/navyas321/vibemis/releases/latest

The AppImage **must** be from PR #33 or later (commit `308c2c12` or newer,
built after 2026-05-28 10:00 UTC). Check with `--version` and confirm the
release tag contains the right date.

**Branch:** `verify/test13-quickmenu-clipboard-otp`
**Device:** Lenovo Legion Go S Z2, SteamOS Desktop Mode
**Host:** Navid-PC running Vibepollo
**Purpose:** Verify the three fixes from PR #33:
1. Quick Menu no longer crashes on gamepad combo or keyboard shortcut
2. Clipboard sync works bidirectionally
3. OTP pairing dialog appears for Vibepollo (not PIN fallback)

**What was broken in test12 (now fixed):**
- Gamepad `Select+L1+R1+Y` → SIGSEGV (QQuickView created on wrong thread)
- Keyboard `Ctrl+Alt+Shift+\` → silent (same threading issue)
- Clipboard sync → SIGABRT + non-functional (QNetworkAccessManager created on
  ExecThread, used from main thread — Qt thread-affinity violation)
- OTP dialog never appeared (checked `<ApolloVersion>` XML tag; Vibepollo
  returns `<Permission>` instead → now detected via `isApolloServer()`)

---

## Setup

```bash
# Kill any running Vibemis first
pkill -f Vibemis || true

# Download latest AppImage
wget -O ~/Vibemis-test13.AppImage \
  "$(curl -s https://api.github.com/repos/navyas321/vibemis/releases/latest \
     | grep browser_download_url | grep AppImage | cut -d'"' -f4)"
chmod +x ~/Vibemis-test13.AppImage

# Record filename and MD5
md5sum ~/Vibemis-test13.AppImage
ls -la ~/Vibemis-test13.AppImage

# Launch with log capture
~/Vibemis-test13.AppImage > ~/test13.log 2>&1 &
sleep 4
```

---

## Check 1 — Regression: video still renders

Connect to Navid-PC → launch Desktop. Confirm video is visible (not black screen).

```bash
grep -E "FORCE_VAAPI|EGLRenderer|video stream is|VAAPI.*Mesa" ~/test13.log | head -10
```

**Pass if:** `FORCE_VAAPI=1` line present, no `Cannot load shader` errors, video visible.

**Pass / Fail + paste grep output.**

---

## Check 2 — Quick Menu (the main fix)

Start a stream to Navid-PC. Once video is visible:

### 2a — Keyboard trigger
Press **`Ctrl + Alt + Shift + \`**

**Expected:** Quick Menu overlay appears.  
**Failure in test12:** Completely silent — no overlay, no log entry.

### 2b — Gamepad trigger
Press **`Select + L1 + R1 + Y`** simultaneously.

**Expected:** Quick Menu appears.  
**Failure in test12:** SIGSEGV crash.

> If both triggers cause a crash or no response — stop and report. Do NOT continue to 2c–2e.

### 2c — Toggle Performance Stats
Open Quick Menu → **Toggle Performance Stats**

**Expected:** Perf overlay appears (bitrate, FPS, latency). Select again → disappears.

### 2d — Toggle Fullscreen
Open Quick Menu → **Toggle Fullscreen**

**Expected:** Window switches between fullscreen and windowed.

### 2e — Dismiss
Press Escape or the X button.

**Expected:** Quick Menu closes, stream continues.

```bash
grep -i "quickmenu\|QuickMenu\|toggle.*quick\|quick.*toggle" ~/test13.log | head -10
```

**Report:** Did keyboard trigger work? Did gamepad trigger work? Did the actions in 2c/2d/2e work? Paste grep output.

---

## Check 3 — Clipboard Sync

### 3a — Enable in settings
Before streaming (or open settings from the PC list): Settings → scroll to **Clipboard Sync** section.

Enable "Enable clipboard synchronization".

### 3b — Client → Host
Start a stream. On the Z2, copy some text to clipboard (e.g. open a terminal, highlight text, Ctrl+C).

Open Quick Menu → **Clipboard Upload**.

On Navid-PC, open Notepad or a terminal and press Ctrl+V.

**Expected:** The text from the Z2 appears on the host.  
**Failure in test12:** Nothing transferred; SIGABRT on "text only" toggle.

### 3c — Host → Client
On Navid-PC, copy some text. Open Quick Menu → **Fetch Clipboard**.

On the Z2, open a terminal and press Ctrl+V.

**Expected:** The text from the host appears on the Z2.

### 3d — Text-only toggle (crash regression)
In clipboard settings, try toggling the "Text content only" checkbox OFF and then back ON.

**Expected:** No crash. The toggle just changes a setting.  
**Failure in test12:** SIGABRT immediately.

```bash
grep -i "clipboard\|ClipboardManager\|sync.*start\|sync.*complete\|sync.*fail" ~/test13.log | head -15
```

**Report:** Did upload work? Did fetch work? Did the text-only toggle survive? Paste grep output.

---

## Check 4 — Server Commands

Open Quick Menu → **Server Commands**.

**Expected:** A list of commands appears. "Bubbles" should be listed (confirmed present in test12 log). Select it.

**Expected:** Command executes on Navid-PC, success toast appears.

```bash
grep -i "servercommand\|executeCommand\|Bubbles\|CommandManager" ~/test13.log | head -10
```

**Report:** Was the command list shown? Did executing "Bubbles" work? Paste grep output.

---

## Check 5 — OTP Pairing

> **Only do this if you are comfortable unpairing.** Use 5c (fallback) if not.

### 5a — Unpair
In the PC list, long-press or right-click Navid-PC → **Unpair** (or Forget).

### 5b — Re-pair with OTP
Click Navid-PC in the list.

**Expected:** An **OTP dialog** appears (not the classic 4-digit PIN dialog).
The dialog should say something like "Pairing with Apollo Server" and ask
you to enter the PIN that Vibepollo's web UI shows.

On Navid-PC, open Vibepollo's web UI and find the OTP code. Enter it in the dialog.

**Expected:** Pairing completes. Navid-PC shows as paired.

**Failure in test12:** Classic PIN dialog appeared instead of OTP dialog.

### 5c — Fallback (if you don't want to unpair)
Click an already-paired Navid-PC and note what happens. Does the description
of any pairing dialog mention "Apollo" or "OTP"?

```bash
grep -i "otp\|OTP\|pairing\|PairStatus\|apolloServer\|isApollo" ~/test13.log | head -15
```

**Report:** Did OTP dialog appear? Did re-pairing succeed? Or fallback: what dialog/UI text appeared? Paste grep output.

---

## What to include in the test13 report

Create `testing/test13-quickmenu-clipboard-otp/report.md` on a new branch
`diagnostic/test13-quickmenu-clipboard-otp-report` with:

1. **AppImage version** — full filename and MD5
2. **Check 1** — regression: video renders? PASS/FAIL + grep
3. **Check 2** — Quick Menu:
   - Keyboard trigger: PASS/FAIL
   - Gamepad trigger: PASS/FAIL (crash or no crash?)
   - Perf stats toggle: PASS/FAIL
   - Fullscreen toggle: PASS/FAIL
   - Dismiss: PASS/FAIL
   - Paste grep output
4. **Check 3** — Clipboard:
   - Upload (client→host): PASS/FAIL
   - Fetch (host→client): PASS/FAIL
   - Text-only toggle: no crash? PASS/FAIL
   - Paste grep output
5. **Check 4** — Server Commands: "Bubbles" executed? PASS/FAIL + grep
6. **Check 5** — OTP dialog appeared? PASS/FAIL/PARTIAL + grep

For any **FAIL** or **crash**: include exact error (log line or systemd journal entry), which step failed, and what you expected vs what happened.

**If the app crashes at any point:** run this immediately after:
```bash
journalctl -b | grep -E "coredump|Vibemis|SIGABRT|SIGSEGV" | tail -10
```
