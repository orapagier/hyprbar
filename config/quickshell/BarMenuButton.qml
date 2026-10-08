import QtQuick

Pill {
    id: control
    required property var bar
    required property string menu
    objectName: menu + "Trigger"
    colorSampler: bar.wallpaperColors
    colorRoot: bar
    selected: bar.activeMenu === menu
    onEntered: bar.menuHovered(menu)
    onExited: bar.menuLeft(menu)
    onClicked: bar.action(menu, null)
}
