import QtQuick 2.9
import "../../app/gui"

// BL-1688 validation scene: the Quick Menu centered over a Game-Mode-sized (1280x800)
// dark backdrop, exactly how the overlay composites into the stream.
Rectangle {
    width: 1280
    height: 800
    color: "#101010"

    QuickMenu {
        anchors.centerIn: parent
    }
}
