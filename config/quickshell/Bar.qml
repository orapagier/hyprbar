pragma ComponentBehavior: Bound
import QtQuick
import "SettingsModel.js" as Settings

Item {
    id: bar
    property var settings: ({})
    readonly property var moduleItems: ({
            launcher: arch,
            settings: settingsCog,
            workspaces: workspaceRow,
            media: mediaSlot,
            calendar: clock,
            tray: trayPill,
            notifications: bell,
            audio: audio,
            wifi: wifi,
            bluetooth: bluetooth,
            battery: battery,
            power: power
        })
    readonly property var defaultSides: ({
            launcher: "left",
            settings: "left",
            workspaces: "left",
            media: "left",
            calendar: "center"
        })
    function itemEnabled(id) {
        return Settings.item(settings, id).enabled !== false;
    }
    function side(id) {
        return Settings.item(settings, id).side || defaultSides[id] || "right";
    }
    function itemX(id) {
        let keys = Object.keys(moduleItems);
        let group = keys.filter(k => side(k) === side(id) && moduleItems[k].visible);
        group.sort((a, b) => ((Settings.item(settings, a).order ?? keys.indexOf(a)) - (Settings.item(settings, b).order ?? keys.indexOf(b))) || keys.indexOf(a) - keys.indexOf(b));
        let spacing = settings.bar ? (settings.bar.spacing ?? 3) : 3;
        let left = k => Settings.item(settings, k).spacingLeft || 0;
        let right = k => Settings.item(settings, k).spacingRight || 0;
        let total = group.reduce((n, k) => n + left(k) + moduleItems[k].width + right(k), 0) + Math.max(0, group.length - 1) * spacing;
        let cursor = side(id) === "right" ? width - total : side(id) === "center" ? (width - total) / 2 : 0;
        for (let k of group) {
            if (k === id)
                return cursor + left(k);
            cursor += left(k) + moduleItems[k].width + right(k) + spacing;
        }
        return cursor;
    }
    property var statusData: ({
            workspaces: [],
            audio: {},
            network: {},
            bluetooth: {},
            battery: {}
        })
    property var mediaData: ({
            playing: false,
            levels: [],
            title: "",
            tooltip: ""
        })
    property var notificationData: ({
            count: 0,
            tooltip: "Notifications",
            class: "empty"
        })
    property string outputName: ""
    property url wallpaperSource: ""
    property real screenWidth: width + 20
    property real screenHeight: 768
    property real screenOffsetX: 10
    property real screenOffsetY: 5
    readonly property alias wallpaperColors: wallpaperSampler
    WallpaperColors {
        id: wallpaperSampler
        source: bar.wallpaperSource
        screenWidth: bar.screenWidth
        screenHeight: bar.screenHeight
        offsetX: bar.screenOffsetX
        offsetY: bar.screenOffsetY
        bandHeight: bar.height
    }
    property var trayModel: []
    property string clockText: ""
    property string activeMenu: ""
    signal menuHovered(string name)
    signal menuLeft(string name)
    readonly property var menuTargets: ({
            launcher: arch,
            settings: settingsCog,
            calendar: clock,
            notifications: bell,
            audio: audio,
            wifi: wifi,
            bluetooth: bluetooth,
            battery: battery,
            power: power
        })
    function menuRect(name) {
        let item = menuTargets[name];
        if (!item)
            return Qt.rect(12, 2, 24, 20);
        // Read layout positions directly so the connector follows screen and
        // status-width changes, including movement of the containing row.
        return Qt.rect(item.x, item.y, item.width, item.height);
    }
    function menuAccent(name) {
        return menuTargets[name] ? menuTargets[name].foreground : "#b4befe";
    }
    signal action(string name, var argument)
    signal trayAction(var item, var source, int button)
    signal trayScroll(var item, var event)
    function rgba(hex, alpha) {
        return Qt.rgba(parseInt(hex.slice(1, 3), 16) / 255, parseInt(hex.slice(3, 5), 16) / 255, parseInt(hex.slice(5, 7), 16) / 255, alpha);
    }
    implicitHeight: Math.max(settings.bar ? (settings.bar.height || 32) : 32,
        ...Object.keys(moduleItems).filter(id => moduleItems[id].visible).map(id => moduleItems[id].height + 4))
    height: implicitHeight
    BarMenuButton {
        id: arch
        bar: bar
        menu: "launcher"
        x: bar.itemX("launcher")
        y: (bar.height - height) / 2
        settings: Settings.appearance(bar.settings, "launcher")
        opacity: Settings.item(bar.settings, "launcher").opacity ?? 1
        visible: bar.itemEnabled("launcher")
        text: ""
        foreground: "#1793d1"
        family: "GoMono Nerd Font"
        pixelSize: 20
        bold: false
        minimumTextWidth: Math.max(28, (settings.iconSize || settings.fontSize || 22) + 6)
        implicitHeight: Math.max(28, (settings.iconSize || settings.fontSize || 22) + 6)
        leftPadding: 5
        rightPadding: 2
        backgroundVisible: false
        content.opacity: arch.settings.text || arch.settings.icon ? 1 : 0
        GlassLogo {
            objectName: "archGlassLogo"
            iconSize: arch.settings.iconSize || arch.settings.fontSize || 22
            visible: !arch.settings.text && !arch.settings.icon && !arch.settings.hideText && !arch.settings.hideIcon
            x: arch.content.x
            width: arch.content.width
            height: arch.height
            accent: arch.settings.iconColor || arch.settings.textColor || arch.effectiveForeground
            highlighted: arch.hovered || arch.selected
        }
    }
    BarMenuButton {
        id: settingsCog
        bar: bar; menu: "settings"
        x: bar.itemX("settings"); y: (bar.height - height) / 2
        settings: Settings.appearance(bar.settings, "settings")
        opacity: settings.opacity ?? 1
        visible: bar.itemEnabled("settings")
        text: "󰒓"
        family: "GoMono Nerd Font"; pixelSize: 16
        backgroundVisible: false
        minimumTextWidth: Math.max(16, settings.iconSize || settings.fontSize || 22)
        implicitHeight: Math.max(28, (settings.iconSize || settings.fontSize || 22) + 6)
        content.opacity: settingsCog.settings.text || settingsCog.settings.icon ? 1 : 0
        GlassCog {
            objectName: "settingsGlassCog"
            iconSize: settingsCog.settings.iconSize || settingsCog.settings.fontSize || 22
            visible: !settingsCog.settings.text && !settingsCog.settings.icon && !settingsCog.settings.hideText && !settingsCog.settings.hideIcon
            x: settingsCog.content.x; width: settingsCog.content.width; height: settingsCog.height
            accent: settingsCog.settings.iconColor || settingsCog.settings.textColor || settingsCog.effectiveForeground
            highlighted: settingsCog.hovered || settingsCog.selected
        }
        foreground: "#b4befe"
        tint: bar.rgba("#b4befe", 0.18); outline: bar.rgba("#b4befe", 0.26)
        leftPadding: 8; rightPadding: 8
    }
    Row {
        id: workspaceRow
        x: bar.itemX("workspaces")
        y: (bar.height - height) / 2
        opacity: Settings.item(bar.settings, "workspaces").opacity ?? 1
        visible: bar.itemEnabled("workspaces")
        objectName: "workspacesSlot"
        height: Math.max(28, ...Array.from(children).map(child => child.height || 0))
        spacing: 2
        leftPadding: 1
        rightPadding: 3
        Repeater {
            model: (bar.statusData.workspaces || []).filter(w => !bar.outputName || w.monitor === bar.outputName)
            delegate: Pill {
                objectName: "workspace" + modelData.id
                settings: Settings.appearance(bar.settings, "workspaces")
                colorSampler: Settings.adaptive(bar.settings, "workspaces") ? bar.wallpaperColors : null
                colorRoot: bar
                required property var modelData
                property bool active: modelData.active || false
                anchors.verticalCenter: workspaceRow.verticalCenter
                height: settings.iconSize && shownIcon.length ? Math.max(20, effectiveIconSize + 6) : 20
                text: modelData.name || String(modelData.id)
                leftPadding: 7
                rightPadding: 7
                foreground: active ? "#cba6f7" : "#a0a0a0"
                colorStyle: active ? "emphasized" : "muted"
                selected: active
                raised: false
                onClicked: bar.action("workspace", modelData.id)
                onWheel: event => bar.action("workspace-scroll", event.angleDelta.y > 0 ? -1 : 1)
            }
        }
    }
    Loader {
        id: mediaSlot
        objectName: "mediaSlot"
        x: bar.itemX("media")
        y: (bar.height - height) / 2
        opacity: Settings.item(bar.settings, "media").opacity ?? 1
        active: bar.itemEnabled("media") && !!bar.mediaData && bar.mediaData.playing === true
        visible: active
        sourceComponent: MediaPill {
            settings: Settings.appearance(bar.settings, "media")
            colorSampler: Settings.adaptive(bar.settings, "media") ? bar.wallpaperColors : null
            colorRoot: bar
            text: bar.mediaData.title || ""
            levels: bar.mediaData.levels || []
            maximumWidth: Math.max(80, Math.min(300, bar.width * 0.24))
            interactive: false
        }
    }
    BarMenuButton {
        id: clock
        bar: bar
        menu: "calendar"
        x: bar.itemX("calendar")
        y: (bar.height - height) / 2
        settings: Settings.appearance(bar.settings, "calendar")
        opacity: Settings.item(bar.settings, "calendar").opacity ?? 1
        visible: bar.itemEnabled("calendar")
        text: bar.clockText
        foreground: "#b4befe"
        tint: bar.rgba("#b4befe", 0.20)
        outline: bar.rgba("#b4befe", 0.28)
    }
    Pill {
        id: trayPill
        x: bar.itemX("tray")
        y: (bar.height - height) / 2
        settings: Settings.appearance(bar.settings, "tray")
        opacity: Settings.item(bar.settings, "tray").opacity ?? 1
        colorSampler: Settings.adaptive(bar.settings, "tray") ? bar.wallpaperColors : null
        colorRoot: bar
        foreground: "#cba6f7"
        interactive: false
        visible: bar.itemEnabled("tray") && trayIcons.count > 0
        width: trayRow.width + 22
        implicitHeight: Math.max(28, trayIconSize + 8)
        readonly property int trayIconSize: settings.iconSize || 16
        Row {
            id: trayRow
            x: 11
            anchors.verticalCenter: parent.verticalCenter
            visible: !trayPill.settings.hideIcon
            spacing: 0
            Repeater {
                id: trayIcons
                model: bar.trayModel
                delegate: Item {
                    id: trayIcon
                    required property var modelData
                    objectName: "trayIcon"
                    width: trayPill.settings.hideIcon ? 0 : trayPill.trayIconSize
                    height: trayPill.trayIconSize
                    Image {
                        anchors.fill: parent
                        source: trayIcon.modelData.icon
                        sourceSize.width: trayPill.trayIconSize
                        sourceSize.height: trayPill.trayIconSize
                        fillMode: Image.PreserveAspectFit
                    }
                    MouseArea {
                        id: trayPointer
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: mouse => bar.trayAction(trayIcon.modelData, trayIcon, mouse.button)
                        onWheel: event => bar.trayScroll(trayIcon.modelData, event)
                    }
                }
            }
        }
    }
    BarMenuButton {
        id: bell
        bar: bar
        menu: "notifications"
        x: bar.itemX("notifications")
        y: (bar.height - height) / 2
        settings: Settings.appearance(bar.settings, "notifications")
        opacity: Settings.item(bar.settings, "notifications").opacity ?? 1
        visible: bar.itemEnabled("notifications")
        objectName: "notificationBell"
        text: "󰂚"
        family: "GoMono Nerd Font"
        pixelSize: 15
        minimumTextWidth: 12
        leftPadding: 7
        rightPadding: badge.visible ? Math.max(11, badge.implicitWidth + 1) : 11
        foreground: bar.notificationData && bar.notificationData.count > 0 ? "#f9e2af" : "#a6adc8"
        tint: bar.rgba("#a6adc8", 0.18)
        outline: bar.rgba("#a6adc8", 0.26)
        Text {
            id: badge
            objectName: "notificationBadge"
            // Attach to the glyph's upper-right corner, independently of
            // the pill width or number of digits in the count.
            x: bell.content.x + (bell.content.width + bell.content.implicitWidth) / 2 - 2
            y: bell.content.y - 2
            visible: !!bar.notificationData && bar.notificationData.count > 0
            text: bar.notificationData ? String(bar.notificationData.count || "") : ""
            color: bell.effectiveForeground
            font.family: "DejaVu Sans"
            font.pixelSize: 8
            font.bold: true
        }
    }
    BarMenuButton {
        id: audio
        x: bar.itemX("audio")
        y: (bar.height - height) / 2
        settings: Settings.appearance(bar.settings, "audio")
        opacity: Settings.item(bar.settings, "audio").opacity ?? 1
        visible: bar.itemEnabled("audio")
        bar: bar
        menu: "audio"
        icon: bar.statusData.audio.icon || "󰕾"
        text: bar.statusData.audio.text || "--"
        foreground: "#89b4fa"
        tint: bar.rgba("#89b4fa", 0.20)
        outline: bar.rgba("#89b4fa", 0.28)
    }
    BarMenuButton {
        id: wifi
        x: bar.itemX("wifi")
        y: (bar.height - height) / 2
        settings: Settings.appearance(bar.settings, "wifi")
        opacity: Settings.item(bar.settings, "wifi").opacity ?? 1
        visible: bar.itemEnabled("wifi")
        bar: bar
        menu: "wifi"
        text: bar.statusData.network.text || "󰤮"
        foreground: bar.statusData.network.connected ? "#94e2d5" : "#585b70"
        tint: bar.rgba("#94e2d5", 0.18)
        outline: bar.rgba("#94e2d5", 0.26)
        family: "GoMono Nerd Font"
        pixelSize: 15
        minimumTextWidth: 20
        leftPadding: 6
        rightPadding: 13
    }
    BarMenuButton {
        id: bluetooth
        x: bar.itemX("bluetooth")
        y: (bar.height - height) / 2
        settings: Settings.appearance(bar.settings, "bluetooth")
        opacity: Settings.item(bar.settings, "bluetooth").opacity ?? 1
        visible: bar.itemEnabled("bluetooth")
        bar: bar
        menu: "bluetooth"
        text: bar.statusData.bluetooth.text || "󰂲"
        foreground: bar.statusData.bluetooth.connected ? "#89b4fa" : bar.statusData.bluetooth.powered ? "#b4befe" : "#585b70"
        tint: bar.rgba("#b4befe", 0.20)
        outline: bar.rgba("#b4befe", 0.28)
        family: "GoMono Nerd Font"
        pixelSize: 15
        minimumTextWidth: 20
        leftPadding: bar.statusData.bluetooth.powered && !bar.statusData.bluetooth.connected ? 9 : 8
        rightPadding: bar.statusData.bluetooth.powered && !bar.statusData.bluetooth.connected ? 10 : 11
    }
    BarMenuButton {
        id: battery
        x: bar.itemX("battery")
        y: (bar.height - height) / 2
        settings: Settings.appearance(bar.settings, "battery")
        opacity: Settings.item(bar.settings, "battery").opacity ?? 1
        bar: bar
        menu: "battery"
        visible: bar.itemEnabled("battery") && !!bar.statusData.battery.present
        readonly property string batteryLabel: bar.statusData.battery.text || ""
        icon: batteryLabel.indexOf(" ") >= 0 ? batteryLabel.slice(0, batteryLabel.indexOf(" ")) : ""
        text: batteryLabel.indexOf(" ") >= 0 ? batteryLabel.slice(batteryLabel.indexOf(" ") + 1) : batteryLabel
        foreground: bar.statusData.battery.charging ? "#fab387" : bar.statusData.battery.warning ? "#f38ba8" : "#a6e3a1"
        tint: bar.rgba(foreground.toString(), bar.statusData.battery.charging ? 0.20 : bar.statusData.battery.warning ? 0.22 : 0.18)
        outline: bar.rgba(foreground.toString(), bar.statusData.battery.charging ? 0.28 : bar.statusData.battery.warning ? 0.32 : 0.26)
    }
    BarMenuButton {
        id: power
        x: bar.itemX("power")
        y: (bar.height - height) / 2
        settings: Settings.appearance(bar.settings, "power")
        opacity: Settings.item(bar.settings, "power").opacity ?? 1
        visible: bar.itemEnabled("power")
        bar: bar
        menu: "power"
        text: "󰐥"
        foreground: "#f38ba8"
        tint: bar.rgba("#f38ba8", 0.18)
        outline: bar.rgba("#f38ba8", 0.26)
        hoverTint: bar.rgba("#f38ba8", 0.30)
        family: "GoMono Nerd Font"
        pixelSize: 15
        leftPadding: 9
        rightPadding: 9
    }
}
