//@ pragma ShellId ba883eebb89585aa1cc7a393f47bfdf8
// Keep the existing notification history when the configuration directory moves.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "SettingsModel.js" as Settings

ShellRoot {
    id: shell
    property string clockText: ""
    // Root properties keep panel properties from shadowing service IDs.
    readonly property var services: desktopServices
    readonly property var inbox: notificationInbox
    readonly property var statusData: desktopServices.statusData
    readonly property var mediaData: desktopServices.mediaData
    readonly property var notificationData: notificationInbox.statusData
    SettingsStore { id: preferences }
    SettingsController {
        id: settingsController
        store: preferences
        wallpaperSources: wallpapers.sources
        lockingError: locking.error
        onLockRequested: locking.lockNow()
        // Reopening an existing window must activate it, even on another
        // workspace. Do not remap it or reset a user's tiled/floating choice.
        onFocusRequested: settingsWindow => {
            let existing = Hyprland.toplevels.values.find(t => t.title === settingsWindow.title);
            if (existing)
                Hyprland.dispatch("hl.dsp.focus({ window = 'address:" + existing.address + "' })");
        }
    }
    function updateClock() {
        let now = new Date();
        clockText = Qt.formatDateTime(now, preferences.config.bar.clockFormat);
    }
    LockingController { id: locking; store: preferences }
    DesktopServices { id: desktopServices }
    NotificationInbox { id: notificationInbox }
    Tray { id: tray }
    WallpaperWatcher { id: wallpapers }
    Component.onCompleted: updateClock()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: shell.updateClock() }
    Variants {
        id: panels
        model: Quickshell.screens
        PanelWindow {
            id: panel
            required property var modelData
            MenuController { id: menuState; dismissPinnedOnLeave: !panel.visible }
            screen: modelData
            visible: preferences.config.bar.visible !== false
            exclusionMode: visible ? ExclusionMode.Auto : ExclusionMode.Ignore
            onVisibleChanged: if (!visible) menuState.close()
            anchors { top: true; left: true; right: true }
            margins { top: preferences.config.bar.marginTop; left: preferences.config.bar.marginSide; right: preferences.config.bar.marginSide }
            implicitHeight: bar.implicitHeight
            color: "transparent"
            WlrLayershell.namespace: "hyprshell"
            Bar {
                id: bar
                settings: preferences.config
                anchors.fill: parent
                statusData: shell.statusData
                mediaData: shell.mediaData
                notificationData: shell.notificationData
                outputName: panel.screen.name
                wallpaperSource: wallpapers.sources[panel.screen.name] || ""
                screenWidth: panel.screen.width
                screenHeight: panel.screen.height
                screenOffsetX: panel.margins.left
                screenOffsetY: panel.margins.top
                clockText: shell.clockText
                trayModel: tray.items
                activeMenu: menuState.section
                onMenuHovered: name => {
                    for (let other of panels.instances) if (other !== panel) other.closeMenu();
                    menuState.hover(name);
                }
                onMenuLeft: name => menuState.leave(name)
                onAction: (name, argument) => {
                    if (name === "workspace") shell.services.workspace(argument);
                    else if (name === "workspace-scroll") shell.services.scrollWorkspace(argument);
                    else if (name === "settings") {
                        for (let panel of panels.instances) panel.closeMenu();
                        settingsController.open();
                    }
                    else {
                        for (let other of panels.instances) if (other !== panel) other.closeMenu();
                        menuState.activate(name);
                    }
                }
                onTrayAction: (item, source, button) => {
                    if (button === Qt.MiddleButton) item.secondaryActivate();
                    else if (button === Qt.RightButton || item.onlyMenu) {
                        if (item.hasMenu) { let position = source.mapToItem(bar,0,source.height); item.display(panel,position.x,position.y); }
                    } else item.activate();
                }
                onTrayScroll: (item,event) => item.scroll(event.angleDelta.y || event.angleDelta.x,!event.angleDelta.y)
            }
            Dropdown {
                wallpaperSource: bar.wallpaperSource
                translucency: Settings.popdownTranslucency(preferences.config, menuState.displayedSection)
                screen: panel.screen
                barBottom: panel.visible ? panel.margins.top + panel.height : 0
                connected: panel.visible
                section: menuState.section
                displayedSection: menuState.displayedSection
                alignment: panel.visible ? bar.side(menuState.displayedSection) : "center"
                pinned: menuState.pinned
                triggerRect: {
                    if (!panel.visible) return Qt.rect(panel.screen.width / 2, 0, 0, 0);
                    let rect = bar.menuRect(menuState.displayedSection);
                    return Qt.rect(rect.x + panel.margins.left, rect.y + panel.margins.top, rect.width, rect.height);
                }
                accent: bar.menuAccent(menuState.displayedSection)
                services: shell.services
                inbox: shell.inbox
                onCloseRequested: menuState.close()
                onSettingsRequested: settingsController.open()
                onHoverChanged: inside => menuState.retain(inside)
            }
            KeybindingsPopup { id: keybindings; screen: panel.screen; wallpaperSource: bar.wallpaperSource; translucency: preferences.config.bar.popdownTranslucency ?? 0.06 }
            function closeMenu() { menuState.close(); keybindings.opened = false; }
            function refreshSettings() {
                if (!panel.visible || (menuState.section && !bar.itemEnabled(menuState.section))) menuState.close();
            }
            function toggleMenu(name) { keybindings.opened = false; menuState.activate(name); }
            function toggleLauncher() { toggleMenu("launcher"); }
            function toggleKeybindings() { menuState.close(); keybindings.opened = !keybindings.opened; }
        }
    }
    Connections {
        target: preferences
        function onConfigChanged() {
            shell.updateClock();
            for (let panel of panels.instances) panel.refreshSettings();
        }
    }
    Process {
        id: barVisibilityWriter
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("settings/backend.py").toString().replace(/^file:\/\//, "")), "--toggle-bar"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let result = JSON.parse(text);
                    if (result.ok) preferences.reload();
                    else console.warn("Topbar toggle: " + result.message);
                } catch (error) { console.warn("Topbar toggle failed: " + error); }
            }
        }
    }
    IpcHandler {
        target: "bar"
        function ready(): bool {
            if (panels.instances.length === 0) return false;
            for (let panel of panels.instances) if (panel.visible && !panel.backingWindowVisible) return false;
            return true;
        }
        function reload(): void { Quickshell.reload(true); }
        function settings(): void {
            for (let panel of panels.instances) panel.closeMenu();
            settingsController.open();
        }
        function toggleBar(): void {
            let ui = settingsController.window;
            if (ui) ui.updateBar("visible", ui.draft.bar.visible === false);
            else if (!barVisibilityWriter.running) barVisibilityWriter.running = true;
        }
        function toggleMenu(name: string): void {
            if (!["calendar", "notifications", "audio", "wifi", "bluetooth", "battery", "power", "launcher"].includes(name)) return;
            let focused = Hyprland.focusedMonitor;
            let panel = panels.instances.find(p => focused && p.screen.name === focused.name) || panels.instances[0];
            for (let other of panels.instances) if (other !== panel) other.closeMenu();
            if (panel) panel.toggleMenu(name);
        }
        function toggleKeybindings(): void {
            let focused = Hyprland.focusedMonitor;
            let panel = panels.instances.find(p => focused && p.screen.name === focused.name) || panels.instances[0];
            for (let other of panels.instances) if (other !== panel) other.closeMenu();
            if (panel) panel.toggleKeybindings();
        }
        function toggleLauncher(): void {
            let focused = Hyprland.focusedMonitor;
            let panel = panels.instances.find(p => focused && p.screen.name === focused.name) || panels.instances[0];
            if (panel) panel.toggleLauncher();
        }
    }
}
