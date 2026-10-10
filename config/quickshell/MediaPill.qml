pragma ComponentBehavior: Bound
import QtQuick

Pill {
    id: media
    property var levels: []
    readonly property real spectrumScale: (settings.iconSize || 16) / 16
    readonly property int spectrumWidth: settings.hideIcon ? 0 : Math.ceil(58 * spectrumScale)
    implicitHeight: Math.max(28, settings.hideIcon ? 0 : (settings.iconSize || 16) + 8, shownText.length ? content.implicitHeight + 8 : 0)
    foreground: "#cba6f7"
    tint: "#2ef5c2e7"
    outline: "#42f5c2e7"
    family: "DejaVu Sans Mono"
    pixelSize: 11
    bold: false
    leftPadding: 9 + spectrumWidth + 8
    rightPadding: 9
    effectiveLeftPadding: Math.max(0, 9 + (settings.paddingLeft || 0)) + spectrumWidth + 8
    interactive: false
    content.horizontalAlignment: Text.AlignLeft
    clip: true
    AudioSpectrumBars {
        objectName: "mediaSpectrum"
        visible: !media.settings.hideIcon
        x: Math.max(0, 9 + (media.settings.paddingLeft || 0))
        width: 58 * media.spectrumScale
        height: 16 * media.spectrumScale
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2 * media.spectrumScale
        minimumHeight: 2 * media.spectrumScale
        levels: media.levels
        color: media.settings.iconColor || ((media.colorSampler || media.settings.vibrantColor) ? media.effectiveForeground : "#94e2d5")
        variableOpacity: !media.colorSampler
        contrastEdge: media.glyphHalo
        edgeColor: media.iconEdge
    }
}
