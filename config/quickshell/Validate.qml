pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell

ShellRoot {
    id: check
    readonly property var desktop: services
    readonly property var notificationStore: inbox
    DesktopServices { id: services }
    NotificationInbox { id: inbox }
    Window {
        id: preview
        visible: true; width: 1400; height: 680
        Rectangle { anchors.fill: parent; color: "#26293e" }
        Bar {
            id: bar
            x: 10; y: 5; width: parent.width - 20
            clockText: "Oct 08   12:34 PM   Thu"
            statusData: services.statusData
            mediaData: services.mediaData
            notificationData: inbox.statusData
        }
        Row {
            y: 50; spacing: 12
            Rectangle {
                width: 290; height: 580; radius: 16; color: "#471e1e2e"; border.color: "#29ffffff"
                CalendarMenu { x: 18; y: 18; width: parent.width - 36 }
            }
            Rectangle {
                width: 290; height: 580; radius: 16; color: "#471e1e2e"; border.color: "#29ffffff"
                Column {
                    x: 18; y: 18; width: parent.width - 36; spacing: 20
                    AudioMenu { width: parent.width; services: check.desktop }
                    WifiMenu { width: parent.width; services: check.desktop }
                    BluetoothMenu { width: parent.width; services: check.desktop }
                }
            }
            Rectangle {
                width: 290; height: 580; radius: 16; color: "#471e1e2e"; border.color: "#29ffffff"
                InboxMenu { x: 18; y: 18; width: parent.width - 36; inbox: check.notificationStore }
            }
            Rectangle {
                width: 290; height: 580; radius: 16; color: "#471e1e2e"; border.color: "#29ffffff"
                Column { x: 18; y: 18; width: parent.width - 36; spacing: 20; PowerMenu { width: parent.width } LauncherMenu { width: parent.width } }
            }
        }
    }
    Timer {
        interval: 1000; running: true
        onTriggered: {
            preview.contentItem.grabToImage(result => { result.saveToFile("/tmp/quickshell-native-menus.png"); Qt.quit(); });
        }
    }
}
