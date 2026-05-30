# Test63 Report — Copy system info to clipboard

**Artifact tested:** `Vibemis-0.6.7-alpha.test63-copy-system-info.20260529.2155+e1817e7-x86_64.AppImage`
**md5:** `7b5b925dd3f5632e98bf94a441baf8d1` recorded (instructions request recording, no expected hash provided)
**Branch:** `test63-copy-system-info` (commit `e1817e7`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.6, Mesa 25.3.0
**Test date:** 2026-05-30
**Prior report:** `testing/test55-system-info/` (Tier 2 baseline)

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — "Copy to clipboard" button renders in System Information | PASS | Button visible in screenshot after scrolling to section |
| B — Click triggers "Copied!" flash then reverts | PASS | Flash captured in screenshot; revert confirmed after 1500ms |
| C — Clipboard contains all required fields | PASS | All 7 fields verified via tkinter clipboard read |
| D — System Information panel no regression (Tier 2) | PASS | All rows render; button coexists cleanly |

---

## 2. Tier 1 — copy works (Desktop Mode)

**Log:** Clean launch, no errors.
```
[vibemis-apprun] FORCE_VAAPI=1 (host DRI: /usr/lib64/dri)
00:00:01 - SDL Info (0): Initialized VAAPI 1.22
00:00:02 - Qt Info: "Navid-PC" is now online at "192.168.4.78:47989"
00:00:02 - Qt Debug: Current Vibemis version: "0.6.7"
```

**Navigation:** Settings gear opened at X11 (1688, 387). Right panel scrolled to System Information.

**Button render:** "Copy to clipboard" button visible at screen position x≈1090–1259, y≈786–816 (pixel analysis).

**Click result:** Button text changed to **"Copied!"** (confirmed in screenshot). After 1500ms the button reverted to "Copy to clipboard" (confirmed in second screenshot). Both states captured.

**Clipboard content** (read via Python/tkinter clipboard_get):
```
Vibemis version: 0.6.7
Architecture: x64
Steam Deck: Yes
Display server: X11
Hardware decode: Available
HDR support: Yes
Max resolution: 0x0
```

All 7 required fields present. "Max resolution: 0x0" matches what the panel displays on this device in X11 mode (`SystemProperties.maximumResolution` reports 0×0 under XWayland — pre-existing; not a new regression from this feature).

**PASS**

---

## 3. Tier 2 — no regression (System Information panel)

System Information panel renders all rows correctly:
- Vibemis version / Architecture / Steam Deck / Display server / Hardware decode / HDR support / Max resolution
- "Copy to clipboard" button coexists with the panel with clean layout
- No overlap, no missing rows, no layout shift

**PASS**

---

## 4. Source verification

QML source (`app/gui/SettingsView.qml`, commit `e1817e7`):
```qml
TextEdit {
    id: systemInfoClipHelper
    visible: false
}
Button {
    id: copySystemInfoButton
    text: qsTr("Copy to clipboard")
    onClicked: {
        systemInfoClipHelper.text =
            "Vibemis version: " + SystemProperties.versionString + "\n" +
            "Architecture: " + SystemProperties.friendlyNativeArchName + "\n" +
            "Steam Deck: " + (SystemProperties.isSteamDeck ? "Yes" : "No") + "\n" +
            "Display server: " + ... + "\n" +
            "Hardware decode: " + ... + "\n" +
            "HDR support: " + ... + "\n" +
            "Max resolution: " + SystemProperties.maximumResolution.width + "x" + SystemProperties.maximumResolution.height
        systemInfoClipHelper.selectAll()
        systemInfoClipHelper.copy()
        copySystemInfoButton.text = qsTr("Copied!")
        copyFeedbackTimer.restart()
    }
    Timer {
        id: copyFeedbackTimer
        interval: 1500
        onTriggered: copySystemInfoButton.text = qsTr("Copy to clipboard")
    }
}
```

Pure QML implementation (hidden TextEdit + `selectAll()` + `copy()`). No ClipboardManager or C++ involved — clipboard note log entry `ClipboardManager: No connection available` is unrelated (streaming clipboard sync, no stream active).

---

## 5. Other findings

**"Max resolution: 0x0":** `SystemProperties.maximumResolution` returns 0×0 on this device running under XWayland. The panel and clipboard are consistent with each other. This is not a regression introduced by test63 — it is pre-existing behavior of `maximumResolution` in the X11/XWayland context. Would be worth noting as a known limitation in the System Information help text.

---

## 6. Recommendation

**MERGE** — "Copy to clipboard" button works correctly end-to-end: renders in Settings, triggers "Copied!" flash, reverts after 1500ms, and puts all 7 required system-info fields into the clipboard. Panel regression-free. The "Max resolution: 0x0" display is pre-existing and orthogonal to this feature.
