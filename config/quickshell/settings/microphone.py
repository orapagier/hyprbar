#!/usr/bin/env python3
"""Capture microphone levels in memory; never save or play recorded audio."""
import argparse
import array
import ctypes
from ctypes.util import find_library
import json
import math
import sys


class SampleSpec(ctypes.Structure):
    _fields_ = [('format', ctypes.c_int), ('rate', ctypes.c_uint32), ('channels', ctypes.c_uint8)]


class BufferAttr(ctypes.Structure):
    _fields_ = [(key, ctypes.c_uint32) for key in ('maxlength', 'tlength', 'prebuf', 'minreq', 'fragsize')]


def level(data):
    samples = array.array('f')
    samples.frombytes(data)
    if sys.byteorder != 'little':
        samples.byteswap()
    peak = max((abs(sample) for sample in samples if math.isfinite(sample)), default=0)
    # Match the perceptual scale used by Quickshell's other audio meters.
    return min(1, peak ** (1 / 3))


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
    spec = SampleSpec(5, 16000, 1)  # PA_SAMPLE_FLOAT32LE, mono.
    attrs = BufferAttr(0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 4096)
    error = ctypes.c_int()
    stream = library.pa_simple_new(None, b'Hyprshell microphone test', 2, device.encode(),
                                   b'Microphone level', ctypes.byref(spec), None, ctypes.byref(attrs), ctypes.byref(error))
    if not stream:
        raise RuntimeError('Could not open the microphone. Check the input device and PipeWire connection.')
    try:
        data = ctypes.create_string_buffer(4096)
        while True:
            if library.pa_simple_read(stream, data, len(data), ctypes.byref(error)) < 0:
                raise RuntimeError('Microphone capture stopped. Check that the input device is still connected.')
            emit({'ok': True, 'peak': level(data.raw)})
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
