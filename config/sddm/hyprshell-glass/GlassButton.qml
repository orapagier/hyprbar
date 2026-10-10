import QtQuick
import QtQuick.Controls.Basic

Button {
    id: control
    property bool primary: false
    implicitHeight: 44
    padding: 12
    font.family: "Noto Sans"
    font.pixelSize: 15
    hoverEnabled: true
    contentItem: Text {
        text: control.text
        font: control.font
        color: control.enabled ? "#eef0ff" : "#788399"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: 12
        color: control.down ? "#53617c" : control.hovered ? "#39445f" : control.primary ? "#354360" : "#182334"
        border.color: control.visualFocus ? "#d0d5ff" : control.primary ? "#778abb" : "#4a5771"
        border.width: control.visualFocus ? 2 : 1
        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
