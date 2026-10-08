import QtQuick
import QtQuick.Controls.Basic

Button {
    id: control
    property string symbol: "󰒓"
    property bool itemEnabled: true
    implicitHeight: 27
    leftPadding: 10; rightPadding: 10
    hoverEnabled: true
    contentItem: Item {
        implicitWidth: 190; implicitHeight: 22
        Text {
            text: control.symbol; width: 22; anchors.verticalCenter: parent.verticalCenter
            color: control.highlighted ? "#d3c6ff" : "#8f9ab8"
            font.family: "GoMono Nerd Font"; font.pixelSize: 16
        }
        Text {
            x: 33; width: parent.width - 43; anchors.verticalCenter: parent.verticalCenter
            text: control.text; font.pixelSize: 12
            color: control.highlighted ? "#eeeaff" : control.itemEnabled ? "#b7c0d8" : "#758099"
            elide: Text.ElideRight
        }
        Rectangle { width: 4; height: 4; radius: 2; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; color: control.highlighted ? "#c0acff" : "transparent" }
    }
    background: Rectangle {
        radius: 8
        color: control.highlighted ? "#302d43" : control.hovered ? "#232b38" : "transparent"
        border.width: control.highlighted || control.activeFocus ? 1 : 0
        border.color: control.activeFocus ? "#b4a2ff" : "#504865"
        Behavior on color { ColorAnimation { duration: 140 } }
    }
}
