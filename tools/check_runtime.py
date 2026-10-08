#!/usr/bin/env python3
"""Check native desktop commands, or validate the optional Waybar fallback."""
import ctypes
from ctypes.util import find_library
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys


def check_native():
    required = ('Hyprland', 'hyprctl', 'awww', 'awww-daemon', 'nmcli',
                'bluetoothctl', 'pactl', 'wpctl', 'kitty', 'thunar', 'uwsm',
                'sqlite3', 'cc', 'busctl', 'systemctl', 'brightnessctl',
                'grim', 'slurp', 'swappy', 'fc-cache', 'xdg-user-dirs-update')
    missing = [name for name in required if not shutil.which(name)]
    if not (shutil.which('quickshell') or shutil.which('qs')):
        missing.append('quickshell')
    if not Path('/usr/lib/qt6/bin/qmltestrunner').is_file():
        missing.append('/usr/lib/qt6/bin/qmltestrunner (qt6-declarative)')
    if missing:
        raise SystemExit('Missing desktop commands: ' + ', '.join(missing))
    ctypes.CDLL(find_library('pulse-simple') or 'libpulse-simple.so.0')
    ctypes.CDLL(find_library('fftw3') or 'libfftw3.so.3')
    print('Native Hyprshell commands, Qt 6, PulseAudio client library, and FFTW: OK')


def check(directory):
    import cairo  # noqa: F401 -- verify optional legacy dependencies
    import dbus  # noqa: F401
    import gi
    gi.require_version('Gtk', '3.0')
    gi.require_version('GtkLayerShell', '0.1')
    gi.require_version('Playerctl', '2.0')
    from gi.repository import Gtk, GtkLayerShell, Playerctl  # noqa: F401
    config = (directory / 'config.jsonc').read_text()
    pattern = r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/'
    clean = re.sub(pattern, lambda m: m[0] if m[0].startswith('"') else '', config)
    json.loads(clean)
    Gtk.CssProvider().load_from_path(str(directory / 'style.css'))
    ctypes.CDLL(find_library('fftw3') or 'libfftw3.so.3')
    required = ('Hyprland', 'hyprctl', 'waybar', 'awww', 'awww-daemon', 'mako',
                'makoctl', 'nmcli', 'pactl', 'parec', 'wpctl', 'rofi', 'kitty',
                'thunar', 'playerctl', 'notify-send', 'brightnessctl', 'uwsm',
                'quickshell', 'sqlite3', 'cc', 'grim', 'slurp', 'swappy')
    missing = [name for name in required if not shutil.which(name)]
    if missing:
        raise SystemExit('Missing commands: ' + ', '.join(missing))
    theme = directory.parent / 'rofi/config.rasi'
    result = subprocess.run(['rofi', '-config', str(theme), '-dump-theme'],
                            text=True, capture_output=True, check=True)
    if re.search(r'error|failed to parse', result.stderr, re.IGNORECASE):
        raise SystemExit(result.stderr)
    print('Waybar JSON/CSS, Rofi theme, GTK layer-shell, Playerctl, D-Bus, Cairo, FFTW, and commands: OK')


if __name__ == '__main__':
    if sys.argv[1:] == ["--native"]:
        check_native()
    else:
        check(Path(sys.argv[1]))
