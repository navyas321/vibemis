import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.2
import Vibemis.Redesign 1.0

// Redesign screen 1f — Help. docs/design/redesign, preview 1f. Pure presentation (no host/
// streaming wiring): a hero Quick Menu card + gamepad shortcuts (left) and keyboard shortcuts
// + remote-play note (right), on the token system. Pushed onto the StackView by the Help
// button; Ⓑ / Esc / Back pops it.
Item {
    id: helpView
    anchors.fill: parent

    // Full-bleed window background.
    Rectangle { anchors.fill: parent; color: VbTokens.bgWindow }

    // Let Esc / Back / gamepad B pop this view.
    focus: true
    Keys.onEscapePressed: stackView.pop()
    Keys.onBackPressed: stackView.pop()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---- Header: Back + title ----
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: VbTokens.headerH
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: VbTokens.screenPadX
                anchors.rightMargin: VbTokens.screenPadX
                spacing: 20
                Button {
                    id: backBtn
                    implicitWidth: VbTokens.iconButton; implicitHeight: VbTokens.iconButton
                    focus: true
                    background: Rectangle {
                        radius: VbTokens.radiusIconButton
                        color: backBtn.activeFocus ? VbTokens.focusedFill : VbTokens.bgElev
                        border.width: 1; border.color: backBtn.activeFocus ? VbTokens.accent : VbTokens.stroke
                    }
                    contentItem: Text {
                        text: "‹"; anchors.centerIn: parent
                        font.family: VbTokens.fontDisplay; font.pixelSize: 30
                        color: VbTokens.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: stackView.pop()
                }
                Text {
                    text: qsTr("Help")
                    font.family: VbTokens.fontDisplay; font.weight: Font.Bold; font.pixelSize: VbTokens.sizeScreenTitle
                    color: VbTokens.text
                    Layout.fillWidth: true
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: VbTokens.strokeSoft }
        }

        // ---- Body: two columns ----
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: VbTokens.screenPadX
            spacing: VbTokens.cardGap

            // LEFT column: Quick Menu hero + gamepad shortcuts
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                spacing: VbTokens.cardGap

                // Hero Quick Menu card (accent gradient wash + accent border)
                VbCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 240
                    baseColor: VbTokens.bgElev
                    Rectangle {
                        anchors.fill: parent; radius: VbTokens.radiusCard
                        border.width: 1; border.color: VbTokens.accent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(VbTokens.accent.r, VbTokens.accent.g, VbTokens.accent.b, 0.14) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 28; spacing: 12
                        Text {
                            text: qsTr("Quick Menu")
                            font.family: VbTokens.fontDisplay; font.weight: Font.Bold; font.pixelSize: VbTokens.sizeSectionTitle
                            color: VbTokens.accent
                        }
                        Text {
                            text: qsTr("Open the in-stream overlay to paste, send text, run server commands, and control the stream.")
                            font.family: VbTokens.fontBody; font.pixelSize: VbTokens.sizeBody
                            color: VbTokens.textDim; wrapMode: Text.WordWrap; Layout.fillWidth: true
                        }
                        Item { Layout.fillHeight: true }
                        // Chord as key-caps: Select + L1 + R1 + Ⓨ
                        RowLayout {
                            spacing: 8
                            Repeater {
                                model: ["Select", "L1", "R1", "ⓨ"]
                                delegate: Rectangle {
                                    implicitWidth: chordText.implicitWidth + 20; implicitHeight: 34
                                    radius: 8; color: VbTokens.bgElev2
                                    border.width: 1; border.color: VbTokens.stroke
                                    Text {
                                        id: chordText; anchors.centerIn: parent; text: modelData
                                        font.family: VbTokens.fontBody; font.pixelSize: 15; font.bold: true
                                        color: modelData === "ⓨ" ? VbTokens.accent : VbTokens.textMute
                                    }
                                }
                            }
                        }
                    }
                }

                // Gamepad shortcuts card
                VbCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 24; spacing: 14
                        Text {
                            text: qsTr("Gamepad shortcuts")
                            font.family: VbTokens.fontDisplay; font.weight: Font.Bold; font.pixelSize: 20; color: VbTokens.text
                        }
                        Repeater {
                            model: [
                                { k: "Start + Select + L1 + R1", v: qsTr("Quit stream") },
                                { k: "Select + L1 + R1 + ⓧ", v: qsTr("Performance stats") },
                                { k: qsTr("Long-press Start"), v: qsTr("Mouse emulation") }
                            ]
                            delegate: RowLayout {
                                Layout.fillWidth: true; spacing: 16
                                Text { text: modelData.v; font.family: VbTokens.fontBody; font.pixelSize: VbTokens.sizeBody; color: VbTokens.textDim; Layout.fillWidth: true }
                                Text { text: modelData.k; font.family: VbTokens.fontBody; font.pixelSize: VbTokens.sizeLabel; font.bold: true; color: VbTokens.textMute }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // RIGHT column: keyboard shortcuts + remote play
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                spacing: VbTokens.cardGap

                VbCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 24; spacing: 14
                        Text {
                            text: qsTr("Keyboard shortcuts")
                            font.family: VbTokens.fontDisplay; font.weight: Font.Bold; font.pixelSize: 20; color: VbTokens.text
                        }
                        Text {
                            text: qsTr("All require Ctrl + Alt + Shift")
                            font.family: VbTokens.fontBody; font.pixelSize: VbTokens.sizeLabel; color: VbTokens.textDim
                        }
                        Repeater {
                            model: [
                                { k: "\\", v: qsTr("Toggle Quick Menu") },
                                { k: "Q", v: qsTr("Quit stream") },
                                { k: "X", v: qsTr("Toggle fullscreen") },
                                { k: "V", v: qsTr("Paste clipboard text") }
                            ]
                            delegate: RowLayout {
                                Layout.fillWidth: true; spacing: 16
                                Text { text: modelData.v; font.family: VbTokens.fontBody; font.pixelSize: VbTokens.sizeBody; color: VbTokens.textDim; Layout.fillWidth: true }
                                Rectangle {
                                    implicitWidth: 34; implicitHeight: 30; radius: 8; color: VbTokens.bgElev2
                                    border.width: 1; border.color: VbTokens.stroke
                                    Text { anchors.centerIn: parent; text: modelData.k; font.family: VbTokens.fontBody; font.pixelSize: 15; font.bold: true; color: VbTokens.accent }
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }

                VbCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 24; spacing: 12
                        Text {
                            text: qsTr("Remote play")
                            font.family: VbTokens.fontDisplay; font.weight: Font.Bold; font.pixelSize: 20; color: VbTokens.text
                        }
                        Text {
                            text: qsTr("Stream across networks with Tailscale — put the host and this device on the same tailnet, then add the host by its 100.x address. No port forwarding.")
                            font.family: VbTokens.fontBody; font.pixelSize: VbTokens.sizeBody
                            color: VbTokens.textDim; wrapMode: Text.WordWrap; Layout.fillWidth: true
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }

        // ---- Gamepad hint bar ----
        VbHintBar {
            Layout.fillWidth: true
            hints: [ { glyph: "Ⓑ", label: qsTr("Back") } ]
            hintsRight: [ { glyph: "☰", label: qsTr("Settings") } ]
        }
    }
}
