pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var settings
    signal edited(string key, var value)
    spacing: 16
    SettingsCard {
        Layout.fillWidth: true
        title: "Layout & spacing"
        subtitle: "Give your bar room to breathe. Drag items in the preview to arrange them."
        GridLayout {
            Layout.fillWidth: true
            columns: root.width >= 600 ? 2 : 1
            uniformCellWidths: true
            columnSpacing: 28
            rowSpacing: 20
            Repeater {
                model: [
                    {key: "height", label: "Bar height", min: 28, max: 80, fallback: 32},
                    {key: "spacing", label: "Between items", min: 0, max: 30, fallback: 3},
                    {key: "marginTop", label: "Top margin", min: 0, max: 100, fallback: 5},
                    {key: "marginSide", label: "Side margins", min: 0, max: 200, fallback: 10}
                ]
                delegate: SettingsSlider {
                    required property var modelData
                    objectName: modelData.key + "Control"
                    Layout.fillWidth: true
                    label: modelData.label
                    settingValue: root.settings[modelData.key]
                    from: modelData.min; to: modelData.max; suffix: " px"
                    resetDescription: "Restore default " + modelData.label.toLowerCase()
                    onEdited: value => root.edited(modelData.key, value === "" ? modelData.fallback : value)
                }
            }
        }
    }
    SettingsCard {
        Layout.fillWidth: true
        title: "Default appearance"
        subtitle: "Choose a shared style. Individual items can override these settings."
        SettingsSwitch {
            Layout.fillWidth: true
            text: "Adapt colors to wallpaper"
            checked: root.settings.adaptiveColors
            onToggled: root.edited("adaptiveColors", checked)
        }
        SettingsBackgroundControl {
            Layout.fillWidth: true
            switchText: "Show background pills"
            mode: root.settings.background || "inherit"
            inheritLabel: "Use originals"
            inheritDescription: "Original backgrounds · the launcher and settings icons have no pill."
            onEdited: mode => root.edited("background", mode)
        }
        SettingsIconSize {
            Layout.fillWidth: true
            settingValue: root.settings.iconSize
            onEdited: value => root.edited("iconSize", value)
        }
    }
    SettingsCard {
        Layout.fillWidth: true
        title: "Clock & date"
        subtitle: "Choose how the time and date appear on your bar."
        SettingField {
            Layout.fillWidth: true
            label: "Clock format"
            hint: "MMM dd   hh:mm AP   ddd"
            description: "Qt date format · hh:mm for time, ddd for weekday, MMM dd for date."
            value: root.settings.clockFormat
            onEdited: value => root.edited("clockFormat", value)
        }
        Label {
            Layout.fillWidth: true
            text: "Preview   " + Qt.formatDateTime(new Date(), root.settings.clockFormat)
            color: "#b9afd9"
            font.pixelSize: 13
            wrapMode: Text.Wrap
        }
    }
}
