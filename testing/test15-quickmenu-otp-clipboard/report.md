# Test15 Report — Quick Menu Visible, OTP Pairing, Clipboard

**Artifact tested:** `Vibemis.AppImage` (`0.6.7-hotfix.20260528.2314+ea7223f`)
**md5:** `5890ce99e609fb08bd18b53bf7d71e96` ✓ verified
**Branch:** `fix/quickmenu-triggers-clipboard-ssl-defaults` (commit `ea7223f`, branch HEAD `dcff131`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0
**Test date:** 2026-05-28
**Prior report:** `testing/test14-triggers-clipboard-ssl-defaults/report.md`

---

## 1. TL;DR

| Check | Status | Summary |
|---|---|---|
| 1 — Video regression | BLOCKED | Device unpaired before stream; no stream attempted |
| 2 — Quick Menu keyboard trigger | BLOCKED | Requires streaming |
| 3 — Quick Menu gamepad trigger | BLOCKED | Requires streaming |
| 4 — Quick Menu actions | BLOCKED | Requires streaming |
| 5 — OTP pairing | PARTIAL | Dialog shows ✓; client generates PIN + sends `otpauth` hash ✓; client rejects server's `paired=1` response due to `status_message="OTP auth not available."` — **client-side bug** |
| 6 — Clipboard upload/fetch | BLOCKED | Requires streaming |
| 7 — Server Commands / Bubbles | BLOCKED | Requires streaming |

**Root blocker:** `PendingOTPPairingTask` rejects a valid server response (`paired=1` + full cert).
All streaming-dependent checks are blocked until pairing succeeds.

---

## 2. Checks 1–4, 6, 7 — BLOCKED

After unpairing Navid-PC for Check 5, OTP pairing failed to complete (see below). With no paired
host, streaming could not be started. All checks that require an active stream are blocked.

VAAPI hook confirmed active from app startup:
```
[vibemis-apprun] FORCE_VAAPI=1 (host DRI: /usr/lib64/dri)
```

---

## 3. Check 5 — OTP Pairing

**Result: PARTIAL — dialog correct, client rejects valid server response.**

### What is working (new in this build)

1. **OTP dialog appears** — `PendingOTPPairingTask` is now invoked instead of the classic PIN flow.
   The dialog generates a random 4-digit PIN, shows it prominently, and fires the pairing request
   immediately. This is the correct direction (client-generated PIN).

2. **Client sends `otpauth` hash** — the request URL includes `&otpauth=SHA256(pin+salt)` in addition
   to the standard `phrase=getservercert&clientcert=...` parameters.

### What is broken

Vibepollo 7.1.431 responds with `status_code=200, status_message="OTP auth not available."` **and**
`paired=1` with a full `plaincert`. The server completed the cert-exchange pairing; it simply does
not validate the `otpauth` extension parameter.

`PendingOTPPairingTask` sees `"OTP auth not available"` in the `status_message` and rejects the
entire pairing — discarding the cert even though `paired=1` and a valid cert were returned:

```
PendingOTPPairingTask: Received response:
  <root status_code="200" status_message="OTP auth not available.">
    <paired>1</paired>
    <plaincert>2D2D2D2D2D...  (full cert present)
  </root>

PendingOTPPairingTask: OTP pairing failed - OTP not available
PcView.pairingComplete called with error: OTP is not available or has expired.
  Please generate a new OTP on the Apollo server.
```

**22 attempts were made.** On odd-numbered attempts the server returned `paired=1` (client discards
it). On even-numbered rapid retries the server returned `400: "Out of order call to getservercert"`
because the previous session was still open:

```
PendingOTPPairingTask: Received response:
  <root status_code="400" status_message="Out of order call to getservercert">
    <paired>0</paired>
  </root>
```

The `"Out of order"` errors are a secondary symptom of the rapid-retry loop triggered by the
client rejecting the first response.

### Root cause and fix

`PendingOTPPairingTask` must accept `status_code=200` + `paired=1` + `plaincert` as a successful
pairing regardless of `status_message`. The `"OTP auth not available"` message from Vibepollo
7.1.431 means the server completed standard cert-exchange pairing without running the `otpauth`
SHA256 extension verification — it is not a pairing failure.

**Suggested fix in `PendingOTPPairingTask`:**

```
if (paired == 1 && !plaincert.isEmpty()) {
    // Server accepted the pairing (may not support otpauth extension).
    // Proceed with cert regardless of status_message.
    proceedWithCert(plaincert);
} else if (statusMessage.contains("OTP auth not available")) {
    // paired=0 AND OTP not available → genuine failure
    emit pairingFailed("OTP is not available ...");
}
```

---

## 4. Other findings

- **Rapid-retry "Out of order" loop.** When the dialog re-shows after each failure, clicking
  Navid-PC immediately fires a new `getservercert` before the server's previous session expires
  (~3 s window). Result: alternating `200/paired=1` and `400/Out of order` responses in a loop.
  The client should back off at least 5 seconds between retries, or disable re-triggering while a
  pairing session is in flight.

- **No classic "Pair" fallback visible.** The context menu only shows "Pair using OTP" for Apollo
  servers (`isApolloServer=true`). With OTP broken, there is no in-app workaround to re-pair.
  Consider keeping a hidden "Pair (classic)" item or a settings override for diagnostics.

---

## 5. Recommendation

**ITERATE — single blocking bug.**

Fix `PendingOTPPairingTask` to accept `paired=1 + plaincert` as success when
`status_message="OTP auth not available."`. That unblocks all remaining checks (1–4, 6, 7) in
the next build. Once pairing succeeds, the Quick Menu visibility fix, clipboard 403 fix, and
Server Commands path from `ea7223f` can all be verified.
