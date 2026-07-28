# BL-2541 handoff — finish the VRR fix without a test agent

Written 2026-07-28. Everything here is doable on the build host alone. Where device verification is
genuinely required, this document says so and tells you what to hand back rather than guessing.

## 1. The defect in one paragraph

On SteamOS handhelds, vibemis's VRR presentation paths deliver **92–93 fps of ~115 incoming**, while
**our own legacy VRR-off path delivers 115.2** and so does the upstream reference client (Nonary) under
identical host, content and settings — with host frame generation ON in every arm. So this is not a
host problem and not a frame-generation problem: it is a defect in our VRR implementation, present in
**both** the worker and unpaced modes. A 10-minute soak also caught a **discrete 67.5-second collapse**
(17 fps, 98.87% hitches, 1,147-interval repeat run) that a short arm never shows.

**Root cause of record:** our VRR timing core was vendored verbatim from Nonary v6.1.0-vrr9.1 in
`bcc7a778` and never re-synced, so it runs that fork's *pre-retune* tuning model. Upstream has since
retuned every divergent constant and added learning parameters we never had.

**Do not "fix" this by recommending users disable VRR.** Maintainer directive: disabling a feature is
not fixing it, and a Known Issues entry is not a deliverable.

## 2. What is already done (merged to `vibemis-main`)

| Commit / PR | What |
|---|---|
| `290b90cf` | `Pacer::dropFrameForEnqueue()` now **counts** its discards. This was the only discard path with no telemetry, and it hid ~15% of the stream in the unpaced mode. Device-validated: hidden loss 15.0% → 0.1%. |
| `5f053fc6` | `VIBEMIS_PRESENT_TRACE=<path>` — one microsecond timestamp per presented frame from `Pacer::renderFrame()`, covering the non-worker paths that `MOONLIGHT_VRR_TRACE` cannot see. |
| PR #312 | Narrowed the blanket `FORCE_VAAPI=1` AppRun hook to libva 0.x, corrected its wrong justification comment, added a CI guard against a *packaged* `HAS_RFI_LATENCY_BUG` opt-in. |
| PR #314 | Removed workaround-as-resolution text from `KNOWN_ISSUES.md`. |
| `docs/engineering/VRR-REMOTE-PRESENTATION-CONCEPTS.md` | The researched model: why a fixed-rate stream on a fixed-refresh panel *must* repeat ~4 frames/sec, why regularity is the only lever, why gamescope is a second pacer, why present mode ≠ display state. **Read this before touching the pacer.** |

## 3. Where the WIP is

Branch **`feat/bl2541-revendor-timing-core`** (pushed; `feat/` publishes nothing).

- `5f5dd29d` — vendored `vrrtimingcontroller.{h,cpp}` from `nonary/master`.
  **Verified:** it compiles standalone, and `VrrPacingWorker` compiles against it **unmodified** (the
  API is compatible — that was the big risk and it is retired). `tst_vrrpacingworker`,
  `test_vrrpacingmode`, `test_vrrswapchainpolicy` all pass.
- `86ab0880` — re-applied our local `maximumReadinessBudgetUs()` / `enforceSourceIntervalBudget()`
  cap onto the vendored core (adapted to upstream's `m_Parameters` struct), called at four sites.
  **Measured: `tst_vrrtimingcontroller` failures 367 → 308.**

### The remaining 308 failures, categorised

| Count | Assertion |
|---|---|
| 138 | a positive readiness phase must not let the reserve ramp push the budget past one source interval |
| 105 | burst-driven phase recovery must preserve the source-interval budget cap |
| 52 | a larger learned render lead must immediately shrink the scheduling reserve |
| 3 | old numeric constants (`target must include render lead and presentation safety`, `preparation duration must include render slack`, near-ceiling budget) |

**These do not fall to more call sites — that was tried and moved 309 → 308.** The real conflict:
upstream computes the readiness reserve from `usableHeadroom` ratios plus a cadence-slack credit our
old model never had, then **ramps** toward it; our cap clamps the *result*, while the tests assert the
ramp must never even transiently exceed one source interval.

## 4. Task 1 — finish the re-vendor (no device needed to make progress)

Pick one of three approaches; (a) is the most likely to be right.

- **(a) Bound the ramp target, not the result.** Apply the source-interval cap *inside* upstream's
  reserve computation (`updateReadinessBudget`, around the `usableHeadroomUs` / `effectiveDemandUs`
  block) so `clampedDesiredUs` can never exceed `maximumReadinessBudgetUs()`. Then the ramp cannot
  transiently overshoot, which is exactly what the 138 + 105 assertions demand.
- **(b) Re-express the tests against the invariant they protect** — "no standing queue deeper than one
  frame / no present backpressure" — rather than the old numeric budget. Legitimate *only* if you can
  show the new model preserves that behaviour; the tests exist because a real bug was fixed there.
- **(c) Port the rest of upstream's model** (`phaseErrorFrames`, readiness attack/release ratios,
  `schedulerLearningSamples`, `preparationLearningSamples`, `baseGuardDivisor`, `usableHeadroom`)
  and see whether our cap becomes unnecessary. Most faithful to upstream, largest diff.

