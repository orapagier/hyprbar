pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "SettingsModel.js" as Model

FloatingWindow {
    id: window
    required property var store
    property var wallpaperSources: ({})
    property string lockingError: ""
    property string powerError: ""
    property var audioServices: null
    property var notificationApps: []
    property var batteryInfo: ({})
    signal lockRequested()
    signal focusRequested()
    // A compositor close hides the native window without clearing the
    // FloatingWindow visibility request. Reset it so the next open remaps.
    onClosed: visible = false
    property var draft: Model.copy(store.defaults)
    property var initial: Model.copy(store.defaults)
    property var submitted: Model.copy(store.defaults)
    property bool editingSession: false
    readonly property bool saving: writer.running
    readonly property bool idle: !writer.running && !autoSave.running && !cleanupPage.busy && !hyprskillPage.busy && !githubSync.running && !keybindingsPage.busy && !themePage.busy && !powerPage.busy && !soundPage.busy
    onDraftChanged: if (editingSession) autoSave.restart()
    onVisibleChanged: if (!visible && editingSession && dirty) apply()
    property int section: -1
    onSectionChanged: Qt.callLater(() => { if (editorScroll.contentItem) editorScroll.contentItem.contentY = 0; })
    property string message: ""
    property bool success: true
    property string savedNotice: ""
    property string submittedNotice: ""
    readonly property bool dirty: JSON.stringify(draft) !== JSON.stringify(initial)
    readonly property var selected: section >= 0 ? draft.items[section] : ({})
    readonly property var names: ({
            launcher: "App launcher",
            settings: "Settings shortcut",
            workspaces: "Workspaces",
            media: "Media & spectrum",
            calendar: "Clock & calendar",
            tray: "System tray",
            notifications: "Notifications",
            audio: "Audio",
            wifi: "Wi-Fi",
            bluetooth: "Bluetooth",
            battery: "Battery",
            power: "Power"
        })
    readonly property var symbols: ({
            launcher: "",
            settings: "󰒓",
            workspaces: "󰍹",
            media: "󰎆",
            calendar: "󰃭",
            tray: "󰕰",
            notifications: "󰂚",
            audio: "󰕾",
            wifi: "󰤨",
            bluetooth: "󰂯",
            battery: "󰁹",
            power: "󰐥"
        })
    visible: false
    title: "Hyprshell Settings"
    implicitWidth: screen ? Math.min(1180, Math.round(screen.width * 0.9)) : 1180
    implicitHeight: screen ? Math.round(screen.height * 0.75) : 810
    color: "#10131c"
    function open() {
        minimized = false;
        if (visible) {
            focusRequested();
            return;
        }
        if (editingSession && (dirty || saving)) {
            visible = true;
            return;
        }
        savedNotice = "";
        savedNoticeTimer.stop();
        editingSession = false;
        initial = Model.copy(store.config);
        draft = Model.copy(store.config);
        message = store.error;
        success = !store.error;
        editingSession = true;
        visible = true;
    }
    function updateItem(key, value) {
        let next = Model.copy(draft);
        if (key === "pillGroup") next = Model.setPillGroup(draft, selected.id, value);
        else if (key === "side") next = Model.setItemSide(draft, selected.id, value);
        else next.items[section][key] = value;
        draft = next;
    }
    function resetItem() {
        if (saving || section < 0) return;
        draft = Model.restoreItem(draft, initial, selected.id);
    }
    function rearrangeItem(id, side, beforeId) {
        draft = Model.reorder(draft, id, side, beforeId);
    }
    function updateBar(key, value) {
        let next = Model.copy(draft);
        next.bar[key] = value;
        draft = next;
    }
    function updateHypr(key, value) {
        let next = Model.copy(draft);
        if (value === "")
            delete next.hyprland[key];
        else
            next.hyprland[key] = value;
        draft = next;
    }
    function updateNotifications(key, value) {
        let next = Model.copy(draft);
        next.notifications[key] = value;
        draft = next;
    }
    function updatePower(key, value) {
        let next = Model.copy(draft);
        next.power[key] = value;
        draft = next;
    }
    function updateLocking(key, value) {
        let next = Model.copy(draft);
        next.locking[key] = value;
        draft = next;
    }
    function moveItem(direction) {
        let next = Model.copy(draft);
        let current = next.items[section];
        let group = next.items.filter(i => i.side === current.side).sort((a, b) => a.order - b.order);
        let index = group.findIndex(i => i.id === current.id), other = index + direction;
        if (other < 0 || other >= group.length)
            return;
        [group[index], group[other]] = [group[other], group[index]];
        group.forEach((item, n) => item.order = n);
        draft = next;
    }
    function saveNotice(before, after) {
        let labels = [];
        if (JSON.stringify(before.bar) !== JSON.stringify(after.bar)) labels.push("Bar & layout");
        let inputKeys = ["pointerSpeed", "mouseNaturalScroll", "touchpadNaturalScroll", "tapToClick", "disableWhileTyping", "repeatRate", "repeatDelay", "keyboardLayouts", "layoutSwitch"];
        if (inputKeys.some(key => before.hyprland[key] !== after.hyprland[key])) labels.push("Mouse, touchpad & keyboard");
        if (Object.keys(Object.assign({}, before.hyprland, after.hyprland)).some(key => inputKeys.indexOf(key) < 0 && before.hyprland[key] !== after.hyprland[key])) labels.push("Hyprland appearance");
        if (JSON.stringify(before.notifications) !== JSON.stringify(after.notifications)) labels.push("Notification delivery");
        if (JSON.stringify(before.power) !== JSON.stringify(after.power)) labels.push("Power & battery");
        if (JSON.stringify(before.locking) !== JSON.stringify(after.locking)) labels.push("Screen locking");
        after.items.forEach(item => {
            let previous = before.items.find(entry => entry.id === item.id);
            if (JSON.stringify(previous) !== JSON.stringify(item)) labels.push(names[item.id] || item.id);
        });
        return labels.length ? labels.join(", ") + " settings saved!" : "Settings saved!";
    }
    function apply() {
        if (writer.running || !dirty) return;
        if (store.error || !store.loaded) {
            message = store.error;
            success = false;
            return;
        }
        autoSave.stop();
        submitted = Model.copy(draft);
        submittedNotice = saveNotice(initial, submitted);
        savedNotice = "";
        savedNoticeTimer.stop();
        success = true;
        message = "Saving changes…";
        writer.command = ["python3", decodeURIComponent(Qt.resolvedUrl("settings/backend.py").toString().replace(/^file:\/\//, "")), "--save-json", JSON.stringify(submitted), "--expected-json", JSON.stringify(initial)];
        writer.running = true;
    }
    Timer {
        id: autoSave
        interval: 500
        onTriggered: window.apply()
    }
    Timer {
        id: savedNoticeTimer
        interval: 2000
        onTriggered: window.savedNotice = ""
    }
    Process {
        id: writer
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && window.success) {
                window.success = false;
                window.message = "Could not save settings. Your last saved values are still active.";
            }
            if (window.dirty && (window.success || JSON.stringify(window.draft) !== JSON.stringify(window.submitted))) autoSave.restart();
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let result = JSON.parse(text);
                    window.success = result.ok;
                    window.message = result.ok ? "" : result.message;
                    if (result.ok) {
                        window.savedNotice = window.submittedNotice;
                        savedNoticeTimer.restart();
                        window.initial = Model.copy(window.submitted);
                        window.store.config = Model.copy(window.submitted);
                        window.store.reload();
                    }
                } catch (e) {
                    window.success = false;
                    window.message = "Could not save settings. Check that Python 3 is installed.";
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text) {
                window.success = false;
                window.message = text;
            }
        }
    }
    property string syncMessage: ""
    property bool syncSuccess: true
    property bool syncReady: false
    property string syncRepository: ""
    property string syncForkUrl: ""
    property string syncCreateUrl: ""
    Process {
        id: githubSync
        property string action: ""
        function request(action, extra) {
            githubSync.action = action;
            window.syncReady = false;
            window.syncForkUrl = "";
            window.syncCreateUrl = "";
            window.syncSuccess = true;
            window.syncMessage = action === "--status" ? "Checking GitHub setup…" : action === "--authenticate" ? "Complete sign-in in the authentication window…" : "Saving live desktop to the local repo, then syncing to GitHub…";
            command = ["python3", decodeURIComponent(Qt.resolvedUrl("settings/github_sync.py").toString().replace(/^file:\/\//, ""))].concat(action ? [action] : []).concat(extra || []);
            running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let result = JSON.parse(text);
                    window.syncSuccess = result.ok;
                    window.syncMessage = result.message;
                    window.syncReady = result.ok && result.ready === true;
                    window.syncRepository = result.repository || "";
                    window.syncForkUrl = result.forkUrl || "";
                    window.syncCreateUrl = result.createUrl || "";
                } catch (e) {
                    window.syncSuccess = false;
                    window.syncMessage = "Could not read GitHub sync results.";
                }
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text) { window.syncSuccess = false; window.syncMessage = text; } }
        onExited: (code, status) => {
            if (code !== 0 && window.syncSuccess) {
                window.syncSuccess = false;
                window.syncMessage = "GitHub sync failed. Check Git and GitHub authentication.";
            }
        }
    }
    Popup {
        id: githubDialog
        objectName: "githubSyncDialog"
        anchors.centerIn: parent
        width: Math.min(480, window.width - 40)
        padding: 24
        modal: true
        closePolicy: githubSync.running ? Popup.NoAutoClose : Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { color: "#1c2130"; radius: 14; border.color: "#545d79" }
        contentItem: ColumnLayout {
            spacing: 14
            Label { text: "  Sync to GitHub"; color: "#ecebff"; font.pixelSize: 20; font.bold: true }
            Label { objectName: "githubRepositoryLabel"; text: window.syncRepository || "Sign in to find your repository"; color: "#b4a2ff" }
            Label { Layout.fillWidth: true; text: window.syncMessage; wrapMode: Text.WordWrap; color: window.syncSuccess ? "#9eafb7" : "#f38ba8" }
            RowLayout {
                SettingsButton {
                    objectName: "githubForkButton"
                    text: "Fork Hyprshell"
                    visible: window.syncForkUrl !== ""
                    enabled: !githubSync.running
                    onClicked: Qt.openUrlExternally(window.syncForkUrl)
                }
                SettingsButton {
                    objectName: "githubCreateButton"
                    text: "Create repository"
                    visible: window.syncCreateUrl !== ""
                    enabled: !githubSync.running
                    onClicked: Qt.openUrlExternally(window.syncCreateUrl)
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                SettingsButton {
                    objectName: "githubCheckButton"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitWidth: 0
                    leftPadding: 8; rightPadding: 8
                    text: "Check again"
                    enabled: !githubSync.running
                    onClicked: githubSync.request("--status", [])
                }
                SettingsButton {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitWidth: 0
                    leftPadding: 8; rightPadding: 8
                    text: "Authenticate"
                    enabled: !githubSync.running
                    onClicked: githubSync.request("--authenticate", [])
                }
                SettingsButton {
                    objectName: "githubConfirmSync"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitWidth: 0
                    leftPadding: 8; rightPadding: 8
                    text: githubSync.running ? "Working…" : "Sync"
                    highlighted: true
                    enabled: !githubSync.running && window.syncReady && !window.dirty && !window.saving && window.success
                    onClicked: githubSync.request("", [])
                }
                SettingsButton {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitWidth: 0
                    leftPadding: 8; rightPadding: 8
                    text: "Close"
                    enabled: !githubSync.running
                    onClicked: githubDialog.close()
                }
            }
        }
    }
    Pane {
        anchors.fill: parent
        padding: 20
        topPadding: 20
        bottomPadding: 12
        palette.window: "#10131c"
        palette.windowText: "#ecebff"
        palette.text: "#ecebff"
        palette.base: "#1c2130"
        palette.button: "#252b3d"
        palette.buttonText: "#ecebff"
        palette.highlight: "#b4a2ff"
        palette.highlightedText: "#151020"
        palette.brightText: "#151020"
        palette.dark: "#b4a2ff"
        palette.mid: "#363e58"
        font.family: "DejaVu Sans"
        background: Rectangle { color: "#141820" }
        contentItem: ColumnLayout {
            spacing: 16
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                ColumnLayout {
                    spacing: 2
                    Label {
                        text: "Hyprshell"
                        font.pixelSize: 24
                        font.bold: true
                        color: "#ecebff"
                    }
                    Label {
                        text: "Settings"
                        color: "#939bb3"
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                SettingsButton {
                    objectName: "githubSyncButton"
                    text: githubSync.running ? "Syncing…" : "  Sync to GitHub"
                    enabled: !githubSync.running && !window.dirty && !window.saving && window.success && window.store.loaded && !cleanupPage.busy
                    ToolTip.visible: hovered
                    ToolTip.text: "Commit and push your desktop setup to your GitHub hyprshell repository"
                    onClicked: {
                        githubDialog.open();
                        githubSync.request("--status", []);
                    }
                }
                SettingsButton {
                    text: "Reset unsaved changes"
                    visible: !window.success && window.dirty
                    enabled: !writer.running
                    onClicked: {
                        autoSave.stop();
                        window.draft = Model.copy(window.initial);
                        window.success = true;
                        window.message = "Restored your last saved settings.";
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                visible: window.section >= -1
                Layout.preferredHeight: previewBar.y + previewBar.height * previewBar.scale + 16
                radius: 12
                color: "#1a202b"
                border.color: "#2c3443"
                Label {
                    x: 16
                    y: 12
                    text: "LIVE PREVIEW   ·   Drag to rearrange, click to customize"
                    color: "#949dbb"
                    font.pixelSize: 10
                    font.letterSpacing: 0.3
                }
                Bar {
                    id: previewBar
                    x: 12
                    y: 34
                    width: Math.max(1000, parent.width - 24)
                    scale: Math.min(1, (parent.width - 24) / width)
                    transformOrigin: Item.TopLeft
                    settings: window.draft
                    wallpaperSource: window.screen ? window.wallpaperSources[window.screen.name] || "" : ""
                    trayModel: [{icon: Qt.resolvedUrl("icons/preview-tray.svg")} ]
                    clockText: Qt.formatDateTime(new Date(), window.draft.bar.clockFormat)
                    statusData: ({
                            workspaces: [
                                {
                                    id: 1,
                                    name: "1",
                                    active: true
                                },
                                {
                                    id: 2,
                                    name: "2"
                                }
                            ],
                            audio: {
                                text: "64%",
                                icon: "󰕾"
                            },
                            network: {
                                text: "󰤨",
                                connected: true
                            },
                            bluetooth: {
                                text: "󰂯",
                                powered: true
                            },
                            battery: {
                                present: true,
                                text: "󰁹 86%"
                            }
                        })
                    mediaData: ({
                            playing: true,
                            title: "Your favorite track",
                            levels: [0.2, 0.5, 0.8, 0.4, 0.9, 0.6, 0.3, 0.7, 0.5, 0.9, 0.3, 0.6]
                        })
                    notificationData: ({
                            count: 2
                        })
                    PreviewLayoutEditor {
                        anchors.fill: parent
                        bar: previewBar
                        names: window.names
                        onItemSelected: id => window.section = window.draft.items.findIndex(i => i.id === id)
                        onItemDropped: (id, side, beforeId) => window.rearrangeItem(id, side, beforeId)
                    }
                }
            }
            RowLayout {
                enabled: !githubSync.running
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16
                ScrollView {
                    id: sidebar
                    Layout.preferredWidth: window.width < 900 ? 200 : 226
                    Layout.fillHeight: true
                    clip: true
                    padding: 8
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    background: Rectangle {
                        radius: 12
                        color: "#191e28"
                        border.color: "#2c3443"
                    }
                    ColumnLayout {
                        width: sidebar.availableWidth
                        spacing: 1
                        Label {
                            text: "PERSONALIZE"
                            color: "#7c89a7"
                            font.pixelSize: 9
                            font.letterSpacing: 1.6
                            Layout.leftMargin: 13
                            Layout.topMargin: 6
                            Layout.bottomMargin: 8
                        }
                        SettingsNavButton {
                            text: "Bar & layout"
                            symbol: "󰕮"
                            Layout.fillWidth: true
                            flat: true
                            highlighted: window.section === -1
                            onClicked: window.section = -1
                        }
                        SettingsNavButton {
                            symbol: "󰖲"
                            text: "Hyprland"
                            Layout.fillWidth: true
                            flat: true
                            highlighted: window.section === -2
                            onClicked: window.section = -2
                        }
                        SettingsNavButton {
                            text: "Application theme"
                            symbol: "󰔎"
                            Layout.fillWidth: true
                            flat: true
                            highlighted: window.section === -8
                            onClicked: window.section = -8
                        }
                        SettingsNavButton {
                            text: "Displays"
                            symbol: "󰍹"
                            Layout.fillWidth: true
                            flat: true
                            highlighted: window.section === -7
                            onClicked: window.section = -7
                        }
                        SettingsNavButton {
                            symbol: "󰍽"
                            text: "Mouse & keyboard"
                            Layout.fillWidth: true
                            flat: true
                            highlighted: window.section === -9
                            onClicked: window.section = -9
                        }
                        SettingsNavButton {
                            symbol: "󰌌"
                            text: "Keybindings"
                            Layout.fillWidth: true
                            flat: true
                            highlighted: window.section === -6
                            onClicked: window.section = -6
                        }
                        SettingsNavButton {
                            symbol: "󰁹"
                            text: "Power & battery"
                            Layout.fillWidth: true
                            flat: true
                            highlighted: window.section === -10
                            onClicked: window.section = -10
                        }
                        SettingsNavButton {
                            symbol: "󰂚"
                            text: "Notification delivery"
                            Layout.fillWidth: true
                            flat: true
                            highlighted: window.section === -11
                            onClicked: window.section = -11
                        }
                        SettingsNavButton {
                            symbol: "󰕾"
                            text: "Sound"
                            Layout.fillWidth: true
                            flat: true
                            highlighted: window.section === -12
                            onClicked: window.section = -12
                        }
                        SettingsNavButton {
                            symbol: "󰌾"
                            text: "Screen locking"
                            Layout.fillWidth: true
                            flat: true
                            highlighted: window.section === -3
                            onClicked: window.section = -3
                        }
                        SettingsNavButton {
                            symbol: "󰃢"
                            text: "System cleanup"
                            Layout.fillWidth: true
                            flat: true
                            highlighted: window.section === -4
                            onClicked: window.section = -4
                        }
                        SettingsNavButton {
                            symbol: "󰒓"
                            text: "Hyprskill"
                            Layout.fillWidth: true
                            flat: true
                            highlighted: window.section === -5
                            onClicked: window.section = -5
                        }
                        Label {
                            text: "TOPBAR ITEMS"
                            color: "#727d9a"
                            font.pixelSize: 10
                            Layout.topMargin: 10
                            Layout.bottomMargin: 6
                            Layout.leftMargin: 13
                            font.letterSpacing: 1.6
                        }
                        Repeater {
                            model: window.draft.items
                            delegate: SettingsNavButton {
                                required property var modelData
                                required property int index
                                text: window.names[modelData.id]
                                symbol: window.symbols[modelData.id] || "󰒓"
                                itemEnabled: modelData.enabled
                                Layout.fillWidth: true
                                flat: true
                                highlighted: window.section === index
                                onClicked: window.section = index
                            }
                        }
                    }
                }
                ScrollView {
                    id: editorScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth
                    padding: window.width < 900 ? 16 : 24
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    background: Rectangle {
                        radius: 12
                        color: "#171c26"
                        border.color: "#2c3443"
                    }
                    ColumnLayout {
                        width: editorScroll.availableWidth
                        spacing: 20
                        Label {
                            text: window.section === -12 ? "SYSTEM / SOUND" : window.section === -11 ? "DESKTOP / NOTIFICATIONS" : window.section === -10 ? "SYSTEM / POWER" : window.section === -9 ? "DESKTOP / INPUT" : window.section === -8 ? "DESKTOP / APPEARANCE" : window.section === -7 ? "DESKTOP / DISPLAYS" : window.section === -6 ? "DESKTOP / SHORTCUTS" : window.section === -5 ? "SYSTEM / AGENTS" : window.section === -4 ? "SYSTEM / MAINTENANCE" : window.section === -3 ? "DESKTOP / SECURITY" : window.section === -2 ? "COMPOSITOR" : window.section === -1 ? "DESKTOP / TOPBAR" : "TOPBAR / APPEARANCE"
                            color: "#8796b5"
                            font.pixelSize: 9
                            font.letterSpacing: 1.6
                        }
                        Label {
                            text: window.section === -12 ? "Sound" : window.section === -11 ? "Notification delivery" : window.section === -10 ? "Power & battery" : window.section === -9 ? "Mouse, touchpad & keyboard" : window.section === -8 ? "Application theme" : window.section === -7 ? "Displays" : window.section === -6 ? "Keybindings" : window.section === -5 ? "Hyprskill" : window.section === -4 ? "System cleanup" : window.section === -3 ? "Screen locking" : window.section === -1 ? "Bar & layout" : window.section === -2 ? "Hyprland appearance" : window.names[window.selected.id] || ""
                            font.pixelSize: 23
                            font.bold: true
                        }
                        Label {
                            Layout.fillWidth: true
                            text: window.section === -12 ? "Choose sound devices, check your microphone, and adjust application volumes." : window.section === -11 ? "Choose popups, Do Not Disturb, and preferences for each application." : window.section === -10 ? "Adjust brightness, inactivity timers, laptop lid behavior, and supported power profiles." : window.section === -9 ? "Adjust pointing, scrolling, typing, and keyboard layouts. Changes save and apply automatically." : window.section === -8 ? "Choose light or dark application windows." : window.section === -7 ? "Set resolution, refresh rate, scale, rotation, and monitor positions. Confirm changes before they are saved." : window.section === -6 ? "Record a shortcut, choose its action, and save. Changes appear in Super + K." : window.section === -5 ? "Give your coding agents reusable knowledge of your machine." : window.section === -4 ? "Schedule cleanup and review files before removing them." : window.section === -3 ? "Choose your lock screen and when it activates." : window.section === -1 ? "Set the layout and default appearance for your desktop bar." : window.section === -2 ? "Fine-tune transparency, frosted glass, and window details. Changes save and apply automatically." : "Customize this item. Empty fields follow the original appearance."
                            wrapMode: Text.WordWrap
                            color: "#939bb3"
                        }
                        SettingsBarEditor {
                            visible: window.section === -1
                            Layout.fillWidth: true
                            settings: window.draft.bar
                            onEdited: (key, value) => window.updateBar(key, value)
                        }
                        SettingsItemEditor {
                            visible: window.section >= 0
                            Layout.fillWidth: true
                            settings: window.selected
                            allItems: window.draft.items
                            barSettings: window.draft.bar
                            saving: window.saving
                            onEdited: (key, value) => window.updateItem(key, value)
                            onMoveRequested: direction => window.moveItem(direction)
                            onResetRequested: window.resetItem()
                        }
                        SettingsLocking {
                            visible: window.section === -3
                            Layout.fillWidth: true
                            settings: window.draft.locking
                            saved: !window.dirty && !window.saving && window.success
                            runtimeError: window.lockingError
                            onLockRequested: window.lockRequested()
                            onEdited: (key, value) => window.updateLocking(key, value)
                        }
                        SettingsTheme {
                            id: themePage
                            visible: window.section === -8
                            Layout.fillWidth: true
                        }
                        SettingsDisplays {
                            visible: window.section === -7
                            Layout.fillWidth: true
                        }
                        SettingsKeybindings {
                            id: keybindingsPage
                            targetWindow: window
                            visible: window.section === -6
                            Layout.fillWidth: true
                            onEditorRequested: if (editorScroll.contentItem) editorScroll.contentItem.contentY = 0
                        }
                        SettingsCleanup {
                            id: cleanupPage
                            visible: window.section === -4
                            Layout.fillWidth: true
                        }
                        SettingsHyprskill {
                            id: hyprskillPage
                            visible: window.section === -5
                            Layout.fillWidth: true
                        }
                        SettingsPower {
                            id: powerPage
                            visible: window.section === -10
                            Layout.fillWidth: true
                            settings: window.draft.power
                            runtimeError: window.powerError
                            batteryInfo: window.batteryInfo
                            onEdited: (key, value) => window.updatePower(key, value)
                        }
                        SettingsNotifications {
                            visible: window.section === -11
                            Layout.fillWidth: true
                            settings: window.draft.notifications
                            applications: window.notificationApps
                            onEdited: (key, value) => window.updateNotifications(key, value)
                        }
                        SoundTest {
                            id: soundTester
                            sink: window.audioServices ? window.audioServices.sink : null
                            visible: window.visible && window.section === -12
                        }
                        SettingsSound {
                            id: soundPage
                            visible: window.visible && window.section === -12
                            Layout.fillWidth: true
                            services: window.audioServices
                            testSound: soundTester
                        }
                        SettingsInput {
                            visible: window.section === -9
                            Layout.fillWidth: true
                            settings: window.draft.hyprland
                            onEdited: (key, value) => window.updateHypr(key, value)
                        }
                        SettingsAppearance {
                            visible: window.section === -2
                            Layout.fillWidth: true
                            settings: window.draft.hyprland
                            onEdited: (key, value) => window.updateHypr(key, value)
                        }
                    }
                }
            }
            Label {
                Layout.fillWidth: true
                objectName: "settingsSaveNotice"
                Layout.minimumHeight: implicitHeight || 14
                text: !window.success ? (window.message || window.store.error) : window.savedNotice
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: 11
                color: window.success ? "#939bb3" : "#f38ba8"
            }
        }
    }
}
