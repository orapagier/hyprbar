import QtQuick
import Quickshell.Io

Item {
    id: controller
    required property var store
    property string profileError: ""
    property string resumeError: ""
    property string lidError: ""
    readonly property string error: [profileError, lidError, resumeError].filter(Boolean).join("\n")
    property string profileFingerprint: ""
    property string lidFingerprint: ""
    property bool restartingLid: false
    property bool stoppingLid: false
    readonly property string helper: decodeURIComponent(Qt.resolvedUrl("settings/power.py").toString().replace(/^file:\/\//, ""))
    function sync() {
        if (!store.loaded) return;
        let power = store.config.power || {};
        let profile = power.profile || "system";
        if (profile !== profileFingerprint && !profileProcess.running) {
            profileFingerprint = profile;
            profileError = "";
            if (profile !== "system") profileProcess.running = true;
        }
        let lid = power.lidAction || "system";
        if (lid !== lidFingerprint) {
            lidFingerprint = lid;
            lidError = "";
            restartingLid = true;
            if (lidProcess.running && !stoppingLid) { stoppingLid = true; lidProcess.running = false; }
            else if (!stoppingLid) lidRestart.restart();
        }
    }
    Component.onCompleted: { recovery.running = true; sync(); }
    Connections {
        target: controller.store
        function onConfigChanged() { controller.sync(); }
        function onLoadedChanged() { controller.sync(); }
    }
    Timer {
        id: lidRestart
        interval: 100
        onTriggered: {
            controller.restartingLid = false;
            if ((controller.store.config.power || {}).lidAction && controller.store.config.power.lidAction !== "system") lidProcess.running = true;
        }
    }
    Process {
        id: recovery
        command: ["python3", controller.helper, "--resume"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { let result = JSON.parse(text); if (!result.ok) controller.resumeError = result.message; }
                catch (e) { controller.resumeError = "Could not restore the previous dimmed screen state."; }
            }
        }
    }
    Process {
        id: profileProcess
        command: ["python3", controller.helper, "--apply-profile"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { let result = JSON.parse(text); if (!result.ok) controller.profileError = result.message; }
                catch (e) { controller.profileError = "Could not read the power profile result."; }
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && !controller.profileError) controller.profileError = "Could not apply the saved power profile.";
            Qt.callLater(controller.sync);
        }
    }
    Process {
        id: lidProcess
        command: ["python3", controller.helper, "--lid"]
        stderr: StdioCollector { onStreamFinished: if (text && !controller.restartingLid) controller.lidError = text.trim() }
        onExited: (code, status) => {
            controller.stoppingLid = false;
            if (controller.restartingLid) lidRestart.restart();
            else if (!controller.lidError) controller.lidError = "Session lid control stopped. Use system behavior or select it again to retry.";
        }
    }
}
