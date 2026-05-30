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
- **Stretch (absorbed former P3.15):** a custom-overlay plug-in hook (user clock/battery/text
  overlays) on the OverlayManager surface — revisit only after the test22 Quick Menu stack is
  hardware-verified.

## P3.6 — Display / scaling / codec / renderer  ✅ mostly implemented  (absorbed former P3.14)
- Done: compact overlay test24 (#46); scale mode test25 (#47); zoom test31 (#53); pan test32 (#54);
  perf-overlay corner test49 (#69); perf-overlay text size test50 (#70); data-usage estimate
  test59 (#79); software-decode advisory test53 (#73).
- **Codec/renderer (merged from P3.14), remaining:** clearer "Prefer AV1 (if host supports)" UX
  (`VCC_FORCE_AV1` already exists); validate the Vulkan video-decode + HDR path (`RB_VULKAN`) on the
  Legion Go S Z2 and document when to prefer it over EGL (device-gated — needs the test agent).

## Phase 4 / Input  ✅ implemented
- Done: configurable QM gamepad combo test26 (#48); back-paddle combos test36 (#56).

## P3.7 — Tailscale remote play  🟢 core complete
- Done: Add-PC Tailscale hint test28 (#50); prefer-tailnet-address ordering test51 (#71, +IPv6 fix);
  **one-command setup `scripts/setup-tailscale.sh` test69 (#89)** — install/up with a single login,
  no-sudo userspace fallback for SteamOS, `--check` status mode. Set up → prefer address → stream.
- Remaining (nice-to-have): an in-app "Set up Tailscale" button that shells out to the script /
  shows `--check` status; a short remote-play how-to doc.
- Remaining: prefer Tailscale (100.64.0.0/10 CGNAT) addresses when reaching a host; MagicDNS name
  support; a "remote play over Tailscale" doc.
- BLOCKER: can't validate NAT traversal / real remote latency without a live Tailscale network +
  remote host (test-agent hardware is LAN-only right now). **Plan:** implement the client-side
  address-preference logic behind a setting, mark the path with `// TODO(P3.7)`, and ship it as its
  own test PR with a launcher-only Tier-1 (setting persists) + a "needs remote network" Tier-2 the
  test agent marks N/A until a remote host exists.

## P3.8 — Feature parity & researched features  🟢 ongoing  (absorbed former P3.11)
The combined backlog for Android-parity gaps and research-led new features (the two overlapped
heavily, so they're now one phase).
- **Done (researched features):** battery-saver bitrate test40 (#60); settings export/import
  test41 (#61); special keys test47 (#67); perf-overlay corner/size test49/50; data estimate
  test59; adaptive-bitrate slice test62.
- **Backlog / parity gaps (pick the next as a single test PR):**
  - **Per-game stream profiles** — persist resolution/fps/bitrate/HDR per app id, applied at launch.
    The headline Android-parity gap. Larger; design the QSettings keying first.
  - **On-screen text-send** — Quick Menu "type text" field → `LiSendUtf8TextEvent` (stacks on test22).
  - **Auto-reconnect on stream drop** — bounded retry; medium risk (session teardown).
  - **Low-latency "competitive" preset** — vsync off + frame pacing tuned (builds on test23 presets).
  - On-screen touch controls overlay; richer gamepad-mapping UI; mic passthrough (protocol-gated);
    HDR tone-map toggle; custom resolution entry.
- BLOCKER (parity audit): no formal Android feature spec yet — confirm gaps against Artemis-Android
  before deep work; the launcher-verifiable items above can proceed now.

## P3.9 — UI modernization (Material)  🟡 partial  → elevated into **P3.17**
- Done: brand accent test27 (#49); About section test37 (#57); first-run hint test39 (#59).
- Remaining: consistent Material control styling pass, spacing/typography, dark-theme polish —
  **this remaining work is now folded into the deliberate design pass of P3.17 below** (step 3).
- Not blocked — large, so done incrementally as small test PRs.

## P3.10 — SteamOS one-click integration  🟡 partial
- Done: helper scripts bundle test48 (#68) — install / update / add-to-steam / add-all / pair /
  uninstall / doctor.
- Remaining: a single guided "one-click" flow (download → install → add to Steam) and a `.desktop`
  polish for Desktop Mode.
- Not blocked.

## P3.12 — Adaptive bitrate (network-aware)  🔵 NEW (research-led)
On the upstream Moonlight-Qt roadmap ("adaptive bit-rate"). Dynamically lower/raise the requested
bitrate in response to observed packet loss / queue depth during a stream, instead of a fixed value.
- **Value:** the single biggest quality win on flaky Wi-Fi / remote (Tailscale) — fewer stutters.
- **Approach:** read the per-frame network stats already surfaced in `ffmpeg.cpp`/connection
  callbacks; when sustained loss exceeds a threshold, step bitrate down (and recover slowly). Gate
  behind a setting `adaptiveBitrate` (default off initially).
- **BLOCKER / risk:** touches the live streaming/control path; correctness needs real network
  conditions to validate. Start with a **client-side estimator + setting + `// TODO(P3.12)`** and a
  conservative step policy; full tuning deferred to on-device testing.
- **Done (first slice):** test62 (#82) — `adaptiveBitrate` setting + a `CONN_STATUS_POOR`
  observation log in `Session::clConnectionStatusUpdate`. Runtime bitrate stepping remains
  `TODO(P3.12)` (gated on moonlight-common-c runtime-bitrate support).

## P3.13 — Apollo-aware client features  🟡 NEW (research-led, in progress)
Apollo (our host) has capabilities mainline Sunshine lacks; surface/expose them client-side.
- **Done:** suppress controller rumble (test57); host software version in PC details (test58);
  per-client **permission level** in the PC context menu (test60); **virtual-display
  resolution-match** clarifying notes (test61).
- **Remaining:** optional **per-app save-sync** awareness (Apollo host feature — document it in
  the host details / a help note). Largely complete otherwise.
- Sources: Apollo README + XDA Apollo coverage (see bottom).

## P3.14 / P3.15 — merged (plan pruned)
- **P3.14 (codec/renderer)** → folded into **P3.6** above.
- **P3.15 (custom overlay plug-in API)** → folded into **P3.4** as a post-verification stretch
  goal (it builds directly on the test22 OverlayManager surface + Quick Menu).

## P3.16 — Motion (gyro) & touch passthrough  🔵 NEW (research-led)
Actively-requested Moonlight-Qt handheld feature (issues #960, #1123): forward the handheld's
**gyro/accelerometer** and **touchscreen** to the host so the client acts like a DS4 (gyro aim,
touchpad). High value on the Legion Go S Z2 (it has a gyro + touchscreen) and a clear differentiator.
- **Approach:** SDL exposes `SDL_CONTROLLER_SENSOR_GYRO/ACCEL` (via `SDL_GameControllerGetSensorData`)
  and touch events; moonlight-common-c exposes `LiSendControllerMotionEvent` / `LiSendTouchEvent`
  (ClassicOldSong's fork — verify symbols). Gate behind a setting `forwardMotionControls`.
- **BLOCKER / risk:** touches the input hot path; needs the host (Apollo/Sunshine) to map the client
  as a DS4-with-sensors, and real hardware to validate. **Plan:** first slice = the setting +
  capability detection (does this controller report a gyro?) surfaced in System Info / a log line,
  with `// TODO(P3.16)` at the send site; wire the actual sensor forwarding after the symbols and
  host behaviour are confirmed on-device.
- Sources: moonlight-qt issues #960 / #1123; Moonlight-Switch gyro-as-DS4.

## P3.17 — UI/UX design overhaul (Claude-assisted)  🔵 NEW — near-term priority
A deliberate, cohesive **design pass on the whole client** — not the incremental Material tidying of
P3.9, but a from-the-top visual/UX redesign using **Claude's design tooling (design credits)** to
generate a consistent visual language + per-screen mockups, then implementing the result in QML.
- **Why now:** the feature set grew fast (Quick Menu, overlays, several Settings panels, Tailscale
  setup, onboarding). The surfaces are *functional* but visually inconsistent (spacing, typography,
  color usage, empty/loading states). A coherent design pass compounds the value of everything
  already shipped and is the highest-leverage UX work available.
- **Approach:**
  1. **Audit** — screenshot every current screen (Computers grid, Add-PC, Settings + each panel,
     Quick Menu overlay, first-run/onboarding, perf overlay) and list the inconsistencies.
  2. **Design (Claude design credits)** — generate a cohesive visual language: a color + spacing +
     type scale, component states, handheld-first layouts for **both Game Mode (Gamescope) and
     Desktop Mode**, light/dark. Anchor on the existing Vibemis teal accent **#00CCCC** (test27).
     Produce per-screen mockups to implement against.
  3. **Implement incrementally** as **launcher-only `test<N>` PRs** (one screen/component per PR so
     the test agent verifies each with no host needed): **Settings first** (largest surface area),
     then the **Computers/Add-PC home**, then **onboarding/first-run**, then the **Quick Menu
     overlay**. (This step *absorbs P3.9's* remaining "consistent Material styling pass".)
  4. **Accessibility / handheld ergonomics** — minimum touch-target sizes, controller-focus
     navigation order, readable-at-arm's-length type; final sign-off on the Legion Go S Z2.
- **Sequence:** slot **right after the current launcher-only verification wave clears** — it produces
  more launcher-only PRs, the cheap-to-verify lane the test agent is fastest at, so the two pipelines
  reinforce each other.
- **Not blocked:** mockups + most implementation are launcher-verifiable; only the final
  Game-Mode ergonomics sign-off needs the device.

## P4.0 — Repo hygiene (DEFERRED to post-1.0 / first stable release)  ⏸️
Hide the Claude/agent development files from GitHub. **Decision: deferred** until after the first
stable release — do NOT start early. Recommended approach when we do it: **two-repo split** — keep
the code repo public (so Releases/AppImages stay downloadable) and move all agent meta (CLAUDE.md,
docs/personas, docs/ROUTINE_PROMPT.md, docs/WORKFLOW.md, docs/PHASE_STATUS.md, testing/*) into a
separate private repo that the agents also clone. Alternatives considered: private-dev + public
release mirror; cosmetic rename + trailer strip; authorship-only history scrub (git-filter-repo).

## P3.11 — merged into P3.8
"Newer researched features" overlapped P3.8 (Android parity) — the two are now the single combined
backlog under **P3.8** above. (Hardware-decode hint shipped as test53; UI accent stays under P3.9.)

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
