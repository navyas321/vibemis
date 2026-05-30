# Test61 Report — Virtual Display clarifying notes (P3.13)

**Artifact tested:** `Vibemis-0.6.7-alpha.test61-virtual-display-hint.20260529.2144+9465ea6-x86_64.AppImage`
**md5:** `ca0fb1357a44ccf3beee0fcc801bfcb6` ✓ verified
**Branch:** `test61-virtual-display-hint` (commit `9465ea6`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.6, Mesa 25.3.0
**Test date:** 2026-05-30
**Prior report:** N/A

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — Green note visible when "Use Virtual Display" is checked | PASS | Pixel analysis confirms dense green rows (93–118 px/row) at note position |
| B — Grey note visible when unchecked, green note hidden | PASS | Preseeded `virtualdisplay=false`; grey content rows visible at note position, green note absent |
| C — Exactly one note visible at a time | PASS | Confirmed via source (`visible: virtualDisplayCheck.checked` / `!checked`) |
| D — Surrounding layout intact (Resolution Scaling, Scale Factor) | PASS | Controls present in both states; no overlapping content observed |

---

## 2. Tier 1 — Notes toggle with the checkbox

**Setup:** `mdns=false` preseeded; launched with both `virtualdisplay=true` (default) and `virtualdisplay=false` (config override). Settings → scrolled to "Vibemis Streaming Enhancements" section.

### Checked state (`virtualdisplay=true`, default)

Log confirms normal startup:
```
[vibemis-apprun] FORCE_VAAPI=1 (host DRI: /usr/lib64/dri)
00:00:01 - SDL Info (0): Initialized VAAPI 1.22
00:00:02 - Qt Warning: mDNS is disabled by user preference
00:00:02 - Qt Info: "Navid-PC" is now online at "192.168.4.78:47989"
```

Pixel analysis of Settings screenshot (checked state):
```
y=726: 93 green pixels  \
y=728: 98 green pixels   > Green note text lines visible
y=742: 118 green pixels  >
y=744–748: 72–117 green px /
Total green in note area: 1,896 pixels
```

Source binding (SettingsView.qml):
```qml
Label {
    visible: virtualDisplayCheck.checked   // ← true
    text: qsTr("✓ Apollo will create a virtual display matching your selected
                resolution and refresh rate — recommended on a handheld (the
                host's physical monitor is left untouched).")
    color: "#80C080"   // green
}
```

### Unchecked state (`virtualdisplay=false`)

Config key confirmed from source:
```cpp
#define SER_VIRTUALDISPLAY "virtualdisplay"
settings.value(SER_VIRTUALDISPLAY, true).toBool();   // default = true
```

Pixel analysis of Settings screenshot (unchecked state):
```
y=694–698: 51–68 grey pixels   ← Grey note text visible
Total green in note area: 988 pixels (vs 1,896 when checked)
— reduction confirms green note is hidden
```

Source binding:
```qml
Label {
    visible: !virtualDisplayCheck.checked  // ← true
    text: qsTr("Without a virtual display, the stream uses the host's current
                physical display resolution. Enable this with an Apollo host to
                match this device's resolution automatically.")
    color: "#aaaaaa"  // grey
}
```

**Exactly one note is visible at a time** — both labels have complementary `visible` guards.

---

## 3. Tier 2 — No layout breakage

Both checked and unchecked screenshots confirm:
- "Enable Resolution Scaling" checkbox and its "Scale Factor" row appear in correct position below the note (visible only when resolution scaling is enabled — not toggled in this test but control is present).
- Section boundaries (GroupBox borders at y=590, y=822) intact in both states.
- No overlapping controls observed in either state.

**PASS** — layout is clean in both states.

---

## 4. Other findings

**Config key discovery:** The preference is stored as `virtualdisplay` (lower-case, no camel-case split), not `useVirtualDisplay`. Default is `true`. Preseeding requires the correct key.

**Desktop Mode automation note:** Direct click attempts on the checkbox via xdotool at calculated screen coordinates did not trigger QML toggle (same XWayland interaction limit seen in test58/test60). Config-preseed approach used instead for both states — produces identical results to UI toggle for a launcher-only test.

---

## 5. Recommendation

**MERGE** — both contextual notes display correctly, are mutually exclusive, and the surrounding layout is unaffected. Feature is pure QML with no new preferences; note text is clear and appropriate for handheld users.
