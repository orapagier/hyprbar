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
    property string lockingError: ""
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
    readonly property bool idle: !writer.running && !autoSave.running && !cleanupPage.busy && !githubSync.running
    onDraftChanged: if (editingSession) autoSave.restart()
    onVisibleChanged: if (!visible && editingSession && dirty) apply()
    property int section: -1
    onSectionChanged: Qt.callLater(() => { if (editorScroll.contentItem) editorScroll.contentItem.contentY = 0; })
    property string message: ""
    property bool success: true
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
        next.items[section][key] = value;
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
    function apply() {
        if (writer.running || !dirty) return;
        if (store.error || !store.loaded) {
            message = store.error;
            success = false;
            return;
        }
        autoSave.stop();
        submitted = Model.copy(draft);
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
                    window.message = result.ok ? result.message.replace("Settings applied.", "Saved automatically.") : result.message;
                    if (result.ok) {
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
    Process {
        id: githubSync
        property string action: ""
        function request(action, extra) {
            githubSync.action = action;
            window.syncSuccess = true;
            window.syncMessage = action === "--status" ? "Checking GitHub setup…" : action === "--authenticate" ? "Complete sign-in in the authentication window…" : "Syncing your desktop to GitHub…";
            command = ["python3", decodeURIComponent(Qt.resolvedUrl("settings/github_sync.py").toString().replace(/^file:\/\//, ""))].concat(action ? [action] : []).concat(extra || []);
            running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let result = JSON.parse(text);
                    window.syncSuccess = result.ok;
                    window.syncMessage = result.message;
                    if (githubSync.action === "--status" && result.ok) {
                        commitName.text = result.name || "";
                        commitEmail.text = result.email || "";
                    }
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
            Label { text: "orapagier/hyprshell"; color: "#b4a2ff" }
            Label { Layout.fillWidth: true; text: "Your commit identity is saved for this repository. Sign in separately to allow GitHub pushes."; wrapMode: Text.WordWrap; color: "#939bb3" }
            Label { text: "Commit name / username"; color: "#ecebff" }
            TextField {
                id: commitName
                objectName: "githubCommitName"
                Layout.fillWidth: true
                enabled: !githubSync.running
                placeholderText: "Your name or GitHub username"
                color: "#ecebff"; placeholderTextColor: "#939bb3"
                background: Rectangle { color: "#10131c"; radius: 6; border.color: "#545d79" }
            }
            Label { text: "Commit email"; color: "#ecebff" }
            TextField {
                id: commitEmail
                objectName: "githubCommitEmail"
                Layout.fillWidth: true
                enabled: !githubSync.running
                placeholderText: "Email or GitHub noreply email"
                color: "#ecebff"; placeholderTextColor: "#939bb3"
                background: Rectangle { color: "#10131c"; radius: 6; border.color: "#545d79" }
            }
            Label { Layout.fillWidth: true; text: "Authenticate opens a terminal and browser. If GitHub CLI is missing, the terminal offers to install it."; wrapMode: Text.WordWrap; color: "#939bb3"; font.pixelSize: 11 }
            Label { Layout.fillWidth: true; text: window.syncMessage; wrapMode: Text.WrapAnywhere; color: window.syncSuccess ? "#9eafb7" : "#f38ba8" }
            RowLayout {
                SettingsButton {
                    text: "Authenticate"
                    enabled: !githubSync.running
                    onClicked: githubSync.request("--authenticate", [])
                }
                SettingsButton {
                    objectName: "githubConfirmSync"
                    text: githubSync.running ? "Working…" : "Sync"
                    highlighted: true
                    enabled: !githubSync.running && commitName.text.trim() !== "" && commitEmail.text.trim() !== "" && !window.dirty && !window.saving && window.success
                    onClicked: githubSync.request("", ["--name", commitName.text, "--email", commitEmail.text])
                }
                SettingsButton { text: "Close"; enabled: !githubSync.running; onClicked: githubDialog.close() }
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
                Label {
                    text: window.saving ? "●  Saving…" : !window.success ? "●  Check your changes" : window.dirty ? "●  Saving soon…" : "●  Saved automatically"
                    font.pixelSize: 11
                    color: !window.success ? "#f38ba8" : window.dirty ? "#e7ca98" : "#9eafb7"
                }
                SettingsButton {
                    objectName: "githubSyncButton"
                    text: githubSync.running ? "Syncing…" : "  Sync to GitHub"
                    enabled: !githubSync.running && !window.dirty && !window.saving && window.success && window.store.loaded && !cleanupPage.busy
                    ToolTip.visible: hovered
                    ToolTip.text: "Commit and push live Hyprland, Quickshell, and saved settings to orapagier/hyprshell"
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
            Label {
                Layout.fillWidth: true
                visible: window.syncMessage !== ""
                text: window.syncMessage
                wrapMode: Text.WrapAnywhere
                color: window.syncSuccess ? "#9eafb7" : "#f38ba8"
                font.pixelSize: 11
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
                            text: window.section === -4 ? "SYSTEM / MAINTENANCE" : window.section === -3 ? "DESKTOP / SECURITY" : window.section === -2 ? "COMPOSITOR" : window.section === -1 ? "DESKTOP / TOPBAR" : "TOPBAR / APPEARANCE"
                            color: "#8796b5"
                            font.pixelSize: 9
                            font.letterSpacing: 1.6
                        }
                        Label {
                            text: window.section === -4 ? "System cleanup" : window.section === -3 ? "Screen locking" : window.section === -1 ? "Bar & layout" : window.section === -2 ? "Hyprland appearance" : window.names[window.selected.id] || ""
                            font.pixelSize: 23
                            font.bold: true
                        }
                        Label {
                            Layout.fillWidth: true
                            text: window.section === -4 ? "Schedule cleanup and review files before removing them." : window.section === -3 ? "Choose your lock screen and when it activates." : window.section === -1 ? "Set the layout and default appearance for your desktop bar." : window.section === -2 ? "Fine-tune transparency, frosted glass, and window details. Changes save and apply automatically." : "Customize this item. Empty fields follow the original appearance."
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
                        SettingsCleanup {
                            id: cleanupPage
                            visible: window.section === -4
                            Layout.fillWidth: true
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
                text: window.section === -4 ? "Cleanup choices apply when you click Save cleanup settings" : !window.success ? (window.message || window.store.error) : "Changes save and apply automatically"
                wrapMode: Text.WordWrap
                font.pixelSize: 11
                color: window.success ? "#939bb3" : "#f38ba8"
            }
        }
    }
}
