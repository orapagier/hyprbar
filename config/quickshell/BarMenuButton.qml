import QtQuick
import "SettingsModel.js" as Settings

Pill {
    id: control
    required property var bar
    required property string menu
    objectName: menu + "Trigger"
    colorSampler: Settings.adaptive(bar.settings, menu) ? bar.wallpaperColors : null
    colorRoot: bar
    selected: bar.activeMenu === menu
    onEntered: bar.menuHovered(menu)
    onExited: bar.menuLeft(menu)
    onClicked: bar.action(menu, null)
}
