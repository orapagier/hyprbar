import QtQuick
import Quickshell.Io

Item {
    id: controller
    required property var store
    property string error: ""
    property string fingerprint: ""
    property bool restarting: false
    readonly property string backend: decodeURIComponent(Qt.resolvedUrl("settings/backend.py").toString().replace(/^file:\/\//, ""))
    function lockNow() {
        if (locker.running) return;
        error = "";
        locker.running = true;
    }
    function sync() {
        if (!store.loaded) return;
        let next = JSON.stringify(store.config.locking);
        if (next === fingerprint) return;
        fingerprint = next;
        error = "";
        restarting = true;
        if (daemon.running) daemon.running = false;
        else restart.restart();
    }
    Component.onCompleted: sync()
    Connections {
        target: controller.store
        function onConfigChanged() { controller.sync(); }
        function onLoadedChanged() { controller.sync(); }
    }
    Timer {
        id: restart
        interval: 100
        onTriggered: {
            controller.restarting = false;
            if (controller.store.config.locking.enabled) daemon.running = true;
        }
    }
    Process {
        id: locker
        command: ["python3", controller.backend, "--lock"]
        stderr: StdioCollector { onStreamFinished: if (text) controller.error = text.trim() }
        onExited: (code, status) => {
            if (code !== 0 && !controller.error) controller.error = "Lock command failed. Check your locker configuration.";
        }
    }
    Process {
        id: daemon
        command: ["python3", controller.backend, "--idle"]
        stderr: StdioCollector { onStreamFinished: if (text && !controller.restarting) controller.error = text.trim() }
        onExited: (code, status) => {
            if (controller.restarting) restart.restart();
            else if (controller.store.config.locking.enabled && !controller.error)
                controller.error = "Automatic locking stopped. Turn it off and on to retry.";
        }
    }
}
