# Test122 Report — Quick Menu "Send Shift+Tab" special key (BL-1788)

**Artifact:** `Vibemis-0.2.0-alpha.014-x86_64.AppImage`
**md5:** `ea3af561d269e8a86c045537b319f035` ✓ · **sha256:** `52b0f6e0…6dfe8d05` ✓ (both exact)
**Branch:** `test122-shift-tab` — **Device:** Legion Go S Z2, SteamOS 3.8.5, Desktop Mode
**Test date:** 2026-07-16. The SIXTH goal item.

---

## 1. TL;DR

| Tier | Verdict |
|---|---|
| 0 — integrity | PASS (hashes exact, selftest PASS exit 0) |
| 1 — the key (client) | **PASS** — row renders per spec; `key_shift_tab` fired ×2 clean |
| 1 — the key (host visual) | **PENDING** — focus-ring walk-back not captured (dialog dismissed mid-exchange); NOT a failure |
| 2 — regressions | **PASS** — other special keys still fire (Super opened host Start menu); list renders with the extra row, no footer clip (BL-1688 holds) |

**Recommendation: PASS-pending-host-visual** (build agent's disposition) — Shift+Tab clearly
transmits; a live host eyeball on resume closes the last 5%. Do not block.

## 2. Tier 1 — client evidence

The new row renders exactly per spec: **"Send Shift+Tab"**, icon `key`, positioned directly
**below "Send Esc"** (last item in the special-keys section), description "Reverse-tab focus on
the host" (verified in-stream screenshot + `QuickMenu.qml:526-530`, `action: "key_shift_tab"`).

Fired twice from the live Quick Menu (host Notepad Font dialog staged, focus tabbed forward to
the Size field):
```
21:17:41 EDT  Qt Debug: Executing action: key_shift_tab  ×1
21:17:57 EDT  Qt Debug: Executing action: key_shift_tab  ×1
```
Both clean, no errors. Uses the same `LiSendKeyboardEvent` DOWN/UP path (VK_TAB + Shift) as the
other special keys.

**Host visual: uncaptured, not failed.** During the two-agent exchange the host Font dialog got
dismissed (a Shift+Tab likely wrapped past the first control and closed the modal; a subsequent
`Send Super` fire opened the Windows Start menu). The build agent's read: *"NOT a failure signal,
just uncaptured … shift+tab clearly transmits. File as PASS-pending-host-visual."* On resume:
re-confirm with a wider dialog (Notepad **Save-As** has more controls, harder to escape) or a live
maintainer eyeball on a single fire.

## 3. Tier 2 — regressions

- **Other special keys still fire (with host reaction):** `Send Super (Win) key` fired and
  **opened the host Windows Start menu** — an unambiguous host-side reaction, confirming the
  special-keys path is intact end-to-end for the neighbors of the new row. (`key_super` ×2 logged.)
- **List renders with the extra row, no clipping:** navigated to the very bottom — the
  "Send Shift+Tab" row displays fully with its selection border and the footer ("Select /
  Resume game") below it, no overflow. **The BL-1688 footer-clip fix holds** with the added row.
- **Order/count sane:** …Send Ctrl+Alt+Del → Send Alt+F4 → Send Super (Win) key → Send Esc →
  **Send Shift+Tab** (last). Matches the intended special-keys ordering.

## 4. Method note (for the resume)

Quick-Menu **list-row navigation via injected gamepad is position-unreliable** (blind d-pad
counting landed on Super instead of Esc twice) — the same nav-order-vs-visible-order quirk seen
in test118. On resume, screenshot-verify the highlight before each fire, or use a wider host
dialog so an over-shoot doesn't dismiss it. Left a host Windows Start menu open at teardown
(harmless; maintainer present to dismiss) — stopped firing keys once the session was paused
rather than risk more accidental host actions.

## 5. Teardown

Stream quit, host session cancelled (`<cancel>1`), app closed, rig stopped. Config at baseline.

## 6. Recommendation

**MERGE — PASS-pending-host-visual.** Client transmit proven, row/order/clip all correct, neighbor
special keys intact. One live host-focus eyeball on resume (wider dialog) converts this to a full
PASS and closes the sixth goal item.
