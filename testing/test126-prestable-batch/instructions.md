# Test126 Instructions — pre-stable batch: security fixes + host badge + auto-reconnect (BL-2062/2063/2067/2008/2072)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** verify a batch of pre-0.2.0-stable fixes compiled and behave. Most are code-review /
launcher checks; one (host badge) wants an on-device confirm.

## What's in this batch
- **BL-2062** (security) — OTP PIN/passphrase/pairing material no longer written to debug logs.
- **BL-2063** (security) — clipboard sync pins the paired cert (was `VerifyNone` MITM); fail-closed unpaired.
- **BL-2067** (security) — `pairingFailed()` UI string no longer embeds the raw server response.
- **BL-2008** (correctness) — host badge detects Vibepollo by `<Permission>`-tag presence (was
  mislabeling an unpaired Vibepollo host as "Sunshine") + inits a previously-uninitialized field.
- **BL-2072** (bug) — auto-reconnect now has a Settings toggle and **defaults ON** (Android parity,
  per docs/PHASE_STATUS.md); it was shipped unreachable (no toggle, default off).

**Alpha:** `0.2.0-alpha.019` — asset `Vibemis-0.2.0-alpha.019-x86_64.AppImage`
**md5:** `9cc19220156b677c53d5eb7b6f22caef`
**sha256:** `a36602b6e863b6b4c074d0e59c6aec1835e856872a16c81d95f65ad905cd0a07`

> **NOTE:** this batch is ALREADY MERGED to vibemis-main (d7b99677) and is in the **0.2.0-rc**.
> Run this as a **post-merge regression gate** — a PASS confirms the RC's auto-reconnect toggle
> (BL-2072) + Vibepollo host-badge (BL-2008) + the security redactions behave on-device.

## Test procedure

### Tier 0 — integrity + boot
md5/sha256 exact vs dispatch; `selftest --json` PASS exit 0.

### Tier 1 — auto-reconnect toggle (launcher, no stream)
1. Settings → find "Automatically reconnect if the stream drops" (new row near "Quit app on host
   PC after ending stream"). It must be **present** and **checked by default** (fresh config).
2. Toggle off → quit → relaunch → still off (persists). Toggle back on → persists.

### Tier 2 — host badge (needs a paired + an unpaired Vibepollo host if available)
1. On the PC list, the Vibepollo host (Navid-PC) shows the **Vibepollo** badge (not "Sunshine"),
   both before and after pairing. (The pre-BL-2008 bug: unpaired Vibepollo showed "Sunshine".)
2. No garbage/flicker badge at cold startup (the uninitialized-field fix).

### Tier 3 — security fixes (mostly code-verified; light launcher checks)
1. BL-2062: after an OTP pairing attempt, the debug log shows redacted PIN/passphrase
   (`[redacted, N digits/chars]`), never the raw values.
2. BL-2067: force a pairing failure (wrong PIN) → the error dialog shows a generic message, not a
   raw server-response blob.
3. BL-2063: clipboard sync to the paired host still works (cert pin accepts the genuine cert).

## What to check and report
Per-fix results. Auto-reconnect default-ON + toggle presence is the key new user-facing change.
Any badge mislabel or clipboard-sync failure is report-worthy.

## Report
`testing/test126-prestable-batch/report.md` on `diagnostic/test126-prestable-batch-report`,
PR targets `test126-prestable-batch`.

## Safety rules (standing)
No sudo/installs; don't modify the AppImage; streaming only where a tier requires it.
