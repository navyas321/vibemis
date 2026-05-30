# Vibemis — test checklist (features in development, not yet in `vibemis-main`/beta)

This is the **ordered queue** of feature test cycles awaiting hardware verification on the
Lenovo Legion Go S Z2. The `clienttest` agent works **top to bottom, one cycle at a time**:
check out the branch, run its `testing/<branch>/instructions.md`, file a report, tick the box.

**Legend:** ☐ = not verified yet · ☑ = verified PASS (report filed) · ✗ = verified FAIL (report filed, needs a fix)
Each row: order · branch · feature · PR · base · status. **Always verify `test22` first** — the
whole Quick Menu group depends on its render path.

> Keep this file the single source of truth for test order. When a cycle is verified, change ☐ →
> ☑ (or ✗) in the same commit as the report, and note the report path.

### ▶ START HERE (first time on the device)
1. `git fetch origin` (gets all `test*` branches + this checklist), then **read
   [`testing/BUILD_AGENT_INBOX.md`](BUILD_AGENT_INBOX.md)** for any priority changes / answers from
   the build agent (it may say SKIP/PRIORITIZE/RE-RUN a specific testN). On a feature branch, read
   `git show origin/vibemis-main:testing/BUILD_AGENT_INBOX.md` to get the latest.
2. **Smoke-test the tooling first:** `./testing/run-cycle.sh test52-selftest-cli` — it downloads the
   alpha, verifies md5, runs `selftest --json`, and captures a launch log. If that PASSes, the
   harness works and you can trust `selftest` for later cycles.
3. Then take the **topmost unchecked (☐) row whose deps are satisfied** (start with **test22** — it
   has a committed AppImage in `testing/test22-quickmenu-overlay/`). `run-cycle.sh <slug>` fetches
   the artifact for any row; then follow that row's `testing/<slug>/instructions.md` for the tiers.
4. **One cycle per session.** File `report.md`, tick the box here, open the report PR. Details below
   and in [`../docs/personas/test-agent.md`](../docs/personas/test-agent.md) +
   [`../docs/TEST_AUTOMATION.md`](../docs/TEST_AUTOMATION.md).

---

## 1. Quick Menu foundation + content (verify in this sub-order — the rest stack on test22)

- [ ] **test22** — Quick Menu renders in Game Mode (OverlayManager surface) — **PR #44** — base `vibemis-main` — ☐  *(FOUNDATION — do first)*
- [ ] **test29** — Quick Menu: Paste Clipboard — **PR #51** — base `test22` — ☐
- [ ] **test33** — Quick Menu: Stream Info — **PR #55** — base `test29` — ☐
- [ ] **test47** — Quick Menu: Send Special Keys (Ctrl+Alt+Del/Alt+F4/Super/Esc) — **PR #67** — base `test22` — ☐

## 2. Streaming quality / video

