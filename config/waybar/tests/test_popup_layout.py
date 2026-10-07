"""Popup placement regressions that run without a desktop display."""
import configparser
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import Mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('wifi_popup_layout', ROOT / 'wifi-popup.py')
popup_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(popup_module)
calendar_spec = importlib.util.spec_from_file_location('calendar_popup_layout', ROOT / 'ph-calendar.py')
calendar_module = importlib.util.module_from_spec(calendar_spec)
calendar_spec.loader.exec_module(calendar_module)


class PopupLayoutTests(unittest.TestCase):
    def setUp(self):
        self.popup = popup_module.Popup.__new__(popup_module.Popup)
        self.popup.closed = False
        self.popup.position_source = None
        self.popup.settings = configparser.ConfigParser()
        self.popup.settings.read_dict({'main': {'x-margin': '12', 'y-margin': '40'}})
        self.popup.settings = self.popup.settings['main']
        self.popup.panel_events = Mock()
        self.popup.panel_events.get_preferred_width.return_value = (338, 338)
        self.popup.panel_events.get_preferred_height.return_value = (300, 300)
        self.popup.fixed = Mock()
        self.popup.fixed.get_allocation.return_value = SimpleNamespace(width=1920, height=1080)
        self.position = [0, 0]
        self.popup.fixed.child_get_property.side_effect = lambda panel, axis: self.position[axis == 'y']
        self.popup.fixed.move.side_effect = lambda panel, x, y: self.position.__setitem__(slice(None), [x, y])

    def drain_layout(self):
        context = popup_module.GLib.MainContext.default()
        while self.popup.position_source is not None:
            context.iteration(False)

    def test_first_allocation_positions_without_user_input(self):
        self.popup.queue_position()
        self.popup.fixed.move.assert_not_called()
        self.drain_layout()
        self.assertEqual(self.position, [1570, 40])

    def test_repeated_allocations_settle_without_resize_loop(self):
        for _ in range(3):
            self.popup.queue_position()
        self.drain_layout()
        self.popup.fixed.move.assert_called_once()
        self.popup.queue_position()
        self.drain_layout()
        self.popup.fixed.move.assert_called_once()

    def test_monitor_resize_reanchors_panel(self):
        self.popup.queue_position()
        self.drain_layout()
        self.popup.fixed.get_allocation.return_value = SimpleNamespace(width=1280, height=720)
        self.popup.queue_position()
        self.drain_layout()
        self.assertEqual(self.position, [930, 40])

    def test_small_monitor_keeps_panel_within_top_left_bounds(self):
        self.assertEqual(self.popup.panel_position(320, 240), (0, 0))

    def test_calendar_is_centered_before_first_frame_and_uses_same_sampling_position(self):
        calendar = calendar_module.CalendarPopup.__new__(calendar_module.CalendarPopup)
        calendar.panel_events = self.popup.panel_events
        calendar.settings = self.popup.settings
        self.assertEqual(calendar.panel_position(1920, 1080), (791, 40))
        self.assertEqual(calendar.panel_position(320, 240), (0, 0))

    def test_closed_popup_ignores_pending_placement(self):
        self.popup.queue_position()
        self.popup.closed = True
        self.drain_layout()
        self.popup.fixed.move.assert_not_called()


if __name__ == '__main__':
    unittest.main()
