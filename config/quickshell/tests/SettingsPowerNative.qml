import QtQuick
import QtQuick.Window
import Quickshell
import ".."

ShellRoot {
    id: test
    property int phase: 0
    QtObject {
        id: prefs
        property bool loaded: true
        property var config: ({locking: {enabled: false, command: "hyprlock", idleMinutes: 5, beforeSleep: true}, power: {dimMinutes: 0, dimPercent: 20, offMinutes: 0, suspendMinutes: 0, lidAction: "system", profile: "system"}})
    }
    LockingController { id: idle; store: prefs }
    PowerController { id: power; store: prefs }
    Window {
        visible: true; width: 820; height: 1500
        SettingsPower {
            id: page
            width: parent.width
            settings: prefs.config.power
            onEdited: (key, value) => {
                let next = JSON.parse(JSON.stringify(prefs.config));
                next.power[key] = value;
                prefs.config = next;
            }
        }
    }
    function find(root, name) {
        if (root.objectName === name) return root;
        for (let child of root.children || []) { let match = find(child, name); if (match) return match; }
        return null;
    }
    function fail(message) { console.error("POWER_UI_FAILED", phase, message); Qt.quit(); }
    Timer {
        interval: 250; running: true; repeat: true
        onTriggered: {
            if (test.phase === 0 && page.status.brightness && !page.busy) {
                if (prefs.config.power.dimMinutes !== 0 || prefs.config.locking.enabled) { test.fail("initial settings changed"); return; }
                let profiles = test.find(page, "powerProfileControl");
                if (profiles.model.indexOf("Performance") >= 0 || profiles.model.length !== 3) { test.fail("unsupported profiles"); return; }
                test.find(page, "dimMinutesControl").edited(3);
                test.find(page, "offMinutesControl").edited(5);
                test.find(page, "suspendMinutesControl").edited(10);
                if (prefs.config.power.dimMinutes !== 3 || prefs.config.power.suspendMinutes !== 10 || prefs.config.locking.enabled) { test.fail("timer edits"); return; }
                test.find(page, "powerBrightnessControl").edited(37);
                profiles.activated(1);
                test.find(page, "lidActionControl").activated(2);
                test.phase = 1;
            } else if (test.phase === 1 && page.status.brightness.percent === 37 && !page.busy) {
                if (prefs.config.power.profile !== "power-saver" || prefs.config.power.lidAction !== "ignore") { test.fail("profile or lid choice"); return; }
                test.find(page, "dimMinutesControl").edited("");
                test.find(page, "offMinutesControl").edited("");
                test.find(page, "suspendMinutesControl").edited("");
                test.find(page, "lidActionControl").activated(0);
                test.phase = 2;
            } else if (test.phase === 2) {
                if (power.error || idle.error) { test.fail(power.error + idle.error); return; }
                if (prefs.config.power.dimMinutes !== 0 || prefs.config.power.offMinutes !== 0 || prefs.config.power.suspendMinutes !== 0) { test.fail("timer reset"); return; }
                page.width = 480;
                test.phase = 3;
            } else if (test.phase === 3) {
                for (let name of ["powerBrightnessControl", "dimMinutesControl", "lidActionControl", "powerProfileControl"]) {
                    let control = test.find(page, name);
                    let position = control.mapToItem(page, 0, 0);
                    if (position.x < 0 || position.x + control.width > page.width + 1) { test.fail("narrow layout " + name); return; }
                }
                console.log("POWER_UI_OK"); Qt.quit();
            }
        }
    }
    Timer { interval: 10000; running: true; onTriggered: test.fail("timeout: " + page.message) }
}
