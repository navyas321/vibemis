# Test19 Report — Pairing PASS; Quick Menu Buttons Broken; Clipboard 403 After Restart

**Artifact tested:** `Vibemis.AppImage`
**md5:** `83fb2c9ece7b71aae9dcdf9cca3cba6d`
**Build:** `0.6.7-hotfix.20260529.0144+de8a96f` (commit `de8a96fa` — 120s timeout, no Continue button)
**Branch:** `fix/quickmenu-triggers-clipboard-ssl-defaults` (commit `de8a96f`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0
**Test date:** 2026-05-29
**Prior report:** `testing/test18-pairing-standard-flow/report.md`

---

## 1. TL;DR

| Check | Status | Summary |
|---|---|---|
| 1 — Cold start: host online | PASS ✅ | Online at 00:00:01, no HTTPS 401 freeze |
| 2 — Full OTP pairing | PASS ✅ | All 4 phases succeeded; dialog closed automatically |
| 3 — Video | PASS ✅ | 1920×1200×120, VAAPI, EGLRenderer |
| 4 — Quick Menu visible | PARTIAL | Overlay appears visually; buttons unresponsive |
| 4 — Clipboard upload | PARTIAL | PASS first session; 403 Forbidden after app restart |
| 4 — Clipboard fetch | NOT TESTED | — |
| 4 — Bubbles | NOT TESTED | ENet drops cut sessions short |

---

## 2. Check 1 — Cold Start: Host Online

**PASS ✅**
```
00:00:01 - "Navid-PC" is now online at "192.168.4.78:47989"
00:00:05 - getServerInfo HTTPS response: PairStatus=1  ← paired from prior session
```
No HTTPS 401 freeze. Fix from `554f8158` confirmed working.

---

## 3. Check 2 — Full OTP Pairing

**PASS ✅** — First complete end-to-end pairing across all tests.

Vibepollo held the `getservercert` connection for **24 seconds** while user entered PIN `4005` on the "Pair Client" form. All 4 phases then completed in rapid succession:

```
00:01:41 - PendingOTPPairingTask: PIN from user: "4005"
00:01:41 - Sending getservercert — waiting for PIN entry on host (up to 2 min)
00:02:05 - Parsed response — status_code: 200 paired: "1" plaincert present: true
00:02:05 - Phase 1 complete, firing challenge exchange immediately
00:02:05 - Generated AES key from salt+PIN
00:02:05 - Sending encrypted client challenge
00:02:05 - /pair?...clientchallenge=50429698037B3BFE41526D6EA7B706FC...  ← AES encrypted
00:02:05 - /pair?...serverchallengeresp=DF02F0DD8AFB3FDB1B59581092C628EF...  ← server decrypted ✅
00:02:05 - Sending client pairing secret
00:02:05 - ComputerModel: Emitted pairingCompleted signal  ← success
```

`serverchallengeresp` received confirms Vibepollo successfully decrypted the AES challenge using the submitted PIN. Pairing dialog closed automatically.

---

## 4. Check 3 — Video

**PASS ✅** — Multiple sessions confirmed:
```
FORCE_VAAPI=1 (host DRI: /usr/lib64/dri)
Video stream is 1920x1200x120 (format 0x100)
EGLRenderer: EGLImage pixel format: 181
```
13 ENet drops observed (`Connection terminated: -1`, `Transaction failed: 11`) — consistent with test14 findings; network-level, not app bug.

---

## 5. Check 4 — Quick Menu

**PARTIAL ⚠️** — Overlay visually appears but buttons are unresponsive.

Log shows QuickMenuManager geometry set correctly on every stream session:
```
Setting QuickMenuManager geometry: 805240832,805240832 1472x920 (actual pos: 224,140)
QuickMenuManager::setWindowGeometry: 224 140 1472 920
```

No QML `TypeError` logged, but no `show`/`trigger`/`button pressed` events either. User reports:
- Overlay does render (visible dark rectangle)
- Menu items not interactable / buttons don't respond to input
- Visual geometry appears off in windowed mode (menu positioned at 224,140 offset — covers only part of the window rather than filling the stream viewport)

**Root cause candidates:**
1. `NavigableMenu.qml:10: TypeError: Cannot read property 'focus' of undefined` — this crash was documented in test14 but never confirmed fixed (fix was in `28f5e4e` but not verified due to pairing blocking). May still be present without logging.
2. Geometry offset (224,140) computed as if the stream window occupies full screen; in windowed Desktop Mode the overlay is positioned incorrectly relative to the actual video area.

---

## 6. Check 4 — Clipboard

**PARTIAL ⚠️** — Works in the pairing session only; 403 Forbidden after every restart.

### First stream session (same process as pairing): PASS ✅
```
00:00:46 - NvHTTP: Sending clipboard content: https://...47984/actions/clipboard?uniqueid=STEAMDEC75F89E8C...
00:00:46 - NvHTTP: Successfully sent clipboard content to server
00:00:46 - ClipboardManager: Successfully sent clipboard to server
```

### All subsequent sessions after app restart: FAIL 403 ❌
```
00:01:03 - NvHTTP: Failed to send clipboard content:
           "Error transferring .../clipboard?uniqueid=STEAMDECA9931650... - server replied: Forbidden"
```

**Root cause:** The `uniqueid` rotates on every app launch (`STEAMDEC0A6AFD8A` → `STEAMDEC75F89E8C` → `STEAMDECA9931650`). Pairing is tied to the original uniqueid's client cert. After restart the new uniqueid's cert is not trusted by Vibepollo → 403 on all HTTPS endpoints. The uniqueid must be persisted in `settings.ini` (or equivalent) and reused across sessions.

Clipboard fetch (host→client) and Bubbles not tested — ENet drops cut sessions short before reaching those items.

---

## 7. Recommendation

**ITERATE** — 3 issues remain after pairing fix:

1. **Uniqueid not persisted** (critical): App generates a new `uniqueid` on every launch. The client cert paired to the original uniqueid is rejected after restart. Fix: generate uniqueid once, persist it in `settings.ini`, reuse on subsequent launches. Without this, pairing is effectively single-session only.

2. **Quick Menu buttons unresponsive**: Overlay renders but items can't be clicked/selected. Likely the `NavigableMenu` focus bug from test14 still present. Also investigate geometry offset — the 224,140 position may be wrong in windowed Desktop Mode, placing the overlay partially out of the interactive area.

3. **ENet drops** (environmental): 13 drops across ~30 minutes of testing, every 20-60 seconds. Prevents completing the full feature matrix. Not an app bug — network quality between Z2 and Navid-PC in Desktop Mode. Recommend testing in Game Mode (wired/better network conditions) for thorough Quick Menu / Bubbles / clipboard fetch verification.
