# Backlog Source-Confirmation Wave 2 — test83–87 (runtime deferred)

**Reviewer:** clienttest (Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0)
**Method:** read-only source review of each cycle's real feature commit (branches are already merged into `vibemis-main`; `git diff main..branch` is misleading due to ancestor/merge state + shallow-clone artifacts — reviewed the isolated feature commits instead).
**Date:** 2026-07-11
**Prior wave:** `testing/backlog-source-confirmation/report.md` (test23/24/25/26/31/32/40, PR #165)

---

## 1. TL;DR

| Cycle | Feature | Commit | Verdict | Runtime-testable here? |
|---|---|---|---|---|
| test83 | Remove blocking server-command probes (BL-1531) + guard clipboard dtor emits (BL-1534) | `37d07dd`/`314846c` region | **SOURCE-PASS** | No — needs stream + host |
| test84 | Pump Qt on non-threaded exec path (BL-1533) | `314846c` | **SOURCE-PASS** (already in main) | **No — unreachable on this device** |
| test85 | Surface Apollo per-app save-sync note (P3.13) | `a8cebba` | **SOURCE-PASS** (minor caveat) | Launcher-visible, no stream |
| test86 | Quick Menu "Type Text" text-send (P3.20) | `c0cbba1` | **ITERATE — Type Text item missing on main (menu still loads)** | No — needs stream + keyboard |
| test87 | Wire dead Quick Menu toggles (BL-1532) | `a5eb640` | **SOURCE-PASS** | No — needs stream |

**One actionable defect for the build agent: the test86 "Type Text" menu item is unreachable on `vibemis-main` because of a merge artifact (details below).** Everything else is correct/safe.

---

## 2. test86 — ⚠️ BLOCKER (merge artifact on vibemis-main)

`app/gui/QuickMenu.qml:323-331` (current `vibemis-main`) is a **single `ListElement {}` with every role declared twice**:

```qml
ListElement {
    text: qsTr("Type Text");            icon: "⌨"; action: "type_text";       description: qsTr("Send typed text to the host")
    text: qsTr("Paste Clipboard Text"); icon: "⌨"; action: "paste_clipboard"; description: qsTr("Type clipboard text into the host")
}
```

The `}` closing the Type-Text element and the `ListElement {` opening the Paste element were dropped during commit `49886c7` ("fix(merge): resolve quickmenumanager conflict markers"). The clean, separated form exists in the original test86 commit `c0cbba1` — the fusion was introduced by the later main re-sync merge, not by test86 itself.

**Effect (QML ListModel last-value-wins on duplicate roles):** the surviving item is **"Paste Clipboard Text"/`paste_clipboard`**; the **"Type Text"/`type_text` entry disappears entirely**. The test86 feature therefore has no menu entry point on main, even though its full backend (`quickmenumanager.cpp` `sendText`/`injectText`, `keyboard.cpp` text-mode branch, `session.cpp` `SDL_TEXTINPUT` routing) and the QML `type_text` action handler (line 431) are all present and correctly wired.

**Severity confirmed empirically (this device, Qt 6.9.1 `qmllint`):** the duplicate-role `ListElement` **passes `qmllint` clean (exit 0, no warning)** — so it is **NOT a hard QML load error**. The Quick Menu still loads; this is a **silent drop of the Type Text row**, not a menu-wide breakage. So the subagent's "either QML load error or item disappears" resolves to the milder branch: **the whole Quick Menu is fine, only the Type Text item is missing.** (Runtime row-dump not obtainable — the SteamOS system `qml` runner won't execute `console.log`; but `qmllint` clean is sufficient to rule out the load-error branch.)

**Fix (build agent):** split lines 323-331 back into two separate `ListElement {}` blocks so `type_text` and `paste_clipboard` are distinct entries; confirm the selftest launch log is free of QML errors.

