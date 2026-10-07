"""Contrast and backdrop-selection checks without a running desktop."""
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import Mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('adaptive_glass_test', ROOT / 'adaptive-glass.py')
glass = importlib.util.module_from_spec(spec)
spec.loader.exec_module(glass)


class ContrastTests(unittest.TestCase):
    def test_every_brightness_keeps_normal_status_and_selected_text_readable(self):
        previous = 0
        for brightness in range(256):
            alpha = glass.opacity_for_brightness(brightness)
            self.assertGreaterEqual(alpha, previous)
            previous = alpha
            panel = glass.composite((255,) * 3, glass.composite(glass.TINT, (brightness,) * 3, alpha), .08)
            button = glass.composite((255,) * 3, panel, .045)
            selected = glass.composite((255,) * 3, glass.composite((203, 166, 247), panel, .22), .06)
            for text, backdrop in ((glass.MUTED, button), (glass.STATUS, button), (glass.SELECTED, selected)):
                self.assertGreaterEqual(glass.contrast(text, backdrop), 4.5)
        self.assertEqual(glass.opacity_for_brightness(0), .28)
        self.assertGreater(glass.opacity_for_brightness(255), .9)

    def test_unavailable_or_invalid_capture_uses_readable_fallback(self):
        for value in (None, float('nan'), float('inf')):
            self.assertEqual(glass.opacity_for_brightness(value), glass.FALLBACK)


class SamplingTests(unittest.TestCase):
    def setUp(self):
        self.sampler = glass.Sampler()
        self.monitors = [{'activeWorkspace': {'id': 1}, 'specialWorkspace': {'id': -99}}]
        self.clients = []
        self.sampler.query = lambda name: self.monitors if name == 'monitors' else self.clients
        self.sampler.capture = Mock(return_value=50)
        self.sampler.wallpaper_state = Mock(return_value=b'eDP-1: night.jpg')

    def client(self, address='0x123', **kwargs):
        result = dict(mapped=True, hidden=False, workspace={'id': 1},
                      at=[-100, 0], size=[400, 200], address=address)
        result.update(kwargs)
        self.clients.append(result)
        return result

    def test_crop_is_relative_to_window_on_monitor_with_negative_origin(self):
        self.client()
        self.assertEqual(self.sampler.windows((-50, 20, 100, 80)), 50)
        self.sampler.capture.assert_called_once_with('window', '0x123', (.125, .1, .25, .4))

    def test_hidden_unmapped_other_workspace_and_nonoverlapping_windows_are_excluded(self):
        self.client(hidden=True)
        self.client(mapped=False)
        self.client(workspace={'id': 9})
        self.client(at=[800, 800])
        self.assertIsNone(self.sampler.windows((0, 0, 100, 100)))
        self.sampler.capture.assert_not_called()

    def test_brightest_overlap_wins_and_failed_capture_falls_back_safely(self):
        self.client('dark')
        self.client('white', floating=True)
        self.sampler.capture.side_effect = lambda mode, address, crop: 255 if address == 'white' else 20
        self.assertEqual(self.sampler.windows((0, 0, 100, 100)), 255)
        self.sampler.capture.side_effect = lambda mode, address, crop: None if address == 'white' else 20
        self.assertIsNone(self.sampler.windows((0, 0, 100, 100)))

    def test_unchanged_empty_desktop_keeps_sample_and_wallpaper_change_invalidates_it(self):
        self.assertEqual(self.sampler.opening('eDP-1', (0, 0, 100, 100), (0, 0, 100, 100)), 50)
        self.assertEqual(self.sampler.windows((0, 0, 100, 100)), 50)
        self.sampler.wallpaper_state.return_value = b'eDP-1: white.jpg'
        self.assertIsNone(self.sampler.windows((0, 0, 100, 100)))

    def test_window_sample_is_never_reused_as_wallpaper_sample(self):
        self.client()
        self.sampler.opening('eDP-1', (0, 0, 100, 100), (0, 0, 100, 100))
        self.clients.clear()
        self.assertIsNone(self.sampler.windows((0, 0, 100, 100)))

    def test_crowded_layout_uses_fallback_instead_of_ignoring_extra_windows(self):
        for index in range(4):
            self.client(str(index))
        self.assertIsNone(self.sampler.windows((0, 0, 100, 100)))
        self.sampler.capture.assert_not_called()

    def test_partial_window_does_not_hide_unknown_wallpaper(self):
        self.client(at=[0, 0], size=[50, 100])
        self.assertIsNone(self.sampler.windows((0, 0, 100, 100)))
        self.client(at=[50, 0], size=[50, 100])
        self.assertEqual(self.sampler.windows((0, 0, 100, 100)), 50)

    def test_partial_window_preserves_known_bright_wallpaper(self):
        self.sampler.desktop_sample = (b'eDP-1: night.jpg', 240)
        self.client(at=[0, 0], size=[50, 100])
        self.assertEqual(self.sampler.windows((0, 0, 100, 100)), 240)

    def test_compositor_failure_leaves_menu_readable(self):
        self.sampler.query = Mock(side_effect=subprocess.TimeoutExpired('hyprctl', .35))
        self.assertIsNone(self.sampler.windows((0, 0, 100, 100)))


if __name__ == '__main__':
    unittest.main()