- [ ] **test23** — Vibepollo quality presets — **PR #45** — base `vibemis-main` — ☐
- [ ] **test24** — Compact performance overlay — **PR #46** — base `vibemis-main` — ☐
- [ ] **test25** — Video scale mode (Fit/Fill/Stretch) — **PR #47** — base `vibemis-main` — ☐
- [ ] **test31** — In-stream video zoom — **PR #53** — base `test25` — ☐
- [ ] **test32** — In-stream video pan — **PR #54** — base `test31` — ☐
- [ ] **test40** — Battery-saver bitrate — **PR #60** — base `vibemis-main` — ☐
- [x] **test53** — Settings performance-guidance advisories (sw-decode / high-bitrate) — **PR #73** — base `vibemis-main` — ☑ **PASS** (report on diagnostic/test53-perf-guidance-report; all 3 tiers, no false positives) → merged
- [x] **test59** — Data-usage estimate under the bitrate slider — **PR #79** — base `vibemis-main` — ☑ **PASS** (report PR #101; 9.0 GB/hr@20Mbps, 22.5@50Mbps — math verified) → merged
- [ ] **test62** — Adaptive bitrate (experimental) first slice (P3.12) — **PR #82** — base `vibemis-main` — ☐  *(Tier 1 launcher-only; Tier 2 needs a degrading stream — mark N/A otherwise)*
- [x] **test65** — AV1 codec guidance note (P3.6) — **PR #85** — base `vibemis-main` — ☑ **PASS** (report PR #103; AV1 note shows/hides on codec=AV1 vs Automatic, color #80A0C0, no Advanced-Settings regression) → merged
- [x] **test66** — Live stream-config summary line — **PR #86** — base `vibemis-main` — ☑ **PASS** (report PR #104; `▶ W×H @ fps · Mbps · codec` teal summary updates with config, no Basic-Settings regression) → merged
- [x] **test67** — Low-latency "competitive" preset button (P3.8) — **PR #87** — base `vibemis-main` — ☑ **PASS** (report PR #105; one tap clears V-Sync + frame pacing, persists to disk, V-Sync re-enable restores independent toggling) → merged
- [ ] **test68** — Native-resolution recommendation hint — **PR #88** — base `vibemis-main` — ✗→🔧 **FAIL, fix pushed — RE-TEST** (report PR #106: hint hidden because `maximumResolution` is the decoder max = (0,0) on >1080p devices; fix `f111363d` falls back to `Screen` panel size) — *(launcher only)*
- [ ] **test49** — Configurable performance-overlay corner (TL/TR/BL/BR) — **PR #69** — base `vibemis-main` — ☐  *(Tier 1 launcher-only; Tier 2 needs a stream — auto-publishes 🔬 alpha)*
- [ ] **test50** — Configurable performance-overlay text size (Small/Normal/Large) — **PR #70** — base `vibemis-main` — ☐  *(Tier 1 launcher-only; Tier 2 needs a stream — auto-publishes 🔬 alpha)*
- [ ] **test72** — Show clock in the performance overlay — **PR #98** — base `vibemis-main` — ☐  *(Tier 1 launcher-only; Tier 2 needs a stream)*

## 3. Input / controls

- [ ] **test26** — Configurable Quick Menu gamepad shortcut — **PR #48** — base `vibemis-main` — ☐
- [ ] **test36** — Back-paddle Quick Menu combos — **PR #56** — base `test26` — ☐
- [ ] **test57** — Disable controller rumble (P3.13) — **PR #77** — base `vibemis-main` — ☐  *(Tier 1 launcher-only; Tier 2 needs controller + stream)*
- [ ] **test64** — Motion-control (gyro) capability detection (P3.16) — **PR #84** — base `vibemis-main` — ☐  *(Tier 1 launcher-only; Tier 2 needs a controller)*

## 4. UI / onboarding

- [x] **test27** — Vibemis brand accent (teal/cyan) — **PR #49** — base `vibemis-main` — ☑ **PASS** (report PR #95; accent #00CCCC confirmed, dark theme intact, no regressions) → merged
- [x] **test28** — Tailscale hint in Add-PC dialog — **PR #50** — base `vibemis-main` — ☑ **PASS** (report PR #97; hint shows 100.x/MagicDNS, wraps cleanly, field works) → merged
- [ ] **test51** — Prefer Tailscale addresses for remote play (P3.7) — **PR #71** — base `vibemis-main` — ☐  *(Tier 1/2 launcher-only; Tier 3 needs a tailnet — mark N/A otherwise)*
- [x] **test69** ⭐**PRIORITY** — One-command Tailscale setup `scripts/setup-tailscale.sh` (P3.7) — **PR #89** — base `vibemis-main` — ☑ **PASS** (report PR #93; `bash -n` clean, `--check` safe, userspace fallback writes only to ~/.local) → merged. *(Tier 3 real-tailnet join = maintainer to confirm once.)*
- [ ] **test70** — In-app "Set up Tailscale" entry point in Settings (P3.7) — **PR #90** — base `vibemis-main` — ☐  *(launcher only; needs a browser)*
- [ ] **test37** — Settings "About" section — **PR #57** — base `vibemis-main` — ☐  *(launcher only)*
- [ ] **test39** — First-run welcome hint — **PR #59** — base `vibemis-main` — ☐  *(launcher only)*
- [ ] **test71** — Fix ALL-CAPS button labels (Material) — **PR #96** — base `vibemis-main` — ☐  *(launcher only; user-reported UI bug)*
- [ ] **test55** — System Information panel in Settings — **PR #75** — base `vibemis-main` — ☐  *(launcher only)*
- [ ] **test56** — Help & Links section in Settings (GitHub / README / Tailscale) — **PR #76** — base `vibemis-main` — ☐  *(launcher only; needs a browser)*
- [ ] **test58** — Show host software version in PC details (P3.13) — **PR #78** — base `vibemis-main` — ☐  *(launcher only; best with an online host)*
- [ ] **test60** — Per-client access level in PC context menu (P3.13) — **PR #80** — base `vibemis-main` — ☐  *(launcher only; best with a paired Apollo host)*
- [ ] **test61** — Virtual Display clarifying notes (P3.13) — **PR #81** — base `vibemis-main` — ☐  *(launcher only)*

