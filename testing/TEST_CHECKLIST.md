# Vibemis — test checklist (features in development, not yet in `vibemis-main`/beta)

This is the **ordered queue** of feature test cycles awaiting hardware verification on the
Lenovo Legion Go S Z2. The `clienttest` agent works **top to bottom, one cycle at a time**:
check out the branch, run its `testing/<branch>/instructions.md`, file a report, tick the box.

**Legend:** ☐ = not verified yet · ☑ = verified PASS (report filed) · ✗ = verified FAIL (report filed, needs a fix)
Each row: order · branch · feature · PR · base · status. **Always verify `test22` first** — the
whole Quick Menu group depends on its render path.

> Keep this file the single source of truth for test order. When a cycle is verified, change ☐ →
> ☑ (or ✗) in the same commit as the report, and note the report path.

> **Build-tier rule (BL-2016):** every cycle here runs against an **alpha** (`testNN`-branch
> build). The test agent never validates betas/RCs — those are cut from already-tested alphas
> and belong to the maintainer's manual-testing tier.

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
5. **Tear down everything you start on the host.** Any Server Command / app / prep-cmd a check
   launches on the host must have a Teardown step in the instructions and a teardown line in the
   report; missing teardown = report-worthy defect. (Bubbles left running kept the host display
   awake for days — BL-1811 / BL-1821. The host-side Bubbles command is now a ~15 s
   self-terminating wrapper; do not regress it to a bare `bubbles.scr`.)

---

## 0. ⭐ ACTIVE PRIORITY — Quick Menu freeze diagnosis + fix (blocks group 1)

- [x] **test75** — Quick Menu FREEZE repro (diagnostic-only) — ☑ **DONE — root cause found**
  (report PR #142: NOT a global freeze; keyboard path passes in-stream under gamescope emulation.
  Real defect = no gamepad close/return: Back/Select swallowed unmapped, only B closes, hint
  keyboard-only; plus the open-combo left stuck buttons on the host. Fix shipped as **test77**.)
- [x] **test77** — Quick Menu gamepad close/return-to-game — **PR #144** — ☑ **PASS** (report
  PR #145: verified in-stream under gamescope emulation — "Resume Game (Ⓑ / Back / Esc)" hint,
  Esc/Back close+resume, submenu Esc→main, exactly 1 combo-detect per open, 0 coredumps; physical-
  controller Game Mode pass optional follow-up) → **merged**, ships in 0.7.1-beta. **Unblocks
  test29/33/47 (rebase onto the fix before verifying).**

## 1. Quick Menu foundation + content (verify in this sub-order — the rest stack on test22)

- [x] **test22** — Quick Menu renders in Game Mode (OverlayManager surface) — **PR #44** — base `vibemis-main` — ☑ **PASS (streaming-verified!)** (report PR #138; Quick Menu opens via `Ctrl+Alt+Shift+\` as a true in-stream overlay (offscreen OverlayManager surface, not a separate window), keyboard nav + clean teardown; first stream-verified cycle) → merged. **Unblocks test29/33/47.** Host-side Virtual Display bug noted (Apollo `0x80030023`, not a client defect).
- [x] **test29** — Quick Menu: Paste Clipboard — **PR #51** — ☑ **PASS (source)** (report PR #163; merged 0.11.3+; runtime toast/paste → ledger)
- [x] **test33** — Quick Menu: Stream Info — **PR #55** — ☑ **PASS (source)** (report PR #163; merged; runtime toast → ledger)
- [x] **test47** — Quick Menu: Send Special Keys — **PR #67** — ☑ **PASS (source)** (report PR #163; merged; runtime pass → ledger)

