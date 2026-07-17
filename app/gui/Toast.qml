import QtQuick 2.15
import QtQuick.Controls 2.15

import Vibemis.Redesign 1.0

Rectangle {
    id: toast
    width: 300
    height: 50
    radius: 10
    // P3.19 wave 2 (BL-2107): palette unified onto VbTokens (was #2A2A2A/#4A4A4A/#FFFFFF).
    color: VbTokens.bgElev2
    border.color: VbTokens.stroke
    border.width: 1
    opacity: 0.9

    property alias text: toastText.text

    Text {
        id: toastText
        anchors.centerIn: parent
        color: VbTokens.text
        font.pixelSize: VbTokens.sizeLabel
        font.bold: true
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    
    function showToast(message) {
        toast.text = message
        toast.opacity = 1.0
        return true
    }
}
