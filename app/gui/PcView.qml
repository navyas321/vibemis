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

    // Freeze repro hardening: when focus enters the grid from the global toolbar
    // (touch the Refresh icon, then press Down), land on a REAL host delegate so the d-pad
    // drives the cards immediately. The repro was "toolbar d-pad works, but the
    // moment focus reaches the cards d-pad stops" — with currentIndex still -1 the GridView had
    // no current item to move from. count>0 excludes the ghost "Add a computer" cell.
    //
    // The ghost-selection reset lives here too (QML forbids a second onActiveFocusChanged — a duplicate handler
    // fails the WHOLE component at runtime, which shipped one beta as a blank home page):
    // losing focus also clears the ghost d-pad selection.
    onActiveFocusChanged: {
        if (activeFocus && currentIndex === -1 && count > 0) {
            currentIndex = 0
        }
        if (!activeFocus) {
            ghostSelected = false
        }
    }
    // Redesign: the grid content is inset so it clears the fixed per-screen header
    // (title + host count + icon buttons) and the bottom gamepad hint bar. See the chrome
    // block below. The global toolbar is collapsed for PcView in main.qml (redesignScreen).
    topMargin: pcChromeHeader.height + 12
    // When hosts don't fill a full row, CenteredGridView skips centering and falls
    // back to minMargin (default 10px) — cards hugged the screen edge, misaligned with the
    // 56px header and visually clipping the focus ring's outer glow. Align partial rows with
    // the redesign's screen padding instead.
    minMargin: VbTokens.screenPadX
    // The "Add a computer" ghost card is hand-placed at the index==count cell (see the delegate's
    // sibling below). GridView.contentHeight only counts real delegates, so when the last row is FULL
    // (count is a multiple of the column count) the ghost card starts a brand-new virtual row at
    // y==contentHeight and can't be scrolled into view. Reserve an extra row of bottom clearance in
    // that case so it's always reachable. (Code-review MED finding.)
    bottomMargin: (pcHintBar.visible ? pcHintBar.height : 0) + 12
                  + ((count > 0 && (count % Math.max(1, Math.floor(itemsPerRow))) === 0) ? cellHeight : 0)
    // Redesign: 430px rich host cards (gap 32) in a centered wrapping row.
    cellWidth: 462; cellHeight: 274;
    objectName: qsTr("Computers")

    // D-pad selection state for the Add-a-computer ghost — WITHOUT focus. The
    // freeze RCA forbids focusing a non-delegate inside the GridView's focus scope,
    // so the grid keeps activeFocus + currentIndex and the ghost merely PAINTS selected;
    // Ⓐ/Return on the current delegate opens Add-PC while this is set. Cleared by any
    // Left/Up, index move, or focus loss.
    property bool ghostSelected: false
    function selectGhost() {
        ghostSelected = true
        // Reveal the ghost above the hint bar (it lives in contentItem space; only ever
        // scroll DOWN to expose it — with few hosts there is nothing to scroll).
        var hintClear = (pcHintBar.visible ? pcHintBar.height : 0) + 12
        var target = addPcCardSlot.y + addPcCardSlot.height + hintClear - pcGrid.height
        if (target > pcGrid.contentY) {
            pcGrid.contentY = target
        }
    }
    onCurrentIndexChanged: ghostSelected = false

    // ---- Redesign chrome: per-screen header + persistent gamepad hint bar ----
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

    // Redesign body section title: "Computers · N hosts · M online". The VIBEMIS wordmark +
    // Add/Refresh/Help/Settings buttons live in the ALWAYS-PRESENT global toolbar (main.qml) — kept
    // present at 84px so it renders under gamescope (a collapsed header black-screens on the WSI path).
    // So this is just the body section title below the toolbar; there is no double header.
    Item {
        id: pcChromeHeader
        z: 10
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: true
        height: 78

        Rectangle { anchors.fill: parent; color: VbTokens.bgWindow }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: VbTokens.screenPadX
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
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
                font.pixelSize: 18
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
        // Matches the design's hint bar exactly:
        // Ⓐ Connect · Ⓧ Host options · Ⓨ Add computer · (right) ☰ Settings. Ⓨ is wired to the
        // Add-PC dialog via Keys.onYPressed on the grid below; ☰/Start opens Settings.
        hints: [
            { glyph: "Ⓐ", label: qsTr("Connect") },
            { glyph: "Ⓧ", label: qsTr("Host options") },
            { glyph: "Ⓨ", label: qsTr("Add computer") }
        ]
        hintsRight: [ { glyph: "☰", label: qsTr("Settings") } ]
    }

    // Redesign: Ⓨ (mapped to Key_Yellow in sdlgamepadkeynavigation.cpp) opens the Add-PC dialog,
    // matching the "Ⓨ Add computer" hint. Keyboard 'A' also adds a computer as a convenience.
    Keys.onPressed: {
        if (event.key === Qt.Key_Yellow) {
            addPcDialog.open()
            event.accepted = true
        }
        // CRITICAL freeze RCA: the earlier "d-pad Right/Down jumps to the ghost card"
        // branch is GONE deliberately. Giving a non-delegate item focus inside the GridView's
        // focus scope started a focus war with the view's own focus management (170% CPU spin,
        // every input hijacked to Add-a-computer with a 1-host grid where currentIndex is always
        // count-1, gamepad dead / touch-only). Gamepad path for Add-PC is the designed Y button.
    }

    // Called by the global toolbar's Refresh button (main.qml) — re-poll for hosts.
    function refreshView() {
        ComputerManager.startPolling()
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

        // Give the GRID active focus on entry so d-pad / arrow keys drive the host cards
        // immediately. Without this, active focus can land on a header toolbar button (the
        // Settings gear), and arrow/d-pad keys never reach the grid — observed as "focus stuck
        // on the gear, DOWN doesn't move to the grid" (headless gamescope, where StackView's
        // implicit focus hand-off to the current item doesn't win over the header buttons).
        forceActiveFocus()
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
                var midx = computerModel.index(targetIndex, 0)
                var appView = component.createObject(stackView, {
                    "computerIndex": targetIndex,
                    "objectName": computerModel.data(midx, ComputerModel.NameRole) || "Computer",
                    // Pass the host status so the global toolbar's 1b header shows the right dot/badge/transport
                    // (code-review: fresh-pair path was missing these). ComputerModel roles.
                    "hostOnline": computerModel.data(midx, ComputerModel.OnlineRole) || false,
                    "hostType": computerModel.data(midx, ComputerModel.HostTypeRole) || "",
                    "hostTransport": computerModel.data(midx, ComputerModel.TransportRole) || ""
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
        id: pcDelegate
        width: 430; height: 242;
        grid: pcGrid

        // The Material style paints an always-visible
        // SQUARE-cornered surface behind every ItemDelegate — visible as a grey box
        // poking past the rounded card corners. The card supplies all visuals.
        background: null

        property alias pcContextMenu : pcContextMenuLoader.item

        // Instance-level nav overrides (these replace NavigableItemDelegate's
        // handlers) route the "can't move further" edge to the ghost card as a pure
        // SELECTION (pcGrid.ghostSelected) — focus and currentIndex never leave this
        // delegate, so the focus-war freeze class is impossible by construction.
        Keys.onRightPressed: {
            if (index === pcGrid.count - 1 && !pcGrid.ghostSelected) {
                pcGrid.selectGhost()
            }
            else if (!pcGrid.ghostSelected) {
                grid.moveCurrentIndexRight()
            }
        }
        Keys.onDownPressed: {
            var cols = Math.max(1, Math.floor(pcGrid.itemsPerRow))
            if (!pcGrid.ghostSelected &&
                    Math.floor(index / cols) === Math.floor((pcGrid.count - 1) / cols)) {
                // On the last delegate row: Down selects the ghost (it sits in the trailing
                // cell or starts the next virtual row — either way it is "below/after").
                pcGrid.selectGhost()
            }
            else if (!pcGrid.ghostSelected) {
                grid.moveCurrentIndexDown()
            }
        }
        Keys.onLeftPressed: {
            if (pcGrid.ghostSelected) {
                pcGrid.ghostSelected = false
            }
            else {
                grid.moveCurrentIndexLeft()
            }
        }
        Keys.onUpPressed: {
            if (pcGrid.ghostSelected) {
                pcGrid.ghostSelected = false
            }
            else {
                grid.moveCurrentIndexUp()

                // Launch blocker, on-device-validated RCA: at the top of the grid,
                // hop focus to the toolbar. The upstream one-liner
                // `nextItemInFocusChain(false).forceActiveFocus()` is structurally broken in
                // the redesign nesting — the delegate's chain-previous is the GRID itself
                // (its ancestor FocusScope), and focusing an ancestor just re-descends into
                // this same delegate (observed: focus never left the card). Walk the chain
                // PAST ancestors to the first real outside item (the toolbar buttons).
                if (grid.currentItem === pcDelegate) {
                    var prev = pcDelegate.nextItemInFocusChain(false)
                    var guard = 0
                    while (prev && guard++ < 8) {
                        var isAncestor = false
                        for (var p = pcDelegate.parent; p; p = p.parent) {
                            if (p === prev) { isAncestor = true; break }
                        }
                        if (!isAncestor) {
                            break
                        }
                        prev = prev.nextItemInFocusChain(false)
                    }
                    if (prev) {
                        prev.forceActiveFocus(Qt.TabFocus)
                    }
                }
            }
        }
        // The manual clicked() calls are REQUIRED (ItemDelegate has no
        // native Return/Enter activation — removing these bricked A on-device in
        // 0.2.0-alpha.001). The double-push symptom is fixed by the stackView.busy guard in
        // onClicked below, which turns any duplicate activation into a no-op.
        Keys.onReturnPressed: {
            if (pcGrid.ghostSelected) {
                addPcDialog.open()
            }
            else {
                clicked()
            }
        }
        Keys.onEnterPressed: {
            if (pcGrid.ghostSelected) {
                addPcDialog.open()
            }
            else {
                clicked()
            }
        }

        // Redesign: the rich host card. Model roles feed the pure-visual
        // VbHostCard; the pairing/wake/menu wiring below is unchanged. The CS_UNKNOWN state is shown by
        // the card's own neutral "CHECKING" pill (no separate teal spinner).
        VbHostCard {
            id: hostCard
            anchors.fill: parent
            hostName: model.name
            online: model.online
            paired: model.paired
            statusUnknown: model.statusUnknown
            // Exactly ONE selection ring at a time — the card yields its ring
            // while the ghost is d-pad-selected (focus stays here invisibly).
            focused: highlighted && !pcGrid.ghostSelected
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

        Loader {
            id: pcContextMenuLoader
            asynchronous: true
            // Redesign: the old right-click NavigableMenu is now a right-side action sheet
            // (VbHostSheet). Same actions + visibility rules, presented gamepad-first.
            sourceComponent: VbHostSheet {
                id: pcContextMenu
                initiator: pcContextMenuLoader.parent
                hostName: model.name
                online: model.online
                apolloHost: model.hostType !== "SUNSHINE"
                hostBadge: model.hostType
                subtitleLine: model.permissionSummary + (model.transport ? " · " + model.transport : "")
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
            // Idempotent activation — if the stack is already mid-push
            // (a duplicate clicked() from the same A press, or a double-tap), drop it.
            // THIS is the actual double-Back fix: one activation, one AppView, one Back.
            if (stackView.busy) {
                return
            }
            // While the ghost Add-PC card is selected, the Keys handler above owns
            // activation (it opened the dialog on key press) — swallow any click that still
            // reaches the delegate so it can't ALSO activate the card underneath. A stray
            // tap while ghost-selected just clears the selection (self-healing).
            if (pcGrid.ghostSelected) {
                pcGrid.ghostSelected = false
                return
            }
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
            // Redesign: the host-options sheet always slides in from the right edge
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

    // Redesign: "Add a computer" ghost card (3rd card slot).
    // NOTE on approach: GridView.footer was tried first but doesn't fit here — Qt always positions the
    // footer at lastPosition() (the last row's y plus one full row height), i.e. it starts a brand-new
    // row even when the last row still has empty cell slots, so it can never sit inline as "the next
    // card" the way the design shows. Instead this Item is parented straight into the grid's own
    // contentItem and manually placed at the "next" cell slot (index === pcGrid.count), using the same
    // col/row × cellWidth/cellHeight math GridView uses internally for its delegates. That makes it
    // render as a real trailing grid cell — inline right after the last host card, top-left aligned
    // within its 462×274 cell exactly like the delegate (430×242, same 32px gap) — and it scrolls with
    // the grid content automatically since it lives in contentItem's coordinate space.
    Item {
        id: addPcCardSlot
        parent: pcGrid.contentItem
        property int columns: Math.max(1, pcGrid.itemsPerRow)
        // Hover highlight + d-pad selection. This item stays
        // deliberately NON-FOCUSABLE — giving a non-delegate item focus inside the GridView's
        // focus scope caused a focus war with the view (CPU spin, every input hijacked,
        // gamepad dead). The d-pad path is a grid-owned SELECTION state instead: the ghost
        // paints selected (accent dashed stroke) while focus never leaves the delegates.
        // Ⓨ remains the shortcut; mouse/touch hover + click unchanged.
        property bool selected: pcGrid.ghostSelected
        property bool highlighted: addPcMouseArea.containsMouse || selected
        onSelectedChanged: addPcDashedBorder.requestPaint()
        x: (pcGrid.count % columns) * pcGrid.cellWidth
        y: Math.floor(pcGrid.count / columns) * pcGrid.cellHeight
        width: 430
        height: 242
        z: 2

        // Hover fill behind the dashed border (token-consistent with VbCard's focused fill).
        Rectangle {
            anchors.fill: parent
            radius: 20
            color: addPcCardSlot.highlighted ? VbTokens.bgElev : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Canvas {
            id: addPcDashedBorder
            anchors.fill: parent
            antialiasing: true
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                // Accent stroke while d-pad-selected, white-ish on hover, faint idle.
                ctx.strokeStyle = addPcCardSlot.selected ? String(VbTokens.accent)
                                : (addPcCardSlot.highlighted ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.14))
                ctx.lineWidth = addPcCardSlot.selected ? 3 : 2
                ctx.setLineDash([6, 6])
                var r = 20, w = width, h = height
                ctx.beginPath()
                ctx.moveTo(r, 1)
                ctx.arcTo(w - 1, 1, w - 1, h - 1, r)
                ctx.arcTo(w - 1, h - 1, 1, h - 1, r)
                ctx.arcTo(1, h - 1, 1, 1, r)
                ctx.arcTo(1, 1, w - 1, 1, r)
                ctx.closePath()
                ctx.stroke()
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 64
                height: 64
                radius: 32
                color: VbTokens.bgElev
                border.width: 1
                border.color: VbTokens.stroke

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    font.family: VbTokens.fontBody
                    font.pixelSize: 32
                    color: VbTokens.textDim
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Add a computer")
                font.family: VbTokens.fontBody
                font.pixelSize: 18
                color: VbTokens.textDim
            }
        }

        MouseArea {
            id: addPcMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: addPcDialog.open()
        }

        // Repaint the dashed border when the highlight state flips (Canvas doesn't auto-bind).
        onHighlightedChanged: addPcDashedBorder.requestPaint()
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
