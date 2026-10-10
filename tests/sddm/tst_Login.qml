import QtQuick
import QtTest
import "../../config/sddm/hyprshell-glass" as Glass

Item {
    id: harness
    width: 1920
    height: 1080
    QtObject {
        id: sddm
        property bool canReboot: true
        property bool canPowerOff: true
        property var calls: []
        signal loginFailed()
        signal loginSucceeded()
        function login(user, password, index) { calls = calls.concat([{user: user, password: password, index: index}]); }
        function reboot() { }
        function powerOff() { }
    }
    ListModel {
        id: userModel
        property int lastIndex: 0
        property string lastUser: "demo"
        ListElement { name: "demo" }
        ListElement { name: "other" }
    }
    ListModel {
        id: sessionModel
        property int lastIndex: 1
        ListElement { name: "Hyprland" }
        ListElement { name: "Hyprland (uwsm-managed)" }
    }
    QtObject {
        id: keyboard
        property bool capsLock: false
        property int currentLayout: 0
        property var layouts: [{shortName: "us", longName: "English (US)"}, {shortName: "gb", longName: "English (UK)"}]
    }
    Glass.Main { id: theme; anchors.fill: parent }

    TestCase {
        name: "GlassLogin"
        when: windowShown
        property var username
        property var password
        property var session

        function initTestCase() {
            username = findChild(theme, "username");
            password = findChild(theme, "password");
            session = findChild(theme, "session");
            verify(username && password && session);
        }
        function init() {
            sddm.calls = [];
            theme.busy = false;
            theme.statusMessage = "";
            theme.showPassword = false;
            username.editText = "demo";
            password.text = "";
            session.currentIndex = 1;
            keyboard.currentLayout = 0;
        }
        function test_login_uses_selected_session_and_blocks_double_submission() {
            username.editText = " unlisted-user ";
            password.text = "test password";
            session.currentIndex = 0;
            theme.submitLogin();
            compare(sddm.calls.length, 1);
            compare(sddm.calls[0].user, "unlisted-user");
            compare(sddm.calls[0].password, "test password");
            compare(sddm.calls[0].index, 0);
            theme.submitLogin();
            compare(sddm.calls.length, 1);
        }
        function test_enter_submits_password() {
            password.text = "test password";
            password.forceActiveFocus();
            keyClick(Qt.Key_Return);
            compare(sddm.calls.length, 1);
        }
        function test_failure_clears_and_hides_password_and_allows_retry() {
            password.text = "test password";
            theme.showPassword = true;
            theme.submitLogin();
            sddm.loginFailed();
            compare(password.text, "");
            compare(theme.showPassword, false);
            compare(theme.busy, false);
            verify(password.activeFocus);
            verify(theme.statusMessage.length > 0);
            password.text = "new password";
            theme.submitLogin();
            compare(sddm.calls.length, 2);
        }
        function test_success_clears_password() {
            password.text = "test password";
            theme.submitLogin();
            sddm.loginSucceeded();
            compare(password.text, "");
            compare(theme.busy, true);
        }
        function test_missing_user_or_session_blocks_login() {
            username.editText = " ";
            theme.submitLogin();
            compare(sddm.calls.length, 0);
            username.editText = "demo";
            session.currentIndex = -1;
            theme.submitLogin();
            compare(sddm.calls.length, 0);
        }
        function test_layout_selection_reaches_keyboard() {
            var layout = findChild(theme, "layout");
            layout.currentIndex = 1;
            layout.activated(1);
            compare(keyboard.currentLayout, 1);
        }
        function test_preview() {
            wait(100);
            var capture = grabImage(theme);
            compare(capture.width, 1920);
            compare(capture.height, 1080);
            capture.save("/tmp/hyprshell-login-preview.png");
        }
    }
}
