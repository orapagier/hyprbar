import QtQuick
import QtQuick.Controls.Basic

ComboBox {
    id: control
    implicitHeight: 40
    implicitWidth: Math.max(116, contentItem.implicitWidth + 54)
    leftPadding: 14; rightPadding: 34
    hoverEnabled: true
    font.pixelSize: 12
    contentItem: Text {
        text: control.displayText; font: control.font; color: "#d7dcef"
        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
    }
    indicator: Text { text: "⌄"; color: "#b1a2d9"; font.pixelSize: 18; x: control.width - 26; y: (control.height - height) / 2 - 2 }
    background: Rectangle {
        radius: 12; color: control.hovered ? "#30384e" : "#242b3f"
        border.color: control.activeFocus ? "#a995d9" : "#414b65"
        Behavior on color { ColorAnimation { duration: 130 } }
    }
    delegate: ItemDelegate {
        required property var modelData
        required property int index
        width: control.width - 12; height: 36
        highlighted: control.highlightedIndex === index
        contentItem: Text { text: modelData; color: "#dedff0"; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        background: Rectangle { radius: 8; color: parent.highlighted ? "#45415e" : "transparent" }
    }
    popup: Popup {
        y: control.height + 6; width: control.width
        padding: 6
        implicitHeight: Math.min(240, list.contentHeight + 12)
        background: Rectangle { radius: 16; color: "#242a3e"; border.color: "#505976" }
        contentItem: ListView {
            id: list
            clip: true; implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }
    }
}
