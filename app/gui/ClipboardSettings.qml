import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.2

import ClipboardManager 1.0
import Vibemis.Redesign 1.0

// P3.19 wave 2 (BL-2107): secondary/tertiary label colors unified onto VbTokens
// (was #cccccc / #aaaaaa). No layout change; full redesign of this panel lands in P3.17.

GroupBox {
    id: clipboardSettingsGroupBox
    width: (parent.width - (parent.leftPadding + parent.rightPadding))
    padding: 12
    title: "<font color=\"skyblue\">" + qsTr("Clipboard Sync") + "</font>"
    font.pointSize: 12

    Column {
        anchors.fill: parent
        spacing: 8

        // Main toggle
        Row {
            spacing: 10
            width: parent.width

            CheckBox {
                id: enableClipboardSync
                text: qsTr("Enable clipboard synchronization")
                font.pointSize: 12
                checked: ClipboardManager.isEnabled
                onCheckedChanged: {
                    ClipboardManager.isEnabled = checked
                }
            }
        }

        // Description
        Label {
            width: parent.width
            text: qsTr("Synchronize clipboard content between your device and the streaming server. Requires Apollo server.")
            font.pointSize: 9
            wrapMode: Text.Wrap
            color: VbTokens.textMute
        }

        // Content filtering section
        GroupBox {
            width: parent.width
            title: qsTr("Content Filtering")
            font.pointSize: 10
            enabled: enableClipboardSync.checked
            clip: true

            Column {
                anchors.fill: parent
                spacing: 8

                CheckBox {
                    id: textOnlyFilter
                    text: qsTr("Text content only")
                    font.pointSize: 10
                    checked: ClipboardManager.textOnlyMode
                    onCheckedChanged: {
                        ClipboardManager.textOnlyMode = checked
                    }
                }

                Label {
                    width: parent.width
                    text: qsTr("Only sync text content, ignore images and files")
                    font.pointSize: 8
                    wrapMode: Text.Wrap
                    color: VbTokens.textDim
                }

                Row {
                    spacing: 10
                    width: parent.width

                    Label {
                        text: qsTr("Max content size:")
                        font.pointSize: 10
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Row {
                        spacing: 5
                        
                        SpinBox {
                            id: maxSizeSpinBox
                            from: 1
                            to: 100
                            value: ClipboardManager.maxContentSizeMB
                            onValueChanged: {
                                ClipboardManager.maxContentSizeMB = value
                            }
                        }
                        
                        Label {
                            text: "MB"
                            anchors.verticalCenter: parent.verticalCenter
                            font.pointSize: 12
                        }
                    }
                }
            }
        }

        // Privacy section
        GroupBox {
            width: parent.width
            title: qsTr("Privacy")
            font.pointSize: 10
            enabled: enableClipboardSync.checked
            clip: true

            Column {
                anchors.fill: parent
                spacing: 8

                CheckBox {
                    id: showNotifications
                    text: qsTr("Show sync notifications")
                    font.pointSize: 10
                    checked: ClipboardManager.showNotifications
                    onCheckedChanged: {
                        ClipboardManager.showNotifications = checked
                    }
                }

                Label {
                    width: parent.width
                    text: qsTr("Display toast notifications when clipboard content is synchronized")
                    font.pointSize: 8
                    wrapMode: Text.Wrap
                    color: VbTokens.textDim
                }
            }
        }

        // Note about when sync is active
        Label {
            width: parent.width
            text: qsTr("Note: Clipboard sync will be active during game streaming sessions when connected to Apollo servers.")
            font.pointSize: 9
            wrapMode: Text.Wrap
            color: VbTokens.textDim
            visible: enableClipboardSync.checked
        }
    }
}