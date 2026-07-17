import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.2

import ServerCommandManager 1.0
import Vibemis.Redesign 1.0

// test133 quick-menu (docs/design/specs/quick-menu.md): migrated onto the Vibemis token system
// to match the Quick Menu / redesigned surfaces — no hardcoded hex/color names, type on the scale,
// VbSheetIcon glyphs, status tokens for feedback. All wiring (ServerCommandManager calls, dialogs,
// signals, toasts, ids) is unchanged. Note: the live in-stream Server Commands submenu is rendered
// inline by QuickMenu.qml (its serverCommandsModel); this standalone component is aligned to the
// same token language so the two never diverge visually.
GroupBox {
    id: serverCommandsGroupBox
    width: (parent.width - (parent.leftPadding + parent.rightPadding))
    padding: VbTokens.space4
    label: Item {}
    background: Rectangle {
        color: VbTokens.surfaceRaised
        radius: VbTokens.radiusCard
        border.width: 1
        border.color: VbTokens.divider
    }

    Column {
        anchors.fill: parent
        spacing: VbTokens.space3

        // Section header (Sora, like the redesigned card headers) — replaces the old cyan title.
        Text {
            width: parent.width
            text: qsTr("Server Commands")
            font.family: VbTokens.fontDisplay
            font.weight: Font.Bold
            font.pixelSize: VbTokens.typeTitle
            color: VbTokens.textPrimary
            elide: Text.ElideRight
        }

        // Description
        Label {
            width: parent.width
            text: qsTr("Execute commands on the streaming server during game sessions. Requires Apollo server with command permissions enabled.")
            font.family: VbTokens.fontBody
            font.pixelSize: VbTokens.typeCaption
            wrapMode: Text.Wrap
            color: VbTokens.textTertiary
        }

        // Note about when commands are available
        Label {
            width: parent.width
            text: qsTr("Note: Commands will be available during streaming sessions when connected to Apollo servers.")
            font.family: VbTokens.fontBody
            font.pixelSize: VbTokens.typeCaption
            wrapMode: Text.Wrap
            color: VbTokens.textTertiary
        }

        // Command buttons grid
        GridLayout {
            width: parent.width
            columns: 2
            columnSpacing: VbTokens.space3
            rowSpacing: VbTokens.space2

            // Token-styled command button — surfaceOverlay fill, accent focus ring, glyph + label.
            component CommandButton: Button {
                id: cmdButton
                property string glyph: "terminal"
                Layout.fillWidth: true
                Layout.preferredHeight: VbTokens.minHitTarget   // 56 — gamepad touch target
                hoverEnabled: true
                background: Rectangle {
                    radius: VbTokens.radiusControl
                    color: cmdButton.down ? VbTokens.interactivePressed
                         : (cmdButton.activeFocus || cmdButton.hovered ? VbTokens.interactiveFocus : VbTokens.surfaceOverlay)
                    border.width: (cmdButton.activeFocus || cmdButton.hovered) ? VbTokens.focusBorder : 1
                    border.color: (cmdButton.activeFocus || cmdButton.hovered) ? VbTokens.accent : VbTokens.divider
                    opacity: cmdButton.enabled ? 1.0 : VbTokens.disabledOpacity
                }
                contentItem: RowLayout {
                    spacing: VbTokens.space2
                    VbSheetIcon {
                        kind: cmdButton.glyph
                        width: 22; height: 22
                        color: (cmdButton.activeFocus || cmdButton.hovered) ? VbTokens.accent : VbTokens.textSecondary
                        Layout.preferredWidth: 22
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: cmdButton.text
                        font.family: VbTokens.fontBody
                        font.weight: Font.DemiBold
                        font.pixelSize: VbTokens.typeLabel
                        color: VbTokens.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // Restart button
            CommandButton {
                glyph: "restart"
                text: qsTr("Restart Server")
                enabled: ServerCommandManager.hasPermission && !ServerCommandManager.isExecuting
                onClicked: {
                    confirmDialog.commandId = "restart_server"
                    confirmDialog.commandName = qsTr("Restart Server")
                    confirmDialog.commandDescription = qsTr("This will restart the streaming server. You will be disconnected.")
                    confirmDialog.open()
                }
            }

            // Shutdown button
            CommandButton {
                glyph: "power"
                text: qsTr("Shutdown Server")
                enabled: ServerCommandManager.hasPermission && !ServerCommandManager.isExecuting
                onClicked: {
                    confirmDialog.commandId = "shutdown_server"
                    confirmDialog.commandName = qsTr("Shutdown Server")
                    confirmDialog.commandDescription = qsTr("This will shut down the streaming server. You will be disconnected.")
                    confirmDialog.open()
                }
            }

            // Suspend button
            CommandButton {
                glyph: "power"
                text: qsTr("Suspend Server")
                enabled: ServerCommandManager.hasPermission && !ServerCommandManager.isExecuting
                onClicked: {
                    confirmDialog.commandId = "suspend_computer"
                    confirmDialog.commandName = qsTr("Suspend Computer")
                    confirmDialog.commandDescription = qsTr("This will suspend the host computer. You will be disconnected.")
                    confirmDialog.open()
                }
            }

            // Custom command button
            CommandButton {
                glyph: "terminal"
                text: qsTr("Custom Command")
                enabled: ServerCommandManager.hasPermission && !ServerCommandManager.isExecuting
                onClicked: {
                    customCommandDialog.open()
                }
            }
        }

    }

    // Confirmation dialog
    Dialog {
        id: confirmDialog
        anchors.centerIn: parent
        width: Math.min(400, parent.width * 0.9)
        height: Math.min(200, parent.height * 0.8)

        property string commandId: ""
        property string commandName: ""
        property string commandDescription: ""

        title: qsTr("Confirm Command")
        modal: true

        background: Rectangle {
            color: VbTokens.surfaceRaised
            radius: VbTokens.radiusDialog
            border.width: 1
            border.color: VbTokens.divider
        }

        Column {
            anchors.fill: parent
            spacing: VbTokens.space4

            Label {
                width: parent.width
                text: confirmDialog.commandName
                font.family: VbTokens.fontDisplay
                font.weight: Font.Bold
                font.pixelSize: VbTokens.typeLabel
                color: VbTokens.textPrimary
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                text: confirmDialog.commandDescription
                font.family: VbTokens.fontBody
                font.pixelSize: VbTokens.typeCaption
                wrapMode: Text.Wrap
                color: VbTokens.textSecondary
            }

            Label {
                width: parent.width
                text: qsTr("Are you sure you want to continue?")
                font.family: VbTokens.fontBody
                font.pixelSize: VbTokens.typeCaption
                wrapMode: Text.Wrap
                color: VbTokens.textPrimary
            }
        }

        standardButtons: Dialog.Yes | Dialog.No

        onAccepted: {
            ServerCommandManager.executeCommand(commandId)
        }
    }

    // Custom command dialog
    Dialog {
        id: customCommandDialog
        anchors.centerIn: parent
        width: Math.min(400, parent.width * 0.9)
        height: Math.min(250, parent.height * 0.8)

        title: qsTr("Custom Command")
        modal: true

        background: Rectangle {
            color: VbTokens.surfaceRaised
            radius: VbTokens.radiusDialog
            border.width: 1
            border.color: VbTokens.divider
        }

        Column {
            anchors.fill: parent
            spacing: VbTokens.space4

            Label {
                width: parent.width
                text: qsTr("Enter a custom command to execute on the server:")
                font.family: VbTokens.fontBody
                font.pixelSize: VbTokens.typeCaption
                wrapMode: Text.Wrap
                color: VbTokens.textPrimary
            }

            TextField {
                id: customCommandField
                width: parent.width
                placeholderText: qsTr("e.g., custom-script.sh")
                color: VbTokens.textPrimary
                placeholderTextColor: VbTokens.textTertiary
                font.family: VbTokens.fontBody
                font.pixelSize: VbTokens.typeBody
                background: Rectangle {
                    color: VbTokens.surfaceBase
                    radius: VbTokens.radiusControl
                    border.width: customCommandField.activeFocus ? VbTokens.focusBorder : 1
                    border.color: customCommandField.activeFocus ? VbTokens.accent : VbTokens.divider
                }
            }

            Label {
                width: parent.width
                text: qsTr("Warning: Only execute commands you trust. Custom commands may have different security implications.")
                font.family: VbTokens.fontBody
                font.pixelSize: VbTokens.typeCaption
                wrapMode: Text.Wrap
                color: VbTokens.statusWarning
            }
        }

        standardButtons: Dialog.Ok | Dialog.Cancel

        onAccepted: {
            if (customCommandField.text.trim() !== "") {
                ServerCommandManager.executeCustomCommand(customCommandField.text.trim())
                customCommandField.text = ""
            }
        }

        onRejected: {
            customCommandField.text = ""
        }
    }

    // Connect to signals
    Connections {
        target: ServerCommandManager

        function onCommandExecuted(commandId, success, message) {
            if (success) {
                successToast.text = qsTr("Command '%1' executed successfully").arg(commandId)
                successToast.show()
            } else {
                errorToast.text = qsTr("Command '%1' failed: %2").arg(commandId).arg(message)
                errorToast.show()
            }
        }

        function onCommandFailed(commandId, error) {
            errorToast.text = qsTr("Command '%1' failed: %2").arg(commandId).arg(error)
            errorToast.show()
        }
    }

    // Toast notifications (transient status pills)
    Rectangle {
        id: successToast
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(300, parent.width * 0.8)
        height: VbTokens.minHitTarget
        color: VbTokens.statusSuccess
        radius: VbTokens.radiusControl
        visible: false

        property string text: ""

        Label {
            anchors.centerIn: parent
            text: successToast.text
            color: VbTokens.textOnAccent
            font.family: VbTokens.fontBody
            font.weight: Font.DemiBold
            font.pixelSize: VbTokens.typeCaption
        }

        function show() {
            visible = true
            hideTimer.start()
        }

        Timer {
            id: hideTimer
            interval: 3000
            onTriggered: successToast.visible = false
        }
    }

    Rectangle {
        id: errorToast
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(300, parent.width * 0.8)
        height: VbTokens.minHitTarget
        color: VbTokens.statusDanger
        radius: VbTokens.radiusControl
        visible: false

        property string text: ""

        Label {
            anchors.centerIn: parent
            text: errorToast.text
            color: VbTokens.textOnAccent
            font.family: VbTokens.fontBody
            font.weight: Font.DemiBold
            font.pixelSize: VbTokens.typeCaption
        }

        function show() {
            visible = true
            errorHideTimer.start()
        }

        Timer {
            id: errorHideTimer
            interval: 5000
            onTriggered: errorToast.visible = false
        }
    }
}
