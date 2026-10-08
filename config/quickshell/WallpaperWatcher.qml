import QtQuick
import Quickshell.Io
import "WallpaperQuery.js" as Query

QtObject {
    id: watcher
    property var sources: ({})
    function acceptQuery(text) {
        let next = Query.sources(text);
        if (JSON.stringify(next) !== JSON.stringify(sources)) sources = next;
    }
    readonly property Process query: Process {
        command: ["awww", "query"]
        running: true
        environment: ({LC_ALL: "C"})
        stdout: StdioCollector { onStreamFinished: watcher.acceptQuery(text) }
        stderr: StdioCollector {}
    }
    readonly property Timer poll: Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: if (!watcher.query.running) watcher.query.running = true
    }
}
