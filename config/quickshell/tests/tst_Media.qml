import QtQuick
import QtTest
import ".."

Item {
    width: 600; height: 70
    MediaPill { id: media; x: 10; y: 10; text: "Artist — Track title" }
    TestCase {
        name: "MediaSpectrum"
        when: windowShown
        function cleanup() { media.levels = []; wait(60); }
        function test_barsExpandAboveAndBelowTheirCenter() {
            let bar = findChild(media, "spectrumBar3");
            compare(bar.height, 2);
            let top = bar.y;
            let bottom = bar.y + bar.height;
            media.levels = [0,0,0,1];
            tryCompare(bar, "height", 16);
            verify(bar.y < top);
            verify(bar.y + bar.height > bottom);
            compare(bar.y + bar.height / 2, 8);
        }
        function test_frequencyBandsMoveIndependently() {
            media.levels = [0.05,0.1,0.25,0.5,0.75,1,0.8,0.6,0.4,0.2,0.1,0];
            wait(70);
            for (let index = 0; index < 12; ++index) {
                let bar = findChild(media, "spectrumBar" + index);
                fuzzyCompare(bar.height, 2 + media.levels[index] * 14, 0.01);
            }
        }
        function test_missingAndInvalidLevelsStayWithinThePill() {
            media.levels = [NaN, -2, 9, undefined];
            wait(70);
            for (let index = 0; index < 12; ++index) {
                let bar = findChild(media, "spectrumBar" + index);
                verify(bar.height >= 2 && bar.height <= 16);
                verify(bar.y >= 0 && bar.y + bar.height <= 16);
            }
        }
        function test_renderSpectrum() {
            media.levels = [0.2,0.4,0.7,0.95,0.6,0.3,0.5,0.8,0.65,0.4,0.15,0.3];
            wait(70);
            grabImage(media).save("/tmp/quickshell-media-spectrum.png");
        }
    }
}
