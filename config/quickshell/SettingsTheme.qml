import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell.Io

ColumnLayout {
    id: page
    property string mode: "light"
    property bool loaded: false
    property bool success: true
    property string message: ""
    readonly property bool busy: worker.running
    spacing: 16
    onVisibleChanged: if (visible && !busy) request("status", mode)
    Component.onCompleted: if (visible) request("status", mode)
    function request(operation, nextMode) {
        if (busy) return;
        let payload = {operation: operation, mode: nextMode, expected: mode};
        worker.command = ["python3", decodeURIComponent(Qt.resolvedUrl("settings/theme.py").toString().replace(/^file:\/\//, "")), "--request-json", JSON.stringify(payload)];
        worker.running = true;
    }
    Process {
        id: worker
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let result = JSON.parse(text);
                    page.success = result.ok;
                    page.message = result.message || "";
                    if (result.ok) { page.mode = result.mode; page.loaded = true; }
                    themeToggle.checked = Qt.binding(() => page.mode === "dark");
                } catch (e) { page.success = false; page.message = "Could not read application appearance. Try refreshing."; }
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text) { page.success = false; page.message = text; } }
    }
    SettingsCard {
        Layout.fillWidth: true
        title: "Application windows"
        subtitle: "Choose a system color preference for apps. The topbar keeps its own appearance."
        SettingsSwitch {
            id: themeToggle
            objectName: "applicationDarkTheme"
            text: "Dark theme"
            enabled: page.loaded && !page.busy
            checked: page.mode === "dark"
            onToggled: page.request("save", checked ? "dark" : "light")
        }
        Label { text: page.mode === "dark" ? "Dark" : "Light"; color: "#c9bdff" }
        Label { text: "Apps with their own appearance setting should use Follow system. Reopen apps that do not change automatically."; color: "#98a5bf"; Layout.fillWidth: true; wrapMode: Text.Wrap }
        Label { visible: !!page.message; text: page.message; color: page.success ? "#a6e3a1" : "#f38ba8"; Layout.fillWidth: true; wrapMode: Text.Wrap }
        SettingsButton { text: "Refresh"; enabled: !page.busy; onClicked: page.request("status", page.mode) }
    }
}
