#!/usr/bin/env python3
"""Render shared SDDM/early-boot artwork (requires rsvg-convert and ffmpeg)."""
import base64
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]
SPLASH = REPO / 'config/boot/hyprshell'
LOGIN = REPO / 'config/sddm/hyprshell-glass'


def render():
    for name in ('background', 'title', 'title-glow', 'footer'):
        shutil.copyfile(SPLASH / (name + '.png'), LOGIN / (name + '.png'))
    subprocess.run(['rsvg-convert', '-o', str(LOGIN / 'card.png'),
                    str(LOGIN / 'sources/card.svg')], check=True)
    # The EFI stub supports a static BMP, before Plymouth can animate.
    layers = [('background', 0, 0, 1920, 1080),
              ('card', 510, 280, 900, 520),
              ('title-glow', 700, 408, 520, 140),
              ('title', 700, 408, 520, 140),
              ('loading', 760, 616, 400, 32),
              ('footer', 760, 1006, 400, 24)]
    images = []
    for name, x, y, width, height in layers:
        data = base64.b64encode((SPLASH / (name + '.png')).read_bytes()).decode()
        images.append(f'<image x="{x}" y="{y}" width="{width}" height="{height}" '
                      f'href="data:image/png;base64,{data}"/>')
    svg = '<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080">' + ''.join(images) + '</svg>'
    with tempfile.TemporaryDirectory(prefix='hyprshell-render-') as directory:
        png = Path(directory) / 'early-boot.png'
        subprocess.run(['rsvg-convert', '-o', str(png)], input=svg.encode(), check=True)
        subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-y', '-i', str(png),
                        '-frames:v', '1', '-pix_fmt', 'bgr24',
                        str(REPO / 'config/boot/uki-splash.bmp')], check=True)
    print('Rendered SDDM theme and static EFI splash.')


if __name__ == '__main__':
    render()
