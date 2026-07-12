import QtQuick 2.9
import QtQuick.Controls 2.2
import Theme 1.0
import QtQuick.Layouts 1.3

import ComputerModel 1.0
import Vibemis.Redesign 1.0

import ComputerManager 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0
import SdlGamepadKeyNavigation 1.0

CenteredGridView {
    property ComputerModel computerModel : createModel()

    id: pcGrid
    focus: true
    activeFocusOnTab: true
    // Redesign 1a: the grid content is inset so it clears the fixed per-screen header
    // (title + host count + icon buttons) and the bottom gamepad hint bar. See the chrome
    // block below. The global toolbar is collapsed for PcView in main.qml (redesignScreen).
    topMargin: pcChromeHeader.height + 12
    bottomMargin: (pcHintBar.visible ? pcHintBar.height : 0) + 12
    // Redesign 1a: 430px rich host cards (gap 32) in a centered wrapping row.
    cellWidth: 462; cellHeight: 182;
    objectName: qsTr("Computers")

    // ---- Redesign 1a chrome: per-screen header + persistent gamepad hint bar ----
    // Live "N hosts · M online" count. QML can't bind an aggregate over model rows, so
    // onlineRev bumps on any model change to force the count to re-compute.
    property int onlineRev: 0
    function onlineHostCount() {
        onlineRev; // re-eval dependency
        var n = 0
        for (var i = 0; i < pcGrid.count; i++) {
            if (computerModel.data(computerModel.index(i, 0), ComputerModel.OnlineRole))
                n++
        }
        return n
    }
    Connections {
        target: computerModel
        function onDataChanged() { pcGrid.onlineRev++ }
        function onRowsInserted() { pcGrid.onlineRev++ }
        function onRowsRemoved() { pcGrid.onlineRev++ }
        function onModelReset() { pcGrid.onlineRev++ }
    }

    // Token-styled icon button used in the header (Add / Help / Settings). Reuses the SVGs
    // and the exact onClicked handlers of the old global toolbar so behaviour is unchanged.
    component PcIconButton: Button {
        id: pib
        property string glyphSource: ""
        implicitWidth: VbTokens.iconButton
        implicitHeight: VbTokens.iconButton
        focusPolicy: Qt.TabFocus
        padding: 0
        background: Rectangle {
            radius: VbTokens.radiusIconButton
            color: pib.activeFocus ? VbTokens.focusedFill : (pib.hovered ? VbTokens.bgElev2 : VbTokens.bgElev)
            border.width: 1
            border.color: pib.activeFocus ? VbTokens.accent : VbTokens.stroke
        }
        contentItem: Image {
            source: pib.glyphSource
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 22
            sourceSize.height: 22
        }
    }

    // Fixed per-screen header (does not scroll with the grid). Opaque bg so scrolled cards
    // pass behind it. Height ~ headerH * 1.4 to fit the two-line title + count block.
    // Redesign 1a header (previews/1a-computers.png): row 1 = VIBEMIS wordmark (left) + 52px icon
    // buttons (Add / Refresh / Help / Settings) right; row 2 = "Computers" + live "N hosts · M online".
    // The global toolbar is collapsed for the redesign screens in main.qml, so this is the only header
    // (no double). Opaque bg so scrolled cards pass behind it.
    Item {
        id: pcChromeHeader
        z: 10
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: true
        height: 134

        Rectangle { anchors.fill: parent; color: VbTokens.bgWindow }

        // ---- Row 1: wordmark + icon buttons ----
        Item {
            id: headerTopRow
            anchors.top: parent.top
            anchors.topMargin: 22
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: VbTokens.screenPadX
            anchors.rightMargin: VbTokens.screenPadX
            height: VbTokens.iconButton

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 11
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    source: "qrc:/res/vibemis-mark-128.png"
                    sourceSize.width: 26; sourceSize.height: 26
                    fillMode: Image.PreserveAspectFit
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "VIBEMIS"
                    font.family: VbTokens.fontDisplay
                    font.weight: Font.Bold
                    font.pixelSize: VbTokens.sizeWordmark
                    font.letterSpacing: 2
                    color: VbTokens.text
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                PcIconButton {
                    glyphSource: "qrc:/res/ic_add_to_queue_white_48px.svg"
                    onClicked: addPcDialog.open()
                    ToolTip.text: qsTr("Add PC manually"); ToolTip.delay: 1000; ToolTip.visible: hovered
                }
                PcIconButton {
                    glyphSource: "qrc:/res/refresh.svg"
                    onClicked: ComputerManager.startPolling()
                    ToolTip.text: qsTr("Refresh"); ToolTip.delay: 1000; ToolTip.visible: hovered
                }
                PcIconButton {
                    visible: SystemProperties.hasBrowser
                    glyphSource: "qrc:/res/question_mark.svg"
                    onClicked: {
                        var comp = Qt.createComponent("qrc:/gui/VbHelpView.qml")
                        if (comp.status === Component.Ready) {
                            stackView.push(comp)
                        } else {
                            Qt.openUrlExternally("https://github.com/navyas321/vibemis")
                        }
                    }
                    ToolTip.text: qsTr("Help"); ToolTip.delay: 1000; ToolTip.visible: hovered
                }
                PcIconButton {
                    glyphSource: "qrc:/res/settings.svg"
                    onClicked: navigateTo("qrc:/gui/SettingsView.qml", "SettingsView")
                    ToolTip.text: qsTr("Settings"); ToolTip.delay: 1000; ToolTip.visible: hovered
                }
            }
        }

        // ---- Row 2: section title + live host count ----
        Row {
            anchors.top: headerTopRow.bottom
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.leftMargin: VbTokens.screenPadX
            spacing: 14
            Text {
                id: sectionTitle
                text: qsTr("Computers")
                font.family: VbTokens.fontDisplay
                font.weight: Font.Bold
                font.pixelSize: VbTokens.sizeScreenTitle
                color: VbTokens.text
            }
            Text {
                anchors.baseline: sectionTitle.baseline
                text: pcGrid.count + " " + (pcGrid.count === 1 ? qsTr("host") : qsTr("hosts")) +
                      " · " + pcGrid.onlineHostCount() + " " + qsTr("online")
                font.family: VbTokens.fontBody
                font.pixelSize: VbTokens.sizeLabel
                color: VbTokens.textDim
            }
        }
    }

    // Persistent gamepad hint bar, fixed at the bottom. Grid bottomMargin clears it.
    VbHintBar {
        id: pcHintBar
        z: 10
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        // Hints reflect the ACTUAL launcher gamepad map (sdlgamepadkeynavigation.cpp,
        // swapFaceButtons off): A=Return(connect), X=Menu(host options), Start(☰)=Hangup(settings).
        // Add-computer has no button shortcut — the focusable "+" tile self-documents — so it is not
        // listed here (previously mis-labelled as Ⓨ, which actually maps to Settings). See BL-1594.
        hints: [
            { glyph: "Ⓐ", label: qsTr("Connect") },
            { glyph: "Ⓧ", label: qsTr("Host options") }
        ]
        hintsRight: [ { glyph: "☰", label: qsTr("Settings") } ]
    }

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
        width: 430; height: 150;
        grid: pcGrid

        property alias pcContextMenu : pcContextMenuLoader.item

        // Redesign 1a: the rich host card (previews/1a-computers.png). Model roles feed the pure-visual
        // VbHostCard; the pairing/wake/menu wiring below is unchanged. A busy spinner overlays while the
        // host state is still unknown (mirrors the old delegate's BusyIndicator).
        VbHostCard {
            id: hostCard
            anchors.fill: parent
            hostName: model.name
            online: model.online
            paired: model.paired
            statusUnknown: model.statusUnknown
            focused: highlighted
            // Access line: paired hosts show their permission summary (Apollo grants "Full access" to
            // the first client, view/input-only to later ones); unpaired hosts prompt to pair.
            accessText: model.paired
                        ? (model.permissionSummary && model.permissionSummary !== ""
                           ? qsTr("Paired · ") + model.permissionSummary
                           : qsTr("Paired"))
                        : (model.online ? qsTr("Tap to pair") : "")
            hostBadge: model.hostType
            badgeAccent: model.hostType !== "SUNSHINE"
            // Online → "4 ms · LAN" (latency + transport); offline → "Last seen …".
            metaText: model.online
                      ? (model.latencyText !== "" ? model.latencyText + " · " + model.transport : model.transport)
                      : (model.lastSeenText !== "" ? qsTr("Last seen ") + model.lastSeenText : "")
        }

        BusyIndicator {
            id: statusUnknownSpinner
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.top: parent.top
            anchors.topMargin: 16
            width: 28
            height: 28
            visible: model.statusUnknown
        }

        Loader {
            id: pcContextMenuLoader
            asynchronous: true
            // Redesign 1d: the old right-click NavigableMenu is now a right-side action sheet
            // (VbHostSheet). Same actions + visibility rules, presented gamepad-first.
            sourceComponent: VbHostSheet {
                id: pcContextMenu
                initiator: pcContextMenuLoader.parent
                hostName: model.name
                online: model.online
                apolloHost: model.isApolloServer
                hostBadge: model.isApolloServer ? qsTr("APOLLO") : qsTr("SUNSHINE")
                subtitleLine: model.permissionSummary
                actions: [
                    {
                        label: qsTr("View all apps"), icon: "apps",
                        visible: model.online && model.paired,
                        trigger: function() {
                            var component = Qt.createComponent("AppView.qml")
                            var appView = component.createObject(stackView, {"computerIndex": index, "objectName": model.name, "showHiddenGames": true, "hostOnline": model.online, "hostType": model.hostType, "hostTransport": model.transport})
                            stackView.push(appView)
                        }
                    },
                    {
                        label: qsTr("Wake PC"), icon: "wake",
                        visible: !model.online && model.wakeable,
                        trigger: function() { computerModel.wakeComputer(index) }
                    },
                    {
                        label: qsTr("Pair"), icon: "pair",
                        visible: model.online && !model.paired,
                        trigger: function() {
                            // Use standard pairing for GeForce Experience
                            var pin = computerModel.generatePinString()
                            computerModel.pairComputer(index, pin)
                            pairDialog.pin = pin
                            pairDialog.open()
                        }
                    },
                    {
                        label: qsTr("Pair using OTP"), icon: "pair",
                        visible: model.online && !model.paired && model.isApolloServer,
                        trigger: function() {
                            // Pairing starts in otpPairDialog.onOpened
                            otpPairDialog.computerIndex = index
                            otpPairDialog.open()
                        }
                    },
                    {
                        label: qsTr("Test network"), icon: "network",
                        visible: true,
                        trigger: function() {
                            computerModel.testConnectionForComputer(index)
                            testConnectionDialog.open()
                        }
                    },
                    {
                        label: qsTr("Rename"), icon: "rename",
                        visible: true,
                        trigger: function() {
                            renamePcDialog.pcIndex = index
                            renamePcDialog.originalName = model.name
                            renamePcDialog.open()
                        }
                    },
                    {
                        label: qsTr("View details & permissions"), icon: "details",
                        visible: true,
                        trigger: function() {
                            showPcDetailsDialog.pcDetails = model.details
                            showPcDetailsDialog.open()
                        }
                    },
                    {
                        label: qsTr("Delete PC"), icon: "delete", danger: true,
                        visible: true,
                        trigger: function() {
                            deletePcDialog.pcIndex = index
                            deletePcDialog.pcName = model.name
                            deletePcDialog.open()
                        }
                    }
                ]
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
                    var appView = component.createObject(stackView, {"computerIndex": index, "objectName": model.name, "hostOnline": model.online, "hostType": model.hostType, "hostTransport": model.transport})
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
            // Redesign 1d: the host-options sheet always slides in from the right edge
            // (not positioned under the cursor like the old context menu).
            pcContextMenu.open()
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
        // Pairing flow (standard Moonlight, no otpauth extension):
        //   1. Dialog opens → client sends getservercert with a 2-minute timeout.
        //      Vibepollo holds the HTTP connection open until the user submits the
        //      "Pair Client" web form with the PIN (same mechanism as Sunshine).
        //   2. User enters PIN + device name in Vibepollo's web UI → submits.
        //      Vibepollo stores the cipher key and unblocks the HTTP response.
        //   3. Client receives paired=1+plaincert → fires phases 2-4 immediately.
        //      Vibepollo already has the cipher key → challenge succeeds.
        //   4. Dialog closes automatically when pairing completes.

        title: qsTr("Pairing — %1").arg(otpPairDialog.computerName)
        standardButtons: Dialog.Cancel
        modal: true
        closePolicy: Popup.CloseOnEscape

        onOpened: {
            var n = Math.floor(Math.random() * 10000)
            generatedPin = ("000" + n).slice(-4)
            // Send getservercert — Vibepollo holds the connection open until the
            // user submits the "Pair Client" form. Phases 2-4 fire automatically.
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
                    color: Theme.surface
                    radius: 6
                    border.color: Theme.accent
                    border.width: 2

                    Label {
                        id: pinLabel
                        anchors.centerIn: parent
                        text: otpPairDialog.generatedPin
                        font.pointSize: 36
                        font.bold: true
                        font.letterSpacing: 12
                        color: Theme.accent
                    }
                }
            }

            // ── Instructions ─────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Label {
                    text: qsTr("Steps:")
                    font.bold: true
                }
                Label {
                    text: qsTr("1.  On %1 — click the\n    \"Incoming Pairing Request\" notification.").arg(otpPairDialog.computerName)
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
                Label {
                    text: qsTr("2.  In Vibepollo web UI → \"Pair Client\" section:")
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
                Label {
                    text: qsTr("       PIN: %1\n       Device name: anything (e.g. LegionGo)\n       Click Submit").arg(otpPairDialog.generatedPin)
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.bold: true
                }
                Label {
                    text: qsTr("3.  This dialog closes automatically.")
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
            }

            Label {
                text: qsTr("Waiting for PIN entry on host… (up to 2 minutes)")
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.textTertiary
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
