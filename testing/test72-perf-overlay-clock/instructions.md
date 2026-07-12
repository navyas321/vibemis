# test72 — Show clock in the performance overlay

**Feature:** A new Settings toggle, *"Show clock in the performance overlay"*, that adds a
wall-clock `Time: HH:MM:SS` line to the **top** of the performance/stats overlay shown while
streaming. Off by default (the overlay is unchanged for existing users). Useful on a handheld in
Game Mode, where the system clock is hidden during a stream.

**Phase:** P3.6 / P3.8 performance-overlay customization family (mirrors test24 / test49 / test50 /
test59 — all customize the same overlay).

**Branch:** `test72-perf-overlay-clock`  ·  **Base:** `vibemis-main`  ·  **PR:** see checklist.

---

## 0. Setup / environment

```bash
# Newest 🔬 alpha pre-release for this branch, OR the committed AppImage if present.
APP=~/Downloads/Vibemis-x86_64.AppImage
md5sum "$APP"
echo "== env =="; grep VERSION= /etc/os-release; glxinfo 2>/dev/null | grep -i "OpenGL version" || true
```
Record the md5, SteamOS version, and Mesa/GL version in the report.

---

## Tier 1 — launcher-only (no host/stream needed) — REQUIRED

Goal: the new setting **renders** in Settings and **persists** across a relaunch.

### 1a. Headless smoke + settings round-trip (selftest)
```bash
"$APP" selftest --json 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print("result:",d["result"])'
# expect: result: PASS  (exit 0)
```

### 1b. Control renders
Launch the app, open **Settings**, scroll to the group that contains *"Show performance stats
while streaming"*. Confirm a new checkbox directly beneath it:
**"Show clock in the performance overlay"**.
- It should be **disabled (greyed out)** while *"Show performance stats while streaming"* is
  unchecked, and become **enabled** once you check the performance-stats box.
- Capture a screenshot:
  - Desktop Mode: `spectacle -b -n -a -o /tmp/test72-settings.png`
  - Game Mode: **Super+S** → `/tmp/gamescope_*.png`

### 1c. Persistence
1. Check *"Show performance stats while streaming"*, then check
   *"Show clock in the performance overlay"*. Fully quit the app.
2. Confirm the key was written:
   ```bash
   grep -i "perfoverlayclock" ~/.config/Vibemis/Vibemis.conf 2>/dev/null \
     || grep -ri "perfoverlayclock" ~/.config/Vibemis* 2>/dev/null
   # expect: perfoverlayclock=true
   ```
3. Relaunch → Settings → confirm both boxes are still checked.

**Tier-1 PASS** = selftest PASS + checkbox present with the correct enabled/disabled behaviour +
`perfoverlayclock=true` persisted + still checked after relaunch.

---

## Tier 2 — in-stream (needs a paired host) — OPTIONAL / mark N/A if no host

Goal: the clock line actually appears in the overlay during a stream.

1. With both boxes checked, start a stream to a paired Apollo/Vibepollo host.
2. Ensure the performance overlay is visible (toggle with **Ctrl+Alt+Shift+S** or
   **Select+L1+R1+X** if needed).
3. Confirm the **first line** of the overlay reads `Time: HH:MM:SS` and the seconds advance.
4. Capture a screenshot (Super+S) and paste the path.
5. Uncheck only the clock box (leave stats on), confirm the `Time:` line disappears while the rest
   of the stats remain.

If no host is available, mark Tier 2 **N/A** — Tier 1 is sufficient to verify the setting wiring.

---

## What to report
TL;DR table (Tier 1 / Tier 2 → PASS / FAIL / N-A), the md5 + env, the two screenshots, the
`perfoverlayclock=` grep line, and any `SEGV`/`Critical` seen in a bounded run log
(`timeout 25s "$APP" >/tmp/run.log 2>&1`; grep `-iE "EGLRenderer|error|SEGV"`).
File `report.md` on `diagnostic/test72-perf-overlay-clock-report`, tick the test72 row in
`testing/TEST_CHECKLIST.md` in the same commit, and open the report PR against this branch.
