import QtQuick
import QtTest
import "../NotificationPolicy.js" as Policy
import "../SettingsModel.js" as Model
import ".."

Item {
    width: 600; height: 1000
    SettingsNotifications {
        id: page
        width: parent.width
        settings: ({popups: false, doNotDisturb: false, criticalBypass: true, popupSeconds: 5, apps: {}})
        applications: ["org.example.App", "org.example.App"]
        onEdited: (key, value) => { let next = Model.copy(settings); next[key] = value; settings = next; }
    }
    TestCase {
        name: "NotificationPolicy"
        when: windowShown
        function test_deliveryMatrix() {
            for (let popups of [false, true]) for (let dnd of [false, true])
                for (let bypass of [false, true]) for (let critical of [false, true])
                    for (let mode of [undefined, "inbox", "off"]) {
                        let result = Policy.delivery({popups: popups, doNotDisturb: dnd, criticalBypass: bypass, apps: {app: mode}}, "app", critical);
                        compare(result.inbox, mode !== "off");
                        compare(result.popup, mode === undefined && popups && (!dnd || critical && bypass));
                    }
        }
        function test_appIdentity() {
            compare(Policy.appKey({desktopEntry: "org.example.App", appName: "Example"}), "org.example.App");
            compare(Policy.appKey({appName: "Example"}), "Example");
            compare(Policy.appKey({}), "Unknown application");
        }
        function test_controlsAndOverrides() {
            let popup = findChild(page, "notificationPopupsControl");
            mouseClick(popup); compare(page.settings.popups, true);
            let dnd = findChild(page, "notificationDndControl");
            mouseClick(dnd); compare(page.settings.doNotDisturb, true);
            page.setApp("org.example.App", "off");
            compare(page.settings.apps["org.example.App"], "off");
            compare(page.knownApps.length, 1);
            page.setApp("org.example.App", "inherit");
            compare(Object.keys(page.settings.apps).length, 0);
        }
        function test_oldSettingsInheritNotificationDefaults() {
            let defaults = {version: 1, bar: {}, items: [], notifications: {popups: false, doNotDisturb: false, apps: {}}};
            let result = Model.merge(defaults, {version: 1, items: []});
            compare(result.notifications.popups, false);
            result = Model.merge(defaults, {version: 1, items: [], notifications: {doNotDisturb: true, apps: {app: "inbox"}}});
            compare(result.notifications.doNotDisturb, true);
            compare(result.notifications.apps.app, "inbox");
        }
    }
}
