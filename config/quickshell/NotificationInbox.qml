pragma ComponentBehavior: Bound
import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Item {
    id: inbox
    property var rows: []
    property bool initialized: false
    readonly property int unread: rows.filter(r => r.unread).length
    readonly property var statusData: ({count: unread, tooltip: unread ? unread + " unread notifications" : "Notifications", class: unread ? "unread" : "empty"})
    PersistentProperties {
        id: session
        reloadableId: "native-notification-session"
        property string token: Date.now().toString()
    }
    function save() { if (initialized) history.setText(JSON.stringify(rows)); }
    function record(notification) {
        let old = rows.find(r => r.sourceId === notification.id && r.sessionToken === session.token);
        let entry = {id: old ? old.id : Date.now() + "-" + notification.id, sessionToken: session.token, restored: notification.lastGeneration, sourceId: notification.id, app: notification.appName, summary: notification.summary, body: notification.body, actions: notification.actions.map(a => ({id: a.identifier, text: a.text})), received: notification.lastGeneration && old ? old.received : Date.now(), unread: notification.lastGeneration && old ? old.unread : true, active: true};
        rows = [entry].concat(rows.filter(r => r.id !== entry.id));
        save();
    }
    function markRead() { rows = rows.map(r => Object.assign({}, r, {unread: false})); save(); }
    function dismiss(id) {
        let row = rows.find(r => r.id === id);
        let live = row && server.trackedNotifications.values.find(n => n.id === row.sourceId);
        if (live) live.dismiss();
        rows = rows.filter(r => r.id !== id); save();
    }
    function clear() {
        for (let n of server.trackedNotifications.values.slice()) n.dismiss();
        rows = []; save();
    }
    function invoke(id, actionId) {
        let row = rows.find(r => r.id === id);
        let n = row && server.trackedNotifications.values.find(n => n.id === row.sourceId);
        let action = n && n.actions.find(a => a.identifier === actionId);
        if (action) action.invoke();
    }
    FileView {
        id: history
        path: Quickshell.statePath("notifications.json")
        printErrors: false
        onLoaded: {
            try {
                let stored = JSON.parse(text());
                let current = inbox.rows.map(row => {
                    let old = stored.find(r => r.sessionToken === row.sessionToken && r.sourceId === row.sourceId);
                    return old && row.restored ? Object.assign({}, row, {id: old.id, received: old.received, unread: old.unread}) : row;
                });
                inbox.rows = current.concat(stored.filter(old => !current.some(row => row.id === old.id || (row.sessionToken === old.sessionToken && row.sourceId === old.sourceId))).map(row => Object.assign({}, row, {active: row.sessionToken === session.token && server.trackedNotifications.values.some(n => n.id === row.sourceId)})));
            }
            catch (error) { console.warn("Notification history:", error); }
            inbox.initialized = true;
            inbox.save();
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) legacyImport.running = true;
            else console.warn("Could not read notification history; leaving the file unchanged.");
        }
    }
    // One-time, read-only import of the previous inbox. No Python process is used.
    Process {
        id: legacyImport
        command: ["sqlite3", "-readonly", "-json", Quickshell.env("HOME") + "/.local/state/waybar/notifications/inbox.sqlite3", "SELECT id,app,summary,body,received,unread FROM notifications WHERE dismissed=0 ORDER BY received DESC"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let old = JSON.parse(text || "[]").map(r => ({id: "legacy-" + r.id, sourceId: -1, app: r.app, summary: r.summary, body: r.body, actions: [], received: r.received * 1000, unread: !!r.unread, active: false}));
                    inbox.rows = inbox.rows.concat(old);
                    inbox.save();
                } catch (error) { console.warn("Previous notification import:", error); }
            }
        }
        onExited: { inbox.initialized = true; inbox.save(); }
    }
    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        persistenceSupported: true
        bodySupported: true
        // The existing Mako configuration hides all toasts; retain that behavior.
        onNotification: notification => { notification.tracked = true; inbox.record(notification); }
    }
    Instantiator {
        model: server.trackedNotifications
        delegate: QtObject {
            id: tracked
            required property var modelData
            property Connections change: Connections {
                target: tracked.modelData
                function onSummaryChanged() { inbox.record(tracked.modelData); }
                function onBodyChanged() { inbox.record(tracked.modelData); }
                function onClosed() {
                    inbox.rows = inbox.rows.map(r => r.sourceId === tracked.modelData.id ? Object.assign({}, r, {active: false}) : r);
                    inbox.save();
                }
            }
            property Timer expiry: Timer {
                interval: tracked.modelData.expireTimeout > 0 ? tracked.modelData.expireTimeout : 5000
                running: !tracked.modelData.resident && tracked.modelData.expireTimeout !== 0
                onTriggered: tracked.modelData.expire()
            }
        }
    }
}
