# Test17 Report — Two-Stage OTP: Gate Works, Challenge Still Fails

**Artifact tested:** `Vibemis.AppImage`
**md5:** `51569dac37f6c277dc808149cf614fb7`
**Build:** `0.6.7-hotfix.20260529.0043+c3918cb` (contains `0b45984b` two-stage OTP fix + `c3918cb` log clarity)
**Branch:** `fix/quickmenu-triggers-clipboard-ssl-defaults` (commit `c3918cb`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0
**Test date:** 2026-05-29
**Prior report:** `testing/test16-otp-pairing-complete/report.md`

---

## 1. TL;DR

| Check | Status | Summary |
|---|---|---|
| 1 — OTP two-stage pairing | PARTIAL | Gate works ✅; `clientchallenge` fails ❌; offline regression on cold start |
| 2 — Video regression | BLOCKED | No stream |
| 3 — Quick Menu | BLOCKED | No stream |
| 4 — Clipboard | BLOCKED | No stream |
| 5 — Bubbles | BLOCKED | No stream |

---

## 2. Check 1 — OTP Pairing

### Two runs performed. Both failed, for different reasons.

---

### Run 1 — Cold start: host stuck offline (regression from `0b45984b`)

App started with fresh `settings.ini` (new uniqueid `STEAMDECB1E0384A`). Startup sequence:

```
00:00:02 - Discovered mDNS host: "Navid-PC.local."
00:00:04 - "Navid-PC" is now offline
00:00:05 - getServerInfo response: status_code=200, PairStatus=0   ← HTTP OK, host responding
00:00:05 - Apollo server permissions: "0x0" (0)
00:00:05 - getServerInfo HTTPS response: status_code=401,
           status_message="The client is not authorized. Certificate verification failed."
```

Log froze at 129 lines after the 401 — no "Navid-PC is now online," no further polling. Multiple UI unpair/re-pair attempts produced zero log lines. Host stayed permanently offline; OTP dialog never reachable.

**Root cause:** HTTPS `serverinfo` 401 treated as fatal — host never marked online despite preceding HTTP 200. This is a regression introduced by `0b45984b`. Fix: HTTP 200 + `PairStatus=0` → mark online regardless of HTTPS result. 401 is expected for any unpaired client.

---

### Run 2 — App restarted, host came online, two-stage gate WORKS ✅

On second launch the host appeared online and the OTP dialog opened (PIN `9039`). The two-stage gate — the core fix in `0b45984b` — behaved correctly:

```
00:00:12 - PendingOTPPairingTask: Starting OTP pairing task for "Navid-PC"
00:00:12 - PendingOTPPairingTask: PIN from user: "9039"
00:00:12 - PendingOTPPairingTask: Sending OTP pairing request
00:00:12 - PendingOTPPairingTask: Parsed response — status_code: 200 paired: "1" plaincert present: true
00:00:12 - PendingOTPPairingTask: Pairing accepted, extracting server certificate
00:00:12 - PendingOTPPairingTask: Phase 1 complete — emitting stage1Completed, waiting for user
  ↑ dialog updated with ✓ + Continue button — user entered PIN on Vibepollo web UI
00:00:30 - PendingOTPPairingTask: User clicked Continue — starting challenge exchange (phase 2)
00:00:30 - PendingOTPPairingTask: Generated AES key from salt+PIN
00:00:30 - PendingOTPPairingTask: Sending encrypted client challenge
00:00:30 - /pair?...clientchallenge=A69C95AA5A1D3ED69E347F845E5623D7...
00:00:30 - PendingOTPPairingTask: Client challenge failed
00:00:30 - PendingOTPPairingTask: Full pairing handshake failed
00:00:30 - PcView.pairingComplete called with error: Apollo pairing handshake failed
```

The gate waited **18 seconds** (12→30) — user had time to enter the PIN on Vibepollo before Continue was clicked. That part is correct.

### `clientchallenge` failure — root cause

Vibepollo's phase 1 response always includes `status_message="OTP auth not available."`. This is not just a cosmetic message — it signals that **Vibepollo does not store the PIN** from the `getservercert` `otpauth` hash. When `clientchallenge` arrives (AES-encrypted with `SHA1(salt+PIN)`), Vibepollo cannot derive the decryption key because it never recorded the PIN. The challenge fails regardless of whether the user enters the PIN in the web UI.

The "Pair Client" web form in Vibepollo appears to be a different code path that does not feed into the Moonlight 4-phase challenge exchange.

### Fix needed (for build agent)

The fundamental mismatch: Vibemis uses the standard Moonlight PIN-derived AES challenge, but Vibepollo's Apollo OTP implementation does not support that path (`status_message="OTP auth not available."`).

Two possible approaches:
1. **Adapt to what Vibepollo actually supports:** Investigate what Vibepollo's "Pair Client" web form actually does — does it use a PIN at all, or a different pairing token? Match the client's phase 2 to that mechanism.
2. **Skip phases 2-4 entirely for Apollo:** If Vibepollo treats `getservercert` → `paired=1+plaincert` as a complete pairing (not requiring the 4-phase challenge), skip `clientchallenge` / `serverchallengeresp` / `clientpairingsecret` and call pairing complete after phase 1. Verify that streaming then works.

The `paired=1` in the phase 1 response may itself be the pairing-complete signal for Apollo.

---

## 3. Checks 2–5 — Video, Quick Menu, Clipboard, Bubbles

All **BLOCKED** — no stream possible while pairing fails.

`FORCE_VAAPI=1` hook confirmed present at startup — no regression there.

---

## 4. Recommendation

**ITERATE** — two issues for the build agent:

1. **Cold-start offline regression** (`0b45984b`): HTTP 200 + `PairStatus=0` must mark host online regardless of HTTPS 401. Only gate online status on HTTPS when `PairStatus=1`.

2. **`clientchallenge` fails — Vibepollo OTP mismatch:** Vibepollo's `status_message="OTP auth not available."` means it never stores the PIN for AES key derivation. Either adapt phase 2 to Vibepollo's actual pairing mechanism, or — if `paired=1+plaincert` in phase 1 is already the Apollo pairing-complete signal — skip phases 2-4 and complete pairing after phase 1 alone. Investigate Vibepollo source to confirm.
