# Test17 Report — Two-Stage OTP: Regression — Host Stuck Offline After HTTPS 401

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
| 1 — OTP two-stage pairing | FAIL | Host stuck "offline" — new regression, never reaches OTP dialog |
| 2 — Video regression | BLOCKED | No stream |
| 3 — Quick Menu | BLOCKED | No stream |
| 4 — Clipboard | BLOCKED | No stream |
| 5 — Bubbles | BLOCKED | No stream |

---

## 2. Check 1 — OTP Pairing

### Regression: host permanently offline after HTTPS 401

App never reached the OTP dialog. Startup sequence:

```
00:00:02 - Discovered mDNS host: "Navid-PC.local."
00:00:04 - "Navid-PC" is now offline
00:00:05 - getServerInfo response: status_code=200, PairStatus=0   ← HTTP OK, host responding
00:00:05 - Apollo server permissions: "0x0" (0)
00:00:05 - getServerInfo HTTPS response: status_code=401,
           status_message="The client is not authorized. Certificate verification failed."
```

After the HTTPS 401 the log goes completely silent — 129 lines total, no further polling, no "Navid-PC is now online." Multiple user unpair/re-pair attempts in the UI produced zero additional log lines; the host remained stuck "offline."

### Root cause

The HTTPS `serverinfo` request returns **401** because the client's new uniqueid (`STEAMDECB1E0384A`, freshly generated after `settings.ini` deletion) has no trusted cert relationship with Vibepollo. This is expected and correct server behaviour for an unpaired client.

The regression: the app treats this 401 as a terminal "host offline" signal rather than a "not paired yet, mark online and allow pairing." The HTTP 200 (`PairStatus=0`) that preceded it is ignored. The polling loop stops entirely.

This did **not** occur in test16 (`3706358`): that build reached the OTP dialog successfully from the same unpaired starting state. The two-stage OTP refactor in `0b45984b` introduced this regression.

### uniqueid rotation side-note

Deleting `settings.ini` regenerates the uniqueid (test16: `STEAMDEC03B47104` → test17: `STEAMDECB1E0384A`). The client cert in `Vibemis.conf` is from 2026-05-26 and was not regenerated. This uniqueid/cert mismatch amplifies the 401, but the underlying bug is that 401 on HTTPS `serverinfo` should not prevent the host from appearing online for pairing purposes.

---

## 3. Checks 2–5 — Video, Quick Menu, Clipboard, Bubbles

All **BLOCKED** — no stream session possible while host is stuck offline.

`FORCE_VAAPI=1` hook confirmed present at startup — no regression there.

---

## 4. Recommendation

**ITERATE** — one regression to fix before the full feature matrix can be verified:

**Fix needed in `PendingOTPPairingTask` / host-polling code:** When HTTP `serverinfo` returns 200 with `PairStatus=0`, the host must be marked **online** regardless of the HTTPS `serverinfo` result. A 401 on the HTTPS endpoint is expected for any unpaired client — it means "cert not trusted yet," not "host unreachable." The host should show as online/unpaired and allow the OTP dialog to open.

Suggested check: if `http_status == 200 && PairStatus == 0` → mark online, proceed to OTP flow. Only use HTTPS `serverinfo` result to determine online status when the client is already paired (`PairStatus == 1`).

After that fix: re-run full test17 matrix (OTP two-stage, video, Quick Menu, clipboard, Bubbles).
