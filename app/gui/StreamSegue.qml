import QtQuick 2.0
import QtQuick.Controls 2.2
import QtQuick.Window 2.2

import SdlGamepadKeyNavigation 1.0
import Session 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0
import UiSoundManager 1.0

Item {
    property Session session
    property string appName
    property string stageText : isResume ? qsTr("Resuming %1...").arg(appName) :
                                           qsTr("Starting %1...").arg(appName)
    property bool isResume : false
    property bool quitAfter : false

    // Bounded auto-reconnect after an unexpected mid-stream drop.
    // Only armed once the stream actually started (launch failures keep the old
    // error-dialog behavior), and capped so a dead host can't loop forever.
    property bool streamStarted: false
    property int reconnectAttempts: 0
    readonly property int maxReconnectAttempts: 3
    property Session pendingReconnectSession: null

    function stageStarting(stage)
    {
        // Update the spinner text
        stageText = qsTr("Starting %1...").arg(stage)
    }

    function stageFailed(stage, errorCode, failingPorts)
    {
        // Display the error dialog after Session::exec() returns
        streamSegueErrorDialog.text = qsTr("Starting %1 failed: Error %2").arg(stage).arg(errorCode)

        if (failingPorts) {
            streamSegueErrorDialog.text += "\n\n" + qsTr("Check your firewall and port forwarding rules for port(s): %1").arg(failingPorts)
        }
    }

    function connectionStarted()
    {
        // Arm auto-reconnect: the stream is genuinely up. Reset the attempt budget so
        // each successful (re)connection gets a fresh allowance.
        streamStarted = true
        reconnectAttempts = 0

        // Hide the UI contents so the user doesn't
        // see them briefly when we pop off the StackView
        stageSpinner.visible = false
        stageLabel.visible = false
        hintText.visible = false

        // Hide the window now that streaming has begun
        window.visible = false
    }

    function displayLaunchError(text)
    {
        // Display the error dialog after Session::exec() returns
        streamSegueErrorDialog.text = text
        console.error(text)
    }

    function quitStarting()
    {
        // Avoid the push transition animation
        var component = Qt.createComponent("QuitSegue.qml")
        stackView.replace(stackView.currentItem, component.createObject(stackView, {"appName": appName}), StackView.Immediate)

        // Show the Qt window again to show quit segue
        window.visible = true
    }

    function sessionFinished(portTestResult)
    {
        // If the stream was up and dropped unexpectedly, retry in place
        // instead of popping back to the grid. Guarded by the setting (default off).
        if (StreamingPreferences.autoReconnect && !quitAfter && streamStarted &&
                session && session.wasUnexpectedTermination() &&
                reconnectAttempts < maxReconnectAttempts) {
            reconnectAttempts++
            streamStarted = false
            stageText = qsTr("Connection lost — reconnecting to %1 (attempt %2 of %3)...")
                            .arg(appName).arg(reconnectAttempts).arg(maxReconnectAttempts)
            stageSpinner.visible = true
            stageLabel.visible = true
            window.visible = true

            // Build the replacement session now (the old object is still alive here);
            // it is swapped in once the old one signals readyForDeletion.
            pendingReconnectSession = session.createResumeSession()
            return
        }

        if (portTestResult !== 0 && portTestResult !== -1 && streamSegueErrorDialog.text) {
            streamSegueErrorDialog.text += "\n\n" + qsTr("This PC's Internet connection is blocking Moonlight. Streaming over the Internet may not work while connected to this network.")
        }

        // Re-enable GUI gamepad usage now
        SdlGamepadKeyNavigation.enable()

        // Pop the StreamSegue off the stack if this is a GUI-based app launch
        if (!quitAfter) {
            stackView.pop()
        }

        if (quitAfter && !streamSegueErrorDialog.text) {
            // If this was a CLI launch without errors, exit now
            Qt.quit()
        }
        else {
            // Show the Qt window again after streaming
            window.visible = true

            // Display any launch errors. We do this after
            // the Qt UI is visible again to prevent losing
            // focus on the dialog which would impact gamepad
            // users.
            if (streamSegueErrorDialog.text) {
                streamSegueErrorDialog.quitAfter = quitAfter
                streamSegueErrorDialog.open()
            }
        }
    }

    function sessionReadyForDeletion()
    {
        // A reconnect is pending — swap in the replacement session and
        // relaunch after a short backoff instead of tearing down the segue.
        if (pendingReconnectSession) {
            session = pendingReconnectSession
            pendingReconnectSession = null
            gc()

            session.stageStarting.connect(stageStarting)
            session.stageFailed.connect(stageFailed)
            session.connectionStarted.connect(connectionStarted)
            session.displayLaunchError.connect(displayLaunchError)
            session.displayLaunchWarning.connect(displayLaunchWarning)
            session.quitStarting.connect(quitStarting)
            session.sessionFinished.connect(sessionFinished)
            session.readyForDeletion.connect(sessionReadyForDeletion)

            SdlGamepadKeyNavigation.disable()
            startSessionTimer.interval = 1500 * reconnectAttempts   // simple backoff
            startSessionTimer.start()
            return
        }

        // Garbage collect the Session object since it's pretty heavyweight
        // and keeps other libraries (like SDL_TTF) around until it is deleted.
        session = null
        gc()
    }

    function displayLaunchWarning(text)
    {
        console.warn(text)
        // Show a brief ToolTip for the warning. Warnings are emitted by
        // Session::exec() during initialize(), so they appear just before
        // the connection stages begin.
        var toast = Qt.createQmlObject('import QtQuick.Controls 2.2; ToolTip {}', parent, '')
        toast.timeout = 3000
        toast.text = text
        toast.visible = true
    }

    StackView.onDeactivating: {
        // Show the toolbar again when popped off the stack
        toolBar.visible = true

        // Re-enable GUI gamepad usage now
        SdlGamepadKeyNavigation.enable()
    }

    StackView.onActivated: {
        // Hide the toolbar before we start loading
        toolBar.visible = false

        // Release the UI-sound audio device now (well before Session
        // constructs its audio renderer) so the renderer's device open never
        // contends with a lingering UI-sound device on exclusive-audio systems.
        UiSoundManager.streamStarting()

        // Hook up our signals
        session.stageStarting.connect(stageStarting)
        session.stageFailed.connect(stageFailed)
        session.connectionStarted.connect(connectionStarted)
        session.displayLaunchError.connect(displayLaunchError)
        session.displayLaunchWarning.connect(displayLaunchWarning)
        session.quitStarting.connect(quitStarting)
        session.sessionFinished.connect(sessionFinished)
        session.readyForDeletion.connect(sessionReadyForDeletion)

        // Kick off the stream
        spinnerTimer.start()
        streamLoader.active = true
    }

    Timer {
        id: spinnerTimer

        // Display the spinner appearance a bit to allow us to reach
        // the code in Session.exec() that pumps the event loop.
        // If we display it immediately, it will briefly hang in the
        // middle of the animation on Windows, which looks very
        // obviously broken.
        interval: 100
        onTriggered: stageSpinner.visible = true
    }

    Timer {
        id: startSessionTimer
        onTriggered: {
            // Garbage collect QML stuff before we start streaming,
            // since we'll probably be streaming for a while and we
            // won't be able to GC during the stream.
            gc()

            // Run the streaming session to completion.
            // Session::exec() calls initialize() internally and emits
            // sessionFinished(0) + readyForDeletion() on failure.
            session.exec(window)
        }
    }

    Loader {
        id: streamLoader
        active: false
        asynchronous: true

        onLoaded: {
            // Set the hint text. We do this here rather than
            // in the hintText control itself to synchronize
            // with Session.exec() which requires no concurrent
            // gamepad usage.
            hintText.text = qsTr("Tip:") + " " + qsTr("Press %1 to disconnect your session").arg(SdlGamepadKeyNavigation.getConnectedGamepads() > 0 ?
                                                  qsTr("Start+Select+L1+R1") : qsTr("Ctrl+Alt+Shift+Q"))

            // Stop GUI gamepad usage now
            SdlGamepadKeyNavigation.disable()

            // Start the session on the next event loop tick so the spinner
            // animation has a chance to render before Session::exec() blocks.
            // Warnings are surfaced via the displayLaunchWarning signal (connected
            // in StackView.onActivated) rather than via a pre-collected array.
            startSessionTimer.interval = 0
            startSessionTimer.start()
        }

        sourceComponent: Item {}
    }

    Row {
        anchors.centerIn: parent
        spacing: 5

        BusyIndicator {
            id: stageSpinner
            running: visible
            visible: false
        }

        Label {
            id: stageLabel
            height: stageSpinner.height
            text: stageText
            font.pointSize: 20
            verticalAlignment: Text.AlignVCenter

            wrapMode: Text.Wrap
        }
    }

    Label {
        id: hintText
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 50
        anchors.horizontalCenter: parent.horizontalCenter
        font.pointSize: 18
        verticalAlignment: Text.AlignVCenter

        wrapMode: Text.Wrap
    }
}
