# Test24 Instructions — Compact performance overlay (Phase 6 / P3.6)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify the new **"Compact performance overlay"** setting renders the stream stats as a
single legible line instead of the full multi-line block.

---

## Background

The performance overlay (toggled with **Ctrl+Alt+Shift+S** / **Select+L1+R1+X**) normally shows a
verbose multi-line block. A new Settings checkbox, **"Compact performance overlay"** (under
*"Show performance stats while streaming"*), switches it to one compact line:

```
60 fps · 1920x1200 HEVC · net 8 ms · dec 3.2 ms · drop 0.1%
```

This uses the existing, already-working stats overlay path (`OverlayDebug`) — independent of
the Quick Menu work in test22.

> **Requires a stream** to see live stats. Host must already be paired (do not pair if not).

---

## Artifact

**AppImage:** `testing/test24-compact-perf-overlay/Vibemis-0.6.7-vibemis-test24-compact-perf-overlay-x86_64.AppImage`
**md5:** `dcb97c2bac953a634f9b4f6220a6a4b3`

```bash
md5sum testing/test24-compact-perf-overlay/*.AppImage
```

---

## Setup

```bash
cd ~/vibemis
git fetch origin test24-compact-perf-overlay
git checkout test24-compact-perf-overlay && git pull
chmod +x testing/test24-compact-perf-overlay/*.AppImage
./testing/test24-compact-perf-overlay/*.AppImage --appimage-extract-and-run > ~/test24.log 2>&1 &
```

---

## Tier 1 — Compact line renders

1. In **Settings**, enable **"Show performance stats while streaming"**.
2. Below it, tick **"Compact performance overlay"**. (It should be greyed out until the
   "Show performance stats" box above is checked — confirm that enable/disable behaviour.)
3. Connect to the paired host and **start a stream**.
4. The overlay should be visible (top-left). Confirm it is a **single compact line** like
   `NN fps · WxH CODEC · net N ms · dec N.N ms · drop N.N%`, **not** the multi-line block.
5. Toggle it off/on with **Ctrl+Alt+Shift+S** — confirm toggling still works.

---

## Tier 2 — Verbose mode unchanged (regression)

1. End the stream. In Settings, **untick** "Compact performance overlay" (leave "Show
   performance stats" on).
2. Stream again, ensure the overlay shows the **full multi-line block** as before
   (Video stream / Incoming frame rate / Decoding / dropped frames / latencies).

---

## Tier 3 — Persistence

1. Tick "Compact performance overlay", fully quit Vibemis, relaunch.
2. Confirm the checkbox is **still ticked** (setting persisted) and a stream shows the compact line.

---

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | "Compact performance overlay" checkbox present under the stats toggle | Yes |
| 2 | Checkbox disabled until "Show performance stats" is on | Yes |
| 3 | Compact mode shows a single stats line while streaming | Yes |
| 4 | Ctrl+Alt+Shift+S still toggles the overlay | Yes |
| 5 | Unticking restores the full multi-line overlay | Yes |
| 6 | Setting persists across an app restart | Yes |

Include a photo/description of the compact line and the SteamOS + Mesa version.

---

## Report format

Commit `testing/test24-compact-perf-overlay/report.md` on
`diagnostic/test24-compact-perf-overlay-report`; open a PR targeting `test24-compact-perf-overlay`.

---

## Safety rules (standing, with streaming exception for this cycle)
- No package installs, no `sudo` outside read-only inspection; do not modify the AppImage
- Streaming authorized; pairing is not — if host isn't paired, stop and report
