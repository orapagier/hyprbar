import QtQuick
import "AdaptiveColors.js" as Colors

Item {
    id: sampler
    property url source: ""
    property real screenWidth: 1366
    property real screenHeight: 768
    property real offsetX: 10
    property real offsetY: 5
    property real bandHeight: 32
    property var pixels: []
    readonly property bool ready: pixels.length > 0
    width: 1; height: 1
    // Keep the Canvas attached to the scene so requestPaint works, without
    // displaying the sampled strip or intercepting pointer events.
    opacity: 0

    function invalidate() { pixels = []; strip.requestPaint(); }
    onSourceChanged: invalidate()
    onScreenWidthChanged: invalidate()
    onScreenHeightChanged: invalidate()
    onOffsetYChanged: invalidate()
    onBandHeightChanged: invalidate()

    function sampleRect(rect, includeBounds) {
        if (!ready) {
            let fallback = Qt.rgba(0.08, 0.09, 0.13, 1);
            return includeBounds ? {average: fallback, minimum: fallback, maximum: fallback} : fallback;
        }
        let x0 = Math.max(0, Math.min(strip.width - 1, Math.floor(rect.x / screenWidth * strip.width)));
        let x1 = Math.max(x0 + 1, Math.min(strip.width, Math.ceil((rect.x + rect.width) / screenWidth * strip.width)));
        let y0 = Math.max(0, Math.min(strip.height - 1, Math.floor((rect.y - offsetY) / bandHeight * strip.height)));
        let y1 = Math.max(y0 + 1, Math.min(strip.height, Math.ceil((rect.y + rect.height - offsetY) / bandHeight * strip.height)));
        let r = 0, g = 0, b = 0, count = 0;
        let lowR = 255, lowG = 255, lowB = 255, highR = 0, highG = 0, highB = 0;
        for (let y = y0; y < y1; ++y) for (let x = x0; x < x1; ++x) {
            let i = (y * strip.width + x) * 4;
            r += pixels[i]; g += pixels[i + 1]; b += pixels[i + 2]; ++count;
            if (includeBounds) {
                lowR = Math.min(lowR, pixels[i]); lowG = Math.min(lowG, pixels[i + 1]); lowB = Math.min(lowB, pixels[i + 2]);
                highR = Math.max(highR, pixels[i]); highG = Math.max(highG, pixels[i + 1]); highB = Math.max(highB, pixels[i + 2]);
            }
        }
        let average = Qt.rgba(r / count / 255, g / count / 255, b / count / 255, 1);
        return includeBounds ? {average: average, minimum: Qt.rgba(lowR/255, lowG/255, lowB/255, 1), maximum: Qt.rgba(highR/255, highG/255, highB/255, 1)} : average;
    }
    function paletteFor(item, root, accent, style) {
        let x = offsetX, y = offsetY;
        // Explicitly read ancestor coordinates so bindings follow Row movement,
        // monitor resizing, newly visible controls, and media title changes.
        for (let node = item; node && node !== root; node = node.parent) {
            x += node.x; y += node.y;
        }
        let region = sampleRect(Qt.rect(x, y, item.width, item.height), true);
        return Colors.palette(region.average, accent, region.minimum, region.maximum, style);
    }

    Image {
        id: wallpaper
        source: sampler.source
        asynchronous: true
        visible: false
        onStatusChanged: {
            sampler.pixels = [];
            if (status === Image.Ready) strip.requestPaint();
        }
    }
    Canvas {
        id: strip
        width: Math.min(1024, Math.max(1, Math.ceil(sampler.screenWidth / 2)))
        height: 16
        onAvailableChanged: if (available) requestPaint()
        onWidthChanged: sampler.invalidate()
        onPaint: {
            if (wallpaper.status !== Image.Ready || sampler.screenWidth <= 0 || sampler.screenHeight <= 0) return;
            let iw = wallpaper.implicitWidth, ih = wallpaper.implicitHeight;
            if (!iw || !ih) return;
            // Match awww's default center-cropped, aspect-preserving wallpaper.
            let scale = Math.max(sampler.screenWidth / iw, sampler.screenHeight / ih);
            let sx = (iw - sampler.screenWidth / scale) / 2;
            let sy = (ih - sampler.screenHeight / scale) / 2 + sampler.offsetY / scale;
            let ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(wallpaper, sx, sy, sampler.screenWidth / scale, sampler.bandHeight / scale, 0, 0, width, height);
            let data = ctx.getImageData(0, 0, width, height).data;
            let copy = [];
            for (let i = 0; i < data.length; ++i) copy.push(data[i]);
            sampler.pixels = copy;
        }
    }
}
