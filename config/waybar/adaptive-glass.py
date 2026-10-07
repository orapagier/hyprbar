#!/usr/bin/env python3
"""Choose glass opacity from local backdrop brightness, without saving images."""
import argparse
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import tempfile

FALLBACK = 0.99
TINT = (30, 30, 46)
MUTED = (186, 194, 222)
SELECTED = (230, 216, 250)
STATUS = (243, 139, 168)
MIN_CONTRAST = 4.6


def luminance(rgb):
    channels = [max(0, min(255, x)) / 255 for x in rgb]
    channels = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in channels]
    return sum(x * weight for x, weight in zip(channels, (0.2126, 0.7152, 0.0722)))


def contrast(text, background):
    a, b = sorted((luminance(text), luminance(background)))
    return (b + 0.05) / (a + 0.05)


def composite(front, back, alpha):
    return tuple(a * alpha + b * (1 - alpha) for a, b in zip(front, back))


def opacity_for_brightness(level, floor=0.28):
    if level is None or not math.isfinite(level):
        return FALLBACK
    backdrop = (max(0, min(255, level)),) * 3
    for hundredths in range(math.ceil(floor * 100 - 1e-9), 100):
        alpha = hundredths / 100
        panel = composite((255, 255, 255), composite(TINT, backdrop, alpha), 0.08)
        button = composite((255, 255, 255), panel, 0.045)
        selected = composite((255, 255, 255), composite((203, 166, 247), panel, 0.22), 0.06)
        if (contrast(MUTED, button) >= MIN_CONTRAST
                and contrast(STATUS, button) >= MIN_CONTRAST
                and contrast(SELECTED, selected) >= MIN_CONTRAST):
            return alpha
    return FALLBACK


def gtk_css(alpha):
    return f'''
#wifi-panel {{ background-color: rgba(30,30,46,{alpha:.2f}); }}
#wifi-panel .muted, #wifi-panel .caption, #wifi-panel .audio-caption,
#wifi-panel .weekday, #wifi-panel .network-badge,
#wifi-panel entry placeholder {{ color: #bac2de; }}
#wifi-panel .body {{ color: #cdd6f4; }}
#wifi-panel row:selected label, #wifi-panel row:hover label,
#wifi-panel button:hover label,
#wifi-panel expander.notification-row:hover label {{ color: #e6d8fa; }}
menu, popover.calendar-tooltip {{ background-color: rgba(30,30,46,{FALLBACK}); }}
menu menuitem:hover {{ color: #e6d8fa; }}
'''


def rofi_theme(alpha):
    return f'''
* {{ glass: rgba(30,30,46,{alpha:.2f}); muted: #cdd6f4; }}
entry, element-text {{
    text-color: #eef2ff;
    text-outline: false;
}}
element selected.normal, element selected.active, element selected.urgent,
element-text selected.normal, element-text selected.active, element-text selected.urgent {{ text-color: #ffffff; }}
textbox-search {{ text-outline: false; }}
'''


def intersection(a, b):
    x, y = max(a[0], b[0]), max(a[1], b[1])
    width = min(a[0] + a[2], b[0] + b[2]) - x
    height = min(a[1] + a[3], b[1] + b[3]) - y
    return (x, y, width, height) if width > 0 and height > 0 else None


def fully_covered(rectangle, boxes):
    """Check union coverage so exposed wallpaper cannot escape the sample."""
    xs = sorted({rectangle[0], rectangle[0] + rectangle[2],
                 *(x for box in boxes for x in (box[0], box[0] + box[2]))})
    area = 0
    for left, right in zip(xs, xs[1:]):
        intervals = sorted((y, y + h) for x, y, w, h in boxes if x <= left and x + w >= right)
        bottom = rectangle[1]
        for top, end in intervals:
            area += (right - left) * max(0, end - max(top, bottom))
            bottom = max(bottom, end)
    return area >= rectangle[2] * rectangle[3]


