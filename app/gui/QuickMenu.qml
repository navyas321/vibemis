import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.2
import ServerCommandManager 1.0
import UiSoundManager 1.0
import Vibemis.Redesign 1.0

// Redesigned onto the Vibemis token system (dark elevated panel, Sora/Manrope
// type, VbSheetIcon line glyphs instead of emoji, sheet-style rows, hint-bar footer) —
// matching the redesigned screens. Input model unchanged (d-pad auto-repeat, left stick,
// injected keys). Renders offscreen into the stream; VbTokens is a process-global
// singleton and VbSheetIcon resolves from the same qrc:/gui directory, so the separate
// offscreen QML engine sees both.
Rectangle {
    id: quickMenu
    // Fixed size for the menu - small and centered
    width: 520
    height: 420
    // Don't use anchors with SizeViewToRootObject - position manually
    color: VbTokens.surfaceRaised
    radius: VbTokens.radiusWindow
    border.color: VbTokens.divider
    border.width: 1
    visible: true  // Always visible when created
    opacity: 1.0
    
    // Menu state management
    property string currentMenu: "main"  // "main" or "server_commands"
    
    // Toast notification system
    property string toastMessage: ""
    property bool showToast: false

    // Server command data model
    ListModel {        id: serverCommandsModel    }
    
    // Animation for smooth show/hide
    Behavior on opacity {
        NumberAnimation { duration: 200 }
    }
    
    // Handle keyboard input for navigation
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            // From a submenu, Esc/B/Back returns to the main menu (matching the
            // on-screen "← Back" button); from the main menu it resumes the game.
            if (currentMenu === "text_send") {
                if (typeof quickMenuManager !== 'undefined') quickMenuManager.setTextInputActive(false)
                currentMenu = "main"
            } else if (currentMenu !== "main") {
                currentMenu = "main"
            } else {
                closeMenu()
            }
        } else if (event.key === Qt.Key_Up) {
            menuListView.decrementCurrentIndex()
        } else if (event.key === Qt.Key_Down) {
            menuListView.incrementCurrentIndex()
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            executeCurrentItem()
        }
    }
    
    // Menu content (no longer nested in another rectangle)
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 12

        // Screen-style title — Sora bold, left-aligned over a soft hairline,
        // like the redesigned section headers (was a centered cyan pointSize title).
        Text {
            text: currentMenu === "text_send" ? qsTr("Send text to host")
                  : (currentMenu === "main" ? qsTr("Quick Menu") : qsTr("Server commands"))
            font.family: VbTokens.fontDisplay
            font.weight: Font.Bold
            font.pixelSize: 24
            color: VbTokens.textPrimary
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: VbTokens.dividerSoft
        }

        // Menu items
        ListView {
            id: menuListView
            visible: currentMenu !== "text_send"
            Layout.fillWidth: true
            Layout.fillHeight: true
            // The root item owns keyboard focus and forwards navigation via Keys.onPressed,
            // so the ListView must not also claim focus (events are injected to the root).
            focus: false
            currentIndex: 0
            // Focus tick. The menu lives in an offscreen window (separate QML
            // engine), so the launcher's activeFocusItem hook can't see it — currentIndex
            // is this menu's focus cursor (moved via injected Up/Down keys and hover).
            onCurrentIndexChanged: UiSoundManager.focusMoved()
            // Bug fix: without clip the 16 delegates (≈960px of content) painted OUTSIDE the
            // ~250px viewport, bleeding over the footer "Resume Game" hint and the title —
            // this is what made the last visible row (e.g. "Fetch Clipboard") and the footer
            // overlap. Clip keeps every delegate inside the list's own bounds.
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            // Keep the keyboard/gamepad-selected row scrolled into view.
            highlightMoveDuration: 0
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: 0
            preferredHighlightEnd: height

            model: currentMenu === "main" ? mainMenuModel : serverCommandsModel
            
            delegate: Button {
                id: menuRow
                width: menuListView.width
                // Taller row so the selection rectangle isn't cramped against the label
                // (was 60 with only 6px text margin — the teal border hugged the text). The list
                // scrolls (d-pad repeat / left stick), so the extra height is fine.
                height: 70
                flat: true

                // Highlight the keyboard/gamepad-selected row, not just mouse hover, so
                // controller navigation is visible in Game Mode.
                highlighted: ListView.isCurrentItem

                // Destructive rows (quit) take the danger treatment like the
                // host sheet's Delete row.
                readonly property bool danger: model.action === "quit"
                readonly property bool active: hovered || highlighted

                // Sheet-row recipe — focusedFill surface + accent border when
                // current (flat variant: the outer glow would clip inside this scrolling
                // clipped list, so the ring is border-only here).
                background: Rectangle {
                    radius: VbTokens.radiusControl
                    color: menuRow.down ? Qt.darker(VbTokens.interactiveFocus, 1.15)
                                        : (menuRow.active ? VbTokens.interactiveFocus : "transparent")
                    border.color: menuRow.active ? VbTokens.accent : "transparent"
                    border.width: VbTokens.focusBorder
                }

                onClicked: {
                    executeAction(model.action)
                }

                // Bug fix: the old RowLayout mixed anchors.fill with anchors.left/right/
                // verticalCenter (conflicting anchors) and its labels had no width bound or
                // elision, so long descriptions overflowed the row and collided with the next
                // item. Fill the delegate with explicit padding; the label column fills the
                // remaining width and elides instead of overflowing.
                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    spacing: 16

                    // Monochrome line glyph (VbSheetIcon) instead of an emoji —
                    // accent when selected, danger red for quit, dim otherwise.
                    VbSheetIcon {
                        kind: model.icon
                        color: menuRow.danger ? VbTokens.statusDanger
                                              : (menuRow.active ? VbTokens.accent : VbTokens.textSecondary)
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 3

                        Text {
                            text: model.text
                            font.family: VbTokens.fontBody
                            font.pixelSize: 17
                            font.weight: menuRow.active ? Font.Bold : Font.DemiBold
                            color: menuRow.danger ? VbTokens.statusDanger : VbTokens.textPrimary
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: model.description
                            font.family: VbTokens.fontBody
                            font.pixelSize: 12
                            color: VbTokens.textSecondary
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // On-screen text-send view. A focused TextField receives typed
        // characters routed from SDL_TEXTINPUT via QuickMenuManager::injectText; Send (or
        // Enter) ships the string to the host as a UTF-8 text event. Fills the OSK gap on
        // keyboard-less handhelds (works with a physical keyboard or the platform OSK).
        ColumnLayout {
            visible: currentMenu === "text_send"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            TextField {
                id: sendTextField
                Layout.fillWidth: true
                placeholderText: qsTr("Type text to send to the host…")
                color: VbTokens.textPrimary
                placeholderTextColor: VbTokens.textSecondary
                font.family: VbTokens.fontBody
                font.pixelSize: 16
                selectByMouse: true
                // Keep typed text inside the styled border — the field fills
                // width with a bordered background but had no clip and no horizontal
                // padding, so long text ran to/past the border edge.
                clip: true
                leftPadding: 12
                rightPadding: 12
                // Token field — window-dark well + accent focus border.
                background: Rectangle {
                    color: VbTokens.surfaceBase
                    border.color: sendTextField.activeFocus ? VbTokens.accent : VbTokens.divider
                    border.width: VbTokens.focusBorder
                    radius: VbTokens.radiusControl
                }
                onActiveFocusChanged: {
                    if (typeof quickMenuManager !== 'undefined')
                        quickMenuManager.setTextInputActive(activeFocus)
                }
                onAccepted: quickMenu.sendTypedText()
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Button {
                    text: qsTr("Send")
                    Layout.fillWidth: true
                    enabled: sendTextField.text.length > 0
                    onClicked: quickMenu.sendTypedText()
                }
                Button {
                    text: qsTr("Clear")
                    onClicked: sendTextField.text = ""
                }
            }

            Text {
                text: qsTr("Enter sends · Ⓑ / Esc returns to the menu")
                font.family: VbTokens.fontBody
                font.pixelSize: 13
                color: VbTokens.textSecondary
                Layout.alignment: Qt.AlignHCenter
            }

            Item { Layout.fillHeight: true }
        }

        // Divider so the footer hint reads as a separate bar below the scrolling menu
        // list rather than sitting on top of the last row.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: VbTokens.dividerSoft
        }

        // Footer restyled as a hint bar (circled glyphs + labels, like every
        // redesigned screen's VbHintBar) — still tappable to go back/resume
        // (controller users need the discoverable gamepad way back to the game).
        // Bug fix history: pinned full-width below the clipped list.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 34

            Row {
                anchors.centerIn: parent
                spacing: 26

                Row {
                    spacing: 8
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 30; implicitHeight: 30; radius: 15
                        color: "transparent"
                        border.width: 2
                        border.color: VbTokens.textSecondary
                        Text {
                            anchors.centerIn: parent
                            text: "A"
                            font.family: VbTokens.fontBody
                            font.pixelSize: 14
                            font.weight: Font.ExtraBold
                            color: VbTokens.textPrimary
                        }
                    }
                    Text {
                        text: qsTr("Select")
                        font.family: VbTokens.fontBody
                        font.pixelSize: VbTokens.sizeLabel
                        color: VbTokens.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Row {
                    spacing: 8
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 30; implicitHeight: 30; radius: 15
                        color: "transparent"
                        border.width: 2
                        border.color: VbTokens.textSecondary
                        Text {
                            anchors.centerIn: parent
                            text: "B"
                            font.family: VbTokens.fontBody
                            font.pixelSize: 14
                            font.weight: Font.ExtraBold
                            color: VbTokens.textPrimary
                        }
                    }
                    Text {
                        text: currentMenu === "main" ? qsTr("Resume game") : qsTr("Back")
                        font.family: VbTokens.fontBody
                        font.pixelSize: VbTokens.sizeLabel
                        color: VbTokens.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (currentMenu === "main") {
                        closeMenu()
                    } else {
                        currentMenu = "main"
                    }
                }
            }
        }
    }
    
    // Toast notification overlay. Bug fix: anchored to the TOP as a banner (was at the
    // bottom, where it stacked on top of the "Resume Game" footer). Kept off the footer
    // hint bar and out of the menu rows; it only shows transiently on an action.
    Rectangle {
        id: toastNotification
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 14
        width: Math.min(parent.width - 44, toastText.implicitWidth + 32)
        height: 40
        radius: VbTokens.radiusPill
        // Token pill (elevated chip + accent edge) instead of grey-on-grey.
        color: VbTokens.surfaceOverlay
        border.color: VbTokens.accent
        border.width: 1
        visible: showToast
        opacity: showToast ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        Text {
            id: toastText
            text: toastMessage
            color: VbTokens.textPrimary
            font.family: VbTokens.fontBody
            font.pixelSize: 14
            anchors.centerIn: parent
        }
    }
    
    // Timer for auto-hiding toast
    Timer {
        id: toastTimer
        interval: 2000
        onTriggered: {
            showToast = false
        }
    }
    
    // Timer for delayed close
    Timer {
        id: closeTimer
        interval: 1000
        onTriggered: {
            closeMenu()
        }
    }

    // ServerCommandManager connection
    Connections {
        target: quickMenuManager.serverCommandManager
        function onCommandsRefreshed() {
            console.log("Server commands refreshed, updating model...");
            serverCommandsModel.clear();
            var commandIds = quickMenuManager.serverCommandManager.getAvailableCommands();
            for (var i = 0; i < commandIds.length; i++) {
                var commandId = commandIds[i];
                // VbSheetIcon kinds (line glyphs), not emoji.
                var icon = "terminal"; // Default
                if (commandId.toLowerCase() === "shutdown") {
                    icon = "power";
                } else if (commandId.toLowerCase() === "restart") {
                    icon = "restart";
                }
                serverCommandsModel.append({
                    icon: icon,
                    text: quickMenuManager.serverCommandManager.getCommandName(commandId),
                    action: commandId, // Use command ID as the action
                    description: quickMenuManager.serverCommandManager.getCommandDescription(commandId)
                });
            }
            console.log("Server commands model updated with", serverCommandsModel.count, "commands");
        }
        function onCommandExecuted(commandId, success, result) {
            showActionFeedback(success ? "Command '" + commandId + "' executed successfully" : "Command '" + commandId + "' failed: " + result);
        }
    }
    
    // Main menu model
    ListModel {
        id: mainMenuModel
        // `icon` values are VbSheetIcon kinds (monochrome line glyphs), not emoji.
        ListElement {
            text: qsTr("Disconnect")
            icon: "disconnect"
            action: "disconnect"
            description: qsTr("End the stream — game keeps running on the host")
        }
        ListElement {
            // Quits the game on the HOST and returns to the Vibemis grid
            // (no longer exits the whole app — start another session right away).
            text: qsTr("Quit game")
            icon: "power"
            action: "quit"
            description: qsTr("Quit the game on the host and return to Vibemis")
        }
        ListElement {
            text: qsTr("Server commands")
            icon: "terminal"
            action: "server_commands"
            description: qsTr("Access server control commands")
        }
        ListElement {
            text: qsTr("Upload clipboard")
            icon: "clipboard-up"
            action: "clipboard_upload"
            description: qsTr("Upload clipboard to server")
        }
        ListElement {
            text: qsTr("Fetch clipboard")
            icon: "clipboard-down"
            action: "clipboard_fetch"
            description: qsTr("Fetch clipboard from server")
        }
        ListElement {
            // Same target as the overlay's KBD button — the SteamOS OSK
            // types straight into the stream, unlike the buffered text-send view.
            text: qsTr("On-screen keyboard")
            icon: "keyboard"
            action: "open_steam_keyboard"
            description: qsTr("Open the SteamOS on-screen keyboard")
        }
        ListElement {
            text: qsTr("Type text")
            icon: "keyboard"
            action: "type_text"
            description: qsTr("Send typed text to the host")
        }
        ListElement {
            text: qsTr("Paste clipboard text")
            icon: "clipboard"
            action: "paste_clipboard"
            description: qsTr("Type clipboard text into the host")
        }
        ListElement {
            text: qsTr("Stream info")
            icon: "details"
            action: "stream_info"
            description: qsTr("Show current resolution, FPS, bitrate and codec")
        }
        ListElement {
            text: qsTr("Performance stats")
            icon: "stats"
            action: "toggle_stats"
            description: qsTr("Show/hide performance statistics")
        }
        ListElement {
            text: qsTr("Mouse capture")
            icon: "mouse"
            action: "toggle_mouse"
            description: qsTr("Toggle mouse capture mode")
        }
        ListElement {
            text: qsTr("Keyboard capture")
            icon: "keyboard"
            action: "toggle_keyboard"
            description: qsTr("Toggle keyboard capture mode")
        }
        ListElement {
            text: qsTr("Fullscreen")
            icon: "fullscreen"
            action: "toggle_fullscreen"
            description: qsTr("Toggle fullscreen mode")
        }
        ListElement {
            text: qsTr("Touch overlay")
            icon: "touch"
            action: "toggle_touch_overlay"
            description: qsTr("Show/hide the on-screen MENU / KBD / touch-mode buttons")
        }
        ListElement {
            text: qsTr("Send Ctrl+Alt+Del")
            icon: "key"
            action: "key_ctrl_alt_del"
            description: qsTr("Send Ctrl+Alt+Del to the host")
        }
        ListElement {
            text: qsTr("Send Alt+F4")
            icon: "key"
            action: "key_alt_f4"
            description: qsTr("Close the focused window on the host")
        }
        ListElement {
            text: qsTr("Send Super (Win) key")
            icon: "key"
            action: "key_super"
            description: qsTr("Open the host start menu / launcher")
        }
        ListElement {
            text: qsTr("Send Esc")
            icon: "key"
            action: "key_esc"
            description: qsTr("Send the Escape key to the host")
        }
        ListElement {
            text: qsTr("Send Alt+Tab")
            icon: "key"
            action: "key_alt_tab"
            description: qsTr("Switch windows on the host")
        }
    }
    
    // Ship the field contents to the host and return to the main menu.
    function sendTypedText() {
        if (typeof quickMenuManager === 'undefined') return
        if (sendTextField.text.length > 0) {
            quickMenuManager.sendText(sendTextField.text)
            sendTextField.text = ""
        }
        quickMenuManager.setTextInputActive(false)
        currentMenu = "main"
    }

    Timer {
        id: sendTextFocusTimer
        interval: 50
        onTriggered: sendTextField.forceActiveFocus()
    }

    function closeMenuDelayed() {
        closeTimer.restart();
    }

    // Functions
    function closeMenu() {
        // Only call backend hide - don't set QML invisible
            if (typeof quickMenuManager !== 'undefined') {
                quickMenuManager.setTextInputActive(false)   // leave text mode
                showActionFeedback("Closing menu...")  // Feedback when closing
            quickMenuManager.hide();
        }
    }
    
    function executeCurrentItem() {
        var currentItem = menuListView.model.get(menuListView.currentIndex)
        if (currentItem) {
            executeAction(currentItem.action)
        }
    }
    
    function executeAction(action) {
        console.log("Executing action:", action)

        // Activation blip — single funnel for injected A/Enter
        // (executeCurrentItem) and mouse/touch row clicks alike
        UiSoundManager.activated()

        // Handle navigation actions
        if (action === "type_text") {
            currentMenu = "text_send"
            // Focus the field so injected text lands in it (deferred so it exists).
            sendTextFocusTimer.restart()
            return;
        }
        if (action === "server_commands") {
            if (quickMenuManager.serverCommandManager && quickMenuManager.serverCommandManager.hasPermission) {
                currentMenu = "server_commands";
            } else {
                showActionFeedback("Server commands not available or no permission");
                closeMenuDelayed();
            }
            return;
        } else { // It might be a server command
            for (var i = 0; i < serverCommandsModel.count; i++) {
                if (serverCommandsModel.get(i).action === action) {
                    if (quickMenuManager.serverCommandManager) {
                        quickMenuManager.serverCommandManager.executeCommand(action);
                        closeMenuDelayed();
                    }
                    return;
                }
            }
        }
        
        // Show action feedback
        showActionFeedback(action)
        
        // Call the backend manager to execute the action
        if (typeof quickMenuManager !== 'undefined') {
            quickMenuManager.executeAction(action)
        }
        
        // Close menu after action (except for navigation)
        closeMenuDelayed();
    }
    
    function showActionFeedback(action) {
        var message = ""
        switch(action) {
            case "disconnect":
                message = "Disconnecting from server..."
                break
            case "quit":
                message = "Quitting session..."
                break
            case "server_restart":
                message = quickMenuManager.hasServerCommands ? "Restarting server..." : "Server commands not available"
                break
            case "server_shutdown":
                message = quickMenuManager.hasServerCommands ? "Shutting down server..." : "Server commands not available"
                break
            case "server_suspend":
                message = quickMenuManager.hasServerCommands ? "Suspending server..." : "Server commands not available"
                break
            case "clipboard_upload":
                message = "Uploading clipboard to server..."
                break
            case "clipboard_fetch":
                message = "Fetching clipboard from server..."
                break
            case "toggle_stats":
                message = "Toggling performance stats..."
                break
            case "toggle_mouse":
                message = "Toggling mouse capture..."
                break
            case "toggle_keyboard":
                message = "Toggling keyboard capture..."
                break
            case "toggle_fullscreen":
                message = "Toggling fullscreen..."
                break
            case "toggle_touch_overlay":
                message = "Toggling touch overlay..."
                break
            case "open_steam_keyboard":
                message = "Opening Steam keyboard..."
                break
            default:
                message = "Executing action..."
        }
        
        if (message) {
            toastMessage = message
            showToast = true
            toastTimer.restart()
        }
    }

    // Show an arbitrary toast string (called from C++ QuickMenuManager::showToast).
    function showToastMessage(message) {
        if (message) {
            toastMessage = message
            showToast = true
            toastTimer.restart()
        }
    }

    // Make menu focusable and reset state
    Component.onCompleted: {
        focus = true
        currentMenu = "main"  // Always start with main menu

        if (quickMenuManager.serverCommandManager) {
            console.log("QuickMenu: Refreshing server commands on open");
            quickMenuManager.serverCommandManager.refreshCommands();
        }
    }
}

