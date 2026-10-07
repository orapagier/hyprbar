#!/usr/bin/env python3
"""A small audio control panel using the existing Wayland popup surface."""

from concurrent.futures import ThreadPoolExecutor
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import traceback

# Keep Wi-Fi's existing entry point while sharing its tested layer surface.
_spec = importlib.util.spec_from_file_location("waybar_popup", Path(__file__).with_name("wifi-popup.py"))
_popup = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_popup)
Gdk, GLib, Gtk, GtkLayerShell, Pango = (_popup.Gdk, _popup.GLib, _popup.Gtk, _popup.GtkLayerShell, _popup.Pango)
Popup, arguments, rgba = _popup.Popup, _popup.arguments, _popup.rgba


class AudioBackend:
    @staticmethod
    def command(*args):
        result = subprocess.run(["pactl", *args], capture_output=True, text=True,
                                check=True, timeout=3)
        return result.stdout.strip()

    @staticmethod
    def volume(device):
        channels = device.get("volume", {}).values()
        levels = []
        for channel in channels:
            if "value_percent" in channel:
                levels.append(float(channel["value_percent"].strip().removesuffix("%")))
            elif "value" in channel:
                levels.append(float(channel["value"]) * 100 / 65536)
        return round(sum(levels) / len(levels)) if levels else 0

    @staticmethod
    def description(device):
        props = device.get("properties", {})
        return device.get("description") or props.get("device.description") or device["name"]

    def snapshot(self):
        sinks = json.loads(self.command("--format=json", "list", "sinks"))
        sources = json.loads(self.command("--format=json", "list", "sources"))
        default_sink = self.command("get-default-sink") if sinks else ""
        default_source = self.command("get-default-source") if sources else ""
        sink = next((item for item in sinks if item["name"] == default_sink), sinks[0] if sinks else None)
        microphones = [item for item in sources if not item["name"].endswith(".monitor")]
        source = next((item for item in sources if item["name"] == default_source),
                      microphones[0] if microphones else None)
        return {"sink": sink, "source": source, "sinks": sinks}

    def set_volume(self, kind, name, value):
        self.command(f"set-{kind}-volume", name, f"{max(0, min(100, round(value)))}%")

    def toggle_mute(self, kind, name):
        self.command(f"set-{kind}-mute", name, "toggle")

    def set_output(self, name):
        self.command("set-default-sink", name)
        # Move existing playback too, so the device selector takes effect now.
        streams = json.loads(self.command("--format=json", "list", "sink-inputs"))
        for stream in streams:
            try:
                self.command("move-sink-input", str(stream["index"]), name)
            except subprocess.CalledProcessError:
                pass  # A playback stream can end while the selector is open.


