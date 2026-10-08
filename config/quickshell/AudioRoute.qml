import QtQuick
import Quickshell.Io
import "AudioStatus.js" as AudioStatus

Item {
    id: route
    required property var sink
    property var bluetoothDevices: []
    property var pulseSinks: []
    property bool refreshPending: false
    readonly property var activeSink: sink ? pulseSinks.find(s => s.name === sink.name) || null : null
    readonly property bool headset: AudioStatus.headset(sink, activeSink, bluetoothDevices)
    onSinkChanged: refreshDelay.restart()
    Component.onCompleted: refreshDelay.start()

    Timer {
        id: refreshDelay
        interval: 80
        onTriggered: {
            if (query.running) route.refreshPending = true;
            else query.running = true;
        }
    }
    // Quickshell exposes node properties; pactl supplies the active jack/port.
    Process {
        id: query
        command: ["pactl", "--format=json", "list", "sinks"]
        environment: ({LC_ALL: "C"})
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let sinks = JSON.parse(text);
                    if (Array.isArray(sinks)) route.pulseSinks = sinks;
                } catch (error) { route.pulseSinks = []; }
            }
        }
        stderr: StdioCollector {}
        onExited: code => {
            if (code !== 0) route.pulseSinks = [];
            if (route.refreshPending) { route.refreshPending = false; refreshDelay.restart(); }
        }
    }
    Process {
        id: events
        command: ["pactl", "subscribe"]
        environment: ({LC_ALL: "C"})
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (/ on (sink|card|server) #/.test(line)) refreshDelay.restart();
            }
        }
        stderr: StdioCollector {}
        onStarted: refreshDelay.restart()
        onExited: { route.pulseSinks = []; reconnect.restart(); }
    }
    Timer { id: reconnect; interval: 5000; onTriggered: events.running = true }
}
