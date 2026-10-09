#!/usr/bin/env python3
"""Install Bash shortcuts while preserving the user's existing bashrc."""
from datetime import datetime
import os
from pathlib import Path
import shutil
import sys
import time


def install(repo):
    home = Path(os.environ['HOME'])
    config = Path(os.environ.get('XDG_CONFIG_HOME') or home / '.config')
    state = Path(os.environ.get('XDG_STATE_HOME') or home / '.local/state')
    destination = config / 'hyprshell/shortcuts.bash'
    source = repo / 'config/bash/shortcuts.bash'
    bashrc = home / '.bashrc'
    text = bashrc.read_text() if bashrc.exists() else ''
    loader = '\n# Hyprshell Bash shortcuts\n[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/hyprshell/shortcuts.bash" ]] && source "${XDG_CONFIG_HOME:-$HOME/.config}/hyprshell/shortcuts.bash"\n'
    changes = []
    if not destination.exists() or destination.read_bytes() != source.read_bytes():
        changes.append((destination, source.read_text(), Path('config/hyprshell/shortcuts.bash')))
    if loader.strip() not in text:
        changes.append((bashrc, text.rstrip('\n') + '\n' + loader, Path('.bashrc')))
    backup = state / 'hyprshell/backups' / (datetime.now().strftime('%Y%m%d-%H%M%S') + '-' + str(time.time_ns()))
    for path, content, relative in changes:
        if path.exists():
            saved = backup / relative
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, saved)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        print('Installed:', path)
    if backup.exists():
        print('Backup directory:', backup)


if __name__ == '__main__':
    install(Path(sys.argv[1]).resolve())
