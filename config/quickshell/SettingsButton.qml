import QtQuick
import "SettingsStyle.js" as Style
import QtQuick.Controls.Basic

Button {
    id: control
    implicitHeight: Style.controlHeight
    implicitWidth: Math.max(100, contentItem.implicitWidth + 36)
    leftPadding: 18; rightPadding: 18
    hoverEnabled: true
    font.pixelSize: Style.bodySize
    opacity: enabled ? 1 : 0.4
    contentItem: Text {
        text: control.text; font: control.font
        color: control.highlighted ? Style.onAccent : Style.text
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: Style.controlRadius
        color: control.highlighted ? (control.down ? Style.accentPressed : control.hovered ? Style.accentHover : Style.accent) : control.down ? Style.pressed : control.hovered ? Style.hover : control.flat ? "transparent" : Style.button
        border.color: control.activeFocus ? Style.accentText : control.highlighted ? Style.accent : Style.border
        border.width: control.activeFocus ? 2 : control.flat ? 0 : 1
        Behavior on color { ColorAnimation { duration: Style.duration(control, 130) } }
    }
}
