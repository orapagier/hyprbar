pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: page
    signal launched()
    readonly property var entries: DesktopEntries.applications.values.filter(a => (a.name + " " + a.genericName).toLowerCase().includes(search.text.toLowerCase())).sort((a,b) => a.name.localeCompare(b.name))
    function launch(entry) {
        if (!entry || !entry.id) return;
        let desktopId = entry.id.endsWith(".desktop") ? entry.id : entry.id + ".desktop";
        // UWSM reads desktop metadata (including Terminal and working directory).
        // Services inherit the current manager environment after theme changes.
        Quickshell.execDetached(["uwsm", "app", "-t", "service", "--", desktopId]);
        launched();
    }
    spacing: 8
    AppIcons { id: icons; visible: false }
    TextField {
        id: search
        Layout.fillWidth: true
        placeholderText: "Search applications"; color: "#cdd6f4"; placeholderTextColor: "#a6adc8"
        font.family: "DejaVu Sans"; font.pixelSize: 13
        background: Rectangle { radius: 8; color: "#0bffffff"; border.color: "#1fffffff" }
        Component.onCompleted: forceActiveFocus()
        onAccepted: { if (page.entries.length) { page.launch(page.entries[0]); } }
        Keys.onDownPressed: applications.forceActiveFocus()
    }
    ListView {
        id: applications
        objectName: "applicationsList"
        Layout.fillWidth: true; Layout.preferredHeight: 300
        model: page.entries
        clip: true; spacing: 4
        keyNavigationEnabled: true
        Keys.onReturnPressed: { if (currentIndex >= 0 && page.entries[currentIndex]) { page.launch(page.entries[currentIndex]); } }
        delegate: AppListButton {
            required property var modelData
            required property int index
            width: applications.width
            text: modelData.name
            iconSource: icons.source(modelData.icon) || icons.source("application-x-executable")
            accent: applications.activeFocus && applications.currentIndex === index ? "#cba6f7" : "#cdd6f4"
            onClicked: { page.launch(modelData); }
        }
    }
}
