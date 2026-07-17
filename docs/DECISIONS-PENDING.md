# Vibemis agent-decision reviews — resolution record (BL-2073 … BL-2077)

Five "agent decided this without documented user sign-off" items were opened for review on
2026-07-16. All five are now **resolved** (2026-07-17): three cancelled by the user from the
Backlog board (shipped behaviour stands), two delegated to the agent to research + decide + close.
This doc is the durable record; per-item closes point here.

---

## A. Resolved by the user — cancelled from the board (shipped behaviour STANDS)

The user cancelled these three; the questions are withdrawn and current behaviour is confirmed.
No AWAITING-USER flag, no changes.

### BL-2073 — Use-Virtual-Display default ON
- **Agent decision:** `useVirtualDisplay` defaults `true` (`app/settings/streamingpreferences.cpp`);
  when on, `app/backend/nvhttp.cpp` appends `&virtualDisplay=1` so an Apollo/Vibepollo host
  auto-creates a per-client virtual display. Toggle at `SettingsView.qml` ("Use Virtual Display").
- **Resolution:** **Cancelled by user → default ON stands.** Handheld-friendly; Apollo/Vibepollo-only;
  toggleable with a tooltip.

### BL-2074 — Quick Menu default gamepad combo Select+L1+R1+Y
- **Agent decision:** default chord `QMGC_SELECT_LB_RB_Y` (`streamingpreferences.h`/`.cpp`), 4 combos
  + paddles configurable.
- **Resolution:** **Cancelled by user → Select+L1+R1+Y default stands.**

### BL-2075 — Quick Menu special-keys set incl. Send Alt+F4
- **Agent decision:** `QuickMenu.qml` exposes Send Ctrl+Alt+Del, Send Alt+F4, Send Super
  (handlers in `quickmenumanager.cpp`). Alt+F4 is a destructive host action reachable in two taps.
- **Resolution:** **Cancelled by user → current special-keys set + labels stand, Alt+F4 as-is (no confirm).**
- **Alt+F4 in-overlay confirm:** designed but **NOT implemented** (item cancelled before build). If
  ever wanted, the change is a one-point intercept in `QuickMenu.qml::executeAction()`: on
  `action === "key_alt_f4"`, route to a small confirm sub-view (`currentMenu = "confirm_altf4"`,
  mirroring the existing `text_send`/`server_commands` sub-menu pattern) and only call
  `quickMenuManager.executeAction("key_alt_f4")` on the second confirm tap. Left unimplemented and
  unmerged per the cancellation; recorded here so it's a 20-minute job if revived.

---

## B. Resolved by delegated sign-off (user comment 2026-07-17: "You make best call by doing research")

The user delegated these two: research → decide → implement → close.

### BL-2076 — Two-gate HDR (`displayHdrCapability` default TRUE on top of upstream `enableHdr`)
**Decision: KEEP the two-gate model as-is. No code change.**

- **What the gate does** (`app/streaming/session.cpp`):
  `effectiveHdr = enableHdr && displayHdrCapability`; if not effective, 10-bit codecs are masked off.
  `enableHdr` defaults **FALSE** (`SER_HDR`), the Vibemis companion `displayHdrCapability` defaults
  **TRUE** (`SER_DISPLAY_HDR_CAPABILITY`). So the capability gate is **inert for new users** (HDR is
  off by default); it only bites once a user explicitly enables HDR, at which point it lets an
  SDR-panel user (Legion Go S Z2 LCD) keep 8-bit and avoid the washed-out PQ-on-SDR picture without
  turning HDR streaming off entirely.
- **Research — can we auto-detect display HDR capability instead of a manual checkbox?**
  - **Qt 6 `QScreen`:** no HDR-capability property exists (geometry/DPI/refresh only). Qt's HDR
    support is nascent and has no display-capability query. (doc.qt.io QScreen; unresolved Qt-forum
    threads on HDR support.)
  - **SDL2** (the app's API surface, via SDL2-compat): **no** HDR display query. The HDR display
    property `SDL_PROP_DISPLAY_HDR_ENABLED_BOOLEAN` / `SDL_GetDisplayProperties` is **SDL3-only**
    (since SDL 3.2.0, added Feb 2024) — not reachable from SDL2 code.
  - Even SDL3's flag is documented **"for informational and diagnostic purposes only, as not all
    platforms provide this information at the display level,"** and it reports whether HDR is
    currently *enabled* (compositor state) rather than whether the *panel* is HDR-capable —
    unreliable exactly on the SteamOS/gamescope + SDR-LCD case that motivated this setting.
- **Why keep it:** robust client-side panel-capability detection is simply not available in the
  current SDL2/Qt6 stack, so the explicit "My display supports HDR" checkbox is the correct,
  pragmatic gate. The default TRUE is harmless (inert until HDR is enabled) and preserves
  back-compat for users who already had working HDR. Folding it into the single `enableHdr` toggle
  would re-introduce the washed-out-SDR bug it was added to fix.
- **Future option (non-blocking):** if/when Vibemis moves to the SDL3 API directly, expose
  `SDL_PROP_DISPLAY_HDR_ENABLED_BOOLEAN` as an *auto-suggest default* for the checkbox (still with a
  manual override), never as a hard gate given the "diagnostic-only" caveat.

### BL-2077 — Brand accent #00CCCC hardcoded vs the VbTokens selectable-accent system
**Decision: consolidate onto the VbTokens token system as the single source of truth, with
#00CCCC as the canonical brand default. Implemented.**

- **The defect** was a split source of truth: `app/gui/Theme.qml` (imported by 4 files) + two
  `app/gui/SettingsView.qml` literals hardcoded `#00CCCC`, while the dominant `app/gui/VbTokens.qml`
  token system (17 files, user-selectable via `uiAccentIndex`) defaulted its accent to a *different*
  teal `#2FC6D0`. Design work (P3.17/P3.18) is meant to anchor on the accent, so the disagreement —
  not the hue — is the real issue.
- **Implementation** (branch `test128-accent-single-source`, PR #233 → `vibemis-main`):
  - `VbTokens.accentOptions[0]` `#2FC6D0` → `#00CCCC` (brand default).
  - `Theme.qml.accent` stops hardcoding, resolves through `VbTokens.accent`.
  - the two `SettingsView` status-label literals → `VbTokens.accent`.
  - Net: ONE source of truth (VbTokens); the accent now follows the user's selection *everywhere*
    (answers the item's "fixed vs selectable" question in favour of the selectable token system);
    default rendering is byte-identical (#00CCCC as before).
- **Why #00CCCC over #2FC6D0 (WCAG, sRGB):** #00CCCC is AA-clean on the app's dark surfaces and
  marginally higher-contrast — **6.60:1** on `#303030`, **7.57:1** on `#262626`, **8.71:1** on
  `#1A1A1A` (≥AAA on the deeper surfaces) vs #2FC6D0's 6.35 / 7.29 / 8.38 — and it is the declared
  brand teal (test27) that P3.17/P3.18 already anchor on. Both pass WCAG AA; #00CCCC is the better
  default.
- **Verification:** `qmllint` syntax-clean on all three files; the `import Vibemis.Redesign 1.0`
  + `VbTokens.accent` pattern is already shipping in `QuickMenu.qml`/`VbCard.qml`; no circular
  import; CI Compile-Sanity/Build gate on PR #233. An `[alpha]` is cut for OPTIONAL on-device accent
  eyeball (cosmetic, low-risk — not a blocker).

_Resolved 2026-07-17 by worker w5-vibemis. A/B: user rulings; C: agent-delegated design calls._
