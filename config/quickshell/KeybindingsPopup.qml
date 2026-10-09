pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: popup
    property bool opened: false
    property bool pointerReady: false
    onOpenedChanged: { pointerReady = false; if (opened) pointerDelay.restart(); else pointerDelay.stop(); }
    Timer { id: pointerDelay; interval: 150; onTriggered: popup.pointerReady = true }
    visible: opened
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hyprshell-keybindings"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    SystemPalette { id: theme; colorGroup: SystemPalette.Active }
    function containsPoint(x, y) {
        return x >= card.x && x <= card.x + card.width && y >= card.y && y <= card.y + card.height;
    }
    // Opening does not dismiss the popup just because the pointer starts outside.
    // Moving outside subsequently dismisses it and returns focus to the desktop.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: mouse => { if (popup.pointerReady && !popup.containsPoint(mouse.x, mouse.y)) popup.opened = false; }
        onClicked: mouse => { if (!popup.containsPoint(mouse.x, mouse.y)) popup.opened = false; }
    }
    Rectangle {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 8
        width: card.width + 10; height: card.height + 10
        radius: 25; color: "#28000000"
    }
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(520, popup.width - 40)
        height: Math.min(600, popup.height - 40)
        radius: 22
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(theme.window.r, theme.window.g, theme.window.b, 0.96) }
            GradientStop { position: 1; color: Qt.rgba(theme.window.r, theme.window.g, theme.window.b, 0.90) }
        }
        border.color: Qt.rgba(theme.windowText.r, theme.windowText.g, theme.windowText.b, 0.16)
        border.width: 1
        // Consume card clicks so only clicks outside dismiss the popup.
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 18
            RowLayout {
                spacing: 14
                Rectangle {
                    implicitWidth: 44; implicitHeight: 44; radius: 14
                    color: Qt.rgba(theme.highlight.r, theme.highlight.g, theme.highlight.b, 0.14)
                    border.color: Qt.rgba(theme.highlight.r, theme.highlight.g, theme.highlight.b, 0.24)
                    Text { anchors.centerIn: parent; text: "⌘"; color: theme.highlight; font.pixelSize: 25 }
                }
                ColumnLayout {
                    spacing: 3; Layout.fillWidth: true
                    Label { text: "Keyboard shortcuts"; color: theme.windowText; font.family: "Noto Sans"; font.pixelSize: 21; font.weight: Font.DemiBold }
                    Label { text: "Find your next move"; color: theme.windowText; opacity: 0.60; font.family: "Noto Sans"; font.pixelSize: 12 }
                }
                Rectangle {
                    implicitWidth: 36; implicitHeight: 25; radius: 7
                    color: Qt.rgba(theme.windowText.r, theme.windowText.g, theme.windowText.b, 0.06)
                    Text { anchors.centerIn: parent; text: "esc"; color: theme.windowText; opacity: 0.65; font.pixelSize: 11 }
                }
            }
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: popup.opened
                sourceComponent: Component { KeybindingsMenu {} }
            }
        }
    }
    Shortcut { sequence: "Escape"; enabled: popup.opened; onActivated: popup.opened = false }
}
