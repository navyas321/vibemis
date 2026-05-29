# Test15 Instructions — Quick Menu Visible, OTP Pairing, Clipboard

**Branch:** `fix/quickmenu-triggers-clipboard-ssl-defaults` (PR #36)
**Device:** Lenovo Legion Go S Z2, SteamOS Desktop Mode
**Host:** Navid-PC running Vibepollo
**Builds on:** all prior fixes (PRs #29 #30 #33 #36)

## What changed since test14

| Fix | test14 result | Now |
|---|---|---|
| **Quick Menu invisible** | Window captured input but content not painted (accidental Quits) | Dropped `Qt::Tool` + transparent bg; Rectangle renders opaque |
| **OTP shows classic PIN** | Screenshot confirmed classic "Please enter 1765" dialog | `isApolloServer()` now uses `!isNvidiaServerSoftware` — reliable for unpaired servers |
| **Clipboard 403 Forbidden** | Every transfer rejected by server | Added `uniqueid=&uuid=` auth params to clipboard URLs |
| **NavigableMenu TypeError** | Crash caused invisible menu to fire accidental Quit events | `initiator: pcContextMenuLoader.parent` added to PcView context menu |

## Setup

```bash
pkill -f Vibemis || true

# Delete stale settings from prior tests
rm -f ~/.config/"Vibemis Project"/Vibemis/vibemis-settings.ini

# Download latest AppImage (fix/* builds are prereleases — use /releases not /releases/latest)
wget -O ~/Vibemis-test15.AppImage \
  "$(curl -s https://api.github.com/repos/navyas321/vibemis/releases \
     | python3 -c "import sys,json; r=json.load(sys.stdin); \
       urls=[a['browser_download_url'] for x in r \
             for a in x['assets'] if 'AppImage' in a['name']]; \
       print(urls[0] if urls else '')")"
chmod +x ~/Vibemis-test15.AppImage
md5sum ~/Vibemis-test15.AppImage
./Vibemis-test15.AppImage --version

~/Vibemis-test15.AppImage > ~/test15.log 2>&1 &
sleep 4
```

The AppImage must contain commit `28f5e4ed` or later.

---

## Check 1 — Regression: video renders

Connect to Navid-PC → launch Desktop. Confirm video is visible.

```bash
grep -E "FORCE_VAAPI|video stream is|EGLRenderer" ~/test15.log | head -5
```

**Pass:** `FORCE_VAAPI=1` present, no shader errors, video on screen. Stop and report if fail.

---

## Check 2 — Quick Menu visible *(was invisible in test14)*

Start a stream. Press **`Ctrl + Alt + Shift + \`**.

**Expected:** A dark overlay rectangle appears in the centre of the screen with the menu items listed. It must be **visually visible** — not just capturing input in the background.

**test14 result:** Window existed and captured clicks (users accidentally quit 3 times) but was completely transparent/invisible.

Confirm it shows all 9 items:
- Disconnect
- Quit
- Server Commands
- Clipboard Upload
- Fetch Clipboard
- Toggle Performance Stats
- Toggle Mouse Capture
- Toggle Keyboard Capture
- Toggle Fullscreen

```bash
grep -i "quickmenu\|QuickMenu\|createQuickView\|QML loaded" ~/test15.log | head -10
```

**Report:** Is the menu visually visible on screen? List which items appear. PASS/FAIL.

---

## Check 3 — Quick Menu gamepad trigger

While streaming, press **`Select + L1 + R1 + Y`**.

**Expected:** Same dark menu overlay appears.

**Report:** PASS/FAIL.

---

## Check 4 — Quick Menu actions

With menu open:

| Step | Action | Expected |
|---|---|---|
| 4a | **Toggle Performance Stats** | Perf overlay (bitrate/FPS/latency) appears; select again → gone |
| 4b | **Toggle Fullscreen** | Window switches between fullscreen and windowed |
| 4c | **Dismiss** (Escape or X) | Menu closes, stream continues with no accidental Quit |

**Report:** Which actions worked?

---

## Check 5 — OTP Pairing *(was showing classic PIN in test14)*

> **Unpair first.** Right-click / long-press Navid-PC → Unpair.

Click Navid-PC in the computer list.

**Expected:** The **OTP dialog** appears — NOT the classic PIN dialog.

The OTP dialog now shows a GENERATED PIN — no typing needed on the client side. It looks like:
- Title bar: **"OTP Pairing"**
- Bold header: **"Pairing with Apollo Server: Navid-PC"**
- Text: **"Apollo servers use OTP (One-Time Password) pairing for enhanced security."**
- A large PIN displayed in teal: e.g. **4523** ← READ this, do NOT type it
- Step-by-step instructions shown in the dialog itself

**test14 result:** Classic PIN dialog appeared ("Please enter 1765 on your host PC").

If the OTP dialog appears:
1. Note the notification on Navid-PC / Vibepollo web UI
2. Find the PIN Vibepollo is expecting (check the Clients page or notification)
3. Enter it in the Vibemis OTP dialog → click OK
4. Confirm pairing completes

```bash
grep -i "otp\|OTP\|pairComputerWithOTP\|PendingOTPPairing\|isApolloServer\|isNvidiaServer" ~/test15.log | head -10
```

**Report:** Did the OTP dialog appear (with "OTP Pairing" title and text field to type into)? Did pairing succeed? Paste grep output.

---

## Check 6 — Clipboard sync *(was 403 Forbidden in test14)*

### 6a — Enable
Settings → Clipboard → enable **"Enable clipboard synchronization"**.

### 6b — Client → Host upload
Start a stream. Copy some text on the Z2. Open Quick Menu → **Clipboard Upload**.  
Paste on Navid-PC.

**Expected:** Text appears on host. No more `403 Forbidden`.  
**test14 result:** `"Error transferring .../actions/clipboard?type=text - server replied: Forbidden"`

### 6c — Host → Client fetch
Copy text on Navid-PC. Open Quick Menu → **Fetch Clipboard**.  
Paste on Z2.

**Expected:** Text appears on Z2.

```bash
grep -i "clipboard\|ClipboardManager\|403\|Forbidden\|sync.*complet\|sync.*fail" ~/test15.log | head -15
```

**Report:** Upload PASS/FAIL, Fetch PASS/FAIL. If still failing, paste the exact error line.

---

## Check 7 — Server Commands

Open Quick Menu → **Server Commands** → select **Bubbles**.

**Expected:** Command executes on Navid-PC. Success toast appears.

```bash
grep -i "servercommand\|Bubbles\|executeCommand" ~/test15.log | head -10
```

**Report:** PASS/FAIL.

---

## What to include in the report

Create `testing/test15-quickmenu-otp-clipboard/report.md` on branch
`diagnostic/test15-quickmenu-otp-clipboard-report` with:

1. **AppImage version** — full filename and MD5
2. **Check 1** — video regression: PASS/FAIL + grep
3. **Check 2** — Quick Menu visible: PASS/FAIL, items listed, grep
4. **Check 3** — gamepad trigger: PASS/FAIL
5. **Check 4** — actions: perf stats / fullscreen / dismiss each PASS/FAIL
6. **Check 5** — OTP dialog appeared (with exact title/text you saw): PASS/FAIL, pairing result, grep
7. **Check 6** — clipboard upload/fetch: PASS/FAIL, grep output
8. **Check 7** — server commands / Bubbles: PASS/FAIL

For any **FAIL or crash**: exact log line, which step, expected vs actual.

```bash
# If any crash during test:
journalctl -b | grep -E "coredump|Vibemis|SIGABRT|SIGSEGV" | tail -10
```
