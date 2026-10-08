import QtQuick
import Quickshell.Services.SystemTray

QtObject {
    readonly property var items: SystemTray.items.values
}
