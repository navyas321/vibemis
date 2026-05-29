# Vibemis — phase status & remaining work (with blockers)

Living tracker for the Phase 3 roadmap. Each phase lists what's **done** (with its test PR),
what's **remaining**, and any **BLOCKER** (so work can start and notes live next to the gap).
Code that's deliberately stubbed pending a blocker carries a `// NOTE(phase):` or `// TODO(phase):`
comment so it's greppable: `grep -rn "TODO(P3" app/`.

> Test numbering is **chronological, not phase-ordered** — see "Why PR numbers jump phases" at the
> bottom. The phase grouping here is the logical view; `testing/TEST_CHECKLIST.md` is the test order.

---

## P3.1 — Quick Menu as OverlayManager surface (Game Mode)  ✅ implemented
- Done: test22 (#44). Foundation for all Quick Menu content.

## P3.3 — Vibepollo quality presets  ✅ implemented
- Done: test23 (#45).

## P3.4 — Expand Quick Menu content  ✅ implemented (stacked on test22)
- Done: Paste test29 (#51), Stream Info test33 (#55), Special Keys test47 (#67).
- Remaining (low priority): in-stream "disconnect" / "toggle stats" menu actions.
  - BLOCKER: `Session::toggleFullscreen()` is private (hit this on test29). NOTE in quickmenumanager.cpp.

## P3.6 — Display/scaling polish  ✅ mostly implemented
- Done: compact overlay test24 (#46); scale mode test25 (#47); zoom test31 (#53); pan test32 (#54);
  perf-overlay corner test49 (#69); perf-overlay text size test50 (#70).

## Phase 4 / Input  ✅ implemented
- Done: configurable QM gamepad combo test26 (#48); back-paddle combos test36 (#56).

## P3.7 — Tailscale remote play  🟡 partial
- Done: Add-PC Tailscale hint test28 (#50).
- Remaining: prefer Tailscale (100.64.0.0/10 CGNAT) addresses when reaching a host; MagicDNS name
  support; a "remote play over Tailscale" doc.
- BLOCKER: can't validate NAT traversal / real remote latency without a live Tailscale network +
  remote host (test-agent hardware is LAN-only right now). **Plan:** implement the client-side
  address-preference logic behind a setting, mark the path with `// TODO(P3.7)`, and ship it as its
  own test PR with a launcher-only Tier-1 (setting persists) + a "needs remote network" Tier-2 the
  test agent marks N/A until a remote host exists.

## P3.8 — Artemis-Android parity  🟡 needs audit, then incremental
- Remaining (parity gaps to confirm against Artemis-Android): on-screen touch controls overlay,
  per-game stream profiles, richer gamepad mapping UI, on-screen keyboard.
- BLOCKER: no formal feature spec yet. **Plan:** land a parity-matrix doc (Android feature → Vibemis
  status), then pick the highest-value gap (likely per-game profiles) as the next test PR.

## P3.9 — UI modernization (Material)  🟡 partial
- Done: brand accent test27 (#49); About section test37 (#57); first-run hint test39 (#59).
- Remaining: consistent Material control styling pass, spacing/typography, dark-theme polish.
- Not blocked — large, so done incrementally as small test PRs.

## P3.10 — SteamOS one-click integration  🟡 partial
- Done: helper scripts bundle test48 (#68) — install / update / add-to-steam / add-all / pair /
  uninstall / doctor.
- Remaining: a single guided "one-click" flow (download → install → add to Steam) and a `.desktop`
  polish for Desktop Mode.
- Not blocked.

## P4.0 — Repo hygiene (DEFERRED to post-1.0 / first stable release)  ⏸️
Hide the Claude/agent development files from GitHub. **Decision: deferred** until after the first
stable release — do NOT start early. Recommended approach when we do it: **two-repo split** — keep
the code repo public (so Releases/AppImages stay downloadable) and move all agent meta (CLAUDE.md,
docs/personas, docs/ROUTINE_PROMPT.md, docs/WORKFLOW.md, docs/PHASE_STATUS.md, testing/*) into a
separate private repo that the agents also clone. Alternatives considered: private-dev + public
release mirror; cosmetic rename + trailer strip; authorship-only history scrub (git-filter-repo).

## P3.11 — Newer researched features  🟢 ongoing
- Done: battery-saver bitrate test40 (#60); settings export/import test41 (#61); special keys
  test47 (#67); perf-overlay corner/size test49/test50.
- Backlog (research-led): per-game profiles, on-screen text send, mic passthrough (protocol-gated),
  HDR tone-map toggle, custom resolution entry, connection retry/timeout tuning.

### Research-led candidate test PRs (queue; sourced from Moonlight/Sunshine 2025 feature set)
Ideas grounded in current Moonlight-Qt / Sunshine capabilities and handheld needs. Each is sized to
a single test PR; pick the next when continuing.
- **On-screen text-send** (extends test47 special-keys): a Quick Menu "type text" field → `LiSendUtf8TextEvent`.
  Mirrors Moonlight mobile's on-screen keyboard toolbar. Stacks on test22.
- **UI accent color choice (P3.9)**: let the user pick the Material accent (teal default) — read in
  main.cpp at startup. Launcher-verifiable.
- **Auto-reconnect on stream drop**: bounded retry when the connection drops mid-stream. Needs care
  around session teardown; medium risk.
- **Per-game stream profiles (P3.8)**: persist resolution/fps/bitrate/HDR per app id; the headline
  Android-parity gap. Larger; design the QSettings keying first.
- **Hardware-decode assurance hint**: warn in the launcher if software decoding is selected (decode
  latency ~8ms vs ~2ms hw) — pairs with existing videoDecoderSelection.
- **Low-latency profile toggle**: one-tap "competitive" preset (vsync off + frame pacing tuned).
  Builds on test23 presets.

---

## Why PR numbers "jump" phases (and aren't sequential per phase)
Test numbers are assigned in **creation order**, not phase order. Features were built
**opportunistically** — whatever was unblocked and high-value at the moment — and several phases were
interleaved (e.g. a Quick Menu content PR, then a video PR, then a UI PR). Some test numbers are also
**stacked** (a branch based on an earlier feature branch, e.g. test31→test25), so a later number can
depend on an earlier one regardless of phase. This is intentional and harmless: `TEST_CHECKLIST.md`
encodes the real dependency/verification order, and this file encodes the logical phase grouping.

## Why not all phases are "done" yet
The fast-moving ones (Quick Menu, video/scaling, input, onboarding, config, SteamOS scripts) are
implemented and awaiting hardware verification. The slower ones (P3.7 Tailscale remote play, P3.8
Android parity) are **gated on things the build host can't exercise** — a live remote/Tailscale
network and a formal parity spec. Per the plan above, the client-side parts of those are still being
implemented behind settings/flags with `// TODO(P3.x)` notes, and the hardware/remote-dependent
verification is deferred to the test agent (marked N/A until the environment exists) rather than
blocking the rest of the roadmap.
