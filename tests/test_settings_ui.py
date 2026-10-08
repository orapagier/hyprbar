"""Exercise real asynchronous settings writes without desktop services or sockets."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('quickshell'), 'Quickshell is needed for the native UI smoke test')
class AutosaveTests(unittest.TestCase):
    def test_debounce_queued_edits_validation_recovery_and_close_flush(self):
        self.run_ui_scenario('SettingsAutosave', 'AUTOSAVE_OK', ('left', '#00ff00', 0.7))

    def test_lazy_loading_close_flush_failed_draft_and_reopen(self):
        self.run_ui_scenario('SettingsLifecycle', 'LIFECYCLE_OK', ('right', '#00ff00', 1))

    def run_ui_scenario(self, scenario, marker, expected_audio):
        with tempfile.TemporaryDirectory(prefix='hyprshell-autosave-') as directory:
            root = Path(directory)
            commands = root / 'bin'
            commands.mkdir()
            # Slow the backend so the QML test can reliably edit while saving.
            wrapper = commands / 'python3'
            wrapper.write_text(f'#!{sys.executable}\nimport os, sys, time\ntime.sleep(0.3)\nos.execv({sys.executable!r}, [{sys.executable!r}] + sys.argv[1:])\n')
            wrapper.chmod(0o755)
            runtime = root / 'runtime'
            runtime.mkdir(mode=0o700)
            payload = root / 'config/quickshell'
            shutil.copytree(ROOT / 'config/quickshell', payload, ignore=shutil.ignore_patterns('__pycache__', 'audio-spectrum'))
            entry = payload / (scenario + '.qml')
            entry.write_text((payload / 'tests' / (scenario + '.qml')).read_text().replace('import ".."', 'import "."'))
            env = dict(os.environ, XDG_CONFIG_HOME=str(root / 'config'), XDG_STATE_HOME=str(root / 'state'), XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', PATH=str(commands) + os.pathsep + os.environ['PATH'])
            result = subprocess.run(['quickshell', '-p', str(entry)], env=env, capture_output=True, text=True, timeout=20)
            self.assertIn(marker, result.stdout + result.stderr, result.stdout + result.stderr)
            self.assertEqual(result.returncode, 0)
            settings = json.loads((root / 'config/hyprshell/settings.json').read_text())
            audio = next(i for i in settings['items'] if i['id'] == 'audio')
            self.assertEqual((audio['side'], audio['textColor'], audio['opacity']), expected_audio)
