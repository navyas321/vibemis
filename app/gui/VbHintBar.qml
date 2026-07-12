import QtQuick 2.9
import QtQuick.Layouts 1.2
import Vibemis.Redesign 1.0

// Persistent gamepad button-hint bar shown at the bottom of every redesigned screen
// (docs/design/redesign). Feed `hints` as an array of { glyph, label } objects. Glyphs are
// the controller face buttons (Ⓐ Ⓑ Ⓧ Ⓨ), shoulders (LB/RB rounded key-caps), or ☰. Toggle
// via VbTokens.showHints. Right-aligned hints can be passed via `hintsRight`.
Rectangle {
    id: bar
    property var hints: []          // [{ glyph: "Ⓐ", label: "Connect" }, ...]
    property var hintsRight: []     // e.g. [{ glyph: "☰", label: "Settings" }]
    height: VbTokens.footerH
    color: VbTokens.bgFooter
    visible: VbTokens.showHints

    // Top divider
    Rectangle {
        anchors.top: parent.top; width: parent.width; height: 1
        color: VbTokens.strokeSoft
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: VbTokens.screenPadX
        anchors.rightMargin: VbTokens.screenPadX
        spacing: 28

        Repeater {
            model: bar.hints
            delegate: VbHintItem { glyph: modelData.glyph; label: modelData.label }
        }
        Item { Layout.fillWidth: true }   // push the right group to the edge
        Repeater {
            model: bar.hintsRight
            delegate: VbHintItem { glyph: modelData.glyph; label: modelData.label }
        }
    }

    // Inline component: one glyph + label pair. LB/RB render as rounded key-caps; the
    // circled letters render as glyphs at the gamepad glyph diameter.
    component VbHintItem: RowLayout {
        property string glyph: ""
        property string label: ""
        spacing: 8
        readonly property bool keyCap: glyph === "LB" || glyph === "RB"

        Rectangle {
            visible: keyCap
            implicitWidth: capText.implicitWidth + 16
            implicitHeight: 26
            radius: 7
            color: VbTokens.bgElev2
            border.width: 1
            border.color: VbTokens.stroke
            Text {
                id: capText; anchors.centerIn: parent; text: glyph
                font.family: VbTokens.fontBody; font.pixelSize: 13; font.bold: true
                color: VbTokens.textMute
            }
        }
        Text {
            visible: !keyCap
            text: glyph
            font.family: VbTokens.fontBody
            font.pixelSize: VbTokens.buttonGlyphD
            color: VbTokens.accent
        }
        Text {
            text: label
            font.family: VbTokens.fontBody
            font.pixelSize: VbTokens.sizeLabel
            color: VbTokens.textDim
        }
    }
}
