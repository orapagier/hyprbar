import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property string label
    property string description: ""
    property var settingValue: undefined
    property real defaultValue: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property string suffix: ""
    property bool inverted: false
    property string inheritedText: "Use config"
    property string resetDescription: "Use your existing configuration"
    readonly property bool inherited: settingValue === undefined
    readonly property real displayValue: inherited ? defaultValue : inverted ? (1 - settingValue) * 100 : settingValue
    signal edited(var value)
    function commitDisplayValue(value) {
        let bounded = Math.max(from, Math.min(to, value));
        let rounded = Math.max(from, Math.min(to, Math.round(bounded / stepSize) * stepSize));
        edited(inverted ? Number((1 - rounded / 100).toFixed(6)) : Number(rounded.toFixed(6)));
    }
    function adjust(direction) {
        commitDisplayValue(slider.value + direction * stepSize);
    }
    spacing: 8
    opacity: enabled ? 1 : 0.45
    RowLayout {
        Layout.fillWidth: true
        Label {
            text: root.label
            color: "#e2e6f3"
            font.pixelSize: 12
            Layout.fillWidth: true
        }
        Label {
            objectName: "sliderValue"
            text: root.inherited ? root.inheritedText : Number(root.displayValue.toFixed(2)) + root.suffix
            color: root.inherited ? "#8996b1" : "#c9bdff"
            font.pixelSize: 12
        }
        ToolButton {
            objectName: "sliderReset"
            text: "↺"
            enabled: !root.inherited
            implicitWidth: 28
            implicitHeight: 28
            hoverEnabled: true
            Accessible.name: "Reset " + root.label
            onClicked: root.edited("")
            contentItem: Text { text: parent.text; color: root.inherited ? "#59647e" : "#b9c4dd"; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { radius: 7; color: parent.hovered || parent.activeFocus ? "#35405a" : "transparent"; border.color: parent.activeFocus ? "#b4a2ff" : "transparent" }
            ToolTip.visible: hovered
            ToolTip.text: root.resetDescription
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        SettingsButton {
            objectName: "sliderDecrease"
            text: "−"
            implicitWidth: 30; implicitHeight: 30
            Layout.preferredWidth: 30
            leftPadding: 0; rightPadding: 0
            enabled: slider.value > root.from
            Accessible.name: "Decrease " + root.label
            onClicked: root.adjust(-1)
        }
        Slider {
            id: slider
            objectName: "effectSlider"
            Layout.fillWidth: true
            implicitHeight: 28
            from: root.from
            to: root.to
            stepSize: root.stepSize
            value: root.displayValue
            live: true
            hoverEnabled: true
            Accessible.name: root.label
            onMoved: root.commitDisplayValue(value)
            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + (slider.availableHeight - height) / 2
                width: slider.availableWidth
                height: 5
                radius: 3
                color: "#35405a"
                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: 3
                    color: root.inherited ? "#63718e" : "#aa96ed"
                }
            }
            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + (slider.availableHeight - height) / 2
                implicitWidth: 18
                implicitHeight: 18
                radius: 9
                color: slider.pressed ? "#ffffff" : "#e5ddff"
                border.width: slider.activeFocus || slider.hovered ? 3 : 2
                border.color: slider.activeFocus || slider.hovered ? "#ab94f3" : "#756796"
            }
        }
        SettingsButton {
            objectName: "sliderIncrease"
            text: "+"
            implicitWidth: 30; implicitHeight: 30
            Layout.preferredWidth: 30
            leftPadding: 0; rightPadding: 0
            enabled: slider.value < root.to
            Accessible.name: "Increase " + root.label
            onClicked: root.adjust(1)
        }
    }
    Label {
        visible: root.description !== ""
        Layout.fillWidth: true
        text: root.description
        color: "#8f9bb5"
        font.pixelSize: 11
        wrapMode: Text.WordWrap
    }
}
