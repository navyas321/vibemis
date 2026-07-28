# Known issues

Known issues in the current build. For what changed per release, see the latest
[Release](https://github.com/navyas321/vibemis/releases/latest) / `docs/release-notes-*.md`.

This file is hand-maintained. It is the single place for the current build's confirmed bugs
and their status — the README stays version-less and does not carry this table (see
[`docs/RELEASING.md`](RELEASING.md), "README update rule").

## Confirmed bugs

Confirmed bugs in the current build, with workarounds. (Fixes in flight are noted; rows drop
off as fixes land.)

| Issue | Workaround | Status |
|---|---|---|
| **D-pad steps twice** on adjustable Settings controls (e.g. the resolution-scale slider moves ±10 per press instead of ±5) | Use keyboard arrows, touch drag, or the mouse | Confirmed; fix queued (gamepad→key translation layer) |
| **In-stream touch taps still don't click** (and drags don't draw) on the host in direct-touch mode — the client now sends correct full-contact touch, but the host injects it as hover | Enable "Use touchscreen as a virtual trackpad" in Input settings | Client side fixed; awaiting a host-side (Vibepollo) fix |
| **Quick Menu items can't be tapped** — menu navigation is gamepad/keyboard only, so a touch-only user can open the menu but not operate it | Navigate with D-pad + A, or arrow keys + Enter | Confirmed; touch operability planned |
| **Text-send has no on-screen keyboard** — on a keyboard-less handheld there's no way to type into it; the first character can also drop if you type immediately | Use a physical/USB keyboard, or Paste Clipboard (clipboard sync) instead | Confirmed; OSK planned |
| **MENU / KBD touch buttons have small tap targets** | Aim carefully, or use the gamepad combo / keyboard shortcut | Confirmed; enlargement queued |
| **Settings page doesn't drag-scroll** (touch or pointer drag) | Use the scroll wheel or D-pad/stick navigation | Confirmed |
| **Host-type badge can mislabel** Apollo-lineage vs Sunshine hosts | Cosmetic only — streaming is unaffected | Fix in flight |

## Limitations

Permanent / architectural constraints (not build-specific bugs). Kept here so the README stays
version-less and free of any issues/limitations tables.

| Feature | Status |
|---|---|
| **Microphone passthrough** | Not possible yet in any Moonlight-family client: it requires host-side protocol support that Apollo/Vibepollo does not ship (tracked upstream — Apollo discussion #591). |
| **Ghosting / double-images and lost frames while Enable VRR is on** | Client-side defect in vibemis's VRR presentation, confirmed 2026-07-28 by a matched on-device A/B (BL-2541). With host frame generation ON, the same device and content measured: vibemis with **VRR off** 115.2 of 115.4 fps rendered (99.8% efficiency, 0.31% hitches) — matching the Nonary reference client (115.3) exactly — while vibemis with **VRR on** delivered only 92–93 fps in both pacing modes, i.e. ~22 fps and up to 15% of hitched frames worse than its own VRR-off path. A 15-minute soak confirmed VRR-off holds at 99.4% with no drift. Cause: our VRR timing core was vendored verbatim from Nonary v6.1.0-vrr9.1 and never re-synced, so it runs that fork's pre-retune tuning model. An earlier version of this entry blamed host-side Lossless Scaling frame generation, and one before that blamed panel overdrive — **both are withdrawn**; frame generation degrades all clients somewhat but the reference client absorbs it, and the panel never engages adaptive refresh at all (no `vrr_capable`, refresh pinned at 120 Hz in every measured arm). **Workaround: turn Enable VRR off. On this hardware that is not a degraded mode — it is the fastest and smoothest mode, and it needs no host-side change.** Fix in progress: re-vendor the VRR timing core from current upstream. |

## Experimental / not yet validated

The HDR item below is a validation gap specific to the current build — it resolves once the code
path is tested on HDR hardware.

| Feature | Status |
|---|---|
| **HDR streaming** | Ships **opt-in and marked Experimental** (off by default; auto-disabled on unsupported PCs). The code path is complete but has not yet been validated on HDR hardware — the primary test device's panel is SDR. Validation is planned via an external HDR display. |
