pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: dropdown
    property url wallpaperSource: ""
    property real translucency: 0.06
    property string section: ""
    property string displayedSection: section
    property rect triggerRect: Qt.rect(12, 4, 32, 20)
    property string alignment: "center"
    property color accent: "#b4befe"
    property bool connected: true
    property bool pinned: false
    property real barBottom: 37
    readonly property bool opened: section.length > 0
    signal hoverChanged(bool inside)
    required property var services
    required property var inbox
    signal closeRequested()
    signal settingsRequested()
    // Keep one surface mapped. Remapping it during hover can synthesize
    // leave/enter events on the bar and repeatedly close and reopen menus.
    visible: true
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // Keep the bar reachable while this overlay is open, so hovering a
    // neighboring icon can switch menus without closing the current one.
    mask: Region { x: 0; y: dropdown.barBottom; width: dropdown.width; height: dropdown.opened ? Math.max(0, dropdown.height - dropdown.barBottom) : 0 }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hyprshell"
    WlrLayershell.keyboardFocus: !opened ? WlrKeyboardFocus.None : pinned ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    MouseArea { anchors.fill: parent; onClicked: dropdown.closeRequested() }
    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: dropdown.closeRequested()
        Keys.onPressed: event => {
            if (dropdown.displayedSection === "power" && dropdown.opened && !event.isAutoRepeat
                    && !(event.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.ShiftModifier))
                    && popover.pageItem && popover.pageItem.runShortcut(event.key))
                event.accepted = true;
        }
        MenuPopover {
            id: popover
            anchors.fill: parent
            wallpaperSource: dropdown.wallpaperSource
            translucency: dropdown.translucency
            triggerRect: dropdown.triggerRect
            alignment: dropdown.alignment
            connected: dropdown.connected
            accent: dropdown.accent
            opened: dropdown.opened
            cardClickable: dropdown.displayedSection === "settings"
            onCardClicked: {
                dropdown.closeRequested();
                dropdown.settingsRequested();
            }
            title: ({launcher:"Applications",settings:"Hyprshell",calendar:"Calendar",audio:"Audio",wifi:"Wi-Fi",bluetooth:"Bluetooth",notifications:"Notifications",battery:"Battery",power:"Power options"})[dropdown.displayedSection] || ""
            symbol: ({launcher:"",settings:"󰒓",calendar:"󰃭",audio:dropdown.services.audioIcon || "󰕾",wifi:"󰤨",bluetooth:"󰂯",notifications:"󰂚",battery:"󰁹",power:"󰐥"})[dropdown.displayedSection] || ""
            page: ({launcher: launcherPage, settings: settingsPage, calendar: calendarPage, audio: audioPage, wifi: wifiPage, bluetooth: bluetoothPage, notifications: inboxPage, battery: batteryPage, power: powerPage})[dropdown.displayedSection] || null
            onHoverChanged: inside => dropdown.hoverChanged(inside)
        }
    }
    onOpenedChanged: if (opened) focusScope.forceActiveFocus()
    Shortcut { sequence: "Escape"; enabled: dropdown.opened; onActivated: dropdown.closeRequested() }
    Component { id: launcherPage; LauncherMenu { onLaunched: dropdown.closeRequested() } }
    Component { id: settingsPage; SettingsMenu { onOpenRequested: { dropdown.closeRequested(); dropdown.settingsRequested(); } } }
    Component { id: calendarPage; CalendarMenu {} }
    Component { id: audioPage; AudioMenu { services: dropdown.services } }
    Component { id: wifiPage; WifiMenu { services: dropdown.services } }
    Component { id: bluetoothPage; BluetoothMenu { services: dropdown.services } }
    Component { id: batteryPage; BatteryMenu { services: dropdown.services } }
    Component { id: inboxPage; InboxMenu { inbox: dropdown.inbox } }
    Component { id: powerPage; PowerMenu {} }
}
