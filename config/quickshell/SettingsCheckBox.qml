import QtQuick
import QtQuick.Controls.Basic

CheckBox {
    id: control
    implicitHeight: 36
    spacing: 10
    indicator: Rectangle {
        implicitWidth: 22; implicitHeight: 22
        x: control.leftPadding; y: (control.height - height) / 2
        radius: 7
        color: control.checked ? "#6d5c9b" : "#232b38"
        border.color: control.activeFocus ? "#d6c5ff" : control.checked ? "#9f88d5" : "#46516c"
        Text { anchors.centerIn: parent; text: "✓"; color: "#f0eaff"; font.pixelSize: 14; visible: control.checked }
    }
    contentItem: Text { text: control.text; font.pixelSize: 12; color: "#bcc5df"; leftPadding: control.indicator.width + control.spacing; verticalAlignment: Text.AlignVCenter }
}
