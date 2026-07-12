import QtQuick 2.9
import QtQuick.Layouts 1.3
import Vibemis.Redesign 1.0

// Redesign 1a host card — an EXACT port of design_handoff "Vibemis Redesign.dc.html" #1a card
// (lines 58-91) / previews/1a-computers.png. Pure-visual: PcView's delegate binds model roles to these
// properties and handles input/activation. 430px wide, radius 20, bg elev, padding 32, three stacked
// blocks (gap 20): [monitor-outline rect  ·  ONLINE/OFFLINE pill] / [name + access] / [badge + meta].
// Focused = 2px accent border + accent glow (VbFocusRing). Offline = whole card opacity .75, grey monitor.
Item {
    id: card

    property string hostName: ""
    property bool online: false
    property bool paired: false
    property bool statusUnknown: false
    property string accessText: ""          // "Paired · Full access" / "Paired · Tailscale"
    property string hostBadge: "SUNSHINE"   // VIBEPOLLO / APOLLO / SUNSHINE
    property bool badgeAccent: false         // accent outline for Apollo-lineage; neutral for Sunshine
    property string metaText: ""            // "4 ms · LAN" (online) / "Last seen 2 h ago" (offline)
    property bool focused: false

    implicitWidth: 430
    implicitHeight: 242

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: 20
        color: VbTokens.bgElev
        border.width: card.focused ? 2 : 1
        border.color: card.focused ? VbTokens.accent : VbTokens.stroke
        opacity: card.online ? 1.0 : 0.75

        VbFocusRing {
            active: card.focused
            radius: 20
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 32
            spacing: 20

            // ---- Row 1: monitor outline + status pill ----
            RowLayout {
                Layout.fillWidth: true
                // Monitor: an 82×58 rounded rectangle drawn as a 5px outline (no fill), like the HTML.
                Rectangle {
                    Layout.preferredWidth: 82
                    Layout.preferredHeight: 58
                    radius: 10
                    color: "transparent"
                    border.width: 5
                    border.color: card.online ? VbTokens.text : "#5A626C"
                }
                Item { Layout.fillWidth: true }
                // Status pill (green pulse ONLINE / grey OFFLINE).
                Rectangle {
                    visible: !card.statusUnknown
                    implicitWidth: pillRow.implicitWidth + 30
                    implicitHeight: 32
                    radius: VbTokens.radiusPill
                    color: card.online ? Qt.rgba(0.243, 0.835, 0.596, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                    Row {
                        id: pillRow
                        anchors.centerIn: parent
                        spacing: 8
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10; height: 10; radius: 5
                            color: card.online ? VbTokens.statusOnline : "#5A626C"
                            SequentialAnimation on opacity {
                                running: card.online
                                loops: Animation.Infinite
                                NumberAnimation { from: 1.0; to: 0.45; duration: VbTokens.onlinePulseMs / 2 }
                                NumberAnimation { from: 0.45; to: 1.0; duration: VbTokens.onlinePulseMs / 2 }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.online ? qsTr("ONLINE") : qsTr("OFFLINE")
                            font.family: VbTokens.fontBody
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            font.letterSpacing: 0.7
                            color: card.online ? VbTokens.statusOnline : VbTokens.textDim
                        }
                    }
                }
            }

            // ---- Name + access ----
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: card.hostName
                    font.family: VbTokens.fontDisplay
                    font.weight: Font.Bold
                    font.pixelSize: 27
                    color: card.online ? VbTokens.text : VbTokens.textMute
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: card.accessText
                    visible: card.accessText !== ""
                    font.family: VbTokens.fontBody
                    font.pixelSize: 17
                    color: VbTokens.textDim
                    elide: Text.ElideRight
                }
            }

            Item { Layout.fillHeight: true }

            // ---- Badge + meta ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                // Host-type badge (accent outline for Apollo-lineage, neutral for Sunshine).
                Rectangle {
                    implicitWidth: badgeText.implicitWidth + 20
                    implicitHeight: badgeText.implicitHeight + 8
                    radius: VbTokens.radiusBadge
                    color: "transparent"
                    border.width: 1
                    border.color: card.badgeAccent ? Qt.rgba(VbTokens.accent.r, VbTokens.accent.g, VbTokens.accent.b, 0.55)
                                                   : Qt.rgba(1, 1, 1, 0.14)
                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: card.hostBadge
                        font.family: VbTokens.fontBody
                        font.pixelSize: 13
                        font.weight: Font.ExtraBold
                        font.letterSpacing: 1.2
                        color: card.badgeAccent ? VbTokens.accent : VbTokens.textDim
                    }
                }
                Text {
                    text: card.metaText
                    visible: card.metaText !== ""
                    Layout.fillWidth: true
                    font.family: VbTokens.fontBody
                    font.pixelSize: 15
                    color: VbTokens.textDim
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
