import QtQuick 2.9
import QtQuick.Controls 2.2

import SdlGamepadKeyNavigation 1.0
import SystemProperties 1.0
import UiSoundManager 1.0

// https://stackoverflow.com/questions/45029968/how-do-i-set-the-combobox-width-to-fit-the-largest-item
ComboBox {
    id: comboRoot

    property int textWidth
    property int desiredWidth : leftPadding + textWidth + indicator.width + rightPadding
    property int maximumWidth : parent.width

    implicitWidth: desiredWidth < maximumWidth ? desiredWidth : maximumWidth

    // Popup navigation tick + selection blip. Connections, not plain
    // handlers, because instances override base handlers (see above).
    // highlightedIndex also syncs while the popup is closed (model/currentIndex
    // churn at init) — the popup.visible guard keeps those silent.
    Connections {
        target: comboRoot
        function onHighlightedIndexChanged() {
            if (comboRoot.popup.visible) {
                UiSoundManager.focusMoved()
            }
        }
        function onActivated(index) {
            UiSoundManager.activated()
        }
    }

    // With the popup CLOSED, ComboBox's built-in key handling edits the value on
    // arrow Up/Down — so KEYBOARD-arrow focus-walking through a settings combo silently
    // changed it. (Gamepad d-pad is unaffected in Settings: UiNavMode translates it to
    // Tab/Shift+Tab; the on-device repro traced to synthetic keyboard
    // arrows.) Closed = arrows navigate focus, matching NavigableMessageDialog's idiom;
    // value editing requires opening the popup (A/Enter) first, where default arrow
    // behavior still applies.
    Keys.onUpPressed: function(event) {
        if (popup.visible) { event.accepted = false; return }
        event.accepted = true
        nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
    }
    Keys.onDownPressed: function(event) {
        if (popup.visible) { event.accepted = false; return }
        event.accepted = true
        nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
    }

    TextMetrics {
        id: popupMetrics
    }

    TextMetrics {
        id: textMetrics
    }

    function recalculateWidth() {
        textMetrics.font = font
        popupMetrics.font = popup.font
        textWidth = 0
        for (var i = 0; i < count; i++){
            textMetrics.text = textAt(i)
            popupMetrics.text = textAt(i)
            textWidth = Math.max(textMetrics.width, textWidth)
            textWidth = Math.max(popupMetrics.width, textWidth)
        }
    }

    // We call this every time the options change (and init)
    // so we can adjust the combo box width here too
    onActivated: recalculateWidth()

    // CRITICAL text-clip RCA: recalculateWidth() used to run ONLY from onActivated —
    // i.e. after a human opens the popup and picks an item. But MANY instances (accent / quick-menu /
    // capture-keys combos in SettingsView) declare their OWN onActivated, which in QML OVERRIDES this
    // base handler and drops the recalc entirely; and none of them recalc at init. So textWidth stayed
    // 0 and the combo collapsed to `leftPadding + indicator.width + rightPadding`, clipping the display
    // text ("Teal (default)"->"Teal", "Select + L1 + R1 + Y (default)"->"Sele", "in fullscreen"->"in f").
    // count-change fires when the model populates and is NOT overridable by an instance's handlers, so
    // this sizes EVERY AutoResizingComboBox correctly on first paint regardless of what else it declares.
    // Qt.callLater defers to end-of-frame so `popup`, `font` and the model are all fully constructed.
    onCountChanged: Qt.callLater(recalculateWidth)
    Component.onCompleted: Qt.callLater(recalculateWidth)

    popup.onAboutToShow: {
        // Switch to normal navigation for combo boxes
        SdlGamepadKeyNavigation.setUiNavMode(false)

        // Override the popup color to improve contrast with the overridden
        // Material 2 background color set in main.qml.
        if (SystemProperties.usesMaterial3Theme) {
            popup.background.color = "#424242"
        }
    }

    popup.onAboutToHide: {
        SdlGamepadKeyNavigation.setUiNavMode(true)
    }

    // Same defect as the Up/Down guard above, and the one that actually bit users:
    // decrement/incrementCurrentIndex() with the popup CLOSED goes through
    // QQuickComboBoxPrivate::setCurrentIndex(..., Activate), which emits activated()
    // and therefore RUNS the instance's onActivated — silently writing and persisting
    // a new value. Unlike Up/Down, gamepad Left/Right is NOT translated by UiNavMode:
    // SdlGamepadKeyNavigation sends raw Key_Left/Key_Right for the d-pad AND the left
    // stick (auto-repeating), so a stick nudge on a focused combo changed the setting.
    // That is how a Stable-channel user was silently moved onto Beta and auto-updated
    // to a prerelease (BL-2437). Closed popup = arrows never edit; open it with A/Enter
    // first, where the default arrow behavior still applies.
    Keys.onLeftPressed: function(event) {
        if (popup.visible) { event.accepted = false; return }
        event.accepted = true
    }
    Keys.onRightPressed: function(event) {
        if (popup.visible) { event.accepted = false; return }
        event.accepted = true
    }
}
