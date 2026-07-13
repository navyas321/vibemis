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

    // BL-1669: the Help screen had NO focusable element, so on entry focus stuck on the global
    // toolbar (only the ☰ settings icon was reachable) and gamepad Ⓑ/Back did nothing — the
    // screen read as "unusable / frozen". Grab focus on entry so Ⓑ/Esc pop and up/down scroll.
    focus: true
    Component.onCompleted: helpView.forceActiveFocus()
    Keys.onEscapePressed: stackView.pop()
    Keys.onBackPressed: stackView.pop()

    // BL-1669: scroll the (previously fixed, overflowing) body. The gamepad sends Key_Up/Down in
    // arrow nav mode and Tab/Backtab in UI nav mode, so accept BOTH plus PageUp/Down — whatever
    // the current mode emits scrolls the card body instead of doing nothing.
    Keys.onPressed: {
        if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || event.key === Qt.Key_PageDown) {
            helpFlick.contentY = Math.min(Math.max(0, helpFlick.contentHeight - helpFlick.height),
                                          helpFlick.contentY + 140)
            event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || event.key === Qt.Key_PageUp) {
            helpFlick.contentY = Math.max(0, helpFlick.contentY - 140)
            event.accepted = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---- Header (Back + "Help") MOVED to the always-present global toolbar (main.qml), kept
        // present so it renders under gamescope. Hidden here to avoid a double header. ----
        Item {
            visible: false
            Layout.fillWidth: true
            Layout.preferredHeight: 0
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: VbTokens.screenPadX
                anchors.rightMargin: VbTokens.screenPadX
                spacing: 20
                Button {
                    id: backBtn
                    implicitWidth: VbTokens.iconButton; implicitHeight: VbTokens.iconButton
                    background: Rectangle {
                        radius: VbTokens.radiusIconButton
                        color: backBtn.activeFocus ? VbTokens.focusedFill : VbTokens.bgElev
                        border.width: 1; border.color: backBtn.activeFocus ? VbTokens.accent : VbTokens.stroke
                    }
                    contentItem: Text {
                        text: "‹"; anchors.centerIn: parent
                        font.family: VbTokens.fontDisplay; font.pixelSize: 24
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

        // ---- Body: two columns, wrapped in a Flickable so tall content (or a small window)
        // scrolls instead of clipping the cards off the top/bottom edge (BL-1669). ----
        Flickable {
            id: helpFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: bodyRow.implicitHeight + VbTokens.screenPadY * 2
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { }

        RowLayout {
            id: bodyRow
            x: VbTokens.screenPadX
            y: VbTokens.screenPadY
            width: helpFlick.width - VbTokens.screenPadX * 2
            spacing: VbTokens.cardGap

            // LEFT column: Quick Menu hero + gamepad shortcuts. BL-1669: `Layout.preferredWidth`
            // was set to 1.1 / 1.0 as if it were a CSS flex ratio — but in QML it is an ABSOLUTE
            // pixel width (≈1px), which fought fillWidth and skewed the scaling. Use real relative
            // stretch widths instead (left slightly wider, as the design intends).
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 110
                spacing: 22

                // Hero Quick Menu card (accent gradient wash + accent border, 20px radius)
                VbCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: heroCol.implicitHeight + 64
                    radius: 20
                    baseColor: VbTokens.bgElev
                    Rectangle {
                        anchors.fill: parent; radius: 20
                        border.width: 1
                        border.color: Qt.rgba(VbTokens.accent.r, VbTokens.accent.g, VbTokens.accent.b, 0.3)
                        // Approximates the HTML's linear-gradient(135deg, color-mix(ac 20%, bgElev), bgElev);
                        // QtQuick 2.9's Gradient has no angle, so this fades top-to-bottom instead of diagonally.
                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: Qt.rgba(VbTokens.accent.r * 0.2 + VbTokens.bgElev.r * 0.8,
                                               VbTokens.accent.g * 0.2 + VbTokens.bgElev.g * 0.8,
                                               VbTokens.accent.b * 0.2 + VbTokens.bgElev.b * 0.8, 1.0)
                            }
                            GradientStop { position: 1.0; color: VbTokens.bgElev }
                        }
                    }
                    ColumnLayout {
                        id: heroCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 32; spacing: 14
                        Text {
                            text: qsTr("QUICK MENU")
                            font.family: VbTokens.fontBody; font.weight: Font.ExtraBold; font.pixelSize: 14
                            font.letterSpacing: 1.4
                            color: VbTokens.accent
                        }
                        Text {
                            text: qsTr("Open the in-stream overlay")
                            font.family: VbTokens.fontDisplay; font.weight: Font.Bold; font.pixelSize: 24
                            color: VbTokens.text
                        }
                        Text {
                            text: qsTr("Clipboard sync, server commands, and stream controls — any time during a session.")
                            font.family: VbTokens.fontBody; font.pixelSize: VbTokens.sizeBody; lineHeight: 1.5
                            color: VbTokens.textMute; wrapMode: Text.WordWrap; Layout.fillWidth: true
                        }
                        // Chord as key-caps: Select + L1 + R1 + (Y in a circle), "+" separators between
                        RowLayout {
                            spacing: 10
                            Repeater {
                                model: ["Select", "L1", "R1", "Y"]
                                delegate: RowLayout {
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 10
                                    Rectangle {
                                        implicitWidth: modelData === "Y" ? 38 : (chordText.implicitWidth + 28)
                                        implicitHeight: 38
                                        radius: modelData === "Y" ? 19 : 9
                                        color: VbTokens.bgWindow
                                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
                                        Text {
                                            id: chordText; anchors.centerIn: parent; text: modelData
                                            font.family: VbTokens.fontBody; font.pixelSize: 15
                                            font.weight: modelData === "Y" ? Font.ExtraBold : Font.Bold
                                            color: VbTokens.text
                                        }
                                    }
                                    Text {
                                        visible: index < 3
                                        text: "+"
                                        font.family: VbTokens.fontBody; font.pixelSize: 15
                                        color: VbTokens.textDim
                                    }
                                }
                            }
                        }
                    }
                }

                // Gamepad shortcuts card — sized to content (fix: VbCard has no implicitHeight,
                // so a fillHeight card starves to 0 when the column has no surplus space).
                VbCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: gpCol.implicitHeight + 56
                    radius: 20
                    ColumnLayout {
                        id: gpCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 28; spacing: 18
                        Text {
                            text: qsTr("Gamepad shortcuts")
                            font.family: VbTokens.fontDisplay; font.weight: Font.Bold; font.pixelSize: 19; color: VbTokens.text
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 14
                            Repeater {
                                model: [
                                    { k: "Start + Select + L1 + R1", v: qsTr("Quit stream") },
                                    { k: "Select + L1 + R1 + X", v: qsTr("Performance stats") },
                                    { k: qsTr("Long press Start"), v: qsTr("Mouse emulation") }
                                ]
                                delegate: RowLayout {
                                    Layout.fillWidth: true; spacing: 16
                                    Text { text: modelData.v; font.family: VbTokens.fontBody; font.pixelSize: VbTokens.sizeBody; color: VbTokens.textMute; Layout.fillWidth: true }
                                    Text { text: modelData.k; font.family: VbTokens.fontBody; font.pixelSize: VbTokens.sizeLabel; font.weight: Font.DemiBold; color: VbTokens.textDim }
                                }
                            }
                        }
                    }
                }
            }

            // RIGHT column: keyboard shortcuts + remote play
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 100
                spacing: 22

                VbCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: kbCol.implicitHeight + 56
                    radius: 20
                    ColumnLayout {
                        id: kbCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 28; spacing: 18
                        Text {
                            text: qsTr("Keyboard shortcuts")
                            font.family: VbTokens.fontDisplay; font.weight: Font.Bold; font.pixelSize: 19; color: VbTokens.text
                        }
                        Text {
                            textFormat: Text.StyledText
                            text: qsTr("All require <font color='%1'>Ctrl + Alt + Shift</font>").arg(VbTokens.textMute)
                            font.family: VbTokens.fontBody; font.pixelSize: VbTokens.sizeLabel; color: VbTokens.textDim
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Repeater {
                                model: [
                                    { k: "\\", v: qsTr("Toggle Quick Menu") },
                                    { k: "Q", v: qsTr("Quit stream") },
                                    { k: "X", v: qsTr("Toggle fullscreen") },
                                    { k: "V", v: qsTr("Paste clipboard") }
                                ]
                                delegate: RowLayout {
                                    Layout.fillWidth: true; spacing: 16
                                    Text { text: modelData.v; font.family: VbTokens.fontBody; font.pixelSize: VbTokens.sizeBody; color: VbTokens.textMute; Layout.fillWidth: true }
                                    Rectangle {
                                        implicitWidth: 34; implicitHeight: 34; radius: 8; color: VbTokens.bgWindow
                                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
                                        Text { anchors.centerIn: parent; text: modelData.k; font.family: VbTokens.fontBody; font.pixelSize: 15; font.weight: Font.Bold; color: VbTokens.text }
                                    }
                                }
                            }
                        }
                    }
                }

                VbCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: rpCol.implicitHeight + 56
                    radius: 20
                    ColumnLayout {
                        id: rpCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 28; spacing: 12
                        Text {
                            text: qsTr("Remote play")
                            font.family: VbTokens.fontDisplay; font.weight: Font.Bold; font.pixelSize: 19; color: VbTokens.text
                        }
                        Text {
                            textFormat: Text.StyledText
                            text: qsTr("Streaming over LAN works out of the box. For a different network, put both devices on <font color='%1'><b>Tailscale</b></font> and add the host by its Tailscale address — no port forwarding.")
                                  .arg(VbTokens.accent)
                            font.family: VbTokens.fontBody; font.pixelSize: 16; lineHeight: 1.6
                            color: VbTokens.textMute; wrapMode: Text.WordWrap; Layout.fillWidth: true
                        }
                    }
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