class Sampler:
    def __init__(self):
        self.binary = None
        self.disabled = False
        self.desktop_sample = None

    def prepare(self):
        if self.disabled:
            return None
        if self.binary:
            return self.binary
        source = Path(__file__).with_name('backdrop-sample.c')
        try:
            digest = hashlib.sha256(source.read_bytes()).hexdigest()[:16]
            root = Path(os.environ.get('XDG_CACHE_HOME') or Path.home() / '.cache') / 'hyprbar'
            root.mkdir(parents=True, exist_ok=True)
            binary = root / ('backdrop-sample-' + digest)
            with (root / 'backdrop-build.lock').open('a') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX)
                if not binary.exists():
                    with tempfile.TemporaryDirectory(dir=root) as temporary:
                        staged = Path(temporary) / 'sample'
                        subprocess.run(['cc', '-std=c11', '-O2', str(source), '-o', str(staged),
                                        '-lwayland-client'], check=True, capture_output=True, timeout=10)
                        os.replace(staged, binary)
            self.binary = binary
        except (OSError, subprocess.SubprocessError):
            self.disabled = True
        return self.binary

    def capture(self, mode, identifier, rectangle):
        binary = self.prepare()
        if not binary:
            return None
        try:
            result = subprocess.run([str(binary), mode, str(identifier), *map(str, rectangle)],
                                    check=True, capture_output=True, text=True, timeout=0.7)
            value = int(result.stdout.strip())
            return value if 0 <= value <= 255 else None
        except (OSError, ValueError, subprocess.SubprocessError):
            return None

    @staticmethod
    def query(name):
        return json.loads(subprocess.check_output(['hyprctl', '-j', name], timeout=0.35,
                                                 stderr=subprocess.DEVNULL))

    def screen(self, output, rectangle):
        return self.capture('screen', output, rectangle)

    def candidates(self, rectangle):
        monitors = self.query('monitors')
        visible = {m['activeWorkspace']['id'] for m in monitors}
        visible.update(m.get('specialWorkspace', {}).get('id', 0) for m in monitors)
        candidates = []
        for client in self.query('clients'):
            if not client.get('mapped') or client.get('hidden') or client['workspace']['id'] not in visible:
                continue
            box = (*client['at'], *client['size'])
            overlap = intersection(rectangle, box)
            if overlap:
                candidates.append((client, box, overlap))
        return candidates

    @staticmethod
    def wallpaper_state():
        return subprocess.check_output(['awww', 'query'], timeout=0.35,
                                       stderr=subprocess.DEVNULL).strip() or None

    def opening(self, output, local_rectangle, global_rectangle):
        level = self.screen(output, local_rectangle) if output else None
        try:
            if level is not None and not self.candidates(global_rectangle):
                state = self.wallpaper_state()
                if state:
                    self.desktop_sample = (state, level)
        except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
            pass
        return level

    def windows(self, rectangle):
        """Capture underlying windows, excluding our own layer-shell surface."""
        try:
            candidates = self.candidates(rectangle)
            if not candidates:
                if self.desktop_sample and self.wallpaper_state() == self.desktop_sample[0]:
                    return self.desktop_sample[1]
                return None
            if len(candidates) > 3:
                # Bound capture work without overlooking a visible bright
                # fourth window on crowded or floating layouts.
                return None
            desktop = None
            if not fully_covered(rectangle, [item[2] for item in candidates]):
                if self.desktop_sample and self.wallpaper_state() == self.desktop_sample[0]:
                    desktop = self.desktop_sample[1]
                else:
                    return None
            # Sample at most three overlapping windows; brighter results win.
            # Conservatively including an obscured bright window is preferable
            # to losing readability. No layer-shell surfaces are exported.
            candidates.sort(key=lambda item: (-bool(item[0].get('floating')), item[0].get('focusHistoryID', 999)))
            values = []
            for client, box, overlap in candidates[:3]:
                crop = ((overlap[0] - box[0]) / box[2], (overlap[1] - box[1]) / box[3],
                        overlap[2] / box[2], overlap[3] / box[3])
                level = self.capture('window', client['address'], crop)
                if level is not None:
                    values.append(level)
            # A failed capture must not hide a potentially bright backdrop.
            return max(values + ([desktop] if desktop is not None else [])) if len(values) == len(candidates[:3]) and values else None
        except (OSError, ValueError, KeyError, TypeError, ZeroDivisionError, subprocess.SubprocessError):
            return None

    def launcher(self):
        try:
            monitors = self.query('monitors')
            monitor = next((m for m in monitors if m.get('focused')), monitors[0])
            width, height = monitor['width'], monitor['height']
            if monitor.get('transform', 0) % 2:
                width, height = height, width
            width, height = width / monitor['scale'], height / monitor['scale']
            panel_width, panel_height = min(440, width), min(440, height)
            region = (int((width - panel_width) / 2), int((height - panel_height) / 2),
                      int(panel_width), int(panel_height))
            return self.screen(monitor['name'], region)
        except (OSError, ValueError, KeyError, TypeError, IndexError, ZeroDivisionError, subprocess.SubprocessError):
            return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--rofi', action='store_true')
    parser.add_argument('--prepare', action='store_true')
    args = parser.parse_args()
    sampler = Sampler()
    if args.prepare:
        print(sampler.prepare() or 'Capture unavailable; using readable fallback')
    elif args.rofi:
        # Rofi loads themes when opening; use solid light glyphs and let the
        # sampled panel tint provide contrast.
        print(rofi_theme(opacity_for_brightness(sampler.launcher())))


if __name__ == '__main__':
    main()
