pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "SettingsModel.js" as Model

Item {
    id: controller
    required property var store
    readonly property var window: editor.item
    readonly property bool loaded: editor.active
    // Only failed, unsaved edits survive unloading; the controls do not.
    property var retainedSession: null
    signal focusRequested(var settingsWindow)

    function open() {
        editor.active = true;
        let ui = editor.item;
        if (!ui) return;
        if (retainedSession) {
            ui.editingSession = false;
            ui.initial = Model.copy(retainedSession.initial);
            ui.draft = Model.copy(retainedSession.draft);
            ui.section = retainedSession.section;
            ui.message = retainedSession.message;
            ui.success = retainedSession.success;
            ui.editingSession = true;
            retainedSession = null;
        }
        ui.open();
    }
    function releaseIfClosed() {
        let ui = editor.item;
        // Process startup is deferred. Dirty edits without a reported error
        // may still be waiting to start, even while running is briefly false.
        if (!ui || ui.visible || !ui.idle || (ui.dirty && ui.success)) return;
        retainedSession = ui.dirty ? {
            initial: Model.copy(ui.initial),
            draft: Model.copy(ui.draft),
            section: ui.section,
            message: ui.message,
            success: ui.success
        } : null;
        editor.active = false;
    }
    LazyLoader {
        id: editor
        active: false
        onItemChanged: release.restart()
        SettingsWindow {
            id: settingsWindow
            store: controller.store
            onFocusRequested: controller.focusRequested(settingsWindow)
        }
    }
    Connections {
        target: editor.item
        function onVisibleChanged() { release.restart(); }
        function onIdleChanged() { release.restart(); }
        function onDirtyChanged() { release.restart(); }
        function onSuccessChanged() { release.restart(); }
    }
    // Defer destruction until close handlers and process collectors finish.
    Timer { id: release; interval: 0; onTriggered: controller.releaseIfClosed() }
}
