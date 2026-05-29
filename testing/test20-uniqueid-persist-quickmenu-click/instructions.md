# Test20 Instructions — Uniqueid Persistence + Quick Menu Clicks

**Branch:** `fix/quickmenu-triggers-clipboard-ssl-defaults` (PR #36)
**Device:** Lenovo Legion Go S Z2, SteamOS Desktop Mode
**Host:** Navid-PC running Vibepollo 7.1.431

## What changed since test19

| Fix | test19 result | Now |
|---|---|---|
| **Uniqueid rotates per restart** | 403 Forbidden on clipboard/HTTPS after every app restart | Both `openConnectionToString` and `getAuthParams` now use `IdentityManager::get()->getUniqueId()` — persisted in QSettings across restarts |
| **Quick Menu buttons unresponsive** | Overlay visible but items not clickable | `SDL_SetRelativeMouseMode(SDL_FALSE)` + `SDL_ShowCursor(SDL_ENABLE)` called when menu opens — releases SDL capture so Qt overlay receives mouse events |

## Setup

> ⚠️ **DO NOT delete `settings.ini` before this test.**
>
> Every previous test started with `rm -f ~/.config/"Vibemis Project"/Vibemis/vibemis-settings.ini`.
> **Do NOT run that command here.** Check 1 verifies that the uniqueid survives an app restart —
> that only works if the existing settings file (from test19's pairing) is still on disk.
> Deleting it would generate a new uniqueid and silently invalidate the test.

```bash
pkill -f Vibemis || true
# settings.ini intentionally NOT deleted — see warning above

wget -O ~/Vibemis-test20.AppImage \
  "$(curl -s https://api.github.com/repos/navyas321/vibemis/releases \
     | python3 -c "import sys,json; r=json.load(sys.stdin); \
       urls=[a['browser_download_url'] for x in r \
             for a in x['assets'] if 'AppImage' in a['name']]; \
       print(urls[0] if urls else '')")"
chmod +x ~/Vibemis-test20.AppImage
md5sum ~/Vibemis-test20.AppImage

~/Vibemis-test20.AppImage > ~/test20.log 2>&1 &
sleep 4
```

---

## Check 1 — Uniqueid persists across restart

Note the uniqueid from this session:
```bash
grep "uniqueid\|uniqueID\|unique_id" ~/test20.log | head -5
```

Restart the app:
```bash
pkill -f Vibemis; sleep 2
~/Vibemis-test20.AppImage >> ~/test20.log 2>&1 &
sleep 4
```

Confirm the uniqueid is the same:
```bash
grep "uniqueid\|uniqueID" ~/test20.log | grep -v "^#" | head -10
```

**Pass:** Same uniqueid in both sessions.

---

## Check 2 — Clipboard works after restart

Enable clipboard sync in settings. Start a stream, upload text (Quick Menu → Clipboard Upload). Then **restart the app**, stream again, try Clipboard Upload again.

**Expected:** No 403 Forbidden after restart. Same uniqueid = same trusted cert.

```bash
grep -i "clipboard\|403\|Forbidden\|uniqueid.*STEAM" ~/test20.log | head -15
```

---

## Check 3 — Quick Menu buttons clickable

Start a stream. Press `Ctrl + Alt + Shift + \` → overlay appears.

**Expected:** Mouse cursor becomes visible. Can click menu items (Clipboard Upload, Toggle Performance Stats, etc.). Items respond to both mouse clicks AND keyboard Up/Down/Enter.

**test19:** Overlay visible but buttons did not respond to any input.

Test each:
- **Clipboard Upload** → click it → text transferred to host
- **Toggle Performance Stats** → click → perf overlay appears; click again → gone
- **Toggle Fullscreen** → click → window switches
- **Dismiss** (Escape or X button) → menu closes cleanly

```bash
grep -i "quickmenu\|QuickMenu\|clipboard.*sent\|executeAction\|toggle.*stats\|toggle.*full" ~/test20.log | head -15
```

**Report:** Mouse cursor appeared on menu open? Each button: PASS/FAIL.

---

## Check 4 — Server Commands / Bubbles

Quick Menu → Server Commands → Bubbles.

```bash
grep -i "Bubbles\|servercommand\|executeCommand" ~/test20.log | head -5
```

---

## Report

Create `testing/test20-uniqueid-persist-quickmenu-click/report.md` on branch
`diagnostic/test20-uniqueid-persist-quickmenu-click-report` with:

1. AppImage version + MD5
2. Check 1 — uniqueid same across restart: PASS/FAIL + grep
3. Check 2 — clipboard works after restart: PASS/FAIL + grep
4. Check 3 — Quick Menu buttons clickable: cursor visible + each button PASS/FAIL
5. Check 4 — Bubbles: PASS/FAIL
