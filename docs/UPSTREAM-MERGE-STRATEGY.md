# Upstream merge strategy — closing the gap behind moonlight-qt master (BL-2654)

How vibemis adopts work from `moonlight-stream/moonlight-qt@master`, and why it is done in small
themed batches rather than one big merge. Written 2026-08-08 against merge base `1bf86f52`
(2025-07-04) and upstream master as fetched that day.

Re-measure before acting on any number here — see [Measuring the gap](#measuring-the-gap) for the
commands.

## TL;DR

- **`git rev-list --count` is the wrong metric and must stop being quoted.** It says 474. It said
  474 before this campaign's first batch landed and it says 474 after, because the merge base
  cannot move while we adopt upstream content as fork commits. It will keep saying ~474 forever.
- **The real gap is 229 files**, of which only **128 need actual merge work**. 62 are already
  content-identical to upstream (hand-ported by earlier campaigns), 22 we have never touched,
  14 we deleted on purpose, 3 upstream deleted.
- **Batch at interface boundaries, not at files or commits.** Every attempt to take a single file
  or a single commit runs into an interface change whose callers live in files we have forked.
- **Each batch ships as a `test**` branch → alpha → on-device cycle → merge.** CI green is not
  tested.

## Why not just merge

Three structural facts rule out `git merge moonlight/master`:

1. **We are 1160 commits ahead**, concentrated in exactly the files upstream churns most —
   `session.cpp`, `ffmpeg.cpp`, `plvk.cpp`, `drm.cpp`, `vaapi.cpp`, `pacer/`, the QuickMenu and
   Vibepollo integration. BL-2226 already measured one of these: a 5133-line whole-file conflict in
   `session.cpp`. A single merge would present ~128 conflicted files at once with no way to test
   any one of them in isolation.
2. **We track a forked `moonlight-common-c`** (`navyas321/moonlight-common-c`, branch
   `vibemis-rtp-timestamp`, carrying BL-2336/BL-2415 RTP-timestamp work and the BL-2630 microphone
   protocol commits). Upstream submodule bumps cannot be taken; protocol commits must be
   cherry-picked onto our branch and the submodule re-pinned.
3. **Some upstream changes are ones we deliberately rejected** — 14 files are gone from our tree on
   purpose (libsoundio, the AppVeyor CI files, upstream's own workflows). A merge would resurrect
   them.

## Measuring the gap

### The metric to stop using

```
git rev-list --count vibemis-main..moonlight/master   # 474 -- SHA distance, not content distance
```

This counts commits that are not ancestors of our HEAD. Prior campaigns (BL-2226, BL-2418) adopted
upstream content as **squashed fork commits with new SHAs**, so the merge base never moved and this
number never fell. Batch 1 of this campaign converged six files with upstream and the number stayed
at exactly 474.

This is the same trap `FORK-SURVEY.md` §2 documents, run in reverse. There, forks carrying upstream
fixes as rebased cherry-picks looked "ahead" of master. Here, our tree carrying upstream fixes as
hand-ports looks "behind" it. **`git merge-base --is-ancestor <sha> <branch>` answers a question
about ancestry, never about content** — and it is the reason BL-2654 was filed claiming four fixes
were missing when two of them (`5034a324` manual-address clobber, `cdacb3d2` empty app names) were
already in our tree, hand-merged by BL-2226 with a comment saying so.

### The metric to use

Compare three blobs per path — merge base (BASE), `vibemis-main` (OURS), `moonlight/master`
(THEIRS) — for every path where THEIRS differs from BASE:

| Verdict | Condition | Meaning |
|---|---|---|
| `CONVERGED` | OURS == THEIRS | Already adopted. No debt. |
| `TAKE-THEIRS` | OURS == BASE | We never forked it; upstream improved it. Cheapest debt. |
| `BOTH` | all three differ | Real merge work. |
| `WE-DELETED` | OURS absent | Deliberately removed. Never resurrect. |
| `UP-DELETED` | THEIRS absent | Upstream removed it; decide per file. |

Measured 2026-08-08, after batch 1:

| Verdict | Files |
|---|---|
| BOTH | 128 |
| CONVERGED | 62 |
| TAKE-THEIRS | 22 |
| WE-DELETED | 14 |
| UP-DELETED | 3 |
| **total in gap** | **229** |

By theme (measured before batch 1, so it still shows the renderer units batch 1 converged):

| Theme | take-theirs | converged | both | total |
|---|---:|---:|---:|---:|
| video / decode | 16 | 24 | 21 | 62 |
| i18n | | | 55 | 55 |
| CI / packaging | 4 | 7 | 4 | 25 |
| GUI / settings | | 8 | 14 | 22 |
| root / submodules | 6 | 6 | 3 | 17 |
| backend | | 5 | 9 | 14 |
| app core | | 4 | 5 | 11 |
| audio | 4 | | 2 | 8 |
| session / stream | | 2 | 4 | 6 |
| input | | | 6 | 6 |
| CLI | | | 2 | 2 |

## The batching rule: cut at interface boundaries

The obvious batching units both fail:

- **Per commit** fails because an upstream commit's callers are usually in files we forked. Of 470
  non-merge commits in the range, only 45 apply cleanly to our tree standalone; 61 are already
  present in content; 364 conflict.
- **Per file** fails because a file that looks free to take verbatim usually is not. All six of
  `cuda.{cpp,h}`, `genhwaccel.{cpp,h}`, `mmal.{cpp,h}` were `TAKE-THEIRS` — we had never forked
  them — and *none* could be taken, because each depended on upstream deleting
  `needsTestFrame()` from `renderer.h`, whose other nine implementors we have forked heavily.
  `eglimagefactory.{cpp,h}` is the same story with a worse blast radius: its constructor,
  `exportDRMImages()` and `exportVAImages()` all changed signature, and its only callers are
  `drm.cpp` and `vaapi.cpp` — two of our most forked files.

So the unit of adoption is **the interface and all of its implementors and callers**, taken
together, in one batch that builds.

### Choosing the next batch

Rank candidates by, in order:

1. **Unblocking power** — how many `TAKE-THEIRS` files does closing this interface release? An
   interface batch that converts eight blocked headers into adoptable ones pays for itself.
2. **Blast radius** — how many of our forked files does it touch, and are any of them
   invariant-guarded (`scripts/check-*-invariants.sh`)?
3. **User-visible value.**
4. **Testability** — can an on-device cycle actually tell whether it worked?

Explicitly deprioritised:

- **`audio/**` is frozen.** BL-2213 established what makes vibemis the only Moonlight fork without
  audio crackling, and `check-audio-invariants.sh` enforces it in CI. The four `TAKE-THEIRS` audio
  files stay untaken until someone deliberately reopens that decision.
- **Upstream's own CI workflows** are `TAKE-THEIRS` only because we never edited *those* files; our
  CI is a deliberate rewrite (`dev-build.yml`, `flatpak.yml`). Do not adopt them.
- **i18n (55 files)** is never hand-merged — regenerate with `lupdate` + `lrelease`, as BL-2226 did.
- **The ~40-commit DRM atomic series** stays deferred (BL-2418's finding): `drm.cpp` is still
  byte-identical to the fork point, so it is a clean take-theirs, but only if bare-KMSDRM ever
  becomes a target.

## Batch procedure

1. **Branch off `vibemis-main`.** Name it `test<something>` — `feat/**`, `fix/**` and `chore/**`
   deliberately do not build (see the header comment in `dev-build.yml`). The branch name is the
   intent; no `[alpha]` marker commit is needed.
2. **Cherry-pick with `-x`** so the upstream SHA is recorded in the message. On a whole-file
   conflict in a heavily forked file, `git checkout --ours` and then apply the upstream hunk by
   hand — do not hand-merge 1700 lines to win a six-line deletion.
3. **Converge whole compilation units where you can.** If removing the interface dependency leaves
   a file identical to upstream but for one or two unrelated hunks, take those too
   (`git checkout moonlight/master -- <file>`) so the unit lands byte-identical and carries no
   residual debt. Verify with `git hash-object <file>` against `git rev-parse moonlight/master:<file>`.
4. **Run all 11 guards** — every `scripts/check-*-invariants.sh` must exit 0.
5. **Push the `test**` branch, wait for the alpha to publish.** Never tell anyone to install a
   release before CI confirms the build finished.
6. **Run a real on-device cycle.** CI green is not tested. Build agent builds; the test agent
   produces runtime evidence on real hardware.
7. **Merge to `vibemis-main`** (which cuts a beta), then re-measure with the three-blob script and
   record the new numbers in this file.

## Progress

### Batch 1 — "test all renderers before use" (2026-08-08)

Upstream `d501a627` (2025-12-22) deletes `needsTestFrame()` from `IFFmpegRenderer` and tests every
renderer with a test frame instead of letting each opt in. Chosen first because it is the interface
that blocks the most `TAKE-THEIRS` renderer files, and because it is mechanical enough to review by
eye.

- Cherry-picked `d501a627` (`0f6e66e4`). 20 files, +15/-107 — identical shape to upstream.
  Two whole-file conflicts (`plvk.cpp`, `vt_metal.mm`, both heavily forked) resolved
  `--ours` + a hand-applied deletion of the method. `ffmpeg.cpp` auto-merged to upstream's exact
  control flow. `git grep needsTestFrame` now returns nothing.
- Rode along the remaining hunks in the units this unblocked (`ab203ad4`): `genhwaccel` moves to
  `Utils::getEnvironmentVariableOverride()` for `GENHWACCEL_CAPS`; `mmal` gains the
  `getDecoderColorRange()` override and a simplified `prepareToRender()` flush.

**Result:** `cuda.{cpp,h}`, `genhwaccel.{cpp,h}`, `mmal.{cpp,h}` are byte-identical to upstream.
All 11 invariant guards exit 0.

**Behaviour change to watch on device:** every renderer is now initialised twice on selection —
once against `testFrameDecoderParams`, then reset and re-initialised for real. Previously SDL (and
any renderer that returned `false`) skipped the test pass. Watch startup latency into a stream and
any renderer that now fails selection where it used to be taken untested.

**Gap after batch 1:** 229 files (128 BOTH, 62 CONVERGED, 22 TAKE-THEIRS, 14 WE-DELETED,
3 UP-DELETED). Six files moved `TAKE-THEIRS` → `CONVERGED`; `vdpau.h` and `vt_avsamplelayer.mm`
moved `TAKE-THEIRS` → `BOTH` (partially closed — 1 and 12 lines residual respectively), because
removing a declaration from a file we had not otherwise touched still counts as touching it.
SHA distance unchanged at 474, as predicted.

### Batch 2 — vendor h264bitstream (2026-08-08)

Upstream replaced the `h264bitstream` **git submodule** with a vendored minimal source set
(`b7adc70e`), then fixed real bugs in it (`3e24a7a1`) and an MSVC warning (`7794a428`). The bug
fixes are in the SPS-parsing path that `ffmpeg.cpp` uses for SPS fixups, so this is user-visible
H.264 correctness, not just build hygiene. Chosen as batch 2 over the `eglimagefactory` interface
because it is fully self-contained — a third-party parser with no entanglement in our fork.

- Cherry-picked all three `-x` (`360b153a`, `2cd86151`, `ccefda41`). One conflict, in `.gitmodules`:
  upstream's hunk deletes the `h264bitstream` submodule entry, ours also carries the
  `moonlight-common-c` fork pointer. Resolved by dropping only the `h264bitstream` block — **our
  `navyas321/moonlight-common-c` @ `vibemis-rtp-timestamp` entry is preserved**, and
  `check-submodule-invariants.sh` confirms it.
- Removed `h264bitstream/libh264bitstream.a` (`94b7706a`). This 998 KB prebuilt static library was
  committed by accident during the 2025-07 quick-menu work and is not tracked upstream. Now that
  `h264bitstream.pro` is `TEMPLATE = lib` compiling the vendored sources and `app.pro` links out of
  `$$OUT_PWD`, a stale `.a` in the *source* tree can shadow a fresh in-source build.

**Result:** all six files under `h264bitstream/` are byte-identical to upstream. All 11 guards
exit 0. CI run 31277994460 SUCCESS (AppImage Build, Compile Sanity (Linux), VRR Tests, Invariants).

**Gap after batch 2:** 229 files — 128 BOTH, **69 CONVERGED** (was 62), **16 TAKE-THEIRS** (was 22),
14 WE-DELETED, 2 UP-DELETED.

## The Artemis line is exhausted — do not re-survey it

Checked directly against our own tree 2026-08-08, which is a stronger test than the GitHub compare
API the fork survey used:

| Artemis branch | We are behind | Content |
|---|---:|---|
| `upstream/develop` (default) | **0** | nothing — we contain all of it |
| `upstream/master` | 2 | `Create FUNDING.yml` then `Delete .github/FUNDING.yml` |
| `upstream/fix/hdr-renderer-logic` | 13 | Flatpak packaging only, despite the branch name |

**Correction to `FORK-SURVEY.md`:** that file says `wjbeckett/artemis` has "detached history —
`compare` returns no common ancestor". That is true of *moonlight-qt vs artemis*, but not of *us vs
artemis*: `git merge-base vibemis-main upstream/develop` returns `afe2de7f`, which is artemis's own
HEAD. Artemis is **vibemis's origin**, and we are 870 commits ahead of it with nothing behind.

The 13-commit `fix/hdr-renderer-logic` branch is misleadingly named — it contains no HDR renderer
logic. It is VA-API driver builds, NVDEC/NVENC with a custom FFmpeg, libva hashes and Flathub
runtime changes, unmerged and unpushed since 2025-09-11. The only idea worth noting is bundling
GPU drivers into the Flatpak for no-setup hardware decode; our `flatpak.yml` has diverged, so that
would be a deliberate feature decision, not a merge. Nothing here is upstream debt.

### Suggested batch 3

The `eglimagefactory` interface — constructor, `exportDRMImages()`, `exportVAImages()`,
`resetCache()`, and the new `EglImageContext` RAII wrapper — together with its two callers
`drm.cpp` and `vaapi.cpp`. It is the next interface that blocks a `TAKE-THEIRS` unit, it is
Linux-relevant (the EGL/DRM/VAAPI import path our handheld target actually uses), and it is
guarded by `check-rfi-invariants.sh` and `check-vrr-invariants.sh` so a regression is caught early.

## Reproducing the measurement

The three-blob classifier is a dozen lines of stdlib Python: list `git ls-tree -r` for the merge
base, `vibemis-main` and `moonlight/master`, then bucket every path where THEIRS differs from BASE
by comparing the three blob hashes. Per-commit presence is `git format-patch -1 --stdout <sha>`
piped into `git apply --check` (applies cleanly) and `git apply --check -R` (already present).

Both are cheap enough to re-run at the start of every batch, and re-running them is the point —
the numbers in this document are a snapshot, not a fact.
