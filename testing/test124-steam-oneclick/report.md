# Test124 Report — one-click Steam library launch: host-game shortcut sync (BL-1786)

**Artifact tested:** `Vibemis-0.2.0-alpha.017-x86_64.AppImage`
**md5:** `f0f1ad94fa99c74a773f3d355e6aa044` ✓ · **sha256:** `48ed3c69d140f346…5ae89fd4` ✓ · selftest PASS.
**Branch:** `test124-steam-oneclick` · **Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5
**Test date:** 2026-07-16 · **Safety-critical file:** `shortcuts.vdf` (own backup kept + script's own backup)

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| Tier 1 — dry-run safety | **PASS** | dry-run writes nothing; Steam-running guard refuses --apply (exit 3); --list=0 pre-apply |
| Tier 2 — apply + one-click E2E | **PASS** | backup + readback-verified write; idempotent; 3 tiles appear; **one-click launched a real Vibepollo session (host-confirmed)** |
| Teardown | **PASS** | shortcuts.vdf restored **byte-identical** to baseline; --list=0; library clean |

**No shortcuts.vdf corruption at any point.** Baseline md5 `a035e3137b6a198554a6209e5485fb7f`
was preserved/restored exactly.

---

## 2. Tier 1 — dry-run safety (launcher only)

Baseline: `stat %Y` = 1784204268, size 4783, md5 `a035e3137b…`. Own safety backup taken first.

1. **--list pre-apply** → `0 Vibemis-managed shortcut(s)`; mtime unchanged. ✓
2. **dry-run** (no --apply) → printed the plan (3 new: **Desktop**, **Steam Big Picture**,
   **Virtual Display**; cover art 3/3), exit 0; **mtime + md5 unchanged; no backup file created**. ✓
3. **Steam-running guard** — with Steam open, `--apply` → `ERROR: Steam appears to be running…`,
   **exit 3**, mtime + md5 **byte-identical** (nothing written despite the plan echo). ✓
4. **--list** still 0 managed. ✓

## 3. Tier 2 — apply + one-click E2E

**3.1 apply (Steam closed):** created backup `shortcuts.vdf.bak-20260716T224420`, **wrote 6233 B,
`Readback OK: True`**, 6 grid-art files, exit 0 (size 4783→6233). Immediate **re-apply →
byte-identical** (md5 unchanged `6bde1f14…`, 0 new art) = idempotent, no duplicate tiles.
`--list` now shows the 3 managed shortcuts, each → `stream "Navid-PC" "<app>"`. ✓

**3.2 tiles appear:** restarted Steam → **Desktop — Navid-PC / Steam Big Picture — Navid-PC /
Virtual Display — Navid-PC** appear as non-Steam library tiles with a PLAY button (grid art from
the CLI's Boxart cache). ✓

**3.3 one-click E2E (the verdict):** clicked **PLAY on "Desktop — Navid-PC"** (22:48:11 EDT).
Process tree confirmed the chain — Steam ran
`SteamLaunch AppId=3701936125 -- Vibemis-0.2.0-alpha.017 stream "Navid-PC" "Desktop"`. The host
desktop **streamed and was interactive** on the handheld; client "Vibepollo — Client Connected"
toast fired. **Host-side corroboration (bus 22:49:27 / 22:51:38):** Vibepollo's
`sunshine_wgc_capture` (spawned only during an active stream) **started 22:48:23** — matching the
click — proving Steam tile → `vibemis stream` → live Vibepollo session. Per host request the
Desktop tile (not a game/BigPicture) was used so the maintainer's live host screen wasn't taken over. ✓

**3.4 clean quit:** disconnected via Ctrl+Alt+Shift+Q → back to the Steam library (tile shows
**Last Played Today / 1 min**), **0 orphan procs** client-side; host confirmed
`sunshine_wgc_capture` **exited cleanly** (session STOP). No orphan session either side. ✓

## 4. Teardown

Closed Steam → **restored the original shortcuts.vdf** from the safety backup →
md5 back to **`a035e3137b…` (byte-identical to baseline, size 4783)**; `--list` = 0 managed.
Removed the 6 sync-created grid-art orphans (stashed for safety). Restarted Steam → library
visually clean, UNCATEGORIZED count 75/76 → **72/73** (the 3 test tiles gone), pre-existing
Vibemis/Moonlight shortcuts intact. ✓

## 5. Other findings

- Steam rewrites shortcuts.vdf from memory on exit — the intermediate post-apply file differed
  from the raw script bytes (`6bde1f14…` → Steam's `c3b4d98a…`) but the restore returns the exact
  original. The Steam-must-be-closed guard is therefore load-bearing and correctly enforced.
- Idempotent re-apply reports "3 updated" (not "0 changes") but the bytes are identical — no
  duplicate tiles, no churn. Cosmetic wording only.
- Grid-art files carry their **source** mtime (May 28 cache), so a mtime-only diff misses them;
  the grid dir's own mtime (= apply time) is the reliable "did the sync add art" signal.

## 6. Recommendation

**MERGE.** Full BL-1786 lifecycle proven end-to-end — safe dry-run, guarded + readback-verified
apply, idempotency, real one-click Vibepollo session (host-confirmed start *and* stop), and a
byte-identical backup-restore teardown. `shortcuts.vdf` integrity held throughout.
