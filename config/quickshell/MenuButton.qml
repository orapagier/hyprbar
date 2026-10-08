import QtQuick
import QtQuick.Controls

Button {
    id: control
    property color accent: "#cdd6f4"
    implicitHeight: Math.max(36, contentItem.implicitHeight + 16)
    leftPadding: 10; rightPadding: 10; topPadding: 8; bottomPadding: 8
    font.family: "DejaVu Sans"; font.pixelSize: 13
    contentItem: Text {
        text: control.text
        font: control.font
        color: control.enabled ? control.accent : "#585b70"
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 8
        color: control.down ? "#55cba6f7" : control.hovered || control.activeFocus ? "#38cba6f7" : "#0bffffff"
        border.width: 1; border.color: control.activeFocus ? "#88cba6f7" : "#1fffffff"
    }
}
