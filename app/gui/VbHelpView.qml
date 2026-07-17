import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.2
import Vibemis.Redesign 1.0

// Redesign screen 1f — Help. docs/design/redesign, preview 1f. Pure presentation (no host/
// streaming wiring): four reference cards — Quick Menu, Keyboard shortcuts, Gamepad shortcuts,
// Remote play — on the token system. Pushed onto the StackView by the Help button; Ⓑ / Esc /
// Back pops it.
//
// The redesign requires (a) UNIFORM card dimensions,
// (b) everything on ONE screen with NO scrolling/movement, and (c) NO focus highlight — nothing
// on this page is actionable (it is a static reference sheet), only Ⓑ/Back leaves it. So:
//   * the Flickable + arrow-scroll handlers are GONE — the four cards live in a fixed
//     2×2 GridLayout that fills the body, so every card is exactly the same size and the content
//     always fits without scrolling at any window height.
//   * the hero Quick Menu card's accent-gradient wash + accent border are GONE — that decorative
//     wash read as "one card is highlighted"; all four cards are now the same plain elevated
//     surface, so the page has no highlight of any kind.
//   * no VbCard binds `focused`, and there is no focusable Control on the page, so nothing ever
//     draws a focus ring.
Item {
    id: helpView
    anchors.fill: parent

    // Full-bleed window background.
    Rectangle { anchors.fill: parent; color: VbTokens.bgWindow }

    // this screen has no actionable/focusable element, so on entry focus would
    // otherwise stick on the global toolbar and gamepad Ⓑ/Back would do nothing ("frozen" screen).
    // Grab focus on the (invisible) root Item — an Item draws no highlight — purely so Ⓑ/Esc/Back
    // are handled here and pop the screen. No arrow-key navigation: the page does not scroll.
    focus: true
    Component.onCompleted: helpView.forceActiveFocus()
    Keys.onEscapePressed: stackView.pop()
    Keys.onBackPressed: stackView.pop()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---- Body: a fixed 2×2 grid of UNIFORM cards, filling all space between the (global)
        // header and the hint bar. Every card gets an equal share of width and height, so the
        // four cards are identical in size and the whole page fits one screen without scrolling. ----
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: VbTokens.screenPadX
            Layout.rightMargin: VbTokens.screenPadX
            Layout.topMargin: VbTokens.screenPadY
            Layout.bottomMargin: VbTokens.screenPadY
            columns: 2
            columnSpacing: VbTokens.cardGap
            rowSpacing: VbTokens.cardGap

            // Row-major fill order → top-left, top-right, bottom-left, bottom-right.

            // TOP-LEFT: Quick Menu (the primary reference). Plain elevated surface — same size and
            // style as every other card (no accent wash / border, so it does not read as "highlighted").
            VbCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 1
                radius: 20
                ColumnLayout {
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 30
                    spacing: 12
                    Text {
                        text: qsTr("QUICK MENU")
                        font.family: VbTokens.fontBody; font.weight: Font.ExtraBold; font.pixelSize: 14
                        font.letterSpacing: 1.4
                        color: VbTokens.accent
                    }
                    Text {
                        text: qsTr("Open the in-stream overlay")
                        font.family: VbTokens.fontDisplay; font.weight: Font.Bold; font.pixelSize: 22
                        color: VbTokens.text
                    }
                    Text {
                        text: qsTr("Clipboard sync, server commands, and stream controls — any time during a session.")
                        font.family: VbTokens.fontBody; font.pixelSize: VbTokens.sizeBody; lineHeight: 1.4
                        color: VbTokens.textMute; wrapMode: Text.WordWrap; Layout.fillWidth: true
                    }
                    // Chord as key-caps: Select + L1 + R1 + (Y in a circle), "+" separators between.
                    RowLayout {
                        Layout.topMargin: 4
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

            // TOP-RIGHT: keyboard shortcuts.
            VbCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 1
                radius: 20
                ColumnLayout {
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 30
                    spacing: 14
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

            // BOTTOM-LEFT: gamepad shortcuts.
            VbCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 1
                radius: 20
                ColumnLayout {
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 30
                    spacing: 14
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

            // BOTTOM-RIGHT: remote play.
            VbCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 1
                radius: 20
                ColumnLayout {
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 30
                    spacing: 12
                    Text {
                        text: qsTr("Remote play")
                        font.family: VbTokens.fontDisplay; font.weight: Font.Bold; font.pixelSize: 19; color: VbTokens.text
                    }
                    Text {
                        textFormat: Text.StyledText
                        text: qsTr("Streaming over LAN works out of the box. For a different network, put both devices on <font color='%1'><b>Tailscale</b></font> and add the host by its Tailscale address — no port forwarding.")
                              .arg(VbTokens.accent)
                        font.family: VbTokens.fontBody; font.pixelSize: 16; lineHeight: 1.5
                        color: VbTokens.textMute; wrapMode: Text.WordWrap; Layout.fillWidth: true
                    }
                }
            }
        }

        // ---- Gamepad hint bar (Back is the only action on the page) ----
        VbHintBar {
            Layout.fillWidth: true
            hints: [ { glyph: "Ⓑ", label: qsTr("Back") } ]
            hintsRight: [ { glyph: "☰", label: qsTr("Settings") } ]
        }
    }
}
