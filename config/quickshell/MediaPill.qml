pragma ComponentBehavior: Bound
import QtQuick

Pill {
    id: media
    property var levels: []
    readonly property real spectrumScale: (settings.iconSize || 16) / 16
    readonly property int spectrumWidth: settings.hideIcon ? 0 : Math.ceil(58 * spectrumScale)
    implicitHeight: Math.max(28, settings.hideIcon ? 0 : (settings.iconSize || 16) + 8)
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
        visible: !media.settings.hideIcon
        x: 9
        height: 16 * media.spectrumScale
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2 * media.spectrumScale
        Repeater {
            model: 12
            delegate: Rectangle {
                required property int index
                objectName: "spectrumBar" + index
                readonly property real level: Math.max(0, Math.min(1, Number(media.levels[index]) || 0))
                anchors.verticalCenter: parent.verticalCenter
                width: 3 * media.spectrumScale
                height: (2 + level * 14) * media.spectrumScale
                radius: 1.5 * media.spectrumScale
                antialiasing: true
                color: media.settings.iconColor || (media.colorSampler ? media.effectiveForeground : "#94e2d5")
                opacity: media.colorSampler ? 1 : 0.45 + level * 0.55
                Behavior on height { NumberAnimation { duration: 40; easing.type: Easing.OutQuad } }
            }
        }
    }
}
