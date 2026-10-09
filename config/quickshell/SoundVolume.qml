pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ColumnLayout {
    id: control
    required property var node
    property string label: "Volume"
    readonly property bool available: !!(node && node.audio)
    spacing: 6
    RowLayout {
        Layout.fillWidth: true
        Label { Layout.fillWidth: true; text: control.label; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: "#ecebff" }
        Label { text: control.available ? Math.round(control.node.audio.volume * 100) + "%" : "—"; color: "#b4befe" }
        SettingsButton {
            objectName: "soundMuteControl"
            text: control.available && control.node.audio.muted ? "Unmute" : "Mute"
            enabled: control.available
            onClicked: control.node.audio.muted = !control.node.audio.muted
        }
    }
    Slider {
        id: slider
        objectName: "soundVolumeControl"
        Layout.fillWidth: true
        implicitHeight: 32
        from: 0; to: 1; stepSize: 0.01
        enabled: control.available
        value: control.available ? control.node.audio.volume : 0
        onMoved: if (control.available) control.node.audio.volume = value
        Accessible.name: control.label
        background: Rectangle {
            implicitWidth: 200; implicitHeight: 4
            x: slider.leftPadding; y: slider.height / 2 - height / 2
            width: slider.availableWidth; height: implicitHeight; radius: 2; color: "#363e58"
            Rectangle { width: slider.visualPosition * parent.width; height: 4; radius: 2; color: "#b4befe" }
        }
        handle: Rectangle { x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width); y: slider.height / 2 - height / 2; implicitWidth: 14; implicitHeight: 14; radius: 7; color: "#cdd6f4" }
    }
}
