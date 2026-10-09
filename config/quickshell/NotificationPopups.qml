pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window
    required property var inbox
    // One stack avoids duplicating alerts on every monitor.
    visible: inbox.popups.length > 0
    anchors { top: true; right: true }
    margins { top: 52; right: 16 }
    implicitWidth: screen ? Math.min(380, screen.width - 32) : 380
    implicitHeight: stack.implicitHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "hyprshell-notifications"
    NotificationPopupStack {
        id: stack
        anchors.left: parent.left; anchors.right: parent.right
        inbox: window.inbox
    }
}
