# Test70 Report — In-app "Set up Tailscale" entry point (P3.7)

**Artifact tested:** `Vibemis-0.6.7-alpha.test70-tailscale-setup-button.20260529.2224+65168d5-x86_64.AppImage`
**md5:** `bf365bb33afb0dab329db0eed9d88ca7` ✓ recorded
**Branch:** `test70-tailscale-setup-button` (commit `65168d5`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.6, Mesa 25.3.0
**Test date:** 2026-05-30
**Prior report:** N/A

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — Remote-play line + two buttons render in Vibemis Features | PASS | Both buttons visible in screenshot; SteamOS tip line present |
| B — "Set up Tailscale" opens correct URL | PASS (source) | URL `https://tailscale.com/kb/installation` confirmed in source; activation N/A in Desktop Mode |
| C — "One-command setup (guide)" opens correct URL | PASS (source) | URL `github.com/navyas321/vibemis/blob/vibemis-main/scripts/setup-tailscale.sh` confirmed in source |
| D — Buttons hidden without a browser | N/A (hasBrowser=true) | `hasBrowser=hasDesktopEnvironment=true` on Desktop Mode (KDE Plasma) |

---

## 2. Tier 1 — Entry point renders (Desktop Mode)

**Log:** Clean launch, no errors.
```
[vibemis-apprun] FORCE_VAAPI=1 (host DRI: /usr/lib64/dri)
00:00:01 - SDL Info (0): Initialized VAAPI 1.22
00:00:02 - Qt Warning: mDNS is disabled by user preference
00:00:02 - Qt Info: "Navid-PC" is now online at "192.168.4.78:47989"
```

**Visual confirmation:** Scrolled to Settings → "Vibemis Features" → screenshot confirms:
- Contextual text: *"Remote play (stream from anywhere): set up Tailscale, then enable 'Prefer Tailscale addresses' above."*
- Button row: **"Set up Tailscale"** | **"One-command setup (guide)"** — both rendered
- Tip line: *"Tip: on SteamOS, run scripts/setup-tailscale.sh for a one-command, no-sudo setup."*

**hasBrowser gate:** `hasBrowser = hasDesktopEnvironment` (source: `systemproperties.cpp`). On Desktop Mode (KDE Plasma), `WMUtils::isRunningDesktopEnvironment()` returns `true` → both buttons are visible.

**PASS**

---

## 3. Tier 2 — Buttons open the right pages

Source bindings verified:
```qml
Button {
    text: qsTr("Set up Tailscale")
    onClicked: Qt.openUrlExternally("https://tailscale.com/kb/installation")
    visible: SystemProperties.hasBrowser
}
Button {
    text: qsTr("One-command setup (guide)")
    onClicked: Qt.openUrlExternally("https://github.com/navyas321/vibemis/blob/vibemis-main/scripts/setup-tailscale.sh")
    visible: SystemProperties.hasBrowser
}
```

URLs are correct for each button. `Qt.openUrlExternally` routes to `xdg-open` on Linux (`xdg-open` present at `/usr/bin/xdg-open`).

**Actual button click:** xdotool click did not activate the QML Button in Desktop Mode (same XWayland/QML interaction limit observed in test56 and test69). Screenshot captures both buttons rendered correctly; actual browser-launch confirmation blocked by automation limitation.

**PASS (source)** — URLs correct; runtime activation not captured, added to ledger.

---

## 4. Other findings

**hasBrowser=false path:** Buttons would be hidden on headless/Game Mode without a DE. Test on such a device would verify the guard; on this device with KDE Plasma, the guard always evaluates true. Code path confirmed: `visible: SystemProperties.hasBrowser`.

---

## 5. Recommendation

**MERGE** — both buttons render correctly on Desktop Mode with `hasBrowser=true`, URLs are correct from source, and the feature is the companion UI to test51 (Prefer Tailscale toggle) and test69 (one-command script). Actual browser-open verification is a ledger item for a future interactive session.
