import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Window 2.2
import QtQuick.Controls.Material 2.2
import Vibemis.Redesign 1.0

import ComputerManager 1.0
import AutoUpdateChecker 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0
import SdlGamepadKeyNavigation 1.0
import Theme 1.0

ApplicationWindow {
    property bool pollingActive: false

    // Set by SettingsView to force the back operation to pop all
    // pages except the initial view. This is required when doing
    // a retranslate() because AppView breaks for some reason.
    property bool clearOnBack: false

    id: window
    width: 1280
    height: 600

    // This function runs prior to creation of the initial StackView item
    function doEarlyInit() {
        // Override the background color to Material 2 colors for Qt 6.5+
        // in order to improve contrast between GFE's placeholder box art
        // and the background of the app grid.
        if (SystemProperties.usesMaterial3Theme) {
            Material.background = Theme.background
        }

        // P3.19 wave 1: bridge the Material style to the Vibemis design tokens so the
        // Material-styled pages (Computers grid, App grid, dialogs) share the same
        // accent/background system as the token-native pages. See docs/DESIGN_SYSTEM.md.
        Material.theme = Material.Dark
        Material.accent = Theme.accent

        SdlGamepadKeyNavigation.enable()
    }

    Component.onCompleted: {
        // Show the window according to the user's preferences
        if (SystemProperties.hasDesktopEnvironment) {
            if (StreamingPreferences.uiDisplayMode == StreamingPreferences.UI_MAXIMIZED) {
                window.showMaximized()
            }
            else if (StreamingPreferences.uiDisplayMode == StreamingPreferences.UI_FULLSCREEN) {
                window.showFullScreen()
            }
            else {
                window.show()
            }
        } else {
            window.showFullScreen()
        }

        // Display any modal dialogs for configuration warnings
        if (SystemProperties.isWow64) {
            wow64Dialog.open()
        }
        else if (!SystemProperties.hasHardwareAcceleration && StreamingPreferences.videoDecoderSelection !== StreamingPreferences.VDS_FORCE_SOFTWARE) {
            if (SystemProperties.isRunningXWayland) {
                xWaylandDialog.open()
            }
            else {
                noHwDecoderDialog.open()
            }
        }

        if (SystemProperties.unmappedGamepads) {
            unmappedGamepadDialog.unmappedGamepads = SystemProperties.unmappedGamepads
            unmappedGamepadDialog.open()
        }
    }
  
    // It would be better to use TextMetrics here, but it always lays out
    // the text slightly more compactly than real Text does in ToolTip,
    // causing unexpected line breaks to be inserted
    Text {
        id: tooltipTextLayoutHelper
        visible: false
        font: ToolTip.toolTip.font
        text: ToolTip.toolTip.text
    }

    // This configures the maximum width of the singleton attached QML ToolTip. If left unconstrained,
    // it will never insert a line break and just extend on forever.
    // Note: ToolTip must be attached to an Item, not ApplicationWindow
    Item {
        id: tooltipHelper
        ToolTip.toolTip.contentWidth: Math.min(tooltipTextLayoutHelper.width, 400)
    }

    function goBack() {
        if (clearOnBack) {
            // Pop all items except the first one
            stackView.pop(null)
            clearOnBack = false
        }
        else {
            stackView.pop()
        }
    }

    StackView {
        id: stackView
        anchors.fill: parent
        focus: true

        Component.onCompleted: {
            // Perform our early initialization before constructing
            // the initial view and pushing it to the StackView
            doEarlyInit()
            push(initialView)
        }

        onCurrentItemChanged: {
            // Ensure focus travels to the next view when going back
            if (currentItem) {
                currentItem.forceActiveFocus()
            }
        }

        Keys.onEscapePressed: {
            if (depth > 1) {
                goBack()
            }
            else {
                quitConfirmationDialog.open()
            }
        }

        Keys.onBackPressed: {
            if (depth > 1) {
                goBack()
            }
            else {
                quitConfirmationDialog.open()
            }
        }

        Keys.onMenuPressed: {
            settingsButton.clicked()
        }

        // This is a keypress we've reserved for letting the
        // SdlGamepadKeyNavigation object tell us to show settings
        // when Menu is consumed by a focused control.
        Keys.onHangupPressed: {
            settingsButton.clicked()
        }
    }

    // This timer keeps us polling for 5 minutes of inactivity
    // to allow the user to work with Moonlight on a second display
    // while dealing with configuration issues. This will ensure
    // machines come online even if the input focus isn't on Moonlight.
    Timer {
        id: inactivityTimer
        interval: 5 * 60000
        onTriggered: {
            if (!active && pollingActive) {
                ComputerManager.stopPollingAsync()
                pollingActive = false
            }
        }
    }

    onVisibleChanged: {
        // When we become invisible while streaming is going on,
        // stop polling immediately.
        if (!visible) {
            inactivityTimer.stop()

            if (pollingActive) {
                ComputerManager.stopPollingAsync()
                pollingActive = false
            }
        }
        else if (active) {
            // When we become visible and active again, start polling
            inactivityTimer.stop()

            // Restart polling if it was stopped
            if (!pollingActive) {
                ComputerManager.startPolling()
                pollingActive = true
            }
        }

        // Poll for gamepad input only when the window is in focus
        SdlGamepadKeyNavigation.notifyWindowFocus(visible && active)
    }

    onActiveChanged: {
        if (active) {
            // Stop the inactivity timer
            inactivityTimer.stop()

            // Restart polling if it was stopped
            if (!pollingActive) {
                ComputerManager.startPolling()
                pollingActive = true
            }
        }
        else {
            // Start the inactivity timer to stop polling
            // if focus does not return within a few minutes.
            inactivityTimer.restart()
        }

        // Poll for gamepad input only when the window is in focus
        SdlGamepadKeyNavigation.notifyWindowFocus(visible && active)
    }

    // Workaround for lack of instanceof in Qt 5.9.
    //
    // Based on https://stackoverflow.com/questions/13923794/how-to-do-a-is-a-typeof-or-instanceof-in-qml
    function qmltypeof(obj, className) { // QtObject, string -> bool
        // className plus "(" is the class instance without modification
        // className plus "_QML" is the class instance with user-defined properties
        var str = obj.toString();
        return str.startsWith(className + "(") || str.startsWith(className + "_QML");
    }

    function navigateTo(url, objectType)
    {
        var existingItem = stackView.find(function(item, index) {
            return qmltypeof(item, objectType)
        })

        if (existingItem !== null) {
            // Pop to the existing item
            stackView.pop(existingItem)
        }
        else {
            // Create a new item
            stackView.push(url)
        }
    }

    header: ToolBar {
        id: toolBar
        // Redesign: the redesigned screens carry their OWN per-screen header (Back/wordmark + title
        // + hint bar), so collapse the global toolbar on them to avoid a double header — matching the
        // design previews, which show only per-screen chrome. Screens 1a (PcView / Computers) and 1b
        // (AppView / app grid) own their full chrome as of test107, joining Settings (1e) + Help (1f).
        readonly property bool redesignScreen: stackView.currentItem
            && (qmltypeof(stackView.currentItem, "SettingsView") || qmltypeof(stackView.currentItem, "VbHelpView")
                || qmltypeof(stackView.currentItem, "PcView") || qmltypeof(stackView.currentItem, "AppView"))
        height: redesignScreen ? 0 : 60
        visible: !redesignScreen
        anchors.topMargin: 5
        anchors.bottomMargin: 5

        Label {
            id: titleLabel
            visible: toolBar.width > 700
            anchors.fill: parent
            text: stackView.currentItem.objectName
            font.pointSize: 20
            elide: Label.ElideRight
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter
        }

        RowLayout {
            spacing: 10
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.fill: parent

            NavigableToolButton {
                // Only make the button visible if the user has navigated somewhere.
                visible: stackView.depth > 1

                iconSource: "qrc:/res/arrow_left.svg"

                onClicked: goBack()

                Keys.onDownPressed: {
                    stackView.currentItem.forceActiveFocus(Qt.TabFocus)
                }
            }

            // This label will appear when the window gets too small and
            // we need to ensure the toolbar controls don't collide
            Label {
                id: titleRowLabel
                font.pointSize: titleLabel.font.pointSize
                elide: Label.ElideRight
                horizontalAlignment: Qt.AlignHCenter
                verticalAlignment: Qt.AlignVCenter
                Layout.fillWidth: true

                // We need this label to always be visible so it can occupy
                // the remaining space in the RowLayout. To "hide" it, we
                // just set the text to empty string.
                text: !titleLabel.visible ? stackView.currentItem.objectName : ""
            }

            // Redesign 1e: the Settings version indicator as a token-styled chip
            // (matches the prototype's "Version 0.6.7" chip in the Settings header).
            Rectangle {
                id: versionLabel
                visible: qmltypeof(stackView.currentItem, "SettingsView")
                implicitWidth: versionChipText.implicitWidth + 24
                implicitHeight: 30
                radius: VbTokens.radiusPill
                color: VbTokens.bgElev2
                border.width: 1
                border.color: VbTokens.stroke
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                Text {
                    id: versionChipText
                    anchors.centerIn: parent
                    text: qsTr("Version %1").arg(SystemProperties.versionString)
                    font.family: VbTokens.fontBody
                    font.pixelSize: VbTokens.sizeLabel
                    font.bold: true
                    color: VbTokens.accent
                }
            }

            NavigableToolButton {
                id: discordButton
                visible: false // Temporarily disabled for Vibemis

                iconSource: "qrc:/res/discord.svg"

                ToolTip.delay: 1000
                ToolTip.timeout: 3000
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Join our community on Discord")

                // TODO need to make sure browser is brought to foreground.
                onClicked: Qt.openUrlExternally("https://moonlight-stream.org/discord");

                Keys.onDownPressed: {
                    stackView.currentItem.forceActiveFocus(Qt.TabFocus)
                }
            }

            NavigableToolButton {
                id: addPcButton
                visible: qmltypeof(stackView.currentItem, "PcView")

                iconSource:  "qrc:/res/ic_add_to_queue_white_48px.svg"

                ToolTip.delay: 1000
                ToolTip.timeout: 3000
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Add PC manually") + (newPcShortcut.nativeText ? (" ("+newPcShortcut.nativeText+")") : "")

                Shortcut {
                    id: newPcShortcut
                    sequence: StandardKey.New
                    onActivated: addPcButton.clicked()
                }

                onClicked: {
                    addPcDialog.open()
                }

                Keys.onDownPressed: {
                    stackView.currentItem.forceActiveFocus(Qt.TabFocus)
                }
            }

            NavigableToolButton {
                property string browserUrl: ""

                id: updateButton

                iconSource: "qrc:/res/update.svg"

                ToolTip.delay: 1000
                ToolTip.timeout: 3000
                ToolTip.visible: hovered || visible

                // Invisible until we get a callback notifying us that
                // an update is available
                visible: false

                onClicked: {
                    if (SystemProperties.hasBrowser) {
                        Qt.openUrlExternally(browserUrl);
                    }
                }

                function updateAvailable(version, url)
                {
                    ToolTip.text = qsTr("Update available for Vibemis: Version %1").arg(version)
                    updateButton.browserUrl = url
                    updateButton.visible = true
                }

                Component.onCompleted: {
                    AutoUpdateChecker.onUpdateAvailable.connect(updateAvailable)
                    AutoUpdateChecker.start()
                }

                Keys.onDownPressed: {
                    stackView.currentItem.forceActiveFocus(Qt.TabFocus)
                }
            }

            NavigableToolButton {
                id: helpButton
                visible: SystemProperties.hasBrowser

                iconSource: "qrc:/res/question_mark.svg"

                ToolTip.delay: 1000
                ToolTip.timeout: 3000
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Help") + (helpShortcut.nativeText ? (" ("+helpShortcut.nativeText+")") : "")

                Shortcut {
                    id: helpShortcut
                    sequence: StandardKey.HelpContents
                    onActivated: helpButton.clicked()
                }

                // Redesign 1f: push the in-app Help screen (falls back to the repo URL is no
                // longer needed — the screen has the shortcuts + remote-play info inline).
                onClicked: {
                    var comp = Qt.createComponent("qrc:/gui/VbHelpView.qml")
                    if (comp.status === Component.Ready) {
                        stackView.push(comp)
                    } else {
                        Qt.openUrlExternally("https://github.com/navyas321/vibemis")
                    }
                }

                Keys.onDownPressed: {
                    stackView.currentItem.forceActiveFocus(Qt.TabFocus)
                }
            }

            NavigableToolButton {
                // TODO: Implement gamepad mapping then unhide this button
                visible: false

                ToolTip.delay: 1000
                ToolTip.timeout: 3000
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Gamepad Mapper")

                iconSource: "qrc:/res/ic_videogame_asset_white_48px.svg"

                onClicked: navigateTo("qrc:/gui/GamepadMapper.qml", "GamepadMapper")

                Keys.onDownPressed: {
                    stackView.currentItem.forceActiveFocus(Qt.TabFocus)
                }
            }

            NavigableToolButton {
                id: settingsButton

                iconSource:  "qrc:/res/settings.svg"

                onClicked: navigateTo("qrc:/gui/SettingsView.qml", "SettingsView")

                Keys.onDownPressed: {
                    stackView.currentItem.forceActiveFocus(Qt.TabFocus)
                }

                Shortcut {
                    id: settingsShortcut
                    sequence: StandardKey.Preferences
                    onActivated: settingsButton.clicked()
                }

                ToolTip.delay: 1000
                ToolTip.timeout: 3000
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Settings") + (settingsShortcut.nativeText ? (" ("+settingsShortcut.nativeText+")") : "")
            }
        }
    }

    ErrorMessageDialog {
        id: noHwDecoderDialog
        text: qsTr("No functioning hardware accelerated video decoder was detected by Vibemis. " +
                   "Your streaming performance may be severely degraded in this configuration.")
        helpText: qsTr("Click the Help button for more information on solving this problem.")
        helpUrl: "https://github.com/navyas321/vibemis"
    }

    ErrorMessageDialog {
        id: xWaylandDialog
        text: qsTr("Hardware acceleration doesn't work on XWayland. Continuing on XWayland may result in poor streaming performance. " +
                   "Try running with QT_QPA_PLATFORM=wayland or switch to X11.")
        helpText: qsTr("Click the Help button for more information.")
        helpUrl: "https://github.com/navyas321/vibemis"
    }

    NavigableMessageDialog {
        id: wow64Dialog
        standardButtons: Dialog.Ok | Dialog.Cancel
        text: qsTr("This version of Vibemis isn't optimized for your PC. Please download the '%1' version of Vibemis for the best streaming performance.").arg(SystemProperties.friendlyNativeArchName)
        onAccepted: {
            Qt.openUrlExternally("https://github.com/navyas321/vibemis/releases");
        }
    }

    ErrorMessageDialog {
        id: unmappedGamepadDialog
        property string unmappedGamepads : ""
        text: qsTr("Vibemis detected gamepads without a mapping:") + "\n" + unmappedGamepads
        helpTextSeparator: "\n\n"
        helpText: qsTr("Click the Help button for information on how to map your gamepads.")
        helpUrl: "https://github.com/navyas321/vibemis"
    }

    // This dialog appears when quitting via keyboard or gamepad button
    NavigableMessageDialog {
        id: quitConfirmationDialog
        standardButtons: Dialog.Yes | Dialog.No
        text: qsTr("Are you sure you want to quit?")
        // For keyboard/gamepad navigation
        onAccepted: Qt.quit()
    }

    // Vibemis: one-time welcome hint with key SteamOS / handheld onboarding tips.
    // Self-contained: opens from its own onCompleted and persists a "seen" flag, so it
    // shows exactly once and does not affect the main startup logic.
    NavigableMessageDialog {
        id: welcomeDialog
        standardButtons: Dialog.Ok
        text: qsTr("Welcome to Vibemis!") + "\n\n" +
              qsTr("• In-stream Quick Menu: Select + L1 + R1 + Y (gamepad), or Ctrl+Alt+Shift+\\ (keyboard).") + "\n" +
              qsTr("• On Steam Deck / SteamOS, add Vibemis to Steam from Desktop Mode so it appears in Game Mode.") + "\n" +
              qsTr("• Set resolution, FPS, video scaling and more in Settings.")

        function markSeen() {
            StreamingPreferences.seenWelcomeHint = true
            StreamingPreferences.save()
        }
        onAccepted: markSeen()
        onRejected: markSeen()

        Component.onCompleted: {
            if (!StreamingPreferences.seenWelcomeHint) {
                welcomeDialog.open()
            }
        }
    }

    // HACK: This belongs in StreamSegue but keeping a dialog around after the parent
    // dies can trigger bugs in Qt 5.12 that cause the app to crash. For now, we will
    // host this dialog in a QML component that is never destroyed.
    //
    // To repro: Start a stream, cut the network connection to trigger the "Connection
    // terminated" dialog, wait until the app grid times out back to the PC grid, then
    // try to dismiss the dialog.
    ErrorMessageDialog {
        id: streamSegueErrorDialog

        property bool quitAfter: false

        onClosed: {
            if (quitAfter) {
                Qt.quit()
            }

            // StreamSegue assumes its dialog will be re-created each time we
            // start streaming, so fake it by wiping out the text each time.
            text = ""
        }
    }

    NavigableDialog {
        // Redesign 1c: Add-PC dialog restyled on the VbTokens system (docs/design/redesign).
        // Wiring unchanged — accept still calls ComputerManager.addNewHostManually().
        id: addPcDialog
        property string label: qsTr("Enter the IP address of your host PC:")

        standardButtons: Dialog.Ok | Dialog.Cancel
        implicitWidth: 720
        padding: 48

        background: Rectangle {
            color: VbTokens.bgElev
            radius: VbTokens.radiusDialog
            border.width: 1
            border.color: VbTokens.stroke
        }

        onOpened: {
            // Force keyboard focus on the textbox so keyboard navigation works
            editText.forceActiveFocus()
        }

        onClosed: {
            editText.clear()
        }

        onAccepted: {
            if (editText.text) {
                ComputerManager.addNewHostManually(editText.text.trim())
            }
        }

        ColumnLayout {
            spacing: 20
            width: parent ? parent.width : 620

            Label {
                text: qsTr("Add a computer")
                font.family: VbTokens.fontDisplay
                font.weight: Font.Bold
                font.pixelSize: VbTokens.sizeSectionTitle
                color: VbTokens.text
            }
            Label {
                text: qsTr("Enter the host's IP address or hostname to pair and stream.")
                font.family: VbTokens.fontBody
                font.pixelSize: VbTokens.sizeBody
                color: VbTokens.textDim
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            // 72px token-styled field with a focus ring.
            Item {
                Layout.fillWidth: true
                implicitHeight: 72
                Rectangle {
                    anchors.fill: parent
                    radius: VbTokens.radiusControl
                    color: editText.activeFocus ? VbTokens.focusedFill : VbTokens.bgWindow
                    border.width: editText.activeFocus ? VbTokens.focusBorder : 1
                    border.color: editText.activeFocus ? VbTokens.accent : VbTokens.stroke
                }
                TextField {
                    id: editText
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    verticalAlignment: TextInput.AlignVCenter
                    focus: true
                    placeholderText: "192.168.1.42"
                    color: VbTokens.text
                    placeholderTextColor: VbTokens.textDim
                    font.family: VbTokens.fontBody
                    font.pixelSize: 20
                    background: Item {}   // the surrounding Rectangle is the visual frame
                    Keys.onReturnPressed: addPcDialog.accept()
                    Keys.onEnterPressed: addPcDialog.accept()
                }
            }

            // Tailscale hint — Tailscale in accent, the 100.x address in the muted tone.
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.family: VbTokens.fontBody
                font.pixelSize: VbTokens.sizeLabel
                color: VbTokens.textDim
                textFormat: Text.StyledText
                text: qsTr("On the same network, use the host's local IP. To stream across networks, put both devices on <font color='%1'>Tailscale</font> and enter the host's <font color='%2'>100.x.x.x</font> address or MagicDNS name.")
                      .arg(VbTokens.accent).arg(VbTokens.textMute)
            }
        }
    }
}
