# Test36 Instructions — Back-paddle Quick Menu binding (Phase 8.5)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify the two new **back-paddle** options in the Quick Menu shortcut dropdown work.

> **Built on test26** (configurable Quick Menu shortcut). Adds paddle combos. Requires a paired
> host + stream and a controller with back paddles (the Legion Go S has them). Uses the pre-P3.1
> windowed menu render, so verify in **Desktop Mode** or via the log line.

---

## Background

The Settings → Gamepad Settings → **Quick Menu shortcut** dropdown gains two options:
- **Both back paddles (P1 + P2)** — press both rear paddles together
- **Select + back paddle 1**

These map to the controller paddle buttons (PADDLE1/PADDLE2). Selecting one makes that combo
open the Quick Menu (log: `Detected quick menu toggle gamepad combo`).

---

## Artifact

**AppImage:** `testing/test36-quickmenu-paddle-combo/Vibemis-0.6.7-vibemis-test36-quickmenu-paddle-combo-x86_64.AppImage`
**md5:** `eb8296f8a16afdec1c117269602c45d7`

```bash
md5sum testing/test36-quickmenu-paddle-combo/*.AppImage
```

## Setup

```bash
cd ~/vibemis
git fetch origin test36-quickmenu-paddle-combo
git checkout test36-quickmenu-paddle-combo && git pull
chmod +x testing/test36-quickmenu-paddle-combo/*.AppImage
./testing/test36-quickmenu-paddle-combo/*.AppImage --appimage-extract-and-run > ~/test36.log 2>&1 &
```

## Tier 1 — Paddle combos

1. First confirm the device exposes paddles: check `~/test36.log` / SDL for paddle mapping, or
   that the Legion Go S back buttons act as PADDLE1/PADDLE2 (they may need a Steam Input mapping).
2. Settings → Gamepad Settings → **Quick Menu shortcut** → choose **"Both back paddles (P1 + P2)"**.
3. Start a stream; press **both back paddles together** → Quick Menu opens; log shows the combo line.
4. Repeat with **"Select + back paddle 1"**.

## Tier 2 — Regression

1. Switch back to the default (Select + L1 + R1 + Y) → that combo opens the menu again; paddles don't.
2. Confirm the four original options still work.

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | Dropdown shows the 2 new paddle options | Yes |
| 2 | "Both back paddles" opens the menu | Yes (if device exposes paddles) |
| 3 | "Select + back paddle 1" opens the menu | Yes |
| 4 | Default + other options still work | Yes |
| 5 | If paddles aren't exposed by the device, note that | report |

**Important:** if the Legion Go S back buttons are NOT surfaced as controller paddles (they may be
keyboard binds via Steam Input), report that — it tells us whether paddle combos are viable here.

## Report format
Commit `testing/test36-quickmenu-paddle-combo/report.md` on
`diagnostic/test36-quickmenu-paddle-combo-report`; PR targets the test branch.

## Safety rules (standing, streaming exception for this cycle)
- No package installs, no `sudo` outside read-only inspection; do not modify the AppImage
- Streaming authorized; pairing is not — if host isn't paired, stop and report
