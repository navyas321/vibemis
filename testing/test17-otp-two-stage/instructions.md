# Test17 Instructions — Two-Stage OTP Pairing

**Branch:** `fix/quickmenu-triggers-clipboard-ssl-defaults` (PR #36)
**Device:** Lenovo Legion Go S Z2, SteamOS Desktop Mode
**Host:** Navid-PC running Vibepollo 7.1.431

## What changed since test16

| Fix | test16 result | Now |
|---|---|---|
| **OTP challenge fired before PIN entered on host** | All 4 challenge phases completed within 1 second, before user could interact with Vibepollo's "Pair Client" form — handshake always failed | `QSemaphore` gate between phase 1 and phase 2. Dialog shows Continue button after host accepts cert. User enters PIN on host, clicks Continue — only then does challenge fire. |

## Setup

```bash
pkill -f Vibemis || true
rm -f ~/.config/"Vibemis Project"/Vibemis/vibemis-settings.ini

wget -O ~/Vibemis-test17.AppImage \
  "$(curl -s https://api.github.com/repos/navyas321/vibemis/releases \
     | python3 -c "import sys,json; r=json.load(sys.stdin); \
       urls=[a['browser_download_url'] for x in r \
             for a in x['assets'] if 'AppImage' in a['name']]; \
       print(urls[0] if urls else '')")"
chmod +x ~/Vibemis-test17.AppImage
md5sum ~/Vibemis-test17.AppImage

~/Vibemis-test17.AppImage > ~/test17.log 2>&1 &
sleep 4
```

AppImage must contain commit `0b45984b` or later.

---

## Check 1 — OTP Pairing (full two-stage flow)

> **Unpair Navid-PC first.**

Click Navid-PC in the computer list.

**Expected new dialog behaviour:**

**Phase 1 (immediate):**
- Dialog opens, shows PIN (e.g. `7195`) in large teal
- Shows: *"Sending pairing request to host…"* + step-by-step instructions
- Pairing request fires to Vibepollo → "Incoming Pairing Request" notification appears on Navid-PC

**On Navid-PC:**
1. Click the notification → Vibepollo web UI → "Pair Client" section
2. Enter the PIN shown in Vibemis + a device name → Submit

**Phase 2 gate (new):**
- Dialog updates: green *"✓ Host accepted the pairing request."*
- Shows a **Continue** button
- Click **Continue**

**Phase 2 (challenge exchange):**
- Vibemis sends AES challenge — Vibepollo can now decrypt it because it knows the PIN
- Dialog closes automatically when pairing completes
- Navid-PC shows as paired

```bash
grep -i "stage1\|stage 1\|PendingOTPPairing\|otp\|paired\|pairingComplete\|plaincert\|Continue\|resumeOTP\|challenge" ~/test17.log | head -25
```

**Report:** 
- Phase 1 (cert received) PASS/FAIL
- Stage1Complete dialog update shown PASS/FAIL
- Continue button appeared PASS/FAIL  
- Phase 2 (challenge) PASS/FAIL
- Pairing completed (Navid-PC paired) PASS/FAIL
- Paste grep output

---

## Check 2 — Video regression

Once paired, connect to Navid-PC → launch Desktop.

```bash
grep -E "FORCE_VAAPI|video stream is|EGLRenderer" ~/test17.log | head -5
```

**Pass:** `FORCE_VAAPI=1` present, video visible.

---

## Check 3 — Quick Menu visible + actions

While streaming:

1. Press **`Ctrl + Alt + Shift + \`** → dark overlay must appear (visually)
2. Press **`Select + L1 + R1 + Y`** (gamepad) → same overlay
3. **Toggle Performance Stats** → perf numbers appear/disappear
4. **Toggle Fullscreen** → window switches modes
5. **Dismiss** → menu closes, no accidental Quit

---

## Check 4 — Clipboard sync

Settings → Clipboard → enable sync.

- **Upload:** copy text on Z2 → Quick Menu → Clipboard Upload → paste on Navid-PC
- **Fetch:** copy on Navid-PC → Quick Menu → Fetch Clipboard → paste on Z2

```bash
grep -i "clipboard\|403\|Forbidden\|sync.*complet\|sync.*fail" ~/test17.log | head -10
```

---

## Check 5 — Server Commands

Quick Menu → **Server Commands** → run **Bubbles**.

```bash
grep -i "Bubbles\|executeCommand\|servercommand" ~/test17.log | head -5
```

---

## Report

Create `testing/test17-otp-two-stage/report.md` on branch
`diagnostic/test17-otp-two-stage-report` with:

1. AppImage version + MD5
2. Check 1 — OTP pairing (per sub-step above): PASS/FAIL + grep
3. Check 2 — video: PASS/FAIL + grep
4. Check 3 — Quick Menu visible + each action
5. Check 4 — clipboard upload/fetch: PASS/FAIL + grep
6. Check 5 — Bubbles: PASS/FAIL

For any crash: `journalctl -b | grep -E "coredump|Vibemis|SIGABRT|SIGSEGV" | tail -10`
