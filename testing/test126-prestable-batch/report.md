# Test126 Report — pre-stable batch: security + host-badge + auto-reconnect (BL-2062/2063/2067/2008/2072)

**Artifact tested:** `Vibemis-0.2.0-alpha.019-x86_64.AppImage` (== `0.2.0-rc.001` code)
**md5:** `9cc19220156b677c53d5eb7b6f22caef` ✓ · **sha256:** `a36602b6e863b6b4…` ✓ · selftest PASS.
**Branch:** `test126-prestable-batch` (report off `f0ea1583`) · **Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5
**Test date:** 2026-07-16 · **Role:** post-merge RC regression gate (batch already in vibemis-main + rc.001)

---

## 1. TL;DR

| Item | Status | Evidence |
|---|---|---|
| BL-2072 auto-reconnect toggle present + default-ON + persists | **PASS** | Tier 1 |
| BL-2008 Vibepollo host-badge (not "Sunshine"), no flicker | **PASS** | Tier 2 |
| BL-2062 PIN/passphrase redacted in logs | **PASS** | Tier 3.1 |
| BL-2067 generic pairing-failure string (no raw server blob) | **PASS** | Tier 3.2 |
| BL-2063 clipboard cert-pin doesn't break clipboard sync | **NOT EXERCISED** | code-verified; full round-trip needs a stream (§4) |

**Device side of 0.2.0-rc.001 validated.** Tier 0: md5/sha256 exact, selftest
`{"failures":0,"result":"PASS"}` exit 0.

---

## 2. Tier 1 — BL-2072 auto-reconnect (launcher)

The toggle **"Automatically reconnect if the stream drops"** is present under **Settings →
Streaming → Host Settings**, directly below "Quit app on host PC after ending stream" (tooltip:
"If a stream ends unexpectedly … Vibemis will try to reconnect automatically").

1. **Default-ON (fresh config).** My long-lived config carries the legacy `autoreconnect=false`
   (written by the pre-BL-2072 build, which shipped the feature unreachable + off), so it correctly
   reads OFF. Verified the true default on a **fresh, isolated config** (throwaway
   `XDG_CONFIG_HOME`): the toggle shows **ON** and the app wrote **`autoreconnect=true`**. Confirmed
   against source — `streamingpreferences.cpp:204` reads `settings.value(SER_AUTORECONNECT, true)`
   (default `true`). **PASS.**
2. **Persistence both directions.** Legacy OFF persisted across many relaunches; toggling **ON** →
   Back (wrote `autoreconnect=true`) → quit → relaunch → still **ON**. **PASS.** (Config restored
   to the device's baseline `false` afterward.)

## 3. Tier 2 — BL-2008 host badge

The Navid-PC card shows the **VIBEPOLLO** badge — **PASS in both pairing states**:
- **Paired** (`Paired · Full access`): VIBEPOLLO badge.
- **Unpaired** (fresh-config instance, `Tap to pair`): still **VIBEPOLLO**, *not* "Sunshine" —
  exactly the pre-BL-2008 bug scenario (unpaired Vibepollo mislabeled as Sunshine), now fixed.
No garbage/flicker badge at cold startup (the uninitialized-field fix). **PASS.**

## 4. Tier 3 — security fixes

1. **BL-2062 (PASS).** The Vibemis debug log redacts pairing secrets with a count-only format:
   `PendingOTPPairingTask: PIN from user: [redacted, 4 digits]`,
   `Passphrase from user: [redacted, 0 chars]`, and
   `Executing request: …/pair?[redacted pairing parameters]` — raw PIN/passphrase never appear.
2. **BL-2067 (PASS).** A timed-out OTP pairing surfaced a **generic** dialog —
   "Apollo OTP pairing network error: Request timed out" — with **no** raw server-response blob.
3. **BL-2063 (NOT EXERCISED).** Clipboard sync is enabled in Settings ("Enable clipboard
   synchronization" checked). The cert-pinning fix is code-verified, but a **full clipboard
   round-trip to the paired host was not exercised this cycle** (it needs a live stream + a
   clipboard exchange, and the maintainer was actively using the host). Recommend a quick
   clipboard round-trip on the next stream to close it; no regression observed at the config level.

### Method note (transparency)
The BL-2008-unpaired / BL-2062 / BL-2067 evidence came from a **fresh-config instance** that
auto-discovered Navid-PC; a navigation click landed on Connect and started an OTP pair. I did
**not** enter the PIN — it self-cancelled by timeout, **nothing paired**, and my real
pairing/certs were untouched (the fresh instance used an isolated `XDG_CONFIG_HOME`). The host
confirmed no stray PIN dialog persisted. The side effect happened to give clean on-device runtime
evidence for three of the batch items.

## 5. Recommendation

**MERGE / RC-VALIDATED.** BL-2072 (default-ON + persist), BL-2008 (badge, both states),
BL-2062 and BL-2067 all confirmed on-device against `alpha.019 == rc.001`. Only BL-2063's full
clipboard round-trip remains unexercised (code-verified, non-blocking — a short stream closes it).
Device side of 0.2.0-rc.001 is validated; remaining path is the maintainer RC eyeball +
`CONFIRM-STABLE`.
