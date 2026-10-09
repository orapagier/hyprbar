#!/usr/bin/env python3
"""Settings entrypoint for installing the checkout's global agent skill."""
import json
import os
from pathlib import Path
import subprocess
import sys


def main():
    try:
        if sys.argv[1:] != ['--install']:
            raise ValueError('Expected --install')
        home = Path.home()
        state = Path(os.environ.get('XDG_STATE_HOME') or home / '.local/state')
        pointer = state / 'hyprshell/repository'
        repo = Path(pointer.read_text().strip()) if pointer.exists() else home / 'repos/hyprshell'
        if not repo.is_absolute():
            raise ValueError('The Hyprshell repository path must be absolute.')
        if not (repo / 'setup.sh').is_file() or not (repo / 'config/quickshell/shell.qml').is_file():
            raise ValueError('Could not find the Hyprshell checkout. Restore its location or rerun desktop setup.')
        installer = repo / 'tools/install_hyprskill.py'
        if not installer.is_file():
            raise ValueError('Update your Hyprshell checkout to include the Hyprskill installer.')
        result = subprocess.run([sys.executable, str(installer)], capture_output=True, text=True, timeout=30)
        if result.returncode:
            raise RuntimeError((result.stderr or result.stdout).strip() or 'Hyprskill installation failed.')
        print(json.dumps({'ok': True, 'message': 'Hyprskill installed for Codex, Claude Code, and OpenCode. Restart your agents to discover it.'}))
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(json.dumps({'ok': False, 'message': str(error)}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
