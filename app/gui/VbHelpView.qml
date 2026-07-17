import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.2
import Vibemis.Redesign 1.0

// Redesign screen 1f — Help. Pure presentation (no host/
// streaming wiring): four reference cards — Quick Menu, Keyboard shortcuts, Gamepad shortcuts,
// Remote play — on the token system. Pushed onto the StackView by the Help button; Ⓑ / Esc /
// Back pops it.
//
// The redesign requires (a) UNIFORM card dimensions and (b) NO focus
// highlight — nothing on this page is actionable (it is a static reference sheet), only Ⓑ/Back
// leaves it.
//
// BL-2153 (user decision, supersedes the BL-1684 "no scrolling ever" rule): cards may never be
// SMALLER than their content. On the Legion Go S the effective logical window (~960×600 at the
// panel's scale factor) gave each fixed 2×2 cell ~170px for ~240px of content, so titles and
// rows bled past the card borders. The cards now carry a shared MINIMUM height = the tallest
// card's content; when the window is tall enough the grid still fills it exactly as before (no
// scrolling, identical layout), and only when the window is too short does the page scroll
// (touch/drag or dpad/arrow up-down).
//   * the hero Quick Menu card's accent-gradient wash + accent border are GONE — that decorative
//     wash read as "one card is highlighted"; all four cards are now the same plain elevated
//     surface, so the page has no highlight of any kind.
//   * no VbCard binds `focused`, and there is no focusable Control on the page, so nothing ever
//     draws a focus ring.
Item {
    id: helpView
    anchors.fill: parent

    // Shared uniform card minimum: the tallest card's content + the 30px content
    // margins. Every cell binds this, so all four cards stay exactly the same size.
    readonly property real cardMinH: 60 + Math.max(qmCol.implicitHeight, kbCol.implicitHeight,
                                                   padCol.implicitHeight, rpCol.implicitHeight)

    // Full-bleed window background.
    Rectangle { anchors.fill: parent; color: VbTokens.bgWindow }

    // This screen has no actionable/focusable element, so on entry focus would
    // otherwise stick on the global toolbar and gamepad Ⓑ/Back would do nothing ("frozen" screen).
    // Grab focus on the (invisible) root Item — an Item draws no highlight — purely so Ⓑ/Esc/Back
    // are handled here and pop the screen. Up/Down scroll the page when (and only when) it
    // overflows; StopAtBounds + the clamp keep it inert on tall windows.
    focus: true
    Component.onCompleted: helpView.forceActiveFocus()
    Keys.onEscapePressed: stackView.pop()
    Keys.onBackPressed: stackView.pop()
    Keys.onUpPressed: helpFlick.contentY = Math.max(0, helpFlick.contentY - 80)
    Keys.onDownPressed: helpFlick.contentY = Math.min(Math.max(0, helpFlick.contentHeight - helpFlick.height),
                                                      helpFlick.contentY + 80)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---- Body: a 2×2 grid of UNIFORM cards. On tall windows the grid fills the
        // space between the (global) header and the hint bar exactly as before — equal shares,
        // no scrolling. When the window is too short for the cards' content minimum, the grid
        // takes its content height instead and this Flickable scrolls. ----
        Flickable {
            id: helpFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: helpGrid.height + 2 * VbTokens.screenPadY
            clip: true
            boundsBehavior: Flickable.StopAtBounds

        GridLayout {
            id: helpGrid
            x: VbTokens.screenPadX
            y: VbTokens.screenPadY
            width: helpFlick.width - 2 * VbTokens.screenPadX
            height: Math.max(implicitHeight, helpFlick.height - 2 * VbTokens.screenPadY)
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
                Layout.minimumHeight: helpView.cardMinH
                radius: 20
                ColumnLayout {
                    id: qmCol
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
                Layout.minimumHeight: helpView.cardMinH
                radius: 20
                ColumnLayout {
                    id: kbCol
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
                            // Keycap FIRST, label immediately after. The previous
                            // right-aligned keycap sat ~700px from its label at the card's
                            // far border — under glare the card surface vanishes and the
                            // keycaps read as floating outside the card (BL-2152). Uniform
                            // 34px keycaps also auto-align every label at the same x.
                            delegate: RowLayout {
                                Layout.fillWidth: true; spacing: 14
                                Rectangle {
                                    implicitWidth: 34; implicitHeight: 34; radius: 8; color: VbTokens.bgWindow
                                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
                                    Text { anchors.centerIn: parent; text: modelData.k; font.family: VbTokens.fontBody; font.pixelSize: 15; font.weight: Font.Bold; color: VbTokens.text }
                                }
                                Text {
                                    text: modelData.v
                                    font.family: VbTokens.fontBody; font.pixelSize: VbTokens.sizeBody; color: VbTokens.textMute
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    elide: Text.ElideRight
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
                Layout.minimumHeight: helpView.cardMinH
                radius: 20
                ColumnLayout {
                    id: padCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 30
                    spacing: 14
                    Text {
                        text: qsTr("Gamepad shortcuts")
                        font.family: VbTokens.fontDisplay; font.weight: Font.Bold; font.pixelSize: 19; color: VbTokens.text
                    }
                    ColumnLayout {
                        id: padRows
                        Layout.fillWidth: true
                        spacing: 14
                        // Widest label so far — every label column sizes to it, putting
                        // each chord immediately after its label instead of at the card's
                        // far border (same perceived-escape fix as the keyboard card).
                        property real labelW: 0
                        Repeater {
                            model: [
                                { k: "Start + Select + L1 + R1", v: qsTr("Quit stream") },
                                { k: "Select + L1 + R1 + X", v: qsTr("Performance stats") },
                                { k: qsTr("Long press Start"), v: qsTr("Mouse emulation") }
                            ]
                            delegate: RowLayout {
                                Layout.fillWidth: true; spacing: 16
                                Text {
                                    text: modelData.v
                                    font.family: VbTokens.fontBody; font.pixelSize: VbTokens.sizeBody; color: VbTokens.textMute
                                    Layout.preferredWidth: padRows.labelW
                                    elide: Text.ElideRight
                                    onImplicitWidthChanged: padRows.labelW = Math.max(padRows.labelW, implicitWidth)
                                    Component.onCompleted: padRows.labelW = Math.max(padRows.labelW, implicitWidth)
                                }
                                Text {
                                    text: modelData.k
                                    font.family: VbTokens.fontBody; font.pixelSize: VbTokens.sizeLabel; font.weight: Font.DemiBold; color: VbTokens.textDim
                                }
                                // absorb leftover width so rows stay left-packed
                                Item { Layout.fillWidth: true }
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
                Layout.minimumHeight: helpView.cardMinH
                radius: 20
                ColumnLayout {
                    id: rpCol
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
        }

        // ---- Gamepad hint bar (Back is the only action on the page) ----
        VbHintBar {
            Layout.fillWidth: true
            hints: [ { glyph: "Ⓑ", label: qsTr("Back") } ]
            hintsRight: [ { glyph: "☰", label: qsTr("Settings") } ]
        }
    }
}
