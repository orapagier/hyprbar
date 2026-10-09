pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: page
    property string error: ""
    property var actions: [
        {key: Qt.Key_L, shortcut: "Alt + P + L", title: "󰌾  Lock", description: "Lock screen", command: ["python3", decodeURIComponent(Qt.resolvedUrl("settings/backend.py").toString().replace(/^file:\/\//, "")), "--lock"]},
        {key: Qt.Key_X, shortcut: "Alt + P + X", title: "󰐥  Shutdown", description: "Shutdown", command: ["systemctl", "poweroff"]},
        {key: Qt.Key_R, shortcut: "Alt + P + R", title: "󰜉  Reboot", description: "Reboot", command: ["systemctl", "reboot"]},
        {key: Qt.Key_S, shortcut: "Alt + P + S", title: "󰒲  Sleep", description: "Sleep", command: ["systemctl", "suspend"]},
        {key: Qt.Key_O, shortcut: "Alt + P + O", title: "󰗽  Logout", description: "Logout", command: ["uwsm", "stop"]}
    ]
    function runShortcut(key) {
        let entry = actions.find(item => item.key === key);
        if (!entry) return false;
        if (!action.running) { page.error = ""; action.exec(entry.command); }
        return true;
    }
    spacing: 8
    Repeater {
        model: page.actions
        delegate: MenuButton {
            required property var modelData
            Layout.fillWidth: true
            text: modelData.title + "    " + modelData.shortcut; font.family: "GoMono Nerd Font"
            enabled: !action.running
            onClicked: { page.error = ""; action.exec(modelData.command); }
        }
    }
    Process {
        id: action
        stderr: StdioCollector { onStreamFinished: page.error = text }
        onExited: (code, status) => { if (code !== 0 && !page.error) page.error = "Action failed"; }
    }
    MenuLabel { text: page.error; visible: text.length > 0; color: "#f38ba8"; Layout.fillWidth: true }
}
