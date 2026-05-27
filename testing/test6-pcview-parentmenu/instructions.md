# Test6 Instructions — PcView context menu crash fix

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.8.5)
**Prior report:** `testing/test5-libva-surgical-symlink/report.md` (PR #9 — VAAPI PASS)
**Goal:** Verify that removing the stale `parentMenu: pcContextMenu` assignments from PcView.qml fixes the Computers screen — host cards should appear and the right-click context menu should open and be navigable.

---

## Background

`NavigableMenuItem` (from `NavigableMenuItem.qml`) does not declare a `parentMenu` property.
The eight `parentMenu: pcContextMenu` assignments in `PcView.qml` caused Qt QML to emit:

```
Cannot assign to non-existent property "parentMenu"
```

Because the property assignment is invalid, QML left each `NavigableMenuItem` in a not-ready state, which silently broke `StackView.push()` — clicking a host card that is paired and online would do nothing instead of navigating to the App list.

This fix removes all eight stale `parentMenu:` lines (lines 201, 211, 217, 229, 239, 248, 257, 265 in the original file). No logic changes — only the invalid property assignments are dropped.

**This build also includes the VAAPI surgical symlink fix from test5**, so VAAPI hardware decode should still work correctly.

---

## Artifact

**AppImage:** `testing/test6-pcview-parentmenu/Vibemis-0.6.7-vibemis-test6-pcview-menu-x86_64.AppImage`
(Committed to `fix/pcview-parentmenu-qml` before this test cycle begins. Run `git pull` to receive it.)

**md5:** `806ac898e1827c9e526eb0dfd2e0c878`

Verify before running:
```bash
md5sum testing/test6-pcview-parentmenu/Vibemis-0.6.7-vibemis-test6-pcview-menu-x86_64.AppImage
# must match: 806ac898e1827c9e526eb0dfd2e0c878
```

---

## Test procedure

### Setup

```bash
cd ~/vibemis
git fetch origin fix/pcview-parentmenu-qml
git checkout fix/pcview-parentmenu-qml
git pull
# confirm the AppImage is present
ls -lh testing/test6-pcview-parentmenu/
```

Make the AppImage executable:
```bash
chmod +x testing/test6-pcview-parentmenu/Vibemis-0.6.7-vibemis-test6-pcview-menu-x86_64.AppImage
```

### Tier 1 — default run (PcView fix + VAAPI hook active)

```bash
./testing/test6-pcview-parentmenu/Vibemis-0.6.7-vibemis-test6-pcview-menu-x86_64.AppImage \
  > /tmp/vibemis-run-test6.log 2>&1 &
APP_PID=$!
sleep 20
kill $APP_PID 2>/dev/null; wait $APP_PID 2>/dev/null
```

### Tier 2 — QML error check (look for parentMenu warnings)

This is a log-only check — no second run needed.

```bash
grep -i "parentMenu\|non-existent property\|Cannot assign" /tmp/vibemis-run-test6.log \
  || echo "(no parentMenu QML errors — good)"
```

---

## What to check and report

### For Tier 1 (default run):

**1. No Qt crash** — confirm there is NO `Qt Fatal` / `mismatching Qt versions` line:
```bash
grep -i "Qt Fatal\|mismatching Qt\|failed to start" /tmp/vibemis-run-test6.log \
  || echo "(no Qt crash — good)"
```

**2. No parentMenu QML errors:**
```bash
grep -i "parentMenu\|non-existent property\|Cannot assign" /tmp/vibemis-run-test6.log \
  || echo "(no parentMenu errors — good)"
```

**3. VAAPI hook still active:**
```bash
grep "vibemis-apprun-hook" /tmp/vibemis-run-test6.log
# Expected: [vibemis-apprun-hook] preferring host libva from /usr/lib64 (via /tmp/tmp.XXXXXX)
```

**4. VAAPI still working:**
```bash
grep -i "vaapi\|vaInitialize\|hardware accelerated\|No functioning" /tmp/vibemis-run-test6.log | head -10
```
- **Pass:** no "No functioning hardware accelerated video decoder"
- **Fail:** `VA_STATUS_ERROR_UNKNOWN` or `__vaDriverInit` errors

**5. Computers screen loads — host visible:**
```bash
grep -i "Discovered mDNS\|Processing new PC\|Navid-PC\|Adding computer" /tmp/vibemis-run-test6.log | head -10
```
- **Pass:** Navid-PC.local. or similar host appears in the log within ~5s

**6. Context menu — observe on screen:**
- Wait for the Computers screen to appear (it should show the Navid-PC card)
- Right-click (or long-press) the PC card — the context menu should open
- Check that menu items are visible and navigable (arrow keys work)
- **Do NOT click Connect or attempt to stream** — this test only checks UI, not streaming

Report what you observed on screen (menu opened / didn't open / items visible / crash).

**7. App list navigation (if Navid-PC is online and paired):**
- Single-click / press A on the Navid-PC card — the App list should open
- If the App list opens: **Pass** — the StackView.push() fix works
- If nothing happens on click: **Fail** — parentMenu issue may still be present

**Do NOT start any stream.** This test only checks navigation, not streaming.

**8. Full log tail for any unexpected errors:**
```bash
tail -30 /tmp/vibemis-run-test6.log
```

---

## Report format

Commit `testing/test6-pcview-parentmenu/report.md` on branch `diagnostic/test6-pcview-menu-report` and open a PR against `fix/pcview-parentmenu-qml`.

**Required sections in the report:**
1. TL;DR table (Goal A: no QML parentMenu errors, Goal B: Computers screen loads, Goal C: VAAPI regression-free)
2. Tier 1 — parentMenu check result (exact grep output or "no errors")
3. Tier 1 — VAAPI hook line (exact text)
4. Tier 1 — VAAPI result (pass/fail)
5. Tier 1 — mDNS / Computers screen (Navid-PC visible or not)
6. Tier 1 — context menu observed on screen (opened / didn't open)
7. Tier 1 — App list navigation (worked / didn't work / not testable if offline)
8. Recommendation (merge PR, iterate, or escalate)

Keep the report under ~150 lines.

---

## Safety rules (standing)

- Do not install any packages or modify the system.
- Do not run with `sudo`.
- Do not modify the AppImage.
- If Navid-PC.local. appears: **do NOT pair or start a stream** in this test cycle — navigation test only.
- If the app asks to pair, dismiss the dialog. Pairing is out of scope for this test.
