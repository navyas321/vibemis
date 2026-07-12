import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import Vibemis.Redesign 1.0

// Redesign screen 1d — Host options side-sheet. Replaces PcView's old right-click
// NavigableMenu: a 560px full-height sheet that slides in from the right over a 60% scrim.
// docs/design/redesign preview 1d. Opened via pcContextMenu.open() (Ⓧ / long-press / offline
// tap on a card). Gamepad-first: D-pad moves the focused row, Ⓐ/Enter selects, Ⓑ/Esc closes.
//
// `actions` is an array of { label, icon, danger, visible, trigger } — the caller (PcView)
// supplies the host-specific wiring; this component only presents and navigates them. Rows with
// visible===false are dropped; the first `danger` row gets a divider above it.
Popup {
    id: sheet
    property var initiator
    property string hostName: ""
    property bool online: false
    property string hostBadge: "SUNSHINE"
    property bool apolloHost: false
    property string subtitleLine: ""
    property var actions: []

    // Only the applicable rows, in order.
    readonly property var visibleActions: {
        var out = []
        for (var i = 0; i < actions.length; i++) {
            var a = actions[i]
            if (a.visible === undefined || a.visible)
                out.push(a)
        }
        return out
    }

    parent: Overlay.overlay
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    modal: true
    dim: false                    // we draw our own scrim
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: Item {}

    // Fade the scrim + panel in together; the panel also slides (Translate below).
    enter: Transition { NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: VbTokens.sheetInMs } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: VbTokens.sheetInMs } }

    onOpened: {
        list.currentIndex = 0
        list.forceActiveFocus()
    }
    onClosed: stackView.forceActiveFocus()

    function activateCurrent() {
        var a = sheet.visibleActions[list.currentIndex]
        if (!a)
            return
        sheet.close()
        // Run the action after the sheet's overlay has torn down so pushed views /
        // dialogs don't fight the closing popup for focus.
        Qt.callLater(a.trigger)
    }

    contentItem: Item {
        id: root

        // ---- Scrim: dims the screen; click/tap outside the panel closes ----
        Rectangle {
            anchors.fill: parent
            color: VbTokens.sheetScrim
            MouseArea { anchors.fill: parent; onClicked: sheet.close() }
        }

        // ---- Right panel ----
        Rectangle {
            id: panel
            width: Math.min(560, root.width * 0.62)
            height: parent.height
            anchors.right: parent.right
            color: VbTokens.bgElev

            // Left edge hairline.
            Rectangle { anchors.left: parent.left; width: 1; height: parent.height; color: VbTokens.stroke }

            // Slide-in from the right edge.
            transform: Translate {
                x: sheet.visible ? 0 : panel.width
                Behavior on x { NumberAnimation { duration: VbTokens.sheetInMs; easing.type: Easing.OutCubic } }
            }

            // Swallow clicks so they don't reach the scrim's close handler.
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ---- Header ----
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150

                    // Monitor glyph box, top-left.
                    Rectangle {
                        id: monoBox
                        x: VbTokens.screenPadX - 8
                        y: 22
                        width: 56; height: 56
                        radius: VbTokens.radiusControl
                        color: VbTokens.bgElev2
                        border.width: 1
                        border.color: VbTokens.stroke
                        VbSheetIcon {
                            anchors.centerIn: parent
                            width: 30; height: 30
                            kind: "monitor"
                            color: sheet.online ? VbTokens.text : VbTokens.statusOffline
                        }
                    }

                    // Online/offline pill, top-right.
                    VbStatusPill {
                        online: sheet.online
                        anchors.right: parent.right
                        anchors.rightMargin: VbTokens.screenPadX - 8
                        anchors.top: parent.top
                        anchors.topMargin: 36
                    }

                    // Host name.
                    Text {
                        id: nameText
                        text: sheet.hostName
                        anchors.left: monoBox.right
                        anchors.leftMargin: 18
                        anchors.right: parent.right
                        anchors.rightMargin: VbTokens.screenPadX - 8
                        anchors.top: parent.top
                        anchors.topMargin: 30
                        font.family: VbTokens.fontDisplay
                        font.weight: Font.Bold
                        font.pixelSize: VbTokens.sizeSectionTitle
                        color: VbTokens.text
                        elide: Text.ElideRight
                    }

                    // Host-type badge + access/transport subtitle.
                    RowLayout {
                        anchors.left: monoBox.right
                        anchors.leftMargin: 18
                        anchors.top: nameText.bottom
                        anchors.topMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: VbTokens.screenPadX - 8
                        spacing: 12
                        VbBadge {
                            text: sheet.hostBadge
                            neutral: !sheet.apolloHost
                        }
                        Text {
                            text: sheet.subtitleLine
                            visible: sheet.subtitleLine !== ""
                            Layout.fillWidth: true
                            font.family: VbTokens.fontBody
                            font.pixelSize: VbTokens.sizeLabel
                            color: VbTokens.textDim
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: VbTokens.strokeSoft }
                }

                // ---- Action rows ----
                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: 12
                    clip: true
                    focus: true
                    keyNavigationEnabled: true
                    keyNavigationWraps: false
                    boundsBehavior: Flickable.StopAtBounds
                    model: sheet.visibleActions

                    Keys.onReturnPressed: sheet.activateCurrent()
                    Keys.onEnterPressed: sheet.activateCurrent()
                    Keys.onEscapePressed: sheet.close()
                    Keys.onBackPressed: sheet.close()

                    delegate: Item {
                        id: rowRoot
                        width: ListView.view.width
                        // A divider + gap sits above the first destructive row.
                        readonly property bool danger: modelData.danger === true
                        readonly property bool firstDanger: danger && (index === 0 || !(sheet.visibleActions[index - 1].danger === true))
                        readonly property bool current: ListView.isCurrentItem
                        height: VbTokens.listRowH + (firstDanger ? 17 : 0)

                        // Divider above the first danger row.
                        Rectangle {
                            visible: rowRoot.firstDanger
                            anchors.top: parent.top
                            anchors.topMargin: 8
                            x: VbTokens.screenPadX - 8
                            width: parent.width - 2 * (VbTokens.screenPadX - 8)
                            height: 1
                            color: VbTokens.strokeSoft
                        }

                        Rectangle {
                            id: rowFill
                            x: 18
                            width: parent.width - 36
                            height: VbTokens.listRowH
                            anchors.bottom: parent.bottom
                            radius: VbTokens.radiusControl
                            color: rowRoot.current ? VbTokens.focusedFill : "transparent"

                            VbFocusRing {
                                active: rowRoot.current && list.activeFocus
                                radius: VbTokens.radiusControl
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 16
                                VbSheetIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    kind: modelData.icon
                                    color: rowRoot.danger ? VbTokens.statusDanger
                                                          : (rowRoot.current ? VbTokens.accent : VbTokens.textMute)
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    font.family: VbTokens.fontBody
                                    font.pixelSize: VbTokens.sizeBody
                                    font.bold: rowRoot.current
                                    color: rowRoot.danger ? VbTokens.statusDanger : VbTokens.text
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: list.currentIndex = index
                                onClicked: {
                                    list.currentIndex = index
                                    sheet.activateCurrent()
                                }
                            }
                        }
                    }
                }

                // ---- Footer hint bar ----
                VbHintBar {
                    Layout.fillWidth: true
                    hints: [
                        { glyph: "Ⓐ", label: qsTr("Select") },
                        { glyph: "Ⓑ", label: qsTr("Close") }
                    ]
                }
            }
        }
    }
}
