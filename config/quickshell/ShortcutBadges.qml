pragma ComponentBehavior: Bound
import QtQuick
import "ShortcutKeys.js" as KeysModel

Flow {
    id: badges
    property string shortcut: ""
    property color foreground: "#d9deed"
    property color fill: "#283142"
    property color outline: "#3a455a"
    spacing: 5
    Repeater {
        model: badges.shortcut ? badges.shortcut.split(" + ") : []
        delegate: Rectangle {
            required property string modelData
            implicitWidth: label.implicitWidth + 16
            implicitHeight: 27
            radius: 7
            color: badges.fill
            border.color: badges.outline
            Text {
                id: label
                anchors.centerIn: parent
                text: KeysModel.display(modelData)
                color: badges.foreground
                font.family: "Noto Sans"; font.pixelSize: 11; font.weight: Font.Medium
            }
        }
    }
}
