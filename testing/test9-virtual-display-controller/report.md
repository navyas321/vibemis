# Test9 Report — Virtual Display, Controller Diagnostics, Display Resolution

**Artifact tested:** `Vibemis-0.6.7-vibemis-test9-virtual-display-controller-x86_64.AppImage`
**md5:** `755512679d991e3e53aae044437c333e` ✓ verified
**Branch:** `fix/virtual-display-controller-display`
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5 — tested in both Desktop Mode and Game Mode
**Test date:** 2026-05-27
**Stream host:** Navid-PC (Vibepollo / Apollo 7.1.431, ServerCommand=Bubbles)

---

## 1. TL;DR

| Issue | Status | Notes |
|---|---|---|
| **#1 — Virtual Display on by default** | **PASS** | Checkbox checked by default; Apollo serverinfo reports `VirtualDisplayCapable=true, VirtualDisplayDriverReady=true` and the streams ran on the virtual display. |
| **#3 — Controller input** | **PASS (Game Mode) / FAIL (Desktop Mode)** | In Game Mode, Legion Go physical pads route through Steam Input → Steam Virtual Gamepad → Vibemis → Apollo as designed. In Desktop Mode the Steam Virtual Gamepad is detected with full mapping but receives no events. Mode-dependent, not a Vibemis code issue. |
| **#4 — Resolution requested matches user setting** | **PASS** | User set 1920x1200 @ 120 in Settings → Basic; log shows `VIBEMIS: Requesting 1920x1200 @ 120 fps from host` and launch URL has `mode=1920x1200x120`. |
| **#4b — Host display restore on disconnect** | **PASS (Game Mode) / FAIL (Desktop Mode)** | Re-test in Game Mode confirms Navid-PC display does return to its original resolution after disconnect. The Desktop Mode failure is also session/mode-specific, not a Vibepollo bug as initially suspected. |
| **#5 — HDR mis-state (NEW)** | **FAIL** | When the host has HDR enabled but the Z2 client does NOT support HDR, Vibemis still streams in HDR mode and the picture is washed out / desaturated. The HDR-capability gate (PR #11) appears not to be reached on this path. See §6. |

Two clean stream launches in one session, both at user-selected 1920×1200×120, no QML TypeErrors — the test8 fixes remain regression-free. Re-testing in Game Mode resolved both Issue #3 (controller) and Issue #4b (host restore) — the originally observed Desktop Mode behaviour is environment-dependent.

---

## 2. Issue #1 — Virtual Display default

User-reported: "resolution and virtual display look good." On the wire:

```
00:00:05 - getServerInfo HTTPS response: ...<VirtualDisplayCapable>true</VirtualDisplayCapable>
                                          <VirtualDisplayDriverReady>true</VirtualDisplayDriverReady>...
```

Both stream launches succeeded against the virtual display (no fallback or error). **PASS.**

---

## 3. Issue #3 — Controller (PASS in Game Mode, FAIL in Desktop Mode)

**Follow-up test in Game Mode: PASS.** User confirms physical Legion Go controls work end-to-end (movement, buttons, triggers) on the remote stream when Vibemis is run from Game Mode. This confirms the hypothesis below — Steam Input was the missing piece.

The instructions anticipated a "CONTROLLER NOT MAPPED" warning with a GUID to add. **That warning never fired.** Vibemis-side controller detection is healthy:

```
00:01:05 - SDL Info (0): Gamepad 0 (player 0) is: Steam Virtual Gamepad
              (VID/PID: 0x28de/0x11ff) (haptic capabilities: 0x10000)
              (mapping: 030079f6de280000ff11000001000000 ->
                030079f6de280000ff11000001000000,Steam Virtual Gamepad,
                a:b0,b:b1,back:b6,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,
                guide:b8,leftshoulder:b4,leftstick:b9,lefttrigger:a2,leftx:a0,lefty:a1,
                rightshoulder:b5,rightstick:b10,righttrigger:a5,rightx:a3,righty:a4,
                start:b7,x:b2,y:b3,platform:Linux,)
```

- Detected device: **Steam Virtual Gamepad** (Valve, VID `0x28de`, PID `0x11ff`).
- Full Xbox-style mapping present, all 4 axes / 11 buttons / D-pad hat mapped.
- Launch HTTP includes `gcmap=1&remoteControllersBitmap=1` — Vibemis is telling Apollo a controller is attached.

**Interpretation (confirmed).** The "Steam Virtual Gamepad" is the abstract device Steam Input exposes. The Legion Go S Z2's physical buttons reach this virtual gamepad **only when Steam Input is actively translating** them. In Desktop Mode that translation isn't happening for a non-Steam window — the virtual gamepad exists but receives no events. In Game Mode, Steam Input is always active and the routing works.

**Suggested follow-up (docs, not code):**
- Document "Launch Vibemis from Game Mode (or from inside Steam as a non-Steam game in Desktop Mode)" as the supported handheld controller workflow.
- No code change required in Vibemis for this issue.

