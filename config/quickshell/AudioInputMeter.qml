import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: input
    property var node: null
    property bool enabled: false
    readonly property real peak: monitor.enabled ? Math.max(0, Math.min(1, monitor.peak)) : 0
    PwNodePeakMonitor {
        id: monitor
        node: input.enabled ? input.node : null
        enabled: input.enabled && !!input.node
    }
}
