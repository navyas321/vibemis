# Fork survey — moonlight-qt / Artemis line (BL-2636)

Timeboxed research spike. **Deliverable is a ranked adoption shortlist, not code.** Nothing here is
ported until the user reviews and accepts a candidate; each accepted candidate then gets its own
epic or task.

**Surveyed:** 2026-08-07, against `moonlight-stream/moonlight-qt@master` (1210 forks at survey time).

## Method (reproducible)

1. Enumerate forks pushed since 2025-08-01:
   `gh api "repos/moonlight-stream/moonlight-qt/forks?per_page=100&sort=newest" --paginate`
2. For each, measure real divergence, not activity:
   `gh api "repos/moonlight-stream/moonlight-qt/compare/master...OWNER:BRANCH"` → `ahead_by`,
   `behind_by`, `files`.
3. Drop every fork with `ahead_by == 0` (a recent push to a tracking mirror is not work).
4. Read the surviving commit subjects; check `.gitmodules` to see whether the fork also forks
   `moonlight-common-c` — that is the single biggest port-risk driver for us.

The GitHub compare API caps at 250 commits / 300 files, so `files=300` is a floor, not a count.

## Why the common-c column dominates port risk

vibemis does not track upstream `moonlight-common-c`. `.gitmodules` points at
`navyas321/moonlight-common-c`, branch `vibemis-rtp-timestamp`, which carries our own RTP-timestamp
work (BL-2336, BL-2415) plus the cherry-picked microphone protocol commits (BL-2630). Any candidate
that also forks common-c cannot be merged — its protocol commits must be cherry-picked onto
`vibemis-rtp-timestamp` and the submodule re-pinned, exactly as BL-2630 did. Candidates that use
**stock** common-c are app-layer-only and are therefore dramatically cheaper.

## Candidates

