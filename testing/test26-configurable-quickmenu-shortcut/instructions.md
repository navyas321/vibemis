# Test26 Instructions — Configurable Quick Menu gamepad shortcut (Phase 4)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify the Quick Menu open combo can be changed in Settings and the chosen combo
takes effect.

---

## Background

Settings → **Gamepad Settings** now has a **"Quick Menu shortcut"** dropdown:

| Option | Combo |
|--------|-------|
| Default | Select + L1 + R1 + Y |
| — | Select + L1 + R1 + B |
| — | L3 + R3 (click both sticks) |
| — | Select + Start |

The selected combo is what opens the in-stream Quick Menu.

> **Note:** this build is based on `vibemis-main`, so the Quick Menu still uses the older
> windowed render path — in **Desktop Mode** the menu appears as before; the Game-Mode render
> fix is a separate cycle (test22). For THIS test, verifying the **combo change** is the goal:
> either watch the menu open in Desktop Mode, or confirm via the log that the new combo is
> detected. Requires a stream.

---

## Artifact

**AppImage:** `testing/test26-configurable-quickmenu-shortcut/Vibemis-0.6.7-vibemis-test26-configurable-quickmenu-shortcut-x86_64.AppImage`
**md5:** `0372c17f3f4f17f0ce1527d5064e1901`

```bash
md5sum testing/test26-configurable-quickmenu-shortcut/*.AppImage
```

---

## Setup

```bash
cd ~/vibemis
git fetch origin test26-configurable-quickmenu-shortcut
git checkout test26-configurable-quickmenu-shortcut && git pull
chmod +x testing/test26-configurable-quickmenu-shortcut/*.AppImage
./testing/test26-configurable-quickmenu-shortcut/*.AppImage --appimage-extract-and-run > ~/test26.log 2>&1 &
```

Run in **Desktop Mode** so the menu is visible for this test.

---

## Tier 1 — Default combo still works

1. Leave the shortcut on the **default** (Select + L1 + R1 + Y).
2. Start a stream, press **Select + L1 + R1 + Y** → menu opens.
3. Confirm the log shows: `grep "quick menu toggle gamepad combo" ~/test26.log` → a hit.

---

## Tier 2 — Change the combo

1. End stream. Settings → Gamepad Settings → **Quick Menu shortcut** → choose
   **"L3 + R3 (click both sticks)"**.
2. Start a stream. Press the **old** combo (Select+L1+R1+Y) → menu should **NOT** open.
3. Click **both analog sticks (L3 + R3)** → menu **should** open (and the log line appears).
4. Repeat with **"Select + Start"** to confirm a second non-default option works.

---

## Tier 3 — Persistence

1. Pick a non-default combo, fully quit, relaunch.
2. Settings shows the chosen combo still selected, and it opens the menu in a stream.

---

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | "Quick Menu shortcut" dropdown in Gamepad Settings (4 options) | Yes |
| 2 | Default combo opens the menu | Yes |
| 3 | After changing, old combo no longer opens it | Yes |
| 4 | New combo (L3+R3, then Select+Start) opens it | Yes |
| 5 | Log shows "quick menu toggle gamepad combo" on the configured combo | Yes |
| 6 | Choice persists across restart | Yes |

Report SteamOS + Mesa version.

---

## Report format

Commit `testing/test26-configurable-quickmenu-shortcut/report.md` on
`diagnostic/test26-configurable-quickmenu-shortcut-report`; PR targets the test branch.

---

## Safety rules (standing, streaming exception for this cycle)
- No package installs, no `sudo` outside read-only inspection; do not modify the AppImage
- Streaming authorized; pairing is not — if host isn't paired, stop and report
