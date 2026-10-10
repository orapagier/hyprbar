import QtQuick
import QtQuick.Controls.Basic
import QtTest
import ".."
import "../SettingsModel.js" as Model

Item {
    id: scene
    width: 840; height: 1600
    readonly property var barDefaults: ({height: 32, spacing: 3, marginTop: 5, marginSide: 10, adaptiveColors: true, background: "inherit", iconSize: 0, clockFormat: "hh:mm", visible: true, workspaceScope: "all", workspaceList: []})
    readonly property var itemDefaults: ({id: "audio", enabled: true, side: "right", adaptiveColors: "inherit", background: "inherit", opacity: 1, backgroundOpacity: -1, radius: -1, fontSize: 0, iconSize: 0})
    SettingsBarEditor {
        id: barPage
        width: 820
        settings: Model.copy(scene.barDefaults)
        onEdited: (key, value) => settings = Object.assign({}, settings, {[key]: value})
    }
    SettingsItemEditor {
        id: itemPage
        width: 820
        visible: false
        settings: Model.copy(scene.itemDefaults)
        barSettings: barPage.settings
        onEdited: (key, value) => settings = Object.assign({}, settings, {[key]: value})
    }
    TestCase {
        name: "SettingsEditors"
        when: windowShown
        function init() {
            barPage.settings = Model.copy(scene.barDefaults);
            itemPage.settings = Model.copy(scene.itemDefaults);
            barPage.visible = true; itemPage.visible = false;
        }
        function control(page, key) { return findChild(page, key + "Control"); }
        function track(page, key) { return findChild(control(page, key), "effectSlider"); }
        function test_barSliderKeyboardAndResetPreserveOtherValues() {
            let slider = track(barPage, "height");
            slider.forceActiveFocus(); keyClick(Qt.Key_Right);
            compare(barPage.settings.height, 33);
            compare(barPage.settings.marginSide, 10);
            mouseClick(findChild(control(barPage, "height"), "sliderReset"));
            compare(barPage.settings.height, 32);
        }
        function test_workspaceScopeShowsListAndParsesNumbers() {
            let scope = control(barPage, "barWorkspaceScope");
            let list = findChild(barPage, "barWorkspaceListControl");
            verify(scope !== null);
            verify(list !== null);
            verify(!list.visible);
            scope.activated(1);
            compare(barPage.settings.workspaceScope, "selected");
            compare(JSON.stringify(barPage.settings.workspaceList), "[1]");
            wait(30);
            verify(list.visible);
            list.text = "2, 4, 4";
            list.editingFinished();
            compare(JSON.stringify(barPage.settings.workspaceList), "[2,4]");
            list.text = "x";
            list.editingFinished();
            compare(JSON.stringify(barPage.settings.workspaceList), "[2,4]");
            scope.activated(0);
            compare(barPage.settings.workspaceScope, "all");
            wait(30);
            verify(!list.visible);
        }
        function test_itemPercentagesAndResetUseOriginalSentinels() {
            barPage.visible = false; itemPage.visible = true;
            itemPage.settings = Object.assign({}, itemPage.settings, {opacity: 0.6, backgroundOpacity: 0.4, radius: 8, fontSize: 14});
            compare(track(itemPage, "opacity").value, 60);
            compare(track(itemPage, "backgroundOpacity").value, 40);
            track(itemPage, "opacity").forceActiveFocus(); keyClick(Qt.Key_Right);
            compare(itemPage.settings.opacity, 0.61);
            for (let key of ["opacity", "backgroundOpacity", "radius", "fontSize"])
                mouseClick(findChild(control(itemPage, key), "sliderReset"));
            compare(itemPage.settings.opacity, 1);
            compare(itemPage.settings.backgroundOpacity, -1);
            compare(itemPage.settings.radius, -1);
            compare(itemPage.settings.fontSize, 0);
        }
        function test_editorsFitWideAndNarrowLayouts() {
            for (let page of [barPage, itemPage]) {
                barPage.visible = page === barPage; itemPage.visible = page === itemPage;
                for (let width of [820, 480, 360]) {
                    page.width = width;
                    wait(30);
                    let keys = page === barPage ? ["height", "spacing", "marginTop", "marginSide"] : ["spacingLeft", "spacingRight", "text", "icon", "textColor", "iconColor", "backgroundColor", "outlineColor", "fontSize", "opacity", "radius"];
                    for (let key of keys) {
                        let field = control(page, key);
                        verify(field !== null, key);
                        let position = field.mapToItem(page, 0, 0);
                        verify(position.x >= 0, key + " left edge");
                        verify(position.x + field.width <= page.width + 1, key + " right edge");
                    }
                }
            }
        }
    }
}
