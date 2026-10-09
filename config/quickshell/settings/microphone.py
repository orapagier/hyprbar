#!/usr/bin/env python3
"""Capture microphone levels in memory; never save or play recorded audio."""
import argparse
import array
import ctypes
from ctypes.util import find_library
import json
import math
import sys


SAMPLE_RATE = 16000
FRAME_SAMPLES = 1600  # Ten meter updates per second.
NOISE_FLOOR = 10 ** (-50 / 20)


class SampleSpec(ctypes.Structure):
    _fields_ = [('format', ctypes.c_int), ('rate', ctypes.c_uint32), ('channels', ctypes.c_uint8)]


class BufferAttr(ctypes.Structure):
    _fields_ = [(key, ctypes.c_uint32) for key in ('maxlength', 'tlength', 'prebuf', 'minreq', 'fragsize')]


def measure(data):
    samples = array.array('f')
    samples.frombytes(data)
    if sys.byteorder != 'little':
        samples.byteswap()
    samples = [max(-1, min(1, sample)) if math.isfinite(sample) else 0 for sample in samples]
    if not samples:
        return {'peak': 0, 'clipping': False}
    # A constant DC offset is not sound. Measure variation around the block mean.
    mean = sum(samples) / len(samples)
    rms = math.sqrt(sum((sample - mean) ** 2 for sample in samples) / len(samples))
    # Compress amplitude instead of stretching every faint noise across a dB bar.
    # Quiet inputs below -50 dBFS are empty; full-scale audio still fills the bar.
    floor = math.sqrt(NOISE_FLOOR)
    return {'peak': max(0, min(1, (math.sqrt(rms) - floor) / (1 - floor))),
            'clipping': sum(abs(sample) >= 0.99 for sample in samples) / len(samples) >= 0.01}


def level(data):
    return measure(data)['peak']


class Envelope:
    """Respond quickly to speech and let the display fall without jitter."""
    def __init__(self):
        self.peak = 0

    def update(self, target):
        seconds = FRAME_SAMPLES / SAMPLE_RATE
        time_constant = 0.08 if target > self.peak else 0.25
        weight = 1 - math.exp(-seconds / time_constant)
        self.peak += weight * (target - self.peak)
        if target == 0 and self.peak < 0.005:
            self.peak = 0
        return self.peak


def capture(device, emit):
    if not device or len(device) > 1024 or '\0' in device:
        raise ValueError('Select an available microphone first.')
    library = ctypes.CDLL(find_library('pulse-simple') or 'libpulse-simple.so.0')
    library.pa_simple_new.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p,
                                     ctypes.c_char_p, ctypes.POINTER(SampleSpec), ctypes.c_void_p,
                                     ctypes.POINTER(BufferAttr), ctypes.POINTER(ctypes.c_int)]
    library.pa_simple_new.restype = ctypes.c_void_p
    library.pa_simple_read.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_int)]
    library.pa_simple_read.restype = ctypes.c_int
    library.pa_simple_free.argtypes = [ctypes.c_void_p]
    library.pa_simple_free.restype = None
    spec = SampleSpec(5, SAMPLE_RATE, 1)  # PA_SAMPLE_FLOAT32LE, mono.
    frame_bytes = FRAME_SAMPLES * 4
    attrs = BufferAttr(0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, frame_bytes)
    error = ctypes.c_int()
    stream = library.pa_simple_new(None, b'Hyprshell microphone test', 2, device.encode(),
                                   b'Microphone level', ctypes.byref(spec), None, ctypes.byref(attrs), ctypes.byref(error))
    if not stream:
        raise RuntimeError('Could not open the microphone. Check the input device and PipeWire connection.')
    try:
        data = ctypes.create_string_buffer(frame_bytes)
        envelope = Envelope()
        while True:
            if library.pa_simple_read(stream, data, len(data), ctypes.byref(error)) < 0:
                raise RuntimeError('Microphone capture stopped. Check that the input device is still connected.')
            result = measure(data.raw)
            result['peak'] = envelope.update(result['peak'])
            emit(dict(ok=True, **result))
    finally:
        library.pa_simple_free(stream)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--device', required=True)
    args = parser.parse_args()
    def emit(result):
        print(json.dumps(result), flush=True)
    try:
        capture(args.device, emit)
    except (OSError, RuntimeError, ValueError) as error:
        emit({'ok': False, 'message': str(error)})
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
