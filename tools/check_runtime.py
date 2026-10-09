#!/usr/bin/env python3
"""Check native Hyprshell desktop commands."""
import ctypes
from ctypes.util import find_library
from pathlib import Path
import shutil


def check_native():
    required = ('Hyprland', 'hyprctl', 'awww', 'awww-daemon', 'nmcli',
                'bluetoothctl', 'pactl', 'wpctl', 'kitty', 'nautilus', 'uwsm',
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


if __name__ == '__main__':
    check_native()
