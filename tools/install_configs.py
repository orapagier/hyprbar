#!/usr/bin/env python3
"""Install only the public config payload; preserve replaced paths in backups."""
from datetime import datetime
import filecmp
import os
from pathlib import Path
import shutil
import subprocess
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


def install(repo):
    home = Path(os.environ['HOME'])
    config = Path(os.environ.get('XDG_CONFIG_HOME') or home / '.config')
    state = Path(os.environ.get('XDG_STATE_HOME') or home / '.local/state')
    stamp = datetime.now().strftime('%Y%m%d-%H%M%S') + '-' + str(time.time_ns())
    backup = state / 'hyprshell/backups' / stamp

    def put(source, destination, relative):
        if same(source, destination):
            print('Unchanged:', destination)
            return
        destination.parent.mkdir(parents=True, exist_ok=True)
        saved = backup / relative
        with tempfile.TemporaryDirectory(prefix='.hyprshell-stage-', dir=destination.parent) as temporary:
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

    for name in ('hypr', 'xdg-desktop-portal'):
        put(repo / 'config' / name, config / name, Path('config') / name)

    # Compile before replacing the destination, so a failed build leaves it intact.
    with tempfile.TemporaryDirectory(prefix='hyprshell-quickshell-') as temporary:
        payload = Path(temporary) / 'quickshell'
        shutil.copytree(repo / 'config/quickshell', payload,
                        ignore=shutil.ignore_patterns('__pycache__', 'audio-spectrum'))
        subprocess.run(['cc', '-O2', str(payload / 'helpers/audio-spectrum.c'),
                        '-o', str(payload / 'helpers/audio-spectrum'),
                        '-lpulse-simple', '-lpulse', '-lfftw3', '-lm'], check=True)
        put(payload, config / 'quickshell', Path('config/quickshell'))

    for script in sorted((repo / 'bin').iterdir()):
        put(script, home / '.local/bin' / script.name, Path('.local/bin') / script.name)

    for desktop in sorted((repo / 'assets/applications').glob('*.desktop')):
        put(desktop, home / '.local/share/applications' / desktop.name,
            Path('.local/share/applications') / desktop.name)

    for wallpaper in sorted((repo / 'assets/wallpapers').iterdir()):
        if wallpaper.is_file():
            put(wallpaper, home / 'Pictures/Wallpapers' / wallpaper.name,
                Path('Pictures/Wallpapers') / wallpaper.name)
    if (repo / 'config/hyprshell/settings.json').exists():
        put(repo / 'config/hyprshell/settings.json', config / 'hyprshell/settings.json', Path('config/hyprshell/settings.json'))
    state.joinpath('hyprshell').mkdir(parents=True, exist_ok=True)
    state.joinpath('hyprshell/repository').write_text(str(repo.resolve()) + '\n')
    if backup.exists():
        print('Backup directory:', backup)


if __name__ == '__main__':
    install(Path(sys.argv[1]).resolve())
