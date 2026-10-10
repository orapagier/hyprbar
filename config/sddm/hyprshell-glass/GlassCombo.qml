pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic

ComboBox {
    id: control
    implicitHeight: 44
    font.family: "Noto Sans"
    font.pixelSize: 15
    palette.text: "#edf0ff"
    palette.buttonText: "#edf0ff"
    palette.base: "#142031"
    palette.button: "#142031"
    palette.window: "#172235"
    palette.mid: "#566581"
    palette.dark: "#c5ceee"
    palette.highlight: "#48577b"
    palette.highlightedText: "#ffffff"
    selectTextByMouse: true
    contentItem: TextField {
        text: control.editable ? control.editText : control.displayText
        font: control.font
        enabled: control.editable
        readOnly: control.down
        autoScroll: control.editable
        selectByMouse: control.selectTextByMouse
        inputMethodHints: control.inputMethodHints
        validator: control.validator
        padding: 0
        leftPadding: 12
        color: "#edf0ff"
        selectionColor: "#48577b"
        selectedTextColor: "#ffffff"
        verticalAlignment: Text.AlignVCenter
        background: null
    }
    background: Rectangle {
        radius: 12
        color: "#90101b2a"
        border.color: control.activeFocus ? "#b4befe" : "#566581"
        border.width: control.activeFocus ? 2 : 1
    }
    delegate: ItemDelegate {
        id: option
        required property int index
        width: control.width
        text: control.textAt(index)
        font: control.font
        highlighted: control.highlightedIndex === index
        contentItem: Text {
            text: option.text
            font: control.font
            color: "#edf0ff"
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 8
            color: option.highlighted ? "#48577b" : "transparent"
        }
    }
    popup: Popup {
        y: control.height + 6
        width: control.width
        padding: 6
        implicitHeight: Math.min(contentItem.implicitHeight + 12, 200)
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.delegateModel
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator { }
        }
        background: Rectangle {
            radius: 12
            color: "#172235"
            border.color: "#657596"
        }
    }
}
