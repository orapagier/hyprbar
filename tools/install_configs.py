#!/usr/bin/env python3
"""Install only the public config payload; preserve replaced paths in backups."""
from datetime import datetime
import filecmp
import os
from pathlib import Path
import shutil
import sys
import tempfile
import time


def same(source, destination):
    if destination.is_symlink() or not destination.exists():
        return False
    if source.is_file():
        return destination.is_file() and filecmp.cmp(source, destination, shallow=False)
    if not destination.is_dir():
        return False
    comparison = filecmp.dircmp(source, destination, ignore=['__pycache__'])
    if comparison.left_only or comparison.right_only or comparison.common_funny:
        return False
    return all(same(source / name, destination / name)
               for name in comparison.common_files + comparison.common_dirs)


def systemd_quote(value):
    # Escape unit specifiers and environment expansion as well as string syntax.
    value = value.replace('\\', '\\\\').replace('"', '\\"')
    return '"' + value.replace('%', '%%').replace('$', '$$') + '"'


def install(repo):
    home = Path(os.environ['HOME'])
    config = Path(os.environ.get('XDG_CONFIG_HOME') or home / '.config')
    state = Path(os.environ.get('XDG_STATE_HOME') or home / '.local/state')
    stamp = datetime.now().strftime('%Y%m%d-%H%M%S') + '-' + str(time.time_ns())
    backup = state / 'hyprbar/backups' / stamp

    def put(source, destination, relative):
        if same(source, destination):
            print('Unchanged:', destination)
            return
        destination.parent.mkdir(parents=True, exist_ok=True)
        saved = backup / relative
        with tempfile.TemporaryDirectory(prefix='.hyprbar-stage-', dir=destination.parent) as temporary:
            staged = Path(temporary) / 'payload'
            if source.is_dir():
                shutil.copytree(source, staged, ignore=shutil.ignore_patterns('__pycache__'))
            else:
                shutil.copy2(source, staged)
            existed = os.path.lexists(destination)
            if existed:
                saved.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(destination), str(saved))
                print('Backed up:', saved)
            try:
                os.replace(staged, destination)
            except OSError:
                if existed:
                    shutil.move(str(saved), str(destination))
                raise
        print('Installed:', destination)

    for name in ('hypr', 'waybar', 'fuzzel'):
        put(repo / 'config' / name, config / name, Path('config') / name)

    with tempfile.TemporaryDirectory(prefix='hyprbar-service-') as temporary:
        service = Path(temporary) / 'waybar-notification-monitor.service'
        text = (repo / 'config/systemd/user' / service.name).read_text()
        text = text.replace('/usr/bin/python3 %h/.config/waybar/notification-monitor.py',
                            '/usr/bin/python3 ' + systemd_quote(str(config / 'waybar/notification-monitor.py')))
        service.write_text(text)
        service.chmod(0o644)
        put(service, config / 'systemd/user' / service.name, Path('config/systemd/user') / service.name)

    for wallpaper in sorted((repo / 'assets/wallpapers').iterdir()):
        if wallpaper.is_file():
            put(wallpaper, home / 'Pictures/Wallpapers' / wallpaper.name,
                Path('Pictures/Wallpapers') / wallpaper.name)
    if backup.exists():
        print('Backup directory:', backup)


if __name__ == '__main__':
    install(Path(sys.argv[1]).resolve())
