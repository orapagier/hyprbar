#!/usr/bin/env python3
"""Render the editable SVG splash assets and a still preview (requires rsvg-convert)."""
import base64
from pathlib import Path
import subprocess

REPO = Path(__file__).resolve().parents[1]
THEME = REPO / 'config/boot/hyprshell'


def render():
    for source in sorted((THEME / 'sources').glob('*.svg')):
        subprocess.run(['rsvg-convert', '-o', str(THEME / (source.stem + '.png')),
                        str(source)], check=True)
    layers = [('background', 0, 0, 1920, 1080),
              ('card', 510, 280, 900, 520),
              ('title-glow', 700, 408, 520, 140),
              ('title', 700, 408, 520, 140),
              ('track', 780, 592, 360, 6),
              ('fill', 780, 592, 223, 6),
              ('loading', 760, 616, 400, 32),
              ('footer', 760, 1006, 400, 24)]
    images = []
    for name, x, y, width, height in layers:
        data = base64.b64encode((THEME / (name + '.png')).read_bytes()).decode()
        images.append(f'<image x="{x}" y="{y}" width="{width}" height="{height}" '
                      f'href="data:image/png;base64,{data}"/>')
    preview = '<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080">' + ''.join(images) + '</svg>'
    destination = REPO / 'docs/assets/boot-splash-preview.png'
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['rsvg-convert', '-o', str(destination)], input=preview.encode(), check=True)
    print(destination)


if __name__ == '__main__':
    render()
