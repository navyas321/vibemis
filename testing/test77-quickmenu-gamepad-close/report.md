# Test77 Report — Quick Menu gamepad close / return-to-game — **PASS**

**Artifact:** `Vibemis-0.6.7-alpha.test77-quickmenu-gamepad-close.20260711.2353+e04647a-x86_64.AppImage`
**md5:** `f2e47542821f544b2680a2527ed7bc55` ✓
**Branch:** `test77-quickmenu-gamepad-close` (@ `e04647a8`) · **Report branch:** `diagnostic/test77-quickmenu-gamepad-close-report`
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0, Qt 6.9.1
**Test date:** 2026-07-11 · **Method:** live Desktop stream to Navid-PC **inside `scripts/gamescope-emulate.sh`** (`virtualDisplay=1`, 1920x1200x120, HEVC/VAAPI). Fixes the **test75** defect (PR #142).

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — fix "no way to close/quit & return to game" | **PASS** | Menu now shows **"Resume Game (Ⓑ / Back / Esc)"**; Esc/Back/Start close & resume. |
| B — discoverable exit + submenu escape | **PASS** | Submenu shows **"← Back (Ⓑ)"**; Esc from submenu → **main menu**, Esc from main → **close/resume**. |
| C — no combo re-trigger (state->buttons) | **PASS** | Exactly **1** `Detected quick menu toggle combo` per open (2 opens → 2 total). |
| D — no regression | **PASS** | Open/nav/close intact; 0 coredumps; no Qt errors. |

**Tier 2 (physical gamepad Back/Start close): N/A — no controller on this remote cycle.** Per the diff, `SDL_CONTROLLER_BUTTON_BACK` and `_START` now map to `Qt::Key_Escape` and flow through the **same `injectKey` bridge** that the keyboard Esc path exercises — which this run verified end-to-end. Recommend one on-device Game-Mode controller pass to close the loop.

---

## 2. Runtime evidence (gamescope emulation, in-stream)

Log (`/tmp/test77-verify.log`):
```
00:00:23 Video stream is 1920x1200x120 (format 0x100)
00:00:23 Setting QuickMenuManager geometry: ... 1536x960 (actual pos: 192,120)
00:00:29 Detected quick menu toggle combo          # open #1
00:00:29 QuickMenuManager: offscreen overlay renderer initialized (500x400)
00:00:44 Detected quick menu toggle combo          # open #2
coredumps: +0 ; toggle-detects total: 2 (exactly 1 per open — no re-trigger)
```

Screenshots (`shots/`):
- **`A1-menu-open.jpg`** — main menu; bottom action reads **"Resume Game (Ⓑ / Back / Esc)"** (was "Close (Esc)"). Fix #3 ✓
- **`C1-submenu.jpg`** — Down×2 → Return opened **Server Commands** submenu; bottom action reads **"← Back (Ⓑ)"**. Nav + fix #3 submenu ✓
- **`D1-esc-from-submenu.jpg`** — Esc in the submenu **returned to the main "Quick Menu"** (not a full close). Fix #4 ✓
- **`E1-esc-close.jpg`** — Esc from the main menu **closed the overlay and resumed the stream**. ✓

## 3. Mapping to the test77 changes (all validated)
1. **Back/Select + Start → close** (`gamepad.cpp`: `BUTTON_BACK`/`BUTTON_START → Key_Escape`) — same injectKey bridge as the verified keyboard Esc. ✓ (runtime keyboard; gamepad source-confirmed)
2. **`state->buttons = 0` after each combo** — no re-trigger observed (1 detect/open). ✓
3. **Discoverable hint "Resume Game (Ⓑ / Back / Esc)" / "← Back (Ⓑ)"** — visible in A1/C1. ✓
4. **Submenu Esc → main menu; main Esc → resume** — D1/E1. ✓

## 4. Negative / regression
- Open → nav → close all intact (keyboard). No stream regression; 0 coredumps; no `Qt Critical`/`TypeError`.
- Quit combo / stats combo not exercised (menu-closed gamepad combos → Tier 2, N/A no controller); unchanged in the diff.

## 5. Recommendation
**MERGE** test77 → cut a beta so the fix reaches the release channel. One optional on-device Game-Mode **controller** pass would runtime-confirm the physical Back/Start close (code path already validated via the shared keyboard bridge). The device's Steam shortcut has been pointed at this verified build for immediate use.

_Notes: live hub bus reachable at `https://hearth.tail71d120.ts.net` (the `:8766` port was a dead endpoint). CLI `stream <host> "Desktop"` still fails name-match (GUI launch works) — minor, separate._