**Definition of done for this task:** all `tests/vrr` binaries green, all
`scripts/check-*-invariants.sh` green, and a written note in the commit saying which approach was
taken and why. Then push a `test<N>-…` branch so CI builds an alpha for the eventual device run.

## 5. Task 2 — BL-2546, make stalls attributable (pure code, high value)

`VIBEMIS_PRESENT_TRACE` records **presents only**. `MOONLIGHT_VRR_TRACE` only exists when the worker
runs. Incoming/decode/render appear only as end-of-session aggregates. So when presentation stalls,
nobody can tell whether frames stopped **arriving**, **decoding**, or **being presented** — the test
agent had to withdraw an attribution claim for exactly this reason, and the 67.5-second collapse
(BL-2545) is currently unattributable because of it.

Add a periodic sampler (flag-gated, ~1 s interval, **every** pacing path) emitting: frames received,
frames decoded, frames presented, render-queue depth, and pacer drops since the last sample. This
makes any future stall an attributable event on the first run.

## 6. Task 3 — BL-2543, the legacy queue-delay statistic is garbage (pure code)

The legacy path reports `Average frame queue delay: 40838.61 ms` on one arm and `16175.61 ms` on
another — same path, same config, so it is an unreset/unaccumulated accumulator, not a sentinel. Fix
it or suppress the field when there are no samples. It matters because queue delay is the statistic
that cracked this whole case; a garbage value there will misdirect the next investigation exactly as
an uncounted drop did.

## 7. Build and verify locally (no device)

```bash
# VRR suite (WSL Ubuntu, qt6 + g++ present)
rm -rf /tmp/bv && mkdir -p /tmp/bv && cd /tmp/bv
qmake6 /mnt/c/Users/navya/Downloads/workspace/vibemis/tests/vrr/vrr.pro && make -j"$(nproc)"
export QT_QPA_PLATFORM=offscreen
for t in tst_vrrtimingcontroller tst_vrrpacingworker test_vrrpacingmode \
         test_vrrswapchainpolicy test_vrrratepolicy test_vrrrefreshguard tst_vrrratepolicy; do
  b=$(find . -name "$t" -type f -executable | head -1); "$b" >/dev/null 2>&1 \
    && echo "$t PASS" || echo "$t FAIL"
done

# invariants (run from repo root, must all pass before any push)
for s in scripts/check-*-invariants.sh; do bash "$s" || echo "FAIL: $s"; done
```

## 8. Gotchas that cost this session hours

- **Do all git from Windows PowerShell, never WSL.** WSL git shows every file as modified (CRLF vs LF)
  and `git checkout --` there will silently revert your edits.
- **`git commit -m` with embedded double quotes breaks PowerShell arg parsing.** Write the message to
  a file and use `git commit -F <file>`.
- **Invariant guards can be satisfied by their own explanatory comments.** Two guards written this
  session passed against mutated code because the comment above the check contained the grepped
  string. Always strip comments (`grep -v '^[[:space:]]*//'`) and **mutation-test every new guard**.
- **`feat/**` and `fix/**` branches never publish.** Push a `test<N>-…` branch to make CI build an
  alpha; `vibemis-main` cuts a beta; `release_type=rc` cuts an RC. Stable needs maintainer approval.
- **Never delete a release** (`docs/RELEASING.md`, permanence policy).

## 9. What genuinely needs the device, and what to hand back

You can complete Tasks 1–3 and get an alpha built with **no device at all**. What you cannot do is
confirm the fix works. Acceptance is defined and internal — no reference client needed:

> The VRR paths must reach **D3**: 115.23 rendered of 115.42 incoming, 0.31% hitches ≥25 ms,
> 98.2% single-refresh intervals — the numbers our own VRR-**off** path already achieves.

Hand back: the alpha tag, the arms to run (VRR on + pacing on; VRR on + pacing off; VRR off control),
the env vars to set (`VIBEMIS_PRESENT_TRACE`, and `MOONLIGHT_VRR_TRACE` on worker arms), and a
reminder that **hitch percentage — not CV — is the discriminator** (CV misranks on small 2-refresh
samples; that mistake was made and corrected this session).

## 10. Reference numbers (all same host, content, settings; host frame-gen ON)

| arm | incoming → rendered | efficiency | reported drops | hitches ≥25 ms | queue delay |
|---|---|---|---|---|---|
| vibemis VRR + pacing on | 115.48 → 102.62 | 88.9% | 11.12% | 5.00% | 4.81 ms |
| vibemis VRR + pacing off | 115.55 → 92.95 | 80.4% | 19.54% | 14.81% | 18.29 ms |
| **vibemis VRR off** | **115.42 → 115.23** | **99.8%** | 0.16% | **0.31%** | (stat broken) |
| Nonary reference | 115.54 → 115.27 | 99.8% | — | — | 0.51 ms |
| VRR-on 10-min soak | 96.68 → 74.50 | 77.1% | 22.94% | 22.13% | 18.11 ms |
