"""Native power page and session controllers with isolated, inert hardware stubs."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('quickshell'), 'Quickshell is required')
class PowerUiTests(unittest.TestCase):
    def test_native_power_controls_and_shared_idle_lifecycle(self):
        with tempfile.TemporaryDirectory(prefix='hyprshell-power-ui-') as directory:
            root = Path(directory)
            payload = root / 'config/quickshell'
            shutil.copytree(ROOT / 'config/quickshell', payload,
                            ignore=shutil.ignore_patterns('__pycache__', 'audio-spectrum'))
            calls = root / 'calls'
            (payload / 'settings/power.py').write_text(
                'import json, sys, time\n'
                f'with open({str(calls)!r}, "a") as out: out.write(" ".join(sys.argv[1:]) + "\\n")\n'
                'if sys.argv[1] == "--lid": time.sleep(30)\n'
                'result = {"ok": True}\n'
                'if sys.argv[1] == "--status": result.update(brightness={"percent": 80}, '
                'profiles={"available":["power-saver","balanced"],"active":"balanced"},lidSupported=True)\n'
                'if sys.argv[1] == "--brightness": result["brightness"]={"percent": int(sys.argv[2])}\n'
                'print(json.dumps(result))\n')
            (payload / 'settings/backend.py').write_text(
                'import sys, time\n'
                f'with open({str(calls)!r}, "a") as out: out.write(sys.argv[1] + "\\n")\n'
                'time.sleep(30)\n')
            entry = payload / 'PowerTest.qml'
            entry.write_text((payload / 'tests/SettingsPowerNative.qml').read_text().replace('import ".."', 'import "."'))
            runtime = root / 'runtime'
            runtime.mkdir(mode=0o700)
            env = dict(os.environ, XDG_CONFIG_HOME=str(root / 'config'),
                       XDG_STATE_HOME=str(root / 'state'), XDG_RUNTIME_DIR=str(runtime),
                       QT_QPA_PLATFORMTHEME='', QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
            result = subprocess.run(['quickshell', '-p', str(entry)], env=env,
                                    capture_output=True, text=True, timeout=15)
            output = result.stdout + result.stderr
            self.assertIn('POWER_UI_OK', output, output)
            self.assertNotIn('POWER_UI_FAILED', output, output)
            calls = calls.read_text().splitlines()
            for expected in ('--status', '--brightness 37', '--apply-profile', '--lid', '--idle'):
                self.assertIn(expected, calls)
            self.assertEqual(calls.count('--idle'), 1, calls)


if __name__ == '__main__':
    unittest.main()
