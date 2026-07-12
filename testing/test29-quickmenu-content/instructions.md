# Test29 Instructions — Quick Menu: Paste Clipboard action (P3.4)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify the new **"Paste Clipboard Text"** item in the Quick Menu types the client
clipboard's text into the host.

> **Built on test22** (the Game-Mode Quick Menu). So this also re-exercises the Quick Menu
> render/nav. Requires a paired host + stream. Test in **Desktop Mode** if the Game-Mode menu
> render is still under verification (test22).

---

## Artifact

**AppImage:** `testing/test29-quickmenu-content/Vibemis-0.6.7-vibemis-test29-quickmenu-content-x86_64.AppImage`
**md5:** `72a6dc0f6a4d9fcadb6aae081521eabd`

```bash
md5sum testing/test29-quickmenu-content/*.AppImage
```

---

## Setup

```bash
cd ~/vibemis
git fetch origin test29-quickmenu-content
git checkout test29-quickmenu-content && git pull
chmod +x testing/test29-quickmenu-content/*.AppImage
./testing/test29-quickmenu-content/*.AppImage --appimage-extract-and-run > ~/test29.log 2>&1 &
```

---

## Tier 1 — Paste Clipboard

1. On the client, copy some text to the clipboard (e.g. in a Desktop-Mode text editor, copy
   `hello vibemis`).
2. Start a stream to the paired host. On the host side, focus a text field (e.g. Notepad /
   a text editor) so typed text is visible.
3. Open the Quick Menu (`Ctrl+Alt+Shift+\` or `Select+L1+R1+Y`).
4. Navigate to **"Paste Clipboard Text"** and select it.
5. **Expected:** the clipboard text (`hello vibemis`) is **typed into the focused field on
   the host**, and a brief "Pasted clipboard text" toast appears; the menu closes.
6. With an **empty** clipboard, the item should show a "Clipboard is empty" toast and type nothing.

---

## Tier 2 — Existing items still work (regression)

1. Re-open the menu; confirm the other items still appear and navigate
   (Disconnect, Quit, Server Commands, Clipboard Upload/Fetch, Toggle Performance Stats, etc.).
2. Select **Toggle Performance Stats** → stats overlay toggles (confirms menu actions still fire).

---

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | "Paste Clipboard Text" item present in the menu | Yes |
| 2 | Selecting it types the client clipboard into the host | Yes |
| 3 | "Pasted clipboard text" toast shown | Yes |
| 4 | Empty clipboard → "Clipboard is empty" toast, nothing typed | Yes |
| 5 | Other menu items unaffected (e.g. Toggle Stats works) | Yes |

Report SteamOS + Mesa version and which mode (Desktop/Game) you tested in.

---

## Report format

Commit `testing/test29-quickmenu-content/report.md` on
`diagnostic/test29-quickmenu-content-report`; PR targets the test branch.

---

## Safety rules (standing, streaming exception for this cycle)
- No package installs, no `sudo` outside read-only inspection; do not modify the AppImage
- Streaming authorized; pairing is not — if host isn't paired, stop and report
