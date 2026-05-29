# Test18 Report — Phase 1 Regressed: Removing `otpauth` Breaks Vibepollo Routing

**Artifact tested:** `Vibemis.AppImage`
**md5:** `5af2069525e1fe03a44d209a6150a960`
**Build:** `0.6.7-hotfix.20260529.0128+dda125f` (contains `554f8158` drop-otpauth fix + `dda125fc` dialog label)
**Branch:** `fix/quickmenu-triggers-clipboard-ssl-defaults` (commit `dda125f`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0
**Test date:** 2026-05-29
**Prior report:** `testing/test17-otp-two-stage/report.md`

---

## 1. TL;DR

| Check | Status | Summary |
|---|---|---|
| 1 — Cold start: host online | PASS | No HTTPS 401 freeze; polling every 3s ✅ |
| 2 — Full pairing | FAIL | Phase 1 times out — `otpauth` removal broke Vibepollo routing |
| 3 — Video | BLOCKED | No stream |
| 4 — Quick Menu / Clipboard / Bubbles | BLOCKED | No stream |

---

## 2. Check 1 — Cold Start: Host Online (regression fix from `554f8158`)

**PASS ✅** — Offline regression fixed. With fresh `settings.ini` (new uniqueid `STEAMDEC0443157B`), the app starts cleanly and polls Navid-PC every ~3 seconds via HTTP without freezing:

```
00:00:04 - getServerInfo response: status_code=200, PairStatus=0
00:00:04 - Apollo server permissions: "0x0" ( 0 )
00:00:07 - Apollo server permissions: "0x0" ( 0 )
00:00:10 - Apollo server permissions: "0x0" ( 0 )
```

No HTTPS 401, no stuck-offline. This fix is solid.

---

## 3. Check 2 — Full Pairing

**FAIL ❌** — Phase 1 times out on every attempt (3 tries, 100% failure rate).

### What happens

```
00:00:28 - PendingOTPPairingTask: Sending OTP pairing request
00:00:28 - Executing request: http://192.168.4.78:47989/pair?...phrase=getservercert&salt=...&clientcert=...
           (no otpauth parameter)
00:00:34 - "pair" request failed: QNetworkReply::OperationCanceledError
00:00:34 - PendingOTPPairingTask: Network error: "Apollo OTP pairing network error: Request timed out"
```

Vibepollo never responds. The request hangs for ~6 seconds then times out.

### Root cause

`554f8158` removed `otpauth` from the `getservercert` request to allow "standard Moonlight pairing." But **Vibepollo requires `otpauth` to route the request to its pairing handler.** Without it, the server ignores the request entirely.

Confirmed by comparison:
- **test17** (`c3918cb`, had `otpauth`): Vibepollo responded in < 1 second with `paired=1+plaincert`
- **test18** (`dda125f`, no `otpauth`): Vibepollo never responds, 6-second timeout every time

`otpauth` is not optional — it is the signal Vibepollo uses to dispatch the pairing request.

---

## 4. Checks 3–4 — Video, Quick Menu, Clipboard, Bubbles

All **BLOCKED** — no stream possible while phase 1 fails.

`FORCE_VAAPI=1` hook confirmed present at startup.

---

## 5. Recommendation

**ITERATE** — revert the `otpauth` removal, take the alternative approach.

The two-issue summary across test17 + test18:

| Issue | test17 result | test18 result |
|---|---|---|
| Cold-start offline (HTTPS 401 freeze) | Present | **Fixed** ✅ |
| `otpauth` required by Vibepollo routing | Phase 1 worked | **Broken** — removed `otpauth`, server times out |
| `clientchallenge` fails (server has no PIN) | Present | N/A (never reached) |

**Recommended fix:** keep `otpauth` in `getservercert` (Vibepollo needs it for routing), but after phase 1 returns `paired=1+plaincert`, **skip phases 2-4 entirely for Apollo** and treat phase 1 success as pairing-complete. The `paired=1` response from Vibepollo is the completion signal — the 4-phase challenge handshake is a GFE/standard Moonlight path that Vibepollo explicitly doesn't support (`status_message="OTP auth not available."`).
