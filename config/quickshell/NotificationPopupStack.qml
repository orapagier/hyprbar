pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Item {
    id: view
    required property var inbox
    implicitHeight: stack.implicitHeight
    ColumnLayout {
        id: stack
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 8
        Repeater {
            model: view.inbox.popups
            delegate: Rectangle {
                id: toast
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: content.implicitHeight + 24
                radius: 12
                color: "#1c2130"
                border.color: modelData.critical ? "#f38ba8" : "#545d79"
                Timer {
                    interval: Math.max(1, toast.modelData.popupDeadline - Date.now())
                    running: !toast.modelData.critical
                    onTriggered: view.inbox.hidePopup(toast.modelData.id)
                }
                ColumnLayout {
                    id: content
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            text: (toast.modelData.critical ? "Critical · " : "") + toast.modelData.app
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: "#a6adc8"
                        }
                        MenuButton {
                            text: "×"
                            Accessible.name: "Close popup, keep in inbox"
                            onClicked: view.inbox.hidePopup(toast.modelData.id)
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: toast.modelData.summary
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        color: "#ecebff"
                        font.bold: true
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: toast.modelData.body
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        color: "#cdd6f4"
                    }
                    Repeater {
                        model: toast.modelData.active ? toast.modelData.actions : []
                        delegate: MenuButton {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.text
                            onClicked: { view.inbox.invoke(toast.modelData.id, modelData.id); view.inbox.hidePopup(toast.modelData.id); }
                        }
                    }
                }
            }
        }
    }
}
