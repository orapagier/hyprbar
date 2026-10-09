import QtQuick
import Quickshell.Io

Item {
    id: input
    property var node: null
    property bool enabled: false
    property real peak: 0
    property bool clipping: false
    property bool ready: false
    property string error: ""
    readonly property bool capturing: enabled && !!node
    onCapturingChanged: update()
    onNodeChanged: update()
    function update() {
        capture.running = false;
        peak = 0; clipping = false; ready = false; error = "";
        stale.stop();
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
                if (!input.capturing || input.error) return;
                try {
                    let result = JSON.parse(line);
                    if (result.ok && Number.isFinite(result.peak)) {
                        input.peak = Math.max(0, Math.min(1, result.peak));
                        input.ready = true;
                        input.clipping = !!result.clipping;
                        startup.stop();
                        stale.restart();
                    } else {
                        input.error = result.message || "Could not test the microphone.";
                        input.ready = false; input.peak = 0; input.clipping = false;
                        startup.stop(); stale.stop();
                        capture.running = false;
                    }
                } catch (e) {
                    input.error = "Could not read the microphone input level.";
                    input.ready = false; input.peak = 0; input.clipping = false;
                    startup.stop(); stale.stop(); capture.running = false;
                }
            }
        }
        stderr: StdioCollector {}
        onExited: code => {
            startup.stop(); stale.stop();
            input.ready = false; input.peak = 0; input.clipping = false;
            if (input.capturing && !input.error) input.error = "Microphone test stopped. Check the input device and try again.";
        }
    }
    Timer {
        id: stale
        interval: 2000
        onTriggered: {
            input.error = "Microphone data stopped updating. Stop the test and try again.";
            input.ready = false; input.peak = 0; input.clipping = false;
            capture.running = false;
        }
    }
    Timer {
        id: startup
        interval: 5000
        onTriggered: {
            input.error = "No microphone data received. Check the input device and PipeWire connection, then try again.";
            capture.running = false;
            input.ready = false; input.peak = 0; input.clipping = false;
        }
    }
}
