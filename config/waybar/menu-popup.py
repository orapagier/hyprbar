"""Common controls for the notification and Bluetooth dropdowns."""
import importlib.util
from pathlib import Path

_spec = importlib.util.spec_from_file_location('waybar_popup', Path(__file__).with_name('wifi-popup.py'))
_popup = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_popup)
Gdk, GLib, Gtk, GtkLayerShell, Pango = _popup.Gdk, _popup.GLib, _popup.Gtk, _popup.GtkLayerShell, _popup.Pango
arguments = _popup.arguments


def list_height(row_heights, spacing, available):
    """Fit up to five complete rows, limited by the output's usable height."""
    height = 0
    for row_height in row_heights[:5]:
        next_height = height + (spacing if height else 0) + row_height
        if next_height > available:
            break
        height = next_height
    if not height and row_heights:
        height = min(row_heights[0], available)
    return min(available, max(80, height))


class MenuPopup(_popup.Popup):
    def __init__(self, args):
        args.lines = 0
        super().__init__(args, [])
        self.controls_css = Gtk.CssProvider()
        self.controls_css.load_from_data(b'''
#wifi-panel button.danger label { color: #f38ba8; }
#wifi-panel button.connected label { color: #a6e3a1; }
#wifi-panel .card { background: transparent; border-radius: 8px; }
#wifi-panel button.device-row { background: transparent; border: 1px solid transparent; padding: 0; }
#wifi-panel button.device-row:hover { background: rgba(49,50,68,0.8); }
#wifi-panel button.device-row:focus { border-color: #b4befe; }
#wifi-panel expander.notification-row { border-radius: 8px; }
#wifi-panel expander.notification-row:hover { background: rgba(49,50,68,0.8); }
#wifi-panel expander.notification-row title { padding: 8px 6px; }
#wifi-panel expander.notification-row arrow { color: #7f849c; min-width: 10px; min-height: 10px; }
#wifi-panel .card-title { font-weight: 600; }
#wifi-panel .caption { color: #7f849c; font-size: 8pt; }
#wifi-panel .body { color: #bac2de; font-size: 9pt; }
''')

    def make_panel(self, title):
        self.panel_events = Gtk.EventBox()
        self.panel_events.set_name('wifi-panel')
        self.panel_events.set_visible_window(True)
        self.panel_events.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        self.panel_events.connect('button-press-event', self.inside_click)
        box = self.panel_content()
        header = Gtk.Box(spacing=8)
        label = Gtk.Label(label=title, xalign=0)
        label.set_ellipsize(Pango.EllipsizeMode.END)
        label.set_width_chars(1)
        label.get_style_context().add_class('popup-title')
        header.pack_start(label, True, True, 0)
        box.pack_start(header, False, False, 0)
        self.size_panel()
        return box, header

    @staticmethod
    def button(text, callback, tooltip=None):
        button = Gtk.Button(label=text)
        button.connect('clicked', callback)
        if tooltip:
            button.set_tooltip_text(tooltip)
        return button

    def label(self, text, style=None):
        label = Gtk.Label(label=text, xalign=0)
        label.set_line_wrap(True)
        label.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR)
        label.set_max_width_chars(max(12, self.args.width - 6))
        if style:
            label.get_style_context().add_class(style)
        return label

    def compact_label(self, text, style=None):
        label = self.label(text, style)
        label.set_line_wrap(False)
        label.set_ellipsize(Pango.EllipsizeMode.END)
        label.set_width_chars(1)
        label.set_hexpand(True)
        label.set_tooltip_text(text)
        return label

    def scrollable(self, box):
        self.scroll = Gtk.ScrolledWindow()
        self.scroll.set_can_focus(True)
        self.scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.scroll.set_min_content_height(80)
        self.scroll.set_max_content_height(420)
        self.scroll.set_propagate_natural_height(True)
        self.scroll.set_overlay_scrolling(False)
        self.content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.scroll.add(self.content)
        box.pack_start(self.scroll, False, False, 0)
        self.list_height = None

    def position_panel(self, *_args):
        if hasattr(self, 'scroll'):
            panel_width = max(self.panel_events.get_size_request()[0],
                              self.panel_events.get_allocated_width())
            scrollbar_width = self.scroll.get_vscrollbar().get_preferred_width()[1]
            content_width = max(1, panel_width - 2 * self.hpad - scrollbar_width - 2)
            panel_height = self.panel_events.get_preferred_height_for_width(panel_width)[1]
            scroll_height = self.scroll.get_preferred_height_for_width(content_width)[1]
            chrome = max(0, panel_height - scroll_height)
            available = max(1, self.fixed.get_allocated_height()
                            - self.settings.getint('y-margin', 40) - 16 - chrome)
            rows = [child.get_preferred_height_for_width(content_width)[1]
                    for child in self.content.get_children() if child.get_visible()]
            height = list_height(rows, self.content.get_spacing(), available)
            if height != self.list_height:
                self.list_height = height
                # Gtk.Fixed can allocate the minimum instead of the scroller's
                # natural height. Request the measured viewport explicitly.
                self.scroll.set_max_content_height(-1)
                self.scroll.set_min_content_height(height)
                self.scroll.set_max_content_height(height)
                self.scroll.set_size_request(-1, height)
        return super().position_panel(*_args)

    @staticmethod
    def inset(box, amount=12):
        for side in ('start', 'end', 'top', 'bottom'):
            getattr(box, 'set_margin_' + side)(amount)

    def keypress(self, _window, event):
        return self.finish() if event.keyval == Gdk.KEY_Escape else False

    def focus_control(self):
        self.scroll.grab_focus()

    def run(self):
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), self.controls_css,
                                                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1)
        super().run()
        return 0
