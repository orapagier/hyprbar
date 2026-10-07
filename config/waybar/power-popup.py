#!/usr/bin/env python3
"""Power controls on the same glass layer surface as the other Waybar menus."""
from concurrent.futures import ThreadPoolExecutor
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import traceback

_spec = importlib.util.spec_from_file_location('menu_popup', Path(__file__).with_name('menu-popup.py'))
_menu = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_menu)
Gtk, GLib, GtkLayerShell = _menu.Gtk, _menu.GLib, _menu.GtkLayerShell


class PowerBackend:
    @staticmethod
    def command(*args):
        result = subprocess.run(args, capture_output=True, text=True, timeout=15)
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or result.stdout.strip() or 'Action failed')

    def perform(self, action):
        if action in ('shutdown', 'reboot', 'sleep'):
            self.command('systemctl', {'shutdown': 'poweroff', 'reboot': 'reboot', 'sleep': 'suspend'}[action])
        elif action == 'logout':
            active = subprocess.run(['uwsm', 'check', 'is-active'], capture_output=True, timeout=5)
            if active.returncode == 0:
                self.command('uwsm', 'stop')
            else:
                session = os.environ.get('XDG_SESSION_ID')
                if not session:
                    raise RuntimeError('Cannot identify the desktop login session')
                self.command('loginctl', 'terminate-session', session)
        else:
            raise ValueError('Unknown power action')


class PowerPopup(_menu.MenuPopup):
    ACTIONS = (
        ('shutdown', '󰐥', 'Shutdown'),
        ('reboot', '󰜉', 'Reboot'),
        ('sleep', '󰒲', 'Sleep'),
        ('logout', '󰗽', 'Logout'),
    )

    def __init__(self, args):
        super().__init__(args)
        self.backend = PowerBackend()
        self.executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix='power-menu')
        self.buttons = []
        self.busy = False

    def panel(self):
        box, _header = self.make_panel('Power options')
        self.scrollable(box)
        for action, icon, title in self.ACTIONS:
            button = Gtk.Button()
            button.connect('clicked', self.activate, action)
            button.get_style_context().add_class('device-row')
            row = Gtk.Box(spacing=12)
            self.inset(row, 10)
            glyph = Gtk.Label(label=icon)
            glyph.set_size_request(24, -1)
            glyph.get_style_context().add_class('network-icon')
            row.pack_start(glyph, False, False, 0)
            label = self.compact_label(title, 'card-title')
            label.set_tooltip_text(None)
            row.pack_start(label, True, True, 0)
            button.add(row)
            self.content.pack_start(button, False, False, 0)
            self.buttons.append(button)
        self.status = self.label('', 'caption')
        self.status.set_no_show_all(True)
        box.pack_start(self.status, False, False, 0)
        return self.panel_events

    def activate(self, _button, action):
        if self.busy:
            return
        self.busy = True
        self.status.hide()
        for button in self.buttons:
            button.set_sensitive(False)
        future = self.executor.submit(self.backend.perform, action)
        future.add_done_callback(lambda done: GLib.idle_add(self.completed, done))

    def completed(self, future):
        if self.closed:
            return False
        try:
            future.result()
        except (OSError, RuntimeError, subprocess.SubprocessError) as error:
            self.busy = False
            for button in self.buttons:
                button.set_sensitive(True)
            self.status.set_text(str(error))
            self.status.show()
            print(f'Power menu: {error}', file=sys.stderr)
            GLib.idle_add(self.position_panel)
        else:
            self.finish()
        return False

    def focus_control(self):
        self.buttons[0].grab_focus()

    def run(self):
        try:
            return super().run()
        finally:
            self.executor.shutdown(wait=False, cancel_futures=True)


if __name__ == '__main__':
    try:
        args = _menu.arguments()
        ready, _argv = Gtk.init_check(None)
        if not ready or not GtkLayerShell.is_supported():
            print('Power menu: a Wayland display with layer-shell support is required', file=sys.stderr)
            sys.exit(2)
        sys.exit(PowerPopup(args).run())
    except Exception:
        traceback.print_exc()
        sys.exit(2)
