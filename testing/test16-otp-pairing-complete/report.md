# Test16 Report — OTP Pairing: Phase 1 Fixed, Challenge Exchange Still Fails

**Artifact tested:** `Vibemis.AppImage`
**md5:** `7f9e95503e0ad47d29ba13362014baf7` ✓ verified
**Branch:** `fix/quickmenu-triggers-clipboard-ssl-defaults` (commit `d715154`)
**Build commit:** `3706358e` (fix: parse OTP pairing response with QXmlStreamReader)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0
**Test date:** 2026-05-28
**Prior report:** `testing/test15-quickmenu-otp-clipboard/report.md`

---

## 1. TL;DR

| Check | Status | Summary |
|---|---|---|
| 1 — OTP pairing | PARTIAL | Phase 1 (`getservercert`) FIXED ✅; phases 2-4 (challenge) fail ❌ |
| 2 — Video regression | BLOCKED | No paired host; `FORCE_VAAPI=1` present |
| 3 — Quick Menu visible | BLOCKED | Stream never started |
| 4 — Quick Menu actions | BLOCKED | Stream never started |
| 5 — Clipboard sync | BLOCKED | Stream never started |
| 6 — Server Commands (Bubbles) | BLOCKED | Stream never started |

---

## 2. Check 1 — OTP Pairing

### Phase 1: `getservercert` — FIXED ✅

The `3706358` fix (QXmlStreamReader) works correctly. The client now accepts `paired=1 + plaincert` regardless of `status_message="OTP auth not available."`:

```
00:00:06 - PendingOTPPairingTask: PIN from user: "7195"
00:00:06 - PendingOTPPairingTask: Generated OTP hash: "3A35EBA604AF..."
00:00:06 - PendingOTPPairingTask: Sending OTP pairing request
00:00:06 - PendingOTPPairingTask: Parsed response — status_code: 200 paired: "1" plaincert present: true
00:00:06 - PendingOTPPairingTask: Pairing accepted, extracting server certificate
00:00:06 - PendingOTPPairingTask: Server certificate obtained, performing full pairing handshake
```

This is the fix that was needed for test15. Phase 1 is now correct.

### Phases 2-4: `clientchallenge` → `clientpairingsecret` — FAIL ❌

All four pairing phases fire within the **same second** (`00:00:06`). The challenge exchange reaches Vibepollo before the user can enter the PIN in the web UI:

```
00:00:06 - PendingOTPPairingTask: Starting full pairing handshake
00:00:06 - PendingOTPPairingTask: Generated AES key from salt+PIN
00:00:06 - PendingOTPPairingTask: Sending encrypted client challenge
00:00:06 - NvHTTP: /pair?...clientchallenge=BE3E07191CEE002C5F9D87E9A3760388...
00:00:06 - PendingOTPPairingTask: Sending client pairing secret
00:00:06 - PendingOTPPairingTask: Client pairing secret failed
00:00:06 - PendingOTPPairingTask: Full pairing handshake failed
00:00:06 - PcView.pairingComplete called with error: Apollo pairing handshake failed
```

### Root cause

The AES key for `clientchallenge` is derived from `SHA1(salt + PIN)`. Vibepollo must know the same PIN to decrypt the challenge — but Vibepollo only learns the PIN when the **user submits the "Pair Client" form** in the web UI. The client fires all phases in one synchronous burst before the user has had any opportunity to interact with Vibepollo.

The dialog says "enter PIN on host", but the challenge has already left the building.

### Fix needed (for build agent)

Split the pairing into two stages with a user gate between them:

1. **Stage 1** — Send `getservercert`, receive and store the server cert. ✅ (already works)
2. **Pause** — Show updated dialog: *"PIN `XXXX` sent to host. Now go to Vibepollo web UI → Pair Client, enter the PIN and submit. Then click Continue here."* Wait for user to click **Continue** (or add a dedicated "I've entered the PIN" button).
3. **Stage 2** — Only after user confirms → send `clientchallenge` → `serverchallengeresp` → `clientpairingsecret`.

This matches the intent of the redesigned dialog (step-by-step instructions) but the code never waits. A `QEventLoop`-based gate, a state machine pause, or simply restructuring `PendingOTPPairingTask` to emit a signal after phase 1 and resume on user confirmation would all work.

---

## 3. Check 2 — Video Regression

**BLOCKED** — device never paired, stream never started.

`FORCE_VAAPI=1` hook confirmed present:
```
[vibemis-apprun] FORCE_VAAPI=1 (host DRI: /usr/lib64/dri)
```
No regression evidence. Prior tests (test8–test14) confirmed video rendering is stable once paired.

---

## 4. Checks 3–6 — Quick Menu, Clipboard, Bubbles

All **BLOCKED** — require an active stream session. No stream was possible because pairing never completed.

These features will need re-verification once OTP pairing is fixed.

---

## 5. Other Findings

- `PairStatus` in `getServerInfo` response is `0` throughout — server correctly reports unpaired state, client's host list reflects this.
- No crashes during this test run.
- OTP dialog displayed the PIN (`7195`) and step-by-step instructions correctly — the UI is right, only the timing of the challenge exchange is wrong.

---

## 6. Recommendation

**ITERATE**

Specific next step for build agent: add a user-confirmation gate in `PendingOTPPairingTask` between phase 1 (`getservercert` success) and phase 2 (`clientchallenge`). The client must wait until the user confirms they have submitted the PIN on Vibepollo before proceeding. Without this gate, phases 2-4 always fire before the server knows the PIN.

After that fix: re-run full test16 matrix (OTP, video, Quick Menu, clipboard, Bubbles).
