"""Active microphone capture and production QML loader without real hardware."""
import ctypes
import importlib.util
import json
import math
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('microphone', ROOT / 'config/quickshell/settings/microphone.py')
mic = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mic)


class MicrophoneTests(unittest.TestCase):
    def test_level_scales_pcm_and_rejects_nonfinite_samples(self):
        self.assertEqual(mic.level(struct.pack('<ffff', 0, 0, float('nan'), float('inf'))), 0)
        self.assertAlmostEqual(mic.level(struct.pack('<ff', 0.125, -0.125)), (20 * math.log10(0.125) + 60) / 60)
        self.assertEqual(mic.level(struct.pack('<f', 4)), 1)

    def test_capture_opens_selected_source_as_record_stream_and_frees_on_stop(self):
        library = Mock()
        library.pa_simple_new.return_value = 42
        def read(stream, data, size, error):
            ctypes.memmove(data, struct.pack('<f', 0.125) * (size // 4), size)
            return 0
        library.pa_simple_read.side_effect = read
        rows = []
        def emit(row):
            rows.append(row)
            raise InterruptedError('test stop')
        with patch.object(mic.ctypes, 'CDLL', return_value=library), self.assertRaises(InterruptedError):
            mic.capture('input with spaces;literal', emit)
        args = library.pa_simple_new.call_args.args
        self.assertEqual(args[2], 2)  # Active PA_STREAM_RECORD, rather than Monitor.
        self.assertEqual(args[3], b'input with spaces;literal')
        self.assertEqual((args[5]._obj.format, args[5]._obj.rate, args[5]._obj.channels), (5, 16000, 1))
        self.assertEqual(len(rows), 1)
        self.assertAlmostEqual(rows[0]['peak'], mic.level(struct.pack('<f', 0.125)))
        self.assertFalse(rows[0]['clipping'])
        library.pa_simple_free.assert_called_once_with(42)

    def test_average_meter_does_not_stick_full_on_isolated_spikes(self):
        spike = mic.measure(struct.pack('<' + 'f' * 1024, 1, *([0] * 1023)))
        self.assertLess(spike['peak'], 0.6)
        self.assertFalse(spike['clipping'])
        full = mic.measure(struct.pack('<ffff', 1, -1, 1, -1))
        self.assertEqual(full, {'peak': 1, 'clipping': True})
        self.assertLess(mic.level(struct.pack('<f', 0.02)), mic.level(struct.pack('<f', 0.2)))
        self.assertEqual(mic.level(struct.pack('<ffff', 0, 0, 0, 0)), 0)

    def test_connection_and_read_failures(self):
        library = Mock()
        library.pa_simple_new.return_value = None
        with patch.object(mic.ctypes, 'CDLL', return_value=library), self.assertRaisesRegex(RuntimeError, 'open the microphone'):
            mic.capture('input', lambda row: None)
        library.pa_simple_new.return_value = 42
        library.pa_simple_read.return_value = -1
        with patch.object(mic.ctypes, 'CDLL', return_value=library), self.assertRaisesRegex(RuntimeError, 'capture stopped'):
            mic.capture('input', lambda row: None)
        library.pa_simple_free.assert_called_once_with(42)

    @unittest.skipUnless(shutil.which('quickshell'), 'Native Quickshell required')
    def test_production_loader_levels_errors_and_capture_lifecycle(self):
        with tempfile.TemporaryDirectory(prefix='hyprshell-microphone-') as directory:
            root = Path(directory)
            payload = root / 'config/quickshell'
            shutil.copytree(ROOT / 'config/quickshell', payload, ignore=shutil.ignore_patterns('__pycache__', 'audio-spectrum'))
            calls = root / 'calls.jsonl'; stopped = root / 'stopped'
            (payload / 'settings/microphone.py').write_text(
                'import json, os, signal, sys, time\n'
                f'with open({str(calls)!r}, "a") as out: out.write(json.dumps({{"args":sys.argv[1:],"pid":os.getpid()}}) + "\\n")\n'
                'def stop(signum, frame):\n'
                f'    with open({str(stopped)!r}, "a") as out: out.write("stopped\\n")\n'
                '    raise SystemExit(0)\n'
                'signal.signal(signal.SIGTERM, stop)\n'
                'if sys.argv[-1] == "fail":\n'
                '    print(json.dumps({"ok":False,"message":"Input disconnected"}), flush=True)\n'
                '    raise SystemExit(1)\n'
                'print(json.dumps({"ok":True,"peak":0.5}), flush=True)\n'
                'time.sleep(20)\n')
            entry = payload / 'MicrophoneNative.qml'
            entry.write_text((payload / 'tests/MicrophoneNative.qml').read_text().replace('import ".."', 'import "."'))
            runtime = root / 'runtime'; runtime.mkdir(mode=0o700)
            env = dict(os.environ, XDG_CONFIG_HOME=str(root / 'config'), XDG_STATE_HOME=str(root / 'state'),
                       XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORMTHEME='basic', QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
            result = subprocess.run(['quickshell', '-p', str(entry)], env=env, capture_output=True, text=True, timeout=15)
            output = result.stdout + result.stderr
            self.assertIn('MICROPHONE_OK', output, output)
            for error in ('MICROPHONE_FAILED', 'TypeError', 'ReferenceError'):
                self.assertNotIn(error, output, output)
            calls = [json.loads(line) for line in calls.read_text().splitlines()]
            commands = [call['args'] for call in calls]
            self.assertEqual(commands, [['--device', 'input with spaces;literal'], ['--device', 'input with spaces;literal'], ['--device', 'fail'], ['--device', 'stall']])
            for call in calls:
                self.assertFalse(Path('/proc', str(call['pid'])).exists(), 'Capture process outlived the test')


if __name__ == '__main__':
    unittest.main()
