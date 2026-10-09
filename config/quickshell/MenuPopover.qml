pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts

Item {
    id: popover
    property url wallpaperSource: ""
    property real translucency: 0.06
    GlassSurface {
        id: glass
        wallpaperSource: popover.wallpaperSource
        screenWidth: popover.width; screenHeight: popover.height
        region: Qt.rect(popover.bodyX, popover.bodyY, popover.bodyWidth, popover.bodyHeight)
        accent: popover.accent; translucency: popover.translucency
    }
    property rect triggerRect: Qt.rect(12, 4, 32, 20)
    property string alignment: "center"
    property color accent: "#b4befe"
    property string title: ""
    property string symbol: ""
    property Component page: null
    readonly property alias pageItem: pageLoader.item
    property bool opened: false
    property bool cardClickable: false
    property bool connected: true
    readonly property bool rendering: opened || surface.opacity > 0
    signal hoverChanged(bool inside)
    signal cardClicked()
    readonly property real bodyWidth: Math.min(300, width - 24)
    // Anchor the card to its bar group; the funnel still follows the icon.
    readonly property real bodyX: alignment === "left" ? 12
        : alignment === "right" ? width - bodyWidth - 12
        : (width - bodyWidth) / 2
    readonly property real neckY: triggerRect.y + triggerRect.height - 1
    readonly property real bodyY: connected ? neckY + 34 : Math.max(48, triggerRect.y + triggerRect.height + 12)
    readonly property real bodyHeight: Math.min(height - bodyY - 16, contents.implicitHeight + 36)
    readonly property real bodyRight: bodyX + bodyWidth
    readonly property real bodyBottom: bodyY + bodyHeight
    readonly property real tipX: triggerRect.x + triggerRect.width / 2
    readonly property real neckHalfWidth: 0.75
    readonly property real attachmentHalfWidth: 8
    readonly property real waistY: neckY + 7
    readonly property real shoulder: Math.max(bodyX + 52, Math.min(bodyRight - 52, triggerRect.x + triggerRect.width / 2))
    readonly property bool pointerInside: opened && tracking.hovered && containsPointer(tracking.point.position)

    function containsPointer(point) {
        if (point.y >= bodyY && point.y <= bodyBottom && point.x >= bodyX && point.x <= bodyRight)
            return true;
        if (!connected) return false;
        // A forgiving bridge lets the pointer travel diagonally into the menu.
        return point.y >= neckY - 4 && point.y < bodyY + (connected ? 0 : 14)
            && point.x >= Math.min(triggerRect.x - 12, bodyX)
            && point.x <= Math.max(triggerRect.x + triggerRect.width + 12, bodyRight);
    }
    onPointerInsideChanged: hoverChanged(pointerInside)
    HoverHandler { id: tracking }

    Item {
        id: surface
        anchors.fill: parent
        opacity: 0
        transform: Translate { id: arrival; y: -8 }
        states: State {
            name: "open"; when: popover.opened
            PropertyChanges { surface.opacity: 1; arrival.y: 0 }
        }
        transitions: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; duration: 140; easing.type: Easing.OutCubic }
                NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic }
            }
        }
        Rectangle {
            x: popover.bodyX + 3; y: popover.bodyY + 7
            width: popover.bodyWidth; height: popover.bodyHeight
            radius: 20; color: "#28000000"
        }
        Shape {
            visible: popover.connected
            objectName: "menuFunnel"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 1
                strokeColor: glass.rimColor
                fillGradient: LinearGradient {
                    x1: 0; y1: popover.neckY; x2: 0; y2: popover.bodyBottom
                    GradientStop { position: 0; color: glass.rimColor }
                    GradientStop { position: 0.23; color: glass.topColor }
                    GradientStop { position: 1; color: glass.bottomColor }
                }
                startX: popover.tipX - popover.attachmentHalfWidth; startY: popover.neckY
                PathLine { x: popover.tipX + popover.attachmentHalfWidth; y: popover.neckY }
                PathCubic {
                    control1X: popover.tipX + popover.neckHalfWidth; control1Y: popover.neckY + 1
                    control2X: popover.tipX + popover.neckHalfWidth; control2Y: popover.waistY - 3
                    x: popover.tipX + popover.neckHalfWidth; y: popover.waistY
                }
                PathCubic {
                    control1X: popover.tipX + popover.neckHalfWidth; control1Y: popover.waistY + 12
                    control2X: popover.shoulder + 12; control2Y: popover.bodyY
                    x: popover.shoulder + 36; y: popover.bodyY
                }
                PathLine { x: popover.bodyRight - 18; y: popover.bodyY }
                PathQuad { controlX: popover.bodyRight; controlY: popover.bodyY; x: popover.bodyRight; y: popover.bodyY + 18 }
                PathLine { x: popover.bodyRight; y: popover.bodyBottom - 18 }
                PathQuad { controlX: popover.bodyRight; controlY: popover.bodyBottom; x: popover.bodyRight - 18; y: popover.bodyBottom }
                PathLine { x: popover.bodyX + 18; y: popover.bodyBottom }
                PathQuad { controlX: popover.bodyX; controlY: popover.bodyBottom; x: popover.bodyX; y: popover.bodyBottom - 18 }
                PathLine { x: popover.bodyX; y: popover.bodyY + 18 }
                PathQuad { controlX: popover.bodyX; controlY: popover.bodyY; x: popover.bodyX + 18; y: popover.bodyY }
                PathLine { x: popover.shoulder - 36; y: popover.bodyY }
                PathCubic {
                    control1X: popover.shoulder - 12; control1Y: popover.bodyY
                    control2X: popover.tipX - popover.neckHalfWidth; control2Y: popover.waistY + 12
                    x: popover.tipX - popover.neckHalfWidth; y: popover.waistY
                }
                PathCubic {
                    control1X: popover.tipX - popover.neckHalfWidth; control1Y: popover.waistY - 3
                    control2X: popover.tipX - popover.neckHalfWidth; control2Y: popover.neckY + 1
                    x: popover.tipX - popover.attachmentHalfWidth; y: popover.neckY
                }
            }
        }
        Rectangle {
            visible: !popover.connected
            objectName: "detachedMenuCard"
            x: popover.bodyX; y: popover.bodyY
            width: popover.bodyWidth; height: popover.bodyHeight
            radius: 20
            border.width: 1
            border.color: glass.rimColor
            gradient: Gradient {
                GradientStop { position: 0; color: glass.topColor }
                GradientStop { position: 1; color: glass.bottomColor }
            }
            Rectangle {
                x: 20; y: 1; width: parent.width - 40; height: 1
                color: Qt.rgba(popover.accent.r, popover.accent.g, popover.accent.b, 0.28)
            }
        }
        MouseArea {
            x: popover.bodyX; y: popover.connected ? popover.neckY : popover.bodyY
            width: popover.bodyWidth; height: popover.bodyBottom - y
            enabled: popover.opened
            cursorShape: popover.cardClickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (popover.cardClickable) popover.cardClicked()
        }
        ColumnLayout {
            id: contents
            x: popover.bodyX + 18; y: popover.bodyY + 18
            width: popover.bodyWidth - 36
            spacing: 12
            RowLayout {
                spacing: 10
                Rectangle {
                    width: 30; height: 30; radius: 10
                    color: Qt.rgba(popover.accent.r, popover.accent.g, popover.accent.b, 0.14)
                    border.color: Qt.rgba(popover.accent.r, popover.accent.g, popover.accent.b, 0.25)
                    Text { anchors.centerIn: parent; text: popover.symbol; color: popover.accent; font.family: "GoMono Nerd Font"; font.pixelSize: 17 }
                }
                MenuLabel { text: popover.title; color: popover.accent; font.bold: true; font.pixelSize: 15; Layout.fillWidth: true }
                Rectangle { width: 5; height: 5; radius: 3; color: popover.accent; opacity: 0.7 }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(popover.accent.r, popover.accent.g, popover.accent.b, 0.15) }
            Loader { id: pageLoader; Layout.fillWidth: true; active: popover.rendering; sourceComponent: popover.page }
        }
    }
}
