import QtQuick
import QtTest
import ".."

Item {
    id: root
    property real testPeak: 0.65
    property bool testClipping: false
    width: 820; height: 1600
    QtObject { id: outputAudio; property real volume: 0.5; property bool muted: false }
    QtObject { id: inputAudio; property real volume: 0.5; property bool muted: false }
    QtObject { id: appAudio; property real volume: 0.6; property bool muted: false }
    QtObject { id: output; property var audio: outputAudio; property string description: "Speakers"; property string name: "test.output" }
    QtObject { id: otherOutput; property var audio: outputAudio; property string description: "Headphones"; property string name: "test.headphones" }
    QtObject { id: input; property var audio: inputAudio; property string description: "Microphone"; property string name: "test.input" }
    QtObject { id: otherInput; property var audio: inputAudio; property string description: "USB microphone"; property string name: "test.usb" }
    QtObject {
        id: app
        property int id: 10
        property var audio: appAudio
        property var properties: ({"application.name": "Test player"})
        property string description: "Playback"
        property string name: "test.player"
        property bool isSink: false
    }
    QtObject {
        id: services
        property var sink: output
        property var microphone: input
        property var outputs: [output, otherOutput]
        property var inputs: [input, otherInput]
        property var applicationStreams: [app]
        function setOutput(node) { sink = node; }
        function setInput(node) { microphone = node; }
    }
    SettingsSound {
        id: page
        width: parent.width
        services: services
        meterComponent: Component { Item { readonly property real peak: root.testPeak; readonly property bool clipping: root.testClipping; readonly property bool ready: true; readonly property string error: "" } }
    }
    TestCase {
        name: "SettingsSound"
        when: windowShown
        function init() {
            services.sink = output; services.microphone = input;
            services.outputs = [output, otherOutput]; services.inputs = [input, otherInput];
            services.applicationStreams = [app];
            outputAudio.volume = 0.5; inputAudio.volume = 0.5; appAudio.volume = 0.6;
            outputAudio.muted = false; inputAudio.muted = false; appAudio.muted = false;
            page.visible = true; page.meterEnabled = false;
            root.width = 820;
        }
        function test_selectDevicesAndHandleHotplug() {
            let outputControl = findChild(page, "soundOutputControl");
            let inputControl = findChild(page, "soundInputControl");
            compare(outputControl.currentIndex, 0);
            outputControl.activated(1); compare(services.sink, otherOutput);
            inputControl.activated(1); compare(services.microphone, otherInput);
            compare(inputControl.currentIndex, 1);
            services.microphone = input;
            compare(inputControl.currentIndex, 0);
            services.sink = null; services.outputs = [];
            services.microphone = null; services.inputs = [];
            compare(outputControl.enabled, false); compare(inputControl.enabled, false);
            compare(findChild(page, "soundTestControl").enabled, false);
            compare(findChild(page, "soundMeterControl").enabled, false);
        }
        function test_volumeMouseKeyboardAndMute() {
            let groups = [findChild(page, "soundOutputVolume"), findChild(page, "soundInputVolume"), findChild(page, "soundAppVolume-10")];
            let audios = [outputAudio, inputAudio, appAudio];
            for (let i = 0; i < groups.length; ++i) {
                let slider = findChild(groups[i], "soundVolumeControl");
                verify(slider.height >= 28);
                mouseClick(slider, slider.width * 0.8, slider.height / 2);
                verify(audios[i].volume > 0.7);
                slider.forceActiveFocus();
                let previous = audios[i].volume;
                keyClick(Qt.Key_Left);
                verify(audios[i].volume < previous);
                mouseClick(findChild(groups[i], "soundMuteControl"));
                compare(audios[i].muted, true);
                audios[i].volume = 0.3;
                compare(slider.value, i === 1 ? 0 : 0.3);
            }
        }
        function test_microphoneMuteEmptiesVolumeAndUnmuteRestoresGain() {
            let group = findChild(page, "soundInputVolume");
            let slider = findChild(group, "soundVolumeControl");
            let mute = findChild(group, "soundMuteControl");
            inputAudio.volume = 1;
            mouseClick(mute);
            compare(mute.text, "Unmute");
            compare(slider.value, 0);
            compare(slider.background.children[0].width, 0);
            compare(inputAudio.volume, 1);
            mouseClick(mute);
            compare(slider.value, 1);
            compare(inputAudio.volume, 1);
            mouseClick(mute);
            mouseClick(slider, slider.width * 0.4, slider.height / 2);
            compare(inputAudio.muted, false);
            verify(inputAudio.volume > 0.3 && inputAudio.volume < 0.5);
            compare(slider.value, inputAudio.volume);
        }
        function test_microphoneMeterRequiresStartAndStopsOnLeaveOrDeviceChange() {
            compare(page.metering, false);
            mouseClick(findChild(page, "soundMeterControl"));
            tryCompare(page, "metering", true);
            tryCompare(page, "inputPeak", 0.65);
            let bar = findChild(page, "soundInputMeter");
            compare(bar.value, 0.65);
            inputAudio.muted = true; compare(bar.value, 0);
            compare(bar.contentItem.children[0].width, 0);
            inputAudio.muted = false;
            compare(bar.value, 0.65);
            services.microphone = otherInput;
            compare(page.meterEnabled, false); compare(page.metering, false);
            page.meterEnabled = true;
            page.visible = false;
            compare(page.meterEnabled, false); compare(page.metering, false);
            page.visible = true; compare(page.metering, false);
        }
        function test_meterFillTracksChangingInput() {
            page.meterEnabled = true;
            let bar = findChild(page, "soundInputMeter");
            let fill = bar.contentItem.children[0];
            for (let value of [0, 0.2, 0.8, 1, 0.1, 0]) {
                root.testPeak = value;
                waitForRendering(page);
                compare(bar.value, value);
                fuzzyCompare(fill.width, bar.contentItem.width * value, 0.5);
            }
            root.testPeak = 0.65;
            root.testClipping = true;
            verify(findChild(page, "soundInputStatus").text.indexOf("clipping") >= 0);
            root.testClipping = false;
        }
        function test_appStreamRemoval() {
            verify(findChild(page, "soundAppVolume-10") !== null);
            services.applicationStreams = [];
            wait(0);
            compare(findChild(page, "soundAppVolume-10"), null);
        }
        function test_narrowLayout() {
            root.width = 480;
            waitForRendering(page);
            for (let name of ["soundOutputControl", "soundInputControl", "soundMeterControl", "soundTestControl"]) {
                let child = findChild(page, name);
                let position = child.mapToItem(page, 0, 0);
                verify(position.x >= 0 && position.x + child.width <= page.width + 1, name);
            }
        }
    }
}
