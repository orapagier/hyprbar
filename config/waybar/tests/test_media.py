"""Audio spectrum, player selection, scrolling, and Waybar output checks."""
from array import array
import contextlib
import importlib.util
import io
import json
import math
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("waybar_media", Path(__file__).resolve().parents[1] / "media.py")
MEDIA = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MEDIA)


def tone(frequency):
    samples = array("h", [int(12000 * math.sin(math.tau * frequency * i / MEDIA.SAMPLE_RATE))
                          for i in range(MEDIA.SAMPLE_COUNT)])
    if MEDIA.sys.byteorder != "little":
        samples.byteswap()
    return samples.tobytes()


def player(name, title, playing=True):
    metadata = MEDIA.GLib.Variant("a{sv}", {"xesam:title": MEDIA.GLib.Variant("s", title)})
    status = MEDIA.Playerctl.PlaybackStatus.PLAYING if playing else MEDIA.Playerctl.PlaybackStatus.PAUSED
    return SimpleNamespace(props=SimpleNamespace(player_instance=name, player_name=name,
                                                playback_status=status, metadata=metadata))


class MediaTests(unittest.TestCase):
    def test_spectrum_follows_frequency_and_decays_to_silence(self):
        peaks = []
        for frequency in (80, 300, 1000, 4000):
            spectrum = MEDIA.Spectrum()
            try:
                bars, sounded = spectrum.frame(tone(frequency))
                self.assertTrue(sounded)
                self.assertEqual(len(bars), 8)
                peaks.append(max(range(8), key=lambda i: spectrum.levels[i]))
                for _ in range(30):
                    bars, sounded = spectrum.frame(bytes(MEDIA.SAMPLE_COUNT * 2))
                self.assertFalse(sounded)
                self.assertEqual(bars, "▁" * 8)
            finally:
                spectrum.close()
        self.assertEqual(peaks, [1, 3, 5, 7])

    def test_title_metadata_and_filename_fallback(self):
        self.assertEqual(MEDIA.media_title({"xesam:title": " Song\nname ", "xesam:artist": ["Artist"]}, "vlc"),
                         "Artist — Song name")
        self.assertEqual(MEDIA.media_title({"xesam:url": "file:///tmp/My%20video.mkv"}, "vlc"), "My video.mkv")
        self.assertEqual(MEDIA.media_title({}, "vlc"), "vlc")

    def test_marquee_holds_then_scrolls_and_resets_on_track_change(self):
        marquee = MEDIA.Marquee(width=10)
        title = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        self.assertEqual(marquee.frame("first", title, 0), title[:10])
        self.assertEqual(marquee.frame("first", title, 1.9), title[:10])
        self.assertNotEqual(marquee.frame("first", title, 3), title[:10])
        self.assertEqual(marquee.frame("second", title, 4), title[:10])
        self.assertEqual(marquee.frame("short", "Hello", 5), "Hello")

    def test_unicode_scroll_preserves_combining_characters_and_width(self):
        marquee = MEDIA.Marquee(width=8)
        title = "e\u0301漢字🎵" * 8
        for now in (0, 3, 6, 10):
            frame = marquee.frame("unicode", title, now)
            self.assertEqual(sum(MEDIA.columns(c) for c in MEDIA.clusters(frame)), 8)
            self.assertFalse(frame.startswith("\u0301"))

    def test_active_player_prefers_recent_playing_and_ignores_paused(self):
        app = MEDIA.Media.__new__(MEDIA.Media)
        app.manager = SimpleNamespace(props=SimpleNamespace(players=[player("vlc", "Film"), player("browser", "Video"),
                                                                    player("spotify", "Song", playing=False)]))
        app.recency = {"vlc": 20, "browser": 10, "spotify": 30}
        self.assertEqual(app.active_player().props.player_name, "vlc")

    def test_output_switch_reconnects_capture(self):
        app = MEDIA.Media.__new__(MEDIA.Media)
        app.default_sink = "speakers"
        app.route_query = object()
        app.retry_at = 30
        stopped = []
        app.stop_capture = lambda: stopped.append(True)
        process = SimpleNamespace(communicate_utf8_finish=lambda result: (True, "headphones\n", ""),
                                  get_successful=lambda: True)
        app.output_changed(process, None)
        self.assertEqual(app.default_sink, "headphones")
        self.assertEqual(stopped, [True])
        self.assertEqual(app.retry_at, 0)

    def test_module_hides_after_stop_and_escapes_title_markup(self):
        app = MEDIA.Media.__new__(MEDIA.Media)
        app.spectrum = MEDIA.Spectrum()
        self.addCleanup(app.spectrum.close)
        app.marquee = MEDIA.Marquee()
        playing = player("vlc", '<b>Title & song</b>')
        app.manager = SimpleNamespace(props=SimpleNamespace(players=[playing]))
        app.recency = {"vlc": 1}
        app.buffer = bytearray(tone(1000))
        app.received_at = 10
        app.sounded_at = -math.inf
        app.previous = None
        app.start_capture = lambda now: None
        app.audio_title = lambda now: ("Stream title", "Other player")
        output = io.StringIO()
        with contextlib.redirect_stdout(output), patch.object(MEDIA.time, "monotonic", return_value=10):
            app.tick()
        payload = json.loads(output.getvalue())
        self.assertEqual(payload["class"], "playing")
        self.assertIn("&lt;b&gt;Title &amp; song&lt;/b&gt;", payload["text"])
        playing.props.playback_status = MEDIA.Playerctl.PlaybackStatus.PAUSED
        output = io.StringIO()
        with contextlib.redirect_stdout(output), patch.object(MEDIA.time, "monotonic", return_value=10.1):
            app.tick()
        self.assertIn("Stream title", json.loads(output.getvalue())["text"])
        output = io.StringIO()
        with contextlib.redirect_stdout(output), patch.object(MEDIA.time, "monotonic", return_value=12):
            app.tick()
        self.assertEqual(json.loads(output.getvalue())["text"], "")


if __name__ == "__main__":
    unittest.main()
