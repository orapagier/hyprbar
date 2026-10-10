import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "SettingsStyle.js" as Style

ColumnLayout {
    id: root
    required property string title
    property string subtitle: ""
    default property alias controls: body.data
    Layout.minimumWidth: 0
    spacing: 10
    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 2
        Layout.rightMargin: 2
        spacing: 4
        Label { Layout.fillWidth: true; text: root.title; color: Style.text; font.pixelSize: Style.sectionSize; font.weight: Font.DemiBold; wrapMode: Text.WordWrap }
        Label { visible: text !== ""; text: root.subtitle; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Style.muted; font.pixelSize: Style.captionSize }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: body.implicitHeight + 36
        color: Style.surface
        radius: Style.radius
        border.color: Style.separator
        ColumnLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: 16
        }
    }
}
