import QtQuick
import QtTest
import ".."
import "../SettingsModel.js" as Model

Item {
    id: root
    width: 1000; height: 180
    property string selectedId: ""
    Bar {
        id: bar
        width: parent.width
        clockText: "12:34"
        mediaData: ({playing:true, title:"Music"})
        statusData: ({workspaces:[{id:1,name:"1"}], battery:{present:true,text:"80%"}, network:{text:"W"}, bluetooth:{text:"B"}, audio:{text:"64%"}})
        trayModel: [{icon:Qt.resolvedUrl("../icons/preview-tray.svg")}]
        PreviewLayoutEditor {
            id: editor
            anchors.fill: parent
            bar: bar
            onItemDropped: (id, side, beforeId) => bar.settings = Model.reorder(bar.settings, id, side, beforeId)
            onItemSelected: id => root.selectedId = id
        }
    }
    SettingsBackgroundControl {
        id: backgroundControl
        y: 70
        onEdited: mode => backgroundControl.mode = mode
    }
    TestCase {
        name: "PreviewLayoutEditor"
        when: windowShown
        function init() {
            let ids = Object.keys(bar.moduleItems);
            bar.settings = {bar:{height:32,spacing:5},items:ids.map((id,i) => ({id:id,enabled:true,side:id === "calendar" ? "center" : i < 4 ? "left" : "right",order:i, spacingLeft:0,spacingRight:0}))};
            root.selectedId = "";
            backgroundControl.mode = "inherit";
            backgroundControl.inheritedVisible = true;
        }
        function drag(id, x, y) {
            let item = bar.moduleItems[id];
            mousePress(editor, item.x+item.width/2, item.y+item.height/2);
            mouseMove(editor, x, y, 20);
            verify(editor.dragging);
            mouseRelease(editor, x, y);
            compare(editor.dragging,false);
        }
        function test_clickSelectsWithoutReordering() {
            let wifi = bar.moduleItems.wifi;
            let before = JSON.stringify(bar.settings);
            mouseClick(editor,wifi.x+wifi.width/2,wifi.y+wifi.height/2);
            compare(root.selectedId,"wifi");
            compare(JSON.stringify(bar.settings),before);
        }
        function test_dragReordersWithinRightGroup() {
            let audio = bar.moduleItems.audio;
            drag("wifi",audio.x+1,16);
            verify(Model.item(bar.settings,"wifi").order < Model.item(bar.settings,"audio").order);
            verify(bar.moduleItems.wifi.x < audio.x);
            compare(bar.menuRect("wifi").x,bar.moduleItems.wifi.x);
        }
        function test_dragAcrossGroupsAndIntoEmptyGroup() {
            drag("wifi",1,16);
            compare(Model.item(bar.settings,"wifi").side,"left");
            let calendar = bar.moduleItems.calendar;
            drag("wifi",calendar.x+1,16);
            compare(Model.item(bar.settings,"wifi").side,"center");
            verify(bar.moduleItems.wifi.x < calendar.x);
            drag("calendar",bar.width-1,16);
            drag("wifi",bar.width-1,16);
            drag("bluetooth",bar.width/2,16);
            compare(Model.item(bar.settings,"bluetooth").side,"center");
            fuzzyCompare(bar.moduleItems.bluetooth.x+bar.moduleItems.bluetooth.width/2,bar.width/2,0.01);
        }
        function test_dragWorkspacesMediaAndTray_data() {
            return ["workspaces","media","tray"].map(id => ({tag:id,id:id}));
        }
        function test_dragWorkspacesMediaAndTray(data) {
            drag(data.id,bar.width-1,16);
            compare(Model.item(bar.settings,data.id).side,"right");
            let group = bar.settings.items.filter(i=>i.side === "right");
            compare(Model.item(bar.settings,data.id).order,group.length-1);
        }
        function test_releaseOutsideCancels() {
            let before = JSON.stringify(bar.settings);
            drag("wifi",100,55);
            compare(JSON.stringify(bar.settings),before);
        }
        function test_switchRemovesPillWithOneClickFromInherit() {
            let toggle = findChild(backgroundControl,"backgroundPillSwitch");
            compare(toggle.checked,true);
            mouseClick(toggle,10,toggle.height/2);
            compare(backgroundControl.mode,"off");
            compare(toggle.checked,false);
            mouseClick(toggle,10,toggle.height/2);
            compare(backgroundControl.mode,"on");
            backgroundControl.mode = "inherit";
            backgroundControl.inheritedVisible = false;
            compare(toggle.checked,false);
            mouseClick(toggle,10,toggle.height/2);
            compare(backgroundControl.mode,"on");
        }
        function test_resetAfterDragRestoresSavedNeighbours() {
            let saved = Model.copy(bar.settings);
            let dragged = Model.reorder(saved,"wifi","right","tray");
            Model.item(dragged,"wifi").background = "off";
            bar.settings = Model.restoreItem(dragged,saved,"wifi");
            verify(bar.moduleItems.audio.x < bar.moduleItems.wifi.x);
            verify(bar.moduleItems.wifi.x < bar.moduleItems.bluetooth.x);
            compare(Model.item(bar.settings,"wifi").background,undefined);
            dragged = Model.reorder(saved,"wifi","left","launcher");
            bar.settings = Model.restoreItem(dragged,saved,"wifi");
            compare(Model.item(bar.settings,"wifi").side,"right");
            verify(bar.moduleItems.audio.x < bar.moduleItems.wifi.x);
            verify(bar.moduleItems.wifi.x < bar.moduleItems.bluetooth.x);
        }
        function test_reorderKeepsHiddenItemsAndStyle() {
            let next = Model.copy(bar.settings);
            Model.item(next,"audio").enabled = false;
            Model.item(next,"wifi").spacingRight = 17;
            Model.item(next,"wifi").background = "off";
            let original = JSON.stringify(next);
            let result = Model.reorder(next,"wifi","left","launcher");
            compare(JSON.stringify(next),original);
            compare(Model.item(result,"audio").enabled,false);
            compare(Model.item(result,"wifi").spacingRight,17);
            compare(Model.item(result,"wifi").background,"off");
            compare(Model.item(result,"wifi").order,0);
        }
    }
}
