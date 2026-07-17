# Upstream moonlight-qt rebase — 2026 Q3 quarterly pass (BL-1564)

**Status: PARKED (merge is gnarly — NOT executed this quarter).** Quarterly *check* complete;
findings below. No code merged, so the shipping build (`vibemis-main`) is unaffected and needs
no device regression this quarter.

## How far behind are we?

| Metric | Value |
|---|---|
| Upstream | `moonlight-stream/moonlight-qt` `master` |
| Upstream tip | `c0c4d60` — 2026-07-08 "Update AppImage libva to 2.24.1" |
| Our integration branch | `vibemis-main` `55d6cc4` |
| Merge base (fork point) | `1bf86f5` — 2025-07-04 |
| **Upstream commits ahead of fork point** | **443** |
| Upstream files changed since fork point | 218 |
| **Trial-merge conflicts** (`git merge --no-commit moonlight/master` onto `vibemis-main`) | **93 files** |

The merge base is still the original 2025-07-04 fork point: no prior quarter landed an
ancestry-preserving upstream merge, so this is a full year of divergence layered under the
Vibemis rebrand + the ClassicOldSong Apollo-lineage `moonlight-common-c` submodule swap.

## Submodule symbol re-check (the wrapper gap watch)

`moonlight-common-c/moonlight-common-c.pro` is the wrapper that bridges upstream's expectations
to ClassicOldSong's fork. Re-checked the listed symbols:

| Symbol | In our (ClassicOldSong) `Limelight.h`? | Referenced by our `app/` code? | Wrapper status |
|---|---|---|---|
| `src/rswrapper.c` (Reed-Solomon indirection) | n/a (source file) | — | **Handled**: `.pro` substitutes `reedsolomon/rs.c` |
| `nanors/` (modern Reed-Solomon) | n/a (include dir) | — | **Handled**: `.pro` substitutes `reedsolomon/` include path |
| `LiSendControllerTouchEvent2` | **No** | **No** | No gap: we use base `LiSendControllerTouchEvent` (present, 4 refs) |
| `LI_CCAP_DUAL_TOUCHPAD` | **No** | **No** | No gap: not consumed by our code |
| `LiGetMicroseconds` | **No** | **No** | No gap: not consumed by our code |

**Conclusion:** the ClassicOldSong fork still lacks the three upstream symbols, but our code does
not call any of them, so there is **no current compile gap** — the two `.pro` substitutions
(rswrapper→rs.c, nanors→reedsolomon) remain sufficient. These three symbols only become blockers
if a future upstream merge pulls in upstream code that calls them; resolve them *at that merge*.

## Why this quarter's merge is gnarly (parked, not attempted)

93 conflicted files on the trial merge, broken down:

| Area | Conflicts | Nature |
|---|---|---|
| `app/languages/*.ts` | 48 | Translation catalogs — mechanical; regenerate with `lupdate`, don't hand-merge |
| `app/streaming` | 9 | **Real code** — video/input/audio path; careful manual resolution |
| `app/backend` | 7 | **Real code** — `nvhttp.cpp/h`, `computermanager.cpp`, `systemproperties.cpp/h` (pairing/host logic, incl. Vibemis' virtualDisplay + host-badge additions) |
| `app/gui` | 7 | **Real code** — QML (`AppView.qml`, navigable menu items) vs Vibemis theme/overlay work |
| `moonlight-common-c.pro` | 1 | Upstream changed the wrapper we customized for the submodule swap |
| `wix/*` | 4 | Windows installer — deleted in our Linux-focused fork (modify/delete) |
| scripts / setup-deps / misc | ~17 | Build tooling — mostly take-ours (we rebranded + Linux-only) |

The ~23 real-code conflicts (streaming + backend + gui + wrapper) sit exactly on top of Vibemis'
largest customizations (Quick Menu overlay, Vibepollo presets, virtual-display, host-badge, the
rebrand). A blind 443-commit rebase would silently clobber those. This is a **curated, staged
merge with maintainer involvement**, not an unattended quarterly auto-rebase.

## Recommendation for when this is executed (future cycle, maintainer-gated)

1. Do it **staged**, not as one 443-commit merge: cherry-pick/merge upstream in themed slices
   (build/deps → backend/nvhttp → streaming → gui), each its own `testNN` cycle with a clean
   WSL rebuild + device regression before the next slice stacks. Never stack on un-green CI.
2. Regenerate `app/languages/*.ts` with `lupdate` rather than resolving 48 catalog conflicts.
3. `wix/*` and Windows/mac installer scripts → take-ours-delete (Vibemis is Linux/AppImage/Flatpak).
4. At the streaming/backend slices, re-run this symbol check — if upstream now calls
   `LiSendControllerTouchEvent2` / `LI_CCAP_DUAL_TOUCHPAD` / `LiGetMicroseconds`, extend the
   `.pro` wrapper (or shim in `reedsolomon`/Limelight compat) before that slice can build.
5. Prototype each slice's merge in a throwaway `git worktree` (as this check did) to size it
   before committing.

## Reproduce this check

```bash
git remote add moonlight https://github.com/moonlight-stream/moonlight-qt.git   # once
git fetch moonlight master --no-tags
MB=$(git merge-base origin/vibemis-main moonlight/master)
git rev-list --count "$MB..moonlight/master"        # behind-count
# trial merge in a throwaway worktree:
git worktree add --detach /tmp/vibemis-trial origin/vibemis-main
cd /tmp/vibemis-trial && git merge --no-commit --no-ff moonlight/master
git diff --name-only --diff-filter=U | wc -l          # conflict count
git merge --abort && cd - && git worktree remove /tmp/vibemis-trial
```

_Checked 2026-07-17 (BL-1564, worker w5-vibemis). Quarterly CHECK done; execution parked._
