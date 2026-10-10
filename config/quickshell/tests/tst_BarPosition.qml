import QtQuick
import QtTest
import ".."
import "../SettingsModel.js" as Model

Item {
    id: scene
    width: 1000; height: 800
    Bar {
        id: bar
        width: vertical ? implicitWidth : scene.width - 20
        height: vertical ? scene.height - 20 : implicitHeight
        settings: ({bar:{position:"top"},items:[]})
        clockText: "Oct 10   08:34 PM   Sat"
        screenHeight: scene.height
        mediaData: ({playing:true, title:"Your favorite track", levels:[0.2,0.7,0.4]})
        trayModel: [{icon:Qt.resolvedUrl("../icons/preview-tray.svg")}, {icon:Qt.resolvedUrl("../icons/preview-tray.svg")}]
        statusData: ({workspaces:[{id:1,name:"1"},{id:2,name:"2"},{id:3,name:"3"}], audio:{icon:"󰕾",text:"64%"}, network:{text:"W"}, bluetooth:{text:"B"}, battery:{present:true,text:"󰁹 80%"}})
        PreviewLayoutEditor {
            id: editor
            anchors.fill: parent
            bar: bar
            onItemDropped: (id, side, beforeId) => bar.settings = Model.reorder(bar.settings, id, side, beforeId)
        }
    }
    MenuPopover {
        id: popover
        anchors.fill: parent
        opened: true
        edge: bar.position
        triggerRect: bar.menuRect("power")
        alignment: "right"
        page: Component { Item { implicitHeight: 160 } }
    }
    SettingsBarEditor {
        id: settingsEditor
        visible: false
        settings: ({position:"top",visible:true,workspaceScope:"all",workspaceOverrides:{},adaptiveColors:true,height:32,spacing:3,marginSide:10,marginTop:5,groupSpacing:3,clockFormat:"hh:mm"})
        onEdited: (key, value) => settings = Object.assign({}, settings, {[key]:value})
    }
    TestCase {
        name: "BarPosition"
        when: windowShown
        function init() {
            bar.settings = {bar:{position:"top"},items:[]};
            popover.visible = false; popover.opened = false;
            popover.triggerRect = Qt.binding(() => bar.menuRect("power"));
        }
        function test_groups_data() {
            return ["top","left","right","bottom"].map(edge => ({tag:edge,edge:edge}));
        }
        function test_groups(data) {
            bar.settings = {bar:{position:data.edge},items:[]};
            waitForRendering(bar);
            let vertical = data.edge === "left" || data.edge === "right";
            compare(bar.vertical,vertical);
            let start = id => vertical ? bar.moduleItems[id].y : bar.moduleItems[id].x;
            compare(start("launcher"),0);
            let power = bar.moduleItems.power;
            fuzzyCompare(vertical ? power.y + power.height : power.x + power.width,vertical ? bar.height : bar.width,0.01);
            let clock = bar.moduleItems.calendar;
            fuzzyCompare(vertical ? clock.y + clock.height/2 : clock.x + clock.width/2,vertical ? bar.height/2 : bar.width/2,0.01);
            verify(start("audio") < start("wifi"));
            verify(start("wifi") < start("power"));
            if (vertical) {
                let first = findChild(bar,"workspace1"), last = findChild(bar,"workspace3");
                verify(last.y > first.y);
                verify(bar.moduleItems.workspaces.height >= last.y + last.height);
                let tray = findChild(bar,"trayIcon");
                verify(bar.moduleItems.tray.height >= tray.height * 2);
                for (let id of Object.keys(bar.moduleItems)) {
                    let item = bar.moduleItems[id];
                    verify(item.x >= 0,id + " left boundary");
                    verify(item.x + item.width <= bar.width + 0.01,id + " right boundary");
                    verify(item.height > 0,id + " height");
                }
                verify(clock.height > 28,"Clock wraps upright in the side bar");
                grabImage(bar).save("/tmp/hyprbar-"+data.edge+".png");
            }
        }
        function test_sharedPillAndHiddenAncestorKeepVerticalGeometry() {
            bar.settings = {bar:{position:"left"},items:[{id:"audio",pillGroup:"status",side:"right"},{id:"wifi",pillGroup:"status",side:"right"}]};
            waitForRendering(bar);
            let bounds = bar.sharedRect(["audio","wifi"]);
            let audio = bar.moduleItems.audio, wifi = bar.moduleItems.wifi;
            compare(bounds.y,audio.y);
            compare(bounds.height,wifi.y+wifi.height-audio.y);
            let before = bar.menuRect("audio");
            bar.visible = false;
            compare(bar.menuRect("audio"),before);
            bar.visible = true;
        }
        function test_verticalPreviewDrop() {
            bar.settings = {bar:{position:"right"},items:Object.keys(bar.moduleItems).map((id,i) => ({id:id,side:bar.defaultSides[id] || "right",order:i}))};
            waitForRendering(bar);
            let wifi = bar.moduleItems.wifi;
            mousePress(editor,wifi.x+wifi.width/2,wifi.y+wifi.height/2);
            mouseMove(editor,bar.width/2,1,20);
            mouseRelease(editor,bar.width/2,1);
            compare(Model.item(bar.settings,"wifi").side,"left");
            verify(bar.moduleItems.wifi.y < bar.moduleItems.launcher.y);
            compare(editor.dropAt(bar.width/2,bar.height-1).side,"right");
        }
        function test_menuGeometry_data() { return test_groups_data(); }
        function test_menuGeometry(data) {
            popover.visible = true; popover.opened = true;
            bar.settings = {bar:{position:data.edge},items:[]};
            popover.triggerRect = data.edge === "bottom" ? Qt.rect(800,760,30,28)
                : data.edge === "left" ? Qt.rect(5,740,60,28)
                : data.edge === "right" ? Qt.rect(935,740,60,28) : Qt.rect(800,5,30,28);
            waitForRendering(popover);
            verify(popover.bodyX >= 12 && popover.bodyRight <= scene.width - 12);
            verify(popover.bodyY >= 12 && popover.bodyBottom <= scene.height - 12);
            let trigger = popover.triggerRect;
            let p = data.edge === "top" ? Qt.point(trigger.x+15,(trigger.y+trigger.height+popover.bodyY)/2)
                : data.edge === "bottom" ? Qt.point(trigger.x+15,(trigger.y+popover.bodyBottom)/2)
                : data.edge === "left" ? Qt.point((trigger.x+trigger.width+popover.bodyX)/2,trigger.y+14)
                : Qt.point((trigger.x+popover.bodyRight)/2,trigger.y+14);
            verify(popover.containsPointer(p),"Pointer can cross the connector from " + data.edge);
            if (data.edge === "top") verify(popover.bodyY > trigger.y + trigger.height);
            if (data.edge === "bottom") verify(popover.bodyBottom < trigger.y);
            if (data.edge === "left") verify(popover.bodyX > trigger.x + trigger.width);
            if (data.edge === "right") verify(popover.bodyRight < trigger.x);
            grabImage(scene).save("/tmp/hyprbar-menu-"+data.edge+".png");
        }
        function test_positionControl() {
            let control = findChild(settingsEditor,"barPositionControl");
            for (let i = 0; i < 4; i++) {
                control.activated(i);
                compare(settingsEditor.settings.position,["top","left","right","bottom"][i]);
                compare(control.currentIndex,i);
            }
        }
    }
}
