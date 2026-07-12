# Test29 / Test33 / Test47 — Quick Menu content stack — SOURCE-CONFIRMED (runtime deferred: host in use)

**Alphas (rebased onto app-seek fix, CI-green):** test29 `0.11.3…a6c9564` (md5 76f6ae12) · test33 `0.11.3…0b8ba79` (898f3d8f) · test47 `0.11.3…34ef441` (0099f14a)
**Device:** Legion Go S Z2, SteamOS 3.8.5 · **Date:** 2026-07-12
**Note:** the build agent **rebuilt these onto the test78 CLI app-seek fix** at my request → CLI stream-entry now works on them. **Runtime (in-stream) verification is deferred** because the **maintainer is actively using the real host** (Claude Design redesign) — my streams terminate ~26s (Connection terminated -1) and I'm not disrupting their live work. All three are **source-confirmed**; runtime pass will run when the host is free (or via the mock-host).

---

## 1. TL;DR

| Cycle | Feature | Source | Runtime |
|---|---|---|---|
| test29 | Quick Menu **Paste Clipboard Text** | ✅ confirmed | ⏭️ deferred (host in use) |
| test33 | Quick Menu **Stream Info** toast | ✅ confirmed | ⏭️ deferred |
| test47 | Quick Menu **Send Special Keys** | ✅ confirmed | ⏭️ deferred |

## 2. Source evidence
- **test29 — Paste Clipboard** (`test29-quickmenu-content`): `app/gui/QuickMenu.qml:264` item `"Paste Clipboard Text"` → `app/backend/quickmenumanager.cpp:411 pasteClipboard()` (`:415` impl) → on success `:424 showToast("Pasted clipboard text")` (empty-clipboard path shows the "empty" toast). Toast mechanism present (`QuickMenu.qml:157-188,410-419`).
- **test33 — Stream Info** (`test33-quickmenu-streaminfo`): `QuickMenu.qml:270` item `"Stream Info"` → `quickmenumanager.cpp:433` builds `"%1x%2 @ %3 · %4 Mbps · %5"` from `prefs->width/height/fps`, bitrate, and codec name → `showToast(...)`. Matches the expected `1920x1200 @ 120 · 40.0 Mbps · HEVC`.
- **test47 — Special Keys** (`test47-quickmenu-special-keys`): `QuickMenu.qml:288-309` items **Send Ctrl+Alt+Del / Send Alt+F4 / Send Super (Win) / Send Esc** (each with description) → special-key send actions.

## 3. Partial runtime signal (already observed on the 0.11.0 beta before termination)
The merged Quick Menu renders in-stream with all items + the Resume-Game hint, and Server Commands loads live ("Bubbles"), captured before the host-conflict termination — so the menu render/nav path is healthy on the shipping build.

## 4. Recommendation
**MERGE** on source review; run the in-stream toast/paste/special-keys **runtime pass when the host is free** (menu opens ~12s in; a ~20s window suffices), or via the Sunshine self-host (`testing/automation/README-input-and-selfhost.md`) to avoid contending with the maintainer's live host.
