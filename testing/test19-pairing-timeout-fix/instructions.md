# Test19 Instructions — Pairing Timeout Fix

**Branch:** `fix/quickmenu-triggers-clipboard-ssl-defaults` (PR #36)
**Device:** Lenovo Legion Go S Z2, SteamOS Desktop Mode
**Host:** Navid-PC running Vibepollo 7.1.431

## What changed since test18

| Fix | test18 result | Now |
|---|---|---|
| **getservercert timed out after 5s** | Vibepollo held connection open waiting for PIN form submission; 5s timeout killed it | Timeout increased to 120s (2 minutes — matches Vibepollo's OTP_EXPIRE_DURATION) |
| **Unnecessary Continue button gate** | Dialog required user to click Continue after submitting form | Removed — phases 2-4 fire automatically when phase 1 returns (Vibepollo already has PIN) |
| **Dialog simplified** | Two-stage UI with stage1Complete property | Single layout: PIN + instructions + "Waiting…" |

## Setup

```bash
pkill -f Vibemis || true
rm -f ~/.config/"Vibemis Project"/Vibemis/vibemis-settings.ini

wget -O ~/Vibemis-test19.AppImage \
  "$(curl -s https://api.github.com/repos/navyas321/vibemis/releases \
     | python3 -c "import sys,json; r=json.load(sys.stdin); \
       urls=[a['browser_download_url'] for x in r \
             for a in x['assets'] if 'AppImage' in a['name']]; \
       print(urls[0] if urls else '')")"
chmod +x ~/Vibemis-test19.AppImage
md5sum ~/Vibemis-test19.AppImage

~/Vibemis-test19.AppImage > ~/test19.log 2>&1 &
sleep 4
```

AppImage must contain commit `fix: pairing timeout` (after test18 build `dda125f`).

---

## Check 1 — Pairing

> Unpair Navid-PC first if still paired.

Click Navid-PC. **Expected new dialog:**
- PIN shown large in teal (e.g. `4523`)
- Steps listed: notification → Pair Client form → auto-close
- "Waiting for PIN entry on host… (up to 2 minutes)"
- **No Continue button**

**Your steps:**
1. Note the PIN in the dialog
2. On Navid-PC: click "Incoming Pairing Request" notification
3. Vibepollo web UI → Pair Client: enter PIN + device name → **Submit**
4. Dialog should close automatically within a few seconds

```bash
grep -i "PendingOTPPairing\|clientchallenge\|handshake\|pairingComplete\|paired\|timeout\|timed out" ~/test19.log | head -20
```

**Report:** Did dialog show PIN + waiting message (no Continue button)? Did host notification appear? Did pairing complete automatically after form submission? PASS/FAIL per step + grep output.

---

## Check 2 — Video

Once paired, stream Desktop.

```bash
grep -E "FORCE_VAAPI|video stream is|EGLRenderer" ~/test19.log | head -5
```

---

## Checks 3-5 — Quick Menu, Clipboard, Bubbles

If stream starts:
- `Ctrl+Alt+Shift+\` → Quick Menu visible
- Clipboard Upload + Fetch (no 403)
- Server Commands → Bubbles

```bash
grep -i "quickmenu\|clipboard\|Bubbles\|403" ~/test19.log | head -10
```

---

## Report

Create `testing/test19-pairing-timeout-fix/report.md` on branch
`diagnostic/test19-pairing-timeout-fix-report` with all checks.
