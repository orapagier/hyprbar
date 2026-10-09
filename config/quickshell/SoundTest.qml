import QtQuick
import Quickshell.Io

Item {
    id: test
    property var sink: null
    readonly property bool busy: player.running
    property string message: ""
    property bool success: true
    property bool requested: false
    property string selectedName: sink ? sink.name : ""
    onSelectedNameChanged: stop()
    onVisibleChanged: if (!visible) stop()
    function play() {
        if (busy || requested) return;
        if (!sink || !sink.audio) { success = false; message = "Select an available output first."; return; }
        if (sink.audio.muted) { success = false; message = "Your output is muted. Unmute it to hear the test sound."; return; }
        if (sink.audio.volume <= 0) { success = false; message = "Raise the output volume to hear the test sound."; return; }
        success = true;
        message = "Playing a short test tone…";
        requested = true;
        player.command = ["paplay", "--device=" + sink.name, "--volume=49152", "--client-name=Hyprshell", "--stream-name=Sound test", decodeURIComponent(Qt.resolvedUrl("sounds/test.wav").toString().replace(/^file:\/\//, ""))];
        player.running = true;
    }
    function stop() {
        if (!requested && !busy) return;
        requested = false;
        player.running = false;
        message = "Test sound stopped.";
    }
    Process {
        id: player
        stderr: StdioCollector {}
        onExited: (code, status) => {
            if (!test.requested) return;
            test.requested = false;
            test.success = code === 0;
            test.message = code === 0 ? "Test sound finished. Did you hear it?" : "Could not play the test sound. Check that the output is connected and PipeWire is running.";
        }
    }
    Timer {
        interval: 5000
        running: test.requested
        onTriggered: {
            test.stop();
            test.success = false;
            test.message = "Test sound timed out. Check that the output is connected and PipeWire is running.";
        }
    }
}