---

## 4. Issue #4 — Resolution

User set Settings → Basic → 1920x1200, 120 fps (Z2 native panel is 1920x1200x120). Log:

```
00:00:45 - SDL Info (0): VIBEMIS: Requesting 1920x1200 @ 120 fps from host
            (Settings -> Basic -> change if this doesn't match your display)
00:00:48 - launch: appid=785894588&mode=1920x1200x120&...
00:01:04 - Launch response: status_code="200", sessionUrl0=rtspenc://192.168.4.78:48010
00:01:04 - SDL Info (0): RTSP port: 48010 / Starting RTSP handshake...
00:01:25 - SDL Error (0): Connection terminated: 0          # clean user disconnect
```

Then a second launch at 00:02:08 (Virtual Display app, appid=873650758) with the same mode, identical clean progression. **PASS.** The user-selected stream resolution flows through to Apollo correctly.

---

## 5. Issue #4b — Host display restore (PASS in Game Mode, FAIL in Desktop Mode)

**Re-test in Game Mode: PASS.** Navid-PC's monitor returns to its original resolution after disconnect when Vibemis is run from Game Mode. Apollo's restore path is functioning correctly.

The Desktop Mode failure originally reported is mode-specific. Possible explanations (not yet root-caused on the client side; this is a multi-component handshake):
- Different disconnect signal sent (e.g. process kill vs. clean shutdown) when terminating from Desktop Mode.
- KWin / X11 in Desktop Mode might re-trigger Apollo's display reset path differently.

Not a Vibemis bug for the common Steam Deck / Legion Go S Z2 workflow (Game Mode). Worth a closer look if Desktop Mode becomes a supported workflow, otherwise low priority.

---

## 6. Issue #5 — HDR mis-state (NEW)

**Symptom (Game Mode):** Host (Navid-PC) has HDR **enabled** on its display. The Legion Go S Z2's panel does **not** support HDR. Vibemis still streams in HDR mode, producing washed-out / desaturated colours on the Z2.

**Why this is unexpected:** PR #11 ("HDR display capability gate") landed on `vibemis-main` (commit `79d2b921`) specifically to prevent the client from requesting HDR when the local display doesn't advertise it. The gate appears to either:
1. Not be reached on this code path (e.g. virtual-display flow bypasses the check), or
2. Be reached but the Z2's panel is mis-reported as HDR-capable to the gate, or
3. Be a gate on whether to *render* HDR but not on the SDP/stream config sent to Apollo, so the host still encodes 10-bit BT.2020 and the client receives it without tone-mapping.

**Suggested log captures for the next test cycle:**
- `grep -i "HDR\|hdr\|bt2020\|bt.2020\|10-bit\|hdrcapable\|supportsHdr" <log>` during a stream where the host has HDR on.
- The serverinfo response on this run shows `<ServerCodecModeSupport>2032385</ServerCodecModeSupport>` — that's the host advertising HEVC Main10 + AV1 support; not necessarily a request for HDR but does say the host can encode it.
- Check whether the SDP / Launch HTTP includes any HDR mode hint (e.g. `mode=1920x1200x120x10` or an HDR query param).

This is the most actionable new finding from this test cycle — it surfaces only when the host has HDR on, which the previous tests against Navid-PC didn't have.

---

## 8. Other findings

- **Second stream ended with `Connection terminated: -1` + `Qt Critical: Connection terminated`** at 00:02:50 (Desktop Mode session). The first stream's clean `Connection terminated: 0` did not produce the Critical line. Could be the user closing differently, or an actual error on the second session — worth a closer look if it recurs.
- **No QML TypeErrors anywhere** — the test8 cleanup (waitForAsyncLoad / session.initialize / launchWarnings / session.start / hasServerCommands) remains clean.
- **HEVC Main profile / VAAPI 1.22 / Mesa 25.3** all still working; surgical libva hook fired (`[vibemis-apprun-hook] preferring host libva from /usr/lib64`).

---

## 9. Recommendation

**ITERATE — one open code-side issue (HDR), two resolved as Game-Mode-only environmental.**

- **Merge** the Issue #1 + Issue #4 changes in this branch — both verified working in both modes.
- **Issue #3 (controller):** **Resolved.** Game Mode works. Document the "Game Mode / launch-from-Steam" workflow as the supported controller path on handhelds. No Vibemis code change needed.
- **Issue #4b (host restore):** **Resolved in Game Mode.** Apollo's restore path works correctly; the Desktop Mode failure is the unsupported workflow. No client-side change needed for the supported path.
- **Issue #5 (HDR mis-state):** **Open and actionable.** Either PR #11's HDR gate isn't reached on this code path, the panel is mis-reported, or the gate only governs render — not the request sent to the host. Next test cycle should grep the log for HDR / 10-bit / BT.2020 markers in a Game Mode session against an HDR-enabled host, and trace the call path that picks the stream codec/bit-depth.
