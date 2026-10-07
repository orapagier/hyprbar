#!/usr/bin/env python3
"""Centered Waybar calendar using the audio/Wi-Fi layer-shell popup."""

import calendar
from datetime import date, timedelta
import importlib.util
from pathlib import Path
import sys
import traceback

_spec = importlib.util.spec_from_file_location("waybar_popup", Path(__file__).with_name("wifi-popup.py"))
_popup = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_popup)
Gdk, Gtk, GtkLayerShell = _popup.Gdk, _popup.Gtk, _popup.GtkLayerShell
Popup, arguments = _popup.Popup, _popup.arguments

KIND_LABELS = {
    "regular": "Regular Holiday",
    "special": "Special Non-Working Day",
    "working": "Special Working Day",
}
CNY = {2024: (2, 10), 2025: (1, 29), 2026: (2, 17), 2027: (2, 6), 2028: (1, 26)}


def easter_sunday(year):
    a, b, c = year % 19, year // 100, year % 100
    d, e = b // 4, b % 4
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i, k = c // 4, c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    month = (h + l - 7 * m + 114) // 31
    day = (h + l - 7 * m + 114) % 31 + 1
    return date(year, month, day)


def holidays_for_year(year):
    # Preserve the holiday data and rules from ph-calendar.html.
    holidays = {
        (1, 1): ("New Year's Day", "regular"),
        (4, 9): ("Araw ng Kagitingan", "regular"),
        (5, 1): ("Labor Day", "regular"),
        (6, 12): ("Independence Day", "regular"),
        (11, 30): ("Bonifacio Day", "regular"),
        (12, 25): ("Christmas Day", "regular"),
        (12, 30): ("Rizal Day", "regular"),
        (8, 21): ("Ninoy Aquino Day", "special"),
        (11, 1): ("All Saints' Day", "special"),
        (11, 2): ("All Souls' Day", "special"),
        (12, 8): ("Feast of the Immaculate Conception", "special"),
        (12, 24): ("Christmas Eve", "special"),
        (12, 31): ("Last Day of the Year", "special"),
        (2, 25): ("EDSA People Power Anniversary", "working"),
    }
    last = date(year, 8, 31)
    monday = last - timedelta(days=last.weekday())
    holidays[(8, monday.day)] = ("National Heroes Day", "regular")
    easter = easter_sunday(year)
    for offset, name, kind in ((-3, "Maundy Thursday", "regular"),
                               (-2, "Good Friday", "regular"),
                               (-1, "Black Saturday", "special")):
        day = easter + timedelta(days=offset)
        holidays[(day.month, day.day)] = (name, kind)
    if year in CNY:
        holidays[CNY[year]] = ("Chinese New Year", "special")
    if year == 2026:
        holidays[(3, 20)] = ("Eid'l Fitr", "regular")
        holidays[(5, 27)] = ("Eid'l Adha", "regular")
    return holidays


def shift_month(year, month, offset):
    index = max(12, min(9999 * 12 + 11, year * 12 + month - 1 + offset))
    new_year, new_month = divmod(index, 12)
    return new_year, new_month + 1


