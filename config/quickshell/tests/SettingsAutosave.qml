import QtQuick
import QtQuick.Window
import Quickshell
import ".."

ShellRoot {
    id: test
    property int phase: 0
    property int focusRequests: 0
    SettingsStore { id: prefs }
    SettingsWindow { id: ui; store: prefs; onFocusRequested: test.focusRequests++ }
    function audio() { return prefs.config.items.find(i => i.id === "audio"); }
    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: {
            if (test.phase === 0 && prefs.loaded) {
                ui.open();
                ui.section = ui.draft.items.findIndex(i => i.id === "audio");
                ui.updateItem("side", "left");
                let before = test.focusRequests;
                ui.open();
                if (test.focusRequests <= before || !ui.dirty || ui.draft.items[ui.section].side !== "left") { console.error("AUTOSAVE_REOPEN_LOST_EDIT_OR_FOCUS"); Qt.quit(); return; }
                test.phase = 1;
            } else if (test.phase === 1 && ui.saving) {
                // Edit during the first in-flight write. Both snapshots must
                // be committed in order without acknowledging an unsaved draft.
                ui.updateItem("textColor", "#ff8800");
                test.phase = 2;
            } else if (test.phase === 2 && !ui.dirty && !ui.saving) {
                if (test.audio().side !== "left" || test.audio().textColor !== "#ff8800") { console.error("AUTOSAVE_LOST_EDIT"); Qt.quit(); return; }
                // Reset must keep the saved custom position instead of moving
                // the module back to its bundled right-side defaults.
                ui.updateItem("side", "center");
                ui.updateItem("spacingRight", 19);
                ui.resetItem();
                if (ui.selected.side !== "left" || ui.selected.textColor !== "#ff8800" || ui.selected.spacingRight !== 0) { console.error("RESET_LOST_SAVED_SETTINGS"); Qt.quit(); return; }
                ui.updateItem("textColor", "#");
                test.phase = 3;
            } else if (test.phase === 3 && !ui.success && !ui.saving) {
                if (test.audio().textColor !== "#ff8800") { console.error("AUTOSAVE_INVALID_APPLIED"); Qt.quit(); return; }
                ui.updateItem("textColor", "#00ff00");
                test.phase = 4;
            } else if (test.phase === 4 && !ui.dirty && !ui.saving) {
                ui.updateItem("opacity", 0.7);
                ui.contentItem.Window.window.close();
                test.phase = 5;
            } else if (test.phase === 5 && !ui.dirty && !ui.saving) {
                if (test.audio().textColor !== "#00ff00" || test.audio().opacity !== 0.7) { console.error("AUTOSAVE_CLOSE_LOST_EDIT"); Qt.quit(); return; }
                ui.open();
                test.phase = 6;
            } else if (test.phase === 6 && ui.backingWindowVisible) {
                ui.contentItem.Window.window.close();
                test.phase = 7;
            } else if (test.phase === 7 && !ui.backingWindowVisible) {
                ui.open();
                test.phase = 8;
            } else if (test.phase === 8 && ui.backingWindowVisible) {
                ui.section = ui.draft.items.findIndex(i => i.id === "audio");
                ui.updateItem("pillGroup", "Connections");
                ui.section = ui.draft.items.findIndex(i => i.id === "wifi");
                ui.updateItem("pillGroup", "Connections");
                ui.updateItem("sharedBackground", "off");
                ui.updateBar("sharedBackground", "on");
                test.phase = 9;
            } else if (test.phase === 9 && !ui.dirty && !ui.saving) {
                let wifi = prefs.config.items.find(i => i.id === "wifi");
                if (test.audio().sharedBackground !== "off" || wifi.sharedBackground !== "off" || prefs.config.bar.sharedBackground !== "on") { console.error("SHARED_BACKGROUND_AUTOSAVE_LOST"); Qt.quit(); return; }
                console.log("AUTOSAVE_OK");
                Qt.quit();
            }
        }
    }
    Timer { interval: 15000; running: true; onTriggered: { console.error("AUTOSAVE_TIMEOUT", test.phase, ui.message); Qt.quit(); } }
}
