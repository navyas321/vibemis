# Test9 Report — Virtual Display, Controller Diagnostics, Display Resolution

**Artifact tested:** `Vibemis-0.6.7-vibemis-test9-virtual-display-controller-x86_64.AppImage`
**md5:** `755512679d991e3e53aae044437c333e` ✓ verified
**Branch:** `fix/virtual-display-controller-display`
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5 Desktop Mode
**Test date:** 2026-05-27
**Stream host:** Navid-PC (Vibepollo / Apollo 7.1.431, ServerCommand=Bubbles)

---

## 1. TL;DR

| Issue | Status | Notes |
|---|---|---|
| **#1 — Virtual Display on by default** | **PASS** | User confirmed checkbox checked by default; Apollo serverinfo reports `VirtualDisplayCapable=true, VirtualDisplayDriverReady=true` and the streams ran on the virtual display. |
| **#3 — Controller input** | **PARTIAL** | No `CONTROLLER NOT MAPPED` line — Vibemis detects "Steam Virtual Gamepad" (VID `0x28de`/PID `0x11ff`) with a full SDL mapping. `gcmap=1&remoteControllersBitmap=1` sent to host. **But user reports input does not reach the host.** Likely Steam Input layer issue, not a missing GUID. See §3. |
| **#4 — Resolution requested matches user setting** | **PASS** | After user set 1920x1200 @ 120 in Settings → Basic, log shows `VIBEMIS: Requesting 1920x1200 @ 120 fps from host` and launch URL has `mode=1920x1200x120`. |
| **#4b — Host display restore on disconnect** | **FAIL** | User confirms Navid-PC display does **not** return to original resolution after disconnect. No client-side log signal — this is server-side (Apollo) behaviour. See §5. |

Two clean stream launches in one session, both at user-selected 1920×1200×120, no QML TypeErrors — the test8 fixes remain regression-free.

---

## 2. Issue #1 — Virtual Display default

User-reported: "resolution and virtual display look good." On the wire:

```
00:00:05 - getServerInfo HTTPS response: ...<VirtualDisplayCapable>true</VirtualDisplayCapable>
                                          <VirtualDisplayDriverReady>true</VirtualDisplayDriverReady>...
```

Both stream launches succeeded against the virtual display (no fallback or error). **PASS.**

---

## 3. Issue #3 — Controller (PARTIAL — input not forwarded)

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

**Interpretation.** The "Steam Virtual Gamepad" is the abstract device Steam Input exposes. The Legion Go S Z2's physical buttons reach this virtual gamepad **only when Steam Input is actively translating** them. Vibemis is launched from SteamOS Desktop Mode here — Steam Input may not be intercepting the physical pads for a non-Steam window, so the virtual gamepad exists but receives no events.

**Suggested next experiments (not done in this cycle):**
1. Add Vibemis to Steam as a non-Steam game, launch it from inside Steam (Big Picture or Desktop), repeat the controller test — Steam Input will then route the pad.
2. If (1) works, document the workflow in the README. If (1) doesn't work, capture the raw HID device list (`ls /dev/input/by-id` while streaming) to see whether the Legion Go physical pads are even visible to SDL outside Steam.

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

## 5. Issue #4b — Host display restore (FAIL — server-side)

After disconnect the Navid-PC monitor does **not** return to its original resolution. There is no client-side signal for this in the log; Vibemis only requests a mode and Apollo handles the host display state on its end. This is the **Apollo (Vibepollo) server-side restore** path.

**Suggested fix path (server side, Navid-PC):**
- Vibepollo / Apollo Web UI → Configuration → look for "Restore Display After Stream" (or equivalent).
- If missing or already on, check the Apollo log on the host to see whether it's attempting a display mode restore and failing.

---

## 6. Other findings

- **Second stream ended with `Connection terminated: -1` + `Qt Critical: Connection terminated`** at 00:02:50. The first stream's clean `Connection terminated: 0` did not produce the Critical line. This could be the user closing differently, or an actual error on the second session — worth a closer look if it recurs.
- **No QML TypeErrors anywhere** — the test8 cleanup (waitForAsyncLoad / session.initialize / launchWarnings / session.start / hasServerCommands) remains clean.
- **HEVC Main profile / VAAPI 1.22 / Mesa 25.3** all still working; surgical libva hook fired (`[vibemis-apprun-hook] preferring host libva from /usr/lib64`).

---

## 7. Recommendation

**ITERATE.**

- **Merge** the Issue #1 + Issue #4 changes in this branch — both verified working.
- **Issue #3 (controller):** Not a missing-GUID problem. Investigate the Steam Input ↔ Steam Virtual Gamepad routing path in Desktop Mode, OR document "launch Vibemis from inside Steam" as the supported controller workflow. A code change in Vibemis is unlikely to be the fix.
- **Issue #4b (host restore):** Server-side. Out of scope for the Vibemis client — file as a Vibepollo configuration / behaviour issue against the host.
