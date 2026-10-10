import QtQuick
import QtTest
import ".."
import "../SettingsModel.js" as Model

Item {
    width: 1366; height: 120
    Bar {
        id: bar
        width: parent.width
        clockText: "Oct 10  12:34 PM"
        statusData: ({workspaces: [], audio: {icon:"♪",text:"64%"}, network: {}, bluetooth: {}, battery: {present:true,text:"󰁹 86%"}})
        mediaData: ({playing:true,title:"Track",levels:[1,0.5]})
        trayModel: [{icon: Qt.resolvedUrl("../icons/preview-tray.svg")}]
    }
    TestCase {
        name: "IconSizes"
        when: windowShown
        function cleanup() { bar.settings = {}; }
        function test_globalSizingIncludesGlassGlyphsTrayAndSpectrum() {
            bar.settings = {bar:{height:32,iconSize:24}};
            compare(findChild(bar.moduleItems.audio,"pillIcon").font.pixelSize,24);
            compare(bar.moduleItems.audio.content.font.pixelSize,18);
            compare(bar.moduleItems.wifi.content.font.pixelSize,24);
            compare(findChild(bar,"archGlassLogo").iconSize,24);
            compare(findChild(bar,"settingsGlassCog").iconSize,24);
            compare(findChild(bar,"trayIcon").width,24);
            compare(findChild(bar.moduleItems.battery,"pillIcon").font.pixelSize,24);
            compare(bar.moduleItems.battery.content.font.pixelSize,18);
            compare(bar.moduleItems.battery.shownText,"86%");
            compare(bar.moduleItems.media.item.spectrumWidth,87);
            compare(bar.moduleItems.media.item.content.font.pixelSize,17);
            compare(bar.moduleItems.calendar.content.font.pixelSize,18);
        }
        function test_textOverridesAndTextOnlyItemsFitAtLargeSizes() {
            bar.statusData = {workspaces:[{id:1,name:"1",active:true}], audio:{text:"64%"}, network:{}, bluetooth:{}, battery:{present:true,text:"󰁹 86%"}};
            bar.settings = {bar:{iconSize:48},items:[{id:"audio",fontSize:14},{id:"calendar",fontSize:48},{id:"media",fontSize:48,hideIcon:true}]};
            compare(bar.moduleItems.audio.content.font.pixelSize,14);
            compare(bar.moduleItems.battery.content.font.pixelSize,36);
            compare(bar.moduleItems.calendar.content.font.pixelSize,48);
            let workspace = findChild(bar,"workspace1");
            compare(workspace.content.font.pixelSize,36);
            for (let item of [workspace,bar.moduleItems.calendar,bar.moduleItems.media.item]) {
                tryVerify(() => item.content.implicitHeight <= item.height, 1000, item.objectName + ": " + item.content.implicitHeight + " / " + item.height + " implicit " + item.implicitHeight + " text " + item.shownText);
                verify(item.y >= 0);
            }
            compare(findChild(bar,"notificationBadge").font.pixelSize,26);
            bar.settings = {bar:{iconSize:24},items:[{id:"battery",iconSize:32}]};
            compare(bar.moduleItems.battery.content.font.pixelSize,24);
            bar.settings = {bar:{iconSize:0}};
            compare(workspace.content.font.pixelSize,12);
            compare(bar.moduleItems.calendar.content.font.pixelSize,12);
            bar.statusData = {workspaces:[],audio:{icon:"♪",text:"64%"},network:{},bluetooth:{},battery:{present:true,text:"󰁹 86%"}};
        }
        function test_individualSizeWinsAndResetFollowsGlobal() {
            bar.settings = {bar:{height:32,iconSize:32},items:[{id:"wifi",iconSize:12},{id:"launcher",iconSize:40},{id:"tray",iconSize:20}]};
            compare(bar.moduleItems.wifi.content.font.pixelSize,12);
            compare(findChild(bar,"archGlassLogo").iconSize,40);
            compare(findChild(bar,"trayIcon").width,20);
            compare(findChild(bar.moduleItems.audio,"pillIcon").font.pixelSize,32);
            bar.settings = {bar:{height:32,iconSize:32},items:[{id:"wifi",iconSize:0}]};
            compare(bar.moduleItems.wifi.content.font.pixelSize,32);
            bar.settings = {bar:{height:32,iconSize:0}};
            compare(bar.moduleItems.wifi.content.font.pixelSize,15);
            compare(findChild(bar,"archGlassLogo").iconSize,22);
            compare(findChild(bar.moduleItems.audio,"pillIcon").font.pixelSize,16);
            compare(findChild(bar,"trayIcon").width,16);
        }
        function test_largerIconsGrowHitAreasAndKeepMenuAnchors() {
            bar.settings = {bar:{height:32,iconSize:48}};
            for(let id of ["launcher","settings","audio","wifi","bluetooth","notifications","battery","power"]) {
                let item = bar.moduleItems[id];
                verify(item.height >= 48);
                verify(item.y >= 0);
                verify(item.y + item.height <= bar.height);
                compare(bar.menuRect(id).x,item.x);
                compare(bar.menuRect(id).height,item.height);
            }
            verify(bar.height >= 52);
        }
        function test_retiredMotionSettingsDoNotSurviveMerge() {
            let defaults={version:1,bar:{iconSize:0},items:[{id:"audio",iconSize:0}],hyprland:{}};
            let merged=Model.merge(defaults,{version:1,bar:{genieEffect:true,genieOpenDuration:300},items:[{id:"audio",genieEffect:"on",genieCloseDuration:400}]});
            compare(merged.bar.genieEffect,undefined);
            compare(merged.items[0].genieEffect,undefined);
            compare(merged.items[0].genieCloseDuration,undefined);
        }
    }
}
