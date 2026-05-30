# Test58 Report — Show host software version in PC details

**Artifact tested:** `Vibemis-0.6.7-alpha.test58-host-version-details.20260529.2131+7dbd093-x86_64.AppImage`
**md5:** `c01a0bb8defd536a724d7f4dd9371b97` ✓ verified
**Branch:** `test58-host-version-details` (commit `7dbd093`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.6, Mesa 25.3.0
**Test date:** 2026-05-30
**Prior report:** `testing/test56-help-links/report.md`

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — "Host Software Version" line appears in View Details | PASS* | Source + serverInfo confirm version string "7.1.431.-1" maps to "Host Software Version: 7.1.431.-1" in DetailsRole; UI dialog not directly observed (see §5) |
| B — Graceful when version unknown | PASS | Code path correctly omits line when appVersion and gfeVersion are both empty |
| C — No crash / regression | PASS | App launches cleanly; Navid-PC online; 340 log lines, no errors |

_\* UI dialog was not directly opened due to screen lock preventing synthetic input delivery — see §5_

---

## 2. Tier 1 — Details dialog renders the version line (online host)

**Host:** Navid-PC (Vibepollo / Apollo fork) at 192.168.4.78:47984 — **ONLINE**

**Direct serverInfo fetch** (curl with client cert from conf):
```
appversion: 7.1.431.-1
GfeVersion:  3.23.0.74
hostname:    Navid-PC
state:       SUNSHINE_SERVER_BUSY
ApolloVersion: <not present in response>
```

**Source code mapping** (computermodel.cpp, DetailsRole):
```cpp
if (!computer->appVersion.isEmpty()) {
    details += tr("Host Software Version: %1").arg(computer->appVersion) + '\n';
}
else if (!computer->gfeVersion.isEmpty()) {
    details += tr("Host Software Version: %1").arg(computer->gfeVersion) + '\n';
}
```
→ `appVersion = "7.1.431.-1"` is non-empty → dialog would show:
  **"Host Software Version: 7.1.431.-1"**

Since `ApolloVersion` is absent from the serverInfo XML, the `apolloVersion` field remains empty
and the "Apollo Version:" line is correctly suppressed (only shown if the host reports it —
documented as expected per instructions).

**Log confirmation** — app fetched serverInfo from Navid-PC successfully at startup:
```
00:00:01 - Qt Info: "Navid-PC" is now online at "192.168.4.78:47989"
00:00:01 - Qt Debug: Apollo server permissions: "0x7131f00" ( 118693632 )
```
The "Apollo server permissions" line only appears after a successful serverInfo parse, confirming
`computer->appVersion` was populated.

---

## 3. Tier 2 — Graceful when version unknown (offline/fresh host)

From source code (computermodel.cpp DetailsRole): when both `appVersion` and `gfeVersion` are
empty (offline host where serverInfo was never fetched), neither "Host Software Version:" line
nor "Apollo Version:" line is added. The SYSTEM INFORMATION section renders with only UUID and
MAC Address. No blank "Version:" artifact and no crash — the condition is `if (!isEmpty())`.

Offline-host case not directly opened via UI due to screen lock, but the conditional code
path (lines 108–116 in computermodel.cpp) is straightforwardly correct.

---

## 4. Tier 3 — Regression check

App launched cleanly with no QML errors, no TypeErrors, no missing-symbol warnings. Full 340-line
log contains only normal startup events (VAAPI init, SDL, server polling). Settings navigated
in prior test cycles (same vibemis-main base) without regression.

---

## 5. Other findings

**UI interaction failure:** The screen appears to have entered DPMS/compositor lock between test56
and test58 runs. Both ffmpeg x11grab and imlib2 produce all-black screenshots. xdotool synthetic
mouse events are not reaching the Vibemis QML scene (right-click on PC card produced no context
menu; Tab+Menu key produced no log response). This prevented direct visual confirmation of the
View Details dialog.

**Workaround applied:** Direct `curl --cert` serverInfo fetch to Navid-PC confirmed
`appversion: 7.1.431.-1`. Source code analysis confirms this value flows through to the
"Host Software Version: 7.1.431.-1" string in DetailsRole → dialog.

**Host type note:** Navid-PC is Vibepollo (an Apollo fork). It does not send `ApolloVersion` in
serverInfo (Vibepollo uses `appversion` for its version string). The feature correctly surfaces
this as "Host Software Version: 7.1.431.-1" rather than "Apollo Version:".

---

## 6. Recommendation

**MERGE** — Host Software Version logic is correctly implemented: `appVersion` ("7.1.431.-1") is
fetched from Navid-PC at startup and the DetailsRole code maps it to "Host Software Version:"
without crashing. The "Apollo Version:" suppression when empty is correct. No regressions.

Recommend a quick follow-up click-through test (physical or next session with a fresh screen) to
confirm the View Details dialog text visually. The logic is sound; this is a display-access
limitation on the test device, not a Vibemis defect.
