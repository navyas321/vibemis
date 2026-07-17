import QtQuick 2.9
import "../../app/gui"

// Validation scene: the Quick Menu over the native 1920x1200 panel size.
Rectangle {
    width: 1920
    height: 1200
    color: "#101010"

    QuickMenu {
        anchors.centerIn: parent
    }
}
