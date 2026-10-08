import QtQuick
import QtTest
import ".."

Item {
    id: root
    width: 300; height: 600
    QtObject {
        id: inbox
        property int unread: 0
        property string dismissedId: ""
        property var rows: [{id: "long", app: "An application name long enough to wrap across several lines", summary: "A very long notification title that must remain completely readable when expanded instead of being cut off at the right edge of the notification panel", body: "Full notification details.\n" + Array(30).fill("A long paragraph with all the details that should be readable by scrolling vertically.").join("\n") + "\nhttps://example.com/" + Array(120).fill("x").join(""), received: Date.now(), active: false, actions: []}]
        function markRead() {}
        function dismiss(id) { dismissedId = String(id); }
        function invoke(id, action) {}
        function clear() {}
    }
    InboxMenu { id: menu; width: 264; inbox: root.notificationStore }
    readonly property var notificationStore: inbox
    TestCase {
        name: "NotificationExpansion"
        when: windowShown
        function init() {
            menu.expanded = "";
            inbox.dismissedId = "";
            let scroll = findChild(menu, "notificationScroll");
            scroll.contentItem.contentY = 0;
            waitForRendering(menu);
        }
        function test_clickExpandsFullTextAndClickAgainCollapses() {
            let card = findChild(menu, "notification-long");
            verify(card !== null);
            let header = findChild(card, "notificationHeader");
            let summary = findChild(card, "notificationSummary");
            let app = findChild(card, "notificationApp");
            let body = findChild(card, "notificationBody");
            let details = findChild(card, "notificationDetails");
            let scroll = findChild(menu, "notificationScroll");
            let close = findChild(card, "notificationDismiss");
            compare(card.expanded, false);
            verify(!close.visible);
            verify(!details.visible);
            let collapsedHeight = card.height;
            mouseClick(header, header.width / 2, header.height / 2);
            tryCompare(card, "expanded", true);
            waitForRendering(card);
            verify(details.visible);
            compare(summary.text, inbox.rows[0].summary);
            compare(body.text, inbox.rows[0].body);
            verify(summary.lineCount > 1);
            verify(app.lineCount > 1);
            verify(!summary.truncated);
            verify(!body.truncated);
            verify(body.paintedWidth <= body.width + 1);
            verify(card.height > collapsedHeight);
            verify(scroll.contentHeight > scroll.height);
            verify(body.height >= body.paintedHeight, "The entire body must fit its item");
            verify(card.width <= scroll.availableWidth + 1);
            verify(close.visible);
            verify(close.mapToItem(header, 0, 0).x > header.width / 2);
            verify(close.mapToItem(header, 0, 0).y < 10);
            let saved = false;
            menu.grabToImage(result => { result.saveToFile("/tmp/quickshell-notification-expanded.png"); saved = true; });
            tryVerify(() => saved);
            mouseClick(header, header.width / 2, header.height / 2);
            tryCompare(card, "expanded", false);
            tryCompare(details, "visible", false);
            tryCompare(card, "height", collapsedHeight);
            mouseClick(header, header.width / 2, header.height / 2);
            tryCompare(card, "expanded", true);
            waitForRendering(card);
            mouseClick(body, body.width / 2, 8);
            tryCompare(card, "expanded", false);
        }
        function test_cornerXDismissesWithoutCollapsing() {
            let card = findChild(menu, "notification-long");
            let header = findChild(card, "notificationHeader");
            let close = findChild(card, "notificationDismiss");
            mouseClick(header, 20, 20);
            tryCompare(card, "expanded", true);
            waitForRendering(card);
            mouseClick(close, close.width / 2, close.height / 2);
            compare(inbox.dismissedId, "long");
            compare(card.expanded, true);
        }
        function test_veryLongNotificationScrollsToFinalLine() {
            let previousRows = inbox.rows;
            let ending = "FINAL LINE — all notification details are retained.";
            let text = Array(1500).fill("A long paragraph that must remain complete and readable.").join("\n") + "\n" + ending;
            let title = Array(30).fill("A long title that must also wrap without a character limit.").join(" ");
            inbox.rows = [{id: "huge", app: "Application", summary: title, body: text, received: Date.now(), active: false, actions: []}];
            waitForRendering(menu);
            let card = findChild(menu, "notification-huge");
            let header = findChild(card, "notificationHeader");
            mouseClick(header, 20, 20);
            tryCompare(card, "expanded", true);
            waitForRendering(card);
            let body = findChild(card, "notificationBody");
            let summary = findChild(card, "notificationSummary");
            let scroll = findChild(menu, "notificationScroll");
            compare(summary.text, title);
            verify(!summary.truncated);
            verify(summary.height >= summary.paintedHeight);
            compare(body.text, text);
            verify(body.text.length > 80000);
            verify(!body.truncated);
            verify(body.height >= body.paintedHeight);
            let flickable = scroll.contentItem;
            flickable.contentY = flickable.contentHeight - flickable.height;
            waitForRendering(menu);
            let bottom = body.mapToItem(flickable, 0, body.height);
            verify(bottom.y > 0 && bottom.y <= flickable.height, "The final line must be reachable by scrolling");
            let saved = false;
            menu.grabToImage(result => { result.saveToFile("/tmp/quickshell-notification-final-line.png"); saved = true; });
            tryVerify(() => saved);
            // Mouse-wheel scrolling must work on desktop, not just setting contentY.
            let before = flickable.contentY;
            mouseWheel(flickable, 50, 150, 0, 120);
            tryVerify(() => flickable.contentY < before);
            inbox.rows = previousRows;
        }
    }
}
