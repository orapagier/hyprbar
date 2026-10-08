import QtQuick
import QtTest
import ".."

Item {
    id: root
    width: 320; height: 400
    QtObject {
        id: outputAudio
        property real volume: 0.5
        property bool muted: false
    }
    QtObject {
        id: inputAudio
        property real volume: 0.5
        property bool muted: false
    }
    QtObject {
        id: outputNode
        property var audio: outputAudio
        property string description: "Test speakers"
    }
    QtObject {
        id: inputNode
        property var audio: inputAudio
        property string description: "Test microphone"
    }
    QtObject {
        id: services
        property var sink: outputNode
        property var microphone: inputNode
        property var outputs: []
    }
    // Match the popup's background MouseArea to catch missed slider presses.
    MouseArea { anchors.fill: parent }
    readonly property var audioServices: services
    MenuPopover {
        id: popup
        anchors.fill: parent
        opened: true
        title: "Audio"; symbol: "󰕾"
        triggerRect: Qt.rect(140, 2, 40, 20)
        page: Component {
            AudioMenu { objectName: "audioMenuUnderTest"; services: root.audioServices }
        }
    }
    TestCase {
        name: "AudioMouseControls"
        when: windowShown

        function sliders(item) {
            let found = [];
            if (item.visualPosition !== undefined && item.from !== undefined)
                found.push(item);
            for (let child of item.children || [])
                found = found.concat(sliders(child));
            return found;
        }

        function test_mouseAdjustsBothVolumes() {
            let menu = findChild(popup, "audioMenuUnderTest");
            verify(menu !== null);
            let controls = sliders(menu);
            compare(controls.length, 2);
            let audioNodes = [outputAudio, inputAudio];
            for (let i = 0; i < controls.length; i++) {
                let slider = controls[i];
                let audio = audioNodes[i];
                verify(slider.height >= 24, "Slider needs a usable mouse hit area");
                let center = slider.handle.x + slider.handle.width / 2;
                mousePress(slider, center, slider.height / 2);
                verify(slider.pressed, "Mouse press must reach the slider");
                mouseMove(slider, slider.width * 0.8, slider.height / 2, 20);
                verify(audio.volume > 0.7, "Dragging must update volume while pressed");
                mouseRelease(slider, slider.width * 0.8, slider.height / 2);
                verify(!slider.pressed);
                mouseClick(slider, slider.width * 0.2, slider.height / 2);
                verify(audio.volume < 0.3, "Clicking the track must update volume");
                audio.volume = 0.6;
                tryCompare(slider, "value", 0.6);
            }
        }
    }
}
