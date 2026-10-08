pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: bar
    property var statusData: ({workspaces: [], audio: {}, network: {}, bluetooth: {}, battery: {}})
    property var mediaData: ({playing: false, levels: [], title: "", tooltip: ""})
    property var notificationData: ({count: 0, tooltip: "Notifications", class: "empty"})
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
        screenWidth: bar.screenWidth; screenHeight: bar.screenHeight
        offsetX: bar.screenOffsetX; offsetY: bar.screenOffsetY
        bandHeight: bar.height
    }
    property var trayModel: []
    property string clockText: ""
    property string activeMenu: ""
    signal menuHovered(string name)
    signal menuLeft(string name)
    readonly property var menuTargets: ({launcher: arch, calendar: clock, notifications: bell, audio: audio, wifi: wifi, bluetooth: bluetooth, battery: battery, power: power})
    function menuRect(name) {
        let item = menuTargets[name];
        if (!item) return Qt.rect(12, 2, 24, 20);
        // Read layout positions directly so the connector follows screen and
        // status-width changes, including movement of the containing row.
        let offset = item.parent === bar ? Qt.point(0, 0) : Qt.point(item.parent.x, item.parent.y);
        return Qt.rect(item.x + offset.x, item.y + offset.y, item.width, item.height);
    }
    function menuAccent(name) { return menuTargets[name] ? menuTargets[name].foreground : "#b4befe"; }
    signal action(string name, var argument)
    signal trayAction(var item, var source, int button)
    signal trayScroll(var item, var event)
    function rgba(hex, alpha) { return Qt.rgba(parseInt(hex.slice(1,3),16)/255, parseInt(hex.slice(3,5),16)/255, parseInt(hex.slice(5,7),16)/255, alpha); }
    height: 32
    Row {
        id: left
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        BarMenuButton {
            bar: bar; menu: "launcher"
            id: arch
            text: ""; foreground: "#1793d1"
            family: "GoMono Nerd Font"; pixelSize: 20; bold: false
            minimumTextWidth: 28
            leftPadding: 5; rightPadding: 5
            backgroundVisible: false
            content.opacity: 0
            GlassLogo {
                objectName: "archGlassLogo"
                x: arch.content.x; width: arch.content.width; height: arch.height
                accent: arch.effectiveForeground
                highlighted: arch.hovered || arch.selected
            }
        }
        Row {
            id: workspaceRow
            height: 28
            spacing: 2
            leftPadding: 3; rightPadding: 3
            Repeater {
                model: (bar.statusData.workspaces || []).filter(w => !bar.outputName || w.monitor === bar.outputName)
                delegate: Pill {
                    objectName: "workspace" + modelData.id
                    colorSampler: bar.wallpaperColors; colorRoot: bar
                    required property var modelData
                    property bool active: modelData.active || false
                    anchors.verticalCenter: workspaceRow.verticalCenter
                    height: 24
                    text: modelData.name || String(modelData.id)
                    leftPadding: 9; rightPadding: 9
                    foreground: active ? "#cba6f7" : "#a0a0a0"
                    colorStyle: active ? "emphasized" : "muted"
                    selected: active
                    raised: active
                    onClicked: bar.action("workspace", modelData.id)
                    onWheel: event => bar.action("workspace-scroll", event.angleDelta.y > 0 ? -1 : 1)
                }
            }
        }
        Loader {
            objectName: "mediaSlot"
            active: !!bar.mediaData && bar.mediaData.playing === true
            visible: active
            sourceComponent: MediaPill {
                colorSampler: bar.wallpaperColors; colorRoot: bar
                text: bar.mediaData.title || ""
                levels: bar.mediaData.levels || []
                maximumWidth: Math.max(0, clock.x - left.x - arch.width - workspaceRow.width - 18)
                interactive: false
            }
        }
    }
    BarMenuButton {
        bar: bar; menu: "calendar"
        id: clock
        anchors.centerIn: parent
        text: bar.clockText
        foreground: "#b4befe"; tint: bar.rgba("#b4befe", 0.20); outline: bar.rgba("#b4befe", 0.28)
    }
    Row {
        id: right
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Pill {
            id: trayPill
            colorSampler: bar.wallpaperColors; colorRoot: bar
            foreground: "#cba6f7"
            interactive: false
            visible: trayIcons.count > 0
            width: trayRow.width + 22
            Row {
                id: trayRow
                anchors.centerIn: parent
                spacing: 0
                Repeater {
                    id: trayIcons
                    model: bar.trayModel
                    delegate: Item {
                        id: trayIcon
                        required property var modelData
                        width: 16; height: 16
                        Image { anchors.fill: parent; source: trayIcon.modelData.icon; sourceSize.width: 16; sourceSize.height: 16; fillMode: Image.PreserveAspectFit }
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
            bar: bar; menu: "notifications"
            id: bell
            objectName: "notificationBell"
            text: "󰂚"
            family: "GoMono Nerd Font"; pixelSize: 15
            minimumTextWidth: 12
            leftPadding: 7; rightPadding: badge.visible ? Math.max(11, badge.implicitWidth + 1) : 11
            foreground: bar.notificationData && bar.notificationData.count > 0 ? "#f9e2af" : "#a6adc8"
            tint: bar.rgba("#a6adc8", 0.18); outline: bar.rgba("#a6adc8", 0.26)
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
                font.family: "DejaVu Sans"; font.pixelSize: 8; font.bold: true
            }
        }
        BarMenuButton {
            id: audio
            bar: bar; menu: "audio"
            icon: bar.statusData.audio.icon || "󰕾"
            text: bar.statusData.audio.text || "--"
            foreground: "#89b4fa"; tint: bar.rgba("#89b4fa", 0.20); outline: bar.rgba("#89b4fa", 0.28)
        }
        BarMenuButton {
            id: wifi
            bar: bar; menu: "wifi"
            text: bar.statusData.network.text || "󰤮"
            foreground: bar.statusData.network.connected ? "#94e2d5" : "#585b70"
            tint: bar.rgba("#94e2d5", 0.18); outline: bar.rgba("#94e2d5", 0.26)
            family: "GoMono Nerd Font"; pixelSize: 15
            minimumTextWidth: 20; leftPadding: 6; rightPadding: 13
        }
        BarMenuButton {
            id: bluetooth
            bar: bar; menu: "bluetooth"
            text: bar.statusData.bluetooth.text || "󰂲"
            foreground: bar.statusData.bluetooth.connected ? "#89b4fa" : bar.statusData.bluetooth.powered ? "#b4befe" : "#585b70"
            tint: bar.rgba("#b4befe", 0.20); outline: bar.rgba("#b4befe", 0.28)
            family: "GoMono Nerd Font"; pixelSize: 15
            minimumTextWidth: 20
            leftPadding: bar.statusData.bluetooth.powered && !bar.statusData.bluetooth.connected ? 9 : 8
            rightPadding: bar.statusData.bluetooth.powered && !bar.statusData.bluetooth.connected ? 10 : 11
        }
        BarMenuButton {
            id: battery
            bar: bar; menu: "battery"
            visible: !!bar.statusData.battery.present
            text: bar.statusData.battery.text || ""
            foreground: bar.statusData.battery.charging ? "#fab387" : bar.statusData.battery.warning ? "#f38ba8" : "#a6e3a1"
            tint: bar.rgba(foreground.toString(), bar.statusData.battery.charging ? 0.20 : bar.statusData.battery.warning ? 0.22 : 0.18)
            outline: bar.rgba(foreground.toString(), bar.statusData.battery.charging ? 0.28 : bar.statusData.battery.warning ? 0.32 : 0.26)
        }
        BarMenuButton {
            id: power
            bar: bar; menu: "power"
            text: "󰐥"
            foreground: "#f38ba8"; tint: bar.rgba("#f38ba8", 0.18); outline: bar.rgba("#f38ba8", 0.26)
            hoverTint: bar.rgba("#f38ba8", 0.30)
            family: "GoMono Nerd Font"; pixelSize: 15
            leftPadding: 9; rightPadding: 9
        }
    }
}
