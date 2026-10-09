import QtQuick
import Quickshell.Io

Item {
    id: input
    property var node: null
    property bool enabled: false
    property real peak: 0
    property bool ready: false
    property string error: ""
    readonly property bool capturing: enabled && !!node
    onCapturingChanged: update()
    onNodeChanged: update()
    function update() {
        capture.running = false;
        peak = 0; ready = false; error = "";
        if (capturing) {
            capture.command = ["python3", decodeURIComponent(Qt.resolvedUrl("settings/microphone.py").toString().replace(/^file:\/\//, "")), "--device", node.name];
            capture.running = true;
            startup.restart();
        } else startup.stop();
    }
    Process {
        id: capture
        stdout: SplitParser {
            onRead: line => {
                try {
                    let result = JSON.parse(line);
                    if (result.ok) {
                        input.peak = Math.max(0, Math.min(1, result.peak));
                        input.ready = true;
                        startup.stop();
                    } else {
                        input.error = result.message || "Could not test the microphone.";
                        input.ready = false; input.peak = 0;
                        startup.stop();
                    }
                } catch (e) {
                    input.error = "Could not read the microphone input level.";
                    input.ready = false; input.peak = 0;
                }
            }
        }
        stderr: StdioCollector {}
        onExited: code => {
            input.ready = false; input.peak = 0;
            if (input.capturing && !input.error) input.error = "Microphone test stopped. Check the input device and try again.";
        }
    }
    Timer {
        id: startup
        interval: 5000
        onTriggered: {
            input.error = "No microphone data received. Check the input device and PipeWire connection, then try again.";
            capture.running = false;
            input.ready = false; input.peak = 0;
        }
    }
}
