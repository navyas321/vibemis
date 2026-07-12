import QtQuick 2.9
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3
import Vibemis.Redesign 1.0

// NOTE: Controls 2.5 (not 2.2) — `Overlay.overlay` (used as this Popup's parent for a full-screen
// scrim + right-anchored 560px panel) only exists in QtQuick.Controls 2.3+. Under 2.2 it resolved to
// undefined, so the Popup fell back to its delegate (a ~300px host tile) as parent and the panel
// rendered as a small cluster on the tile instead of the full-height right slide-in (the "1d bug").

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
                // HTML: padding 44px 44px 28px, column, gap 18px between the icon/pill row
                // and the name+badge column below it (which is NOT indented past the icon —
                // both rows share the same 44px left padding, confirmed by the 1d preview PNG).
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 210

                    // Monitor glyph box, top-left.
                    Rectangle {
                        id: monoBox
                        x: 44
                        y: 44
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

                    // Online/offline pill, top-right — vertically centered against the icon box
                    // (HTML row1: align-items:center; justify-content:space-between).
                    VbStatusPill {
                        online: sheet.online
                        anchors.right: parent.right
                        anchors.rightMargin: 44
                        anchors.verticalCenter: monoBox.verticalCenter
                    }

                    // Host name — starts below the icon row, left-aligned to the same 44px
                    // padding as the icon (not offset to the icon's right).
                    Text {
                        id: nameText
                        text: sheet.hostName
                        anchors.left: parent.left
                        anchors.leftMargin: 44
                        anchors.right: parent.right
                        anchors.rightMargin: 44
                        anchors.top: monoBox.bottom
                        anchors.topMargin: 18
                        font.family: VbTokens.fontDisplay
                        font.weight: Font.Bold
                        font.pixelSize: VbTokens.sizeSectionTitle
                        color: VbTokens.text
                        elide: Text.ElideRight
                    }

                    // Host-type badge + access/transport subtitle.
                    RowLayout {
                        anchors.left: parent.left
                        anchors.leftMargin: 44
                        anchors.top: nameText.bottom
                        anchors.topMargin: 5
                        anchors.right: parent.right
                        anchors.rightMargin: 44
                        spacing: 10
                        VbBadge {
                            text: sheet.hostBadge
                            neutral: !sheet.apolloHost
                        }
                        Text {
                            text: sheet.subtitleLine
                            visible: sheet.subtitleLine !== ""
                            Layout.fillWidth: true
                            font.family: VbTokens.fontBody
                            font.pixelSize: 16
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
                    Layout.topMargin: 22
                    spacing: 8
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
                        // HTML divider: height:1 + margin:8px 0 (top/bottom). The ListView's own
                        // 8px inter-row `spacing` already supplies the gap above the divider, so
                        // only the divider's own height (1) + its bottom gap (8) are added here.
                        height: VbTokens.listRowH + (firstDanger ? 9 : 0)

                        // Divider above the first danger row. Inset 22px — matches the HTML
                        // action-list container's own 22px padding.
                        Rectangle {
                            visible: rowRoot.firstDanger
                            anchors.top: parent.top
                            x: 22
                            width: parent.width - 44
                            height: 1
                            color: VbTokens.strokeSoft
                        }

                        Rectangle {
                            id: rowFill
                            x: 22
                            width: parent.width - 44
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
                                anchors.leftMargin: 22
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 16
                                VbSheetIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    kind: modelData.icon
                                    color: rowRoot.danger ? VbTokens.statusDanger
                                                          : (rowRoot.current ? VbTokens.accent : VbTokens.textDim)
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    font.family: VbTokens.fontBody
                                    font.pixelSize: 18
                                    font.weight: rowRoot.danger ? Font.DemiBold
                                                                : (rowRoot.current ? Font.Bold : Font.Normal)
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
