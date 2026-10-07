"""Check the compiled C pixel sampler with known buffers, without a display."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('cc'), 'C compiler is required')
class PixelTests(unittest.TestCase):
    def test_dark_white_mixed_cropped_inverted_and_colored_frames(self):
        with tempfile.TemporaryDirectory(prefix='hyprbar-pixels-') as directory:
            directory = Path(directory)
            # Include the actual production sampler; replace only its entrypoint.
            harness = directory / 'pixels.c'
            harness.write_text('''
#define main capture_main
#include "backdrop-sample.c"
#undef main
int main(void) {
    uint32_t data[64] = {0};
    pixels = data; width = height = 8; stride = 32; format = 1;
    printf("%d\\n", brightness());
    for (int i = 0; i < 64; i++) data[i] = 0xffffff;
    printf("%d\\n", brightness());
    for (int i = 0; i < 62; i++) data[i] = 0;
    printf("%d\\n", brightness());
    for (int y = 0; y < 8; y++) for (int x = 0; x < 8; x++)
        data[y * 8 + x] = x < 4 ? 0 : 0xffffff;
    window_mode = 1; crop[2] = .5;
    printf("%d\\n", brightness());
    crop[0] = .5;
    printf("%d\\n", brightness());
    for (int i = 0; i < 64; i++) data[i] = i < 32 ? 0xff000080 : 0xffffffff;
    crop[0] = 0; crop[1] = .5; crop[2] = 1; crop[3] = .5;
    inverted = 1; format = 0x34324241;
    printf("%d\\n", brightness());
    for (int i = 0; i < 64; i++) data[i] = 0;
    printf("%d\\n", brightness());
    crop[2] = 0;
    printf("%d\\n", brightness());
    return 0;
}
''')
            binary = directory / 'pixels'
            subprocess.run(['cc', '-std=c11', '-O2', '-I', str(ROOT), str(harness),
                            '-o', str(binary), '-lwayland-client'],
                           check=True, capture_output=True, timeout=15)
            result = subprocess.check_output([str(binary)], text=True, timeout=3)
            self.assertEqual(result.splitlines(), ['0', '255', '255', '0', '255', '128', '255', '-1'])


if __name__ == '__main__':
    unittest.main()
