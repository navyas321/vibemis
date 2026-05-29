# Test18 Instructions — Standard Pairing Flow (no otpauth)

**Branch:** `fix/quickmenu-triggers-clipboard-ssl-defaults` (PR #36)
**Device:** Lenovo Legion Go S Z2, SteamOS Desktop Mode
**Host:** Navid-PC running Vibepollo 7.1.431

## What changed since test17

| Fix | test17 result | Now |
|---|---|---|
| **clientchallenge always fails** | `otpauth` in request triggered OTP validation path; Vibepollo used a random PIN → AES key mismatch | `otpauth` removed; standard Moonlight pairing; Vibepollo uses PIN from "Pair Client" form → AES keys match |
| **Cold-start offline regression** | Cert written to `NvComputer` before phase 4 → polling got HTTPS 401 → host appeared offline | Cert only written to `NvComputer` after phase 4 succeeds; `http.setServerCert()` on local instance only |

## Setup

```bash
pkill -f Vibemis || true
rm -f ~/.config/"Vibemis Project"/Vibemis/vibemis-settings.ini

wget -O ~/Vibemis-test18.AppImage \
  "$(curl -s https://api.github.com/repos/navyas321/vibemis/releases \
     | python3 -c "import sys,json; r=json.load(sys.stdin); \
       urls=[a['browser_download_url'] for x in r \
             for a in x['assets'] if 'AppImage' in a['name']]; \
       print(urls[0] if urls else '')")"
chmod +x ~/Vibemis-test18.AppImage
md5sum ~/Vibemis-test18.AppImage

~/Vibemis-test18.AppImage > ~/test18.log 2>&1 &
sleep 4
```

AppImage must contain commit `554f8158` or later.

---

## Check 1 — Cold start: host comes online (regression fix)

With fresh `settings.ini`, confirm Navid-PC appears online (lock icon = unpaired but reachable).

```bash
grep -i "is now online\|is now offline\|PairStatus\|CS_ONLINE\|CS_OFFLINE" ~/test18.log | head -10
```

**Pass:** `Navid-PC is now online` log line present; PC shows in the list with a lock icon.
**test17 failure:** Host stayed permanently offline with fresh settings.ini after HTTPS 401.

---

## Check 2 — Full pairing (no otpauth, standard challenge)

> Unpair Navid-PC first if still paired.

Click Navid-PC in the computer list.

**Expected sequence:**

1. **OTP dialog opens** — shows PIN (e.g. `4523`) and instructions
2. **Phase 1 fires immediately** — pairing request sent to Vibepollo
3. **Notification appears on Navid-PC** — "Incoming Pairing Request"
4. **On Navid-PC:** click notification → Vibepollo web UI → scroll to **"Pair Client"**
   - Enter the PIN shown in the Vibemis dialog
   - Enter a device name (e.g. `LegionGo`)
   - Click **Submit**
5. **Dialog shows** green **"✓ Host accepted"** and **Continue** button
6. **Click Continue** in the Vibemis dialog
7. **Phase 2-4 fire** — Vibepollo now has the PIN stored → decrypts the AES challenge → responds → phases 3-4 complete
8. **Dialog closes automatically** — Navid-PC shows as paired in the list

```bash
grep -i "PendingOTPPairing\|phase 1\|stage1\|User clicked Continue\|clientchallenge\|pairingComplete\|Parsed response\|handshake" ~/test18.log | head -25
```

**Report per step:**
- Host notification appeared: PASS/FAIL
- `stage1Complete` / Continue button appeared: PASS/FAIL
- `clientchallenge` succeeded (no "Client challenge failed"): PASS/FAIL
- Full handshake succeeded: PASS/FAIL
- Dialog closed / PC shows as paired: PASS/FAIL
- Paste grep output

---

## Check 3 — Video regression

Once paired, connect to Navid-PC → launch Desktop → confirm video renders.

```bash
grep -E "FORCE_VAAPI|video stream is|EGLRenderer" ~/test18.log | head -5
```

---

## Check 4 — Quick Menu, Clipboard, Bubbles (abbreviated)

If pairing works and stream starts:

1. `Ctrl+Alt+Shift+\` → Quick Menu overlay visually visible (dark rect, not transparent)
2. Quick Menu → **Clipboard Upload** → paste on Navid-PC (no 403 error)
3. Quick Menu → **Server Commands** → **Bubbles**

```bash
grep -i "quickmenu\|clipboard\|Bubbles\|403\|Forbidden" ~/test18.log | head -15
```

---

## Report

Create `testing/test18-pairing-standard-flow/report.md` on branch
`diagnostic/test18-pairing-standard-flow-report` with:

1. AppImage version + MD5
2. Check 1 — cold start: host online PASS/FAIL + grep
3. Check 2 — pairing: per-step PASS/FAIL + grep
4. Check 3 — video: PASS/FAIL + grep
5. Check 4 — Quick Menu / clipboard / Bubbles: PASS/FAIL

For any crash: `journalctl -b | grep -E "coredump|Vibemis|SIGABRT|SIGSEGV" | tail -10`