**Underlying test86 plumbing — verified sound (no change needed):** `sendText()` → `LiSendUtf8TextEvent` + "Sent text to host" toast; char injection via synthetic `QKeyEvent`; SDL routing gated on menu-visible AND `isTextInputActive()` so host passthrough is unaffected outside the menu.

---

## 3. test83 — server-command probe + clipboard dtor (SOURCE-PASS)

- **BL-1531:** `servercommandmanager.cpp` `refreshCommands()` else-branch no longer calls the blocking `fetchAvailableCommands()` (6 endpoints × 5s = up to 30s UI stall); builtin populate remains. `fetchAvailableCommands()` is now dead code (safe to delete in a follow-up).
- **BL-1534:** clipboard-manager dtor nulls its fields directly instead of `disconnect()`-ing, which previously emitted signals into half-destroyed QML. Correct.

## 4. test84 — non-threaded Qt pump (SOURCE-PASS, but device-unreachable)

`Session::execInternal()` drains `QCoreApplication::processEvents(ExcludeUserInputEvents)` + `sendPostedEvents()` each loop iteration **only when `!m_ThreadedExec`**. Correct and safe: guarded no-op on X11/Wayland (a dedicated thread already pumps Qt there), non-blocking, no double-dispatch (`ExcludeUserInputEvents` keeps SDL in sole charge of input).

**Important scope note:** `m_ThreadedExec = isRunningX11() || isRunningWayland()`, so on **SteamOS this is always `true`** (Desktop Mode = KDE Wayland/X11; Game Mode = gamescope Wayland). The fix rescues only the EGLFS/DRM/Windows/macOS path. **It does NOT touch the SteamOS threaded path, so it does not by itself resolve a SteamOS-side test75 Quick-Menu freeze.** Branch is an ancestor of main and can be deleted.

## 5. test85 — save-sync note (SOURCE-PASS, minor caveat)

`computermodel.cpp` appends an advisory line to the `DetailsRole` string (display-only, no behavior change), gated on `computer->isApolloServer()`. Caveat: `isApolloServer()` is defined as `!isNvidiaServerSoftware`, so it is **also true for plain Sunshine hosts**, where the "Apollo feature" wording is inaccurate. Low severity (advisory text, and Vibepollo — an Apollo fork — is the project target). Optional follow-up: gate on a more specific save-sync capability signal if plain-Sunshine hosts are in scope.

## 6. test87 — wire dead Quick Menu toggles (SOURCE-PASS)

Bridge pattern is correct: `QuickMenuManager::sendKeyCombo` (Qt thread) pushes a registered SDL user event → `Session::execInternal` default case → `SdlInputHandler::dispatchQuickMenuCombo` (SDL thread, bounds-checked) → `performSpecialKeyCombo`. All four toggles terminate in real, proven combo handlers in `keyboard.cpp`. Non-blocking follow-up cleanups noted: (a) `toggle_mouse`/`toggle_fullscreen` don't update their `m_isMouseCaptured`/`m_isFullscreen` Q_PROPERTYs (harmless today — items are fire-and-forget, not stateful switches); (b) redundant file-scope `KeyCombo` enum duplicates `SdlInputHandler::KeyCombo` (drift risk — drop it now that `input.h` is included); (c) labels "Mouse/Keyboard Capture" are looser than the actual combos (mouse-mode toggle / full input ungrab).

---

## 7. Recommendation

- **test86: ITERATE** — build agent to split the fused `ListElement` on `vibemis-main` (`QuickMenu.qml:323-331`). This is the one item blocking a shipped feature.
- **test83/84/85/87: MERGE** (already merged) — correct and safe as reviewed.
- **Runtime status:** all of test83/84/86/87 are stream-gated (need an active Vibepollo stream, Game Mode = supported workflow) and cannot be headless-verified. test85 is launcher-visible without a stream. This report is source-confirmation only; runtime re-test to follow once the test86 fix ships and a stream window is available on the real host (Navid-PC).
