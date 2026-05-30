# Test22 Report — Quick Menu renders + navigates as an in-stream overlay

**Artifact tested:** `Vibemis-0.6.7-vibemis-test22-quickmenu-overlay-x86_64.AppImage`
**md5:** `683719e1fdd5dba2716bf6c65cb64ded` ✓ verified (matches instructions.md)
**Branch:** `test22-quickmenu-overlay`
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.6, Mesa 25.3.0 (radeonsi, AMD Ryzen Z2 Go), VAAPI 1.22
**Test date:** 2026-05-30
**Mode:** **Desktop Mode** (KDE Plasma), keyboard-driven automation (xdotool + spectacle)
**Host:** Navid-PC (192.168.4.78), Apollo — paired, online; streamed the **Desktop** app at 1920×1200×120 HEVC
**Prior report:** N/A (first verification of the Quick Menu render path; FOUNDATION of the Quick Menu group)

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — Quick Menu opens as an in-stream overlay | **PASS** | `Ctrl+Alt+Shift+\` → `Detected quick menu toggle combo` → overlay renders centered over the video |
| B — Drawn via OverlayManager surface (not a separate window) | **PASS** | `QuickMenuManager: offscreen overlay renderer initialized (500x400)` — composited into the stream, no separate OS window |
| C — Renders in Desktop Mode | **PASS** | Confirmed visually in Desktop Mode (instructions say it should now work in both Game + Desktop Mode) |
| D — Keyboard navigation | **PASS** | Arrow Down ×2 moved highlight Disconnect → Server Commands; Esc closed the menu |
| E — No regression / clean teardown | **PASS** | `Ctrl+Alt+Shift+Q` disconnected cleanly (all streams cleaned up), app returned to PC list healthy |

**Recommendation: MERGE.** The OverlayManager-surface architecture works — the Quick Menu is a true
in-stream overlay and navigates by keyboard. This unblocks the rest of the Quick Menu group
(test29/33/47). One host-side caveat noted in §4 (Virtual Display app), not a Vibemis defect.

---

## 2. Tier 1 — Quick Menu opens, renders over video, navigates

**Automation flow (Desktop Mode, no controller needed):** launch with `QT_QPA_PLATFORM=xcb` →
single-click Navid-PC card → single-click **Desktop** tile → stream establishes → `Ctrl+Alt+Shift+\`.

Open combo detected and overlay renderer initialized:
```
00:07:46 - SDL Info (0): Detected quick menu toggle combo
00:07:46 - Qt Debug: QuickMenu: Refreshing server commands on open
00:07:46 - SDL Info (0): QuickMenuManager: offscreen overlay renderer initialized (500x400)
```

The menu rendered **centered over the live video** (screenshot `09-quickmenu.png`) with a teal
"Quick Menu" header and 5 items:
1. **Disconnect** (default-highlighted)
2. **Quit**
3. **Server Commands**
4. **Clipboard Upload**
5. **Fetch Clipboard**

**Navigation:** `Down` ×2 moved the highlight from **Disconnect → Server Commands**
(screenshot `10-nav-down.png`). `Esc` closed the overlay back to plain video
(`11-menu-closed.png`). Open → navigate → close all worked via keyboard.

## 3. Tier 2 — Architecture / teardown

The overlay is drawn through the offscreen `QuickMenuManager` renderer and composited into the
stream surface (the `Setting QuickMenuManager geometry … 1472x920` + `offscreen overlay renderer
initialized (500x400)` lines), confirming the P3.1 OverlayManager-surface path rather than the old
separate `QQuickView` OS window. Clean disconnect:
```
00:09:19 - SDL Info (0): Stopping control stream...
00:09:19 - SDL Info (0): Cleaning up video stream...   (＋ input / control / audio / platform)
00:09:19 - Qt Debug: ClipboardManager: Disconnected
```
App returned to the PC list and remained responsive (no crash, no hang).

## 4. Other findings

- **Virtual Display app fails host-side (NOT a Vibemis bug).** First attempt streamed the
  **Virtual Desktop** tile (`virtualDisplay=1`); the client connected and created HEVC surfaces but
  never received an IDR frame — after ~30 s the host terminated:
  `Server notified termination reason: 0x80030023` → `Connection terminated`. The **Desktop** app
  then streamed flawlessly with the identical client. This points to a host-side Apollo virtual-display
  encoder/capture issue on Navid-PC, not the client. Flagging for the build agent / host owner.
- **Automation milestone:** the full streaming flow is now scriptable in Desktop Mode with
  keyboard + screenshots (launch → card → app tile → stream → in-stream combos → quit). The Quick
  Menu open/nav/close combos (`Ctrl+Alt+Shift+\`, arrows, Esc) all reach the offscreen scene. This
  unblocks autonomous verification of the remaining stream-required cycles.
- **mDNS:** preseeded `mdns=false` (known auto-exit avoidance); host still discovered via the saved
  manual address and reached **online** immediately.
- ICMP ping to the host is blocked/dropped — reachability must be judged from the app's
  `"Navid-PC" is now online` + applist, not `ping`.

## 5. Recommendation

**MERGE.** All five checks pass; the Quick Menu render path is solid in Desktop Mode and the group's
foundation is verified. Suggest the host owner look at the Virtual Display encoder (term `0x80030023`)
separately. Game-Mode gamepad-combo nav (`Select+L1+R1+Y`) remains the supported-workflow path and is
not blocked by anything here — keyboard parity is confirmed.
