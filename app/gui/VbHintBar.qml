import QtQuick 2.9
import QtQuick.Layouts 1.2
import Vibemis.Redesign 1.0

// Persistent gamepad button-hint bar shown at the bottom of every redesigned screen.
// Feed `hints` as an array of { glyph, label } objects. Glyphs are
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
        anchors.leftMargin: 44          // HTML hint bar padding (0 44px)
        anchors.rightMargin: 44
        spacing: 36                     // HTML gap between hint items

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

    // Inline component: one glyph + label pair. Matches the design exactly (dc.html
    // lines 100-104): face buttons + ☰ render as a 30px circular OUTLINE badge (2px textDim
    // border) with the bare letter inside (ExtraBold, primary text); LB/RB render as rounded
    // key-caps. Callers pass the circled-letter unicode (Ⓐ/Ⓑ/Ⓧ/Ⓨ) which is mapped to the bare
    // letter here so existing hint arrays keep working.
    component VbHintItem: RowLayout {
        property string glyph: ""
        property string label: ""
        spacing: 11
        readonly property bool keyCap: glyph === "LB" || glyph === "RB"
        readonly property string capLetter: glyph === "Ⓐ" ? "A"
                                          : glyph === "Ⓑ" ? "B"
                                          : glyph === "Ⓧ" ? "X"
                                          : glyph === "Ⓨ" ? "Y"
                                          : glyph   // ☰ or an already-bare glyph

        // LB / RB rounded key-cap.
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
        // Circular outline badge for face buttons + ☰.
        Rectangle {
            visible: !keyCap
            implicitWidth: 30
            implicitHeight: 30
            radius: 15
            color: "transparent"
            border.width: 2
            border.color: VbTokens.textDim
            Text {
                anchors.centerIn: parent
                text: capLetter
                font.family: VbTokens.fontBody
                font.pixelSize: capLetter === "☰" ? 13 : 14
                font.weight: Font.ExtraBold
                color: VbTokens.text
            }
        }
        Text {
            text: label
            font.family: VbTokens.fontBody
            font.pixelSize: 16          // HTML hint label size
            color: VbTokens.textDim
        }
    }
}
