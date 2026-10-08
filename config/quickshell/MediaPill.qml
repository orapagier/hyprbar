pragma ComponentBehavior: Bound
import QtQuick

Pill {
    id: media
    property var levels: []
    readonly property int spectrumWidth: 58
    foreground: "#cba6f7"
    tint: "#2ef5c2e7"
    outline: "#42f5c2e7"
    family: "DejaVu Sans Mono"
    pixelSize: 11
    bold: false
    leftPadding: 9 + spectrumWidth + 8
    rightPadding: 9
    interactive: false
    content.horizontalAlignment: Text.AlignLeft
    clip: true
    Row {
        x: 9
        height: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Repeater {
            model: 12
            delegate: Rectangle {
                required property int index
                objectName: "spectrumBar" + index
                readonly property real level: Math.max(0, Math.min(1, Number(media.levels[index]) || 0))
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 2 + level * 14
                radius: 1.5
                antialiasing: true
                color: media.colorSampler ? media.effectiveForeground : "#94e2d5"
                opacity: media.colorSampler ? 1 : 0.45 + level * 0.55
                Behavior on height { NumberAnimation { duration: 40; easing.type: Easing.OutQuad } }
            }
        }
    }
}
