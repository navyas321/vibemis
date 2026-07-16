# Release runbook — 0.2.0 (second stable)

The exact ordered procedure from **now** (`vibemis-main` @ `c3d72786`, `app/version.txt` =
`0.2.0`, newest cuts at writing `0.2.0-beta.015` / `0.2.0-alpha.008`) to the **0.2.0 stable**
and its post-cut chores. Follow it top to bottom; every step lists who may run it.

**Tier model (recap):** alphas (`test<N>` branches) are validated by the test agent →
betas (`vibemis-main`) are the **maintainer's MANUAL tier** (BL-2016 — the test agent never
validates betas) → RC is the exact build proposed as the stable → **stable is
maintainer-approval-gated** (CI-enforced, BL-1741). All dispatch commands below were verified
against [`.github/workflows/dev-build.yml`](../.github/workflows/dev-build.yml) inputs
(`release_type`, `version_override`, `stable_confirm`, `dry_run`) on 2026-07-16.

---

## 0. Freeze the merge set

Decide what is **in** 0.2.0 and drain it through the normal alpha→merge loop. Nothing merges
without its `test<N>` cycle (alpha tier) passing or an explicit maintainer waiver.

**Remaining-merge-set placeholder** — fill in at freeze time (state as of 2026-07-16 ~20:30Z):

