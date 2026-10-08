import QtQuick
import QtTest
import ".."
import "../AudioStatus.js" as AudioStatus

Item {
    id: root
    width: 600; height: 90
    Rectangle { anchors.fill: parent; color: "#26293e" }
    Bar { id: bar; width: parent.width; clockText: "12:34 PM" }
    Row {
        id: samples
        x: 15; y: 40; spacing: 12
        Pill { icon: AudioStatus.icon(false, false, 0.8); text: "80%"; foreground: "#89b4fa" }
        Pill { icon: AudioStatus.icon(false, false, 0.3); text: "30%"; foreground: "#89b4fa" }
        Pill { icon: AudioStatus.icon(false, true, 0.8); text: "muted"; foreground: "#89b4fa" }
        Pill { icon: AudioStatus.icon(true, false, 0.8); text: "80%"; foreground: "#89b4fa" }
    }
    TestCase {
        name: "AudioOutputIcons"
        when: windowShown
        function test_headsetRouting_data() {
            let internal = {name: "alsa_output.internal", description: "Built-in Audio", properties: {"device.form-factor": "internal"}};
            let bluetooth = {name: "bluez_output.AA_BB_CC_DD_EE_FF.1", properties: {"api.bluez5.address": "AA:BB:CC:DD:EE:FF"}};
            return [
                {tag: "wired-headphones", sink: internal, route: {active_port: "analog-output-headphones"}, devices: [], expected: true},
                {tag: "wired-unplugged", sink: internal, route: {active_port: "analog-output-speaker"}, devices: [], expected: false},
                {tag: "usb-headset", sink: {name: "usb_output", properties: {"device.form-factor": "headset"}}, route: null, devices: [], expected: true},
                {tag: "usb-named-headphones", sink: {name: "usb_output", description: "USB Headphones"}, route: null, devices: [], expected: true},
                {tag: "bluetooth-headset", sink: bluetooth, route: null, devices: [{connected: true, address: "AA:BB:CC:DD:EE:FF", icon: "audio-headset"}], expected: true},
                {tag: "bluetooth-headphone-metadata", sink: bluetooth, route: {properties: {"device.form-factor": "headphone"}}, devices: [], expected: true},
                {tag: "bluetooth-speaker", sink: bluetooth, route: {properties: {"device.form-factor": "speaker"}}, devices: [{connected: true, address: "AA:BB:CC:DD:EE:FF", icon: "audio-speakers"}], expected: false},
                {tag: "headset-connected-but-speakers-selected", sink: internal, route: {active_port: "analog-output-speaker"}, devices: [{connected: true, address: "AA:BB:CC:DD:EE:FF", icon: "audio-headset"}], expected: false},
                {tag: "bluetooth-keyboard", sink: bluetooth, route: null, devices: [{connected: true, address: "AA:BB:CC:DD:EE:FF", icon: "input-keyboard"}], expected: false},
                {tag: "no-output", sink: null, route: null, devices: [], expected: false}
            ];
        }
        function test_headsetRouting(data) {
            compare(AudioStatus.headset(data.sink, data.route, data.devices), data.expected);
        }
        function test_barSwitchesIconWithOutput() {
            bar.statusData = {workspaces: [], audio: {icon: AudioStatus.icon(false, false, 0.8), text: "80%"}, network: {}, bluetooth: {}, battery: {}};
            let trigger = findChild(bar, "audioTrigger");
            compare(trigger.icon, "󰕾");
            compare(trigger.text, "80%");
            let speakers = trigger.icon;
            bar.statusData = {workspaces: [], audio: {icon: AudioStatus.icon(true, false, 0.8), text: "80%"}, network: {}, bluetooth: {}, battery: {}};
            verify(trigger.icon !== speakers);
            compare(trigger.icon, "󰋎");
            compare(trigger.text, "80%");
            verify(AudioStatus.icon(false, true, 0.8) !== speakers);
            compare(AudioStatus.icon(true, true, 0.8), trigger.icon);
        }
        function test_renderMaterialIcons() {
            waitForRendering(samples);
            let saved = false;
            root.grabToImage(result => { result.saveToFile("/tmp/quickshell-audio-icons.png"); saved = true; });
            tryVerify(() => saved);
        }
    }
}
