import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: root
    required property string title
    property string subtitle: ""
    default property alias controls: body.data
    implicitHeight: content.implicitHeight + 40
    Layout.minimumWidth: 0
    color: "#1d2430"
    radius: 12
    border.color: "#303948"
    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            Label { text: root.title; color: "#edf0fa"; font.pixelSize: 15; font.bold: true }
            Label { visible: text !== ""; text: root.subtitle; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: "#98a5bf"; font.pixelSize: 11 }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: "#303a50" }
        ColumnLayout { id: body; Layout.fillWidth: true; spacing: 20 }
    }
}