> ⚠️ **Stale alphas:** the May 🔬 alphas for all unchecked rows below (and test29/33/47 above) were
> pruned from Releases. The build agent is re-dispatching CI per branch — if `run-cycle.sh` can't
> find a branch's alpha, ping the bus and take the next row that has one. test29/33/47 rebuild
> AFTER test77 merges (they'll be rebased onto the fix).

## 2. Streaming quality / video

- [x] **test23** — Vibepollo quality presets — **PR #45** — ☑ **PASS (source, #165)** → merged; runtime → ledger
- [x] **test24** — Compact performance overlay — **PR #46** — ☑ **PASS (source, #165)** → merged
- [x] **test25** — Video scale mode — **PR #47** — ☑ **PASS (source, #165)** → merged
- [x] **test31** — In-stream video zoom — **PR #53** — ☑ **PASS (source, #165)** → merged
- [x] **test32** — In-stream video pan — **PR #54** — ☑ **PASS (source, #165)** → merged
- [x] **test40** — Battery-saver bitrate — **PR #60** — ☑ **PASS (source, #165)** → merged
- [x] **test53** — Settings performance-guidance advisories (sw-decode / high-bitrate) — **PR #73** — base `vibemis-main` — ☑ **PASS** (report on diagnostic/test53-perf-guidance-report; all 3 tiers, no false positives) → merged
- [x] **test59** — Data-usage estimate under the bitrate slider — **PR #79** — base `vibemis-main` — ☑ **PASS** (report PR #101; 9.0 GB/hr@20Mbps, 22.5@50Mbps — math verified) → merged
- [x] **test62** — Adaptive bitrate (experimental) first slice (P3.12) — **PR #82** — base `vibemis-main` — ☑ **PASS (Tier 1)** (report PR #107; checkbox visible + default off + persists; Tiers 2/3 N/A — need a degrading stream, re-check later) → merged. Note: QSettings may skip writing `adaptivebitrate` when false/default — read path verified, harmless.
- [x] **test65** — AV1 codec guidance note (P3.6) — **PR #85** — base `vibemis-main` — ☑ **PASS** (report PR #103; AV1 note shows/hides on codec=AV1 vs Automatic, color #80A0C0, no Advanced-Settings regression) → merged
- [x] **test66** — Live stream-config summary line — **PR #86** — base `vibemis-main` — ☑ **PASS** (report PR #104; `▶ W×H @ fps · Mbps · codec` teal summary updates with config, no Basic-Settings regression) → merged
- [x] **test67** — Low-latency "competitive" preset button (P3.8) — **PR #87** — base `vibemis-main` — ☑ **PASS** (report PR #105; one tap clears V-Sync + frame pacing, persists to disk, V-Sync re-enable restores independent toggling) → merged
- [x] **test68** — Native-resolution recommendation hint — **PR #88** — base `vibemis-main` — ☑ **PASS** (FAIL→fixed→re-test PASS, report PR #113; hint now reads 1920×1200 via `Screen` fallback — decoder max was (0,0) on this >1080p device; fix `f111363d`) → merged *(launcher only)*
- [x] **test49** — Configurable performance-overlay corner (TL/TR/BL/BR) — **PR #69** — base `vibemis-main` — ☑ **PASS (Tier 1)** (report PR #110; dropdown shows all 4 corners, default Top-left, `perfoverlayposition=3` read from config; Tier 2 corner-render-during-stream N/A → ledger) → merged. Minor: position combo truncates to "Bott" at narrow width — fold into P3.17 Settings restyle.
- [x] **test50** — Configurable performance-overlay text size (Small/Normal/Large) — **PR #70** — base `vibemis-main` — ☑ **PASS (Tier 1)** (report PR #111; dropdown lists Small/Normal/Large, default Normal, `perfoverlaytextsize=2` read from config; Tier 2 in-stream-render N/A → ledger) → merged. Minor: combo truncates to "Larg" — fold into P3.17 Settings restyle.
- [x] **test72** — Show clock in the performance overlay — **PR #98** — base `vibemis-main` — ☑ **PASS (Tier 1)** (report PR #114; clock checkbox renders, greys out when perf-stats off, `perfoverlayclock` persists, selftest 7/7; Tier 2 in-stream clock N/A → ledger) → merged

## 3. Input / controls

- [x] **test26** — Configurable Quick Menu shortcut — **PR #48** — ☑ **PASS (source, #165)** → merged
- [ ] **test36** — Back-paddle Quick Menu combos — **PR #56** — ☐ (stacks on test26; re-sync + verify)
- [x] **test57** — Disable controller rumble (P3.13) — **PR #77** — base `vibemis-main` — ☑ **PASS (Tier 1)** (report PR #112; toggle in Gamepad Settings, default OFF, `suppresscontrollerrumble` persists; Tier 2 in-stream suppression N/A → ledger) → merged
- [x] **test64** — Motion-control (gyro) capability detection (P3.16) — **PR #84** — base `vibemis-main` — ☑ **PASS (Tier 1)** (report PR #116; gyro toggle renders in Gamepad Settings, `forwardmotioncontrols` persists; Tier 2 `[motion]` log needs a controller/Game Mode → ledger) → merged. ⚠ Report also flagged a **pre-existing mDNS auto-exit bug** (tracked separately).

## 4. UI / onboarding

- [x] **test27** — Vibemis brand accent (teal/cyan) — **PR #49** — base `vibemis-main` — ☑ **PASS** (report PR #95; accent #00CCCC confirmed, dark theme intact, no regressions) → merged
- [x] **test28** — Tailscale hint in Add-PC dialog — **PR #50** — base `vibemis-main` — ☑ **PASS** (report PR #97; hint shows 100.x/MagicDNS, wraps cleanly, field works) → merged
- [x] **test51** — Prefer Tailscale addresses for remote play (P3.7) — **PR #71** — base `vibemis-main` — ☑ **PASS (Tier 1+2)** (report PR #126; default off, persists, LAN unaffected; Tier 3 real-tailnet stream N/A → ledger) → merged
- [x] **test69** ⭐**PRIORITY** — One-command Tailscale setup `scripts/setup-tailscale.sh` (P3.7) — **PR #89** — base `vibemis-main` — ☑ **PASS** (report PR #93; `bash -n` clean, `--check` safe, userspace fallback writes only to ~/.local) → merged. *(Tier 3 real-tailnet join = maintainer to confirm once.)*
- [x] **test70** — In-app "Set up Tailscale" entry point in Settings (P3.7) — **PR #90** — base `vibemis-main` — ☑ **PASS** (report PR #127; both buttons render, hasBrowser gate works, URLs correct; browser-open → ledger) → merged
- [x] **test37** — Settings "About" section — **PR #57** — base `vibemis-main` — ☑ **PASS** (report PR #117; teal "About" header, "Vibemis 0.6.7", description, github.com/navyas321/vibemis link; no regression) → merged
- [x] **test39** — First-run welcome hint — **PR #59** — base `vibemis-main` — ☑ **PASS** (report PR #118; "Welcome to Vibemis!" dialog with 3 onboarding tips shows once, dismisses cleanly, `seenwelcomehint` persists so it doesn't reappear; no regression) → merged
- [x] **test71** — Fix ALL-CAPS button labels (Material) — **PR #96** — base `vibemis-main` — ☑ **PASS** (report PR #119; **user-reported bug FIXED** — bitrate button now "Use Default (32 Mbps)" not "USE DEFAULT (32 MBPS)"; app-wide `QFont::MixedCase`, no styling regression) → merged
- [x] **test73** — Design-system `Theme` token singleton (P3.17) — **PR #108** — base `vibemis-main` — ☑ **PASS** (report PR #120; Theme singleton resolves — selftest 7/7, zero Theme QML errors, version label renders #00CCCC confirmed by pixel analysis) → merged. **P3.17 foundation landed.**
- [x] **test55** — System Information panel in Settings — **PR #75** — base `vibemis-main` — ☑ **PASS** (report PR #121; all 7 rows populated + correct — arch x86_64, SteamOS, VAAPI, HDR enabled, 1920×1200; no regression) → merged. *(Unblocks test63.)*
- [x] **test56** — Help & Links section in Settings (GitHub / README / Tailscale) — **PR #76** — base `vibemis-main` — ☑ **PASS** (report PR #122; Help & Links GroupBox + all 3 buttons render, `hasBrowser` gate works (xdg-open present); Tier 2 actual link-open N/A — screen capture failed mid-test → ledger) → merged
- [x] **test58** — Show host software version in PC details (P3.13) — **PR #78** — base `vibemis-main` — ☑ **PASS*** (report PR #123; logic verified — Navid-PC `appversion 7.1.431.-1` → "Host Software Version: 7.1.431.-1", graceful when empty, no regression. *Visual dialog confirmation blocked by device screen-lock → ledger.) → merged
- [x] **test60** — Per-client access level in PC context menu (P3.13) — **PR #80** — base `vibemis-main` — ☑ **PASS*** (report PR #124; server→model→QML pipeline confirmed via log/source; context-menu visual deferred — screen-lock) → merged
- [x] **test61** — Virtual Display clarifying notes (P3.13) — **PR #81** — base `vibemis-main` — ☑ **PASS** (report PR #125; both contextual notes display, mutually exclusive, layout intact) → merged

## 5. Tooling / test automation

- [x] **test52** — `vibemis selftest` headless smoke test (automation enabler) — **PR #72** — base `vibemis-main` — ☑ **PASS** (report PR #91; SteamOS 3.8.5/Mesa 25.3.0; 5/5 checks, exit 0) → merged to vibemis-main
- [x] **test54** — `selftest --json` + settings round-trip checks — **PR #74** — base `test52` — ☑ **PASS** (report PR #92; 7/7 checks, valid JSON, non-destructive) → merged. Note: use `selftest --json 2>/dev/null` for pure JSON (hook/Qt warnings go to stderr).
- [x] **test63** — Copy system info to clipboard — **PR #83** — base `test55` — ☑ **PASS** (report PR #128; "Copy to clipboard" → "Copied!" flash, all 7 fields copied, reverts after 1500ms) → merged. Note: "Max resolution: 0×0" under XWayland (same `maximumResolution` quirk as test68) — follow-up: apply Screen fallback to the System-Info row too.

## 5b. Parity features (P3.8)

- [x] **test76** — Per-game stream profiles — **PR #143** — ☑ **PARTIAL→merged with maintainer
  approval** (report PR #146: selftest PASS + full wiring source-confirmed; runtime context-menu
  CRUD not drivable headlessly — harness limit, no code defect) → **merged**, ships in 0.8.0-beta.
- [ ] **test76-followup** — Per-game profiles on-device runtime pass *(2 min, needs the physical
  device/controller)*: open a game tile's menu → Save profile → `grep appprofiles` conf → stream
  applies profile (log line + negotiated shape) → Clear — ☐

## 5b2. UI / design system (P3.19)

- [ ] **test79** — Theme-token migration wave 1 (PcView + AppView + Material bridge) — **PR #149**
  — base `vibemis-main` — ☐ (launcher-only screenshot diff vs your audit zip;
  `testing/test79-theme-wave1/instructions.md`; auto-merges on green CI — report = post-merge gate)

## 5b4. Input / handheld (P3.22)

- [ ] **test82** — Motion forwarding slice 2: gate gyro/accel enablement on the setting — **PR #157**
  (auto-merges) — ☐ device-gated Tier 2 (`testing/test82-motion-forward/instructions.md`)

## 5b3. Streaming resilience (P3.21)

- [ ] **test80** — Auto-reconnect on unexpected stream drop (3 attempts, backoff; setting default
  OFF) — **PR #153** (auto-merges) — ☐ (`testing/test80-auto-reconnect/instructions.md`)

## 5b5. Quick Menu — parity (P3.20)

- [ ] **test86** — On-screen text-send (Type Text → LiSendUtf8TextEvent) — **PR #164** merged 0.12.0
  — ☐ launcher/source PASS; in-stream typing→host on the Deferred ledger.

## 5b6. UI / scaling (P3.6)

- [ ] **test109** — Gamescope High-DPI UI scaling fix — base `vibemis-main` — ☐ (`testing/test109-gamescope-scaling/instructions.md`)

## 5c. CLI

- [x] **test78** — CLI app seek fix — **PR #148** — ☑ **PASS** (report PR #150: all 4 headless CLI
  cases on the real host — exact, substring, not-found w/ app list, ambiguity) → merged; zero-width
  app-name sanitization follow-up shipped in test81.
