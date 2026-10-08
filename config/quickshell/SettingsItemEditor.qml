pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var settings
    required property var barSettings
    property bool saving: false
    signal edited(string key, var value)
    signal moveRequested(int direction)
    signal resetRequested()
    spacing: 16
    SettingsCard {
        Layout.fillWidth: true
        title: "Visibility & position"
        subtitle: "Choose where this item belongs in your bar."
        SettingsSwitch {
            Layout.fillWidth: true
            text: "Show in bar"
            checked: root.settings.enabled !== false
            onToggled: root.edited("enabled", checked)
        }
        GridLayout {
            Layout.fillWidth: true
            columns: root.width >= 600 ? 2 : 1
            uniformCellWidths: true
            columnSpacing: 28
            rowSpacing: 16
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Label { text: "Alignment"; color: "#aeb9d2"; font.pixelSize: 12 }
                SettingsComboBox {
                    Layout.fillWidth: true
                    model: ["Left", "Center", "Right"]
                    currentIndex: Math.max(0, ["left", "center", "right"].indexOf(root.settings.side))
                    onActivated: root.edited("side", ["left", "center", "right"][currentIndex])
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Label { text: "Order within group"; color: "#aeb9d2"; font.pixelSize: 12 }
                RowLayout {
                    Layout.fillWidth: true
                    SettingsButton { Layout.fillWidth: true; text: "← Earlier"; onClicked: root.moveRequested(-1) }
                    SettingsButton { Layout.fillWidth: true; text: "Later →"; onClicked: root.moveRequested(1) }
                }
            }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: root.width >= 600 ? 2 : 1
            uniformCellWidths: true
            columnSpacing: 28
            rowSpacing: 20
            Repeater {
                model: [{key: "spacingLeft", label: "Space before"}, {key: "spacingRight", label: "Space after"}]
                delegate: SettingsSlider {
                    required property var modelData
                    objectName: modelData.key + "Control"
                    Layout.fillWidth: true
                    label: modelData.label
                    settingValue: root.settings[modelData.key] ?? 0
                    to: 200; suffix: " px"
                    resetDescription: "Remove extra spacing"
                    onEdited: value => root.edited(modelData.key, value === "" ? 0 : value)
                }
            }
        }
    }
    SettingsCard {
        Layout.fillWidth: true
        title: "Text & icon"
        subtitle: root.settings.id === "tray" ? "Tray artwork is provided by each application. Overrides do not replace it." : "Leave overrides empty to keep the original text and glyph."
        GridLayout {
            Layout.fillWidth: true
            columns: root.width >= 600 ? 2 : 1
            uniformCellWidths: true
            columnSpacing: 28
            rowSpacing: 20
            Repeater {
                model: [{key: "text", label: "Text or glyph"}, {key: "icon", label: "Icon glyph"}]
                delegate: SettingField {
                    required property var modelData
                    objectName: modelData.key + "Control"
                    Layout.fillWidth: true
                    label: modelData.label
                    value: root.settings[modelData.key] || ""
                    hint: "Use original"
                    onEdited: value => root.edited(modelData.key, value)
                }
            }
            SettingsCheckBox { text: "Hide text"; checked: root.settings.hideText || false; onToggled: root.edited("hideText", checked) }
            SettingsCheckBox { text: "Hide icon"; checked: root.settings.hideIcon || false; onToggled: root.edited("hideIcon", checked) }
        }
        SettingsIconSize {
            Layout.fillWidth: true
            individual: true
            settingValue: root.settings.iconSize
            inheritedSize: root.barSettings.iconSize
            onEdited: value => root.edited("iconSize", value)
        }
        SettingsSlider {
            Layout.fillWidth: true
            objectName: "fontSizeControl"
                label: "Text size"
            settingValue: root.settings.fontSize > 0 ? root.settings.fontSize : undefined
            inheritedText: "Original size"
            defaultValue: 13
            from: 1; to: 48; suffix: " px"
            resetDescription: "Restore original text size"
            onEdited: value => root.edited("fontSize", value === "" ? 0 : value)
        }
    }
    SettingsCard {
        Layout.fillWidth: true
        title: "Colors & background"
        subtitle: "Custom colors take priority over wallpaper colors."
        RowLayout {
            Layout.fillWidth: true
            Label { text: "Wallpaper colors"; color: "#e2e6f3"; font.pixelSize: 12; Layout.fillWidth: true }
            SettingsComboBox {
                model: ["Use general setting", "Enabled", "Disabled"]
                currentIndex: Math.max(0, ["inherit", "on", "off"].indexOf(root.settings.adaptiveColors))
                onActivated: root.edited("adaptiveColors", ["inherit", "on", "off"][currentIndex])
            }
        }
        SettingsBackgroundControl {
            Layout.fillWidth: true
            mode: root.settings.background || "inherit"
            inheritedVisible: root.barSettings.background === "on" || (root.barSettings.background !== "off" && root.settings.id !== "launcher" && root.settings.id !== "settings")
            onEdited: mode => root.edited("background", mode)
        }
        GridLayout {
            Layout.fillWidth: true
            columns: root.width >= 600 ? 2 : 1
            uniformCellWidths: true
            columnSpacing: 28
            rowSpacing: 20
            Repeater {
                model: [{key: "textColor", label: "Text color"}, {key: "iconColor", label: "Icon color"}, {key: "backgroundColor", label: "Background color"}, {key: "outlineColor", label: "Outline color"}]
                delegate: SettingField {
                    required property var modelData
                    objectName: modelData.key + "Control"
                    Layout.fillWidth: true
                    label: modelData.label
                    value: root.settings[modelData.key] || ""
                    colorField: true
                    hint: "Default · #RRGGBB"
                    onEdited: value => root.edited(modelData.key, value)
                }
            }
        }
    }
    SettingsCard {
        Layout.fillWidth: true
        title: "Shape & transparency"
        subtitle: "Refine the item's surface and overall visibility."
        GridLayout {
            Layout.fillWidth: true
            columns: root.width >= 600 ? 2 : 1
            uniformCellWidths: true
            columnSpacing: 28
            rowSpacing: 20
            SettingsSlider {
                Layout.fillWidth: true
                objectName: "opacityControl"
                label: "Item opacity"
                settingValue: (root.settings.opacity ?? 1) * 100
                suffix: "%"
                resetDescription: "Restore full opacity"
                onEdited: value => root.edited("opacity", value === "" ? 1 : value / 100)
            }
            SettingsSlider {
                Layout.fillWidth: true
                objectName: "backgroundOpacityControl"
                label: "Background opacity"
                settingValue: root.settings.backgroundOpacity >= 0 ? root.settings.backgroundOpacity * 100 : undefined
                inheritedText: "Original opacity"
                defaultValue: 80; suffix: "%"
                resetDescription: "Restore original background opacity"
                onEdited: value => root.edited("backgroundOpacity", value === "" ? -1 : value / 100)
            }
            SettingsSlider {
                Layout.fillWidth: true
                objectName: "radiusControl"
                label: "Corner radius"
                settingValue: root.settings.radius >= 0 ? root.settings.radius : undefined
                inheritedText: "Original shape"
                defaultValue: 12; to: 50; suffix: " px"
                resetDescription: "Restore original corner radius"
                onEdited: value => root.edited("radius", value === "" ? -1 : value)
            }
        }
    }
    SettingsButton {
        text: "Restore last saved item"
        enabled: !root.saving
        onClicked: root.resetRequested()
        ToolTip.visible: hovered
        ToolTip.text: "Restore this item's last saved settings and position"
    }
}