class CalendarPopup(Popup):
    def __init__(self, args):
        args.lines = 0
        super().__init__(args, [])
        today = date.today()
        self.year, self.month = today.year, today.month
        self.updating = False
        self.selected = today
        self.date_popover = None
        self.day_buttons = {}
        self.calendar_css = Gtk.CssProvider()
        self.calendar_css.load_from_data(b'''
#wifi-panel button {
  background: rgba(255,255,255,0.045); background-image: none; color: #cdd6f4;
  border: 1px solid transparent; border-radius: 8px; box-shadow: none;
  padding: 5px 7px; min-height: 22px; min-width: 18px;
}
#wifi-panel button:hover { background: rgba(203,166,247,0.22); }
#wifi-panel button:focus { border-color: #b4befe; outline: none; }
#wifi-panel button.today-control, #wifi-panel button.today-control:hover, #wifi-panel button.today-control:active, #wifi-panel button.today-control:focus { border-color: transparent; outline: none; box-shadow: none; }
#wifi-panel .calendar-heading { color: #b4befe; font-size: 11pt; font-weight: 600; }
#wifi-panel .weekday { color: #a6adc8; font-size: 8pt; }
#wifi-panel button.day { padding: 3px; min-height: 24px; }
#wifi-panel button.regular, #wifi-panel .regular { color: #f38ba8; }
#wifi-panel button.special, #wifi-panel .special { color: #f9e2af; }
#wifi-panel button.working, #wifi-panel .working { color: #89b4fa; }
#wifi-panel button.regular { background: rgba(243,139,168,0.12); }
#wifi-panel button.special { background: rgba(249,226,175,0.12); }
#wifi-panel button.working { background: rgba(137,180,250,0.12); }
#wifi-panel button.today { border-color: #cba6f7; font-weight: bold; }
#wifi-panel button.selected { background: rgba(203,166,247,0.22); }
popover.calendar-tooltip { background: rgba(30,30,46,0.72); color: #cdd6f4; border: 1px solid rgba(255,255,255,0.16); border-radius: 8px; box-shadow: none; }
popover.calendar-tooltip label { color: #cdd6f4; font-family: "GoMono Nerd Font"; font-size: 9pt; }
#wifi-panel combobox button { padding: 5px 8px; }
#wifi-panel combobox arrow { color: #a6adc8; min-width: 10px; min-height: 10px; }
#wifi-panel spinbutton { background: rgba(255,255,255,0.045); color: #cdd6f4; caret-color: #b4befe; border: 1px solid rgba(255,255,255,0.12); border-radius: 8px; box-shadow: none; font-weight: 600; }
#wifi-panel spinbutton entry { background: transparent; color: #cdd6f4; caret-color: #b4befe; padding: 4px 6px; min-height: 24px; font-weight: 600; }
#wifi-panel spinbutton:focus, #wifi-panel spinbutton:focus-within { border-color: rgba(205,214,244,0.10); outline: none; box-shadow: none; }
#wifi-panel spinbutton selection, #wifi-panel spinbutton entry selection { background-color: #b4befe; color: #11111b; }
#wifi-panel spinbutton button, #wifi-panel spinbutton button:hover, #wifi-panel spinbutton button:active, #wifi-panel spinbutton button:focus, #wifi-panel spinbutton button:checked { color: #b4befe; border: none; outline: none; box-shadow: none; padding: 2px 4px; min-width: 10px; }
menu { background: rgba(30,30,46,0.28); background-image: linear-gradient(to bottom, rgba(255,255,255,0.08), rgba(255,255,255,0)); color: #cdd6f4; border: 1px solid rgba(255,255,255,0.16); border-radius: 8px; padding: 6px; }
menu menuitem { color: #cdd6f4; padding: 8px 10px; border-radius: 6px; }
menu menuitem:hover { background: rgba(203,166,247,0.22); color: #b4befe; }
''')

    def button(self, label, tooltip, callback):
        button = Gtk.Button(label=label)
        button.get_accessible().set_name(tooltip or label)
        button.connect("clicked", callback)
        return button

    def panel(self):
        self.panel_events = Gtk.EventBox()
        self.panel_events.set_name("wifi-panel")
        self.panel_events.set_visible_window(True)
        self.panel_events.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        self.panel_events.connect("button-press-event", self.inside_click)
        box = self.panel_content()
        header = Gtk.Box(spacing=8)
        self.previous = self.button("‹", "Previous month", lambda *_: self.change_month(-1))
        header.pack_start(self.previous, False, False, 0)
        self.heading = Gtk.Label()
        self.heading.get_style_context().add_class("calendar-heading")
        header.pack_start(self.heading, True, True, 0)
        header.pack_end(self.button("›", "Next month", lambda *_: self.change_month(1)), False, False, 0)
        box.pack_start(header, False, False, 0)
        self.grid = Gtk.Grid(column_spacing=4, row_spacing=4)
        self.grid.set_column_homogeneous(True)
        box.pack_start(self.grid, False, False, 0)
        footer = Gtk.Box(spacing=6)
        self.month_selector = Gtk.ComboBoxText()
        for month in range(1, 13):
            self.month_selector.append(str(month), calendar.month_name[month])
        self.month_selector.connect("changed", self.jump)
        footer.pack_start(self.month_selector, True, True, 0)
        self.year_selector = Gtk.SpinButton.new_with_range(1, 9999, 1)
        self.year_selector.set_numeric(True)
        self.year_selector.set_width_chars(4)
        self.year_selector.set_alignment(0.5)
        self.year_selector.connect("value-changed", self.jump)
        footer.pack_start(self.year_selector, False, False, 0)
        today_button = self.button("Today", "Return to today", self.go_today)
        today_button.get_style_context().add_class('today-control')
        footer.pack_end(today_button, False, False, 0)
        box.pack_start(footer, False, False, 0)
        legend = Gtk.Box(spacing=10)
        legend.set_halign(Gtk.Align.CENTER)
        for kind in ("regular", "special", "working"):
            label = Gtk.Label(label="● " + kind.title())
            label.get_style_context().add_class("muted")
            label.get_style_context().add_class(kind)
            legend.pack_start(label, False, False, 0)
        box.pack_start(legend, False, False, 0)
        self.panel_events.set_size_request(350, -1)
        self.render()
        return self.panel_events

    def render(self):
        self.close_date_info()
        self.day_buttons = {}
        self.updating = True
        self.heading.set_text(f"{calendar.month_name[self.month]} {self.year}")
        self.month_selector.set_active_id(str(self.month))
        self.year_selector.set_value(self.year)
        self.updating = False
        for child in self.grid.get_children():
            self.grid.remove(child)
        for column, weekday in enumerate(("Su", "Mo", "Tu", "We", "Th", "Fr", "Sa")):
            label = Gtk.Label(label=weekday)
            label.get_style_context().add_class("weekday")
            self.grid.attach(label, column, 0, 1, 1)
        holidays = holidays_for_year(self.year)
        today = date.today()
        for week, days in enumerate(calendar.Calendar(firstweekday=6).monthdayscalendar(self.year, self.month), 1):
            for column, day in enumerate(days):
                if not day:
                    continue
                value = date(self.year, self.month, day)
                info = holidays.get((self.month, day))
                button = self.button(str(day), value.strftime("%A, %B %d, %Y"),
                                     lambda button, value=value: self.select_day(value, button))
                self.day_buttons[value] = button
                context = button.get_style_context()
                context.add_class("day")
                if info:
                    context.add_class(info[1])
                if value == today:
                    context.add_class("today")
                if value == self.selected:
                    context.add_class("selected")
                self.grid.attach(button, column, week, 1, 1)
        self.grid.show_all()
        if hasattr(self, "fixed"):
            _popup.GLib.idle_add(self.position_panel)

    def select_day(self, value, button):
        toggled = value == self.selected and self.date_popover is not None
        self.close_date_info()
        previous = self.day_buttons.get(self.selected)
        if previous is not None:
            previous.get_style_context().remove_class('selected')
        self.selected = value
        button.get_style_context().add_class('selected')
        if toggled:
            return
        text = value.strftime('%A, %B %d, %Y')
        info = holidays_for_year(value.year).get((value.month, value.day))
        if info:
            text += f'\n{info[0]}\n{KIND_LABELS[info[1]]}'
        popover = Gtk.Popover.new(button)
        popover.get_style_context().add_class('calendar-tooltip')
        popover.set_position(Gtk.PositionType.BOTTOM)
        label = Gtk.Label(label=text, xalign=0)
        label.set_line_wrap(True)
        label.set_line_wrap_mode(_popup.Pango.WrapMode.WORD_CHAR)
        label.set_max_width_chars(32)
        for side in ('start', 'end', 'top', 'bottom'):
            getattr(label, 'set_margin_' + side)(10)
        popover.add(label)
        popover.connect('closed', self.date_info_closed)
        self.date_popover = popover
        popover.show_all()
        popover.popup()

    def date_info_closed(self, popover):
        if self.date_popover is popover:
            self.date_popover = None
        popover.destroy()

    def close_date_info(self):
        popover, self.date_popover = self.date_popover, None
        if popover is not None:
            popover.destroy()

    def finish(self, result=None):
        self.close_date_info()
        return super().finish(result)

    def change_month(self, offset):
        self.year, self.month = shift_month(self.year, self.month, offset)
        self.selected = date(self.year, self.month, 1)
        self.render()

    def jump(self, *_args):
        if not self.updating:
            self.month = int(self.month_selector.get_active_id())
            self.year = self.year_selector.get_value_as_int()
            self.selected = date(self.year, self.month, 1)
            self.render()

    def go_today(self, *_args):
        self.selected = date.today()
        self.year, self.month = self.selected.year, self.selected.month
        self.render()

    def panel_position(self, output_width, output_height):
        width = self.panel_events.get_preferred_width()[1]
        height = self.panel_events.get_preferred_height()[1]
        x = max(0, (output_width - width) // 2)
        y = max(0, min(self.settings.getint("y-margin", 40), output_height - height))
        return x, y

    def focus_control(self):
        self.previous.grab_focus()

    def keypress(self, _window, event):
        if event.keyval == Gdk.KEY_Escape:
            return self.finish()
        # Let the month/year controls keep their own keyboard navigation.
        focus = _window.get_focus()
        if isinstance(focus, (Gtk.Entry, Gtk.ComboBox)):
            return False
        if event.keyval in (Gdk.KEY_Left, Gdk.KEY_Right):
            self.change_month(-1 if event.keyval == Gdk.KEY_Left else 1)
            return True
        return False

    def run(self):
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), self.calendar_css,
                                                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1)
        super().run()
        return 0


def main():
    args = arguments()
    ready, _argv = Gtk.init_check(None)
    if not ready or not GtkLayerShell.is_supported():
        print("Calendar menu: a Wayland display with layer-shell support is required", file=sys.stderr)
        return 2
    return CalendarPopup(args).run()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        traceback.print_exc()
        sys.exit(2)
