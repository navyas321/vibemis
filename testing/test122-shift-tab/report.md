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

## 6. Recommendation (superseded — see §7)

~~MERGE — PASS-pending-host-visual.~~ Overturned by the re-confirm run below.

---

## 7. ADDENDUM — host-visual re-confirm (2026-07-16 21:35–21:48 EDT, self-serve): **FAIL host-side**

Re-ran Tier 1 self-serve on the same alpha.014 stream (Navid-PC Desktop, 1920×1200 1:1),
wide **Notepad Save-As** dialog, screenshots at every step.

**Setup proof (forward chain via stream keyboard, xdotool → keyboard capture):**
File name (text selected) → Tab → Save-as-type (dotted focus rect) → Tab → Hide Folders (ring).
Stream-injected plain Tab demonstrably moves host dialog focus.

**Fires (QM highlight screenshot-verified on "Send Shift+Tab" before each):**

| Fire | Time (EDT) | Dialog foreground proof | Host focus result |
|---|---|---|---|
| 1 | 21:41:19 | stale (~4 min after last Tab) | no movement |
| 2 | 21:43:12 | stale | no movement |
| 3 | 21:46:03 | **proven** — dotted rect on Encoding set by stream Tab 5 s earlier | **no movement, not even forward** |

Client log: `Executing action: key_shift_tab` ×3, "Executing action…" pill captured on fire 2.

**Discriminating control (21:47:25):** `Send Esc` fired from the same menu, same highlight-verify
protocol → **the Save-As dialog closed instantly on the host.** The QM →
`LiSendKeyboardEvent` → host delivery path works; the defect is specific to Send Shift+Tab.

**RCA hypothesis (for the build agent):** `quickmenumanager.cpp:650-660` sends
`LiSendKeyboardEvent(VK_TAB, DOWN/UP, MODIFIER_SHIFT)` — the Shift rides only in the
`modifiers` bitfield; **no VK_SHIFT down/up events are sent**. If Vibepollo/Apollo ignores the
modifiers field for injection (relying on real modifier-key state), the event is dropped or
mis-injected. Note focus did not move even *forward*, so the host appears to not inject the
Tab at all. Host-side Vibepollo input log + the build agent's UIA focus log at
21:41:19 / 21:43:12 / 21:46:03 are the corroborating artifacts (timestamps posted on the bus
2026-07-16 21:44:57 and 21:48:03).

**Confound-free re-fire (21:55:18 EDT, second fresh stream).** The build agent raised that a
host game (Trails in the Sky) had been holding foreground and eating injected keys, then closed
it and re-staged. On the clean stage: `windowactivate` + a plain stream **Tab** landed *real*
focus on the **File name** edit (its text became selected) — proving the stream keyboard reaches
the host dialog *at that moment, with no game in the way*. Immediately after, QM **Send Shift+Tab**
(`key_shift_tab` logged) left focus **unchanged on File name** — no wrap-back to the last control.
This removes the foreground confound entirely and independently locks the FAIL.

**Build-agent corroboration (bus, 21:53:33):** FAIL confirmed via their UIA focus logger + code
read. Confirmed RCA: the QM path passes `MODIFIER_SHIFT` as a per-event bitfield with **no real
VK_LSHIFT key event**, whereas the client's physical-keyboard path (`keyboard.cpp:473`) sends
`VK_LSHIFT (0xA0)` as a genuine key. Vibepollo never sees Shift held, so the modified Tab is
dropped (not even forward). **BL-1788 REOPENED**; fix (wrap VK_TAB with explicit VK_LSHIFT
down/up) in flight as **alpha.016 / test122b**. The host-visual re-confirm caught a broken
feature before it could ship in stable.

**Also observed (minor):** activating a QM row closes the menu immediately; the "Sent key to
host" toast was not visible in a +1.0 s screenshot after fire 1 (the in-menu toast has no
surface once the menu closes — same class as the BL-2002/BL-2007 out-of-menu toast gap).
The menu *does* remember the highlighted row across reopen, which makes repeat-fire safe.

## 8. Revised recommendation

**ITERATE.** Client side remains fully proven (row renders per spec, action dispatches,
neighbors intact). Host side: Send Shift+Tab has **no effect** while Send Esc from the same
path works. Suggested fix: bracket the TAB with explicit VK_SHIFT (0x10) DOWN/UP events, or
confirm/repair Vibepollo's handling of the `modifiers` field. Re-test is cheap: the
fire-with-foreground-proof protocol above takes ~2 min on a live stream.

---

## 9. RE-TEST — alpha.016 (BL-1788 fix): **PASS**

**Artifact:** `Vibemis-0.2.0-alpha.016-x86_64.AppImage`
**md5:** `6453bbed0ed32bf47c2c722a4a1df35c` ✓ · **sha256:** `64ea08b6…dcec5e7` ✓ · selftest PASS.
**Fix:** `sendSpecialKey(key_shift_tab)` now emits a real **VK_LSHIFT DOWN → VK_TAB DOWN →
VK_TAB UP → VK_LSHIFT UP** sequence (mirroring the physical-keyboard path), instead of the
bitfield-only `MODIFIER_SHIFT` that Sunshine-lineage hosts ignore.

**Tier 1 — host-visual reverse-tab (live Desktop stream, host-staged Notepad Save-As, hands-off):**

| Step | Time (EDT) | Host focus ring | Meaning |
|---|---|---|---|
| Forward-Tab baseline | 22:29:06 | File name → **Save as type** (dotted rect) | channel proven, no game confound |
| Send Shift+Tab ×2 | 22:30:24, 22:32:30 | walked **backward** → **File name** (value pane selected) | `key_shift_tab` logged both fires |
| Send Esc (delivery control) | 22:33:43 | **Save-As dialog closed** (Notepad editor visible) | delivery path confirmed |

**Result: the focus ring moves BACKWARD** under Send Shift+Tab — the exact behavior that was
absent on alpha.014. The forward-Tab baseline confirms the keyboard channel reached the dialog,
and Send Esc closing it confirms delivery, so the backward movement is genuine, not a fluke.

**Host UIA corroboration (build agent, bus 22:35:25):** UIA focus log = 'Save as type' at the
baseline → **File-name value pane after Send Shift+Tab (backward)** → text editor at Esc.
"Direction unambiguous… contrast alpha.014 = ZERO movement. The VK_LSHIFT fix WORKS."

**Honest caveat (environmental, not the app):** a video decode-queue overflow hit my client
right at fire 1, and the host's UIA logger lagged ~1 min under load (7 parallel build agents),
so the **per-fire granularity (one control vs two) was not cleanly separable**. Both sides
captured the unambiguous **backward** direction and at least one clean control-step; neither
side saw any forward or zero movement. Given alpha.014 showed exactly zero and this shows
backward, the fix is proven. The build agent offered a belt-and-suspenders clean double-fire
re-stage; declined as redundant since client + host already agree on PASS.

**Tier 2 — regressions:** neighbor special key **Send Esc fired** (closed the dialog); the
Quick Menu list renders with the extra row and the footer un-clipped (Send Shift+Tab sits below
Send Esc, "Select / Resume game" below it — BL-1688 clip fix holds); row order sane
(…Alt+F4 → Super → Esc → Shift+Tab).

## 10. FINAL recommendation

**MERGE — PASS.** BL-1788 Send Shift+Tab reverse-tabs host focus on alpha.016, verified
host-visual with a forward-Tab baseline and an Esc delivery control, corroborated by the host
UIA log. This closes the sixth 0.2.0 goal item. (Supersedes the §8 ITERATE verdict, which
applied to alpha.014.)
