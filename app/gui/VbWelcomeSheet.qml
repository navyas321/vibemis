import QtQuick 2.9
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.2

import StreamingPreferences 1.0
import Vibemis.Redesign 1.0

// First-run welcome sheet (test132, BL-2107 / docs/design/specs/onboarding-first-run.md).
// A token-styled modal card over the Computers screen, reusing the Add-PC dialog pattern
// (NavigableDialog + bgElev card + custom accent pill). Elevates the former stock
// NavigableMessageDialog welcome hint onto the redesign visual language WITHOUT changing when
// it shows or the one-shot persistence: gated by StreamingPreferences.seenWelcomeHint, markSeen()
// persists the flag, shown exactly once. Gamepad-first — a single focused "Get started" pill
// (Ⓐ); Ⓑ / Esc dismisses. No new preference keys; all copy is qsTr for i18n. Self-contained:
// opens from its own Component.onCompleted, so it does not touch the main startup logic.
NavigableDialog {
    id: welcomeSheet

    // Custom Ⓐ Get started pill lives in the content (per the design) — no stock button box.
    // Ⓑ / Esc (gamepad B maps to Escape) rejects via closePolicy.
    standardButtons: Dialog.NoButton
    closePolicy: Popup.CloseOnEscape
    implicitWidth: 720
    padding: VbTokens.space6      // 32

    // Token scrim behind the modal card (matches the redesign dialog language).
    Overlay.modal: Rectangle { color: VbTokens.dialogScrim }

    background: Rectangle {
        color: VbTokens.bgElev
        radius: VbTokens.radiusDialog
        border.width: 1
        border.color: VbTokens.stroke
    }

    // One-shot persistence — identical semantics to the former welcomeDialog.
    function markSeen() {
        StreamingPreferences.seenWelcomeHint = true
        StreamingPreferences.save()
    }
    onAccepted: markSeen()
    onRejected: markSeen()

    // Focus the primary action so the controller lands on it immediately.
    onOpened: getStartedBtn.forceActiveFocus()

    // Show exactly once, from the component's own lifecycle (no startup-flow coupling).
    Component.onCompleted: {
        if (!StreamingPreferences.seenWelcomeHint) {
            welcomeSheet.open()
        }
    }

    // Reusable two-line info row: line-glyph + title + sub, optional extra content slot.
    component InfoRow: RowLayout {
        property string glyph: ""
        property string title: ""
        property string sub: ""
        default property alias extra: extraSlot.data
        Layout.fillWidth: true
        spacing: VbTokens.space3      // 12
        VbSheetIcon {
            kind: glyph
            width: 28; height: 28
            color: VbTokens.accent
            Layout.preferredWidth: 28
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: VbTokens.space1
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: VbTokens.space1  // 4
            Text {
                text: title
                font.family: VbTokens.fontBody
                font.weight: Font.DemiBold
                font.pixelSize: VbTokens.typeLabel     // 14
                color: VbTokens.textPrimary
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
            Text {
                text: sub
                visible: sub.length > 0
                font.family: VbTokens.fontBody
                font.pixelSize: VbTokens.typeCaption   // 13
                color: VbTokens.textTertiary
                lineHeight: 1.35
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
            ColumnLayout {
                id: extraSlot
                Layout.fillWidth: true
                Layout.topMargin: VbTokens.space1
                spacing: VbTokens.space2
            }
        }
    }

    ColumnLayout {
        width: parent ? parent.width : 640
        spacing: VbTokens.space5      // 24

        // ---- Header: accent diamond + VIBEMIS wordmark, then the welcome title ----
        ColumnLayout {
            Layout.fillWidth: true
            spacing: VbTokens.space2  // 8
            RowLayout {
                spacing: VbTokens.space2
                Rectangle {
                    width: 13; height: 13
                    color: VbTokens.accent
                    rotation: 45
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: "VIBEMIS"
                    font.family: VbTokens.fontDisplay
                    font.weight: Font.ExtraBold
                    font.pixelSize: VbTokens.sizeWordmark      // 21
                    font.letterSpacing: VbTokens.wordmarkSpacing
                    color: VbTokens.text
                    Layout.alignment: Qt.AlignVCenter
                }
            }
            Text {
                text: qsTr("Welcome to Vibemis")
                font.family: VbTokens.fontDisplay
                font.weight: Font.Bold
                font.pixelSize: VbTokens.typeDisplay           // 34
                color: VbTokens.textPrimary
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }

        // ---- Body: three info rows ----
        ColumnLayout {
            Layout.fillWidth: true
            spacing: VbTokens.space4  // 16

            // 1) In-stream Quick Menu — chord chips (gamepad) + keyboard fallback.
            InfoRow {
                glyph: "gamepad"
                title: qsTr("In-stream Quick Menu")
                sub: qsTr("Clipboard sync, server commands and stream controls — any time during a session.")

                // Chord as key-caps (Select + L1 + R1 + Ⓨ), matching the Help screen.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: VbTokens.space2
                    Repeater {
                        model: ["Select", "L1", "R1", "Y"]
                        delegate: RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: VbTokens.space2
                            Rectangle {
                                implicitWidth: modelData === "Y" ? 34 : (capText.implicitWidth + 24)
                                implicitHeight: 34
                                radius: modelData === "Y" ? 17 : VbTokens.radiusBadge
                                color: VbTokens.bgWindow
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.14)
                                Text {
                                    id: capText
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: VbTokens.fontBody
                                    font.pixelSize: VbTokens.typeCaption
                                    font.weight: modelData === "Y" ? Font.ExtraBold : Font.Bold
                                    color: VbTokens.text
                                }
                            }
                            Text {
                                visible: index < 3
                                text: "+"
                                font.family: VbTokens.fontBody
                                font.pixelSize: VbTokens.typeCaption
                                color: VbTokens.textDim
                            }
                        }
                    }
                }
                Text {
                    textFormat: Text.StyledText
                    text: qsTr("Keyboard: <font color='%1'>Ctrl + Alt + Shift + \\</font>").arg(VbTokens.textMute)
                    font.family: VbTokens.fontBody
                    font.pixelSize: VbTokens.typeCaption
                    color: VbTokens.textTertiary
                }
            }

            // 2) Add to Steam.
            InfoRow {
                glyph: "apps"
                title: qsTr("Add to Steam")
                sub: qsTr("On Steam Deck / SteamOS, add Vibemis to Steam from Desktop Mode so it appears in Game Mode.")
            }

            // 3) Settings.
            InfoRow {
                glyph: "advanced"
                title: qsTr("Settings")
                sub: qsTr("Set resolution, FPS, video scaling and more in Settings.")
            }
        }

        // ---- Primary action: single accent "Get started" pill (Ⓐ), focused by default ----
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: VbTokens.space1
            Item { Layout.fillWidth: true }   // right-align the button
            Button {
                id: getStartedBtn
                implicitHeight: VbTokens.minHitTarget     // 56
                leftPadding: VbTokens.space6; rightPadding: VbTokens.space6
                focusPolicy: Qt.TabFocus
                background: Rectangle {
                    radius: VbTokens.radiusControl
                    color: VbTokens.accent
                    border.width: getStartedBtn.activeFocus ? VbTokens.focusBorder : 0
                    border.color: VbTokens.accentHi
                }
                contentItem: Row {
                    spacing: VbTokens.space2
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26; height: 26; radius: 13
                        color: "transparent"
                        border.width: 2
                        border.color: VbTokens.textOnAccent
                        Text {
                            anchors.centerIn: parent
                            text: "A"
                            font.family: VbTokens.fontBody
                            font.pixelSize: VbTokens.typeCaption
                            font.weight: Font.ExtraBold
                            color: VbTokens.textOnAccent
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Get started")
                        font.family: VbTokens.fontBody
                        font.pixelSize: 17
                        font.weight: Font.ExtraBold
                        color: VbTokens.textOnAccent
                    }
                }
                onClicked: welcomeSheet.accept()
                Keys.onReturnPressed: welcomeSheet.accept()
                Keys.onEnterPressed: welcomeSheet.accept()
            }
        }

        // ---- Hint bar: Ⓐ Get started … Ⓑ Skip (reuses the shared VbHintBar) ----
        VbHintBar {
            Layout.fillWidth: true
            Layout.topMargin: VbTokens.space2
            hints: [ { glyph: "Ⓐ", label: qsTr("Get started") } ]
            hintsRight: [ { glyph: "Ⓑ", label: qsTr("Skip") } ]
        }
    }
}
