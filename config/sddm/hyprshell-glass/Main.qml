import QtQuick
import QtQuick.Controls.Basic

Item {
    id: root
    width: 1920
    height: 1080
    property bool busy: false
    property string statusMessage: ""
    property bool showPassword: false
    readonly property real sceneScale: Math.min(width / 1920, height / 1080, 1.5)

    function submitLogin() {
        if (busy || username.editText.trim() === "" || session.currentIndex < 0)
            return;
        busy = true;
        statusMessage = qsTr("Signing in…");
        sddm.login(username.editText.trim(), password.text, session.currentIndex);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false;
            password.clear();
            root.showPassword = false;
            root.statusMessage = qsTr("Sign-in failed. Check your username and password.");
            password.forceActiveFocus();
        }
        function onLoginSucceeded() {
            password.clear();
            root.showPassword = false;
            root.statusMessage = qsTr("Welcome back.");
        }
    }

    Rectangle { anchors.fill: parent; color: "#0b101a" }
    Image { anchors.fill: parent; source: "background.png"; fillMode: Image.Stretch }

    Item {
        id: scene
        width: 900
        height: 760
        anchors.centerIn: parent
        scale: root.sceneScale

        Image { anchors.fill: parent; source: "card.png" }

        Item {
            id: title
            x: 190
            y: 108
            width: 520
            height: 140
            Image {
                id: glow
                anchors.fill: parent
                source: "title-glow.png"
                opacity: 0.55
                SequentialAnimation {
                    running: true
                    loops: Animation.Infinite
                    NumberAnimation { target: glow; property: "opacity"; to: 0.9; duration: 1700; easing.type: Easing.InOutSine }
                    NumberAnimation { target: glow; property: "opacity"; to: 0.3; duration: 1700; easing.type: Easing.InOutSine }
                }
            }
            Image { anchors.fill: parent; source: "title.png" }
            SequentialAnimation {
                running: true
                loops: Animation.Infinite
                NumberAnimation { target: title; property: "y"; to: 110; duration: 2200; easing.type: Easing.InOutSine }
                NumberAnimation { target: title; property: "y"; to: 107; duration: 2200; easing.type: Easing.InOutSine }
            }
        }

        Column {
            x: 245
            y: 305
            width: 410
            spacing: 12
            enabled: !root.busy

            Text { text: qsTr("USER"); color: "#adb8d0"; font.family: "Noto Sans"; font.pixelSize: 11; font.letterSpacing: 2 }
            GlassCombo {
                id: username
                objectName: "username"
                width: parent.width
                model: userModel
                textRole: "name"
                editable: true
                currentIndex: userModel.lastIndex
                onAccepted: password.forceActiveFocus()
                Accessible.name: qsTr("Username")
                KeyNavigation.tab: password
            }
            Text { text: qsTr("PASSWORD"); color: "#adb8d0"; font.family: "Noto Sans"; font.pixelSize: 11; font.letterSpacing: 2 }
            Item {
                width: parent.width
                height: 44
                TextField {
                    id: password
                    objectName: "password"
                    anchors.fill: parent
                    rightPadding: 85
                    leftPadding: 14
                    color: "#edf0ff"
                    placeholderText: qsTr("Enter your password")
                    placeholderTextColor: "#8e9bb5"
                    echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    selectByMouse: true
                    font.family: "Noto Sans"
                    font.pixelSize: 15
                    Accessible.name: qsTr("Password")
                    onAccepted: root.submitLogin()
                    KeyNavigation.tab: reveal
                    background: Rectangle {
                        radius: 12
                        color: "#90101b2a"
                        border.color: password.activeFocus ? "#b4befe" : "#566581"
                        border.width: password.activeFocus ? 2 : 1
                    }
                }
                GlassButton {
                    id: reveal
                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    height: 34
                    width: 70
                    padding: 8
                    font.pixelSize: 13
                    text: root.showPassword ? qsTr("Hide") : qsTr("Show")
                    onClicked: root.showPassword = !root.showPassword
                    KeyNavigation.tab: session
                }
            }
            Text { text: qsTr("SESSION"); color: "#adb8d0"; font.family: "Noto Sans"; font.pixelSize: 11; font.letterSpacing: 2 }
            GlassCombo {
                id: session
                objectName: "session"
                width: parent.width
                model: sessionModel
                textRole: "name"
                currentIndex: sessionModel.lastIndex
                Accessible.name: qsTr("Desktop session")
                KeyNavigation.tab: login
            }
            GlassButton {
                id: login
                objectName: "login"
                width: parent.width
                primary: true
                enabled: username.editText.trim() !== "" && session.currentIndex >= 0
                text: qsTr("Sign in")
                onClicked: root.submitLogin()
                KeyNavigation.tab: layout
            }
        }

        Text {
            x: 155
            y: 609
            width: 590
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.statusMessage !== "" ? root.statusMessage : keyboard.capsLock ? qsTr("Caps Lock is on") : ""
            color: root.busy ? "#b8dfe9" : "#eac2d2"
            font.family: "Noto Sans"
            font.pixelSize: 13
            Accessible.role: Accessible.StaticText
        }

        Row {
            x: 245
            y: 654
            width: 410
            spacing: 10
            enabled: !root.busy
            GlassCombo {
                id: layout
                objectName: "layout"
                width: 170
                model: keyboard.layouts
                textRole: "shortName"
                currentIndex: keyboard.currentLayout
                onActivated: keyboard.currentLayout = currentIndex
                Accessible.name: qsTr("Keyboard layout")
                KeyNavigation.tab: restart
            }
            GlassButton {
                id: restart
                width: 110
                text: qsTr("Restart")
                enabled: sddm.canReboot
                onClicked: sddm.reboot()
                KeyNavigation.tab: poweroff
            }
            GlassButton {
                id: poweroff
                width: 110
                text: qsTr("Power off")
                enabled: sddm.canPowerOff
                onClicked: sddm.powerOff()
                KeyNavigation.tab: username
            }
        }
    }

    Image {
        width: 400 * root.sceneScale
        height: 24 * root.sceneScale
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - 74 * root.sceneScale
        source: "footer.png"
    }

    Component.onCompleted: {
        username.editText = userModel.lastUser || username.currentText;
        if (username.editText === "") username.forceActiveFocus();
        else password.forceActiveFocus();
    }
}
