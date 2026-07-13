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
        if (!obj) return false;   // currentItem is null during the first frame at startup
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
        // Redesign: EVERY redesigned launcher screen (1a Computers, 1b App grid, 1e Settings, 1f Help)
        // carries its OWN per-screen header (wordmark/back + title + icon buttons + hint bar), matching
        // the design handoff previews. So the global toolbar is collapsed on all of them — the previews
        // show only per-screen chrome, never a global bar.
        //
        // BLACK-SCREEN SAFETY (the 0.25.0 gamescope/WSI regression): collapsing the toolbar 60->0 on the
        // STARTUP screen resized the window during Vulkan swapchain creation -> "Destroying swapchain:
        // (nil)" -> black. The fix here is to make `redesignScreen` DEFAULT-TRUE — collapsed when
        // currentItem is still null (startup) AND on every redesign screen — so the toolbar is height 0
        // from the very first frame and NEVER transitions 60->0 at startup. It expands to 60 only for the
        // legacy fullscreen stream/quit segues, whose transitions happen after the window is stable and
        // on a separate render path. Test agent: verify 1a renders (not black) under gamescope.
        // Redesign header architecture (BLACK-SCREEN FIX): the global ApplicationWindow toolbar is
        // ALWAYS PRESENT at 84px and IS the per-screen header. It must never collapse to height 0 — a
        // 0-height / hidden header black-screens under the gamescope WSI path (test-agent-verified:
        // 0.25.1 with the toolbar PRESENT rendered clean; 0.25.0 + 0.26.0 with it collapsed went
        // black). So it stays visible on every screen and renders that screen's header content
        // (VIBEMIS wordmark on Computers; Back + title elsewhere). The redesign screens no longer draw
        // their own header BAR (only their body section title), so there is no double header.
        readonly property bool onPcView: qmltypeof(stackView.currentItem, "PcView")
        readonly property bool onSettings: qmltypeof(stackView.currentItem, "SettingsView")
        readonly property bool onHelp: qmltypeof(stackView.currentItem, "VbHelpView")
        readonly property bool onAppView: qmltypeof(stackView.currentItem, "AppView")
        height: 84
        visible: true
        anchors.topMargin: 0
        anchors.bottomMargin: 0

        // Redesign: dark token-styled surface. This global toolbar stays visible on the home screens
        // (1a Computers / 1b app grid) — where it can't collapse without resizing the window during
        // gamescope swapchain creation (the 0.25.0 black-screen cause) — so it must LOOK like the
        // redesign rather than the default Material indigo, which read as an "ugly blue" header
        // clashing with the dark UI below it. Height is constant on the home screens (no runtime
        // geometry change) so the black-screen fix is preserved.
        background: Rectangle {
            color: VbTokens.bgWindow
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: VbTokens.strokeSoft
            }
        }

        // VIBEMIS wordmark (diamond + wordmark), shown on the Computers screen in place of a title,
        // matching the handoff 1a header. Left-aligned at the HTML's 40px padding.
        Row {
            visible: toolBar.onPcView
            anchors.left: parent.left
            anchors.leftMargin: 40
            anchors.verticalCenter: parent.verticalCenter
            spacing: 11
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 13; height: 13
                color: VbTokens.accent
                rotation: 45
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "VIBEMIS"
                font.family: VbTokens.fontDisplay
                font.weight: Font.ExtraBold
                font.pixelSize: 21
                font.letterSpacing: 3
                color: VbTokens.text
            }
        }

        Label {
            id: titleLabel
            // Hidden on Computers (the wordmark stands in) and on the App grid (which shows a
            // left-aligned host + status block instead). On Settings/Help it shows the screen name;
            // the streaming segues keep their default objectName title.
            visible: !toolBar.onPcView && !toolBar.onAppView && toolBar.width > 700
            anchors.fill: parent
            text: toolBar.onSettings ? qsTr("Settings")
                : toolBar.onHelp ? qsTr("Help")
                : stackView.currentItem ? stackView.currentItem.objectName : ""
            font.pointSize: 20
            font.family: VbTokens.fontDisplay
            font.weight: Font.Bold
            color: VbTokens.text
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

            // App grid (1b) header: host name + online-dot + "Vibepollo · LAN" (host-type · transport),
            // left-aligned — the design's "‹ Navid-PC / ● Vibepollo · 4 ms". Reads the current AppView's
            // hostOnline/hostType/hostTransport properties (passed in by PcView when the view is pushed).
            ColumnLayout {
                visible: toolBar.onAppView
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                Text {
                    text: (toolBar.onAppView && stackView.currentItem) ? stackView.currentItem.objectName : ""
                    font.family: VbTokens.fontDisplay
                    font.weight: Font.Bold
                    font.pixelSize: 20
                    color: VbTokens.text
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                RowLayout {
                    spacing: 8
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        width: 9; height: 9; radius: 4.5
                        color: (toolBar.onAppView && stackView.currentItem && stackView.currentItem.hostOnline)
                               ? VbTokens.statusOnline : VbTokens.statusOffline
                    }
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: {
                            var it = toolBar.onAppView ? stackView.currentItem : null
                            if (!it) return ""
                            var badge = it.hostType === "VIBEPOLLO" ? qsTr("Vibepollo")
                                      : it.hostType === "APOLLO" ? qsTr("Apollo")
                                      : it.hostType === "SUNSHINE" ? qsTr("Sunshine") : ""
                            var t = it.hostTransport || ""
                            return badge + (badge && t ? " · " : "") + t
                        }
                        font.family: VbTokens.fontBody
                        font.pixelSize: 14
                        color: VbTokens.textDim
                    }
                }
            }

            // This label will appear when the window gets too small and
            // we need to ensure the toolbar controls don't collide
            Label {
                id: titleRowLabel
                font.pointSize: titleLabel.font.pointSize
                font.family: VbTokens.fontDisplay
                font.weight: Font.Bold
                color: VbTokens.text
                elide: Label.ElideRight
                horizontalAlignment: Qt.AlignHCenter
                verticalAlignment: Qt.AlignVCenter
                Layout.fillWidth: true

                // We need this label to always be visible so it can occupy the remaining space in the
                // RowLayout. To "hide" it, we set the text to empty. On Computers the wordmark stands in
                // (never a title); otherwise it mirrors titleLabel's text only when titleLabel is hidden
                // by a narrow window.
                text: (toolBar.onPcView || toolBar.onAppView) ? ""
                    : (titleLabel.visible ? ""
                       : toolBar.onSettings ? qsTr("Settings")
                       : toolBar.onHelp ? qsTr("Help")
                       : (stackView.currentItem ? stackView.currentItem.objectName : ""))
            }

            // Redesign 1e: the Settings version indicator as a token-styled chip
            // (matches the prototype's "Version 0.6.7" chip in the Settings header).
            Rectangle {
                id: versionLabel
                visible: qmltypeof(stackView.currentItem, "SettingsView")
                implicitWidth: versionChipText.implicitWidth + 28
                implicitHeight: versionChipText.implicitHeight + 12
                // Handoff 1e: accent-tinted pill (12% accent bg, radius 8, no border).
                radius: 8
                color: Qt.rgba(VbTokens.accent.r, VbTokens.accent.g, VbTokens.accent.b, 0.12)
                Layout.alignment: Qt.AlignVCenter
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

            // Redesign: Refresh (re-poll hosts on Computers / reload the app list on App grid).
            NavigableToolButton {
                id: refreshButton
                visible: toolBar.onPcView || toolBar.onAppView
                iconSource: "qrc:/res/refresh.svg"
                ToolTip.delay: 1000
                ToolTip.timeout: 3000
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Refresh")
                onClicked: {
                    if (stackView.currentItem && stackView.currentItem.refreshView)
                        stackView.currentItem.refreshView()
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

        // Custom Ⓐ Connect / Ⓑ Cancel pill buttons live in the content (handoff 1c) — no stock
        // DialogButtonBox. A = Return (accepted by the field / Connect button), B = Esc (closePolicy).
        standardButtons: Dialog.NoButton
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
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
            spacing: 28    // handoff 1c modal gap
            width: parent ? parent.width : 620

            Label {
                text: qsTr("Add a computer")
                font.family: VbTokens.fontDisplay
                font.weight: Font.Bold
                font.pixelSize: 30    // handoff 1c title
                color: VbTokens.text
            }
            Label {
                text: qsTr("Enter the IP address or hostname of your host PC.")
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
                    // BL-1647 (test-agent find): Material's placeholderText renders as a FLOATING
                    // label that rises to the control's top edge on focus and clipped into the
                    // custom 72px frame's border. Use a plain in-field hint instead (the handoff
                    // shows a static grey hint, not a floating label).
                    color: VbTokens.text
                    font.family: VbTokens.fontBody
                    font.pixelSize: 20
                    background: Item {}   // the surrounding Rectangle is the visual frame
                    Keys.onReturnPressed: addPcDialog.accept()
                    Keys.onEnterPressed: addPcDialog.accept()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        visible: editText.text.length === 0
                        text: "192.168.1.42"
                        color: VbTokens.textDim
                        font.family: VbTokens.fontBody
                        font.pixelSize: 20
                    }
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

            // ---- Custom footer: Ⓑ Cancel + Ⓐ Connect pill buttons (handoff 1c, lines 198-201) ----
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 14
                Item { Layout.fillWidth: true }   // right-align the buttons

                Button {
                    id: cancelBtn
                    implicitHeight: 56
                    leftPadding: 28; rightPadding: 28
                    focusPolicy: Qt.TabFocus
                    background: Rectangle {
                        radius: VbTokens.radiusControl
                        color: cancelBtn.activeFocus ? VbTokens.focusedFill : VbTokens.bgElev2
                        border.width: 1
                        border.color: cancelBtn.activeFocus ? VbTokens.accent : VbTokens.stroke
                    }
                    contentItem: Row {
                        spacing: 10
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26; height: 26; radius: 13
                            color: "transparent"; border.width: 2; border.color: VbTokens.textDim
                            Text { anchors.centerIn: parent; text: "B"; font.family: VbTokens.fontBody; font.pixelSize: 12; font.weight: Font.ExtraBold; color: VbTokens.textMute }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Cancel"); font.family: VbTokens.fontBody; font.pixelSize: 17; font.weight: Font.DemiBold; color: VbTokens.textMute }
                    }
                    onClicked: addPcDialog.reject()
                }

                Button {
                    id: connectBtn
                    implicitHeight: 56
                    leftPadding: 32; rightPadding: 32
                    focusPolicy: Qt.TabFocus
                    background: Rectangle {
                        radius: VbTokens.radiusControl
                        color: VbTokens.accent
                        border.width: connectBtn.activeFocus ? 2 : 0
                        border.color: VbTokens.accentHi
                    }
                    contentItem: Row {
                        spacing: 10
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26; height: 26; radius: 13
                            color: "transparent"; border.width: 2; border.color: VbTokens.textOnAccent
                            Text { anchors.centerIn: parent; text: "A"; font.family: VbTokens.fontBody; font.pixelSize: 12; font.weight: Font.ExtraBold; color: VbTokens.textOnAccent }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Connect"); font.family: VbTokens.fontBody; font.pixelSize: 17; font.weight: Font.ExtraBold; color: VbTokens.textOnAccent }
                    }
                    onClicked: addPcDialog.accept()
                }
            }
        }
    }
}
