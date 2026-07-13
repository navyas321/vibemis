import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.2
import ServerCommandManager 1.0

Rectangle {
    id: quickMenu
    // Fixed size for the menu - small and centered
    width: 500
    height: 400
    // Don't use anchors with SizeViewToRootObject - position manually
    color: "#2d2d2d"
    radius: 10
    border.color: "#444"
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
            // test77: from a submenu, Esc/B/Back returns to the main menu (matching the
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
        anchors.margins: 20
        spacing: 15

        // Title
        Text {
            text: currentMenu === "text_send" ? qsTr("Send Text to Host")
                  : (currentMenu === "main" ? qsTr("Quick Menu") : qsTr("Server Commands"))
            font.pointSize: 24
            font.bold: true
            color: "#00cccc"
            Layout.alignment: Qt.AlignHCenter
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
                width: menuListView.width
                height: 60
                flat: true

                // Highlight the keyboard/gamepad-selected row, not just mouse hover, so
                // controller navigation is visible in Game Mode.
                highlighted: ListView.isCurrentItem

                background: Rectangle {
                    color: parent.down ? "#333"
                                       : ((parent.hovered || parent.highlighted) ? "#444" : "transparent")
                    border.color: (parent.hovered || parent.highlighted) ? "#00cccc" : "transparent"
                    border.width: 2
                    radius: 5
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
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    spacing: 14

                    Text {
                        text: model.icon
                        font.pointSize: 20
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        Layout.preferredWidth: 40
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            text: model.text
                            font.pointSize: 14
                            font.bold: true
                            color: "white"
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: model.description
                            font.pointSize: 10
                            color: "#cccccc"
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // P3.20 (test86): on-screen text-send view. A focused TextField receives typed
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
                color: "white"
                font.pointSize: 14
                selectByMouse: true
                background: Rectangle {
                    color: "#1e1e1e"
                    border.color: sendTextField.activeFocus ? "#00cccc" : "#444"
                    border.width: 2
                    radius: 5
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
                text: qsTr("Enter sends • Esc returns to the menu")
                font.pointSize: 9
                color: "#999999"
                Layout.alignment: Qt.AlignHCenter
            }

            Item { Layout.fillHeight: true }
        }

        // Divider so the footer hint reads as a separate bar below the scrolling menu
        // list rather than sitting on top of the last row.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#444"
        }

        // Back/Close button. test77: name the action ("Resume Game") and show the GAMEPAD
        // buttons that trigger it — the old "Close (Esc)" keyboard-only hint left
        // controller users with no discoverable way back to the game.
        // Bug fix: pinned as a full-width footer bar (was a centered auto-width button that
        // the overflowing, unclipped list painted over). It now always sits below the list.
        Button {
            text: currentMenu === "main" ? qsTr("Resume Game (Ⓑ / Back / Esc)") : qsTr("← Back (Ⓑ)")
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignHCenter
            onClicked: {
                if (currentMenu === "main") {
                    closeMenu()
                } else {
                    currentMenu = "main"
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
        anchors.topMargin: 12
        width: Math.min(parent.width - 40, toastText.implicitWidth + 20)
        height: 40
        radius: 20
        color: "#333"
        border.color: "#666"
        border.width: 1
        visible: showToast
        opacity: showToast ? 1.0 : 0.0
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
        
        Text {
            id: toastText
            text: toastMessage
            color: "white"
            font.pointSize: 12
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
                var icon = "⚙️"; // Default
                if (commandId.toLowerCase() === "shutdown") {
                    icon = "⏻";
                } else if (commandId.toLowerCase() === "restart") {
                    icon = "🔄";
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
        ListElement {
            text: qsTr("Disconnect")
            icon: "⏹"
            action: "disconnect"
            description: qsTr("Disconnect from server")
        }
        ListElement {
            text: qsTr("Quit")
            icon: "❌"
            action: "quit"
            description: qsTr("Quit streaming session")
        }
        ListElement {
            text: qsTr("Server Commands")
            icon: "⚙"
            action: "server_commands"
            description: qsTr("Access server control commands")
        }
        ListElement {
            text: qsTr("Clipboard Upload")
            icon: "📋"
            action: "clipboard_upload"
            description: qsTr("Upload clipboard to server")
        }
        ListElement {
            text: qsTr("Fetch Clipboard")
            icon: "📥"
            action: "clipboard_fetch"
            description: qsTr("Fetch clipboard from server")
        }
        ListElement {
            text: qsTr("Type Text")
            icon: "⌨"
            action: "type_text"
            description: qsTr("Send typed text to the host")
        }
        ListElement {
            text: qsTr("Paste Clipboard Text")
            icon: "📋"
            action: "paste_clipboard"
            description: qsTr("Type clipboard text into the host")
        }
        ListElement {
            text: qsTr("Stream Info")
            icon: "ℹ"
            action: "stream_info"
            description: qsTr("Show current resolution, FPS, bitrate and codec")
        }
        ListElement {
            text: qsTr("Toggle Performance Stats")
            icon: "📊"
            action: "toggle_stats"
            description: qsTr("Show/hide performance statistics")
        }
        ListElement {
            text: qsTr("Toggle Mouse Capture")
            icon: "🖱"
            action: "toggle_mouse"
            description: qsTr("Toggle mouse capture mode")
        }
        ListElement {
            text: qsTr("Toggle Keyboard Capture")
            icon: "⌨"
            action: "toggle_keyboard"
            description: qsTr("Toggle keyboard capture mode")
        }
        ListElement {
            text: qsTr("Toggle Fullscreen")
            icon: "🖥"
            action: "toggle_fullscreen"
            description: qsTr("Toggle fullscreen mode")
        }
        ListElement {
            text: qsTr("Toggle Touch Overlay")
            icon: "👆"
            action: "toggle_touch_overlay"
            description: qsTr("Show/hide the on-screen MENU / KBD touch buttons")
        }
        ListElement {
            text: qsTr("Send Ctrl+Alt+Del")
            icon: "⌨"
            action: "key_ctrl_alt_del"
            description: qsTr("Send Ctrl+Alt+Del to the host")
        }
        ListElement {
            text: qsTr("Send Alt+F4")
            icon: "✖"
            action: "key_alt_f4"
            description: qsTr("Close the focused window on the host")
        }
        ListElement {
            text: qsTr("Send Super (Win) key")
            icon: "⊞"
            action: "key_super"
            description: qsTr("Open the host start menu / launcher")
        }
        ListElement {
            text: qsTr("Send Esc")
            icon: "⎋"
            action: "key_esc"
            description: qsTr("Send the Escape key to the host")
        }
    }
    
    // P3.20 (test86): ship the field contents to the host and return to the main menu.
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
                quickMenuManager.setTextInputActive(false)   // P3.20: leave text mode
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