class AudioPopup(Popup):
    def __init__(self, args):
        args.lines = 0
        super().__init__(args, [])
        self.backend = AudioBackend()
        self.executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="audio-menu")
        self.snapshot_pending = False
        self.updating = False
        self.devices = {}
        self.output_options = []
        self.controls = {}
        self.pending_volume = {}
        self.inflight_volume = set()
        self.volume_timers = {}
        self.dragging = set()
        self.poll_timer = None
        self.first_snapshot = True
        accent = rgba(self.theme["colors"]["prompt"])
        text = rgba(self.theme["colors"]["text"])
        dim = rgba(self.theme["colors"]["placeholder"])
        self.audio_css = Gtk.CssProvider()
        self.audio_css.load_from_data(f'''
#wifi-panel .audio-title {{ font-weight: 600; font-size: 11pt; }}
#wifi-panel .audio-percent {{ color: {accent}; }}
#wifi-panel .audio-caption {{ color: {dim}; font-size: 8pt; }}
#wifi-panel button.mute-toggle {{ background: rgba(49,50,68,0.55); background-image: none; border: none; box-shadow: none; border-radius: 8px; padding: 4px; min-height: 26px; min-width: 26px; }}
#wifi-panel button.mute-toggle label {{ color: {accent}; font-size: 16pt; }}
#wifi-panel button.mute-toggle:hover {{ background: rgba(69,71,90,0.8); }}
#wifi-panel button.mute-toggle.muted-audio label {{ color: #f38ba8; }}
#wifi-panel scale {{ padding: 9px 6px; min-height: 14px; }}
#wifi-panel scale trough {{ background: #313244; border: none; border-radius: 4px; min-height: 4px; }}
#wifi-panel scale highlight {{ background: {accent}; border: none; border-radius: 4px; min-height: 4px; }}
#wifi-panel scale slider {{ background: {text}; background-image: none; border: none; box-shadow: none; border-radius: 7px; min-width: 12px; min-height: 12px; margin: -4px 0; }}
#wifi-panel #mic-slider highlight {{ background: #89b4fa; }}
#wifi-panel combobox button {{ background: rgba(49,50,68,0.45); background-image: none; color: {text}; border: 1px solid rgba(205,214,244,0.10); border-radius: 8px; padding: 8px 10px; box-shadow: none; min-height: 20px; }}
#wifi-panel combobox button:hover {{ background: rgba(69,71,90,0.65); }}
#wifi-panel combobox arrow {{ color: {dim}; min-width: 10px; min-height: 10px; }}
menu {{ background: #181825; color: {text}; border: 1px solid #313244; border-radius: 8px; padding: 6px; }}
menu menuitem {{ color: {text}; padding: 8px 10px; border-radius: 6px; }}
menu menuitem:hover {{ background: #313244; color: {accent}; }}
'''.encode())

    def background(self, action, callback=None):
        if self.closed:
            return
        future = self.executor.submit(action)
        def completed(done):
            if not self.closed:
                GLib.idle_add(self.deliver, done, callback)
        future.add_done_callback(completed)

    def deliver(self, future, callback):
        if self.closed:
            return False
        try:
            result = future.result()
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            self.snapshot_pending = False
            self.inflight_volume.clear()
            self.status.set_text("Audio is unavailable")
            self.status.show()
            print(f"Audio menu: {error}", file=sys.stderr)
        else:
            self.status.hide()
            if callback is not None:
                callback(result)
        return False

    def refresh(self, *_args):
        if self.closed:
            return False
        if not self.snapshot_pending:
            self.snapshot_pending = True
            self.background(self.backend.snapshot, self.apply_snapshot)
        return True

    def apply_snapshot(self, state):
        self.snapshot_pending = False
        self.updating = True
        try:
            for kind in ("sink", "source"):
                device = state[kind]
                self.devices[kind] = device
                scale, percent, button = self.controls[kind]
                scale.set_sensitive(device is not None)
                button.set_sensitive(device is not None)
                if device is None:
                    percent.set_text("—")
                    continue
                muted = bool(device.get("mute"))
                if kind not in self.pending_volume and kind not in self.inflight_volume and kind not in self.dragging:
                    volume = self.backend.volume(device)
                    scale.set_value(min(100, volume))
                    percent.set_text(f"{volume}%")
                icon = ('󰖁' if muted else '󰕾') if kind == 'sink' else ('󰍭' if muted else '󰍬')
                button.set_label(icon)
                context = button.get_style_context()
                (context.add_class if muted else context.remove_class)("muted-audio")
                button.set_tooltip_text(("Unmute" if muted else "Mute") + (" sound" if kind == "sink" else " microphone"))
            options = [(item["name"], self.backend.description(item)) for item in state["sinks"]]
            if options != self.output_options:
                self.output.remove_all()
                for name, description in options:
                    self.output.append(name, description)
                self.output_options = options
            sink = state["sink"]
            self.output.set_sensitive(sink is not None)
            if sink is not None:
                self.output.set_active_id(sink["name"])
                self.output.set_tooltip_text(self.backend.description(sink))
            source = state["source"]
            self.controls["source"][0].set_tooltip_text(self.backend.description(source) if source else "No microphone")
        finally:
            self.updating = False
        if self.first_snapshot:
            self.first_snapshot = False
            self.focus_control()

    def change_volume(self, scale, kind):
        if self.updating or kind not in self.devices or self.devices[kind] is None:
            return
        value = round(scale.get_value())
        self.controls[kind][1].set_text(f"{value}%")
        self.pending_volume[kind] = (self.devices[kind]["name"], value)
        if kind in self.volume_timers:
            GLib.source_remove(self.volume_timers[kind])
        self.volume_timers[kind] = GLib.timeout_add(80, self.commit_volume, kind)

    def commit_volume(self, kind):
        self.volume_timers.pop(kind, None)
        change = self.pending_volume.pop(kind, None)
        if change is not None:
            name, value = change
            self.inflight_volume.add(kind)
            def applied(_result):
                self.inflight_volume.discard(kind)
                self.refresh()
            self.background(lambda: self.backend.set_volume(kind, name, value), applied)
        return False

    def toggle_mute(self, _button, kind):
        device = self.devices.get(kind)
        if device is not None:
            name = device["name"]
            self.background(lambda: self.backend.toggle_mute(kind, name), self.refresh)

    def change_output(self, combo):
        name = combo.get_active_id()
        if not self.updating and name is not None:
            self.background(lambda: self.backend.set_output(name), self.refresh)

    def drag(self, _widget, _event, kind, active):
        (self.dragging.add if active else self.dragging.discard)(kind)
        return False

    def volume_section(self, kind, title):
        section = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        header = Gtk.Box(spacing=10)
        button = Gtk.Button(label="󰕾" if kind == "sink" else "󰍬")
        button.get_style_context().add_class("mute-toggle")
        button.set_sensitive(False)
        button.connect("clicked", self.toggle_mute, kind)
        header.pack_start(button, False, False, 0)
        label = Gtk.Label(label=title, xalign=0)
        label.get_style_context().add_class("audio-title")
        header.pack_start(label, True, True, 0)
        percent = Gtk.Label(label="—", xalign=1)
        percent.get_style_context().add_class("audio-percent")
        header.pack_end(percent, False, False, 0)
        section.pack_start(header, False, False, 0)
        scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        scale.set_name("speaker-slider" if kind == "sink" else "mic-slider")
        scale.set_draw_value(False)
        scale.set_sensitive(False)
        scale.connect("value-changed", self.change_volume, kind)
        scale.connect("button-press-event", self.drag, kind, True)
        scale.connect("button-release-event", self.drag, kind, False)
        self.controls[kind] = (scale, percent, button)
        section.pack_start(scale, False, False, 0)
        return section

    def panel(self):
        self.panel_events = Gtk.EventBox()
        self.panel_events.set_name("wifi-panel")
        self.panel_events.set_visible_window(True)
        self.panel_events.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        self.panel_events.connect("button-press-event", self.inside_click)
        box = self.panel_content()
        box.pack_start(self.volume_section("sink", "Sound"), False, False, 0)
        output_section = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        caption = Gtk.Label(label="OUTPUT", xalign=0)
        caption.get_style_context().add_class("audio-caption")
        output_section.pack_start(caption, False, False, 0)
        self.output = Gtk.ComboBoxText()
        self.output.set_sensitive(False)
        self.output.set_hexpand(True)
        for cell in self.output.get_cells():
            if cell.find_property("ellipsize") is not None:
                cell.set_property("ellipsize", Pango.EllipsizeMode.END)
                cell.set_property("max-width-chars", self.args.width - 4)
        self.output.connect("changed", self.change_output)
        output_section.pack_start(self.output, False, False, 0)
        box.pack_start(output_section, False, False, 0)
        mic = self.volume_section("source", "Microphone")
        mic.set_margin_top(4)
        box.pack_start(mic, False, False, 0)
        self.status = Gtk.Label(label="Connecting…", xalign=0)
        self.status.get_style_context().add_class("audio-caption")
        self.status.set_no_show_all(True)
        box.pack_start(self.status, False, False, 0)
        self.size_panel()
        GLib.idle_add(self.refresh)
        self.poll_timer = GLib.timeout_add(1500, self.refresh)
        return self.panel_events

    def focus_control(self):
        self.controls["sink"][0].grab_focus()

    def keypress(self, _window, event):
        return self.finish() if event.keyval == Gdk.KEY_Escape else False

    def finish(self, result=None):
        if not self.closed:
            if self.poll_timer is not None:
                GLib.source_remove(self.poll_timer)
                self.poll_timer = None
            for kind, timer in list(self.volume_timers.items()):
                GLib.source_remove(timer)
                self.commit_volume(kind)
        return super().finish(result)

    def run(self):
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), self.audio_css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1)
        try:
            super().run()
            return 0
        finally:
            self.executor.shutdown(wait=False)


def main():
    args = arguments()
    ready, _argv = Gtk.init_check(None)
    if not ready or not GtkLayerShell.is_supported():
        print("Audio menu: a Wayland display with layer-shell support is required", file=sys.stderr)
        return 2
    return AudioPopup(args).run()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        traceback.print_exc()
        sys.exit(2)
