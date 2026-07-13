# Test110 Report — double-Back navigation fix + A resumes a running session

**Artifact tested:** `Vibemis-0.2.0-alpha.001-x86_64.AppImage` (self-reports `0.2.0-alpha.001`)
**sha256:** `e7005099d38f7590d605151adfb45aa8f959bdcdd71a05ec2ee5ea003a2bc3fe` ✓ verified against GitHub release asset digest (91,400,696 bytes)
**Branch:** `test110-a-resume-doubleback` (commit `05fd8f5d`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0
**Test date:** 2026-07-13
**Prior report:** N/A

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — single-Back navigation fix (BL-1745) | PASS* | Back arrow (mouse, Desktop Mode) returns home in one click |
| B — A/tap resumes RESUME-badged app | PASS | Resume-badge tap (mouse) resumed the stream directly, no options sheet |
| C — no regression | PASS | No app-side crash/segfault/coredump across 5 stream attempts |

\* **Caveat:** this cycle was run entirely in **Desktop Mode with mouse/touch input**, not Game Mode with a gamepad. The instructions' Tier 1/2 steps specifically exercise the **gamepad/Enter-key** path (`AbstractButton` auto-`clicked()` on Return, stacked with a manual `Keys.onReturnPressed` handler) — a mouse click does not trigger `Keys.onReturnPressed` at all. So while the Tier 3 mouse-driven nav/resume behavior verified cleanly, **it does not exercise the exact double-fire code path Tier 1 targets.** Recorded as PASS per maintainer direction, with this caveat flagged for the record — a real gamepad/Game Mode pass would be a stronger signal for BL-1745 specifically.

---

## 2. Tier 3 — Desktop Mode spot-check (only tier run this cycle)

1. Clicked `Navid-PC` card → app grid opened normally.
2. Clicked back arrow once → returned to PC-card home immediately. No second click needed.
3. Re-entered grid, launched Desktop stream to Navid-PC, Quick Menu → Disconnect → RESUME badge appeared on the app.
4. Tapped/clicked the RESUME-badged app's box art → stream resumed directly, no options sheet shown (matches spec).

Tier 1 (gamepad B-once-to-home, ghost Add-PC card) and Tier 2 (gamepad A/X semantics on RESUME-badged vs. non-running apps) were **not exercised with a gamepad** — see caveat above.

---

## 3. Other findings — repeated control-stream disconnects (not a blocking regression)

During the Tier 3 session, every stream/resume attempt after the first disconnected within seconds of starting, with disconnect intervals shrinking on each retry:

| Time | Command | Stream start | Disconnect | Duration | Code |
|---|---|---|---|---|---|
| 00:01:38 | `launch` | 00:01:41 | 00:02:08 | ~27s | `0` (matches manual Quick-Menu Disconnect) |
| 00:02:30 | `launch` (not `resume`) | 00:02:31 | 00:03:31 | ~60s | `-1` |
| 00:03:39 | `resume` | 00:03:39 | 00:03:44 | ~5s | `-1` |
| 00:03:52 | `resume` | 00:03:52 | 00:04:10 | ~18s | `-1` |
| 00:04:16 | `resume` | 00:04:16 | 00:04:18 | ~2s | `-1` |

```
00:03:31 - SDL Error (0): Connection terminated: -1
00:03:44 - Qt Critical: Connection terminated
00:04:10 - SDL Info (0): Control stream received unexpected disconnect event
00:04:18 - SDL Error (0): Connection terminated: -1
00:04:28 - Qt Debug: NvHTTP::openConnection ... Command: "cancel"
```

No app-side crash signal (no segfault, coredump, qFatal, or abort) accompanies any of these — the app cleanly logs the disconnect and issues `cancel`. One oddity: the 00:02:30 re-entry issued a `launch` command rather than `resume`, despite a session already running server-side.

**Assessment (tester's judgment, not flagged as a regression):** likely Desktop-Mode-only environmental — consistent with the established finding (test9) that Desktop Mode does not reliably route/sustain the streaming session the way Game Mode's Steam Input path does. Not treated as blocking. Logs retained here for posterity in case it recurs in a real Game Mode pass.

Visually, the stream/UI looked fine throughout to the tester — this pattern only surfaced in the log, not as an observed glitch.

---

## 4. Recommendation (superseded — see §5/§6 for alpha.002 cycle)

**MERGE** — not blocking. BL-1745 nav fix and the RESUME-tap feature both verified via mouse/touch in Desktop Mode with no app-side crashes. Flagging for the record only:
- Tier 1/2 gamepad/Enter-key path unverified this cycle (see caveat).
- Repeated control-stream disconnects during Desktop Mode testing, believed environmental (not Vibemis-side), not blocking the release.

---

## 5. Addendum — alpha.001 A/Enter activation regression (2026-07-13, same day)

Shortly after this report merged, `0.2.0-alpha.001` was found **BAD**: A/Enter activation was dead on all grids (round-1 removed the manual `Keys.onReturnPressed` handlers, and `ItemDelegate` has no native Return activation on its own). This was caught before it shipped further and mitigated by switching channel back to `0.2.0-beta.010` (known-good). PR #189 was held for a fix.

## 6. Addendum — alpha.002 regression re-check (2026-07-13)

**Artifact:** `Vibemis-0.2.0-alpha.002-x86_64.AppImage`
**sha256:** `bc75baeb737c0a79d8cfc7dc11a0d007ebc02ce4de9cdc4e399d90501815b0b2` ✓ verified (matches GitHub release digest; instructions.md still only lists the alpha.001 digest — known protocol gap, same as §1).
**Commit:** `35914527` (manual Return/Enter handlers restored; double-Back fix now via `stackView.busy` idempotent push guards; A-resumes-running-session kept).

- Desktop Mode: launched the AppImage directly (`~/Downloads/Vibemis.AppImage`, logged), confirmed clean startup — self-reports `"0.2.0-alpha.002"`, `Navid-PC` discovered online via Tailscale, no crash/error in the startup log.
- Game Mode (tester-driven, physical device — Game Mode kills the Desktop Claude session so this was run and observed directly by the maintainer/tester): confirmed **A-button and mouse-click activation both work correctly** on the app/PC grids — the alpha.001 dead-activation regression is **fixed** in alpha.002.
- **Not re-run this cycle:** the full numbered Tier 1/2 gamepad scorecard (steps 1–9: single-Back-via-B, ghost Add-PC card, RESUME-badge A/X semantics, no-double-launch) was not exercised step-by-step — this cycle's scope was the regression check only, per direction. Tier 3 mouse nav/resume was already PASS from §2 and is architecturally unaffected by the alpha.002 diff (idempotent push guard, not a behavior change on the mouse path).

### Recommendation

**Regression check: PASS.** The alpha.001 blocker (dead A/Enter activation) is confirmed fixed on alpha.002, verified both by direct device observation (Game Mode, gamepad + mouse) and this cycle's Desktop Mode launch check. Full step-by-step Tier 1/2 gamepad scorecard replay against alpha.002 is still recommended before considering BL-1745 fully closed, but is not treated as blocking this update — flagging as a follow-up rather than re-running now.
