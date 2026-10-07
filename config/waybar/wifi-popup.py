#!/usr/bin/env python3
"""A scrollable Wayland picker with outside clicks handled in its own surface."""

import argparse
import configparser
import signal
import sys
import traceback

import cairo
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell, Pango


def arguments(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--theme", required=True)
    parser.add_argument("--width", type=int, default=30)
    parser.add_argument("--output")
    parser.add_argument("--output-x", type=int)
    parser.add_argument("--output-y", type=int)
    parser.add_argument("--lines", type=int, default=6)
    parser.add_argument("--index", action="store_true")
    parser.add_argument("--only-match", action="store_true")
    parser.add_argument("--prompt", default="")
    parser.add_argument("--placeholder", default="Wi-Fi")
    parser.add_argument("--mesg", default="")
    parser.add_argument("--password", nargs="?", const="•")
    return parser.parse_args(argv)


def rgba(value):
    value = value.strip()
    red, green, blue, alpha = (int(value[i:i + 2], 16) for i in (0, 2, 4, 6))
    return f"rgba({red}, {green}, {blue}, {alpha / 255:.3f})"


class Popup:
    def __init__(self, args, items):
        self.args = args
        self.items = items
        self.windows = []
        self.rows = []
        self.result = None
        self.closed = False
        self.theme = configparser.ConfigParser()
        self.theme.read(args.theme)
        self.settings = self.theme["main"]
        self.row_height = self.settings.getint("line-height", 24)
        self.css = Gtk.CssProvider()
        colors, border = self.theme["colors"], self.theme["border"]
        family, _, font_options = self.settings.get("font", "monospace:size=10").partition(":")
        font_size = float(font_options.removeprefix("size=") or "10")
        hpad = self.settings.getint("horizontal-pad", 14)
        vpad = self.settings.getint("vertical-pad", 10)
        gap = self.settings.getint("inner-pad", 6)
        self.css.load_from_data(f'''
window, #wifi-outside {{ background: transparent; }}
#wifi-panel {{
  background: {rgba(colors['background'])}; color: {rgba(colors['text'])};
  background-image: linear-gradient(to bottom, rgba(255,255,255,0.08), rgba(255,255,255,0));
  border: {border.getint('width', 1)}px solid {rgba(colors['border'])};
  border-radius: {border.getint('radius', 12)}px;
  box-shadow: inset 0 1px rgba(255,255,255,0.10);
  padding: 0;
}}
#wifi-panel * {{ font-family: "{family}"; font-size: {font_size}pt; }}
#wifi-panel label, #wifi-panel list, #wifi-panel row {{ color: {rgba(colors['text'])}; }}
#wifi-panel entry {{
  background: transparent; background-image: none; color: {rgba(colors['input'])};
  border: none; box-shadow: none; min-height: 24px; padding: 0; margin: 0;
  caret-color: {rgba(colors['prompt'])};
}}
#wifi-panel entry:focus {{ border: none; box-shadow: none; }}
#wifi-panel entry placeholder {{ color: {rgba(colors['placeholder'])}; }}
#wifi-panel .popup-title {{ font-size: 11pt; font-weight: 600; }}
#wifi-panel button {{ background: rgba(255,255,255,0.045); background-image: none; border: 1px solid rgba(255,255,255,0.12); border-radius: 8px; box-shadow: none; padding: 6px 8px; min-height: 20px; }}
#wifi-panel button:hover {{ background: {rgba(colors['selection'])}; }}
#wifi-panel button:focus {{ border-color: {rgba(colors['prompt'])}; outline: none; }}
#wifi-panel .input-field {{ background: rgba(255,255,255,0.045); border: 1px solid rgba(255,255,255,0.12); border-radius: 8px; }}
#wifi-panel .input-field:focus-within {{ border-color: {rgba(colors['prompt'])}; }}
#wifi-panel list, #wifi-panel scrolledwindow, #wifi-panel viewport {{ background: transparent; border: none; }}
#wifi-panel row {{ padding: 0; margin: 0; border: none; border-radius: {border.getint('selection-radius', 6)}px; }}
#wifi-panel row:selected, #wifi-panel row:hover {{ background: {rgba(colors['selection'])}; color: {rgba(colors['selection-text'])}; }}
#wifi-panel row:selected label, #wifi-panel row:hover label {{ color: {rgba(colors['selection-text'])}; }}
#wifi-panel scrollbar {{ background: transparent; border: none; min-width: 4px; }}
#wifi-panel scrollbar slider {{ background: {rgba(colors['placeholder'])}; border: none; border-radius: 3px; min-width: 4px; min-height: 20px; margin-left: 3px; }}
#wifi-panel .muted {{ color: {rgba(colors['placeholder'])}; font-size: 8pt; }}
#wifi-panel .prompt {{ color: {rgba(colors['prompt'])}; }}
#wifi-panel .network-icon {{ color: {rgba(colors['prompt'])}; font-size: 13pt; }}
#wifi-panel .network-badge {{ color: {rgba(colors['placeholder'])}; }}
#wifi-panel .network-badge.connected {{ color: #a6e3a1; }}
'''.encode())
        self.gap = gap
        self.hpad = hpad
        self.vpad = vpad

    def panel_content(self, spacing=None):
        # EventBox has no CSS layout gadget: padding can paint without insetting
        # its child. Widget margins provide real space on every panel edge.
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL,
                      spacing=self.gap if spacing is None else spacing)
        box.set_margin_start(self.hpad)
        box.set_margin_end(self.hpad)
        box.set_margin_top(self.vpad)
        box.set_margin_bottom(self.vpad)
        self.panel_events.add(box)
        return box

    def size_panel(self):
        """Use the same monitor-aware, font-measured width for every menu."""
        font = Pango.FontDescription(self.settings.get('font', 'monospace:size=10').replace(':size=', ' '))
        measure = self.panel_events.create_pango_layout('M')
        measure.set_font_description(font)
        width = self.args.width * measure.get_pixel_size()[0] + 2 * self.hpad + 2
        self.panel_events.set_size_request(width, -1)
        return width

    def finish(self, result=None):
        if not self.closed:
            self.closed = True
            self.result = result
            Gtk.main_quit()
        return True

    def outside_click(self, *_args):
        return self.finish()

    @staticmethod
    def inside_click(*_args):
        # Consume bubbling clicks inside the panel before they reach the backdrop.
        return True

    @staticmethod
    def set_input_region(widget, allocation):
        native = widget.get_window()
        if native is not None:
            region = cairo.Region(cairo.RectangleInt(0, 0, allocation.width, allocation.height))
            native.input_shape_combine_region(region, 0, 0)

    def accept(self, *_args):
        if self.args.lines == 0:
            return self.finish(self.entry.get_text())
        row = self.listbox.get_selected_row()
        if row is not None and row.get_child_visible():
            return self.choose(row.original_index)
        return True

    def choose(self, index):
        value = str(index) if self.args.index else self.items[index]
        return self.finish(value)

    def visible_rows(self):
        return self.rows

    def update_list(self, *_args):
        visible = self.visible_rows()
        self.listbox.select_row(visible[0] if visible else None)
        # All rows remain in the list. Only the viewport height is bounded.
        count = max(1, min(self.args.lines, len(visible)))
        height = count * self.row_height
        self.scroll.set_max_content_height(-1)
        self.scroll.set_min_content_height(height)
        self.scroll.set_max_content_height(height)
        self.scroll.set_propagate_natural_height(True)
        self.hint.set_visible(len(visible) > self.args.lines)
        GLib.idle_add(self.position_panel)

    def keypress(self, _window, event):
        if event.keyval == Gdk.KEY_Escape:
            return self.finish()
        if self.args.lines and event.keyval in (Gdk.KEY_Return, Gdk.KEY_KP_Enter):
            return self.accept()
        if self.args.lines and event.keyval in (Gdk.KEY_Down, Gdk.KEY_Up, Gdk.KEY_Page_Down, Gdk.KEY_Page_Up):
            visible = self.visible_rows()
            if not visible:
                return True
            selected = self.listbox.get_selected_row()
            index = visible.index(selected) if selected in visible else 0
            step = self.args.lines if event.keyval in (Gdk.KEY_Page_Down, Gdk.KEY_Page_Up) else 1
            if event.keyval in (Gdk.KEY_Up, Gdk.KEY_Page_Up):
                step = -step
            row = visible[max(0, min(len(visible) - 1, index + step))]
            self.listbox.select_row(row)
            GLib.idle_add(self.reveal, row)
            return True
        return False

    def reveal(self, row):
        adjustment = self.scroll.get_vadjustment()
        allocation = row.get_allocation()
        top, bottom = allocation.y, allocation.y + allocation.height
        if top < adjustment.get_value():
            adjustment.set_value(top)
        elif bottom > adjustment.get_value() + adjustment.get_page_size():
            adjustment.set_value(bottom - adjustment.get_page_size())
        return False

    def panel(self):
        # A separate EventBox inside the SAME layer surface stops inside clicks
        # bubbling into the full-screen outside-click EventBox.
        self.panel_events = Gtk.EventBox()
        self.panel_events.set_name("wifi-panel")
        self.panel_events.set_visible_window(True)
        self.panel_events.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        self.panel_events.connect("button-press-event", self.inside_click)
        box = self.panel_content()
        title = Gtk.Label(label=self.args.placeholder if self.args.lines else "Wi-Fi", xalign=0)
        title.get_style_context().add_class("popup-title")
        box.pack_start(title, False, False, 0)
        if self.args.mesg:
            label = Gtk.Label(label=self.args.mesg, xalign=0)
            label.set_ellipsize(Pango.EllipsizeMode.END)
            box.pack_start(label, False, False, 0)
        if not self.args.lines:
            input_frame = Gtk.Frame()
            input_frame.set_shadow_type(Gtk.ShadowType.NONE)
            input_frame.get_style_context().add_class("input-field")
            input_box = Gtk.Box(spacing=8)
            input_box.set_margin_start(10)
            input_box.set_margin_end(10)
            input_box.set_margin_top(6)
            input_box.set_margin_bottom(6)
            input_frame.add(input_box)
            if self.args.prompt:
                icon = Gtk.Label(label=self.args.prompt.strip())
                icon.get_style_context().add_class("prompt")
                input_box.pack_start(icon, False, False, 0)
            self.entry = Gtk.Entry()
            self.entry.set_width_chars(1)
            self.entry.set_placeholder_text(self.args.placeholder)
            if self.args.password is not None:
                self.entry.set_visibility(False)
                self.entry.set_invisible_char(self.args.password[0] if self.args.password else '•')
            self.entry.connect("activate", self.accept)
            input_box.pack_start(self.entry, True, True, 0)
            box.pack_start(input_frame, False, False, 0)
        if self.args.lines:
            self.listbox = Gtk.ListBox()
            self.listbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
            self.listbox.set_activate_on_single_click(True)
            self.listbox.connect("row-activated", lambda _list, row: self.choose(row.original_index))
            for index, item in enumerate(self.items):
                row = Gtk.ListBoxRow()
                row.original_index = index
                row.set_size_request(-1, self.row_height)
                content = Gtk.Box(spacing=10)
                content.set_margin_start(10)
                content.set_margin_end(10)
                content.set_margin_top(8)
                content.set_margin_bottom(8)
                icon, separator, name = item.partition(" ")
                if separator:
                    glyph = Gtk.Label(label=icon)
                    glyph.set_size_request(20, -1)
                    glyph.get_style_context().add_class("network-icon")
                    content.pack_start(glyph, False, False, 0)
                else:
                    name = item
                name = name.strip()
                badge = name[-1:] if name.endswith(("󰌾", "󰄬")) else ""
                if badge:
                    name = name[:-1].rstrip()
                label = Gtk.Label(label=name, xalign=0)
                label.set_ellipsize(Pango.EllipsizeMode.END)
                label.set_max_width_chars(self.args.width)
                content.pack_start(label, True, True, 0)
                if badge:
                    status = Gtk.Label(label=badge)
                    status.get_style_context().add_class("network-badge")
                    if badge == "󰄬":
                        status.get_style_context().add_class("connected")
                    content.pack_end(status, False, False, 0)
                row.add(content)
                self.rows.append(row)
                self.listbox.add(row)
            self.scroll = Gtk.ScrolledWindow()
            self.scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            self.scroll.set_overlay_scrolling(False)
            self.scroll.add(self.listbox)
            box.pack_start(self.scroll, False, False, 0)
            self.hint = Gtk.Label(label="Scroll for more", xalign=1)
            self.hint.get_style_context().add_class("muted")
            self.hint.set_no_show_all(True)
            box.pack_start(self.hint, False, False, 0)
        self.size_panel()
        return self.panel_events

    def position_panel(self, *_args):
        allocation = self.fixed.get_allocation()
        width = self.panel_events.get_preferred_width()[1]
        height = self.panel_events.get_preferred_height()[1]
        x = max(0, allocation.width - width - self.settings.getint("x-margin", 12))
        y = max(0, min(self.settings.getint("y-margin", 40), allocation.height - height))
        self.fixed.move(self.panel_events, x, y)
        return False

    def surface(self, monitor, with_panel):
        window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        window.set_decorated(False)
        window.set_app_paintable(True)
        visual = window.get_screen().get_rgba_visual()
        if visual is not None:
            window.set_visual(visual)
        GtkLayerShell.init_for_window(window)
        GtkLayerShell.set_namespace(window, self.settings.get("namespace", "wifi-menu"))
        GtkLayerShell.set_monitor(window, monitor)
        GtkLayerShell.set_layer(window, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_mode(window, GtkLayerShell.KeyboardMode.EXCLUSIVE if with_panel else GtkLayerShell.KeyboardMode.NONE)
        GtkLayerShell.set_exclusive_zone(window, -1)
        for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM, GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT):
            GtkLayerShell.set_anchor(window, edge, True)
        outside = Gtk.EventBox()
        outside.set_name("wifi-outside")
        outside.set_visible_window(True)
        outside.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        outside.connect("button-press-event", self.outside_click)
        outside.connect("size-allocate", self.set_input_region)
        window.connect("size-allocate", self.set_input_region)
        window.add(outside)
        if with_panel:
            self.fixed = Gtk.Fixed()
            outside.add(self.fixed)
            self.fixed.put(self.panel(), 0, 0)
            self.fixed.connect("size-allocate", self.position_panel)
            window.connect("key-press-event", self.keypress)
        self.windows.append(window)
        window.show_all()
        # Explicitly keep the entire surface clickable, including clear pixels.
        self.set_input_region(window, window.get_allocation())
        self.set_input_region(outside, outside.get_allocation())

    def run(self):
        display = Gdk.Display.get_default()
        monitors = [display.get_monitor(i) for i in range(display.get_n_monitors())]
        # GDK exposes display geometry, rather than connector names. Use the
        # logical output position supplied by the shell's Hyprland layout query.
        target = next((m for m in monitors if self.args.output_x is not None
                       and m.get_geometry().x == self.args.output_x
                       and m.get_geometry().y == self.args.output_y), None)
        if target is None:
            pointer = display.get_default_seat().get_pointer()
            _screen, x, y = pointer.get_position()
            target = display.get_monitor_at_point(x, y)
        if target is None:
            target = display.get_primary_monitor() or monitors[0]
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), self.css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        try:
            for monitor in monitors:
                if monitor != target:
                    self.surface(monitor, False)
            self.surface(target, True)
            if self.args.lines:
                self.update_list()
            self.focus_control()
            for signum in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
                GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signum, self.finish)
            Gtk.main()
        finally:
            for window in self.windows:
                window.destroy()
        if self.result is None:
            return 1
        print(self.result)
        return 0

    def focus_control(self):
        if self.args.lines:
            row = self.listbox.get_selected_row()
            (row if row is not None else self.listbox).grab_focus()
        else:
            self.entry.grab_focus()


def main():
    args = arguments()
    items = sys.stdin.read().splitlines()
    ready, _argv = Gtk.init_check(None)
    if not ready or not GtkLayerShell.is_supported():
        print("Wi-Fi menu: a Wayland display with layer-shell support is required", file=sys.stderr)
        return 2
    return Popup(args, items).run()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        traceback.print_exc()
        sys.exit(2)
