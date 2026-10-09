"""Microphone FFT and production capture lifecycle without desktop audio sockets."""
import json
import math
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
RATE = 16000
HOP = 256


def tone(frequency=500, amplitude=0.4, hops=32, offset=0):
    samples = [round(32767 * (offset + amplitude * math.sin(2 * math.pi * frequency * i / RATE)))
               for i in range(HOP * hops)]
    return struct.pack('<' + 'h' * len(samples), *samples)


class MicrophoneTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix='hyprshell-microphone-fft-')
        cls.addClassCleanup(cls.build.cleanup)
        cls.helper = Path(cls.build.name) / 'audio-spectrum'
        subprocess.run(['cc', '-O2', '-Wall', '-Wextra', '-Werror',
                        str(ROOT / 'config/quickshell/helpers/audio-spectrum.c'),
                        '-o', str(cls.helper), '-lpulse-simple', '-lpulse', '-lfftw3', '-lm'], check=True)

    def frames(self, pcm):
        result = subprocess.run([str(self.helper), '--source', '--stdin'], input=pcm,
                                capture_output=True, check=True, timeout=5)
        return [json.loads(line) for line in result.stdout.splitlines()]

    def test_microphone_frequencies_use_the_same_bands_as_media(self):
        for frequency, band in [(125, 2), (500, 5), (2000, 8), (5000, 11)]:
            with self.subTest(frequency=frequency):
                frame = self.frames(tone(frequency))[-1]
                self.assertTrue(frame['ok'])
                self.assertFalse(frame['clipping'])
                self.assertEqual(max(range(12), key=frame['levels'].__getitem__), band)
                self.assertGreater(frame['levels'][band], 0.75)
                self.assertTrue(all(0 <= level <= 1 for level in frame['levels']))

    def test_quieter_audio_falls_and_silence_returns_every_band_to_zero(self):
        frames = self.frames(tone() + tone(amplitude=0.025) + tone(amplitude=0, hops=48))
        self.assertEqual(len(frames), 112)
        self.assertGreater(frames[31]['levels'][5], 0.75)
        self.assertLess(frames[63]['levels'][5], 0.25)
        self.assertGreater(frames[63]['levels'][5], 0.05)
        self.assertEqual(frames[-1]['levels'], [0] * 12)
        self.assertEqual(frames[-1]['peak'], 0)

    def test_quiet_input_and_constant_dc_do_not_create_motion(self):
        for pcm in [tone(amplitude=0), tone(amplitude=0.001), tone(amplitude=0, offset=0.8)]:
            with self.subTest(pcm=pcm[:8]):
                frames = self.frames(pcm)
                self.assertTrue(all(frame['levels'] == [0] * 12 for frame in frames[-8:]))

    def test_attack_follows_speech_onset_within_two_hops(self):
        frames = self.frames(tone(amplitude=0, hops=8) + tone(2000, hops=8))
        self.assertEqual(frames[7]['levels'], [0] * 12)
        self.assertGreater(frames[9]['levels'][8], 0.6)

    def test_clipping_warning_uses_raw_samples(self):
        frame = self.frames(struct.pack('<h', 32767) * HOP * 32)[-1]
        self.assertTrue(frame['clipping'])
        self.assertEqual(frame['levels'], [0] * 12)

    def test_source_capture_requires_explicit_named_device(self):
        for args in [[], ['alsa_input.microphone'], ['--source'], ['--source', ''],
                     ['--source', '@DEFAULT_SOURCE@'], ['--source', '--other']]:
            with self.subTest(args=args):
                result = subprocess.run([str(self.helper), *args], capture_output=True, timeout=5)
                self.assertEqual(result.returncode, 2)

    @unittest.skipUnless(shutil.which('quickshell'), 'Native Quickshell required')
    def test_production_loader_levels_errors_and_capture_lifecycle(self):
        with tempfile.TemporaryDirectory(prefix='hyprshell-microphone-') as directory:
            root = Path(directory)
            payload = root / 'config/quickshell'
            shutil.copytree(ROOT / 'config/quickshell', payload, ignore=shutil.ignore_patterns('__pycache__', 'audio-spectrum'))
            calls = root / 'calls.jsonl'; stopped = root / 'stopped'
            helper = payload / 'helpers/audio-spectrum'
            helper.write_text(
                '#!/usr/bin/env python3\n'
                'import json, os, signal, sys, time\n'
                f'with open({str(calls)!r}, "a") as out: out.write(json.dumps({{"args":sys.argv[1:],"pid":os.getpid()}}) + "\\n")\n'
                'def stop(signum, frame):\n'
                f'    with open({str(stopped)!r}, "a") as out: out.write("stopped\\n")\n'
                '    raise SystemExit(0)\n'
                'signal.signal(signal.SIGTERM, stop)\n'
                'if sys.argv[-1] == "fail":\n'
                '    print(json.dumps({"ok":False,"message":"Input disconnected"}), flush=True)\n'
                '    raise SystemExit(1)\n'
                'print(json.dumps({"ok":True,"peak":0.5,"levels":[0,0,0,0,0,0.5,0,0,0,0,0,0]}), flush=True)\n'
                'time.sleep(20)\n')
            helper.chmod(0o755)
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
            self.assertEqual(commands, [['--source', 'input with spaces;literal'], ['--source', 'input with spaces;literal'], ['--source', 'fail'], ['--source', 'stall']])
            for call in calls:
                self.assertFalse(Path('/proc', str(call['pid'])).exists(), 'Capture process outlived the test')


if __name__ == '__main__':
    unittest.main()
