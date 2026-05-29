# Test16 Instructions — Full Apollo Feature Matrix

**Branch:** `fix/quickmenu-triggers-clipboard-ssl-defaults` (PR #36)
**Device:** Lenovo Legion Go S Z2, SteamOS Desktop Mode
**Host:** Navid-PC running Vibepollo 7.1.431
**Builds on:** all prior fixes — PRs #29 #30 #33 #36

## What changed since test15

| Fix | test15 result | Now |
|---|---|---|
| **OTP pairing rejected valid cert** | `PendingOTPPairingTask` saw `status_message="OTP auth not available."` and rejected `paired=1` + full cert — 22 failed attempts | Response now parsed with `QXmlStreamReader`; `paired=1` + `plaincert` is the success signal; `status_message` is ignored |

All other fixes from test14/test15 remain in this build (Quick Menu visible, keyboard/gamepad triggers, clipboard SSL + auth params, NavigableMenu crash fix, OTP dialog redesign).

## Setup

```bash
pkill -f Vibemis || true

# Delete stale settings — important so OTPPairing.enabled=true default applies
rm -f ~/.config/"Vibemis Project"/Vibemis/vibemis-settings.ini

# Download latest AppImage (fix/* = prerelease, use /releases not /releases/latest)
wget -O ~/Vibemis-test16.AppImage \
  "$(curl -s https://api.github.com/repos/navyas321/vibemis/releases \
     | python3 -c "import sys,json; r=json.load(sys.stdin); \
       urls=[a['browser_download_url'] for x in r \
             for a in x['assets'] if 'AppImage' in a['name']]; \
       print(urls[0] if urls else '')")"
chmod +x ~/Vibemis-test16.AppImage
md5sum ~/Vibemis-test16.AppImage

# AppImage must contain commit 3706358e or later
~/Vibemis-test16.AppImage > ~/test16.log 2>&1 &
sleep 4
```

---

## Check 1 — OTP Pairing *(was failing in test15 with 22 rejected attempts)*

> **Unpair Navid-PC first.** Right-click → Unpair (or use Delete PC then re-add).

Click Navid-PC in the computer list.

**Expected:** OTP dialog opens. It shows:
- A large 4-digit PIN in teal (e.g. `4523`) — **this is the PIN to enter on the host**
- Step-by-step instructions referencing "Pair Client" form
- Pairing request fires immediately (host notification appears)

**Steps:**
1. Note the PIN shown in the dialog
2. On Navid-PC — click the "Incoming Pairing Request" notification
3. In Vibepollo web UI → scroll down to **"Pair Client"** section
4. Enter the PIN from the dialog + a device name (e.g. `LegionGo`) → Submit
5. Dialog on the Legion Go should close automatically

**test15 result:** `PendingOTPPairingTask: OTP pairing failed - OTP not available` × 22.

```bash
grep -i "PendingOTPPairing\|otp\|paired\|pairingComplete\|plaincert\|status_code" ~/test16.log | head -20
```

**Report:** Did the OTP dialog show the PIN? Did the host notification appear? Did pairing complete (dialog closed, Navid-PC shows as paired)? Paste grep output.

---

## Check 2 — Video regression

Once paired, connect to Navid-PC → launch Desktop. Confirm video renders.

```bash
grep -E "FORCE_VAAPI|video stream is|EGLRenderer" ~/test16.log | head -5
```

**Pass:** `FORCE_VAAPI=1` present, video visible.

---

## Check 3 — Quick Menu visible

While streaming, press **`Ctrl + Alt + Shift + \`**.

**Expected:** Dark overlay rectangle appears, visually visible on screen (not transparent), showing all 9 menu items.

Press **`Select + L1 + R1 + Y`** on gamepad.

**Expected:** Same overlay.

```bash
grep -i "quickmenu\|QuickMenu\|createQuickView" ~/test16.log | head -10
```

**Report:** Keyboard trigger PASS/FAIL, gamepad trigger PASS/FAIL, menu items visible PASS/FAIL.

---

## Check 4 — Quick Menu actions

With menu open:

| Action | Expected |
|---|---|
| **Toggle Performance Stats** | Perf overlay appears; select again → gone |
| **Toggle Fullscreen** | Window switches modes |
| **Dismiss** | Menu closes, stream continues, no accidental Quit |

---

## Check 5 — Clipboard sync

### 5a — Enable
Settings → Clipboard → enable "Enable clipboard synchronization".

### 5b — Upload (client → host)
Copy text on Z2. Open Quick Menu → **Clipboard Upload**.
Paste on Navid-PC.

**Expected:** Text appears. No more `403 Forbidden`.

### 5c — Fetch (host → client)
Copy text on Navid-PC. Open Quick Menu → **Fetch Clipboard**.
Paste on Z2.

**Expected:** Text appears on Z2.

```bash
grep -i "clipboard\|403\|Forbidden\|sync.*complet\|sync.*fail" ~/test16.log | head -15
```

**Report:** Upload PASS/FAIL, Fetch PASS/FAIL. If fail, paste the exact error line.

---

## Check 6 — Server Commands

Open Quick Menu → **Server Commands** → select **Bubbles**.

**Expected:** Command executes on Navid-PC.

```bash
grep -i "Bubbles\|servercommand\|executeCommand" ~/test16.log | head -10
```

---

## What to include in the report

Create `testing/test16-otp-pairing-complete/report.md` on branch
`diagnostic/test16-otp-pairing-complete-report` with:

1. **AppImage version** — filename and MD5
2. **Check 1** — OTP pairing: PASS/FAIL, dialog showed PIN, host notification appeared, pairing completed, grep output
3. **Check 2** — video regression: PASS/FAIL + grep
4. **Check 3** — Quick Menu visible: keyboard PASS/FAIL, gamepad PASS/FAIL, items visible
5. **Check 4** — actions: perf stats / fullscreen / dismiss
6. **Check 5** — clipboard: upload PASS/FAIL, fetch PASS/FAIL, grep output
7. **Check 6** — server commands / Bubbles: PASS/FAIL

For any **FAIL or crash**: exact log line, which step, expected vs actual.

```bash
# On crash:
journalctl -b | grep -E "coredump|Vibemis|SIGABRT|SIGSEGV" | tail -10
```
