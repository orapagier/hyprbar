#!/usr/bin/env python3
"""Waybar's continuous unread counter; also starts the independent collector."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import time

_spec = importlib.util.spec_from_file_location('notification_store', Path(__file__).with_name('notification-store.py'))
_store = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_store)

if __name__ == '__main__':
    os.umask(0o077)
    watch = '--watch' in sys.argv
    if watch:
        for arguments in (['daemon-reload'], ['start', 'waybar-notification-monitor.service']):
            subprocess.run(['systemctl', '--user', *arguments], stdout=subprocess.DEVNULL, timeout=10)
    store = _store.Store()
    previous = None
    try:
        while True:
            value = json.dumps(store.status(), ensure_ascii=False)
            if value != previous:
                print(value, flush=True)
                previous = value
            if not watch:
                break
            time.sleep(1)
    except BrokenPipeError:
        pass
