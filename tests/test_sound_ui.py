"""Sound UI playback uses an inert player and never touches real audio hardware."""
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest
import wave

ROOT = Path(__file__).resolve().parents[1]


class SoundTests(unittest.TestCase):
    def test_packaged_tone_is_short_stereo_with_fades(self):
        with wave.open(str(ROOT / 'config/quickshell/sounds/test.wav')) as tone:
            self.assertEqual(tone.getnchannels(), 2)
            self.assertEqual(tone.getsampwidth(), 2)
            duration = tone.getnframes() / tone.getframerate()
            self.assertGreater(duration, 0.3)
            self.assertLess(duration, 1)
            samples = struct.unpack('<' + 'h' * tone.getnframes() * 2, tone.readframes(tone.getnframes()))
            self.assertEqual(samples[::2], samples[1::2])
            self.assertLess(max(abs(value) for value in samples), 13000)
            self.assertLess(max(abs(value) for value in samples[:100]), 1000)
            self.assertLess(max(abs(value) for value in samples[-100:]), 1000)

    @unittest.skipUnless(shutil.which('quickshell'), 'Native Quickshell required')
    def test_native_tone_command_failure_and_cancellation(self):
        with tempfile.TemporaryDirectory(prefix='hyprshell-sound-') as directory:
            root = Path(directory)
            payload = root / 'config/quickshell'
            shutil.copytree(ROOT / 'config/quickshell', payload, ignore=shutil.ignore_patterns('__pycache__', 'audio-spectrum'))
            entry = payload / 'SoundNative.qml'
            entry.write_text((payload / 'tests/SoundNative.qml').read_text().replace('import ".."', 'import "."'))
            commands = root / 'bin'
            commands.mkdir()
            calls = root / 'calls.jsonl'
            stopped = root / 'stopped'
            player = commands / 'paplay'
            player.write_text('#!/usr/bin/env python3\nimport json, signal, sys, time\n'
                             f'with open({str(calls)!r}, "a") as out: out.write(json.dumps(sys.argv[1:]) + "\\n")\n'
                             'def stop(signum, frame):\n'
                             f'    with open({str(stopped)!r}, "a") as out: out.write("stopped\\n")\n'
                             '    raise SystemExit(0)\n'
                             'signal.signal(signal.SIGTERM, stop)\n'
                             'if "--device=slow" in sys.argv: time.sleep(20)\n'
                             'raise SystemExit(1 if "--device=fail" in sys.argv else 0)\n')
            player.chmod(0o755)
            runtime = root / 'runtime'
            runtime.mkdir(mode=0o700)
            env = dict(os.environ, XDG_CONFIG_HOME=str(root / 'config'), XDG_STATE_HOME=str(root / 'state'),
                       XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORMTHEME='basic', QT_QPA_PLATFORM='offscreen',
                       QT_QUICK_BACKEND='software', PATH=str(commands) + os.pathsep + os.environ['PATH'])
            result = subprocess.run(['quickshell', '-p', str(entry)], env=env, capture_output=True, text=True, timeout=18)
            output = result.stdout + result.stderr
            self.assertIn('SOUND_OK', output, output)
            for error in ('SOUND_FAILED', 'TypeError', 'ReferenceError'):
                self.assertNotIn(error, output, output)
            commands = [json.loads(line) for line in calls.read_text().splitlines()]
            self.assertEqual(len(commands), 5, commands)
            self.assertEqual(commands[0][0], '--device=device with spaces;$(literal)')
            for command in commands:
                self.assertIn('--volume=49152', command)
                self.assertEqual(Path(command[-1]), payload / 'sounds/test.wav')
            self.assertEqual(commands[1][0], '--device=fail')
            self.assertTrue(all(command[0] == '--device=slow' for command in commands[2:]))
            self.assertEqual(len(stopped.read_text().splitlines()), 3)


if __name__ == '__main__':
    unittest.main()