| Fork | ★ | Ahead / behind | Files | common-c | License | Port risk |
|---|---|---|---|---|---|---|
| [Nonary/moonlight-qt](https://github.com/Nonary/moonlight-qt) | 34 | 17 / 24 | 105 | **stock** | GPL-3.0 | **Low** |
| [qiin2333/moonlight-qt](https://github.com/qiin2333/moonlight-qt) | 901 | 269 / 12 | 300+ | forked | GPL-3.0 | High (cherry-pick only) |
| [MrOz59/Hestia](https://github.com/MrOz59/Hestia) | 5 | 53 / 12 | 126 | forked (`hestia`) | GPL-3.0 | Medium (host-coupled) |
| [jackhric/moonlight-qt-usbip](https://github.com/jackhric/moonlight-qt-usbip) | 0 | 23 / 12 | 73 | stock | GPL-3.0 | High (privileged helper) |
| [WonderwerksSoftware/perigee](https://github.com/WonderwerksSoftware/perigee) | 0 | 130 / 12 | 235 | stock | GPL-3.0 | Medium |
| [linckosz/moonlight-qt](https://github.com/linckosz/moonlight-qt) | 4 | 1 / 12 | 139 | stock | GPL-3.0 | Trivial |

All GPL-3.0 — license-compatible with vibemis. Upstream attribution belongs in the commit/PR trail.

### Ruled out (evidence, not opinion)

- **`wjbeckett/artemis` — this is "Artemis Qt".** 367★, GPL-3.0, branch `develop`. It is **not** a
  GitHub fork of moonlight-qt (detached history — `compare` returns no common ancestor), and it has
  been **unpushed since 2025-09-11**, ~11 months stale at survey time. Its commit content is
  overwhelmingly Flatpak / SPIR-V / glslang / shaderc / libplacebo *build plumbing*, plus a
  `preferred renderer setting (Auto/Vulkan/OpenGL)` and QuickMenu thread-safety fixes. vibemis
  already ships libplacebo/plvk and a QuickMenu. **Nothing to adopt.** Note this also corrects a
  long-standing naming confusion (BL-1579): the Artemis *feature set* lives in the **Android** line
  (`ClassicOldSong/moonlight-android`, `Marssvoodoo/artemis-android`,
  `drunkitguy/artemis-apollo2`), which is Java/Android and not portable to our Qt client.
- **Zero-divergence forks** (`ahead_by == 0`, nothing to mine despite recent pushes):
  `Grippy98/moonlight-qt`, `tertiumndatur/moonlight-qt-pyrowave` (name promises a pyrowave codec;
  the tree carries none), `Totaie/umbra`, `Beam2026/beam-view`, `jorys-paulin/moonlight-qt`,
  `Blahkaey/moonlight-qt`.
- **`mhadifilms/Screener`** — unrelated history, a product rewrite for edit-suite review, not a
  streaming-feature source.

## Ranked adoption order

### 1. Nonary/moonlight-qt — VRR adaptive frame pacing (recommended first)

Highest strategic fit and lowest risk. **Nonary authors Vibepollo**, the host vibemis actually pairs
with, so this is the client half designed against our host. All 17 commits are VRR pacing on **stock
common-c** — app-layer only, so no submodule surgery:

`feat(vrr): add GPU-ready adaptive frame pacing` · `fix(vrr): stabilize host-quantized source
cadence` · `feat(vrr): split pacing telemetry by outcome` · `fix(vrr): retain Gamescope WSI adaptive
pacing` · `feat(vrr): add replay-grade diagnostics and optimize pacing` · `fix(vrr): recover pacing
after transient stalls` · `perf(vrr): smooth mid-rate adaptive pacing` · `perf(vrr): add
low-overhead cadence diagnostics`

**Caveat that makes this a comparison, not a port:** vibemis already has substantial VRR/cadence
work of its own (`session.cpp`, `streamutils.cpp`, `bitraterescuepolicy.h`, `quickmenumanager.cpp`).
This should be scoped as *"diff our pacing against Nonary's and adopt what measurably wins"*, not a
wholesale merge. `fix(vrr): retain Gamescope WSI adaptive pacing` is directly relevant to our Game
Mode path. Ties into BL-2642.

### 2. Cross-fork fixes that upstream has not merged

Four fixes appear independently in **both** qiin2333 and Hestia but are absent from
moonlight-qt master — meaning they are circulating in the fork ecosystem while upstream lags. Small,
self-contained, stock-common-c, and cheap to verify:

- `Fix manual address being clobbered when using the CLI`
- `Loosen applist XML validation to accept empty app names`
- `Fix blocking during rendering rather than in waitToRender() on MoltenVK`
- `Use libplacebo renderer on macOS`

The last two are macOS-only and therefore low value for our Linux/handheld focus. The first two are
platform-neutral bug fixes and are the cheapest real wins in this survey.

### 3. qiin2333/moonlight-qt — selective cherry-picks only

The most active fork by far (901★, 269 ahead, daily pushes, largely Chinese-language commits).
**Do not merge** — it forks common-c and 269 commits carry heavy UI divergence (it reskins the whole
app to neo-brutalism, `feat(ui) #134`). Cherry-pick candidates:

- `feat(hdr): add configurable brightness profile (#126)` — vibemis just promoted HDR out of
  experimental (BL-2622); a brightness profile is the natural follow-on.
- `feat(video): follow upstream color range series — default to full range (#151)` — we already have
  color-range surface; worth diffing.
- `feat(cursor): synchronize host cursor shapes locally (#133)` — we have essentially none of this.
- `fix(clipboard): route large payloads through blob transfer` — we have broad clipboard support;
  this is a robustness fix.
- `fix(streaming): isolate microphone processing (#115)` — **directly relevant to BL-2629.** An
  independent implementation of mic handling; read it as a second opinion on our capture threading.
- `chore: script to track which upstream commits are still unhandled (#152)` — tooling, not a
  feature, but it is exactly the gap BL-2418 describes.

### 4. WonderwerksSoftware/perigee — stock-host display switching

Mostly Debian packaging/provenance and CI hygiene (low value to us), but one coherent feature
stands out: a *physical display request controller* that switches host displays **on a stock host**
via shortcut, explicitly with `refactor: remove fork-only display target path`. Given our history of
ghost virtual displays and resolution churn (BL-1811, BL-2220), a stock-host display-switch path is
worth reading. Also carries Steam Deck pointer-input fixes.

### 5. MrOz59/Hestia — mine the generic commits, ignore the Hermes coupling

Most of this fork exists to integrate a different host ("Hermes") and forks common-c on a `hestia`
branch, so it is not adoptable wholesale. Generic pieces worth reading:

- `Pace from fractional refresh rate, not a rounded integer` — small, and squarely in our VRR lane.
- `feat(audio): add selectable buffering profiles` + `enhance buffer policy with prebuffering and
  recovery parameters` — compare against our BL-2523 SDL queue backpressure work.
- `Add codec capability probe` and `Add quality presets` — we have neither.

### 6. jackhric/moonlight-qt-usbip — park it

USB/IP device forwarding (23 commits, stock common-c). Genuinely interesting for handheld
peripheral passthrough, but it needs a **privileged helper**, polkit grants, an AppImage-bundled
binary, and host-side `UsbBridgePort` support. That is a program, not a port. Revisit only if
peripheral passthrough becomes a goal.

### Not recommended

`linckosz/moonlight-qt` — 1 commit ahead; nothing meaningful.

## Recommended next step

Adopt in this order, each as its own task after user review: **(1) Nonary VRR comparison →
(2) the two platform-neutral cross-fork fixes → (3) qiin2333 HDR brightness profile.** Everything
below that is opportunistic.

Re-run the method above when upstream moonlight-qt cuts a release, or roughly every 6 months.
