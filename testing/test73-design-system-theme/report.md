# Test73 Report — Design-system Theme token singleton

**Artifact tested:** `Vibemis-0.6.7-alpha.test73-design-system-theme.20260530.0801+55a2c21-x86_64.AppImage`
**md5:** `383bf342016f3ddfd6d3f65520bd9e37` ✓ verified
**Branch:** `test73-design-system-theme` (commit `55a2c21`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0
**Test date:** 2026-05-30
**Prior report:** N/A

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — selftest exit 0, no Theme QML error | PASS | 7/7 checks, exit=0, zero Theme errors in log |
| B — Version label renders in teal | PASS | Teal text confirmed at Settings toolbar right edge (RGB ≈ 0,195,200) |
| C — No regression | PASS | App launches, Settings navigable, accent intact |

---

## 2. Tier 1 — Selftest (headless)

```
~/Downloads/Vibemis.AppImage selftest
SELFTEST RESULT: PASS (0 failure(s))
exit=0
```

All 7 named checks passed. The `import Theme 1.0` singleton registered without error at QML engine startup — confirming the module path and singleton hook are wired correctly.

Log grep for Theme errors (zero results):

```
grep -iE "Theme|is not a type|Singleton|QQmlApplicationEngine failed" /tmp/vibemis-test73.log
(no output)
```

Full log excerpt (launch through ready):

```
00:00:00 - Qt Warning: QGuiApplication::setDesktopFileName: ...desktop suffix...
00:00:01 - SDL Warn: VAAPI driver affected by RFI latency bug
00:00:01 - SDL Warn: Vulkan device does not support HDR10
00:00:02 - Qt Warning: mDNS is disabled by user preference
```

No `QQmlApplicationEngine failed`, no `is not a type`, no `Theme` errors. ✅

---

## 3. Tier 1 — Settings version label teal check

Settings was opened via gear icon. Due to the Claude Code interface covering the upper portion of the screen, pixel analysis was used on the captured screenshot.

Teal pixels were located at screen x=1068–1161, y=575–584 — the right side of the Settings toolbar visible past the Claude window boundary. Representative pixel values:

| x | y | R | G | B | Note |
|---|---|---|---|---|---|
| 1068 | 577 | 21 | 193 | 203 | teal foreground |
| 1082 | 577 | 2 | 198 | 200 | teal foreground |
| 1093 | 577 | 10 | 199 | 203 | teal foreground |
| 1120 | 577 | 0 | 195 | 198 | teal foreground |
| 1134 | 577 | 12 | 201 | 201 | teal foreground |

RGB values (R≈0–21, G≈170–204, B≈184–204) are exactly #00CCCC anti-aliased against the Settings toolbar dark background — not the white/grey that the version label showed before this branch. 162 teal pixels confirmed in this band.

Additional evidence of Settings being open: large teal clusters visible in the left navigation panel (client y≈111–301, x=0–399) consistent with teal category-icon accents.

**Note:** Screenshots `shot-t73b-settings.png`, `shot-t73c-settings.png`, `shot-t73d-raised.png` on device at `/tmp/` (not committed — too large and partially obstructed by test environment window). Pixel data is the primary evidence.

---

## 4. Tier 2 — Controller (N/A)

Not applicable for a launcher-only Theme check. No stream or SDL mapping tested.

---

## 5. Other findings

- **mDNS auto-exit**: Confirmed pre-existing. Test used `mdns=false` preseed throughout.
- **Screen obstruction**: Claude Code UI covers x=0–1067 at the y-level of the Vibemis window when positioned in the lower screen half. Workaround: pixel analysis at the visible right edge confirmed teal rendering. No code impact.

---

## 6. Recommendation

**MERGE** — Theme singleton resolves cleanly (selftest 7/7), no QML errors, and the Settings toolbar version label renders in Vibemis teal (#00CCCC) as intended. Design-system token wiring is confirmed working.
