import QtQuick
import QtQuick.Controls.Basic

Switch {
    id: control
    implicitHeight: 42
    spacing: 12
    hoverEnabled: true
    indicator: Rectangle {
        implicitWidth: 42; implicitHeight: 24
        x: control.leftPadding; y: (control.height - height) / 2
        radius: 12
        color: control.checked ? "#8170b8" : "#2b3248"
        border.color: control.activeFocus ? "#ded3ff" : control.checked ? "#a18cd6" : "#48516a"
        Behavior on color { ColorAnimation { duration: 140 } }
        Rectangle {
            x: control.checked ? parent.width - width - 3 : 3
            y: 3; width: 18; height: 18; radius: 9
            color: control.checked ? "#f0eaff" : "#929db7"
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
    }
    contentItem: Text {
        text: control.text; font.pixelSize: 12; color: "#d2d7e9"
        leftPadding: control.indicator.width + control.spacing
        verticalAlignment: Text.AlignVCenter
    }
}
