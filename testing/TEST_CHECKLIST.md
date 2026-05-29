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
1. `git fetch origin` (gets all `test*` branches + this checklist).
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
- [ ] **test53** — Settings performance-guidance advisories (sw-decode / high-bitrate) — **PR #73** — base `vibemis-main` — ☐  *(launcher only)*
- [ ] **test59** — Data-usage estimate under the bitrate slider — **PR #79** — base `vibemis-main` — ☐  *(launcher only)*
- [ ] **test49** — Configurable performance-overlay corner (TL/TR/BL/BR) — **PR #69** — base `vibemis-main` — ☐  *(Tier 1 launcher-only; Tier 2 needs a stream — auto-publishes 🔬 alpha)*
- [ ] **test50** — Configurable performance-overlay text size (Small/Normal/Large) — **PR #70** — base `vibemis-main` — ☐  *(Tier 1 launcher-only; Tier 2 needs a stream — auto-publishes 🔬 alpha)*

## 3. Input / controls

- [ ] **test26** — Configurable Quick Menu gamepad shortcut — **PR #48** — base `vibemis-main` — ☐
- [ ] **test36** — Back-paddle Quick Menu combos — **PR #56** — base `test26` — ☐
- [ ] **test57** — Disable controller rumble (P3.13) — **PR #77** — base `vibemis-main` — ☐  *(Tier 1 launcher-only; Tier 2 needs controller + stream)*

## 4. UI / onboarding

- [ ] **test27** — Vibemis brand accent (teal/cyan) — **PR #49** — base `vibemis-main` — ☐  *(launcher only, no stream)*
- [ ] **test28** — Tailscale hint in Add-PC dialog — **PR #50** — base `vibemis-main` — ☐  *(launcher only)*
- [ ] **test51** — Prefer Tailscale addresses for remote play (P3.7) — **PR #71** — base `vibemis-main` — ☐  *(Tier 1/2 launcher-only; Tier 3 needs a tailnet — mark N/A otherwise)*
- [ ] **test37** — Settings "About" section — **PR #57** — base `vibemis-main` — ☐  *(launcher only)*
- [ ] **test39** — First-run welcome hint — **PR #59** — base `vibemis-main` — ☐  *(launcher only)*
- [ ] **test55** — System Information panel in Settings — **PR #75** — base `vibemis-main` — ☐  *(launcher only)*
- [ ] **test56** — Help & Links section in Settings (GitHub / README / Tailscale) — **PR #76** — base `vibemis-main` — ☐  *(launcher only; needs a browser)*
- [ ] **test58** — Show host software version in PC details (P3.13) — **PR #78** — base `vibemis-main` — ☐  *(launcher only; best with an online host)*

## 5. Tooling / test automation

- [ ] **test52** — `vibemis selftest` headless smoke test (automation enabler) — **PR #72** — base `vibemis-main` — ☐  *(launcher-only / headless; do this FIRST each visit — see docs/TEST_AUTOMATION.md)*
- [ ] **test54** — `selftest --json` + settings round-trip checks — **PR #74** — base `test52` — ☐  *(launcher-only / headless; verify after test52)*

## 6. Config / SteamOS helpers

- [ ] **test41** — Settings export / import — **PR #61** — base `vibemis-main` — ☐  *(launcher only)*
- [ ] **test48** — SteamOS helper scripts bundle (install / update / add-game / add-all / pair / uninstall / doctor) — **PR #68** — base `vibemis-main` — ☐  *(script-only)*

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
