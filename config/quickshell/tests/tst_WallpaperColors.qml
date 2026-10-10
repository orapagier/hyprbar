import QtQuick
import QtTest
import ".."
import "../AdaptiveColors.js" as Colors
import "../WallpaperQuery.js" as Query

Item {
    id: scene
    width: 800; height: 100
    WallpaperColors {
        id: sampler
        source: Qt.resolvedUrl("fixtures/wallpaper-regions.svg")
        screenWidth: 800; screenHeight: 400
        offsetX: 0; offsetY: 8
    }
    Item {
        id: movingRow
        x: 20; y: 8
        Pill { id: pill; width: 100; text: "Sample"; colorSampler: sampler; colorRoot: scene }
    }
    Bar {
        id: bar
        y: 50; width: 800
        wallpaperSource: sampler.source
        screenWidth: 800; screenHeight: 400
    }
    TestCase {
        name: "WallpaperColors"
        when: windowShown
        function init() {
            pill.settings = {};
            sampler.source = Qt.resolvedUrl("fixtures/wallpaper-regions.svg");
            bar.settings = {};
            bar.wallpaperSource = sampler.source;
            bar.mediaData = {playing:false};
            sampler.screenWidth = 800; sampler.screenHeight = 400;
            movingRow.x = 20;
            tryCompare(sampler, "ready", true);
        }
        function sample(x) { return sampler.sampleRect(Qt.rect(x, 10, 30, 18)); }
        function test_bareMediaAndGlassUseContrastProtection() {
            bar.wallpaperSource = Qt.resolvedUrl("fixtures/wallpaper-fine-texture.svg");
            bar.settings = {bar:{background:"off", randomVibrantColors:true}};
            bar.mediaData = {playing:true, title:"Track", levels:[0.5]};
            tryCompare(bar.wallpaperColors, "ready", true);
            verify(findChild(bar, "archGlassLogo").contrastEdge);
            verify(findChild(bar, "settingsGlassCog").contrastEdge);
            let spectrum = findChild(bar.moduleItems.media.item, "mediaSpectrum");
            verify(spectrum.contrastEdge);
            compare(bar.moduleItems.media.item.content.style, Text.Outline);
            bar.settings = {bar:{background:"on", randomVibrantColors:true}};
            verify(!findChild(bar, "archGlassLogo").contrastEdge);
            verify(!spectrum.contrastEdge);
        }
        function test_samplingRetainsFineWallpaperDetails() {
            sampler.source = Qt.resolvedUrl("fixtures/wallpaper-fine-texture.svg");
            tryCompare(sampler, "ready", true);
            let region = sampler.sampleRect(Qt.rect(20, 10, 100, 20), true);
            fuzzyCompare(region.minimum, Qt.color("#000000"), 0.01);
            fuzzyCompare(region.maximum, Qt.color("#ffffff"), 0.01);
            let result = Colors.palette(region.average, Qt.color("#ffd45c"), region.minimum, region.maximum, "vibrant-bare");
            verify(result.glyphHalo, "Fine texture must not be mistaken for uniform gray");
        }
        function test_bareColorsProtectEveryToneAndVibrantMode() {
            let uniform = ["#000000", "#ffffff", "#777777", "#ff0000", "#00ff00", "#0000ff", "#b89961", "#576848"];
            for (let wallpaper of uniform) for (let accent of ["#ffd45c", "#54e3da", "#86a6ff", "#585b70", "#ff6b9d"])
                for (let style of ["bare-normal", "bare-muted", "bare-emphasized", "vibrant-bare"]) {
                    let sample = Qt.color(wallpaper);
                    let result = Colors.palette(sample, Qt.color(accent), sample, sample, style);
                    verify(Colors.contrast(result.foreground, sample) >= 4.5, wallpaper + " " + accent + " " + style);
                    verify(!result.glyphHalo, "Uniform colors should not need an outline");
                }
            for (let style of ["bare-normal", "bare-muted", "bare-emphasized", "vibrant-bare"]) {
                let result = Colors.palette(Qt.color("#888888"), Qt.color("#ffd45c"), Qt.color("#000000"), Qt.color("#ffffff"), style);
                verify(result.glyphHalo, "An average cannot protect glyphs on black/white texture");
                verify(Colors.contrast(result.foreground, result.glyphOutline) >= 4.5);
                compare(Colors.regionContrast(result.foreground, Qt.color("#000000"), Qt.color("#ffffff")), 1);
            }
            // A mostly pale region with a darker patch needs dark ink even
            // when the average alone would accept the original accent.
            let result = Colors.palette(Qt.color("#eeeeee"), Qt.color("#6a4d8a"), Qt.color("#aaaaaa"), Qt.color("#ffffff"), "vibrant-bare");
            verify(Colors.regionContrast(result.foreground, Qt.color("#aaaaaa"), Qt.color("#ffffff")) >= 4.5);
        }
        function test_bareEdgeFollowsWallpaperAndLeavesPillsAlone() {
            movingRow.x = 170;
            pill.settings = {background:"off", vibrantColor:"#ffd45c"};
            verify(pill.glyphHalo);
            compare(pill.content.style, Text.Outline);
            movingRow.x = 240;
            verify(!pill.glyphHalo);
            compare(pill.content.style, Text.Raised);
            verify(Colors.contrast(pill.effectiveForeground, Qt.color("#ffffff")) >= 4.5);
            movingRow.x = 170;
            pill.settings = {background:"on", vibrantColor:"#ffd45c"};
            compare(pill.glyphHalo, false);
            compare(pill.content.style, Text.Normal);
        }
        function test_samplesEachLocalRegionAtBarHeight() {
            fuzzyCompare(sample(20), Qt.rgba(0,0,0,1), 0.01);
            fuzzyCompare(sample(250), Qt.rgba(1,1,1,1), 0.01);
            fuzzyCompare(sample(450), Qt.rgba(1,0,0,1), 0.01);
            fuzzyCompare(sample(650), Qt.rgba(0,0,1,1), 0.01);
        }
        function test_detectsAwwwOutputsAndEscapesPaths() {
            let sources = Query.sources(": eDP-1: 1920x1080, scale: 1, currently displaying: image: /tmp/My wallpaper #1.png\nother: DP-1: 2560x1440, scale: 1.5, currently displaying: image: /tmp/other.jpg\n");
            compare(sources["eDP-1"], "file:///tmp/My%20wallpaper%20%231.png");
            compare(sources["DP-1"], "file:///tmp/other.jpg");
            sources = Query.sources("eDP-1: 1920x1080, scale: 1, currently displaying: image: /tmp/plain.jpg\n");
            compare(sources["eDP-1"], "file:///tmp/plain.jpg");
        }
        function test_centerCropMatchesWallpaper() {
            sampler.screenWidth = 400;
            tryCompare(sampler, "ready", true);
            fuzzyCompare(sample(20), Qt.rgba(1,1,1,1), 0.01);
            fuzzyCompare(sample(250), Qt.rgba(1,0,0,1), 0.01);
            sampler.screenWidth = 800; sampler.screenHeight = 200;
            tryCompare(sampler, "ready", true);
            fuzzyCompare(sample(20), Qt.rgba(0,1,0,1), 0.01);
        }
        function test_followsItemAndAncestorMovement() {
            let initial = Colors.luminance(pill.effectiveForeground);
            movingRow.x = 240;
            tryVerify(() => Colors.luminance(pill.effectiveForeground) < initial);
            movingRow.x = 440;
            tryVerify(() => Colors.luminance(pill.effectiveForeground) < 0.1);
        }
        function test_missingWallpaperKeepsReadableFallback() {
            sampler.source = "";
            compare(sampler.ready, false);
            verify(Colors.luminance(pill.effectiveForeground) > 0.15);
        }
        function test_contrastForEveryStateAndUnderlyingExtreme() {
            let samples = [Qt.rgba(0,0,0,1), Qt.rgba(1,1,1,1), Qt.rgba(1,0,0,1), Qt.rgba(0,1,0,1), Qt.rgba(0,0,1,1), Qt.rgba(0.6,0.6,0.6,1)];
            let accents = [Qt.rgba(0.09,0.58,0.82,1), Qt.rgba(0.34,0.35,0.44,1), Qt.rgba(0.95,0.55,0.66,1)];
            for (let sample of samples) for (let accent of accents) for (let style of ["normal", "muted", "emphasized"]) {
                let palette = Colors.palette(sample, accent, Qt.rgba(0,0,0,1), Qt.rgba(1,1,1,1), style);
                for (let fill of [palette.tint, palette.hover, palette.selected]) {
                    for (let under of samples) {
                        let composite = Colors.mix(under, fill, fill.a);
                        for (let highlight of [0, 0.08]) {
                            let rendered = Colors.mix(composite, Qt.rgba(1,1,1,1), highlight);
                            verify(Colors.contrast(palette.foreground, rendered) >= 4.5,
                                   "Text contrast fell below 4.5:1");
                        }
                    }
                }
            }
        }
        function test_uniformWallpapersKeepTransparentGlass() {
            let samples = [Qt.rgba(0,0,0,1), Qt.rgba(1,1,1,1), Qt.rgba(1,0,0,1), Qt.rgba(0,1,0,1), Qt.rgba(0,0,1,1), Qt.rgba(0.6,0.6,0.6,1)];
            for (let sample of samples) {
                let palette = Colors.palette(sample, Qt.rgba(0.54,0.70,0.98,1));
                verify(palette.tint.a <= 0.40, "Uniform wallpaper should show through the glass");
                for (let fill of [palette.tint, palette.hover, palette.selected]) {
                    let composite = Colors.mix(sample, fill, fill.a);
                    for (let highlight of [0, 0.08])
                        verify(Colors.contrast(palette.foreground, Colors.mix(composite, Qt.rgba(1,1,1,1), highlight)) >= 4.5);
                }
            }
        }
        function test_mixedRegionsProvideContrastBounds() {
            let region = sampler.sampleRect(Qt.rect(185, 10, 30, 18), true);
            fuzzyCompare(region.minimum, Qt.rgba(0,0,0,1), 0.01);
            fuzzyCompare(region.maximum, Qt.rgba(1,1,1,1), 0.01);
            let palette = Colors.palette(region.average, Qt.rgba(0.54,0.70,0.98,1), region.minimum, region.maximum);
            verify(palette.tint.a > 0.22, "Mixed black and white areas need stronger tinting");
        }
        function test_barContentsUseLocalPalette() {
            tryCompare(bar.wallpaperColors, "ready", true);
            let launcher = findChild(bar, "launcherTrigger");
            let bell = findChild(bar, "notificationBell");
            verify(launcher.adaptivePalette !== null);
            verify(bell.adaptivePalette !== null);
            bar.mediaData = {playing: true, title: "Track", levels: [0.5]};
            let media = findChild(bar, "mediaSlot");
            tryCompare(media, "active", true);
            verify(media.item.adaptivePalette !== null);
            grabImage(bar).save("/tmp/quickshell-wallpaper-regions.png");
        }
    }
}
