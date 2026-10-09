import QtQuick
import Quickshell
import ".."

ShellRoot {
    id: test
    property int index: 0
    property bool waiting: false
    PowerMenu { id: menu }
    KeybindingsMenu { id: shortcuts }
    Component.onCompleted: {
        // Never execute a real lock, shutdown, reboot, sleep, or logout in tests.
        menu.actions = menu.actions.map(entry => Object.assign({}, entry, {command: ["/usr/bin/false"]}));
        if (menu.runShortcut(Qt.Key_Q)) { console.error("POWER_UNKNOWN_KEY"); Qt.quit(); }
    }
    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: {
            if (test.waiting) {
                if (menu.error !== "Action failed") return;
                test.waiting = false;
                test.index++;
            }
            if (test.index === menu.actions.length) {
                console.log("POWER_SHORTCUTS_OK"); Qt.quit(); return;
            }
            let entry = menu.actions[test.index];
            if (!shortcuts.entries.some(binding => binding.shortcut === entry.shortcut && binding.action === entry.description)) {
                console.error("POWER_SHORTCUT_MISSING"); Qt.quit(); return;
            }
            menu.error = "";
            if (!menu.runShortcut(entry.key)) { console.error("POWER_KEY_NOT_HANDLED"); Qt.quit(); return; }
            test.waiting = true;
        }
    }
    Timer { interval: 5000; running: true; onTriggered: { console.error("POWER_SHORTCUT_TIMEOUT"); Qt.quit(); } }
}
