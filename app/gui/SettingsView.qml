import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.2
import QtQuick.Window 2.2

import StreamingPreferences 1.0
import ComputerManager 1.0
import SdlGamepadKeyNavigation 1.0
import SystemProperties 1.0
import ClipboardManager 1.0
import ServerCommandManager 1.0
import AutoUpdateChecker 1.0
import UiSoundManager 1.0

import Vibemis.Redesign 1.0

Item {
    id: settingsPage
    objectName: qsTr("Settings")

    // LB/RB category flips change `category` without moving item focus,
    // so the launcher-wide focus tick (main.qml) never fires for them — tick here.
    onCategoryChanged: UiSoundManager.focusMoved()

    // Redesign (sidebar categories). The root was a Flickable; it is now an Item hosting a
    // fixed header + a 340px category sidebar + a right-hand Flickable panel (settingsFlick)
    // that shows one category's GroupBoxes at a time, gated by `category`. Every GroupBox and
    // its StreamingPreferences/ComputerManager/SystemProperties bindings are unchanged — only
    // the outer container, header, sidebar and per-category visibility were added.
    property int category: 0

    signal languageChanged()

    // ---- Sidebar -> content focus transfer. D-pad RIGHT on a sidebar row moves
    // active focus to the first focusable control of the visible category, mirroring the
    // toolbar->grid transfer in main.qml (stackView.currentItem.forceActiveFocus(Qt.TabFocus)).
    // Search order is declaration order inside the panel columns, and hidden categories'
    // GroupBoxes are skipped via the visible check, so this lands on the visible page.
    function focusContentPane() {
        var target = findFirstFocusable(settingsFlick.contentItem)
        if (target) {
            target.forceActiveFocus(Qt.TabFocus)
        }
    }

    function findFirstFocusable(item) {
        for (var i = 0; i < item.children.length; i++) {
            var child = item.children[i]
            if (!child.visible || !child.enabled) {
                continue
            }
            if (child.activeFocusOnTab) {
                return child
            }
            var nested = findFirstFocusable(child)
            if (nested) {
                return nested
            }
        }
        return null
    }

    // ---- Shared restyle components, factored from the redesigned Video subpage so
    // the other categories reuse the exact same visual pattern (no new design language). ----

    // Card-style settings group — same recipe as the Video page's Vibepollo Presets card
    // (bgElev fill, radiusCard, 1px stroke border, 24px padding, label rendered inside).
    component VbSettingsCard: GroupBox {
        padding: 24
        label: Item {}
        background: Rectangle {
            color: VbTokens.bgElev
            radius: VbTokens.radiusCard
            border.width: 1
            border.color: VbTokens.stroke
        }
    }

    // Sora section header shown at the top of each settings card (fontDisplay, like the
    // category title above the panel, at card scale).
    component VbSectionHeader: Text {
        width: parent.width
        font.family: VbTokens.fontDisplay
        font.weight: Font.Bold
        font.pixelSize: 20
        color: VbTokens.text
        bottomPadding: 6
        wrapMode: Text.Wrap
    }

    // Toggle-row CheckBox — identical visual language to the Video page's V-Sync /
    // frame-pacing / adaptive-bitrate rows (18px DemiBold title + accent pill switch over
    // a strokeSoft hairline). Purely visual: each usage keeps its own checked /
    // onCheckedChanged / visible / enabled bindings and ToolTip, unchanged.
    component VbToggleRow: CheckBox {
        id: toggleRoot
        width: parent.width
        height: Math.max(70, toggleTitle.implicitHeight + 28)
        hoverEnabled: true
        opacity: enabled ? 1.0 : 0.5

        // Activation blip on user toggles only — toggled() never fires
        // for programmatic checked changes (the pref-binding churn at load).
        // Connections so a future instance-level onToggled can't override it.
        Connections {
            target: toggleRoot
            function onToggled() {
                UiSoundManager.activated()
            }
        }

        indicator: Item {}
        background: Item {
            // No visible pane focus: the toggle rows had no focus
            // affordance at all, so gamepad focus in the content pane was invisible. Paint
            // the standard focused fill + accent border when the row holds active focus.
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                radius: 10
                visible: toggleRoot.activeFocus
                color: VbTokens.focusedFill
                border.width: VbTokens.focusBorder
                border.color: VbTokens.accent
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: VbTokens.strokeSoft
            }
        }
        contentItem: Item {
            anchors.fill: parent
            Text {
                id: toggleTitle
                anchors.left: parent.left
                // Constant inset so the focused ring's left border never overlaps
                // the first letters (padding is permanent — text must not shift on focus).
                anchors.leftMargin: 14
                anchors.right: togglePill.left
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: toggleRoot.text
                font.family: VbTokens.fontBody
                font.weight: Font.DemiBold
                font.pixelSize: 18
                color: VbTokens.text
                wrapMode: Text.Wrap
            }
            Rectangle {
                id: togglePill
                anchors.right: parent.right
                // Mirror inset on the right so the ring clears the pill too.
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 60; height: 34; radius: 999
                color: toggleRoot.checked ? VbTokens.accent : "#2A2F37"
                Rectangle {
                    width: 26; height: 26; radius: 13
                    anchors.verticalCenter: parent.verticalCenter
                    x: toggleRoot.checked ? parent.width - width - 4 : 4
                    color: toggleRoot.checked ? "#08090B" : VbTokens.textDim
                    Behavior on x { NumberAnimation { duration: 120 } }
                }
            }
        }
    }

    // Full-bleed window background.
    Rectangle { anchors.fill: parent; color: VbTokens.bgWindow }

    // StackView attached handlers must stay on the pushed page (the Item root).
    StackView.onActivated: {
        // This enables Tab and BackTab based navigation rather than arrow keys.
        // It is required to shift focus between controls on the settings page.
        SdlGamepadKeyNavigation.setUiNavMode(true)

        // Highlight the first sidebar category row if a gamepad is connected.
        if (SdlGamepadKeyNavigation.getConnectedGamepads() > 0 && sidebarRepeater.count > 0) {
            var firstRow = sidebarRepeater.itemAt(0)
            if (firstRow) {
                firstRow.forceActiveFocus(Qt.TabFocus)
            }
        }
    }

    StackView.onDeactivating: {
        SdlGamepadKeyNavigation.setUiNavMode(false)

        // Save the prefs so the Session can observe the changes
        StreamingPreferences.save()
    }

    Component.onDestruction: {
        // Also save preferences on destruction, since we won't get a
        // deactivating callback if the user just closes Moonlight
        StreamingPreferences.save()
    }

    // ---- Redesign: LB/RB switch category (matches the hint bar below) ----
    // SdlGamepadKeyNavigation forwards the shoulder buttons as Key_MediaPrevious (LB) /
    // Key_MediaNext (RB) — see sdlgamepadkeynavigation.cpp. The handler lives on the page root, so
    // a shoulder press from any focused sidebar row or control bubbles up here (unhandled key
    // events propagate to ancestors — the same path main.qml uses for ☰/Start). The category is
    // clamped to the sidebar's range with no wrap. Other screens don't bind these keys, so the
    // shoulder buttons are a harmless no-op there.
    // Switching category must ALSO move keyboard/gamepad focus onto the newly
    // selected sidebar row. Selection (`category`) and focus (`activeFocus`) were two
    // independent states, so LB/RB moved the selected-row ring while the focus ring stayed
    // on the old row (or the d-pad/stick moved focus while selection stayed) — you could see
    // TWO accent rings at once. focusCategoryRow() keeps them locked together: exactly one row
    // is ever both selected and focused.
    function focusCategoryRow(idx) {
        settingsPage.category = idx
        var row = sidebarRepeater.itemAt(idx)
        if (row) {
            row.forceActiveFocus()
        }
    }

    Keys.onPressed: {
        if (event.key === Qt.Key_MediaPrevious) {
            focusCategoryRow(Math.max(0, settingsPage.category - 1))
            event.accepted = true
        }
        else if (event.key === Qt.Key_MediaNext) {
            focusCategoryRow(Math.min(sidebarRepeater.count - 1, settingsPage.category + 1))
            event.accepted = true
        }
    }

    // ---- Header (Back + "Settings" + version chip) MOVED to the always-present global toolbar
    // (main.qml), which is the header bar kept present so it renders under gamescope. Hidden here so
    // there is no double header; the sidebar/panel (anchored to header.bottom) shift up to the top. ----
    Item {
        id: header
        visible: false
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 0
        z: 2

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: VbTokens.screenPadX
            anchors.rightMargin: VbTokens.screenPadX
            spacing: 20

            Button {
                id: backBtn
                implicitWidth: VbTokens.iconButton
                implicitHeight: VbTokens.iconButton
                background: Rectangle {
                    radius: VbTokens.radiusIconButton
                    color: backBtn.activeFocus ? VbTokens.focusedFill : VbTokens.bgElev
                    border.width: 1
                    border.color: backBtn.activeFocus ? VbTokens.accent : VbTokens.stroke
                }
                contentItem: Text {
                    text: "‹"
                    font.family: VbTokens.fontDisplay
                    font.pixelSize: 30
                    color: VbTokens.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                // Use goBack() rather than a bare stackView.pop() so the retranslate
                // clearOnBack path still pops all AppView pages — identical to gamepad Ⓑ / Esc.
                onClicked: window.goBack()
            }

            Text {
                text: qsTr("Settings")
                font.family: VbTokens.fontDisplay
                font.weight: Font.Bold
                font.pixelSize: VbTokens.sizeScreenTitle
                color: VbTokens.text
                Layout.fillWidth: true
            }

            // Version chip (e.g. "Version 0.24.0"). Redesign: accent-tinted pill —
            // accent text on a 12%-accent background, 8px radius (not a full pill).
            Rectangle {
                implicitHeight: versionChipText.implicitHeight + 12
                implicitWidth: versionChipText.implicitWidth + 28
                radius: 8
                color: Qt.rgba(VbTokens.accent.r, VbTokens.accent.g, VbTokens.accent.b, 0.12)
                Text {
                    id: versionChipText
                    anchors.centerIn: parent
                    text: qsTr("Version %1").arg(SystemProperties.versionString)
                    font.family: VbTokens.fontBody
                    font.weight: Font.DemiBold
                    font.pixelSize: VbTokens.sizeLabel
                    color: VbTokens.accent
                }
            }
        }

        // Header hairline.
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: VbTokens.strokeSoft
        }
    }

    // ---- Sidebar: 5 focusable category rows (redesign) ----
    Rectangle {
        id: sidebar
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.bottom: hintBar.top
        width: 340
        color: VbTokens.bgWindow
        z: 2

        // Vertical hairline between the sidebar and the panel.
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: VbTokens.strokeSoft
        }

        Column {
            id: sidebarColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 28
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 6

            Repeater {
                id: sidebarRepeater
                model: [
                    { icon: "video",     label: qsTr("Video") },
                    { icon: "audio",     label: qsTr("Audio") },
                    { icon: "gamepad",   label: qsTr("Input & gamepad") },
                    { icon: "streaming", label: qsTr("Streaming") },
                    { icon: "advanced",  label: qsTr("Advanced") }
                ]
                delegate: Button {
                    id: catButton
                    width: sidebarColumn.width
                    height: 58
                    padding: 0
                    leftPadding: 16
                    rightPadding: 16
                    readonly property bool selected: settingsPage.category === index

                    background: Item {
                        // Selection/focus glow (accent @ 22%), just outside the row. The design spec
                        // keeps this glow on the selected row persistently (not just while focused).
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -VbTokens.focusGlow
                            radius: VbTokens.radiusControl + VbTokens.focusGlow
                            visible: catButton.activeFocus || catButton.selected
                            color: "transparent"
                            border.width: VbTokens.focusGlow
                            border.color: VbTokens.focusGlowColor
                            antialiasing: true
                        }
                        // Row fill + border. Selected OR focused shows the accent ring.
                        Rectangle {
                            anchors.fill: parent
                            radius: VbTokens.radiusControl
                            color: catButton.selected ? VbTokens.focusedFill
                                 : (catButton.activeFocus ? VbTokens.bgElev2 : "transparent")
                            border.width: (catButton.selected || catButton.activeFocus) ? VbTokens.focusBorder : 1
                            border.color: (catButton.selected || catButton.activeFocus) ? VbTokens.accent : VbTokens.stroke
                            antialiasing: true
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }

                    contentItem: RowLayout {
                        spacing: 14
                        VbSheetIcon {
                            kind: modelData.icon
                            width: 24; height: 24
                            color: catButton.selected ? VbTokens.accent : VbTokens.textDim
                            Layout.preferredWidth: 22
                        }
                        Text {
                            text: modelData.label
                            font.family: VbTokens.fontBody
                            font.pixelSize: VbTokens.sizeBody
                            font.weight: catButton.selected ? Font.DemiBold : Font.Medium
                            color: catButton.selected ? VbTokens.text : VbTokens.textMute
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                            Layout.fillWidth: true
                        }
                    }

                    // onClicked fires on mouse/touch, Return/Space, and gamepad Ⓐ (UI nav mode).
                    onClicked: settingsPage.category = index

                    // v2 — the v1 stale-flag redirect proved unreliable on device (the
                    // Advanced-jump reproduced from EVERY category): only the CURRENT
                    // category's row participates in the Tab focus chain. A BackTab escaping the
                    // content pane (d-pad UP at a pane-section top in UI-nav mode) can therefore
                    // only ever land on THIS category's row — never "Advanced" — so the surprise
                    // pane switch is structurally impossible. LB/RB, clicks and the key handlers
                    // below use forceActiveFocus/clicks, which ignore activeFocusOnTab.
                    activeFocusOnTab: index === settingsPage.category

                    // Selection follows focus. When the d-pad/left-stick or a mouse
                    // moves focus onto this row, make it the selected category — so the selected
                    // ring and the focus ring are always the SAME row (no two-rings-at-once).
                    onActiveFocusChanged: {
                        if (activeFocus) {
                            settingsPage.category = index
                        }
                    }

                    // Explicit vertical nav. Keyboard arrows AND the gamepad's
                    // UI-nav Tab/Shift+Tab are stepped here (Keys handlers run before default
                    // tab handling), since non-current rows are no longer in the tab chain.
                    //
                    // REGRESSION LESSON ("Up completely broken"): UiNav
                    // d-pad UP arrives as Key_Tab WITH ShiftModifier (sdlgamepadkeynavigation
                    // sendKey(Key_Tab, ShiftModifier)) — NOT Key_Backtab. Keys.onTabPressed
                    // matches Key_Tab regardless of modifiers, so a naive onTab/onBacktab pair
                    // made Up step DOWN. Direction must come from the modifier.
                    // Up at the TOP row (Video) escapes to the toolbar instead of
                    // self-focusing (focusCategoryRow(0) on row 0 consumed the press and made
                    // the toolbar unreachable by d-pad — a launch blocker). Leaving
                    // the event unaccepted lets the default BackTab chain walk out of the
                    // sidebar (this row is the only tab-focusable one, so chain-previous is
                    // the toolbar).
                    Keys.onUpPressed: {
                        if (index === 0) {
                            event.accepted = false
                        }
                        else {
                            settingsPage.focusCategoryRow(index - 1)
                        }
                    }
                    Keys.onDownPressed: settingsPage.focusCategoryRow(Math.min(sidebarRepeater.count - 1, index + 1))
                    Keys.onPressed: {
                        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                            var backwards = (event.key === Qt.Key_Backtab)
                                            || (event.modifiers & Qt.ShiftModifier)
                            if (backwards && index === 0) {
                                event.accepted = false   // escape to the toolbar
                                return
                            }
                            settingsPage.focusCategoryRow(backwards
                                ? index - 1
                                : Math.min(sidebarRepeater.count - 1, index + 1))
                            event.accepted = true
                        }
                    }

                    // D-pad RIGHT (sent as Key_Right by SdlGamepadKeyNavigation even in
                    // UI nav mode) enters the content pane: select this row's category, then move
                    // focus to its first control. Without this, RIGHT was a dead key on the sidebar.
                    Keys.onRightPressed: {
                        settingsPage.category = index
                        settingsPage.focusContentPane()
                    }
                }
            }
        }
    }

    // ---- Panel: the two settings columns, scrollable (redesign). The flickable-specific
    // logic (bounds, content sizing, autoscroll-to-focus, scrollbar) lives here so bare
    // contentY / contentItem / contentHeight / height resolve to settingsFlick. ----
    Flickable {
        id: settingsFlick
        anchors.top: header.bottom
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.bottom: hintBar.top

        boundsBehavior: Flickable.OvershootBounds

        // Symmetric return path: unhandled d-pad LEFT from any focused content
        // control bubbles up here and returns focus to the selected sidebar row. Controls
        // that consume Left themselves (e.g. Slider value adjustment, text fields in
        // dialogs) are unaffected because they accept the event before it propagates.
        Keys.onLeftPressed: {
            var row = sidebarRepeater.itemAt(settingsPage.category)
            if (row) {
                row.forceActiveFocus(Qt.TabFocus)
            }
        }

        contentWidth: settingsFlick.width
        // Columns now stack vertically (settingsColumn2 anchors under settingsColumn1), so the
        // visible category's height is the sum of both columns (each auto-sizes to its visible
        // children only).
        contentHeight: settingsColumn1.height + settingsColumn2.height + 50

        ScrollBar.vertical: ScrollBar {
            anchors {
                left: parent.right
                leftMargin: -10
            }
        }

        function isChildOfFlickable(item) {
            while (item) {
                if (item.parent === contentItem) {
                    return true
                }

                item = item.parent
            }
            return false
        }

        NumberAnimation on contentY {
            id: autoScrollAnimation
            duration: 100
        }

        Window.onActiveFocusItemChanged: {
            var item = Window.activeFocusItem
            if (item) {
                // Ignore non-child elements like the toolbar buttons / header / sidebar rows
                if (!isChildOfFlickable(item)) {
                    return
                }

                // Map the focus item's position into our content item's coordinate space
                var pos = item.mapToItem(contentItem, 0, 0)

                // Ensure some extra space is visible around the element we're scrolling to
                var scrollMargin = height > 100 ? 50 : 0

                if (pos.y - scrollMargin < contentY) {
                    autoScrollAnimation.from = contentY
                    autoScrollAnimation.to = Math.max(pos.y - scrollMargin, 0)
                    autoScrollAnimation.start()
                }
                else if (pos.y + item.height + scrollMargin > contentY + height) {
                    autoScrollAnimation.from = contentY
                    autoScrollAnimation.to = Math.min(pos.y + item.height + scrollMargin - height, contentHeight - height)
                    autoScrollAnimation.start()
                }
            }
        }

    Column {
        padding: 40
        id: settingsColumn1
        width: settingsFlick.width - 20
        spacing: 20

        // ---- Category title (redesign). "Video" / "Audio" / etc, Sora 28px bold, matching
        // the currently-selected sidebar row's label. ----
        Text {
            width: parent.width - (parent.leftPadding + parent.rightPadding)
            text: sidebarRepeater.model[settingsPage.category].label
            font.family: VbTokens.fontDisplay
            font.weight: Font.Bold
            font.pixelSize: VbTokens.sizeSectionTitle
            color: VbTokens.text
        }

        // ---- Live stream summary line (redesign), relocated here (was inside Basic
        // Settings) so it sits directly under the "Video" title like the design.
        // Numbers render in accent; the rest stays dim. Content/bindings unchanged.
        Text {
            id: streamSummaryLabel
            visible: settingsPage.category === 0
            width: parent.width - (parent.leftPadding + parent.rightPadding)
            textFormat: Text.RichText
            function codecName(v) {
                if (v === StreamingPreferences.VCC_FORCE_H264) return "H.264"
                if (v === StreamingPreferences.VCC_FORCE_HEVC ||
                    v === StreamingPreferences.VCC_FORCE_HEVC_HDR_DEPRECATED) return "HEVC"
                if (v === StreamingPreferences.VCC_FORCE_AV1) return "AV1"
                return qsTr("Auto codec")
            }
            text: "<font color=\"" + VbTokens.accent + "\"><b>" + StreamingPreferences.width + "×" + StreamingPreferences.height + "</b></font> · " +
                  "<font color=\"" + VbTokens.accent + "\"><b>" + StreamingPreferences.fps + " fps</b></font> · " +
                  "<font color=\"" + VbTokens.accent + "\"><b>" + (StreamingPreferences.bitrateKbps / 1000).toFixed(0) + " Mbps</b></font>" +
                  "<font color=\"" + VbTokens.textDim + "\"> — " + codecName(StreamingPreferences.videoCodecConfig) +
                  (StreamingPreferences.enableHdr ? " · HDR" : "") + "</font>"
            font.family: VbTokens.fontBody
            font.pixelSize: VbTokens.sizeBody
            wrapMode: Text.Wrap
        }

        GroupBox {
            id: vibepolloPresetsGroupBox
            visible: settingsPage.category === 0
            width: (parent.width - (parent.leftPadding + parent.rightPadding))
            padding: 24
            label: Item {}
            background: Rectangle {
                color: VbTokens.bgElev
                radius: VbTokens.radiusCard
                border.width: 1
                border.color: VbTokens.stroke
            }

            // Re-sync the resolution and FPS combo selections to the current
            // preferences after a preset is applied (the bitrate slider is already
            // bound live). If the matching entry isn't in a combo's model yet, the
            // selection is left as-is — the stream still uses the preference values.
            function reconcileResolutionFps() {
                for (var i = 0; i < resolutionListModel.count; i++) {
                    var e = resolutionListModel.get(i)
                    if (!e.is_custom &&
                        parseInt(e.video_width) === StreamingPreferences.width &&
                        parseInt(e.video_height) === StreamingPreferences.height) {
                        resolutionComboBox.currentIndex = i
                        break
                    }
                }
                for (var j = 0; j < fpsListModel.count; j++) {
                    var f = fpsListModel.get(j)
                    if (!f.is_custom && parseInt(f.video_fps) === StreamingPreferences.fps) {
                        fpsComboBox.currentIndex = j
                        break
                    }
                }
            }

            function applyVibepolloPreset(presetIndex, presetName) {
                StreamingPreferences.applyPreset(presetIndex)
                reconcileResolutionFps()
                presetStatusLabel.text = qsTr("Applied: %1 — takes effect on the next stream.").arg(presetName)
            }

            Column {
                anchors.fill: parent
                spacing: 8

                Text {
                    width: parent.width
                    // Generic wording — no host/device product names.
                    text: qsTr("Presets")
                    font.family: VbTokens.fontBody
                    font.weight: Font.DemiBold
                    font.pixelSize: VbTokens.sizeLabel
                    color: VbTokens.textDim
                }

                Label {
                    width: parent.width
                    text: qsTr("One-click starting points for common quality/performance trade-offs (HEVC, hardware decode). Pick one, then fine-tune anything below.")
                    font.pointSize: 9
                    wrapMode: Text.Wrap
                }

                Flow {
                    width: parent.width
                    spacing: 8

                    Button {
                        text: qsTr("Quality · 1200p120")
                        onClicked: vibepolloPresetsGroupBox.applyVibepolloPreset(0, qsTr("Quality"))
                    }
                    Button {
                        text: qsTr("Balanced · 1200p90")
                        onClicked: vibepolloPresetsGroupBox.applyVibepolloPreset(1, qsTr("Balanced"))
                    }
                    Button {
                        text: qsTr("Performance · 800p120")
                        onClicked: vibepolloPresetsGroupBox.applyVibepolloPreset(2, qsTr("Performance"))
                    }
                    Button {
                        text: qsTr("Battery · 800p60")
                        onClicked: vibepolloPresetsGroupBox.applyVibepolloPreset(3, qsTr("Battery Saver"))
                    }
                }

                Label {
                    id: presetStatusLabel
                    width: parent.width
                    text: ""
                    visible: text !== ""
                    color: "#00cccc"
                    font.pointSize: 9
                    wrapMode: Text.Wrap
                }
            }
        }

        GroupBox {
            id: basicSettingsGroupBox
            visible: settingsPage.category === 0
            width: (parent.width - (parent.leftPadding + parent.rightPadding))
            padding: 0
            label: Item {}
            background: Item {}

            Column {
                anchors.fill: parent
                spacing: 20

                // Vibemis: recommend this device's native resolution so users pick the sharpest
                // option without guesswork.
                // NOTE: SystemProperties.maximumResolution is the *decoder* ceiling, which
                // is (0,0) on devices whose decoder can exceed 1080p (e.g. Legion Go S Z2), so it
                // can't be the native-resolution source on capable hardware. Prefer the actual panel
                // size from QML's Screen attached property; fall back to the decoder max only if
                // Screen is somehow unavailable. Hidden only if neither yields a positive size.
                Label {
                    width: parent.width
                    readonly property int nativeResW: Screen.width > 0 ? Screen.width
                                                       : SystemProperties.maximumResolution.width
                    readonly property int nativeResH: Screen.height > 0 ? Screen.height
                                                       : SystemProperties.maximumResolution.height
                    visible: nativeResW > 0 && nativeResH > 0
                    text: "💡 " + qsTr("This device's native resolution is %1×%2 — matching it gives the sharpest image (use a lower resolution only if you need more performance).")
                          .arg(nativeResW).arg(nativeResH)
                    font.pointSize: 9
                    wrapMode: Text.Wrap
                    color: "#aaaaaa"
                    bottomPadding: 4
                }

                // Vibemis: extra detail beyond the live summary line (which now lives at the top
                // of the panel, redesign). Kept as contextual copy above the resolution/FPS cards.
                Label {
                    width: parent.width
                    id: resFPSdesc
                    text: qsTr("Setting values too high for your PC or network connection may cause lag, stuttering, or errors.")
                    font.pointSize: 9
                    wrapMode: Text.Wrap
                    color: VbTokens.textDim
                }

                // ---- Resolution / Frame rate cards (redesign) ----
                Row {
                    spacing: 20
                    width: parent.width

                    AutoResizingComboBox {
                        // Redesign: card look (bgElev, radius16, accent focus ring) — visual only.
                        // Model/functions/dialog below are unchanged.
                        width: (parent.width - parent.spacing) / 2
                        padding: 0
                        // The content Column is inset by 24px margins that don't count
                        // toward the control's implicit height, so the value text used to render
                        // past the card's bottom edge. Size the card to content + both margins.
                        implicitHeight: resolutionCardContent.implicitHeight + 48
                        background: Rectangle {
                            color: VbTokens.bgElev
                            radius: VbTokens.radiusCard
                            border.width: resolutionComboBox.activeFocus ? VbTokens.focusBorder : 1
                            border.color: resolutionComboBox.activeFocus ? VbTokens.accent : VbTokens.stroke
                        }
                        indicator: Item { width: 0; height: 0 }
                        contentItem: Column {
                            id: resolutionCardContent
                            anchors.fill: parent
                            anchors.margins: 24
                            spacing: 10
                            Text {
                                width: parent.width
                                text: qsTr("Resolution")
                                font.family: VbTokens.fontBody
                                font.weight: Font.DemiBold
                                font.pixelSize: VbTokens.sizeLabel
                                color: VbTokens.textDim
                                elide: Text.ElideRight
                            }
                            Row {
                                width: parent.width
                                Text {
                                    width: parent.width - 26
                                    text: resolutionComboBox.displayText
                                    font.family: VbTokens.fontBody
                                    font.weight: Font.Bold
                                    font.pixelSize: 20
                                    color: VbTokens.text
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: "⌄"
                                    font.pixelSize: 20
                                    color: VbTokens.textDim
                                }
                            }
                        }
                        // Unlike the auto-sizing combos elsewhere, this combo's width is
                        // fixed by the card, so long entries (e.g. "Native (Excluding Notch)
                        // (1920x1200)") could overflow the default popup delegate. Elide instead.
                        delegate: ItemDelegate {
                            width: resolutionComboBox.width
                            highlighted: resolutionComboBox.highlightedIndex === index
                            contentItem: Text {
                                text: model.text
                                font: resolutionComboBox.font
                                color: VbTokens.text
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        property int lastIndexValue

                        function addDetectedResolution(friendlyNamePrefix, rect) {
                            var indexToAdd = 0
                            for (var j = 0; j < resolutionComboBox.count; j++) {
                                var existing_width = parseInt(resolutionListModel.get(j).video_width);
                                var existing_height = parseInt(resolutionListModel.get(j).video_height);

                                if (rect.width === existing_width && rect.height === existing_height) {
                                    // Duplicate entry, skip
                                    indexToAdd = -1
                                    break
                                }
                                else if (rect.width * rect.height > existing_width * existing_height) {
                                    // Candidate entrypoint after this entry
                                    indexToAdd = j + 1
                                }
                            }

                            // Insert this display's resolution if it's not a duplicate
                            if (indexToAdd >= 0) {
                                resolutionListModel.insert(indexToAdd,
                                                           {
                                                               "text": friendlyNamePrefix+" ("+rect.width+"x"+rect.height+")",
                                                               "video_width": ""+rect.width,
                                                               "video_height": ""+rect.height,
                                                               "is_custom": false
                                                           })
                            }
                        }

                        // ignore setting the index at first, and actually set it when the component is loaded
                        Component.onCompleted: {
                            // Refresh display data before using it to build the list
                            SystemProperties.refreshDisplays()

                            // Add native and safe area resolutions for all attached displays
                            var done = false
                            for (var displayIndex = 0; !done; displayIndex++) {
                                var screenRect = SystemProperties.getNativeResolution(displayIndex);
                                var safeAreaRect = SystemProperties.getSafeAreaResolution(displayIndex);

                                if (screenRect.width === 0) {
                                    // Exceeded max count of displays
                                    done = true
                                    break
                                }

                                addDetectedResolution(qsTr("Native"), screenRect)
                                addDetectedResolution(qsTr("Native (Excluding Notch)"), safeAreaRect)
                            }

                            // Prune resolutions that are over the decoder's maximum
                            var max_pixels = SystemProperties.maximumResolution.width * SystemProperties.maximumResolution.height;
                            if (max_pixels > 0) {
                                for (var j = 0; j < resolutionComboBox.count; j++) {
                                    var existing_width = parseInt(resolutionListModel.get(j).video_width);
                                    var existing_height = parseInt(resolutionListModel.get(j).video_height);

                                    if (existing_width * existing_height > max_pixels) {
                                        resolutionListModel.remove(j)
                                        j--
                                    }
                                }
                            }

                            // load the saved width/height, and iterate through the ComboBox until a match is found
                            // and set it to that index.
                            var saved_width = StreamingPreferences.width
                            var saved_height = StreamingPreferences.height
                            var index_set = false
                            for (var i = 0; i < resolutionListModel.count; i++) {
                                var el_width = parseInt(resolutionListModel.get(i).video_width);
                                var el_height = parseInt(resolutionListModel.get(i).video_height);

                                if (saved_width === el_width && saved_height === el_height) {
                                    currentIndex = i
                                    index_set = true
                                    break
                                }
                            }

                            if (!index_set) {
                                // We did not find a match. This must be a custom resolution.
                                resolutionListModel.append({
                                                               "text": qsTr("Custom")+" ("+StreamingPreferences.width+"x"+StreamingPreferences.height+")",
                                                               "video_width": ""+StreamingPreferences.width,
                                                               "video_height": ""+StreamingPreferences.height,
                                                               "is_custom": true
                                                           })
                                currentIndex = resolutionListModel.count - 1
                            }
                            else {
                                resolutionListModel.append({
                                                               "text": qsTr("Custom"),
                                                               "video_width": "",
                                                               "video_height": "",
                                                               "is_custom": true
                                                           })
                            }

                            // Since we don't call activate() here, we need to trigger
                            // width calculation manually
                            recalculateWidth()

                            lastIndexValue = currentIndex
                        }

                        id: resolutionComboBox
                        maximumWidth: parent.width / 2
                        textRole: "text"
                        model: ListModel {
                            id: resolutionListModel
                            // Other elements may be added at runtime
                            // based on attached display resolution
                            ListElement {
                                text: qsTr("720p")
                                video_width: "1280"
                                video_height: "720"
                                is_custom: false
                            }
                            ListElement {
                                text: qsTr("1080p")
                                video_width: "1920"
                                video_height: "1080"
                                is_custom: false
                            }
                            ListElement {
                                text: qsTr("1440p")
                                video_width: "2560"
                                video_height: "1440"
                                is_custom: false
                            }
                            ListElement {
                                text: qsTr("4K")
                                video_width: "3840"
                                video_height: "2160"
                                is_custom: false
                            }
                        }

                        function updateBitrateForSelection() {
                            var selectedWidth = parseInt(resolutionListModel.get(currentIndex).video_width)
                            var selectedHeight = parseInt(resolutionListModel.get(currentIndex).video_height)

                            // Only modify the bitrate if the values actually changed
                            if (StreamingPreferences.width !== selectedWidth || StreamingPreferences.height !== selectedHeight) {
                                StreamingPreferences.width = selectedWidth
                                StreamingPreferences.height = selectedHeight

                                if (StreamingPreferences.autoAdjustBitrate) {
                                    StreamingPreferences.bitrateKbps = StreamingPreferences.getDefaultBitrate(StreamingPreferences.width,
                                                                                                              StreamingPreferences.height,
                                                                                                              StreamingPreferences.fps,
                                                                                                              StreamingPreferences.enableYUV444);
                                    slider.value = StreamingPreferences.bitrateKbps
                                }
                            }

                            lastIndexValue = currentIndex
                        }

                        // ::onActivated must be used, as it only listens for when the index is changed by a human
                        onActivated : {
                            if (resolutionListModel.get(currentIndex).is_custom) {
                                customResolutionDialog.open()
                            }
                            else {
                                updateBitrateForSelection()
                            }
                        }

                        NavigableDialog {
                            id: customResolutionDialog
                            standardButtons: Dialog.Ok | Dialog.Cancel
                            onOpened: {
                                // Force keyboard focus on the textbox so keyboard navigation works
                                widthField.forceActiveFocus()

                                // standardButton() was added in Qt 5.10, so we must check for it first
                                if (customResolutionDialog.standardButton) {
                                    customResolutionDialog.standardButton(Dialog.Ok).enabled = customResolutionDialog.isInputValid()
                                }
                            }

                            onClosed: {
                                widthField.clear()
                                heightField.clear()
                            }

                            onRejected: {
                                resolutionComboBox.currentIndex = resolutionComboBox.lastIndexValue
                            }

                            function isInputValid() {
                                // If we have text in either textbox that isn't valid,
                                // reject the input.
                                if ((!widthField.acceptableInput && widthField.text) ||
                                        (!heightField.acceptableInput && heightField.text)) {
                                    return false
                                }

                                // The textboxes need to have text or placeholder text
                                if ((!widthField.text && !widthField.placeholderText) ||
                                        (!heightField.text && !heightField.placeholderText)) {
                                    return false
                                }

                                return true
                            }

                            onAccepted: {
                                // Reject if there's invalid input
                                if (!isInputValid()) {
                                    reject()
                                    return
                                }

                                var width = widthField.text ? widthField.text : widthField.placeholderText
                                var height = heightField.text ? heightField.text : heightField.placeholderText

                                // Find and update the custom entry
                                for (var i = 0; i < resolutionListModel.count; i++) {
                                    if (resolutionListModel.get(i).is_custom) {
                                        resolutionListModel.setProperty(i, "video_width", width)
                                        resolutionListModel.setProperty(i, "video_height", height)
                                        resolutionListModel.setProperty(i, "text", "Custom ("+width+"x"+height+")")

                                        // Now update the bitrate using the custom resolution
                                        resolutionComboBox.currentIndex = i
                                        resolutionComboBox.updateBitrateForSelection()

                                        // Update the combobox width too
                                        resolutionComboBox.recalculateWidth()
                                        break
                                    }
                                }
                            }

                            ColumnLayout {
                                Label {
                                    text: qsTr("Custom resolutions are not officially supported by GeForce Experience, so it will not set your host display resolution. You will need to set it manually while in game.") + "\n\n" +
                                          qsTr("Resolutions that are not supported by your client or host PC may cause streaming errors.") + "\n"
                                    wrapMode: Label.WordWrap
                                    Layout.maximumWidth: 300
                                }

                                Label {
                                    text: qsTr("Enter a custom resolution:")
                                    font.bold: true
                                }

                                RowLayout {
                                    TextField {
                                        id: widthField
                                        maximumLength: 5
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        placeholderText: resolutionListModel.get(resolutionComboBox.currentIndex).video_width
                                        validator: IntValidator{bottom:256; top:8192}
                                        focus: true

                                        onTextChanged: {
                                            // standardButton() was added in Qt 5.10, so we must check for it first
                                            if (customResolutionDialog.standardButton) {
                                                customResolutionDialog.standardButton(Dialog.Ok).enabled = customResolutionDialog.isInputValid()
                                            }
                                        }

                                        Keys.onReturnPressed: {
                                            customResolutionDialog.accept()
                                        }

                                        Keys.onEnterPressed: {
                                            customResolutionDialog.accept()
                                        }
                                    }

                                    Label {
                                        text: "x"
                                        font.bold: true
                                    }

                                    TextField {
                                        id: heightField
                                        maximumLength: 5
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        placeholderText: resolutionListModel.get(resolutionComboBox.currentIndex).video_height
                                        validator: IntValidator{bottom:256; top:8192}

                                        onTextChanged: {
                                            // standardButton() was added in Qt 5.10, so we must check for it first
                                            if (customResolutionDialog.standardButton) {
                                                customResolutionDialog.standardButton(Dialog.Ok).enabled = customResolutionDialog.isInputValid()
                                            }
                                        }

                                        Keys.onReturnPressed: {
                                            customResolutionDialog.accept()
                                        }

                                        Keys.onEnterPressed: {
                                            customResolutionDialog.accept()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    AutoResizingComboBox {
                        // Redesign: card look, matching the Resolution card. Visual only.
                        width: (parent.width - parent.spacing) / 2
                        padding: 0
                        // Same content-margin sizing fix as the Resolution card — keeps
                        // the frame-rate value text inside the card bounds.
                        implicitHeight: fpsCardContent.implicitHeight + 48
                        background: Rectangle {
                            color: VbTokens.bgElev
                            radius: VbTokens.radiusCard
                            border.width: fpsComboBox.activeFocus ? VbTokens.focusBorder : 1
                            border.color: fpsComboBox.activeFocus ? VbTokens.accent : VbTokens.stroke
                        }
                        indicator: Item { width: 0; height: 0 }
                        contentItem: Column {
                            id: fpsCardContent
                            anchors.fill: parent
                            anchors.margins: 24
                            spacing: 10
                            Text {
                                width: parent.width
                                text: qsTr("Frame rate")
                                font.family: VbTokens.fontBody
                                font.weight: Font.DemiBold
                                font.pixelSize: VbTokens.sizeLabel
                                color: VbTokens.textDim
                                elide: Text.ElideRight
                            }
                            Row {
                                width: parent.width
                                Text {
                                    width: parent.width - 26
                                    text: fpsComboBox.displayText
                                    font.family: VbTokens.fontBody
                                    font.weight: Font.Bold
                                    font.pixelSize: 20
                                    color: VbTokens.text
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: "⌄"
                                    font.pixelSize: 20
                                    color: VbTokens.textDim
                                }
                            }
                        }
                        // Fixed-width card combo — elide long popup entries (e.g.
                        // "Custom (119.88 Hz)") instead of letting them overflow the delegate.
                        delegate: ItemDelegate {
                            width: fpsComboBox.width
                            highlighted: fpsComboBox.highlightedIndex === index
                            contentItem: Text {
                                text: model.text
                                font: fpsComboBox.font
                                color: VbTokens.text
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        property int lastIndexValue

                        function updateBitrateForSelection() {
                            // Only modify the bitrate if the values actually changed
                            var selectedFps = parseInt(model.get(fpsComboBox.currentIndex).video_fps)
                            if (StreamingPreferences.fps !== selectedFps) {
                                StreamingPreferences.fps = selectedFps

                                if (StreamingPreferences.autoAdjustBitrate) {
                                    StreamingPreferences.bitrateKbps = StreamingPreferences.getDefaultBitrate(StreamingPreferences.width,
                                                                                                              StreamingPreferences.height,
                                                                                                              StreamingPreferences.fps,
                                                                                                              StreamingPreferences.enableYUV444);
                                    slider.value = StreamingPreferences.bitrateKbps
                                }
                            }

                            lastIndexValue = currentIndex
                        }

                        NavigableDialog {
                            property bool isRefreshRateMode: false
                            
                            function isInputValid() {
                                // If we have text that isn't valid, reject the input.
                                if (!fpsField.acceptableInput && fpsField.text) {
                                    return false
                                }

                                // Allow empty field (will use placeholder text) or valid input
                                return true
                            }

                            id: customFpsDialog
                            title: qsTr("Custom Display Refresh Rate")
                            standardButtons: Dialog.Ok | Dialog.Cancel
                            onOpened: {
                                // Force keyboard focus on the textbox so keyboard navigation works
                                fpsField.forceActiveFocus()

                                // Check if we have a saved custom refresh rate value
                                if (StreamingPreferences.enableFractionalRefreshRate && StreamingPreferences.customRefreshRate > 0) {
                                    fpsField.text = StreamingPreferences.customRefreshRate.toString()
                                    customFpsDialog.isRefreshRateMode = true
                                } else {
                                    fpsField.text = ""
                                    customFpsDialog.isRefreshRateMode = false
                                }

                                // standardButton() was added in Qt 5.10, so we must check for it first
                                if (customFpsDialog.standardButton) {
                                    customFpsDialog.standardButton(Dialog.Ok).enabled = customFpsDialog.isInputValid()
                                }
                            }

                            onClosed: {
                                fpsField.clear()
                            }

                            onRejected: {
                                fpsComboBox.currentIndex = fpsComboBox.lastIndexValue
                            }

                            onAccepted: {
                                // Reject if there's invalid input
                                if (!isInputValid()) {
                                    reject()
                                    return
                                }

                                // Check if user entered a value
                                var enteredValue = fpsField.text ? fpsField.text : fpsField.placeholderText
                                var hasCustomValue = fpsField.text && fpsField.text.trim() !== ""
                                
                                if (hasCustomValue) {
                                    // User entered a custom refresh rate - enable fractional refresh rate mode
                                    var refreshRate = parseFloat(enteredValue)
                                    if (!isNaN(refreshRate)) {
                                        StreamingPreferences.customRefreshRate = refreshRate
                                        StreamingPreferences.enableFractionalRefreshRate = true
                                        StreamingPreferences.fps = Math.round(refreshRate)
                                        
                                        // Update the FPS dropdown to reflect the new value
                                        for (var i = 0; i < fpsListModel.count; i++) {
                                            if (fpsListModel.get(i).is_custom) {
                                                fpsListModel.setProperty(i, "video_fps", Math.round(refreshRate).toString())
                                                fpsListModel.setProperty(i, "text", qsTr("Custom (%1 Hz)").arg(refreshRate.toFixed(2)))
                                                fpsComboBox.currentIndex = i
                                                fpsComboBox.updateBitrateForSelection()
                                                fpsComboBox.recalculateWidth()
                                                break
                                            }
                                        }
                                    }
                                } else {
                                    // User didn't enter a value - disable fractional refresh rate mode
                                    StreamingPreferences.enableFractionalRefreshRate = false
                                    
                                    // Use default/standard FPS value 
                                    var fps = parseInt(fpsField.placeholderText)
                                    if (isNaN(fps)) fps = 60 // fallback to 60 FPS
                                    
                                    StreamingPreferences.fps = fps

                                    // Find and update the custom entry
                                    for (var i = 0; i < fpsListModel.count; i++) {
                                        if (fpsListModel.get(i).is_custom) {
                                            fpsListModel.setProperty(i, "video_fps", fps.toString())
                                            fpsListModel.setProperty(i, "text", qsTr("Custom (%1 FPS)").arg(fps))

                                            // Now update the bitrate using the custom resolution
                                            fpsComboBox.currentIndex = i
                                            fpsComboBox.updateBitrateForSelection()

                                            // Update the combobox width too
                                            fpsComboBox.recalculateWidth()
                                            break
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                width: Math.max(300, customFpsDialog.availableWidth)
                                spacing: 10

                                Label {
                                    text: qsTr("Enter a custom display refresh rate (Hz):")
                                    font.bold: true
                                }

                                RowLayout {
                                        TextField {
                                            id: fpsField
                                            maximumLength: 6
                                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                                            placeholderText: "144.0"
                                            validator: refreshRateValidator
                                            focus: true

                                            IntValidator {
                                                id: intValidator
                                                bottom: 10
                                                top: 500
                                            }
                                            
                                            DoubleValidator {
                                                id: refreshRateValidator
                                                bottom: 10.0
                                                top: 500.0
                                                decimals: 2
                                            }

                                        onTextChanged: {
                                            // Automatically enable fractional refresh rate if there's a value
                                            var hasValue = fpsField.text && fpsField.text.trim() !== ""
                                            customFpsDialog.isRefreshRateMode = hasValue
                                            StreamingPreferences.enableFractionalRefreshRate = hasValue
                                            
                                            // standardButton() was added in Qt 5.10, so we must check for it first
                                            if (customFpsDialog.standardButton) {
                                                customFpsDialog.standardButton(Dialog.Ok).enabled = customFpsDialog.isInputValid()
                                            }
                                        }

                                        Keys.onReturnPressed: {
                                            customFpsDialog.accept()
                                        }

                                        Keys.onEnterPressed: {
                                            customFpsDialog.accept()
                                        }
                                    }
                                }
                            }
                        }

                        function addRefreshRateOrdered(fpsListModel, refreshRate, description, custom) {
                            var indexToAdd = 0
                            for (var j = 0; j < fpsListModel.count; j++) {
                                var existing_fps = parseInt(fpsListModel.get(j).video_fps);

                                if (refreshRate === existing_fps || (custom && fpsListModel.get(j).is_custom)) {
                                    // Duplicate entry, skip
                                    indexToAdd = -1
                                    break
                                }
                                else if (refreshRate > existing_fps) {
                                    // Candidate entrypoint after this entry
                                    indexToAdd = j + 1
                                }
                            }

                            // Insert this frame rate if it's not a duplicate
                            if (indexToAdd >= 0) {
                                // Custom values always go at the end of the list
                                if (custom) {
                                    indexToAdd = fpsListModel.count
                                }

                                fpsListModel.insert(indexToAdd,
                                                    {
                                                        "text": description,
                                                        "video_fps": ""+refreshRate,
                                                        "is_custom": custom
                                                    })
                            }

                            return indexToAdd
                        }

                        function reinitialize() {
                            // Add native refresh rate for all attached displays
                            var done = false
                            for (var displayIndex = 0; !done; displayIndex++) {
                                var refreshRate = SystemProperties.getRefreshRate(displayIndex);
                                if (refreshRate === 0) {
                                    // Exceeded max count of displays
                                    done = true
                                    break
                                }

                                addRefreshRateOrdered(fpsListModel, refreshRate, qsTr("%1 FPS").arg(refreshRate), false)
                            }

                            var saved_fps = StreamingPreferences.fps
                            var found = false
                            for (var i = 0; i < model.count; i++) {
                                var el_fps = parseInt(model.get(i).video_fps);

                                // Look for a matching frame rate
                                if (saved_fps === el_fps) {
                                    currentIndex = i
                                    found = true
                                    break
                                }
                            }

                            // If we didn't find one, add a custom frame rate for the current value
                            if (!found) {
                                currentIndex = addRefreshRateOrdered(model, saved_fps, qsTr("Custom (%1 FPS)").arg(saved_fps), true)
                            }
                            else {
                                addRefreshRateOrdered(model, "", qsTr("Custom"), true)
                            }

                            recalculateWidth()

                            lastIndexValue = currentIndex
                        }

                        // ignore setting the index at first, and actually set it when the component is loaded
                        Component.onCompleted: {
                            reinitialize()
                            languageChanged.connect(reinitialize)
                        }

                        model: ListModel {
                            id: fpsListModel
                            // Other elements may be added at runtime
                            ListElement {
                                text: qsTr("30 FPS")
                                video_fps: "30"
                                is_custom: false
                            }
                            ListElement {
                                text: qsTr("60 FPS")
                                video_fps: "60"
                                is_custom: false
                            }
                        }

                        id: fpsComboBox
                        maximumWidth: parent.width / 2
                        textRole: "text"
                        // ::onActivated must be used, as it only listens for when the index is changed by a human
                        onActivated : {
                            if (model.get(currentIndex).is_custom) {
                                customFpsDialog.open()
                            }
                            else {
                                updateBitrateForSelection()
                            }
                        }
                    }
                }

                Label {
                    width: parent.width
                    id: bitrateDesc
                    text: qsTr("Lower the bitrate on slower connections. Raise the bitrate to increase image quality.")
                    font.pointSize: 9
                    wrapMode: Text.Wrap
                    color: VbTokens.textDim
                }

                // ---- Video bitrate card (redesign) ----
                Rectangle {
                    width: parent.width
                    height: bitrateCardColumn.implicitHeight + 52
                    radius: VbTokens.radiusCard
                    color: VbTokens.bgElev
                    border.width: 1
                    border.color: VbTokens.stroke

                    Column {
                        id: bitrateCardColumn
                        anchors.fill: parent
                        anchors.margins: 26
                        spacing: 16

                        Item {
                            width: parent.width
                            height: Math.max(bitrateTitle.implicitHeight, bitrateValueText.implicitHeight)

                            Text {
                                id: bitrateTitle
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Video bitrate")
                                font.family: VbTokens.fontBody
                                font.weight: Font.DemiBold
                                font.pixelSize: 17
                                color: VbTokens.text
                            }
                            Text {
                                id: bitrateValueText
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("%1 Mbps").arg((StreamingPreferences.bitrateKbps / 1000).toFixed(0))
                                font.family: VbTokens.fontBody
                                font.weight: Font.ExtraBold
                                font.pixelSize: 17
                                color: VbTokens.accent
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 12

                            Slider {
                                id: slider

                                value: StreamingPreferences.bitrateKbps

                                stepSize: 500
                                from : 500
                                to: StreamingPreferences.unlockBitrate ? 500000 : 150000

                                snapMode: "SnapOnRelease"
                                width: parent.width - (resetBitrateButton.visible ? resetBitrateButton.width + parent.spacing : 0)

                                background: Rectangle {
                                    x: slider.leftPadding
                                    y: slider.topPadding + slider.availableHeight / 2 - height / 2
                                    width: slider.availableWidth
                                    height: 10
                                    radius: 6
                                    color: VbTokens.bgWindow
                                    Rectangle {
                                        width: slider.visualPosition * parent.width
                                        height: parent.height
                                        radius: 6
                                        color: VbTokens.accent
                                    }
                                }
                                handle: Rectangle {
                                    x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                                    y: slider.topPadding + slider.availableHeight / 2 - height / 2
                                    width: 26
                                    height: 26
                                    radius: 13
                                    color: VbTokens.text
                                }

                                onValueChanged: {
                                    StreamingPreferences.bitrateKbps = value
                                }

                                onMoved: {
                                    StreamingPreferences.autoAdjustBitrate = false
                                }
                            }

                            Button {
                                id: resetBitrateButton
                                font.capitalization: Font.MixedCase   // Vibemis: no ALL-CAPS "USE DEFAULT (30 MBPS)"
                                text: qsTr("Use Default (%1 Mbps)").arg(StreamingPreferences.getDefaultBitrate(StreamingPreferences.width, StreamingPreferences.height, StreamingPreferences.fps, StreamingPreferences.enableYUV444) / 1000.0)
                                visible: StreamingPreferences.bitrateKbps !== StreamingPreferences.getDefaultBitrate(StreamingPreferences.width, StreamingPreferences.height, StreamingPreferences.fps, StreamingPreferences.enableYUV444)
                                onClicked: {
                                    var defaultBitrate = StreamingPreferences.getDefaultBitrate(StreamingPreferences.width, StreamingPreferences.height, StreamingPreferences.fps, StreamingPreferences.enableYUV444)
                                    StreamingPreferences.bitrateKbps = defaultBitrate
                                    StreamingPreferences.autoAdjustBitrate = true
                                    slider.value = defaultBitrate
                                }
                            }
                        }

                        // Vibemis: rough data-usage estimate for the chosen bitrate. Helps users on
                        // metered connections or marginal Wi-Fi gauge cost/feasibility. Video only
                        // (audio/overhead excluded). GB/hour = kbps * 3600 / 8 / 1e6 = kbps * 0.00045.
                        // This is the design's "≈ N GB/hour..." card description line.
                        Text {
                            width: parent.width
                            text: "≈ " + qsTr("%1 GB/hour at this bitrate (video only). Lower on slower connections.")
                                  .arg((StreamingPreferences.bitrateKbps * 0.00045).toFixed(1))
                            font.family: VbTokens.fontBody
                            font.pixelSize: VbTokens.sizeLabel
                            wrapMode: Text.Wrap
                            color: VbTokens.textDim
                        }
                    }
                }

                // Vibemis: adaptive bitrate (experimental). Currently logs a recommendation
                // when the host reports a poor connection; runtime auto-adjust is pending protocol
                // support (see the adaptive-bitrate TODO in session.cpp). Redesign toggle-row visual.
                CheckBox {
                    id: adaptiveBitrateCheck
                    width: parent.width
                    height: 70
                    checked: StreamingPreferences.adaptiveBitrate
                    onCheckedChanged: {
                        StreamingPreferences.adaptiveBitrate = checked
                    }

                    indicator: Item {}
                    background: Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: VbTokens.strokeSoft
                    }
                    contentItem: Item {
                        anchors.fill: parent
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Adaptive bitrate (experimental)")
                            font.family: VbTokens.fontBody
                            font.weight: Font.DemiBold
                            font.pixelSize: 18
                            color: VbTokens.text
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 60; height: 34; radius: 999
                            color: adaptiveBitrateCheck.checked ? VbTokens.accent : "#2A2F37"
                            Rectangle {
                                width: 26; height: 26; radius: 13
                                anchors.verticalCenter: parent.verticalCenter
                                x: adaptiveBitrateCheck.checked ? parent.width - width - 4 : 4
                                color: adaptiveBitrateCheck.checked ? "#08090B" : VbTokens.textDim
                                Behavior on x { NumberAnimation { duration: 120 } }
                            }
                        }
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Experimental: when the connection to the host degrades, Vibemis notes a recommendation to lower the bitrate. Automatic runtime adjustment is still in development.")
                }

                // Vibemis (perf guidance): advise when the bitrate is set well above the recommended
                // default for the chosen resolution/fps. Very high bitrate over Wi-Fi (common on a
                // handheld) is the usual cause of stutter/dropped frames. Threshold = 2x recommended.
                Label {
                    width: parent.width
                    visible: StreamingPreferences.bitrateKbps >
                             StreamingPreferences.getDefaultBitrate(StreamingPreferences.width, StreamingPreferences.height, StreamingPreferences.fps, StreamingPreferences.enableYUV444) * 2
                    text: "⚠ " + qsTr("This bitrate is much higher than recommended for the selected resolution. On Wi-Fi this often causes stutter or dropped frames — lower it if the stream isn't smooth.")
                    font.pointSize: 9
                    wrapMode: Text.Wrap
                    color: "#E0A030"
                    topPadding: 4
                }

                Label {
                    width: parent.width
                    id: windowModeTitle
                    text: qsTr("Display mode")
                    font.pointSize: 12
                    wrapMode: Text.Wrap
                    visible: SystemProperties.hasDesktopEnvironment
                }

                AutoResizingComboBox {
                    function createModel() {
                        var model = Qt.createQmlObject('import QtQuick 2.0; ListModel {}', parent, '')

                        model.append({
                                         text: qsTr("Fullscreen"),
                                         val: StreamingPreferences.WM_FULLSCREEN
                                     })

                        model.append({
                                         text: qsTr("Borderless windowed"),
                                         val: StreamingPreferences.WM_FULLSCREEN_DESKTOP
                                     })

                        model.append({
                                         text: qsTr("Windowed"),
                                         val: StreamingPreferences.WM_WINDOWED
                                     })


                        // Set the recommended option based on the OS
                        for (var i = 0; i < model.count; i++) {
                            var thisWm = model.get(i).val;
                            if (thisWm === StreamingPreferences.recommendedFullScreenMode) {
                                model.get(i).text += " " + qsTr("(Recommended)")
                                model.move(i, 0, 1)
                                break
                            }
                        }

                        return model
                    }


                    // This is used on initialization and upon retranslation
                    function reinitialize() {
                        if (!visible) {
                            // Do nothing if the control won't even be visible
                            return
                        }

                        model = createModel()
                        currentIndex = 0

                        // Set the current value based on the saved preferences
                        var savedWm = StreamingPreferences.windowMode
                        for (var i = 0; i < model.count; i++) {
                             var thisWm = model.get(i).val;
                             if (savedWm === thisWm) {
                                 currentIndex = i
                                 break
                             }
                        }

                        activated(currentIndex)
                    }

                    Component.onCompleted: {
                        reinitialize()
                        languageChanged.connect(reinitialize)
                    }

                    id: windowModeComboBox
                    visible: SystemProperties.hasDesktopEnvironment
                    enabled: !SystemProperties.rendererAlwaysFullScreen
                    hoverEnabled: true
                    textRole: "text"
                    onActivated: {
                        StreamingPreferences.windowMode = model.get(currentIndex).val
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Fullscreen generally provides the best performance, but borderless windowed may work better with features like macOS Spaces, Alt+Tab, screenshot tools, on-screen overlays, etc.")
                }

                Label {
                    width: parent.width
                    id: videoScaleModeTitle
                    text: qsTr("Video scaling")
                    font.pointSize: 12
                    wrapMode: Text.Wrap
                }

                AutoResizingComboBox {
                    id: videoScaleModeComboBox
                    textRole: "text"
                    hoverEnabled: true
                    model: ListModel {
                        id: videoScaleModeModel
                        ListElement { text: qsTr("Fit (preserve aspect, letterbox)"); val: 0 }
                        ListElement { text: qsTr("Fill (crop to fill screen)"); val: 1 }
                        ListElement { text: qsTr("Stretch (fill, ignore aspect)"); val: 2 }
                    }

                    function reinitialize() {
                        var saved = StreamingPreferences.videoScaleMode
                        currentIndex = 0
                        for (var i = 0; i < videoScaleModeModel.count; i++) {
                            if (videoScaleModeModel.get(i).val === saved) {
                                currentIndex = i
                                break
                            }
                        }
                    }

                    Component.onCompleted: {
                        reinitialize()
                        languageChanged.connect(reinitialize)
                    }

                    onActivated: {
                        StreamingPreferences.videoScaleMode = videoScaleModeModel.get(currentIndex).val
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Fit shows the whole image with black bars if needed. Fill crops the image to fill the screen with no bars. Stretch fills the screen ignoring the aspect ratio.")
                }

                // Redesign toggle-row (title + sublabel + pill switch). Matches the design's
                // "V-Sync" row text exactly; the fuller explanation moves to the tooltip.
                CheckBox {
                    id: vsyncCheck
                    width: parent.width
                    height: 70
                    hoverEnabled: true
                    checked: StreamingPreferences.enableVsync
                    onCheckedChanged: {
                        StreamingPreferences.enableVsync = checked
                    }

                    indicator: Item {}
                    background: Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: VbTokens.strokeSoft
                    }
                    contentItem: Item {
                        anchors.fill: parent
                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 80
                            spacing: 2
                            Text {
                                text: qsTr("V-Sync")
                                font.family: VbTokens.fontBody
                                font.weight: Font.DemiBold
                                font.pixelSize: 18
                                color: VbTokens.text
                            }
                            Text {
                                width: parent.width
                                text: qsTr("Reduces tearing; may add latency")
                                font.family: VbTokens.fontBody
                                font.pixelSize: VbTokens.sizeLabel
                                color: VbTokens.textDim
                                wrapMode: Text.Wrap
                            }
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 60; height: 34; radius: 999
                            color: vsyncCheck.checked ? VbTokens.accent : "#2A2F37"
                            Rectangle {
                                width: 26; height: 26; radius: 13
                                anchors.verticalCenter: parent.verticalCenter
                                x: vsyncCheck.checked ? parent.width - width - 4 : 4
                                color: vsyncCheck.checked ? "#08090B" : VbTokens.textDim
                                Behavior on x { NumberAnimation { duration: 120 } }
                            }
                        }
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Disabling V-Sync allows sub-frame rendering latency, but it can display visible tearing")
                }

                // Redesign toggle-row. Extra setting beyond the mock — same visual
                // language as V-Sync above for consistency.
                CheckBox {
                    id: framePacingCheck
                    width: parent.width
                    height: 70
                    hoverEnabled: true
                    enabled: StreamingPreferences.enableVsync
                    opacity: enabled ? 1.0 : 0.5
                    checked: StreamingPreferences.enableVsync && StreamingPreferences.framePacing
                    onCheckedChanged: {
                        StreamingPreferences.framePacing = checked
                    }

                    indicator: Item {}
                    background: Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: VbTokens.strokeSoft
                    }
                    contentItem: Item {
                        anchors.fill: parent
                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 80
                            spacing: 2
                            Text {
                                text: qsTr("Frame pacing")
                                font.family: VbTokens.fontBody
                                font.weight: Font.DemiBold
                                font.pixelSize: 18
                                color: VbTokens.text
                            }
                            Text {
                                width: parent.width
                                text: qsTr("Reduces micro-stutter by delaying early frames")
                                font.family: VbTokens.fontBody
                                font.pixelSize: VbTokens.sizeLabel
                                color: VbTokens.textDim
                                wrapMode: Text.Wrap
                            }
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 60; height: 34; radius: 999
                            color: framePacingCheck.checked ? VbTokens.accent : "#2A2F37"
                            Rectangle {
                                width: 26; height: 26; radius: 13
                                anchors.verticalCenter: parent.verticalCenter
                                x: framePacingCheck.checked ? parent.width - width - 4 : 4
                                color: framePacingCheck.checked ? "#08090B" : VbTokens.textDim
                                Behavior on x { NumberAnimation { duration: 120 } }
                            }
                        }
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Frame pacing reduces micro-stutter by delaying frames that come in too early")
                }

                // Vibemis: one-tap low-latency / "competitive" preset. Frame pacing delays
                // early frames (smoother but higher latency) and V-Sync adds a frame of latency;
                // turning both off minimises input-to-photon latency for fast/competitive games.
                Button {
                    id: lowLatencyPresetButton
                    text: qsTr("Apply low-latency preset")
                    onClicked: {
                        StreamingPreferences.framePacing = false
                        StreamingPreferences.enableVsync = false
                        lowLatencyPresetButton.text = qsTr("Applied — V-Sync & frame pacing off")
                        lowLatencyFeedbackTimer.restart()
                    }
                    Timer {
                        id: lowLatencyFeedbackTimer
                        interval: 2000
                        onTriggered: lowLatencyPresetButton.text = qsTr("Apply low-latency preset")
                    }
                    ToolTip.delay: 1000
                    ToolTip.timeout: 6000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Turns off V-Sync and frame pacing for the lowest input latency (best for fast/competitive games). May introduce slight tearing.")
                }
            }
        }

        // Restyled to the Video-page card pattern (VbSettingsCard + Sora header +
        // VbToggleRow rows). Bindings, visibility logic and tooltips are unchanged.
        VbSettingsCard {
            id: artemisStreamingGroupBox
            visible: settingsPage.category === 3
            width: (parent.width - (parent.leftPadding + parent.rightPadding))
            font.pointSize: 12

            Column {
                anchors.fill: parent
                spacing: 12

                VbSectionHeader {
                    text: qsTr("Vibemis Streaming Enhancements")
                }

                Label {
                    width: parent.width
                    text: qsTr("Client-side streaming enhancements")
                    font.pointSize: 12
                    wrapMode: Text.Wrap
                }

                Label {
                    width: parent.width
                    text: qsTr("These features require an Apollo / Vibepollo host (they use Apollo's extended protocol — not available with plain Sunshine or GeForce Experience).")
                    font.pointSize: 9
                    wrapMode: Text.Wrap
                    color: VbTokens.textDim
                }

                // Virtual Display Control
                VbToggleRow {
                    id: virtualDisplayCheck
                    text: qsTr("Use Virtual Display")
                    checked: StreamingPreferences.useVirtualDisplay
                    onCheckedChanged: {
                        StreamingPreferences.useVirtualDisplay = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Creates a virtual display on the host for streaming. Requires an Apollo / Vibepollo host - not available with plain Sunshine/GeForce Experience.")
                }

                // Vibemis: clarify the virtual-display behavior, which commonly confuses
                // new users. Apollo auto-creates a per-client virtual display matching the
                // resolution/refresh you select above — ideal on a handheld so you don't have to
                // change the host's physical display. Shown contextually based on the toggle.
                Label {
                    width: parent.width
                    visible: virtualDisplayCheck.checked
                    text: qsTr("✓ Your Apollo / Vibepollo host will create a virtual display matching your selected resolution and refresh rate — recommended on a handheld (the host's physical monitor is left untouched).")
                    font.pointSize: 9
                    wrapMode: Text.Wrap
                    color: "#80C080"
                    leftPadding: 8
                }
                Label {
                    width: parent.width
                    visible: !virtualDisplayCheck.checked
                    text: qsTr("Without a virtual display, the stream uses the host's current physical display resolution. Enable this with an Apollo / Vibepollo host to match this device's resolution automatically.")
                    font.pointSize: 9
                    wrapMode: Text.Wrap
                    color: "#aaaaaa"
                    leftPadding: 8
                }

                // Resolution Scaling
                VbToggleRow {
                    id: resolutionScalingCheck
                    text: qsTr("Enable Resolution Scaling")
                    checked: StreamingPreferences.enableResolutionScaling
                    onCheckedChanged: {
                        StreamingPreferences.enableResolutionScaling = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Scales the stream resolution. Useful for improving performance on lower-end devices or increasing quality on high-DPI displays.")
                }

                Row {
                    spacing: 10
                    visible: StreamingPreferences.enableResolutionScaling
                    width: parent.width

                    Label {
                        id: scaleFactorLabel
                        text: qsTr("Scale Factor:")
                        font.pointSize: 10
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Slider {
                        id: resolutionScaleSlider
                        from: 50    // 50%
                        to: 200     // 200%
                        stepSize: 5
                        value: StreamingPreferences.resolutionScaleFactor

                        // This Slider sits in a plain Row and its background derives
                        // width from availableWidth (contributing no implicitWidth), so without
                        // an explicit width it collapsed to ~0px and the handle was undraggable.
                        // Mirror the Video-page bitrate slider: fill the row between the labels.
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - scaleFactorLabel.width - scaleValueLabel.width - (2 * parent.spacing)

                        // Guarantee one arrow / d-pad press moves exactly one stepSize
                        // (5). The default handling was observed stepping twice (+10); overriding
                        // Left/Right with a single accepted increase()/decrease() forces one step
                        // per press and stops Left from bubbling to the Flickable's focus-return
                        // handler mid-adjustment. Range 50-200 / stepSize 5 unchanged.
                        Keys.onLeftPressed: { resolutionScaleSlider.decrease(); event.accepted = true }
                        Keys.onRightPressed: { resolutionScaleSlider.increase(); event.accepted = true }

                        // Same track/handle recipe as the Video page's bitrate slider.
                        background: Rectangle {
                            x: resolutionScaleSlider.leftPadding
                            y: resolutionScaleSlider.topPadding + resolutionScaleSlider.availableHeight / 2 - height / 2
                            width: resolutionScaleSlider.availableWidth
                            height: 10
                            radius: 6
                            color: VbTokens.bgWindow
                            Rectangle {
                                width: resolutionScaleSlider.visualPosition * parent.width
                                height: parent.height
                                radius: 6
                                color: VbTokens.accent
                            }
                        }
                        handle: Rectangle {
                            x: resolutionScaleSlider.leftPadding + resolutionScaleSlider.visualPosition * (resolutionScaleSlider.availableWidth - width)
                            y: resolutionScaleSlider.topPadding + resolutionScaleSlider.availableHeight / 2 - height / 2
                            width: 26
                            height: 26
                            radius: 13
                            color: VbTokens.text
                        }

                        onValueChanged: {
                            StreamingPreferences.resolutionScaleFactor = value
                        }
                    }

                    Label {
                        id: scaleValueLabel
                        text: resolutionScaleSlider.value + "%"
                        font.pointSize: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                    }
                }
            }
        }

        // Restyled to the Video-page card pattern. Bindings unchanged.
        VbSettingsCard {
            id: audioSettingsGroupBox
            visible: settingsPage.category === 1
            width: (parent.width - (parent.leftPadding + parent.rightPadding))
            font.pointSize: 12

            Column {
                anchors.fill: parent
                spacing: 12

                VbSectionHeader {
                    text: qsTr("Audio Settings")
                }

                Label {
                    width: parent.width
                    id: resAudioTitle
                    text: qsTr("Audio configuration")
                    font.pointSize: 12
                    wrapMode: Text.Wrap
                }

                AutoResizingComboBox {
                    // ignore setting the index at first, and actually set it when the component is loaded
                    Component.onCompleted: {
                        var saved_audio = StreamingPreferences.audioConfig
                        currentIndex = 0
                        for (var i = 0; i < audioListModel.count; i++) {
                            var el_audio = audioListModel.get(i).val;
                            if (saved_audio === el_audio) {
                                currentIndex = i
                                break
                            }
                        }
                        activated(currentIndex)
                    }

                    id: audioComboBox
                    textRole: "text"
                    model: ListModel {
                        id: audioListModel
                        ListElement {
                            text: qsTr("Stereo")
                            val: StreamingPreferences.AC_STEREO
                        }
                        ListElement {
                            text: qsTr("5.1 surround sound")
                            val: StreamingPreferences.AC_51_SURROUND
                        }
                        ListElement {
                            text: qsTr("7.1 surround sound")
                            val: StreamingPreferences.AC_71_SURROUND
                        }
                    }
                    // ::onActivated must be used, as it only listens for when the index is changed by a human
                    onActivated : {
                        StreamingPreferences.audioConfig = audioListModel.get(currentIndex).val
                    }
                }


                VbToggleRow {
                    id: audioPcCheck
                    text: qsTr("Mute host PC speakers while streaming")
                    checked: !StreamingPreferences.playAudioOnHost
                    onCheckedChanged: {
                        StreamingPreferences.playAudioOnHost = !checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("You must restart any game currently in progress for this setting to take effect")
                }

                VbToggleRow {
                    id: muteOnFocusLossCheck
                    text: qsTr("Mute audio stream when Vibemis is not the active window")
                    visible: SystemProperties.hasDesktopEnvironment
                    checked: StreamingPreferences.muteOnFocusLoss
                    onCheckedChanged: {
                        StreamingPreferences.muteOnFocusLoss = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Mutes Vibemis's audio when you Alt+Tab out of the stream or click on a different window.")
                }
            }
        }

        // Restyled to the Video-page card pattern. Bindings unchanged.
        VbSettingsCard {
            id: hostSettingsGroupBox
            visible: settingsPage.category === 3
            width: (parent.width - (parent.leftPadding + parent.rightPadding))
            font.pointSize: 12

            Column {
                anchors.fill: parent
                spacing: 12

                VbSectionHeader {
                    text: qsTr("Host Settings")
                }

                VbToggleRow {
                    id: optimizeGameSettingsCheck
                    text: qsTr("Optimize game settings for streaming")
                    checked: StreamingPreferences.gameOptimizations
                    onCheckedChanged: {
                        StreamingPreferences.gameOptimizations = checked
                    }
                }

                VbToggleRow {
                    id: quitAppAfter
                    text: qsTr("Quit app on host PC after ending stream")
                    checked: StreamingPreferences.quitAppAfter
                    onCheckedChanged: {
                        StreamingPreferences.quitAppAfter = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("This will close the app or game you are streaming when you end your stream. You will lose any unsaved progress!")
                }

                VbToggleRow {
                    id: autoReconnectCheck
                    text: qsTr("Automatically reconnect if the stream drops")
                    checked: StreamingPreferences.autoReconnect
                    onCheckedChanged: {
                        StreamingPreferences.autoReconnect = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("If a stream ends unexpectedly (a network blip or the host waking), Vibemis will try to reconnect automatically.")
                }
            }
        }

        // Restyled to the Video-page card pattern. Bindings unchanged.
        VbSettingsCard {
            id: uiSettingsGroupBox
            visible: settingsPage.category === 4
            width: (parent.width - (parent.leftPadding + parent.rightPadding))
            font.pointSize: 12

            Column {
                anchors.fill: parent
                spacing: 12

                VbSectionHeader {
                    text: qsTr("UI Settings")
                }

                Label {
                    width: parent.width
                    id: languageTitle
                    text: qsTr("Language")
                    font.pointSize: 12
                    wrapMode: Text.Wrap
                }

                AutoResizingComboBox {
                    // ignore setting the index at first, and actually set it when the component is loaded
                    Component.onCompleted: {
                        var saved_language = StreamingPreferences.language
                        currentIndex = 0
                        for (var i = 0; i < languageListModel.count; i++) {
                            var el_language = languageListModel.get(i).val;
                            if (saved_language === el_language) {
                                currentIndex = i
                                break
                            }
                        }

                        activated(currentIndex)
                    }

                    id: languageComboBox
                    textRole: "text"
                    model: ListModel {
                        id: languageListModel
                        ListElement {
                            text: qsTr("Automatic")
                            val: StreamingPreferences.LANG_AUTO
                        }
                        ListElement {
                            text: "Deutsch" // German
                            val: StreamingPreferences.LANG_DE
                        }
                        ListElement {
                            text: "English"
                            val: StreamingPreferences.LANG_EN
                        }
                        ListElement {
                            text: "Français" // French
                            val: StreamingPreferences.LANG_FR
                        }
                        ListElement {
                            text: "简体中文" // Simplified Chinese
                            val: StreamingPreferences.LANG_ZH_CN
                        }
                        ListElement {
                            text: "Norwegian Bokmål"
                            val: StreamingPreferences.LANG_NB_NO
                        }
                        ListElement {
                            text: "русский" // Russian
                            val: StreamingPreferences.LANG_RU
                        }
                        ListElement {
                            text: "Español" // Spanish
                            val: StreamingPreferences.LANG_ES
                        }
                        ListElement {
                            text: "日本語" // Japanese
                            val: StreamingPreferences.LANG_JA
                        }
                        ListElement {
                            text: "Tiếng Việt" // Vietnamese
                            val: StreamingPreferences.LANG_VI
                        }
                        ListElement {
                            text: "ภาษาไทย" // Thai
                            val: StreamingPreferences.LANG_TH
                        }
                        ListElement {
                            text: "한국어" // Korean
                            val: StreamingPreferences.LANG_KO
                        }
                        ListElement {
                            text: "Magyar" // Hungarian
                            val: StreamingPreferences.LANG_HU
                        }
                        ListElement {
                            text: "Nederlands" // Dutch
                            val: StreamingPreferences.LANG_NL
                        }
                        ListElement {
                            text: "Svenska" // Swedish
                            val: StreamingPreferences.LANG_SV
                        }
                        ListElement {
                            text: "Türkçe" // Turkish
                            val: StreamingPreferences.LANG_TR
                        }
                        /* ListElement {
                            text: "Українська" // Ukrainian
                            val: StreamingPreferences.LANG_UK
                        } */
                        ListElement {
                            text: "繁體中文" // Traditional Chinese
                            val: StreamingPreferences.LANG_ZH_TW
                        }
                        ListElement {
                            text: "Português" // Portuguese
                            val: StreamingPreferences.LANG_PT
                        }
                        ListElement {
                            text: "Português do Brasil" // Brazilian Portuguese
                            val: StreamingPreferences.LANG_PT_BR
                        }
                        ListElement {
                            text: "Ελληνικά" // Greek
                            val: StreamingPreferences.LANG_EL
                        }
                        ListElement {
                            text: "Italiano" // Italian
                            val: StreamingPreferences.LANG_IT
                        }
                        /* ListElement {
                            text: "हिन्दी, हिंदी" // Hindi
                            val: StreamingPreferences.LANG_HI
                        } */
                        ListElement {
                            text: "Język polski" // Polish
                            val: StreamingPreferences.LANG_PL
                        }
                        ListElement {
                            text: "Čeština" // Czech
                            val: StreamingPreferences.LANG_CS
                        }
                        /* ListElement {
                            text: "עִבְרִית" // Hebrew
                            val: StreamingPreferences.LANG_HE
                        } */
                        /* ListElement {
                            text: "کرمانجیی خواروو" // Central Kurdish
                            val: StreamingPreferences.LANG_CKB
                        } */
                        /* ListElement {
                            text: "Lietuvių kalba" // Lithuanian
                            val: StreamingPreferences.LANG_LT
                        } */
                        /* ListElement {
                            text: "Eesti" // Estonian
                            val: StreamingPreferences.LANG_ET
                        } */
                        ListElement {
                            text: "Български" // Bulgarian
                            val: StreamingPreferences.LANG_BG
                        }
                        /* ListElement {
                            text: "Esperanto"
                            val: StreamingPreferences.LANG_EO
                        } */
                        ListElement {
                            text: "தமிழ்" // Tamil
                            val: StreamingPreferences.LANG_TA
                        }
                    }
                    // ::onActivated must be used, as it only listens for when the index is changed by a human
                    onActivated : {
                        // Retranslating is expensive, so only do it if the language actually changed
                        var new_language = languageListModel.get(currentIndex).val
                        if (StreamingPreferences.language !== new_language) {
                            StreamingPreferences.language = languageListModel.get(currentIndex).val
                            if (!StreamingPreferences.retranslate()) {
                                ToolTip.show(qsTr("You must restart Vibemis for this change to take effect"), 5000)
                            }
                            else {
                                // Force the back operation to pop any AppView pages that exist.
                                // The AppView stops working after retranslate() for some reason.
                                window.clearOnBack = true

                                // Signal other controls to adjust their text
                                languageChanged()
                            }
                        }
                    }
                }

                Label {
                    width: parent.width
                    id: uiDisplayModeTitle
                    text: qsTr("GUI display mode")
                    font.pointSize: 12
                    wrapMode: Text.Wrap
                    visible: SystemProperties.hasDesktopEnvironment
                }

                AutoResizingComboBox {
                    // ignore setting the index at first, and actually set it when the component is loaded
                    Component.onCompleted: {
                        if (!visible) {
                            // Do nothing if the control won't even be visible
                            return
                        }

                        var saved_uidisplaymode = StreamingPreferences.uiDisplayMode
                        currentIndex = 0
                        for (var i = 0; i < uiDisplayModeListModel.count; i++) {
                            var el_uidisplaymode = uiDisplayModeListModel.get(i).val;
                            if (saved_uidisplaymode === el_uidisplaymode) {
                                currentIndex = i
                                break
                            }
                        }

                        activated(currentIndex)
                    }

                    id: uiDisplayModeComboBox
                    visible: SystemProperties.hasDesktopEnvironment
                    textRole: "text"
                    model: ListModel {
                        id: uiDisplayModeListModel
                        ListElement {
                            text: qsTr("Windowed")
                            val: StreamingPreferences.UI_WINDOWED
                        }
                        ListElement {
                            text: qsTr("Maximized")
                            val: StreamingPreferences.UI_MAXIMIZED
                        }   
                        ListElement {
                            text: qsTr("Fullscreen")
                            val: StreamingPreferences.UI_FULLSCREEN
                        }
                    }
                    // ::onActivated must be used, as it only listens for when the index is changed by a human
                    onActivated : {
                        StreamingPreferences.uiDisplayMode = uiDisplayModeListModel.get(currentIndex).val
                    }
                }

                VbToggleRow {
                    id: connectionWarningsCheck
                    text: qsTr("Show connection quality warnings")
                    checked: StreamingPreferences.connectionWarnings
                    onCheckedChanged: {
                        StreamingPreferences.connectionWarnings = checked
                    }
                }

                VbToggleRow {
                    id: configurationWarningsCheck
                    text: qsTr("Show configuration warnings")
                    checked: StreamingPreferences.configurationWarnings
                    onCheckedChanged: {
                        StreamingPreferences.configurationWarnings = checked
                    }
                }

                // Gate for the controller-nav UI sounds (UiSoundManager)
                VbToggleRow {
                    id: uiSoundsCheck
                    text: qsTr("Play navigation sounds")
                    checked: StreamingPreferences.uiSounds
                    onCheckedChanged: StreamingPreferences.uiSounds = checked
                    ToolTip.text: qsTr("Play a short sound when moving focus or activating items with the gamepad or keyboard, including the in-stream Quick Menu.")
                    ToolTip.delay: 1000
                    ToolTip.visible: hovered
                }

                VbToggleRow {
                    visible: SystemProperties.hasDiscordIntegration
                    id: discordPresenceCheck
                    text: qsTr("Discord Rich Presence integration")
                    checked: StreamingPreferences.richPresence
                    onCheckedChanged: {
                        StreamingPreferences.richPresence = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Updates your Discord status to display the name of the game you're streaming.")
                }

                VbToggleRow {
                    id: keepAwakeCheck
                    text: qsTr("Keep the display awake while streaming")
                    checked: StreamingPreferences.keepAwake
                    onCheckedChanged: {
                        StreamingPreferences.keepAwake = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Prevents the screensaver from starting or the display from going to sleep while streaming.")
                }

                VbToggleRow {
                    id: reduceBitrateOnBatteryCheck
                    text: qsTr("Reduce bitrate when on battery")
                    checked: StreamingPreferences.reduceBitrateOnBattery
                    onCheckedChanged: {
                        StreamingPreferences.reduceBitrateOnBattery = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("When this device is running on battery, start streams at a lower bitrate (60% of the configured value) to save power and reduce heat. Plugged-in streams are unaffected.")
                }

                Label {
                    width: parent.width
                    text: qsTr("Settings backup")
                    font.pointSize: 12
                    topPadding: 6
                }

                Row {
                    spacing: 8

                    Button {
                        text: qsTr("Export settings")
                        onClicked: {
                            var p = StreamingPreferences.exportSettings()
                            settingsBackupStatus.text = p
                                ? qsTr("Exported to %1").arg(p)
                                : qsTr("Export failed")
                        }
                        ToolTip.delay: 1000
                        ToolTip.timeout: 5000
                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("Save all Vibemis settings to ~/vibemis-settings.ini for backup or to copy to another device.")
                    }

                    Button {
                        text: qsTr("Import settings")
                        onClicked: {
                            settingsBackupStatus.text = StreamingPreferences.importSettings()
                                ? qsTr("Imported from ~/vibemis-settings.ini — reopen Settings or restart to see all values.")
                                : qsTr("No backup found at ~/vibemis-settings.ini")
                        }
                        ToolTip.delay: 1000
                        ToolTip.timeout: 5000
                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("Load settings previously exported to ~/vibemis-settings.ini.")
                    }
                }

                Label {
                    id: settingsBackupStatus
                    width: parent.width
                    text: ""
                    visible: text !== ""
                    color: "#00cccc"
                    font.pointSize: 9
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    Column {
        padding: 10
        rightPadding: 20
        bottomPadding: 30
        anchors.top: settingsColumn1.bottom
        anchors.left: settingsColumn1.left
        id: settingsColumn2
        width: settingsFlick.width - 20
        spacing: 15

        // Restyled to the Video-page card pattern. Bindings unchanged. The
        // capture-shortcuts checkbox + mode combo were a side-by-side Row; the toggle row is
        // full-width now, so the combo moved directly below it (layout only — same ids,
        // same enabled/checked logic).
        VbSettingsCard {
            id: inputSettingsGroupBox
            visible: settingsPage.category === 2
            width: (parent.width - (parent.leftPadding + parent.rightPadding))
            font.pointSize: 12

            Column {
                anchors.fill: parent
                spacing: 12

                VbSectionHeader {
                    text: qsTr("Input Settings")
                }

                VbToggleRow {
                    id: absoluteMouseCheck
                    text: qsTr("Optimize mouse for remote desktop instead of games")
                    checked: StreamingPreferences.absoluteMouseMode
                    onCheckedChanged: {
                        StreamingPreferences.absoluteMouseMode = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 10000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("This enables seamless mouse control without capturing the client's mouse cursor. It is ideal for remote desktop usage but will not work in most games.") + " " +
                                  qsTr("You can toggle this while streaming using Ctrl+Alt+Shift+M.") + "\n\n" +
                                  qsTr("NOTE: Due to a bug in GeForce Experience, this option may not work properly if your host PC has multiple monitors.")
                }

                VbToggleRow {
                    id: captureSysKeysCheck
                    text: qsTr("Capture system keyboard shortcuts")
                    enabled: SystemProperties.hasDesktopEnvironment
                    checked: StreamingPreferences.captureSysKeysMode !== StreamingPreferences.CSK_OFF || !SystemProperties.hasDesktopEnvironment

                    ToolTip.delay: 1000
                    ToolTip.timeout: 10000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("This enables the capture of system-wide keyboard shortcuts like Alt+Tab that would normally be handled by the client OS while streaming.") + "\n\n" +
                                  qsTr("NOTE: Certain keyboard shortcuts like Ctrl+Alt+Del on Windows cannot be intercepted by any application, including Vibemis.")
                }

                AutoResizingComboBox {
                    // ignore setting the index at first, and actually set it when the component is loaded
                    Component.onCompleted: {
                        if (!visible) {
                            // Do nothing if the control won't even be visible
                            return
                        }

                        var saved_syskeysmode = StreamingPreferences.captureSysKeysMode
                        currentIndex = 0
                        for (var i = 0; i < captureSysKeysModeListModel.count; i++) {
                            var el_syskeysmode = captureSysKeysModeListModel.get(i).val;
                            if (saved_syskeysmode === el_syskeysmode) {
                                currentIndex = i
                                break
                            }
                        }

                        activated(currentIndex)
                    }

                    enabled: captureSysKeysCheck.checked && captureSysKeysCheck.enabled
                    textRole: "text"
                    model: ListModel {
                        id: captureSysKeysModeListModel
                        ListElement {
                            text: qsTr("in fullscreen")
                            val: StreamingPreferences.CSK_FULLSCREEN
                        }
                        ListElement {
                            text: qsTr("always")
                            val: StreamingPreferences.CSK_ALWAYS
                        }
                    }

                    function updatePref() {
                        if (!enabled) {
                            StreamingPreferences.captureSysKeysMode = StreamingPreferences.CSK_OFF
                        }
                        else {
                            StreamingPreferences.captureSysKeysMode = captureSysKeysModeListModel.get(currentIndex).val
                        }
                    }

                    // ::onActivated must be used, as it only listens for when the index is changed by a human
                    onActivated: {
                        updatePref()
                    }

                    // This handles transition of the checkbox state
                    onEnabledChanged: {
                        updatePref()
                    }
                }

                VbToggleRow {
                    id: absoluteTouchCheck
                    text: qsTr("Use touchscreen as a virtual trackpad")
                    checked: !StreamingPreferences.absoluteTouchMode
                    onCheckedChanged: {
                        StreamingPreferences.absoluteTouchMode = !checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("When checked, the touchscreen acts like a trackpad. When unchecked, the touchscreen will directly control the mouse pointer.")
                }

                VbToggleRow {
                    id: swapMouseButtonsCheck
                    text: qsTr("Swap left and right mouse buttons")
                    checked: StreamingPreferences.swapMouseButtons
                    onCheckedChanged: {
                        StreamingPreferences.swapMouseButtons = checked
                    }
                }

                VbToggleRow {
                    id: reverseScrollButtonsCheck
                    text: qsTr("Reverse mouse scrolling direction")
                    checked: StreamingPreferences.reverseScrollDirection
                    onCheckedChanged: {
                        StreamingPreferences.reverseScrollDirection = checked
                    }
                }
            }
        }

        // Restyled to the Video-page card pattern. Bindings unchanged.
        VbSettingsCard {
            id: gamepadSettingsGroupBox
            visible: settingsPage.category === 2
            width: (parent.width - (parent.leftPadding + parent.rightPadding))
            font.pointSize: 12

            Column {
                anchors.fill: parent
                spacing: 12

                VbSectionHeader {
                    text: qsTr("Gamepad Settings")
                }

                // Expose the (previously hidden) gamepad remapping screen.
                Button {
                    id: gamepadMapButton
                    // No trailing ellipsis — it read as clipped text on device.
                    text: qsTr("Configure gamepad mapping")
                    onClicked: navigateTo("qrc:/gui/GamepadMapper.qml", "GamepadMapper")
                    ToolTip.text: qsTr("Remap or calibrate connected controllers (paddles, face buttons, sticks).")
                    ToolTip.delay: 1000
                    ToolTip.visible: hovered
                }

                // Redesign live tweaks (State model: showHints + accent). Persisted via prefs.
                VbToggleRow {
                    id: showHintsCheck
                    text: qsTr("Show the gamepad hint bar")
                    checked: StreamingPreferences.uiShowHints
                    onCheckedChanged: StreamingPreferences.uiShowHints = checked
                    ToolTip.text: qsTr("Show the button-hint bar at the bottom of every screen.")
                    ToolTip.delay: 1000
                    ToolTip.visible: hovered
                }

                Label {
                    width: parent.width
                    text: qsTr("Accent color")
                    font.pointSize: 12
                    wrapMode: Text.Wrap
                }

                AutoResizingComboBox {
                    id: accentComboBox
                    textRole: "text"
                    hoverEnabled: true
                    model: ListModel {
                        ListElement { text: qsTr("Teal (default)") }
                        ListElement { text: qsTr("Indigo") }
                        ListElement { text: qsTr("Green") }
                        ListElement { text: qsTr("Amber") }
                    }
                    Component.onCompleted: currentIndex = StreamingPreferences.uiAccentIndex
                    onActivated: StreamingPreferences.uiAccentIndex = currentIndex
                    ToolTip.text: qsTr("The accent color used across the redesigned UI.")
                    ToolTip.delay: 1000
                    ToolTip.visible: hovered
                }

                Label {
                    width: parent.width
                    id: quickMenuComboTitle
                    text: qsTr("Quick Menu shortcut")
                    font.pointSize: 12
                    wrapMode: Text.Wrap
                }

                AutoResizingComboBox {
                    id: quickMenuComboBox
                    textRole: "text"
                    hoverEnabled: true
                    model: ListModel {
                        id: quickMenuComboModel
                        ListElement { text: qsTr("Select + L1 + R1 + Y (default)"); val: 0 }
                        ListElement { text: qsTr("Select + L1 + R1 + B"); val: 1 }
                        ListElement { text: qsTr("L3 + R3 (click both sticks)"); val: 2 }
                        ListElement { text: qsTr("Select + Start"); val: 3 }
                        ListElement { text: qsTr("Back paddle P1"); val: 4 }
                        ListElement { text: qsTr("Back paddle P2"); val: 5 }
                        ListElement { text: qsTr("Back paddle P3"); val: 6 }
                        ListElement { text: qsTr("Back paddle P4"); val: 7 }
                    }

                    function reinitialize() {
                        var saved = StreamingPreferences.quickMenuGamepadCombo
                        currentIndex = 0
                        for (var i = 0; i < quickMenuComboModel.count; i++) {
                            if (quickMenuComboModel.get(i).val === saved) {
                                currentIndex = i
                                break
                            }
                        }
                    }

                    Component.onCompleted: {
                        reinitialize()
                        languageChanged.connect(reinitialize)
                    }

                    onActivated: {
                        StreamingPreferences.quickMenuGamepadCombo = quickMenuComboModel.get(currentIndex).val
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Which gamepad button combination opens the in-stream Quick Menu.") + "\n\n" +
                                  qsTr("On controllers with back paddles (Legion Go, Xbox Elite, …) the P1 paddle ALSO opens the menu while the default combo is selected — no setup needed. Picking any other combo takes full control.")
                }

                VbToggleRow {
                    id: swapFaceButtonsCheck
                    text: qsTr("Swap A/B and X/Y gamepad buttons")
                    checked: StreamingPreferences.swapFaceButtons
                    onCheckedChanged: {
                        StreamingPreferences.swapFaceButtons = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("This switches gamepads into a Nintendo-style button layout")
                }

                VbToggleRow {
                    id: singleControllerCheck
                    text: qsTr("Force gamepad #1 always connected")
                    checked: !StreamingPreferences.multiController
                    onCheckedChanged: {
                        StreamingPreferences.multiController = !checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Forces a single gamepad to always stay connected to the host, even if no gamepads are actually connected to this PC.") + " " +
                                  qsTr("Only enable this option when streaming a game that doesn't support gamepads being connected after startup.")
                }

                VbToggleRow {
                    id: gamepadMouseCheck
                    text: qsTr("Enable mouse control with gamepads by holding the 'Start' button")
                    checked: StreamingPreferences.gamepadMouse
                    onCheckedChanged: {
                        StreamingPreferences.gamepadMouse = checked
                    }
                }

                VbToggleRow {
                    id: backgroundGamepadCheck
                    text: qsTr("Process gamepad input when Vibemis is in the background")
                    visible: SystemProperties.hasDesktopEnvironment
                    checked: StreamingPreferences.backgroundGamepad
                    onCheckedChanged: {
                        StreamingPreferences.backgroundGamepad = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Allows Vibemis to capture gamepad inputs even if it's not the current window in focus")
                }

                VbToggleRow {
                    id: forwardMotionCheck
                    text: qsTr("Forward motion controls (gyro) — experimental")
                    checked: StreamingPreferences.forwardMotionControls
                    onCheckedChanged: {
                        StreamingPreferences.forwardMotionControls = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Experimental: detect this device's gyro/accelerometer for forwarding to the host (motion/gyro aim). Sensor forwarding is still in development; enabling this currently logs the detected sensors.")
                }

                VbToggleRow {
                    id: suppressRumbleCheck
                    text: qsTr("Disable controller rumble")
                    checked: StreamingPreferences.suppressControllerRumble
                    onCheckedChanged: {
                        StreamingPreferences.suppressControllerRumble = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Ignore rumble/force-feedback sent by the host. Useful to save battery on a handheld or if you find rumble distracting.")
                }
            }
        }

        // Restyled to the Video-page card pattern. Bindings unchanged.
        VbSettingsCard {
            id: advancedSettingsGroupBox
            visible: settingsPage.category === 4
            width: (parent.width - (parent.leftPadding + parent.rightPadding))
            font.pointSize: 12

            Column {
                anchors.fill: parent
                spacing: 12

                VbSectionHeader {
                    text: qsTr("Advanced Settings")
                }

                Label {
                    width: parent.width
                    id: resVDSTitle
                    text: qsTr("Video decoder")
                    font.pointSize: 12
                    wrapMode: Text.Wrap
                }


                AutoResizingComboBox {
                    // ignore setting the index at first, and actually set it when the component is loaded
                    Component.onCompleted: {
                        var saved_vds = StreamingPreferences.videoDecoderSelection
                        currentIndex = 0
                        for (var i = 0; i < decoderListModel.count; i++) {
                            var el_vds = decoderListModel.get(i).val;
                            if (saved_vds === el_vds) {
                                currentIndex = i
                                break
                            }
                        }
                        activated(currentIndex)
                    }

                    id: decoderComboBox
                    textRole: "text"
                    model: ListModel {
                        id: decoderListModel
                        ListElement {
                            text: qsTr("Automatic (Recommended)")
                            val: StreamingPreferences.VDS_AUTO
                        }
                        ListElement {
                            text: qsTr("Force software decoding")
                            val: StreamingPreferences.VDS_FORCE_SOFTWARE
                        }
                        ListElement {
                            text: qsTr("Force hardware decoding")
                            val: StreamingPreferences.VDS_FORCE_HARDWARE
                        }
                    }
                    // ::onActivated must be used, as it only listens for when the index is changed by a human
                    onActivated: {
                        if (enabled) {
                            StreamingPreferences.videoDecoderSelection = decoderListModel.get(currentIndex).val
                        }
                    }
                }

                // Vibemis (perf guidance): warn when software decoding is forced. On the Legion Go S
                // Z2 (and most handhelds) hardware decoding cuts decode latency from ~8ms to ~2ms, so
                // forcing software decode noticeably hurts responsiveness. Shown only when relevant.
                Label {
                    width: parent.width
                    visible: StreamingPreferences.videoDecoderSelection === StreamingPreferences.VDS_FORCE_SOFTWARE
                    text: "⚠ " + qsTr("Software decoding adds latency (≈8 ms vs ≈2 ms for hardware) and raises CPU/battery use. Prefer \"Automatic\" unless hardware decoding is broken on this device.")
                    font.pointSize: 9
                    wrapMode: Text.Wrap
                    color: "#E0A030"
                    topPadding: 4
                }

                Label {
                    width: parent.width
                    id: resVCCTitle
                    text: qsTr("Video codec")
                    font.pointSize: 12
                    wrapMode: Text.Wrap
                }

                AutoResizingComboBox {
                    // ignore setting the index at first, and actually set it when the component is loaded
                    Component.onCompleted: {
                        var saved_vcc = StreamingPreferences.videoCodecConfig

                        // Default to Automatic (relevant if HDR is enabled,
                        // where we will match none of the codecs in the list)
                        currentIndex = 0

                        for(var i = 0; i < codecListModel.count; i++) {
                            var el_vcc = codecListModel.get(i).val;
                            if (saved_vcc === el_vcc) {
                                currentIndex = i
                                break
                            }
                        }

                        activated(currentIndex)
                    }

                    id: codecComboBox
                    textRole: "text"
                    model: ListModel {
                        id: codecListModel
                        ListElement {
                            text: qsTr("Automatic (Recommended)")
                            val: StreamingPreferences.VCC_AUTO
                        }
                        ListElement {
                            text: qsTr("H.264")
                            val: StreamingPreferences.VCC_FORCE_H264
                        }
                        ListElement {
                            text: qsTr("HEVC (H.265)")
                            val: StreamingPreferences.VCC_FORCE_HEVC
                        }
                        ListElement {
                            text: qsTr("AV1 (Experimental)")
                            val: StreamingPreferences.VCC_FORCE_AV1
                        }
                    }
                    // ::onActivated must be used, as it only listens for when the index is changed by a human
                    onActivated : {
                        if (enabled) {
                            StreamingPreferences.videoCodecConfig = codecListModel.get(currentIndex).val
                        }
                    }
                }

                // Vibemis (codec guidance): contextual guidance when AV1 is forced. AV1 gives better
                // quality-per-bit (great on a bandwidth-limited handheld) but needs a host + GPU that
                // can encode it; otherwise the stream falls back or fails. Shown only for AV1.
                Label {
                    width: parent.width
                    visible: StreamingPreferences.videoCodecConfig === StreamingPreferences.VCC_FORCE_AV1
                    text: qsTr("AV1 offers better quality at the same bitrate, but requires an Apollo/Sunshine host with an AV1-capable GPU (e.g. NVIDIA RTX 40, AMD RX 7000, Intel Arc). If streaming fails or falls back, choose \"Automatic\".")
                    font.pointSize: 9
                    wrapMode: Text.Wrap
                    color: "#80A0C0"
                    topPadding: 4
                }

                // Preferred renderer backend
                Label {
                    width: parent.width
                    text: qsTr("Preferred renderer")
                    font.pointSize: 12
                    wrapMode: Text.Wrap
                    topPadding: 12
                }

                AutoResizingComboBox {
                    function createModel() {
                        var model = Qt.createQmlObject('import QtQuick 2.0; ListModel {}', parent, '')

                        model.append({ text: qsTr("Auto (Vulkan, fallback to OpenGL)"), val: StreamingPreferences.RB_AUTO })
                        model.append({ text: qsTr("Vulkan"), val: StreamingPreferences.RB_VULKAN })
                        model.append({ text: qsTr("OpenGL"), val: StreamingPreferences.RB_OPENGL })
                        return model
                    }

                    function reinitialize() {
                        model = createModel()
                        currentIndex = 0
                        var saved = StreamingPreferences.rendererBackend
                        for (var i = 0; i < model.count; i++) {
                            if (model.get(i).val === saved) {
                                currentIndex = i
                                break
                            }
                        }
                        activated(currentIndex)
                    }

                    Component.onCompleted: {
                        reinitialize()
                        languageChanged.connect(reinitialize)
                    }

                    id: rendererBackendComboBox
                    textRole: "text"
                    onActivated: {
                        StreamingPreferences.rendererBackend = model.get(currentIndex).val
                    }
                }

                VbToggleRow {
                    id: enableHdr
                    text: qsTr("Enable HDR (Experimental)")

                    enabled: SystemProperties.supportsHdr
                    checked: enabled && StreamingPreferences.enableHdr
                    onCheckedChanged: {
                        StreamingPreferences.enableHdr = checked
                    }

                    // Updating StreamingPreferences.videoCodecConfig is handled above

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: enabled ?
                                      qsTr("The stream will be HDR-capable, but some games may require an HDR monitor on your host PC to enable HDR mode.")
                                    :
                                      qsTr("HDR streaming is not supported on this PC.")
                }

                // Vibemis: companion checkbox under "Enable HDR". When unchecked,
                // the client keeps the HDR setting but does NOT actually ask the
                // host for HDR pixels — fixing the wash-out on SDR displays like
                // the Legion Go S Z2 LCD, most Steam Decks, etc.
                VbToggleRow {
                    id: displayHdrCapability
                    text: qsTr("    My display supports HDR")

                    visible: enableHdr.checked
                    enabled: enableHdr.checked
                    checked: StreamingPreferences.displayHdrCapability
                    onCheckedChanged: {
                        StreamingPreferences.displayHdrCapability = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 6000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Uncheck this if HDR-streamed content looks washed out, dim, or color-shifted. " +
                                       "Many Linux handhelds (Steam Deck LCD, Legion Go S Z2, etc.) can decode HDR but " +
                                       "their display panels can't actually show HDR — leaving this checked makes the picture look wrong. " +
                                       "Unchecking keeps the HDR codec path off; re-check it later if you connect an HDR display.")
                }

                // Vibemis: client-side HDR tone-mapping toggle.
                // When on, the Vulkan renderer tone-maps HDR content down to SDR on this
                // device (rather than passing HDR through to the display). Effective only
                // on the Vulkan/libplacebo renderer, which is the HDR-capable one on Linux.
                VbToggleRow {
                    id: hdrTonemapping
                    text: qsTr("    Tone-map HDR to SDR on this device (Experimental)")

                    visible: enableHdr.checked
                    enabled: enableHdr.checked
                    checked: StreamingPreferences.hdrTonemapping
                    onCheckedChanged: {
                        StreamingPreferences.hdrTonemapping = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 6000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Force the client to tone-map HDR content down to SDR instead of sending HDR to your display. " +
                                       "Turn this ON if your display reports HDR support but HDR looks too dim, over-saturated, or wrong, " +
                                       "and you'd rather view a tone-mapped SDR image. Leave OFF (default) to pass HDR through to HDR-capable displays. " +
                                       "Applies on the Vulkan renderer (Steam Deck / most Linux handhelds).")
                }

                VbToggleRow {
                    id: enableYUV444
                    text: qsTr("Enable YUV 4:4:4 (Experimental)")

                    checked: StreamingPreferences.enableYUV444
                    onCheckedChanged: {
                        // This is called on init, so only reset to default bitrate when checked state changes.
                        if (StreamingPreferences.enableYUV444 != checked) {
                            StreamingPreferences.enableYUV444 = checked
                            if (StreamingPreferences.autoAdjustBitrate) {
                                StreamingPreferences.bitrateKbps = StreamingPreferences.getDefaultBitrate(StreamingPreferences.width,
                                                                                                          StreamingPreferences.height,
                                                                                                          StreamingPreferences.fps,
                                                                                                          StreamingPreferences.enableYUV444);
                                slider.value = StreamingPreferences.bitrateKbps
                            }
                        }
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: enabled ?
                                      qsTr("Good for streaming desktop and text-heavy games, but not recommended for fast-paced games.")
                                    :
                                      qsTr("YUV 4:4:4 is not supported on this PC.")
                }

                VbToggleRow {
                    id: unlockBitrate
                    text: qsTr("Unlock bitrate limit (Experimental)")

                    checked: StreamingPreferences.unlockBitrate
                    onCheckedChanged: {
                        StreamingPreferences.unlockBitrate = checked
                        StreamingPreferences.bitrateKbps = Math.min(StreamingPreferences.bitrateKbps, slider.to)
                        slider.value = StreamingPreferences.bitrateKbps
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("This unlocks extremely high video bitrates for use with Sunshine hosts. It should only be used when streaming over an Ethernet LAN connection.")
                }

                VbToggleRow {
                    id: enableMdns
                    text: qsTr("Automatically find PCs on the local network (Recommended)")
                    checked: StreamingPreferences.enableMdns
                    onCheckedChanged: {
                        // This is called on init, so only do the work if we've
                        // actually changed the value.
                        if (StreamingPreferences.enableMdns != checked) {
                            StreamingPreferences.enableMdns = checked

                            // Restart polling so the mDNS change takes effect
                            if (window.pollingActive) {
                                ComputerManager.stopPollingAsync()
                                ComputerManager.startPolling()
                            }
                        }
                    }
                }

                VbToggleRow {
                    id: detectNetworkBlocking
                    text: qsTr("Automatically detect blocked connections (Recommended)")
                    checked: StreamingPreferences.detectNetworkBlocking
                    onCheckedChanged: {
                        StreamingPreferences.detectNetworkBlocking = checked
                    }
                }

                VbToggleRow {
                    id: showPerformanceOverlay
                    text: qsTr("Show performance stats while streaming")
                    checked: StreamingPreferences.showPerformanceOverlay
                    onCheckedChanged: {
                        StreamingPreferences.showPerformanceOverlay = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Display real-time stream performance information while streaming.") + "\n\n" +
                                  qsTr("You can toggle it at any time while streaming using Ctrl+Alt+Shift+S or Select+L1+R1+X.") + "\n\n" +
                                  qsTr("The performance overlay is not supported on Steam Link or Raspberry Pi.")
                }

                VbToggleRow {
                    id: compactPerformanceOverlay
                    text: qsTr("Compact performance overlay")
                    enabled: showPerformanceOverlay.checked
                    checked: StreamingPreferences.compactPerformanceOverlay
                    onCheckedChanged: {
                        StreamingPreferences.compactPerformanceOverlay = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Show the stats as a single compact line (fps, resolution, latency, dropped frames) instead of the full multi-line block — easier to read on a handheld screen.")
                }

                VbToggleRow {
                    id: perfOverlayShowClock
                    text: qsTr("Show clock in the performance overlay")
                    enabled: showPerformanceOverlay.checked
                    checked: StreamingPreferences.perfOverlayShowClock
                    onCheckedChanged: {
                        StreamingPreferences.perfOverlayShowClock = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Add a wall-clock time (HH:MM:SS) line to the top of the performance overlay.") + "\n\n" +
                                  qsTr("Useful on a handheld in Game Mode, where the system clock is hidden while streaming.")
                }

                Label {
                    width: parent.width
                    id: perfOverlayTextSizeTitle
                    text: qsTr("Performance overlay text size")
                    font.pointSize: 12
                    wrapMode: Text.Wrap
                    visible: showPerformanceOverlay.checked
                }

                AutoResizingComboBox {
                    id: perfOverlayTextSizeComboBox
                    visible: showPerformanceOverlay.checked
                    textRole: "text"
                    model: ListModel {
                        id: perfOverlayTextSizeListModel
                        ListElement {
                            text: qsTr("Small")
                            val: StreamingPreferences.PERF_TEXT_SMALL
                        }
                        ListElement {
                            text: qsTr("Normal")
                            val: StreamingPreferences.PERF_TEXT_NORMAL
                        }
                        ListElement {
                            text: qsTr("Large")
                            val: StreamingPreferences.PERF_TEXT_LARGE
                        }
                    }
                    Component.onCompleted: {
                        var saved = StreamingPreferences.perfOverlayTextSize
                        currentIndex = 0
                        for (var i = 0; i < perfOverlayTextSizeListModel.count; i++) {
                            if (perfOverlayTextSizeListModel.get(i).val === saved) {
                                currentIndex = i
                                break
                            }
                        }
                    }
                    // ::onActivated only fires on human-driven index changes
                    onActivated: {
                        StreamingPreferences.perfOverlayTextSize = perfOverlayTextSizeListModel.get(currentIndex).val
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Adjust the size of the performance overlay text. Takes effect the next time you start a stream.")
                }

                Label {
                    width: parent.width
                    id: perfOverlayPositionTitle
                    text: qsTr("Performance overlay position")
                    font.pointSize: 12
                    wrapMode: Text.Wrap
                    visible: showPerformanceOverlay.checked
                }

                AutoResizingComboBox {
                    id: perfOverlayPositionComboBox
                    visible: showPerformanceOverlay.checked
                    textRole: "text"
                    model: ListModel {
                        id: perfOverlayPositionListModel
                        ListElement {
                            text: qsTr("Top left")
                            val: StreamingPreferences.POS_TOP_LEFT
                        }
                        ListElement {
                            text: qsTr("Top right")
                            val: StreamingPreferences.POS_TOP_RIGHT
                        }
                        ListElement {
                            text: qsTr("Bottom left")
                            val: StreamingPreferences.POS_BOTTOM_LEFT
                        }
                        ListElement {
                            text: qsTr("Bottom right")
                            val: StreamingPreferences.POS_BOTTOM_RIGHT
                        }
                    }
                    Component.onCompleted: {
                        var saved = StreamingPreferences.perfOverlayPosition
                        currentIndex = 0
                        for (var i = 0; i < perfOverlayPositionListModel.count; i++) {
                            if (perfOverlayPositionListModel.get(i).val === saved) {
                                currentIndex = i
                                break
                            }
                        }
                    }
                    // ::onActivated only fires on human-driven index changes
                    onActivated: {
                        StreamingPreferences.perfOverlayPosition = perfOverlayPositionListModel.get(currentIndex).val
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Choose which corner of the screen the performance overlay appears in.")
                }

                // Vibemis: in-app update channel + manual check + one-tap install.
                // The checker follows StreamingPreferences.updateChannel; installUpdate()
                // swaps the running AppImage in place (falls back to the release page).
                Label {
                    width: parent.width
                    id: updateChannelTitle
                    text: qsTr("Software updates")
                    font.pointSize: 12
                    wrapMode: Text.Wrap
                    topPadding: 8
                }

                AutoResizingComboBox {
                    id: updateChannelComboBox
                    textRole: "text"
                    model: ListModel {
                        id: updateChannelListModel
                        ListElement {
                            text: qsTr("Stable (recommended)")
                            val: StreamingPreferences.UC_STABLE
                        }
                        ListElement {
                            text: qsTr("Release candidate (pre-stable)")
                            val: StreamingPreferences.UC_RC
                        }
                        ListElement {
                            text: qsTr("Beta (new features)")
                            val: StreamingPreferences.UC_BETA
                        }
                        ListElement {
                            text: qsTr("Alpha (test builds)")
                            val: StreamingPreferences.UC_ALPHA
                        }
                    }
                    Component.onCompleted: {
                        var saved = StreamingPreferences.updateChannel
                        currentIndex = 0
                        for (var i = 0; i < updateChannelListModel.count; i++) {
                            if (updateChannelListModel.get(i).val === saved) {
                                currentIndex = i
                                break
                            }
                        }
                    }
                    // ::onActivated only fires on human-driven index changes
                    onActivated: {
                        StreamingPreferences.updateChannel = updateChannelListModel.get(currentIndex).val
                        // A previous check's result doesn't apply to the new channel
                        updateStatusLabel.text = qsTr("Channel changed — check for updates to see this channel's newest build.")
                        updateNowButton.assetUrl = ""
                        updateNowButton.visible = false
                        viewReleaseButton.releaseUrl = ""
                        viewReleaseButton.visible = false
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Which release channel updates come from. Stable is safest; Beta gets features as they ship; Alpha is per-feature test builds.")
                }

                Row {
                    spacing: 8

                    Button {
                        id: checkUpdatesButton
                        text: qsTr("Check for updates")
                        // Do NOT toggle `enabled` here — disabling the focused button
                        // drops activeFocus and the pane auto-scrolls to the next focus item at
                        // the top of the page. Re-entry is already guarded in C++ (one check in
                        // flight at a time), so the button can stay enabled and keep focus.
                        onClicked: {
                            updateStatusLabel.text = qsTr("Checking for updates…")
                            updateNowButton.visible = false
                            viewReleaseButton.visible = false
                            AutoUpdateChecker.checkNow()
                        }
                    }

                    Button {
                        id: updateNowButton
                        property string assetUrl: ""
                        // QML-side re-entry guard instead of `enabled = false` (which
                        // would drop focus and scroll the pane to the top — same class as the
                        // Check button). Reset on installFailed; a successful install relaunches.
                        property bool installing: false
                        text: qsTr("Update now")
                        visible: false
                        onClicked: {
                            if (installing) {
                                return
                            }
                            installing = true
                            updateStatusLabel.text = qsTr("Downloading update…")
                            AutoUpdateChecker.installUpdate(assetUrl)
                        }
                    }

                    Button {
                        id: viewReleaseButton
                        property string releaseUrl: ""
                        text: qsTr("View release")
                        visible: false
                        onClicked: {
                            if (releaseUrl) {
                                SystemProperties.openUrl(releaseUrl)
                            }
                        }
                    }
                }

                Label {
                    id: updateStatusLabel
                    width: parent.width
                    text: qsTr("Current version: %1").arg(AutoUpdateChecker.currentVersion())
                    font.pointSize: 10
                    wrapMode: Text.Wrap
                }

                Connections {
                    target: AutoUpdateChecker
                    function onUpdateCheckFinished(available, version, htmlUrl, assetUrl, message) {
                        updateStatusLabel.text = message
                        viewReleaseButton.releaseUrl = htmlUrl
                        viewReleaseButton.visible = available && htmlUrl !== "" && SystemProperties.hasBrowser
                        updateNowButton.assetUrl = assetUrl
                        updateNowButton.visible = available && assetUrl !== "" && AutoUpdateChecker.canInstallUpdates()
                    }
                    function onInstallProgress(bytesReceived, bytesTotal) {
                        if (bytesTotal > 0) {
                            updateStatusLabel.text = qsTr("Downloading update… %1%").arg(Math.floor(bytesReceived * 100 / bytesTotal))
                        }
                        else {
                            updateStatusLabel.text = qsTr("Downloading update… %1 MB").arg((bytesReceived / 1048576).toFixed(1))
                        }
                    }
                    function onInstallFailed(error, htmlUrl) {
                        updateNowButton.installing = false
                        updateStatusLabel.text = qsTr("Install failed: %1").arg(error)
                        if (htmlUrl !== "") {
                            viewReleaseButton.releaseUrl = htmlUrl
                            viewReleaseButton.visible = SystemProperties.hasBrowser
                        }
                    }
                }
            }
        }

        // Restyled to the Video-page card pattern. Bindings unchanged.
        VbSettingsCard {
            id: artemisSettingsGroupBox
            visible: settingsPage.category === 3
            width: (parent.width - (parent.leftPadding + parent.rightPadding))
            font.pointSize: 12

            Column {
                anchors.fill: parent
                spacing: 12

                VbSectionHeader {
                    text: qsTr("Vibemis Features")
                }

                ClipboardSettings {
                    id: clipboardSettings
                    width: parent.width
                }

                // The touch-overlay PREF shipped with a
                // Quick-Menu toggle but never got its Settings row — unfindable outside a
                // stream. Same opt-in default (off).
                VbToggleRow {
                    id: touchOverlayCheck
                    text: qsTr("On-screen touch controls while streaming")
                    checked: StreamingPreferences.enableTouchOverlay
                    onCheckedChanged: {
                        StreamingPreferences.enableTouchOverlay = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Composites three translucent buttons into the stream: MENU (top-left, opens the Quick Menu), KBD (top-right, opens the SteamOS on-screen keyboard) and a touch-mode toggle (next to KBD, switches trackpad/direct touch). Finger taps only — mouse clicks in those corners pass through to the game.") + "\n\n" +
                                  qsTr("Can also be toggled mid-stream from the Quick Menu (\"Touch overlay\").")
                }

                VbToggleRow {
                    id: preferTailscaleCheck
                    text: qsTr("Prefer Tailscale addresses for remote play")
                    checked: StreamingPreferences.preferTailscale
                    onCheckedChanged: {
                        StreamingPreferences.preferTailscale = checked
                    }

                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("When connecting to a host, try its Tailscale address (100.64.x.x or a *.ts.net MagicDNS name) before other addresses.") + "\n\n" +
                                  qsTr("Useful for remote play over your tailnet. Has no effect if the host has no Tailscale address.")
                }

                // Vibemis: in-app entry point to set up Tailscale for remote play. One click
                // opens the setup guide; the one-command script scripts/setup-tailscale.sh does the
                // install + login. Pair with Settings -> "Prefer Tailscale addresses".
                Label {
                    width: parent.width
                    text: qsTr("Remote play (stream from anywhere): set up Tailscale, then enable \"Prefer Tailscale addresses\" above.")
                    font.pointSize: 10
                    wrapMode: Text.Wrap
                    topPadding: 6
                }
                Row {
                    spacing: 8
                    Button {
                        text: qsTr("Set up Tailscale")
                        onClicked: SystemProperties.openUrl("https://tailscale.com/kb/installation")
                        visible: SystemProperties.hasBrowser
                    }
                    Button {
                        text: qsTr("One-command setup (guide)")
                        onClicked: SystemProperties.openUrl("https://github.com/navyas321/vibemis/blob/vibemis-main/scripts/setup-tailscale.sh")
                        visible: SystemProperties.hasBrowser
                    }
                    // Vibemis: check the tailnet status in-app (no terminal needed).
                    Button {
                        text: qsTr("Check status")
                        onClicked: tailscaleStatusLabel.text = SystemProperties.checkTailscaleStatus()
                    }
                }
                Label {
                    id: tailscaleStatusLabel
                    width: parent.width
                    text: ""
                    visible: text !== ""
                    font.pointSize: 10
                    wrapMode: Text.Wrap
                    topPadding: 4
                }
                Label {
                    width: parent.width
                    text: qsTr("Tip: on SteamOS, run scripts/setup-tailscale.sh for a one-command, no-sudo setup.")
                    font.pointSize: 9
                    wrapMode: Text.Wrap
                    color: "#aaaaaa"
                }

                // Note about Server Commands
                Label {
                    width: parent.width
                    text: qsTr("Server Commands are available during streaming sessions via the game menu when connected to Apollo / Vibepollo hosts.")
                    font.pointSize: 9
                    wrapMode: Text.Wrap
                    color: "#aaaaaa"
                    topPadding: 10
                }
            }
        }

        // Vibemis: read-only System Information panel. Surfaces the same environment facts the
        // headless `vibemis selftest` reports, so a human (or a bug report) can see version,
        // platform, and capability at a glance. Pure QML over the already-exposed SystemProperties.
        // Restyled to the Video-page card pattern. Bindings unchanged.
        VbSettingsCard {
            id: systemInfoGroupBox
            visible: settingsPage.category === 4
            width: (parent.width - (parent.leftPadding + parent.rightPadding))
            font.pointSize: 12

            Column {
                anchors.fill: parent
                spacing: 6

                VbSectionHeader {
                    text: qsTr("System Information")
                }

                Repeater {
                    width: parent.width
                    model: [
                        { k: qsTr("Vibemis version"), v: SystemProperties.versionString },
                        { k: qsTr("Architecture"),    v: SystemProperties.friendlyNativeArchName },
                        { k: qsTr("SteamOS / gamescope"), v: SystemProperties.isSteamDeck ? qsTr("Yes") : qsTr("No") },
                        { k: qsTr("Display server"),  v: SystemProperties.isRunningWayland ? (SystemProperties.isRunningXWayland ? "XWayland" : "Wayland") : "X11" },
                        { k: qsTr("Hardware decode"), v: SystemProperties.hasHardwareAcceleration ? qsTr("Available") : qsTr("Not available") },
                        // These two report the DECODER, not the panel —
                        // 'HDR support: Yes' on an SDR device and 'Max resolution: 0×0' were
                        // both technically-true sentinels rendered misleadingly. supportsHdr =
                        // the decoder can decode HDR streams; maximumResolution 0×0 = the probe
                        // found no ceiling above 1080p (see the Video page NOTE).
                        { k: qsTr("Display resolution"), v: Screen.width + "×" + Screen.height },
                        { k: qsTr("HDR decode"),      v: SystemProperties.supportsHdr ? qsTr("Supported (stream decode)") : qsTr("No") },
                        { k: qsTr("Max decode resolution"),  v: (SystemProperties.maximumResolution.width > 0 && SystemProperties.maximumResolution.height > 0)
                                                                ? (SystemProperties.maximumResolution.width + "×" + SystemProperties.maximumResolution.height)
                                                                : qsTr("No limit found (above 1080p)") }
                    ]
                    delegate: RowLayout {
                        width: systemInfoGroupBox.availableWidth
                        spacing: 8
                        Label {
                            text: modelData.k
                            font.pointSize: 11
                            color: "#aaaaaa"
                            Layout.preferredWidth: 200
                        }
                        Label {
                            text: modelData.v
                            font.pointSize: 11
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                        }
                    }
                }

                Label {
                    width: parent.width
                    text: qsTr("Useful when filing a bug report. The headless 'vibemis selftest' command reports the same kind of information for automated checks.")
                    font.pointSize: 9
                    wrapMode: Text.Wrap
                    color: "#aaaaaa"
                    topPadding: 6
                }
            }
        }

        // Restyled to the Video-page card pattern. Bindings unchanged.
        VbSettingsCard {
            id: aboutGroupBox
            visible: settingsPage.category === 4
            width: (parent.width - (parent.leftPadding + parent.rightPadding))
            font.pointSize: 12

            Column {
                anchors.fill: parent
                spacing: 6

                VbSectionHeader {
                    text: qsTr("About")
                }

                Label {
                    width: parent.width
                    text: qsTr("Vibemis %1").arg(SystemProperties.versionString)
                    font.pointSize: 12
                    font.bold: true
                    wrapMode: Text.Wrap
                }
                Label {
                    width: parent.width
                    text: qsTr("The actively maintained Apollo / Vibepollo game-streaming client for Linux and SteamOS.")
                    font.pointSize: 9
                    wrapMode: Text.Wrap
                    color: "#aaaaaa"
                }
                Label {
                    width: parent.width
                    text: "<a href=\"https://github.com/navyas321/vibemis\">github.com/navyas321/vibemis</a>"
                    onLinkActivated: SystemProperties.openUrl(link)
                    font.pointSize: 9
                    wrapMode: Text.Wrap
                    color: "#aaaaaa"
                }
            }
        }

        // Vibemis: Help & Links — quick access to docs/support. Only shown when a browser is
        // available (SystemProperties.hasBrowser). Uses Qt.openUrlExternally so it works in
        // Desktop Mode; in Game Mode the buttons simply do nothing if no browser is present.
        // Restyled to the Video-page card pattern. Bindings unchanged.
        VbSettingsCard {
            id: helpLinksGroupBox
            visible: SystemProperties.hasBrowser && settingsPage.category === 4
            width: (parent.width - (parent.leftPadding + parent.rightPadding))
            font.pointSize: 12

            Column {
                anchors.fill: parent
                spacing: 8

                VbSectionHeader {
                    text: qsTr("Help & Links")
                }

                Label {
                    width: parent.width
                    text: qsTr("Vibemis is the Linux/SteamOS client for Apollo & Sunshine hosts. These open in your browser.")
                    font.pointSize: 9
                    wrapMode: Text.Wrap
                    color: "#aaaaaa"
                }

                Button {
                    text: qsTr("Vibemis on GitHub")
                    onClicked: SystemProperties.openUrl("https://github.com/navyas321/vibemis")
                }
                Button {
                    text: qsTr("Install guide (README)")
                    onClicked: SystemProperties.openUrl("https://github.com/navyas321/vibemis#readme")
                }
                Button {
                    text: qsTr("Remote play over Tailscale — setup")
                    onClicked: SystemProperties.openUrl("https://tailscale.com/kb/installation")
                }
            }
        }
    }
    }

    // ---- Gamepad hint bar (redesign) ----
    // The LB/RB hint matches real behavior: SdlGamepadKeyNavigation now forwards the shoulder
    // buttons as Key_MediaPrevious/Key_MediaNext, handled by the page-root Keys.onPressed above to
    // switch category (LB = previous, RB = next). The sidebar rows also stay focusable (D-pad/Tab
    // reachable, Ⓐ/Return/click to select). Ⓑ / Esc pop the view via the StackView's key handlers.
    VbHintBar {
        id: hintBar
        anchors.bottom: parent.bottom
        width: parent.width
        hints: [
            { glyph: "LB", label: "" },
            { glyph: "RB", label: qsTr("Switch category") },
            { glyph: "Ⓐ", label: qsTr("Toggle / adjust") }
        ]
        hintsRight: [
            { glyph: "Ⓑ", label: qsTr("Back") }
        ]
    }
}
