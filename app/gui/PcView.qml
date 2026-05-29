import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

import ComputerModel 1.0

import ComputerManager 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0
import SdlGamepadKeyNavigation 1.0

CenteredGridView {
    property ComputerModel computerModel : createModel()

    id: pcGrid
    focus: true
    activeFocusOnTab: true
    topMargin: 20
    bottomMargin: 5
    cellWidth: 310; cellHeight: 330;
    objectName: qsTr("Computers")

    Component.onCompleted: {
        // Don't show any highlighted item until interacting with them.
        // We do this here instead of onActivated to avoid losing the user's
        // selection when backing out of a different page of the app.
        currentIndex = -1
    }

    // Note: Any initialization done here that is critical for streaming must
    // also be done in CliStartStreamSegue.qml, since this code does not run
    // for command-line initiated streams.
    StackView.onActivated: {
        // Setup signals on CM
        ComputerManager.computerAddCompleted.connect(addComplete)

        // Highlight the first item if a gamepad is connected
        if (currentIndex == -1 && SdlGamepadKeyNavigation.getConnectedGamepads() > 0) {
            currentIndex = 0
        }
    }

    StackView.onDeactivating: {
        ComputerManager.computerAddCompleted.disconnect(addComplete)
    }

    function pairingComplete(error)
    {
        console.log("PcView.pairingComplete called with error:", error)
        
        // Close all pairing dialogs
        pairDialog.close()
        otpPairDialog.close()
        otpProgressDialog.close()

        // Display a failed dialog if we got an error
        if (error !== undefined) {
            console.log("PcView: Showing error dialog:", error)
            errorDialog.text = error
            errorDialog.helpText = ""
            errorDialog.open()
        } else {
            console.log("PcView: Pairing successful, attempting navigation")
            
            // Successful pairing - navigate to AppView like Android does
            // Find the computer that was just paired (should now be paired)
            // Use OTP dialog's computer index if available, otherwise find first paired computer
            var targetIndex = otpPairDialog.computerIndex >= 0 ? otpPairDialog.computerIndex : -1
            
            console.log("PcView: Target index for navigation:", targetIndex)
            
            if (targetIndex >= 0) {
                console.log("PcView: Creating AppView for computer index:", targetIndex)
                
                // Navigate to the AppView for the newly paired computer
                var component = Qt.createComponent("AppView.qml")
                var appView = component.createObject(stackView, {
                    "computerIndex": targetIndex, 
                    "objectName": computerModel.data(computerModel.index(targetIndex, 0), ComputerModel.NameRole) || "Computer"
                })
                stackView.push(appView)
                
                console.log("PcView: Navigation completed")
            } else {
                console.log("PcView: No valid target index, cannot navigate")
            }
        }
    }

    function addComplete(success, detectedPortBlocking)
    {
        if (!success) {
            errorDialog.text = qsTr("Unable to connect to the specified PC.")

            if (detectedPortBlocking) {
                errorDialog.text += "\n\n" + qsTr("This PC's Internet connection is blocking Moonlight. Streaming over the Internet may not work while connected to this network.")
            }
            else {
                errorDialog.helpText = qsTr("Click the Help button for possible solutions.")
            }

            errorDialog.open()
        }
    }

    function createModel()
    {
        var model = Qt.createQmlObject('import ComputerModel 1.0; ComputerModel {}', parent, '')
        model.initialize(ComputerManager)
        model.pairingCompleted.connect(pairingComplete)
        model.connectionTestCompleted.connect(testConnectionDialog.connectionTestComplete)
        return model
    }

    Row {
        anchors.centerIn: parent
        spacing: 5
        visible: pcGrid.count === 0

        BusyIndicator {
            id: searchSpinner
            visible: StreamingPreferences.enableMdns
        }

        Label {
            height: searchSpinner.height
            elide: Label.ElideRight
            text: StreamingPreferences.enableMdns ? qsTr("Searching for compatible hosts on your local network...")
                                                  : qsTr("Automatic PC discovery is disabled. Add your PC manually.")
            font.pointSize: 20
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
        }
    }

    model: computerModel

    delegate: NavigableItemDelegate {
        width: 300; height: 320;
        grid: pcGrid

        property alias pcContextMenu : pcContextMenuLoader.item

        Image {
            id: pcIcon
            anchors.horizontalCenter: parent.horizontalCenter
            source: "qrc:/res/desktop_windows-48px.svg"
            sourceSize {
                width: 200
                height: 200
            }
        }

        Image {
            // TODO: Tooltip
            id: stateIcon
            anchors.horizontalCenter: pcIcon.horizontalCenter
            anchors.verticalCenter: pcIcon.verticalCenter
            anchors.verticalCenterOffset: !model.online ? -18 : -16
            visible: !model.statusUnknown && (!model.online || !model.paired)
            source: !model.online ? "qrc:/res/warning_FILL1_wght300_GRAD200_opsz24.svg" : "qrc:/res/baseline-lock-24px.svg"
            sourceSize {
                width: !model.online ? 75 : 70
                height: !model.online ? 75 : 70
            }
        }

        BusyIndicator {
            id: statusUnknownSpinner
            anchors.horizontalCenter: pcIcon.horizontalCenter
            anchors.verticalCenter: pcIcon.verticalCenter
            anchors.verticalCenterOffset: -15
            width: 75
            height: 75
            visible: model.statusUnknown
        }

        Label {
            id: pcNameText
            text: model.name

            width: parent.width
            anchors.top: pcIcon.bottom
            anchors.bottom: parent.bottom
            font.pointSize: 36
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            elide: Text.ElideRight
        }

        Loader {
            id: pcContextMenuLoader
            asynchronous: true
            sourceComponent: NavigableMenu {
                id: pcContextMenu
                initiator: pcContextMenuLoader.parent
                MenuItem {
                    text: qsTr("PC Status: %1").arg(model.online ? qsTr("Online") : qsTr("Offline"))
                    font.bold: true
                    enabled: false
                }
                NavigableMenuItem {
                    text: qsTr("View All Apps")
                    onTriggered: {
                        var component = Qt.createComponent("AppView.qml")
                        var appView = component.createObject(stackView, {"computerIndex": index, "objectName": model.name, "showHiddenGames": true})
                        stackView.push(appView)
                    }
                    visible: model.online && model.paired
                }
                NavigableMenuItem {
                    text: qsTr("Wake PC")
                    onTriggered: computerModel.wakeComputer(index)
                    visible: !model.online && model.wakeable
                }
                NavigableMenuItem {
                    text: qsTr("Pair")
                    onTriggered: {
                        // Use standard pairing for GeForce Experience
                        var pin = computerModel.generatePinString()
                        computerModel.pairComputer(index, pin)
                        pairDialog.pin = pin
                        pairDialog.open()
                    }
                    visible: model.online && !model.paired
                }
                NavigableMenuItem {
                    text: qsTr("Pair using OTP")
                    onTriggered: {
                        // Pairing starts in otpPairDialog.onOpened
                        otpPairDialog.computerIndex = index
                        otpPairDialog.open()
                    }
                    visible: model.online && !model.paired && model.isApolloServer
                }
                NavigableMenuItem {
                    text: qsTr("Test Network")
                    onTriggered: {
                        computerModel.testConnectionForComputer(index)
                        testConnectionDialog.open()
                    }
                }

                NavigableMenuItem {
                    text: qsTr("Rename PC")
                    onTriggered: {
                        renamePcDialog.pcIndex = index
                        renamePcDialog.originalName = model.name
                        renamePcDialog.open()
                    }
                }
                NavigableMenuItem {
                    text: qsTr("Delete PC")
                    onTriggered: {
                        deletePcDialog.pcIndex = index
                        deletePcDialog.pcName = model.name
                        deletePcDialog.open()
                    }
                }
                NavigableMenuItem {
                    text: qsTr("View Details")
                    onTriggered: {
                        showPcDetailsDialog.pcDetails = model.details
                        showPcDetailsDialog.open()
                    }
                }
            }
        }

        onClicked: {
            if (model.online) {
                if (!model.serverSupported) {
                    errorDialog.text = qsTr("The version of GeForce Experience on %1 is not supported by this build of Moonlight. You must update Moonlight to stream from %1.").arg(model.name)
                    errorDialog.helpText = ""
                    errorDialog.open()
                }
                else if (model.paired) {
                    // go to game view
                    var component = Qt.createComponent("AppView.qml")
                    var appView = component.createObject(stackView, {"computerIndex": index, "objectName": model.name})
                    stackView.push(appView)
                }
                else {
                    // OTP pairing for any non-GFE server (Vibepollo / Apollo / Sunshine).
                    // The dialog generates the PIN, starts the handshake immediately
                    // (via onOpened), then shows the PIN and instructions.
                    if (model.isApolloServer) {
                        otpPairDialog.computerIndex = index
                        otpPairDialog.open()
                        // pairing is started inside otpPairDialog.onOpened
                    } else {
                        // Default to standard PIN pairing on click
                        var pin = computerModel.generatePinString()

                        // Kick off pairing in the background
                        computerModel.pairComputer(index, pin)

                        // Display the pairing dialog
                        pairDialog.pin = pin
                        pairDialog.open()
                    }
                }
            } else if (!model.online) {
                // Using open() here because it may be activated by keyboard
                pcContextMenu.open()
            }
        }

        onPressAndHold: {
            // popup() ensures the menu appears under the mouse cursor
            if (pcContextMenu.popup) {
                pcContextMenu.popup()
            }
            else {
                // Qt 5.9 doesn't have popup()
                pcContextMenu.open()
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton;
            onClicked: {
                parent.pressAndHold()
            }
        }

        Keys.onMenuPressed: {
            // We must use open() here so the menu is positioned on
            // the ItemDelegate and not where the mouse cursor is
            pcContextMenu.open()
        }

        Keys.onDeletePressed: {
            deletePcDialog.pcIndex = index
            deletePcDialog.pcName = model.name
            deletePcDialog.open()
        }
    }

    ErrorMessageDialog {
        id: errorDialog

        // Using Setup-Guide here instead of Troubleshooting because it's likely that users
        // will arrive here by forgetting to enable GameStream or not forwarding ports.
        helpUrl: "https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide"
    }

    NavigableMessageDialog {
        id: pairDialog

        // Pairing dialog must be modal to prevent double-clicks from triggering
        // pairing twice
        modal: true
        closePolicy: Popup.CloseOnEscape

        // don't allow edits to the rest of the window while open
        property string pin : "0000"
        text:qsTr("Please enter %1 on your host PC. This dialog will close when pairing is completed.").arg(pin)+"\n\n"+
             qsTr("If your host PC is running Sunshine, navigate to the Sunshine web UI to enter the PIN.")
        standardButtons: Dialog.Cancel
        onRejected: {
            // FIXME: We should interrupt pairing here
        }
    }

    NavigableMessageDialog {
        id: deletePcDialog
        // don't allow edits to the rest of the window while open
        property int pcIndex : -1
        property string pcName : ""
        text: qsTr("Are you sure you want to remove '%1'?").arg(pcName)
        standardButtons: Dialog.Yes | Dialog.No

        onAccepted: {
            computerModel.deleteComputer(pcIndex)
        }
    }

    NavigableMessageDialog {
        id: testConnectionDialog
        closePolicy: Popup.CloseOnEscape
        standardButtons: Dialog.Ok

        onAboutToShow: {
            testConnectionDialog.text = qsTr("Moonlight is testing your network connection to determine if any required ports are blocked.") + "\n\n" + qsTr("This may take a few seconds…")
            showSpinner = true
        }

        function connectionTestComplete(result, blockedPorts)
        {
            if (result === -1) {
                text = qsTr("The network test could not be performed because none of Moonlight's connection testing servers were reachable from this PC. Check your Internet connection or try again later.")
                imageSrc = "qrc:/res/baseline-warning-24px.svg"
            }
            else if (result === 0) {
                text = qsTr("This network does not appear to be blocking Moonlight. If you still have trouble connecting, check your PC's firewall settings.") + "\n\n" + qsTr("If you are trying to stream over the Internet, install the Moonlight Internet Hosting Tool on your gaming PC and run the included Internet Streaming Tester to check your gaming PC's Internet connection.")
                imageSrc = "qrc:/res/baseline-check_circle_outline-24px.svg"
            }
            else {
                text = qsTr("Your PC's current network connection seems to be blocking Moonlight. Streaming over the Internet may not work while connected to this network.") + "\n\n" + qsTr("The following network ports were blocked:") + "\n"
                text += blockedPorts
                imageSrc = "qrc:/res/baseline-error_outline-24px.svg"
            }

            // Stop showing the spinner and show the image instead
            showSpinner = false
        }
    }

    NavigableDialog {
        id: renamePcDialog
        property string label: qsTr("Enter the new name for this PC:")
        property string originalName
        property int pcIndex : -1;

        standardButtons: Dialog.Ok | Dialog.Cancel

        onOpened: {
            // Force keyboard focus on the textbox so keyboard navigation works
            editText.forceActiveFocus()
        }

        onClosed: {
            editText.clear()
        }

        onAccepted: {
            if (editText.text) {
                computerModel.renameComputer(pcIndex, editText.text)
            }
        }

        ColumnLayout {
            Label {
                text: renamePcDialog.label
                font.bold: true
            }

            TextField {
                id: editText
                placeholderText: renamePcDialog.originalName
                Layout.fillWidth: true
                focus: true

                Keys.onReturnPressed: {
                    renamePcDialog.accept()
                }

                Keys.onEnterPressed: {
                    renamePcDialog.accept()
                }
            }
        }
    }

    NavigableDialog {
        id: showPcDetailsDialog
        property string pcDetails : "";
        title: qsTr("Computer Details")
        standardButtons: Dialog.Ok
        
        // Make the dialog larger
        implicitWidth: 600
        implicitHeight: 500
        
            ScrollView {
            id: detailsScrollView
            anchors.fill: parent
            anchors.margins: 8  // Slightly larger margin for better appearance
            clip: true
            
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AsNeeded
            
            // Ensure scrollbars stay within bounds
            ScrollBar.vertical.width: 12
            ScrollBar.horizontal.height: 12
            
            TextArea {
                id: detailsLabel
                text: showPcDetailsDialog.pcDetails
                wrapMode: Text.Wrap
                selectByMouse: true
                readOnly: true
                font.family: "SF Pro Display, Segoe UI, system-ui, Arial"
                font.pixelSize: 14  // Slightly larger for better readability
                font.weight: Font.Normal
                textFormat: Text.PlainText  // Use plain text to maintain transparent background
                
                // Use default text color for dark theme compatibility
                // Enhanced padding for better spacing
                padding: 20
                
                // Remove white border - use transparent background
                background: Rectangle {
                    color: "transparent"
                    border.width: 0
                }
                
                // Allow the text to expand naturally within the scroll area
                width: Math.max(detailsScrollView.availableWidth, implicitWidth)
                
                Keys.onReturnPressed: {
                    showPcDetailsDialog.accept()
                }

                Keys.onEnterPressed: {
                    showPcDetailsDialog.accept()
                }

                Keys.onEscapePressed: {
                    showPcDetailsDialog.reject()
                }
            }
        }
    }

    // Receive stage1Completed from ComputerManager (via ComputerModel) and
    // flip the dialog into "ready to continue" mode.
    Connections {
        target: computerModel
        function onOtpStage1Completed() {
            otpPairDialog.stage1Complete = true
        }
    }

    NavigableDialog {
        id: otpPairDialog
        property int computerIndex: -1
        property string computerName: computerIndex >= 0 ? (computerModel.data(computerModel.index(computerIndex, 0), ComputerModel.NameRole) || "") : ""
        property string generatedPin: ""
        // Two-stage pairing:
        //   Stage 1 (fires on open): client sends getservercert + otpauth hash.
        //                            Server replies paired=1 + plaincert.
        //   << USER gate >>          Dialog shows Continue button. User goes to
        //                            host web UI, enters PIN in "Pair Client"
        //                            form + device name, submits.
        //   Stage 2 (on Continue):   Client sends AES-encrypted challenge.
        //                            Server can now decrypt it because it knows
        //                            the PIN from the "Pair Client" submission.
        property bool stage1Complete: false

        title: qsTr("Pairing — %1").arg(otpPairDialog.computerName)
        standardButtons: Dialog.Cancel
        modal: true
        closePolicy: Popup.CloseOnEscape

        onOpened: {
            var n = Math.floor(Math.random() * 10000)
            generatedPin = ("000" + n).slice(-4)
            stage1Complete = false
            // Start stage 1: sends getservercert to host, triggers notification.
            computerModel.pairComputerWithOTP(computerIndex, generatedPin, "")
        }

        onRejected: {
            // FIXME: interrupt in-progress pairing if the API ever exposes it
        }

        ColumnLayout {
            width: parent.width
            spacing: 12

            // ── PIN display ──────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Label {
                    text: qsTr("Enter this PIN on your host PC:")
                    font.bold: true
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: pinLabel.implicitHeight + 16
                    color: "#1a1a2e"
                    radius: 6
                    border.color: "#00cccc"
                    border.width: 2

                    Label {
                        id: pinLabel
                        anchors.centerIn: parent
                        text: otpPairDialog.generatedPin
                        font.pointSize: 36
                        font.bold: true
                        font.letterSpacing: 12
                        color: "#00cccc"
                    }
                }
            }

            // ── Stage 1: waiting for host notification ───────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: !otpPairDialog.stage1Complete

                Label {
                    text: qsTr("Sending pairing request to host…")
                    font.bold: true
                    Layout.fillWidth: true
                }
                Label {
                    text: qsTr("1.  Wait for the \"Incoming Pairing Request\"\n    notification on %1.").arg(otpPairDialog.computerName)
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
                Label {
                    text: qsTr("2.  Click the notification → go to Vibepollo\n    web UI → \"Pair Client\" section.")
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
                Label {
                    text: qsTr("       PIN: %1\n       Device name: anything (e.g. LegionGo)").arg(otpPairDialog.generatedPin)
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.bold: true
                }
                Label {
                    text: qsTr("3.  Submit on the host, then click Continue ↓")
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
            }

            // ── Stage 2: Continue button (shown after host cert received) ────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: otpPairDialog.stage1Complete

                Label {
                    text: qsTr("✓  Host accepted the pairing request.")
                    color: "#00cc66"
                    font.bold: true
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
                Label {
                    text: qsTr("Enter PIN %1 in Vibepollo's \"Pair Client\" form\n(if you haven't already), then click Continue.").arg(otpPairDialog.generatedPin)
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }

                Button {
                    text: qsTr("Continue — I've entered the PIN on the host")
                    Layout.fillWidth: true
                    onClicked: {
                        computerModel.resumeOTPPairing()
                    }
                }
            }

            Label {
                text: otpPairDialog.stage1Complete
                    ? qsTr("Click Continue once you have submitted the PIN on the host.")
                    : qsTr("This dialog will close automatically when pairing completes.")
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: "#aaaaaa"
                font.pointSize: 9
            }
        }
    }
    
    NavigableMessageDialog {
        id: otpProgressDialog
        title: qsTr("OTP Pairing in Progress")
        text: qsTr("Pairing with Apollo server...\n\nThis may take a few seconds.")
        standardButtons: Dialog.NoButton
        modal: true
        closePolicy: Popup.NoAutoClose
        showSpinner: true
        
        // The dialog will be closed automatically when pairing completes
        // via the pairingComplete() function
    }

    ScrollBar.vertical: ScrollBar {}
}
