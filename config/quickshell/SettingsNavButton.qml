import QtQuick
import "SettingsStyle.js" as Style
import QtQuick.Controls.Basic

Button {
    id: control
    property string symbol: "󰒓"
    property bool itemEnabled: true
    implicitHeight: 42
    leftPadding: 13; rightPadding: 13
    hoverEnabled: true
    Accessible.name: text
    Accessible.description: highlighted ? "Current page" : itemEnabled ? "" : "Bar item is hidden"
    ToolTip.visible: (hovered || activeFocus) && truncated
    ToolTip.text: text
    readonly property bool truncated: labelText.truncated
    contentItem: Item {
        implicitWidth: 180; implicitHeight: 24
        Text {
            text: control.symbol; width: 22; anchors.verticalCenter: parent.verticalCenter
            color: control.highlighted ? Style.text : Style.muted
            font.family: "GoMono Nerd Font"; font.pixelSize: 16
        }
        Text {
            id: labelText
            x: 33; width: parent.width - 33; anchors.verticalCenter: parent.verticalCenter
            text: control.text; font.pixelSize: Style.bodySize; font.weight: control.highlighted ? Font.DemiBold : Font.Normal
            color: control.itemEnabled ? Style.text : Style.disabled
            elide: Text.ElideRight
        }
    }
    background: Rectangle {
        radius: 8
        color: control.highlighted ? Style.selection : control.hovered ? Style.button : "transparent"
        border.width: control.activeFocus ? 2 : 0
        border.color: control.activeFocus ? Style.accentText : Style.border
        Behavior on color { ColorAnimation { duration: Style.duration(control, 140) } }
    }
}
