import QtQuick
import Quickshell.Io

Item {
    id: reader
    property string nativePath: ""
    property real fullMah: 0
    property real designMah: 0
    readonly property string filePath: nativePath.startsWith("/sys/") ? nativePath + "/uevent"
        : /^[A-Za-z0-9_.:-]+$/.test(nativePath) ? "/sys/class/power_supply/" + nativePath + "/uevent" : ""
    onFilePathChanged: { fullMah = 0; designMah = 0; }

    function readCapacity(text) {
        let full = 0;
        let design = 0;
        for (let line of text.split(/\r?\n/)) {
            let match = line.match(/^POWER_SUPPLY_CHARGE_(FULL|FULL_DESIGN)=(\d+)$/);
            if (!match) continue;
            // Linux reports charge in microamp-hours; the menu uses mAh.
            let value = Number(match[2]) / 1000;
            if (!Number.isFinite(value) || value <= 0) continue;
            if (match[1] === "FULL") full = value;
            else design = value;
        }
        fullMah = full;
        designMah = design;
    }

    FileView {
        id: capacityFile
        path: reader.filePath
        preload: true
        printErrors: false
        onLoaded: reader.readCapacity(text())
        onLoadFailed: { reader.fullMah = 0; reader.designMah = 0; }
    }
    Timer {
        interval: 60000
        running: reader.filePath.length > 0
        repeat: true
        onTriggered: capacityFile.reload()
    }
}
