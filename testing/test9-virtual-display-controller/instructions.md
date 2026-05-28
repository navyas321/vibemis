# Test9 Instructions — Virtual Display, Controller Diagnostics, Display Resolution

**AppImage:** `Vibemis-0.6.7-vibemis-test9-virtual-display-controller-x86_64.AppImage`
**md5:** `755512679d991e3e53aae044437c333e`
**Branch:** `fix/virtual-display-controller-display`
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5
**Purpose:** Verify Issue 1 fix (virtual display default), capture controller GUID (Issue 3), confirm stream resolution logging (Issue 4)

---

## Setup

```bash
chmod +x Vibemis-0.6.7-vibemis-test9-virtual-display-controller-x86_64.AppImage
./Vibemis-0.6.7-vibemis-test9-virtual-display-controller-x86_64.AppImage > ~/test9.log 2>&1
```

Connect to Navid-PC as usual.

---

## Tier 1 — Virtual display now on by default (Issue 1)

Open Settings. Under "Artemis Streaming Enhancements" confirm:
- [ ] "Use Virtual Display" checkbox is **checked** (it should be on by default now, no manual toggle needed)

Then launch Desktop.

**Expected:** Apollo creates a virtual display for the stream. Stream should start normally.

**If it crashes:** Note the exact error in the log around the crash line. Include in report.

---

## Tier 2 — Controller GUID capture (Issue 3)

After the stream starts (or immediately after launching), grep the log:

```bash
grep "CONTROLLER NOT MAPPED" ~/test9.log
```

**If you see output like this:**
```
CONTROLLER NOT MAPPED — will not be forwarded to host!
  Device name: Lenovo Legion Go S Z2 Controller
  GUID for gamecontrollerdb.txt: 03000000ef17000082610000...
  Axes: 6 | Buttons: 17 | Hats: 1
```

**→ Copy the full GUID line and include it in the test9 report.** This is what's needed to add the mapping and fix controller forwarding.

**If you see NO output:** The controller IS recognised (has an SDL mapping) — check if input is actually forwarded during the stream by moving the left stick.

---

## Tier 3 — Stream resolution (Issue 4)

```bash
grep "VIBEMIS: Requesting" ~/test9.log
```

**Expected output:**
```
VIBEMIS: Requesting 1280x720 @ 60 fps from host (Settings -> Basic -> change if this doesn't match your display)
```

This confirms vibemis is requesting 720p60 by default (the Moonlight/Artemis default), which means Apollo sets the HOST display to 720p during the stream.

**Action:** Go to Settings → Basic → change Resolution to `1920x1200` and FPS to `144` (the Z2's native display). Restart the stream to verify Apollo uses the correct resolution.

**Display restore (Issue 4b):** After disconnecting, check if the host's display resolution returns to its original state. If it does not:
- This is an **Apollo server-side config issue**
- In Apollo's web UI → Configuration → look for **"Restore Display After Stream"** and ensure it's enabled

---

## What to include in the test9 report

1. Was "Use Virtual Display" checked by default? (Issue 1 pass/fail)
2. Did the stream launch successfully with virtual display on? Or did it crash — and what was the error?
3. Paste the full output of `grep "CONTROLLER NOT MAPPED" ~/test9.log` (Issue 3 — GUID needed)
4. Paste the output of `grep "VIBEMIS: Requesting" ~/test9.log` (Issue 4 confirmation)
5. After changing resolution to 1920x1200 @ 144fps — does the stream look correct on the Z2?
6. Did the host display restore after disconnect?
