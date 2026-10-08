pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: page
    property string error: ""
    spacing: 8
    Repeater {
        model: [{title: "󰐥  Shutdown", command: ["systemctl","poweroff"]}, {title: "󰜉  Reboot", command: ["systemctl","reboot"]}, {title: "󰒲  Sleep", command: ["systemctl","suspend"]}, {title: "󰗽  Logout", command: ["uwsm","stop"]}]
        delegate: MenuButton {
            required property var modelData
            Layout.fillWidth: true
            text: modelData.title; font.family: "GoMono Nerd Font"
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
