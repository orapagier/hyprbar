import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: control
    property bool individual: false
    property var settingValue: 0
    property int inheritedSize: 0
    signal edited(var value)
    SettingsSlider {
        Layout.fillWidth: true
        label: control.individual ? "Icon size for this item" : "Icon size for all items"
        from: 8; to: 48; suffix: " px"
        settingValue: control.settingValue > 0 ? control.settingValue : undefined
        inheritedText: control.individual ? "Use global" : "Original sizes"
        defaultValue: control.inheritedSize || 16
        resetDescription: control.individual ? "Use the global icon size" : "Restore original icon sizes"
        description: control.individual ? "Overrides the global icon size. ↺ follows the global setting again. Text keeps its own font size." : "Resize glyphs, glass icons, tray artwork, and the media spectrum. Individual sizes take priority. The bar grows to fit larger icons."
        onEdited: value => control.edited(value === "" ? 0 : value)
    }
}
