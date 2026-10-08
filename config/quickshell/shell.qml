//@ pragma ShellId ba883eebb89585aa1cc7a393f47bfdf8
// Keep the existing notification history when the configuration directory moves.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: shell
    property string clockText: ""
    // Root properties keep panel properties from shadowing service IDs.
    readonly property var services: desktopServices
    readonly property var inbox: notificationInbox
    readonly property var statusData: desktopServices.statusData
    readonly property var mediaData: desktopServices.mediaData
    readonly property var notificationData: notificationInbox.statusData
    function updateClock() {
        let now = new Date();
        clockText = Qt.formatDateTime(now, "MMM dd   hh:mm AP   ddd");
    }
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
            MenuController { id: menuState }
            screen: modelData
            anchors { top: true; left: true; right: true }
            margins { top: 5; left: 10; right: 10 }
            implicitHeight: 32
            color: "transparent"
            WlrLayershell.namespace: "waybar"
            Bar {
                id: bar
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
                screen: panel.screen
                barBottom: panel.margins.top + panel.height
                section: menuState.section
                displayedSection: menuState.displayedSection
                pinned: menuState.pinned
                triggerRect: {
                    let rect = bar.menuRect(menuState.displayedSection);
                    return Qt.rect(rect.x + panel.margins.left, rect.y + panel.margins.top, rect.width, rect.height);
                }
                accent: bar.menuAccent(menuState.displayedSection)
                services: shell.services
                inbox: shell.inbox
                onCloseRequested: menuState.close()
                onHoverChanged: inside => menuState.retain(inside)
            }
            function closeMenu() { menuState.close(); }
            function toggleLauncher() { menuState.activate("launcher"); }
        }
    }
    IpcHandler {
        target: "bar"
        function ready(): bool {
            if (panels.instances.length === 0) return false;
            for (let panel of panels.instances) if (!panel.backingWindowVisible) return false;
            return true;
        }
        function reload(): void { Quickshell.reload(true); }
        function toggleLauncher(): void {
            let focused = Hyprland.focusedMonitor;
            let panel = panels.instances.find(p => focused && p.screen.name === focused.name) || panels.instances[0];
            if (panel) panel.toggleLauncher();
        }
    }
}
