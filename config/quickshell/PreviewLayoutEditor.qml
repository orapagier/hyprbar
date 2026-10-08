pragma ComponentBehavior: Bound
import QtQuick
import "SettingsModel.js" as Model

Item {
    id: editor
    required property var bar
    property var names: ({})
    property string draggedId: ""
    property bool dragging: false
    property real pressX: 0
    property real pressY: 0
    property real pointerX: 0
    property var destination: ({side:"left", beforeId:"", markerX:0})
    signal itemSelected(string id)
    signal itemDropped(string id, string side, string beforeId)
    z: 10

    function itemAt(x, y) {
        return Object.keys(bar.moduleItems).find(id => {
            let item = bar.moduleItems[id];
            return item.visible && x >= item.x && x <= item.x + item.width && y >= item.y && y <= item.y + item.height;
        }) || "";
    }
    function dropAt(x, y) {
        let hoveredId = itemAt(x, y);
        let side = hoveredId ? bar.side(hoveredId) : x < width / 3 ? "left" : x > width * 2 / 3 ? "right" : "center";
        let group = Object.keys(bar.moduleItems).filter(id => id !== draggedId && bar.moduleItems[id].visible && bar.side(id) === side)
            .sort((a, b) => bar.moduleItems[a].x - bar.moduleItems[b].x);
        let before = group.find(id => x < bar.moduleItems[id].x + bar.moduleItems[id].width / 2);
        let last = group.length ? bar.moduleItems[group[group.length - 1]] : null;
        return {side:side, beforeId:before || "", markerX:before ? bar.moduleItems[before].x - 2 : last ? last.x + last.width + 2 : side === "left" ? 2 : side === "right" ? width - 2 : width / 2};
    }
    // This overlay captures gestures only in the settings preview.
    MouseArea {
        id: pointer
        objectName: "previewDragArea"
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: editor.dragging ? Qt.ClosedHandCursor : editor.itemAt(mouseX, mouseY) ? Qt.OpenHandCursor : Qt.ArrowCursor
        onPressed: mouse => {
            editor.draggedId = editor.itemAt(mouse.x, mouse.y);
            editor.pressX = mouse.x;
            editor.pressY = mouse.y;
            editor.pointerX = mouse.x;
        }
        onPositionChanged: mouse => {
            if (!pressed || !editor.draggedId) return;
            if (Math.abs(mouse.x-editor.pressX) + Math.abs(mouse.y-editor.pressY) >= 6)
                editor.dragging = true;
            editor.pointerX = mouse.x;
            editor.destination = editor.dropAt(mouse.x, mouse.y);
        }
        onReleased: mouse => {
            if (editor.draggedId) {
                if (editor.dragging && mouse.x >= 0 && mouse.x <= width && mouse.y >= 0 && mouse.y <= height) {
                    let target = editor.dropAt(mouse.x, mouse.y);
                    editor.itemDropped(editor.draggedId, target.side, target.beforeId);
                } else if (!editor.dragging) {
                    editor.itemSelected(editor.draggedId);
                }
            }
            editor.dragging = false;
            editor.draggedId = "";
        }
        onCanceled: { editor.dragging = false; editor.draggedId = ""; }
    }
    Rectangle {
        visible: editor.dragging
        x: editor.destination.markerX - 1
        y: 1; width: 2; height: editor.height - 2
        color: "#d1b5ff"
        radius: 1
    }
    Rectangle {
        visible: editor.dragging
        x: Math.max(0, Math.min(editor.width-width, editor.pointerX-width/2))
        y: editor.height + 4
        width: caption.implicitWidth + 24; height: 28
        radius: 10; color: "#35304e"; border.color: "#b99ce4"
        Text {
            id: caption
            anchors.centerIn: parent
            text: (editor.names[editor.draggedId] || editor.draggedId) + " → " + editor.destination.side
            color: "#eee4ff"; font.pixelSize: 11
        }
    }
}
