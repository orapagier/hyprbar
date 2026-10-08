import QtQuick

Item {
    id: pill
    property var settings: ({})
    readonly property string shownText: settings.hideText ? "" : settings.text || text
    readonly property string shownIcon: settings.hideIcon ? "" : settings.icon || icon
    readonly property color textColor: settings.textColor || (family === "GoMono Nerd Font" ? settings.iconColor : "") || effectiveForeground
    readonly property color iconColor: settings.iconColor || effectiveForeground
    function styledBackground(base) {
        let c = settings.backgroundColor ? Qt.color(settings.backgroundColor) : base;
        return Qt.rgba(c.r, c.g, c.b, settings.backgroundOpacity >= 0 ? settings.backgroundOpacity : base.a);
    }
    property string text: ""
    property string icon: ""
    property int iconSize: 16
    property color foreground: "#cdd6f4"
    property var colorSampler: null
    property Item colorRoot: null
    property string colorStyle: "normal"
    readonly property var adaptivePalette: colorSampler ? colorSampler.paletteFor(pill, colorRoot, foreground, colorStyle) : null
    readonly property color effectiveForeground: adaptivePalette ? adaptivePalette.foreground : foreground
    property color tint: Qt.rgba(30/255, 30/255, 46/255, 0.28)
    property color outline: Qt.rgba(1, 1, 1, 0.16)
    property string family: "DejaVu Sans"
    property int pixelSize: 12
    property bool bold: true
    property int leftPadding: 11
    property int rightPadding: 11
    property int minimumTextWidth: 0
    property int maximumWidth: 10000
    property int textFormat: Text.PlainText
    property bool interactive: true
    property bool raised: true
    property bool backgroundVisible: true
    readonly property bool backgroundShown: settings.background === "on" || (settings.background !== "off" && backgroundVisible)
    readonly property bool hovered: pointer.containsMouse
    property bool selected: false
    property color hoverTint: tint
    property alias content: label
    signal clicked(var mouse)
    signal wheel(var event)
    signal entered()
    signal exited()
    readonly property bool labelIsIcon: family === "GoMono Nerd Font"
    readonly property int effectiveIconSize: settings.iconSize || settings.fontSize || iconSize
    readonly property int effectiveGlyphSize: settings.iconSize || settings.fontSize || pixelSize
    readonly property int iconWidth: shownIcon.length ? effectiveIconSize + 5 : 0
    implicitWidth: Math.min(maximumWidth, Math.max(minimumTextWidth, label.implicitWidth) + iconWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(28, shownIcon.length ? effectiveIconSize + 8 : 0, labelIsIcon && shownText.length ? effectiveGlyphSize + 8 : 0)
    Rectangle {
        visible: pill.backgroundShown
        anchors.fill: parent
        radius: pill.settings.radius >= 0 ? pill.settings.radius : height / 2
        color: pill.styledBackground(pill.adaptivePalette
            ? (pill.selected ? pill.adaptivePalette.selected : pointer.containsMouse ? pill.adaptivePalette.hover : pill.adaptivePalette.tint)
            : pill.selected ? Qt.rgba(pill.foreground.r, pill.foreground.g, pill.foreground.b, 0.32) : pointer.containsMouse ? pill.hoverTint : pill.tint)
        Behavior on color { ColorAnimation { duration: 200 } }
        border.width: 1
        border.color: pill.settings.outlineColor || (pill.adaptivePalette ? (pill.selected ? pill.adaptivePalette.selectedOutline : pill.adaptivePalette.outline)
            : pill.selected ? Qt.rgba(pill.foreground.r, pill.foreground.g, pill.foreground.b, 0.65) : pill.outline)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius
            visible: pill.raised
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.08) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Rectangle {
            x: 6; y: 1; width: parent.width - 12; height: 1
            visible: pill.raised
            color: Qt.rgba(1, 1, 1, 0.10)
        }
    }
    Text {
        x: pill.leftPadding
        anchors.verticalCenter: parent.verticalCenter
        objectName: "pillIcon"
        width: pill.effectiveIconSize
        visible: pill.shownIcon.length > 0
        text: pill.shownIcon
        color: pill.iconColor
        font.family: "GoMono Nerd Font"; font.pixelSize: pill.effectiveIconSize
        horizontalAlignment: Text.AlignHCenter
        renderType: Text.NativeRendering
    }
    Text {
        id: label
        x: pill.leftPadding + pill.iconWidth
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - pill.leftPadding - pill.rightPadding - pill.iconWidth
        text: pill.shownText
        textFormat: pill.textFormat
        color: pill.textColor
        font.family: pill.family
        font.pixelSize: pill.labelIsIcon ? pill.effectiveGlyphSize : pill.settings.fontSize || pill.pixelSize
        font.bold: pill.bold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        renderType: Text.NativeRendering
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: pill.interactive ? Qt.LeftButton | Qt.RightButton | Qt.MiddleButton : Qt.NoButton
        cursorShape: pill.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onEntered: pill.entered()
        onExited: pill.exited()
        onClicked: mouse => pill.clicked(mouse)
        onWheel: event => pill.wheel(event)
    }
}
