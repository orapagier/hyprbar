import QtQuick
import QtQuick.Shapes

Item {
    id: symbol
    property string vectorPath: ""
    property real viewBoxSize: 24
    property real iconSize: 22
    property color accent: "#b4befe"
    property bool highlighted: false
    property bool contrastEdge: false
    property color edgeColor: "transparent"
    implicitWidth: 28; implicitHeight: 28
    scale: highlighted ? 1.06 : 1
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Item {
        width: symbol.iconSize; height: symbol.iconSize
        anchors.centerIn: parent
        Shape {
            visible: symbol.contrastEdge
            width: symbol.viewBoxSize; height: symbol.viewBoxSize
            scale: symbol.iconSize / symbol.viewBoxSize
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillRule: ShapePath.OddEvenFill
                fillColor: "transparent"
                strokeWidth: symbol.viewBoxSize * 0.09
                strokeColor: symbol.edgeColor
                PathSvg { path: symbol.vectorPath }
            }
        }
        // The offset silhouette forms the glass thickness. The same cutouts
        // are retained in every layer, so there is no backing pill.
        Shape {
            x: 0.6; y: 1.2
            width: symbol.viewBoxSize; height: symbol.viewBoxSize
            scale: symbol.iconSize / symbol.viewBoxSize
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillRule: ShapePath.OddEvenFill
                strokeWidth: symbol.viewBoxSize * 0.018
                strokeColor: "#b0081223"
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: symbol.viewBoxSize; y2: symbol.viewBoxSize
                    GradientStop { position: 0; color: Qt.darker(symbol.accent, 1.5) }
                    GradientStop { position: 1; color: Qt.darker(symbol.accent, 3) }
                }
                PathSvg { path: symbol.vectorPath }
            }
        }
        Shape {
            width: symbol.viewBoxSize; height: symbol.viewBoxSize
            scale: symbol.iconSize / symbol.viewBoxSize
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillRule: ShapePath.OddEvenFill
                strokeWidth: symbol.viewBoxSize * 0.018
                strokeColor: Qt.rgba(0.90, 0.96, 1, symbol.highlighted ? 0.95 : 0.75)
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: symbol.viewBoxSize * 0.65; y2: symbol.viewBoxSize
                    GradientStop { position: 0; color: "#f4f9ffff" }
                    GradientStop { position: 0.22; color: Qt.lighter(symbol.accent, symbol.highlighted ? 1.6 : 1.35) }
                    GradientStop { position: 0.46; color: Qt.rgba(symbol.accent.r, symbol.accent.g, symbol.accent.b, 0.72) }
                    GradientStop { position: 0.72; color: Qt.rgba(symbol.accent.r * 0.5, symbol.accent.g * 0.5, symbol.accent.b * 0.5, 0.85) }
                    GradientStop { position: 1; color: "#e0daeaff" }
                }
                PathSvg { path: symbol.vectorPath }
            }

        }
    }
}
