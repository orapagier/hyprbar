import QtQuick
import QtQuick.Window

Window {
    id: preview
    visible: true
    width: 1366
    height: 100
    color: "#26293e"
    Rectangle { anchors.fill: parent; color: "#26293e" }
    Bar {
        id: bar
        x: 10; y: 5; width: parent.width - 20
        clockText: "Oct 08   12:34 PM   Thu"
        statusData: ({workspaces: [{id: 1, name: "1", active: true}, {id: 2, name: "2", active: false}, {id: 3, name: "3", active: false}],
                 audio: {icon: "󰕾", text: "48%"}, network: {text: "󰤨", connected: true},
                 bluetooth: {text: "󰂱", connected: true, powered: true},
                 battery: {present: true, text: "󰂁 82%"}})
        mediaData: ({playing: true, levels: [0.2,0.4,0.7,0.95,0.6,0.3,0.5,0.8,0.65,0.4,0.15,0.3], title: "Artist — Track title"})
        notificationData: ({count: 3, class: "unread"})
    }
    Timer {
        interval: 600; running: true
        onTriggered: preview.contentItem.grabToImage(result => {
            result.saveToFile(Qt.resolvedUrl("preview.png").toString().replace("file://", ""));
            Qt.quit();
        })
    }
}
