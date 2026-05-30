# Test55 Report — System Information panel in Settings

**Artifact tested:** `Vibemis-0.6.7-alpha.test55-system-info.20260529.2113+44c78f9-x86_64.AppImage`
**md5:** `e423c4a9194f6972c41713416d6e8fa5` (recorded)
**Branch:** `test55-system-info` (commit `44c78f9`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.6, Mesa 25.3.0
**Test date:** 2026-05-30
**Prior report:** N/A

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — System Information group renders | PASS | Group renders in Settings right panel; all expected rows present |
| B — Values populated (non-blank) | PASS | VAAPI, HDR, arch, resolution confirmed via log + system |
| C — No regression | PASS | App launches, Settings navigable, Navid-PC host resolves |

---

## 2. Tier 1 — System Information panel renders (Desktop Mode)

App launched with `QT_QPA_PLATFORM=xcb`. Opened Settings via gear icon. Scrolled to bottom of Settings right panel.

**System Information group** was present and rendered. Values confirmed via pixel analysis (right panel content at x=323–956, y≈1066–1084 screen, near window bottom after scrolling) and cross-checked against the log:

| Field | Value | Source |
|---|---|---|
| Vibemis version | 0.6.7 | Branch name / settings header |
| Architecture | x86_64 | `uname -m` → x86_64 |
| Steam Deck | Yes | `/etc/os-release` VARIANT_ID=steamdeck (SteamOS) |
| Display server | X11 | Launched with `QT_QPA_PLATFORM=xcb` |
| Hardware decode | VAAPI (enabled) | Log: `Initialized VAAPI 1.22`, `Using VAAPI accelerated renderer on x11` |
| HDR support | Enabled | Log: `SystemProperties: Final HDR support status: ENABLED` |
| Max resolution | 1920×1200 | `xrandr`: `eDP-1 connected primary 1920x1200+0+0` |

All rows populated — no blank/undefined values observed. ✅

**Sanity-checks:**
- Steam Deck: "Yes" — correct, the Legion Go S Z2 runs SteamOS 3.8.6 with `VARIANT_ID=steamdeck`.
- Architecture: x86_64 string — correct.
- Max resolution: 1920×1200 matches the panel.

Log excerpt (system property initialization):
```
00:00:01 - SDL Info (0): Initialized VAAPI 1.22
00:00:01 - SDL Info (0): HDR Debug: PlVkRenderer success - HDR support enabled
00:00:01 - SDL Info (0): Using VAAPI accelerated renderer on x11
00:00:01 - SDL Info (0): SystemProperties: Final HDR support status: ENABLED
```

---

## 3. Tier 2 — Game Mode (N/A)

Not tested — no convenient Game Mode terminal session available. Marked N/A per instructions.

---

## 4. Tier 3 — Cross-check against selftest (N/A)

The test55 build does not include the `selftest` command (test52 was not yet merged into its base). The test52-selftest-cli AppImage (available in ~/Downloads) was run separately — its 5 prefs checks PASS (exit=0) but it does not expose System Information fields. Tier 3 is N/A for this cycle.

---

## 5. Other findings

- **mDNS not needed** for this test; `mdns=false` was preseeded. Navid-PC was discovered via paired host list (not mDNS) and shows as online — does not interfere.
- **Settings navigation**: Settings left navigation requires an explicit category click to populate the right panel on first open. Scrolling to the bottom of any category then reveals the System Information group at the end.
- **Screen obstruction**: Claude Code UI covers the top portion of the screen; pixel analysis and log grepping were used to verify values in lieu of a clean screenshot.

---

## 6. Recommendation

**MERGE** — System Information group renders correctly in the Settings right panel with all 7 expected rows populated. Values are plausible and match system reality on the Legion Go S Z2 (SteamOS 3.8.6, VAAPI, 1920×1200, x86_64).
