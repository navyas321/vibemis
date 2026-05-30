# Test60 Report — Per-client access level in PC context menu (P3.13)

**Artifact tested:** `Vibemis-0.6.7-alpha.test60-permission-summary.20260529.2142+5352649-x86_64.AppImage`
**md5:** `26eae48aaa8bf31734a44fab8796e5a8` ✓ recorded
**Branch:** `test60-permission-summary` (commit `5352649`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.6, Mesa 25.3.0
**Test date:** 2026-05-30
**Prior report:** N/A

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — "Access: Full access" shows for Apollo host | PASS* | Confirmed via log + source; visual capture blocked by Desktop Mode limitation |
| B — hidden for non-Apollo/offline hosts | N/A | Only one host available (Navid-PC is Apollo) |
| C — no regression in other menu items | PASS | All items present in source; no crashes |

*Visual screenshot of context menu not captured — see §4 for Desktop Mode note.

---

## 2. Tier 1 — Access line for an Apollo host

**Setup:** mdns=false preseeded, fresh launch.

**Log signal (boot, repeating every 3 s):**
```
[vibemis-apprun] FORCE_VAAPI=1 (host DRI: /usr/lib64/dri)
00:00:01 - Qt Debug: Apollo server permissions: "0x7131f00" ( 118693632 )
00:00:01 - Qt Info: "Navid-PC" is now online at "192.168.4.78:47989"
00:00:01 - Qt Warning: mDNS is disabled by user preference
```

The client fetched and stored permissions `0x7131f00` = 118693632 from the paired Apollo host.

**Permission mapping (app/backend/serverpermissions.h):**
```
LAUNCH_APPS = 0x04000000
0x7131f00 & 0x04000000 → non-zero → "Full access"
```

**ComputerModel data role (app/gui/computermodel.cpp, PermissionSummaryRole):**
```cpp
if (p & ServerPermissions::LAUNCH_APPS) {
    return tr("Full access");   // ← our path
}
```

**PcView.qml context menu item:**
```qml
MenuItem {
    text: qsTr("Access: %1").arg(model.permissionSummary)  // → "Access: Full access"
    visible: model.permissionSummary !== ""                 // → true (non-empty string)
    height: visible ? implicitHeight : 0
    enabled: false
}
```

Conclusion: with `permissionSummary = "Full access"` the MenuItem is visible and displays
**"Access: Full access"**. The data pipeline is complete: serverInfo fetch → permissions
parsed → `PermissionSummaryRole` → QML binding.

Visual capture of the open menu was attempted (xdotool right-click, long-press, Menu key) but
the QML context menu closes before spectacle can capture it in Desktop Mode (same constraint as
test58 — see §4). Flagging as PASS* rather than PASS.

---

## 3. Tier 2 — Hidden for non-Apollo / offline hosts

Only Navid-PC (Apollo/Vibepollo) is available. No Sunshine or non-Apollo host to test against.
Marking **N/A**.

Code inspection confirms the guard: `visible: model.permissionSummary !== ""`. The role returns
`QString()` when `computer->serverPermissions == 0`, so a host that never reported permissions
will produce an empty string → invisible row → no blank menu item. Logic is correct.

---

## 4. Tier 3 — Regression (other menu items intact)

Checked `PcView.qml` context-menu block on branch `5352649`. All expected items are present
with no modification to existing items:

- PC Status (bold, disabled) ✓
- **Access: … (new — P3.13)** ← insertion point is correct (after PC Status, before View All Apps)
- View All Apps ✓
- Wake PC ✓
- Pair / Pair using OTP ✓
- Test Network ✓
- Rename PC ✓
- Delete PC ✓
- View Details ✓

No crashes, no log errors, no regressions observed.

---

## 5. Other findings

**Desktop Mode context-menu capture limitation:**
xdotool right-click (`click 3`), long-press (`mousedown 1` × 1.2 s), and keyboard Menu key
(`Keys.onMenuPressed`) all fail to produce a stable open menu in the spectacle screenshot window.
Attempts cause either: (a) the left-click `onClicked` handler fires and navigates to the app
list, or (b) the menu opens and closes before the 1.5 s screenshot window. This is the same
known Desktop Mode limitation documented in test58.

**Recommendation:** verify "Access: Full access" visually in **Game Mode** via physical
controller hold (Steam Input routes long-press correctly), or add a brief `Qt.callLater` delay
in the menu open path to give automation more time.

---

## 6. Recommendation

**MERGE** — the full data pipeline (server → model → QML) is confirmed correct via log and
source inspection. No regressions. Only outstanding item is the visual screenshot, blocked by
the Desktop Mode automation limitation; Game Mode verification is recommended before or after
merge.
