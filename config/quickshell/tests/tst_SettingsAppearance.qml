import QtQuick
import QtQuick.Controls.Basic
import QtTest
import ".."

Item {
    width: 820; height: 1500
    SettingsAppearance {
        id: page
        width: parent.width
        settings: ({})
        onEdited: (key, value) => {
            let next = Object.assign({}, settings);
            if (value === "") delete next[key];
            else next[key] = value;
            settings = next;
        }
    }
    TestCase {
        name: "SettingsAppearance"
        when: windowShown
        function cleanup() { page.settings = {}; page.width = 820; }
        function slider(key) { return findChild(findChild(page, key + "Control"), "effectSlider"); }
        function test_transparencyDragChangesOpacityAndResetRestoresConfig() {
            let control = findChild(page, "activeOpacityControl");
            let track = slider("activeOpacity");
            verify(control.inherited);
            compare(findChild(control, "sliderValue").text, "Use config");
            mousePress(track, track.width * 0.25, track.height / 2);
            mouseMove(track, track.width * 0.6, track.height / 2);
            mouseRelease(track, track.width * 0.6, track.height / 2);
            verify(page.settings.activeOpacity < 0.5 && page.settings.activeOpacity > 0.3);
            verify(!control.inherited);
            compare(page.settings.inactiveOpacity, undefined);
            mouseClick(findChild(control, "sliderReset"));
            compare(page.settings.activeOpacity, undefined);
            verify(control.inherited);
        }
        function test_keyboardAndStoredValues() {
            page.settings = {activeOpacity: 0.8, blurSize: 8, blurPasses: 2, blurVibrancy: 0.2};
            fuzzyCompare(slider("activeOpacity").value, 20, 0.001);
            let strength = slider("blurSize");
            strength.forceActiveFocus();
            keyClick(Qt.Key_Right);
            compare(page.settings.blurSize, 9);
            let vibrancy = slider("blurVibrancy");
            vibrancy.forceActiveFocus();
            keyClick(Qt.Key_Right);
            compare(page.settings.blurVibrancy, 0.21);
            compare(page.settings.blurPasses, 2);
        }
        function test_disablingBlurRetainsStrengthAndDisablesSliders() {
            page.settings = {blur: false, blurSize: 12, blurVibrancy: 0.4};
            verify(!slider("blurSize").enabled);
            verify(!slider("blurVibrancy").enabled);
            page.settings = Object.assign({}, page.settings, {blur: true});
            verify(slider("blurSize").enabled);
            compare(slider("blurSize").value, 12);
            compare(slider("blurVibrancy").value, 40);
        }
        function test_responsiveLayoutHasNoHorizontalOverflow() {
            for (let width of [820, 480]) {
                page.width = width;
                wait(30);
                for (let key of ["activeOpacity", "inactiveOpacity", "blurSize", "blurVibrancy", "rounding", "gapsOut"]) {
                    let control = findChild(page, key + "Control");
                    let position = control.mapToItem(page, 0, 0);
                    verify(position.x >= 0);
                    verify(position.x + control.width <= page.width + 1);
                }
            }
        }
    }
}
