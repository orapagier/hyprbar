import QtQuick

Item {
    id: controller
    property string section: ""
    // Keep the last menu's geometry and contents through its exit animation.
    property string displayedSection: ""
    onSectionChanged: if (section.length) displayedSection = section
    property string hoveredMenu: ""
    property bool pinned: false
    property bool dismissPinnedOnLeave: false
    property bool pointerInMenu: false

    function hover(name) {
        hoveredMenu = name;
        closeDelay.stop();
        if (section !== name) openDelay.restart();
    }
    function leave(name) {
        if (hoveredMenu !== name) return;
        hoveredMenu = "";
        openDelay.stop();
        retain(pointerInMenu);
    }
    function retain(inside) {
        pointerInMenu = inside;
        if (inside || hoveredMenu.length || (pinned && !dismissPinnedOnLeave)) closeDelay.stop();
        else if (section.length) closeDelay.restart();
    }
    function activate(name) {
        openDelay.stop();
        closeDelay.stop();
        if (section === name && pinned) close();
        else { section = name; pinned = true; }
    }
    function close() {
        openDelay.stop();
        closeDelay.stop();
        section = "";
        pinned = false;
    }
    Timer {
        id: openDelay
        interval: 110
        onTriggered: {
            if (!controller.hoveredMenu.length) return;
            if (controller.section !== controller.hoveredMenu) controller.pinned = false;
            controller.section = controller.hoveredMenu;
        }
    }
    Timer {
        id: closeDelay
        interval: 320
        onTriggered: {
            if (!controller.pointerInMenu && !controller.hoveredMenu.length && (!controller.pinned || controller.dismissPinnedOnLeave))
                controller.close();
        }
    }
}
