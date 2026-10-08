import QtQuick
import QtQuick.Controls
import QtTest
import ".."

Item {
    id: root
    width: 1366; height: 500
    MenuController { id: state }
    Bar {
        id: bar
        z: 1
        width: parent.width
        clockText: "Oct 08   12:34 PM   Thu"
        statusData: ({workspaces: [], audio: {}, network: {}, bluetooth: {}, battery: {present: true, text: "󰂁 76%"}})
        activeMenu: state.section
        onMenuHovered: name => state.hover(name)
        onMenuLeft: name => state.leave(name)
        onAction: (name, argument) => state.activate(name)
    }
    MenuPopover {
        id: popover
        anchors.fill: parent
        triggerRect: bar.menuRect(state.displayedSection)
        accent: bar.menuAccent(state.displayedSection)
        title: state.displayedSection
        symbol: "󰕾"
        opened: state.section.length > 0
        centered: state.displayedSection === "calendar"
        leftAligned: state.displayedSection === "launcher"
        onHoverChanged: inside => state.retain(inside)
        page: Component {
            Item {
                implicitHeight: 140
                Button { objectName: "menuAction"; text: "Test action"; onClicked: root.actionCount++ }
            }
        }
    }
    property int actionCount: 0
    TestCase {
        name: "HoverMenus"
        when: windowShown
        function init() { mouseMove(root, 5, 480); state.close(); }
        function cleanup() { state.close(); root.width = 1366; }
        function hover(name) {
            let trigger = findChild(bar, name === "notifications" ? "notificationBell" : name + "Trigger");
            verify(trigger !== null);
            mouseMove(trigger, trigger.width / 2, trigger.height / 2);
            tryCompare(state, "section", name);
        }
        function test_hoverOpensEveryMenu_data() {
            return ["launcher", "calendar", "notifications", "audio", "wifi", "bluetooth", "battery", "power"].map(name => ({tag: name, menu: name}));
        }
        function test_hoverOpensEveryMenu(data) {
            hover(data.menu);
            verify(!state.pinned);
            verify(popover.bodyX >= 12);
            if (data.menu === "calendar")
                compare(popover.bodyX + popover.bodyWidth / 2, root.width / 2);
            else if (data.menu === "launcher")
                compare(popover.bodyX, 12);
            else
                compare(popover.bodyRight, root.width - 12);
            let trigger = bar.menuRect(data.menu);
            compare(popover.neckY, trigger.y + trigger.height - 1);
            compare(popover.tipX, trigger.x + trigger.width / 2);
            if (data.menu === "launcher") {
                verify(findChild(popover, "menuFunnel").visible);
                compare(popover.bodyY, popover.neckY + 34);
            }
        }
        function test_pointerCanCrossBridgeAndUseMenu() {
            hover("audio");
            mouseMove(root, popover.shoulder, popover.bodyY - 8);
            wait(380);
            compare(state.section, "audio");
            let button = findChild(popover, "menuAction");
            verify(button !== null);
            mouseMove(button, button.width / 2, button.height / 2);
            wait(380);
            compare(state.section, "audio");
            let before = root.actionCount;
            mouseClick(button, button.width / 2, button.height / 2);
            compare(root.actionCount, before + 1);
            mouseMove(root, 5, 480);
            tryCompare(state, "section", "");
        }
        function test_launcherCanBeEnteredAndUsed() {
            hover("launcher");
            mouseMove(root, popover.shoulder, popover.bodyY - 8);
            wait(380);
            compare(state.section, "launcher");
            let button = findChild(popover, "menuAction");
            mouseMove(button, button.width / 2, button.height / 2);
            wait(380);
            compare(state.section, "launcher");
            let before = root.actionCount;
            mouseClick(button, button.width / 2, button.height / 2);
            compare(root.actionCount, before + 1);
            wait(250);
            grabImage(root).save("/tmp/quickshell-attached-launcher.png");
        }
        function test_hoverSwitchesToNeighbor() {
            hover("audio");
            hover("wifi");
            compare(popover.accent, bar.menuAccent("wifi"));
            mouseMove(root, popover.bodyX + 40, popover.bodyY + 80);
            wait(380);
            compare(state.section, "wifi");
        }
        function test_clickKeepsMenuOpenUntilDismissed() {
            hover("audio");
            let trigger = findChild(bar, "audioTrigger");
            mouseClick(trigger, trigger.width / 2, trigger.height / 2);
            verify(state.pinned);
            mouseMove(root, 5, 480);
            wait(380);
            compare(state.section, "audio");
            state.close();
            compare(state.section, "");
        }
        function test_connectorFollowsScreenResize() {
            hover("audio");
            root.width = 1000;
            waitForRendering(bar);
            let trigger = findChild(bar, "audioTrigger");
            let position = trigger.mapToItem(root, trigger.width / 2, 0);
            compare(popover.tipX, position.x);
            compare(popover.bodyRight, root.width - 12);
        }
        function test_hoverReentryDoesNotFlicker() {
            hover("audio");
            // Surface focus changes can deliver a brief leave/reentry pair.
            for (let i = 0; i < 4; i++) {
                state.leave("audio");
                wait(40);
                state.hover("audio");
                wait(350);
                compare(state.section, "audio");
            }
        }
        function test_exitAndMenuEntryEventOrder() {
            hover("audio");
            state.retain(true);
            state.leave("audio");
            wait(380);
            compare(state.section, "audio");
            state.retain(false);
            wait(40);
            state.retain(true);
            wait(380);
            compare(state.section, "audio");
            state.retain(false);
            tryCompare(state, "section", "");
        }
        function test_closeKeepsGeometryUntilInvisible_data() {
            return [{tag: "audio", menu: "audio"}, {tag: "calendar", menu: "calendar"}, {tag: "battery", menu: "battery"}, {tag: "launcher", menu: "launcher"}];
        }
        function test_closeKeepsGeometryUntilInvisible(data) {
            hover(data.menu);
            wait(250);
            let tip = popover.tipX;
            let x = popover.bodyX;
            let height = popover.bodyHeight;
            let button = findChild(popover, "menuAction");
            state.close();
            compare(popover.tipX, tip, "The closing funnel must stay attached to its icon");
            compare(popover.bodyX, x, "The closing calendar must stay centered");
            compare(popover.bodyHeight, height, "The card must retain its size while fading");
            compare(findChild(popover, "menuAction"), button);
            wait(50);
            compare(popover.tipX, tip);
            compare(findChild(popover, "menuAction"), button);
            tryVerify(() => findChild(popover, "menuAction") === null);
        }
        function test_renderConnectedPopover() {
            hover("audio");
            wait(250);
            let saved = false;
            root.grabToImage(result => { result.saveToFile("/tmp/quickshell-hover-menu.png"); saved = true; });
            tryVerify(() => saved);
        }
    }
}
