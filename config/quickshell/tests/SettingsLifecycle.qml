import QtQuick
import QtQuick.Window
import Quickshell
import ".."

ShellRoot {
    id: test
    property real phase: 0
    SettingsStore { id: prefs }
    SettingsController { id: settings; store: prefs }
    function audio() { return prefs.config.items.find(i => i.id === "audio"); }
    function selectAudio() { settings.window.section = settings.window.draft.items.findIndex(i => i.id === "audio"); }
    function close() { settings.window.contentItem.Window.window.close(); }
    function fail(message) { console.error("LIFECYCLE_FAILED", phase, message, settings.loaded, settings.retainedSession ? settings.retainedSession.message : "no retained draft", JSON.stringify(test.audio()), settings.window ? [settings.window.visible, settings.window.dirty, settings.window.saving, settings.window.idle, settings.window.message, settings.window.editingSession] : "unloaded"); Qt.quit(); }
    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: {
            if (test.phase === 0 && prefs.loaded) {
                if (settings.loaded || settings.window !== null) { test.fail("UI instantiated before first open"); return; }
                settings.open();
                test.phase = 0.5;
            } else if (test.phase === 0.5 && settings.window && settings.window.backingWindowVisible) {
                test.selectAudio();
                settings.window.updateItem("side", "left");
                test.close();
                test.phase = 1;
            } else if (test.phase === 1 && settings.window && settings.window.saving) {
                if (!settings.loaded || settings.window.visible) { test.fail("UI unloaded during a save"); return; }
                // A second edit while closing must be saved before destruction.
                settings.window.updateItem("textColor", "#00ff00");
                test.phase = 2;
            } else if (test.phase === 2 && !settings.loaded) {
                if (test.audio().side !== "left" || test.audio().textColor !== "#00ff00") { test.fail("queued save lost"); return; }
                settings.open();
                test.phase = 3;
            } else if (test.phase === 3 && settings.window.backingWindowVisible) {
                test.close();
                test.phase = 4;
            } else if (test.phase === 4 && !settings.loaded) {
                settings.open();
                test.phase = 4.5;
            } else if (test.phase === 4.5 && settings.window && settings.window.backingWindowVisible) {
                test.selectAudio();
                settings.window.updateItem("textColor", "#");
                test.close();
                test.phase = 5;
            } else if (test.phase === 5 && !settings.loaded) {
                if (test.audio().textColor !== "#00ff00" || !settings.retainedSession) { test.fail("invalid edit applied or discarded"); return; }
                settings.open();
                if (settings.window.selected.textColor !== "#" || !settings.window.dirty || settings.window.success) { test.fail("failed draft not restored"); return; }
                test.phase = 5.5;
            } else if (test.phase === 5.5 && settings.window && settings.window.backingWindowVisible) {
                settings.window.updateItem("textColor", "#00ff00");
                test.close();
                test.phase = 6;
            } else if (test.phase === 6 && !settings.loaded) {
                settings.open();
                test.phase = 6.5;
            } else if (test.phase === 6.5 && settings.window && settings.window.backingWindowVisible) {
                test.selectAudio();
                settings.window.updateItem("side", "right");
                let original = settings.window;
                test.close();
                settings.open();
                if (settings.window !== original || !settings.window.visible || settings.window.selected.side !== "right") { test.fail("reopen during save lost window or draft"); return; }
                test.close();
                test.phase = 7;
            } else if (test.phase === 7 && !settings.loaded) {
                if (settings.window !== null || test.audio().side !== "right" || test.audio().textColor !== "#00ff00") { test.fail("final save or unloading failed"); return; }
                console.log("LIFECYCLE_OK");
                Qt.quit();
            }
        }
    }
    Timer { interval: 15000; running: true; onTriggered: test.fail("timeout") }
}
