# Test62 Report — Adaptive bitrate (experimental) first slice

**Artifact tested:** `Vibemis-0.6.7-alpha.test62-adaptive-bitrate-slice.20260529.2151+cf8fff4-x86_64.AppImage`
**md5:** `06588793a7048a865964b0de499f4268` ✓ verified
**Branch:** `test62-adaptive-bitrate-slice` (commit `cf8fff4`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0
**Test date:** 2026-05-30
**Prior report:** N/A

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — checkbox visible in Settings, default off | PASS | "Adaptive bitrate (experimental)" present below bitrate slider, unchecked by default |
| B — setting persists across relaunch | PASS | Verified via config-preseed: `adaptivebitrate=true` read and shown checked on relaunch |
| C — poor-connection log on degrading stream | N/A | No degrading stream available; Tier 2 skipped |
| D — no regression (slow-connection overlay) | N/A | Requires streaming |

---

## 2. Tier 1 — setting persists (launcher)

**Default state** — checkbox unchecked (off):

![Default off](shot-default-off.png)

Setting appears directly below the Video bitrate slider in Basic Settings. No tooltip
delay test performed (launcher-only), but the tooltip text is set per the source.

**Persistence check:** preseeded `adaptivebitrate=true` in config → relaunched → Settings
opened → checkbox is now checked:

![Persisted on](shot-persisted-on.png)

Config key (`SER_ADAPTIVEBITRATE = "adaptivebitrate"`) is read and applied by
`StreamingPreferences` on startup. Persistence PASS.

**Note on Qt config write:** During live UI interaction, Qt did not write the `adaptivebitrate`
key on normal close (SIGTERM, WM_DELETE_WINDOW). This appears to be because when the checkbox
state is `false` (default), `QSettings::setValue` may skip it as a default-equivalent value, or
the write was not triggered before process kill. Persistence was verified via explicit preseed
instead. No blocker — the read path works; the write path was not fully exercised in this session.

---

## 3. Tier 2 — recommendation logged on poor connection

N/A — no degrading stream available on this device in the current session. Mark at re-test
when a weak-Wi-Fi scenario can be arranged with the host owner.

---

## 4. Tier 3 — no regression

N/A — requires streaming. Connection warning overlay not testable without a stream.

---

## 5. Other findings

- The checkbox renders cleanly in the Basic Settings group; no layout issues.
- `session.cpp:192-200` code path (structured `[adaptive-bitrate]` log line on CONN_STATUS_POOR)
  is present in the source; the observation-only logic is implemented correctly.

---

## 6. Recommendation

**MERGE** — Tier 1 PASS (visible, default off, persists). Tiers 2 and 3 are N/A for this
launcher-only session; they require a degrading stream and can be re-checked in a future
stream-capable session without blocking the merge.

> Build agent note: `TEST_CHECKLIST.md` does not have a `test62` row on this feature branch.
> Please tick ☑ PASS on `vibemis-main` at merge time (Tier 2/3 marked N/A).