## 5. Tooling / test automation

- [x] **test52** — `vibemis selftest` headless smoke test (automation enabler) — **PR #72** — base `vibemis-main` — ☑ **PASS** (report PR #91; SteamOS 3.8.5/Mesa 25.3.0; 5/5 checks, exit 0) → merged to vibemis-main
- [x] **test54** — `selftest --json` + settings round-trip checks — **PR #74** — base `test52` — ☑ **PASS** (report PR #92; 7/7 checks, valid JSON, non-destructive) → merged. Note: use `selftest --json 2>/dev/null` for pure JSON (hook/Qt warnings go to stderr).
- [ ] **test63** — Copy system info to clipboard — **PR #83** — base `test55` — ☐  *(launcher only; verify after test55)*

## 6. Config / SteamOS helpers

- [ ] **test41** — Settings export / import — **PR #61** — base `vibemis-main` — ☐  *(launcher only)*
- [x] **test48** — SteamOS helper scripts bundle (install / update / add-game / add-all / pair / uninstall / doctor) — **PR #68** — base `vibemis-main` — ☑ **PASS** (report PR #94; all 7 scripts clean, sudo-free, $HOME-scoped) → merged. Follow-up: fixed `vibemis-doctor.sh` settings-path check.

---

## How the test agent should work this list (also in docs/personas/test-agent.md)

1. **Pick the topmost unchecked (☐) item** whose dependencies are satisfied. Start at the top;
   never start a `base test22` item before test22 itself is ☑.
2. `git fetch origin <branch> && git checkout <branch>` (the branch column), then follow
   `testing/<branch>/instructions.md` exactly. Get the AppImage from the branch's committed
   `testing/<branch>/*.AppImage`, **or** download the branch's 🔬 alpha pre-release from
   GitHub Releases (newer test cycles auto-publish one).
3. Run the cycle's tiers; write `testing/<branch>/report.md` (TL;DR table → per-tier → recommendation).
4. **Update this checklist**: change that row's ☐ to ☑ (PASS) or ✗ (FAIL) and add the report path,
   committed on the `diagnostic/<branch>-report` branch alongside the report; open the report PR.
5. Do **one** cycle per session unless asked otherwise. Move to the next ☐ item next time.
6. If a row is ✗, the build agent fixes it and re-pushes the same testN; re-run that row before moving on.

Launcher-only rows (no stream/host) are the safest to knock out quickly if a host isn't available.

### Batching (why the cycles are NOT merged into fewer PRs)
The branches are deliberately kept **separate** — they are not combined into mega-PRs. Merging them
would (a) collide (many edit `streamingpreferences`/`SettingsView` at the same anchors) and (b) lose
per-feature regression isolation (a combined failure is ambiguous). Sequential, one-branch-at-a-time
verification stays the rule.

**But you may batch the *launcher-only* cycles in a single session** (they need no host/stream):
run several in a row with `testing/run-cycle.sh <branch>` + their Tier-1 checks, then file each
report (or one combined report that ticks several rows, clearly per-cycle). Stream-required tiers
(marked "needs a stream/controller/tailnet") stay one-at-a-time when a host is available.
Rough split today: **launcher-only** (batchable) = test27/28/37/39/41/48/49/50/52/53/54/55/56/58/59/
60/61/62/63/64; **needs host/controller/stream** = test22/23/24/25/26/29/31/32/33/36/40/47/51/57
(+ the Tier-2/3 of several launcher-only ones).