- [x] `test115-touch-fixes` — slider drag + mode-agnostic touch overlay taps + text-send
  borders (BL-1747/1748/2000) — verified PASS, **merged** (#199).
- [x] `test116-touch-pressure` — zero-pressure touch clamp (BL-2015 client side) — verified,
  **merged** (#205). Note: e2e touch taps still FAIL — BL-2015 was **rescoped host-side**
  (Vibepollo injects hover regardless of pressure); that residual is outside this repo and is
  **not** a 0.2.0 client blocker unless the maintainer says otherwise.
- [ ] *(maintainer decides in/out)* open fixes not yet in a test cycle: d-pad double-step
  (`sdlgamepadkeynavigation.cpp` HAT→key layer, test115 report §3), host-type badge accuracy
  (`feat/BL-2008-vibepollo-badge`, unpushed), MENU/KBD tap-target enlargement, text-send OSK.
  Anything cut from 0.2.0 stays on the README Known-issues table and rides the next train.
- [ ] Anything else the board/bus marks as 0.2.0-blocking.

**Who:** build agent proposes, maintainer confirms the final set.

## 1. Merge the set → betas green

1. Each merge lands via PR into `vibemis-main` (one feature per branch). A PR merge that
   touches code **auto-cuts the next beta** (`0.2.0-beta.NNN`) — no dispatch needed.
2. After the last merge: CI on `vibemis-main` green, and the newest beta contains the full set.
   If the final merge was docs-only (no beta cut) and a fresh beta artifact is wanted:
   `gh workflow run dev-build.yml --ref vibemis-main` (a plain dispatch on `vibemis-main`
   builds a beta; dispatch always builds — it skips the docs-only smart-build check).
3. **Update the docs to current state in the same window** (README Known-issues pruning —
   drop rows the merge set fixed; the phase tracker and test checklist in the agent-meta repo).
   The README current-state rule is hardest at a stable.

**Who:** build agent.

## 2. Maintainer manual pass on the beta (the beta gate)

The maintainer runs the newest `0.2.0-beta.NNN` on the device (Legion Go S Z2, Game Mode
first): pair → stream → Quick Menu combo open/close → touch taps/drags → resume/quit from the
grid (A / Y) → settings persistence → in-app updater sanity on the Beta channel. Betas are the
manual tier — **no test-agent involvement here** (BL-2016).

- 🔴 Findings → fix via a new `test<N>` cycle (alpha) → back to step 1.
- 🟢 Green → proceed to the RC.

**Who:** maintainer (hands-on). Build agent relays findings into fixes.

## 3. Cut the RC

```bash
gh workflow run dev-build.yml --ref vibemis-main -f release_type=rc
```

- Produces `0.2.0-rc.NNN` (prerelease, RC channel) pinned to the built commit — the **exact
  bits proposed as the stable**.
- An agent **may propose and cut an RC** once the merge set is in and betas are green (per the
  CLAUDE.md tier matrix).
- Verify after the run: release `Vibemis release 0.2.0-rc.NNN` exists, prerelease-flagged,
  AppImage attached, sha256 in the release body, `RELEASES.md` refreshed with the row.

**Who:** build agent (may self-serve) or maintainer.

## 4. Maintainer RC pass

Maintainer switches the in-app channel to **Release candidate**, updates to the RC in place,
and repeats the manual pass on the RC build itself (the thing that will be re-tagged stable in
spirit — the stable is a fresh cut of the same `vibemis-main` state, so **do not merge anything
between RC-green and the stable dispatch**).

- 🔴 Findings → fix → new beta(s) → new RC (`rc.002`, …; RCs are permanent, never re-cut the
  same number) → repeat.
- 🟢 Green → the maintainer states approval for the stable cut **explicitly, in-conversation**.

**Who:** maintainer (hands-on).

## 5. Cut the STABLE — <MAINTAINER-APPROVAL-REQUIRED>

> ⚠️ **MAINTAINER-APPROVAL-REQUIRED.** **An agent may only run this command while relaying the
> maintainer's explicit, in-conversation approval of THIS specific cut** (the exact version, on
> the current `vibemis-main` state). Never dispatch it autonomously, never "pre-stage" it, and
> never type `CONFIRM-STABLE` except as that relay. CI enforces the gate (BL-1741): a stable
> dispatch without `stable_confirm=CONFIRM-STABLE` fails at Setup Version before anything
> builds — but the gate is the maintainer's approval, not the string.

```bash
gh workflow run dev-build.yml --ref vibemis-main -f release_type=stable -f stable_confirm=CONFIRM-STABLE
```

- Tags bare **`0.2.0`** from `app/version.txt`, non-prerelease, takes **Latest**. Title:
  `Vibemis release 0.2.0`.
- Hotfix patches later ship the same way plus `-f version_override=0.2.1`.
- (`-f dry_run=true` exists to validate pipeline changes without minting a release/tag — never
  needed on the real cut.)

**Permanence stance:** releases and tags are **PERMANENT** (BL-1736; SemVer §3). Never delete,
un-publish, or re-tag a release — **a bad stable is superseded by `0.2.1`**, it is not removed.
A burnt number stays burnt.

**Who:** maintainer, or an agent relaying the maintainer's explicit approval of this cut.

## 6. Post-cut chores (same session as the cut)

1. **Bump `app/version.txt` to the next stable** right after the cut (strict semver: `0.3.0`
   if the next train carries any feature — the default expectation; `0.2.1` only if the
   maintainer declares a fixes-only train). Commit to `vibemis-main` with `[skip ci]`.
2. **RELEASES.md refresh check** — the timeline is auto-regenerated on every cut; verify the
   `0.2.0` ✅ Stable row is at the top with a working AppImage link. (Known gap: the refresh
   has previously missed cuts — `beta.013–.015` and `alpha.005–.008` are absent as of
   2026-07-16; nothing has refreshed the file since the `beta.012` rename. If the stable row
   doesn't appear, regenerate via `scripts/gen-releases-index.sh` and investigate the
   workflow's refresh step.)
3. **Releases-page ordering check** — **Latest** now points at `0.2.0`; `0.1.0` remains
   published below it; `0.2.0` sorts above every `0.2.0-*` prerelease (SemVer precedence —
   alphas below betas of the same base is EXPECTED, per BL-1772; don't "fix" it).
4. **In-app updater stable-channel check** — on a device running the **oldest deployed
   binary** (0.1.0, not just the RC): Settings → Advanced → Software updates → channel
   **Stable** → *Check for updates* offers `0.2.0` → *Update now* swaps in place (previous
   build kept as `.old`) and relaunches as 0.2.0.
5. **README badge/links check** — the README carries no version badge (nothing to bump);
   verify `releases/latest` links now resolve to `0.2.0`, the Known-issues table matches
   post-merge reality, and the channel table needs no change. Refresh
   `docs/RELEASE_HISTORY.md` only if the catalog convention requires the new stable's row.
6. **Announce / handoff** — post the cut (tag, sha256, "Latest updated") on the coordination
   bus and in the agent-meta repo's build-agent inbox; update the phase tracker (second stable
   shipped) and the session handoff doc.

**Who:** build agent (all mechanical); maintainer sees the announcement.

---

## Quick reference — who may cut what

| Tier | Command / trigger | Who decides |
|------|-------------------|-------------|
| alpha | `test<N>` push with `[alpha]` in the HEAD commit | automatic (test agent requests) |
| beta | PR merge into `vibemis-main` touching code; or plain dispatch on `vibemis-main` | automatic / agent |
| rc | `gh workflow run dev-build.yml --ref vibemis-main -f release_type=rc` | agent may propose & cut |
| stable | `gh workflow run dev-build.yml --ref vibemis-main -f release_type=stable -f stable_confirm=CONFIRM-STABLE` | **MAINTAINER APPROVAL REQUIRED** (step 5) |
