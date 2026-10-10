import QtQuick
import "SettingsStyle.js" as Style
import QtQuick.Controls.Basic

ComboBox {
    id: control
    implicitHeight: Style.controlHeight
    implicitWidth: Math.max(116, contentItem.implicitWidth + 54)
    leftPadding: 14; rightPadding: 34
    hoverEnabled: true
    opacity: enabled ? 1 : 0.45
    font.pixelSize: Style.bodySize
    contentItem: Text {
        text: control.displayText; font: control.font; color: Style.text
        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
    }
    indicator: Text { text: "⌄"; color: Style.muted; font.pixelSize: 18; x: control.width - 26; y: (control.height - height) / 2 - 2 }
    background: Rectangle {
        radius: Style.controlRadius; color: control.hovered ? Style.hover : Style.field
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Style.accentText : Style.controlBorder
        Behavior on color { ColorAnimation { duration: Style.duration(control, 130) } }
    }
    delegate: ItemDelegate {
        required property var modelData
        required property int index
        width: control.width - 12; height: 36
        highlighted: control.highlightedIndex === index
        contentItem: Text { text: modelData; color: Style.text; font.pixelSize: Style.bodySize; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        background: Rectangle { radius: Style.controlRadius; color: parent.highlighted ? Style.selection : "transparent" }
    }
    popup: Popup {
        y: control.height + 6; width: control.width
        padding: 6
        implicitHeight: Math.min(240, list.contentHeight + 12)
        background: Rectangle { radius: 10; color: Style.surface; border.color: Style.border }
        contentItem: ListView {
            id: list
            clip: true; implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }
    }
}
