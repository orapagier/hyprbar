import QtQuick
import QtQuick.Controls.Basic

Button {
    id: control
    implicitHeight: 40
    implicitWidth: Math.max(100, contentItem.implicitWidth + 36)
    leftPadding: 18; rightPadding: 18
    hoverEnabled: true
    font.pixelSize: 12
    opacity: enabled ? 1 : 0.4
    contentItem: Text {
        text: control.text; font: control.font
        color: control.highlighted ? "#ede8ff" : "#cbd0e4"
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: height / 2
        color: control.down ? "#555078" : control.highlighted ? "#45405e" : control.hovered ? "#343a50" : control.flat ? "transparent" : "#272d41"
        border.color: control.activeFocus ? "#b4a2ff" : control.highlighted ? "#74648e" : control.hovered ? "#545d79" : "#3b435c"
        border.width: control.flat && !control.highlighted && !control.hovered && !control.activeFocus ? 0 : 1
        Behavior on color { ColorAnimation { duration: 130 } }
        Rectangle { x: 12; y: 1; width: parent.width - 24; height: 1; color: "#12ffffff"; radius: 1 }
    }
}
