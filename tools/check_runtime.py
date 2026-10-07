#!/usr/bin/env python3
"""Check the dependencies and parse Waybar's configuration without a display."""
import ctypes
from ctypes.util import find_library
import json
from pathlib import Path
import re
import shutil
import sys

import cairo
import dbus
import gi

gi.require_version('Gtk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
gi.require_version('Playerctl', '2.0')
from gi.repository import Gtk, GtkLayerShell, Playerctl


def check(directory):
    config = (directory / 'config.jsonc').read_text()
    pattern = r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/'
    clean = re.sub(pattern, lambda m: m[0] if m[0].startswith('"') else '', config)
    json.loads(clean)
    Gtk.CssProvider().load_from_path(str(directory / 'style.css'))
    ctypes.CDLL(find_library('fftw3') or 'libfftw3.so.3')
    required = ('Hyprland', 'hyprctl', 'waybar', 'awww', 'awww-daemon', 'mako',
                'makoctl', 'nmcli', 'pactl', 'parec', 'wpctl', 'fuzzel', 'kitty',
                'thunar', 'playerctl', 'notify-send', 'brightnessctl', 'uwsm')
    missing = [name for name in required if not shutil.which(name)]
    if missing:
        raise SystemExit('Missing commands: ' + ', '.join(missing))
    print('Waybar JSON/CSS, GTK layer-shell, Playerctl, D-Bus, Cairo, FFTW, and commands: OK')


if __name__ == '__main__':
    check(Path(sys.argv[1]))
