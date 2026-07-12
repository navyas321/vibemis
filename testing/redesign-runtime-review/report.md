# Redesign Runtime Review — test88 (tokens) + test89 (Help)

**Reviewer:** clienttest (Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0, Qt 6.9.1)
**Artifact:** `Vibemis.AppImage` 0.15.0-beta.20260712.0237+ce61cb9 (md5 `a11e3c34535582f022878f202a06b698`) — the Steam-shortcut target
**Method:** source-confirmation (2 subagents) + on-device font check + **headless gamescope-emulation runtime capture** of the Help page (F1 → VbHelpView)
**Date:** 2026-07-11

---

## 1. TL;DR

| Cycle | Source | Runtime | Verdict |
|---|---|---|---|
| test88 redesign-tokens (VbTokens + Vb* components, → 0.14.0) | PASS | No consumer yet (foundation) | **MERGE** — clean; one real cosmetic gap (fonts, §3) |
| test89 redesign-help (VbHelpView, → 0.15.0) | PASS | **⚠️ layout defect — two cards collapse** | **ITERATE** (§2) |

**The Help redesign renders — accent theming, hero card, and Remote-play card look great — but the two "shortcut" cards (Gamepad shortcuts, Keyboard shortcuts) collapse to ~0 height, piling their title + rows on top of each other (unreadable). Reproduced identically across 3 captures (1920×1200 ×2, 1920×2400 ×1).** Screenshot: `help-1920x1200-shortcut-cards-collapsed.png`.

---

## 2. test89 RUNTIME DEFECT — shortcut cards collapse (ITERATE)

**What renders correctly:** header ("‹ Help"), the **Quick Menu hero card** (accent-gradient wash, teal border, Select/L1/R1/Ⓨ key-caps, copy), and the **Remote play** card (Tailscale text) — both crisp and correctly positioned.

**What breaks:** the **Gamepad shortcuts** and **Keyboard shortcuts** cards have their section title and all their rows rendered at the same Y coordinate — text stacked on itself, completely unreadable.

**Root cause (code correlation is dispositive):** the two broken cards are exactly the two whose `VbCard` uses `Layout.fillHeight: true` with **no** `Layout.preferredHeight`; the two clean cards use an explicit `Layout.preferredHeight`:

| Card | `app/gui/VbHelpView.qml` | Height binding | Result |
|---|---|---|---|
| Quick Menu hero | `:76-78` | `Layout.preferredHeight: 240` | ✅ renders |
| Remote play | `:189-191` | `Layout.preferredHeight: 200` | ✅ renders |
| Gamepad shortcuts | `:122-124` | `Layout.fillHeight: true` | ❌ collapses |
| Keyboard shortcuts | `:155-157` | `Layout.fillHeight: true` | ❌ collapses |

`VbCard` (`app/gui/VbCard.qml:8-37`) is a bare `Item` with **no `implicitHeight`** and a content holder anchored `anchors.fill: parent`, so a card is sized *entirely* by its parent Layout and its content never drives its height. When the body doesn't have surplus vertical space to distribute (the page renders at a fixed/centered height, not window-filling — visible as letterboxing in the 1920×2400 capture), `Layout.fillHeight` resolves to ~0 for those cards. Their inner `ColumnLayout { anchors.fill: parent }` is then 0-tall, so the title Text + the `Repeater` rows all collapse to y=0 and overlap.

**Not a font problem.** The clean cards use the same `VbTokens.fontDisplay`/`fontBody` (which fall back — see §3) and render fine, so the missing font is not what causes the overlap. The overlap is purely the Layout height-collapse above.

**Suggested fix (build agent):** give the two shortcut cards an explicit `Layout.preferredHeight` (matching the hero/Remote-play pattern), **or** give `VbCard` an `implicitHeight` derived from its content so `fillHeight` never starves to 0, **or** let the content drive height (drop `anchors.fill` on the inner ColumnLayout and bind the card height to `childrenRect`/implicit content height). Any one resolves it. Then re-verify at 1920×1200.

**Note:** the static preview `docs/design/redesign/previews/1f-help.png` (a design export, not the QML) would not show this — it only appears when the QML actually lays out, which is why source review passed and runtime capture caught it.

---

## 3. test88 — token foundation (MERGE) + confirmed font gap

VbTokens singleton + 5 Vb* components are correctly wired (registered `main.cpp`, in `qml.qrc`, tokens map the design JSON 1:1). No screen consumed them at 0.14.0, so behavior was unchanged — foundation only.

**On-device confirmation of the subagent's font concern:** `fc-list` on this SteamOS install shows **neither "Sora" nor "Manrope" is present** (the only hit, "Noto Sans Sora Sompeng", is an unrelated script face). `VbTokens.fontDisplay="Sora"`/`fontBody="Manrope"` are referenced but **not bundled and never `FontLoader`-ed**, so every redesigned screen falls back to the system sans on the actual target device — the typography will not match the design. Gamepad glyphs (Ⓐ/☰) *are* covered by installed Noto/DejaVu fallbacks, so those render without tofu. Recommend the build agent bundle Sora + Manrope `.ttf` under `app/` and load via `FontLoader`/`QFontDatabase::addApplicationFont`.

---

## 4. Recommendation

- **test89: ITERATE** — fix the two `fillHeight` shortcut cards (§2). One-line-per-card change; visible, reproducible, on the shipped 0.15.0 build.
- **test88: MERGE** — with a follow-up to bundle+load Sora/Manrope (§3), otherwise the whole redesign renders in fallback type on-device.
- **Environment:** captured headless via gamescope emulation (Game Mode surrogate) at the native 1920×1200. The defect is a resolution-independent Layout bug (reproduced at 2400 height too), not a gamescope artifact — the hero/Remote-play cards prove the renderer and fonts work.