- [x] **test81** — repo-review fix wave — **PR #152** — ☑ **PASS** (report PR #156 on real Apollo
  host: Server Commands revived (lists "Bubbles", no Command-not-found), TLS private-key export leak
  gone, renderer-swap race stable 17×8 toggles / 0 coredumps) → merged, 0.10.1. Tier-2 controller +
  Settings-UAF nav deferred (headless-harness gaps).

## 6. Config / SteamOS helpers

- [x] **test41** — Settings export / import — **PR #61** — base `vibemis-main` — ☑ **PASS** (report PR #129; export+import work end-to-end, import restores via reload(), status messages correct) → merged
- [x] **test48** — SteamOS helper scripts bundle (install / update / add-game / add-all / pair / uninstall / doctor) — **PR #68** — base `vibemis-main` — ☑ **PASS** (report PR #94; all 7 scripts clean, sudo-free, $HOME-scoped) → merged. Follow-up: fixed `vibemis-doctor.sh` settings-path check.
- [x] **test74** — Guided one-command setup `scripts/vibemis-setup.sh` (P3.10) — **PR #109** — base `vibemis-main` — ☑ **PASS (Tier 1)** (report PR #130; bash -n clean, --help/--dry-run correct, bad-option exit 2, no unsafe shell patterns; Tier 2/3 → ledger) → merged

