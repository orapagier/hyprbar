pragma ComponentBehavior: Bound
import QtQuick
import "SettingsStyle.js" as Style
import QtQuick.Controls.Basic
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var settings
    signal edited(string key, var value)
    spacing: 16
    SettingsCard {
        Layout.fillWidth: true
        title: "Topbar visibility"
        subtitle: "Hide the topbar to give windows its screen space, or show it only on chosen workspaces. Open Hyprshell Settings from the application launcher to show it again."
        SettingsSwitch {
            objectName: "barVisibleControl"
            Layout.fillWidth: true
            text: "Show topbar"
            checked: root.settings.visible !== false
            onToggled: root.edited("visible", checked)
        }
        Label {
            Layout.fillWidth: true
            text: "Workspaces"
            color: Style.text
            font.pixelSize: Style.bodySize
        }
        SettingsComboBox {
            objectName: "barWorkspaceScopeControl"
            Layout.fillWidth: true
            model: ["All workspaces", "Selected workspaces"]
            currentIndex: (root.settings.workspaceScope || "all") === "selected" ? 1 : 0
            onActivated: index => {
                root.edited("workspaceScope", index === 1 ? "selected" : "all");
                if (index === 1 && (!root.settings.workspaceList || root.settings.workspaceList.length === 0))
                    root.edited("workspaceList", [1]);
            }
        }
        TextField {
            id: workspaceListField
            objectName: "barWorkspaceListControl"
            Layout.fillWidth: true
            visible: (root.settings.workspaceScope || "all") === "selected"
            implicitHeight: 42
            hoverEnabled: true
            leftPadding: 14; rightPadding: 14
            Accessible.name: "Workspace numbers"
            color: "#e0e5f4"
            font.pixelSize: Style.bodySize
            selectionColor: Style.selection
            selectedTextColor: "#ffffff"
            placeholderText: "Workspace numbers (for example 1,2,3)"
            placeholderTextColor: Style.muted
            selectByMouse: true
            text: (root.settings.workspaceList || []).join(",")
            background: Rectangle {
                radius: Style.controlRadius
                color: workspaceListField.activeFocus ? Style.field : workspaceListField.hovered ? Style.hover : Style.field
                border.width: workspaceListField.activeFocus ? 2 : 1
                border.color: workspaceListField.activeFocus ? Style.accentText : Style.controlBorder
                Behavior on color { ColorAnimation { duration: 130 } }
            }
            onEditingFinished: {
                let parts = text.split(",").map(s => s.trim()).filter(s => s.length > 0);
                let numbers = parts.map(s => Number(s));
                if (parts.length === 0 || numbers.some(n => !Number.isInteger(n) || n < 1 || n > 99)) return;
                numbers = [...new Set(numbers)];
                if (JSON.stringify(numbers) !== JSON.stringify(root.settings.workspaceList || []))
                    root.edited("workspaceList", numbers);
            }
        }
        Label {
            Layout.fillWidth: true
            visible: (root.settings.workspaceScope || "all") === "selected"
            text: "The topbar appears only when one of these workspaces is active on that screen. Changes save after you leave the field."
            wrapMode: Text.WordWrap
            color: Style.muted
            font.pixelSize: Style.captionSize
        }
    }
    SettingsCard {
        Layout.fillWidth: true
        title: "Popdown glass"
        subtitle: "Keep a dense glass finish. Higher translucency reveals more of the background; text stays fully visible. Also applies to Super+K."
        SettingsSlider {
            Layout.fillWidth: true
            objectName: "popdownTranslucencyControl"
            label: "Popdown translucency"
            settingValue: (root.settings.popdownTranslucency ?? 0.06) * 100
            suffix: "%"
            resetDescription: "Restore subtle glass (6%)"
            onEdited: value => root.edited("popdownTranslucency", value === "" ? 0.06 : value / 100)
        }
    }
    SettingsCard {
        Layout.fillWidth: true
        title: "Layout & spacing"
        subtitle: "Set the global gap here. Select a module in the sidebar or preview to adjust its individual spacing."
        GridLayout {
            Layout.fillWidth: true
            columns: root.width >= 600 ? 2 : 1
            uniformCellWidths: true
            columnSpacing: 28
            rowSpacing: 20
            Repeater {
                model: [
                    {key: "height", label: "Bar height", min: 28, max: 80, fallback: 32},
                    {key: "groupSpacing", label: "Inside shared pills", min: 0, max: 30, fallback: 3},
                    {key: "spacing", label: "Between items / pills", min: 0, max: 30, fallback: 3},
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
        SettingsSwitch {
            objectName: "randomVibrantColorsControl"
            Layout.fillWidth: true
            text: "Random vibrant item colors"
            checked: root.settings.randomVibrantColors === true
            onToggled: root.edited("randomVibrantColors", checked)
        }
        Label {
            Layout.fillWidth: true
            text: "Give each item a bright color. Colors reshuffle when the wallpaper changes and stay readable. Turn off to use the current theme. Individual colors and wallpaper choices take priority."
            wrapMode: Text.WordWrap
            color: Style.muted
            font.pixelSize: Style.captionSize
        }
        SettingsBackgroundControl {
            Layout.fillWidth: true
            switchText: "Show background pills"
            mode: root.settings.background || "inherit"
            inheritLabel: "Use originals"
            inheritDescription: "Original backgrounds · the launcher and settings icons have no pill."
            onEdited: mode => root.edited("background", mode)
        }
        SettingsBackgroundControl {
            objectName: "sharedBackgroundControl"
            Layout.fillWidth: true
            switchText: "Show shared (common) pills"
            mode: root.settings.sharedBackground || "inherit"
            inheritedVisible: root.settings.background !== "off"
            inheritLabel: "Follow background pills"
            inheritDescription: "Shared pills follow the background switch above. Modules keep their grouping and spacing when the pill is hidden."
            onEdited: mode => root.edited("sharedBackground", mode)
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
            color: Style.accentText
            font.pixelSize: Style.bodySize
            wrapMode: Text.Wrap
        }
    }
}
