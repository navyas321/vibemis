import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3

import Theme 1.0
import Vibemis.Redesign 1.0
import AppModel 1.0
import AppProfileManager 1.0
import ComputerManager 1.0
import SdlGamepadKeyNavigation 1.0

CenteredGridView {
    property int computerIndex
    property AppModel appModel : createModel()
    property bool activated
    property bool showHiddenGames
    property bool showGames
    // Redesign 1b header status line — passed from PcView when this view is pushed so the header
    // can show "● <hostType> · <transport>" (matching previews/1b-app-grid.png) without re-querying
    // the ComputerModel here.
    property bool hostOnline: true
    property string hostType: ""
    property string hostTransport: ""

    id: appGrid
    focus: true
    activeFocusOnTab: true
    // Redesign 1b: inset the grid so it clears the fixed per-screen header (Back + host name +
    // host status + "Apps N available" section title) and the bottom gamepad hint bar. The global
    // toolbar is collapsed on all redesign screens (main.qml). Chrome block is defined below.
    // Gap between the "Apps" title row and the tile row is 30 (HTML body flex gap), and the
    // bottom clearance matches the body's own bottom padding (screenPadY = 52).
    topMargin: appChromeHeader.height + 30
    bottomMargin: (appHintBar.visible ? appHintBar.height : 0) + VbTokens.screenPadY
    // Redesign 1b: 320x430 app tiles (HTML #1b), gap 36 horizontal; cellHeight adds room for the
    // 16px-gap + "Ⓐ Launch" hint row (or app name) below the focused tile.
    // Cap the row height to the available viewport so tiles never clip their bottom border on
    // shorter render surfaces (e.g. 1280x800 in Game Mode) — the absolute 474 was tuned for
    // 1920x1200 (BL-1622). At 1200p this stays 474; on shorter surfaces tiles shrink to fit.
    cellWidth: 356
    cellHeight: Math.max(300, Math.min(474, height - topMargin - bottomMargin))

    // ---- Redesign 1b chrome: per-screen header + persistent gamepad hint bar ----
    // Fixed header (does not scroll with the grid). Opaque bg so scrolled tiles pass behind it.
    Item {
        id: appChromeHeader
        z: 10
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        // Redesign 1b header (previews/1b-app-grid.png, lines 111-178): row 1 is a fixed 84px band
        // (padding 0 40, bottom divider) = Back + host name + "● <hostType> · <transport>" status,
        // Refresh + Settings on the right; row 2 = "Apps" + "N available", offset by the body's own
        // top padding (screenPadY = 52) below the divider. The global toolbar is collapsed on all
        // redesign screens (main.qml), so this is the only header.
        visible: true
        height: appsTitleRow.y + appsTitleRow.height

        Rectangle { anchors.fill: parent; color: VbTokens.bgWindow }

        // Row 1 (back + host name/status + refresh/settings) and its divider now live in the
        // always-present global toolbar (main.qml) — the toolbar reads hostOnline/hostType/
        // hostTransport (properties above) to render the same status line. Only the body section
        // title below remains in-screen.

        // ---- Row 2: "Apps" section title + available count (body top padding = screenPadY) ----
        Row {
            id: appsTitleRow
            anchors.top: parent.top
            anchors.topMargin: 34
            anchors.left: parent.left
            anchors.leftMargin: VbTokens.screenPadX
            spacing: 14
            Text {
                id: appsTitle
                text: qsTr("Apps")
                font.family: VbTokens.fontDisplay
                font.weight: Font.Bold
                font.pixelSize: VbTokens.sizeScreenTitle
                color: VbTokens.text
            }
            Text {
                anchors.baseline: appsTitle.baseline
                text: appGrid.count + " " + qsTr("available")
                font.family: VbTokens.fontBody
                font.pixelSize: 18
                color: VbTokens.textDim
            }
        }
    }

    // Persistent gamepad hint bar, fixed at the bottom. Grid bottomMargin clears it.
    VbHintBar {
        id: appHintBar
        z: 10
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        hints: [
            { glyph: "Ⓐ", label: qsTr("Launch") },
            { glyph: "Ⓑ", label: qsTr("Back") },
            { glyph: "Ⓧ", label: qsTr("App options") }
        ]
        hintsRight: [ { glyph: "☰", label: qsTr("Settings") } ]
    }

    // Called by the global toolbar's Refresh button (main.qml) — reload the host's app list.
    function refreshView() {
        appModel.initialize(ComputerManager, computerIndex, showHiddenGames)
    }

    function computerLost()
    {
        // Go back to the PC view on PC loss
        stackView.pop()
    }

    Component.onCompleted: {
        // Don't show any highlighted item until interacting with them.
        // We do this here instead of onActivated to avoid losing the user's
        // selection when backing out of a different page of the app.
        currentIndex = -1
    }

    StackView.onActivated: {
        appModel.computerLost.connect(computerLost)
        activated = true

        // Highlight the first item if a gamepad is connected
        if (currentIndex === -1 && SdlGamepadKeyNavigation.getConnectedGamepads() > 0) {
            currentIndex = 0
        }

        // Give the app grid active focus on entry (see PcView) so d-pad / arrow keys drive the
        // tiles immediately instead of a header toolbar button capturing focus.
        forceActiveFocus()

        if (!showGames && !showHiddenGames) {
            // Check if there's a direct launch app
            var directLaunchAppIndex = model.getDirectLaunchAppIndex();
            if (directLaunchAppIndex >= 0) {
                // Start the direct launch app if nothing else is running
                currentIndex = directLaunchAppIndex
                currentItem.launchOrResumeSelectedApp(false)

                // Set showGames so we will not loop when the stream ends
                showGames = true
            }
        }
    }

    StackView.onDeactivating: {
        appModel.computerLost.disconnect(computerLost)
        activated = false
    }

    function createModel()
    {
        var model = Qt.createQmlObject('import AppModel 1.0; AppModel {}', parent, '')
        model.initialize(ComputerManager, computerIndex, showHiddenGames)
        return model
    }

    model: appModel

    delegate: NavigableItemDelegate {
        id: appDelegate
        // Shrink with the row height on short surfaces so the tile + its border stay on-screen
        // (BL-1622). At 1200p cellHeight is 474 -> tile 430; on shorter surfaces it scales down.
        width: 320; height: Math.min(430, appGrid.cellHeight - 44)
        grid: appGrid

        property alias appContextMenu: appContextMenuLoader.item
        property alias appNameText: appNameTextLoader.item

        // Dim the app if it's hidden
        opacity: model.hidden ? 0.4 : 1.0

        // Redesign 1b tile card (previews/1b-app-grid.png): 320x430, radius 20, bg elev / focused
        // fill + accent ring via VbCard's built-in VbFocusRing recipe (see VbCard.qml — "used by
        // ... app tiles (1b)"). Box art fills the card with a small inset so the rounded frame and
        // border remain visible, matching the HTML tile chrome.
        VbCard {
            id: tileCard
            anchors.fill: parent
            radius: 20
            focused: appDelegate.highlighted

            Image {
                property bool isPlaceholder: false

                id: appIcon
                anchors.fill: parent
                anchors.margins: 5
                source: model.boxart

                onSourceSizeChanged: {
                    // Nearly all of Nvidia's official box art does not match the dimensions of placeholder
                    // images, however the one known exception is Overcooked. Therefore, we only execute
                    // the image size checks if this is not an app collector game. We know the officially
                    // supported games all have box art, so this check is not required.
                    if (!model.isAppCollectorGame &&
                        ((sourceSize.width === 130 && sourceSize.height === 180) || // GFE 2.0 placeholder image
                         (sourceSize.width === 628 && sourceSize.height === 888) || // GFE 3.0 placeholder image
                         (sourceSize.width === 200 && sourceSize.height === 266)))  // Our no_app_image.png
                    {
                        isPlaceholder = true
                    }
                    else
                    {
                        isPlaceholder = false
                    }
                }

                // Display a tooltip with the full name if it's truncated
                ToolTip.text: model.name
                ToolTip.delay: 1000
                ToolTip.timeout: 5000
                ToolTip.visible: (appDelegate.hovered || appDelegate.highlighted) && (!appNameText || appNameText.truncated)
            }

            Loader {
                active: model.running
                asynchronous: true
                anchors.fill: appIcon

                sourceComponent: Item {
                    RoundButton {
                        // Don't steal focus from the toolbar buttons
                        focusPolicy: Qt.NoFocus

                        anchors.horizontalCenterOffset: appIcon.isPlaceholder ? -47 : 0
                        anchors.verticalCenterOffset: appIcon.isPlaceholder ? -75 : -60
                        anchors.centerIn: parent
                        implicitWidth: 85
                        implicitHeight: 85

                        icon.source: "qrc:/res/play_arrow_FILL1_wght700_GRAD200_opsz48.svg"
                        icon.width: 75
                        icon.height: 75

                        onClicked: {
                            launchOrResumeSelectedApp(true)
                        }

                        ToolTip.text: qsTr("Resume Game")
                        ToolTip.delay: 1000
                        ToolTip.timeout: 3000
                        ToolTip.visible: hovered

                        Material.background: Qt.rgba(Theme.surfaceAlt.r, Theme.surfaceAlt.g, Theme.surfaceAlt.b, 0.82)
                    }

                    RoundButton {
                        // Don't steal focus from the toolbar buttons
                        focusPolicy: Qt.NoFocus

                        anchors.horizontalCenterOffset: appIcon.isPlaceholder ? 47 : 0
                        anchors.verticalCenterOffset: appIcon.isPlaceholder ? -75 : 60
                        anchors.centerIn: parent
                        implicitWidth: 85
                        implicitHeight: 85

                        icon.source: "qrc:/res/stop_FILL1_wght700_GRAD200_opsz48.svg"
                        icon.width: 75
                        icon.height: 75

                        onClicked: {
                            doQuitGame()
                        }

                        ToolTip.text: qsTr("Quit Game")
                        ToolTip.delay: 1000
                        ToolTip.timeout: 3000
                        ToolTip.visible: hovered

                        Material.background: Qt.rgba(Theme.surfaceAlt.r, Theme.surfaceAlt.g, Theme.surfaceAlt.b, 0.82)
                    }
                }
            }

            Loader {
                id: appNameTextLoader
                active: appIcon.isPlaceholder

                // This loader is not asynchronous to avoid noticeable differences
                // in the time in which the text loads for each game.

                width: appIcon.width
                height: model.running ? 175 : appIcon.height

                anchors.left: appIcon.left
                anchors.right: appIcon.right
                anchors.bottom: appIcon.bottom

                sourceComponent: Label {
                    id: appNameText
                    text: model.name
                    font.pointSize: 22
                    leftPadding: 20
                    rightPadding: 20
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                }
            }

            // Redesign 1b: solid RESUME badge, top-left of the tile (HTML: top:18/left:18,
            // bg #3ED598 solid, dark text, radius 6 — not the translucent/centered pill used before).
            Rectangle {
                visible: model.running
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: 18
                anchors.topMargin: 18
                z: 5
                implicitWidth: resumeLbl.implicitWidth + 20
                implicitHeight: resumeLbl.implicitHeight + 8
                radius: 6
                color: VbTokens.statusOnline
                Text {
                    id: resumeLbl
                    anchors.centerIn: parent
                    text: qsTr("RESUME")
                    font.family: VbTokens.fontBody
                    font.pixelSize: VbTokens.sizeBadge
                    font.bold: true
                    font.letterSpacing: VbTokens.badgeSpacing
                    color: VbTokens.bgWindow
                }
            }
        }

        // Redesign 1b: "Ⓐ Launch" hint under the focused tile (HTML: circled accent "A" + bold
        // "Launch", 16px below the card). Shown only while this tile is the current selection.
        Row {
            visible: appDelegate.highlighted
            anchors.top: tileCard.bottom
            anchors.topMargin: 16
            anchors.horizontalCenter: tileCard.horizontalCenter
            spacing: 11
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 28; height: 28; radius: 14
                color: "transparent"
                border.width: 2
                border.color: VbTokens.accent
                Text {
                    anchors.centerIn: parent
                    text: "A"
                    font.family: VbTokens.fontBody
                    font.pixelSize: 13
                    font.bold: true
                    color: VbTokens.accent
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Launch")
                font.family: VbTokens.fontBody
                font.weight: Font.Bold
                font.pixelSize: 18
                color: VbTokens.text
            }
        }

        function launchOrResumeSelectedApp(quitExistingApp)
        {
            var runningId = appModel.getRunningAppId()
            if (runningId !== 0 && runningId !== model.appid) {
                if (quitExistingApp) {
                    quitAppDialog.appName = appModel.getRunningAppName()
                    quitAppDialog.segueToStream = true
                    quitAppDialog.nextAppName = model.name
                    quitAppDialog.nextAppIndex = index
                    quitAppDialog.open()
                }

                return
            }

            var component = Qt.createComponent("StreamSegue.qml")
            var segue = component.createObject(stackView, {
                                                   "appName": model.name,
                                                   "session": appModel.createSessionForApp(index),
                                                   "isResume": runningId === model.appid
                                               })
            stackView.push(segue)
        }

        onClicked: {
            // Only allow clicking on the box art for non-running games.
            // For running games, buttons will appear to resume or quit which
            // will handle starting the game and clicks on the box art will
            // be ignored.
            if (!model.running) {
                launchOrResumeSelectedApp(true)
            }
        }

        onPressAndHold: {
            // popup() ensures the menu appears under the mouse cursor
            if (appContextMenu.popup) {
                appContextMenu.popup()
            }
            else {
                // Qt 5.9 doesn't have popup()
                appContextMenu.open()
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton;
            onClicked: {
                parent.pressAndHold()
            }
        }

        Keys.onReturnPressed: {
            // Open the app context menu if activated via the gamepad or keyboard
            // for running games. If the game isn't running, the above onClicked
            // method will handle the launch.
            if (model.running) {
                // This will be keyboard/gamepad driven so use
                // open() instead of popup()
                appContextMenu.open()
            }
        }

        Keys.onEnterPressed: {
            // Open the app context menu if activated via the gamepad or keyboard
            // for running games. If the game isn't running, the above onClicked
            // method will handle the launch.
            if (model.running) {
                // This will be keyboard/gamepad driven so use
                // open() instead of popup()
                appContextMenu.open()
            }
        }

        Keys.onMenuPressed: {
            // This will be keyboard/gamepad driven so use open() instead of popup()
            appContextMenu.open()
        }

        function doQuitGame() {
            quitAppDialog.appName = appModel.getRunningAppName()
            quitAppDialog.segueToStream = false
            quitAppDialog.open()
        }

        Loader {
            id: appContextMenuLoader
            asynchronous: true
            sourceComponent: NavigableMenu {
                id: appContextMenu
                initiator: appContextMenuLoader.parent

                // P3.8 per-game profiles: bump to re-evaluate hasProfile() bindings after
                // a save/clear (QML can't observe QSettings directly).
                property int profileRev: 0
                readonly property bool hasGameProfile: {
                    profileRev; // re-evaluation dependency
                    return AppProfileManager.hasProfile(appModel.getComputerUuid(), model.appid)
                }

                NavigableMenuItem {
                    text: model.running ? qsTr("Resume Game") : qsTr("Launch Game")
                    onTriggered: launchOrResumeSelectedApp(true)
                }
                NavigableMenuItem {
                    text: qsTr("Quit Game")
                    onTriggered: doQuitGame()
                    visible: model.running
                }
                NavigableMenuItem {
                    checkable: true
                    checked: model.directLaunch
                    text: qsTr("Direct Launch")
                    onTriggered: appModel.setAppDirectLaunch(model.index, !model.directLaunch)
                    enabled: !model.hidden

                    ToolTip.text: qsTr("Launch this app immediately when the host is selected, bypassing the app selection grid.")
                    ToolTip.delay: 1000
                    ToolTip.timeout: 3000
                    ToolTip.visible: hovered
                }
                NavigableMenuItem {
                    // P3.8: snapshot the CURRENT global settings (resolution/FPS/bitrate/HDR)
                    // as this game's stream profile, applied automatically at launch.
                    text: appContextMenu.hasGameProfile ? qsTr("Update Game Profile from Current Settings")
                                                        : qsTr("Save Current Settings as Game Profile")
                    onTriggered: {
                        AppProfileManager.saveCurrentAsProfile(appModel.getComputerUuid(), model.appid)
                        appContextMenu.profileRev++
                    }

                    ToolTip.text: qsTr("Store the current resolution, FPS, bitrate and HDR settings as this game's profile. Streams of this game will use the profile instead of the global settings.")
                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                }
                NavigableMenuItem {
                    text: {
                        appContextMenu.profileRev; // re-evaluation dependency
                        return qsTr("Clear Game Profile (%1)").arg(AppProfileManager.profileSummary(appModel.getComputerUuid(), model.appid))
                    }
                    visible: appContextMenu.hasGameProfile
                    onTriggered: {
                        AppProfileManager.clearProfile(appModel.getComputerUuid(), model.appid)
                        appContextMenu.profileRev++
                    }

                    ToolTip.text: qsTr("Remove this game's stream profile and go back to the global settings.")
                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                }
                NavigableMenuItem {
                    checkable: true
                    checked: model.hidden
                    text: qsTr("Hide Game")
                    onTriggered: appModel.setAppHidden(model.index, !model.hidden)
                    enabled: model.hidden || (!model.running && !model.directLaunch)

                    ToolTip.text: qsTr("Hide this game from the app grid. To access hidden games, right-click on the host and choose %1.").arg(qsTr("View All Apps"))
                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                }
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 5
        visible: appGrid.count === 0

        Label {
            text: qsTr("This computer doesn't seem to have any applications or some applications are hidden")
            font.pointSize: 20
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
        }
    }

    NavigableMessageDialog {
        id: quitAppDialog
        property string appName : ""
        property bool segueToStream : false
        property string nextAppName: ""
        property int nextAppIndex: 0
        text:qsTr("Are you sure you want to quit %1? Any unsaved progress will be lost.").arg(appName)
        standardButtons: Dialog.Yes | Dialog.No

        function quitApp() {
            var component = Qt.createComponent("QuitSegue.qml")
            var params = {"appName": appName, "quitRunningAppFn": function() { appModel.quitRunningApp() }}
            if (segueToStream) {
                // Store the session and app name if we're going to stream after
                // successfully quitting the old app.
                params.nextAppName = nextAppName
                params.nextSession = appModel.createSessionForApp(nextAppIndex)
            }
            else {
                params.nextAppName = null
                params.nextSession = null
            }

            stackView.push(component.createObject(stackView, params))
        }

        onAccepted: quitApp()
    }

    ScrollBar.vertical: ScrollBar {}
}
