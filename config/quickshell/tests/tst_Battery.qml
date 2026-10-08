import QtQuick
import QtTest
import ".."

Item {
    id: root
    width: 300; height: 640
    QtObject { id: services; property var batteryInfo: ({present: false}) }
    readonly property var batteryServices: services
    BatteryMenu { id: menu; width: 264; services: root.batteryServices }
    TestCase {
        name: "BatteryInformation"
        when: windowShown
        function sample() {
            return {present: true, percentage: 76, status: "Discharging", charging: false, pluggedIn: false, discharging: true, seconds: 7380, health: 91, power: -8.5, energy: 38.2, energyCapacity: 50.3, fullMah: 2867, designMah: 3950, model: "Test battery"};
        }
        function test_dischargeInformation() {
            services.batteryInfo = sample();
            compare(findChild(menu, "batteryCharge").text, "76%");
            compare(findChild(menu, "batteryStatus").text, "Discharging");
            tryVerify(() => findChild(menu, "batteryDetail-time") !== null);
            compare(findChild(menu, "batteryDetail-time").text, "2h 3m");
            compare(findChild(menu, "batteryDetail-health").text, "91.0%");
            compare(findChild(menu, "batteryDetail-power").text, "8.5 W");
            compare(findChild(menu, "batteryDetail-energy").text, "38.2 Wh");
            compare(findChild(menu, "batteryDetail-fullCharge").text, "2,867 mAh");
            compare(findChild(menu, "batteryDetail-designCharge").text, "3,950 mAh");
        }
        function test_chargingUpdatesLive() {
            services.batteryInfo = sample();
            let charging = sample();
            charging.charging = true; charging.pluggedIn = true; charging.discharging = false;
            charging.status = "Charging"; charging.seconds = 2400; charging.percentage = 80;
            services.batteryInfo = charging;
            compare(findChild(menu, "batteryCharge").text, "80%");
            compare(findChild(menu, "batteryStatus").text, "Charging");
            tryVerify(() => findChild(menu, "batteryDetail-time") !== null);
            compare(findChild(menu, "batteryDetail-time").text, "40m");
        }
        function test_healthUsesPercentageUnits() {
            let battery = sample();
            battery.health = 72.582278481;
            services.batteryInfo = battery;
            tryVerify(() => findChild(menu, "batteryDetail-health") !== null);
            compare(findChild(menu, "batteryDetail-health").text, "72.6%");
        }
        function test_careAdvice_data() {
            return [
                {tag: "low", charge: 15, plugged: false, charging: false, title: "Plug in soon"},
                {tag: "20-percent", charge: 20, plugged: false, charging: false, title: "Plug in soon"},
                {tag: "normal", charge: 50, plugged: false, charging: false, title: "Good charge level"},
                {tag: "charging", charge: 60, plugged: true, charging: true, title: "Charging toward 80%"},
                {tag: "80-percent", charge: 80, plugged: true, charging: true, title: "Consider unplugging"},
                {tag: "full-plugged-not-charging", charge: 100, plugged: true, charging: false, title: "Consider unplugging"},
                {tag: "high-unplugged", charge: 95, plugged: false, charging: false, title: "No charging needed"},
                {tag: "plugged-not-charging", charge: 70, plugged: true, charging: false, title: "Charger connected"}
            ];
        }
        function test_careAdvice(data) {
            let battery = sample();
            battery.percentage = data.charge; battery.pluggedIn = data.plugged; battery.charging = data.charging;
            services.batteryInfo = battery;
            compare(findChild(menu, "batteryCareTitle").text, data.title);
            verify(findChild(menu, "batteryCareMessage").text.length > 0);
        }
        function test_missingStatisticsAreNotShownAsZero() {
            let unknown = sample();
            unknown.seconds = 0; unknown.health = null; unknown.energyCapacity = 0;
            unknown.fullMah = 0; unknown.designMah = null;
            services.batteryInfo = unknown;
            tryVerify(() => findChild(menu, "batteryDetail-time") !== null);
            compare(findChild(menu, "batteryDetail-time").text, "Estimating…");
            compare(findChild(menu, "batteryDetail-health").text, "Not reported");
            compare(findChild(menu, "batteryDetail-capacity").text, "Not reported");
            compare(findChild(menu, "batteryDetail-fullCharge").text, "Not reported");
            compare(findChild(menu, "batteryDetail-designCharge").text, "Not reported");
            services.batteryInfo = {present: false};
            tryVerify(() => findChild(menu, "batteryDetail-health") === null);
            compare(findChild(menu, "batteryCareCard").visible, false);
        }
        function test_renderBatteryMenu() {
            services.batteryInfo = sample();
            waitForRendering(menu);
            let saved = false;
            menu.grabToImage(result => { result.saveToFile("/tmp/quickshell-battery-menu.png"); saved = true; });
            tryVerify(() => saved);
        }
    }
}
