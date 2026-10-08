import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ColumnLayout {
    id: field
    property string label: ""
    property string value: ""
    property string hint: ""
    property bool colorField: false
    signal edited(string value)
    spacing: 8
    Label {
        text: field.label
        color: "#aeb9d2"
        font.pixelSize: 12
    }
    RowLayout {
        Layout.fillWidth: true
        Rectangle {
            visible: field.colorField
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            radius: 7
            border.color: "#667085"
            color: /^#[0-9a-fA-F]{6}$/.test(field.value) ? field.value : "transparent"
        }
        TextField {
            id: input
            Layout.fillWidth: true
            implicitHeight: 42
            leftPadding: 14
            rightPadding: 14
            color: "#e0e5f4"
            font.pixelSize: 12
            selectionColor: "#6e6099"
            selectedTextColor: "#ffffff"
            text: field.value
            placeholderText: field.hint
            placeholderTextColor: "#939bb3"
            selectByMouse: true
            background: Rectangle {
                radius: 12
                color: input.activeFocus ? "#30364f" : input.hovered ? "#2b3349" : "#242c40"
                border.color: input.activeFocus ? "#a894db" : input.hovered ? "#596582" : "#3e4a65"
                Behavior on color {
                    ColorAnimation {
                        duration: 130
                    }
                }
            }
            onTextEdited: field.edited(text)
        }
    }
}