---

## ⏸ Deferred verification ledger (merged on a launcher tier — runtime tier still UNVERIFIED)

Some features were **merged after only their launcher-only tier passed** because the remaining tier
needs hardware/environment the test device doesn't have in a normal session (a live host, a
*degrading* network, a second controller, a real tailnet). Those features are safe to ship in the
meantime (default-off settings / observation-only / non-destructive), but their runtime behavior is
**not yet verified**. This is the standing queue to clear **when the right environment is available** —
ticking a row above does NOT clear its entry here.

> **Test agent:** whenever a host / degrading-network / controller / tailnet *is* available, work this
> ledger in addition to the normal queue. File a short follow-up report and check the box here.
> **Build agent:** when you merge a Tier-1-only PASS that has an N/A runtime tier, ADD a row here
> (don't just close the report).

- [ ] **test80** — auto-reconnect, Tier 1–2 — with a **drop lever** (host-side stream bounce or
  client Wi-Fi drop), confirm the 3-attempt in-place reconnect + backoff + final give-up-to-grid
  (setting default-off). Build side source-verified; needs a real mid-stream drop.
- [ ] **test82** — motion forwarding, Tier 2 — with a **gyro/accel controller in Game Mode** + a host
  that requests motion, confirm live gyro/accel reaches the host and honours the report rate (source-
  confirmed by report PR #162; default-off = safe).
- [x] ☑ **BL-1528 (P3.23)** — touchscreen passthrough, on-device — **PASS (real-usage), test119**
  (2026-07-16): dense pointer-id slots fixed it — taps INK at the exact mapped point and the
  maintainer's real-finger freehand strokes DRAW continuously through the stream (264 moves @~90Hz,
  slots 0/1 multi-finger clean, touchpad-emu negative holds). Residual (non-blocking, upstream
  Vibepollo note): slow *synthetic* drags with sparse/irregular updates can drop mid-gesture
  contact in the forwarding path — real fingers unaffected
  (`testing/test119-pointer-slots/report.md`; evidence chain test116 → BL-2015 → test119).
- [ ] **test62** — Adaptive bitrate, Tiers 2–3 — on a **degrading stream**, confirm the
  `[adaptive-bitrate]` recommendation is logged on `CONN_STATUS_POOR` and no regression to the
  slow-connection overlay. *(Note: runtime bitrate-stepping itself is still `TODO(P3.12)` — only the
  observation log is in.)*
- [ ] **test69** — Tailscale setup, Tier 3 — on a **real tailnet**, run `scripts/setup-tailscale.sh`
  end-to-end (login URL → join → `--check` shows `up` → reach a host by its 100.x IP). Maintainer
  may do this once.
- [ ] **test51** *(when merged)* — prefer-Tailscale ordering, Tier 3 — actually stream to a host over
  the tailnet (not just verify the address-ordering logic launcher-side).
- [ ] **test74** *(when merged)* — guided setup, Tier 3 — run `scripts/vibemis-setup.sh --host <host>`
  end-to-end on a real host (install → pair via PIN → add-all-games creates launchers). Maintainer can
  do this once when a host is on hand.
- [ ] **test49** — perf-overlay position, Tier 2 — during a **live stream**, confirm the overlay
  actually renders in the selected corner (TL/TR/BL/BR) and moves when the setting changes.
- [ ] **test50** — perf-overlay text size, Tier 2 — during a **live stream**, confirm the overlay
  text actually renders at the chosen size (Small/Normal/Large).
- [ ] **test57** — disable controller rumble, Tier 2 — with a **rumble-capable controller + live
  stream**, confirm rumble is actually suppressed when the toggle is on (and works when off).
- [ ] **test72** — perf-overlay clock, Tier 2 — during a **live stream**, confirm the clock line
  actually renders in the performance overlay when enabled.
- [ ] **test64** — motion-control capability, Tier 2 — in **Game Mode (or with a connected
  controller)**, confirm the `[motion]` capability log line fires on controller connect.
- [ ] **test56** — Help & Links, Tier 2 — with the screen awake / a browser available, click each
  of the 3 buttons and confirm `xdg-open` launches the correct URL (GitHub / README / Tailscale doc).
- [ ] **test58** — host software version, visual — with the screen awake + an online host, open the
  PC card's **View Details** dialog and visually confirm the "Host Software Version: …" line shows.

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
