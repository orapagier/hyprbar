import QtQuick

Item {
    id: pill
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
    readonly property bool hovered: pointer.containsMouse
    property bool selected: false
    property color hoverTint: tint
    property alias content: label
    signal clicked(var mouse)
    signal wheel(var event)
    signal entered()
    signal exited()
    readonly property int iconWidth: icon.length ? iconSize + 5 : 0
    implicitWidth: Math.min(maximumWidth, Math.max(minimumTextWidth, label.implicitWidth) + iconWidth + leftPadding + rightPadding)
    implicitHeight: 28
    Rectangle {
        visible: pill.backgroundVisible
        anchors.fill: parent
        radius: height / 2
        color: pill.adaptivePalette
            ? (pill.selected ? pill.adaptivePalette.selected : pointer.containsMouse ? pill.adaptivePalette.hover : pill.adaptivePalette.tint)
            : pill.selected ? Qt.rgba(pill.foreground.r, pill.foreground.g, pill.foreground.b, 0.32) : pointer.containsMouse ? pill.hoverTint : pill.tint
        Behavior on color { ColorAnimation { duration: 200 } }
        border.width: 1
        border.color: pill.adaptivePalette ? (pill.selected ? pill.adaptivePalette.selectedOutline : pill.adaptivePalette.outline)
            : pill.selected ? Qt.rgba(pill.foreground.r, pill.foreground.g, pill.foreground.b, 0.65) : pill.outline
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: height / 2
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
        width: pill.iconSize
        visible: pill.icon.length > 0
        text: pill.icon
        color: pill.effectiveForeground
        font.family: "GoMono Nerd Font"; font.pixelSize: pill.iconSize
        horizontalAlignment: Text.AlignHCenter
        renderType: Text.NativeRendering
    }
    Text {
        id: label
        x: pill.leftPadding + pill.iconWidth
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - pill.leftPadding - pill.rightPadding - pill.iconWidth
        text: pill.text
        textFormat: pill.textFormat
        color: pill.effectiveForeground
        font.family: pill.family
        font.pixelSize: pill.pixelSize
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
