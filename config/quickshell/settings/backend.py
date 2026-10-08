#!/usr/bin/env python3
"""Validated, backed-up settings transactions. No shell evaluation of user input."""
import argparse
import copy
from contextlib import contextmanager
from datetime import datetime
import fcntl
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

DEFAULTS = json.loads(Path(__file__).with_name('defaults.json').read_text())
HYPR = {
    'gapsIn': ('general.gaps_in', 0, 100),
    'gapsOut': ('general.gaps_out', 0, 100),
    'borderSize': ('general.border_size', 0, 20),
    'rounding': ('decoration.rounding', 0, 100),
    'activeOpacity': ('decoration.active_opacity', 0, 1),
    'inactiveOpacity': ('decoration.inactive_opacity', 0, 1),
    'blur': ('decoration.blur.enabled', None, None),
    'blurSize': ('decoration.blur.size', 1, 20),
    'blurPasses': ('decoration.blur.passes', 1, 4),
    'blurVibrancy': ('decoration.blur.vibrancy', 0, 1),
    'shadows': ('decoration.shadow.enabled', None, None),
    'animations': ('animations.enabled', None, None),
}
MARKER = '-- Hyprshell settings override'


def number(value, low, high, integer=False):
    if type(value) not in (int, float) or not math.isfinite(value) or not low <= value <= high:
        raise ValueError(f'Expected a number from {low} to {high}, got {value!r}')
    if integer and int(value) != value:
        raise ValueError('Expected a whole number')


def validate(data):
    if not isinstance(data, dict) or type(data.get('version')) is not int or data['version'] != 1:
        raise ValueError('Unsupported settings version')
    data = copy.deepcopy(data)
    # Ignore only the retired experiment, preserving validation of other keys.
    sections = [data.get('bar')] + (data.get('items', []) if isinstance(data.get('items', []), list) else [])
    for section in sections:
        if isinstance(section, dict):
            for key in ('genieEffect', 'genieOpenDuration', 'genieCloseDuration'):
                section.pop(key, None)
    if set(data) - set(DEFAULTS):
        raise ValueError('Unknown settings section')
    result = json.loads(json.dumps(DEFAULTS))
    bar = data.get('bar', {})
    if not isinstance(bar, dict) or set(bar) - set(result['bar']):
        raise ValueError('Unknown bar setting')
    result['bar'].update(bar)
    bar = result['bar']
    if type(bar['adaptiveColors']) is not bool:
        raise ValueError('adaptiveColors must be boolean')
    if bar['iconSize'] != 0 or type(bar['iconSize']) is bool:
        number(bar['iconSize'], 8, 48, True)
    if bar['background'] not in ('inherit', 'on', 'off'):
        raise ValueError('Invalid global background')
    for key, low, high in [('height', 28, 80), ('marginTop', 0, 100), ('marginSide', 0, 200), ('spacing', 0, 30)]:
        number(bar[key], low, high, True)
    if not isinstance(bar['clockFormat'], str) or not 1 <= len(bar['clockFormat']) <= 100:
        raise ValueError('Clock format must contain 1–100 characters')
    items = data.get('items', [])
    if not isinstance(items, list):
        raise ValueError('items must be a list')
    known = {i['id']: i for i in result['items']}
    seen = set()
    for item in items:
        if not isinstance(item, dict) or item.get('id') not in known or item['id'] in seen:
            raise ValueError('Unknown or duplicate bar item')
        seen.add(item['id'])
        target = known[item['id']]
        if set(item) - set(target):
            raise ValueError('Unknown item setting')
        target.update(item)
        for key in ('enabled', 'hideText', 'hideIcon'):
            if type(target[key]) is not bool:
                raise ValueError(f'{key} must be boolean')
        for key, choices in [('side', ('left', 'center', 'right')), ('adaptiveColors', ('inherit', 'on', 'off')), ('background', ('inherit', 'on', 'off'))]:
            if target[key] not in choices:
                raise ValueError(f'Invalid {key}')
        for key in ('text', 'icon'):
            if not isinstance(target[key], str) or len(target[key]) > 200:
                raise ValueError('Text/icon must be at most 200 characters')
        for key in ('textColor', 'iconColor', 'backgroundColor', 'outlineColor'):
            if not isinstance(target[key], str) or (target[key] and not re.fullmatch(r'#[0-9a-fA-F]{6}', target[key])):
                raise ValueError(f'{key} must be empty or #RRGGBB')
        for key, low, high, integer in [('order', 0, 1000, True), ('opacity', 0, 1, False), ('fontSize', 0, 48, True), ('radius', -1, 50, True), ('spacingLeft', 0, 200, True), ('spacingRight', 0, 200, True)]:
            number(target[key], low, high, integer)
        if target['iconSize'] != 0 or type(target['iconSize']) is bool:
            number(target['iconSize'], 8, 48, True)
        alpha = target['backgroundOpacity']
        if alpha != -1:
            number(alpha, 0, 1)
    hypr = data.get('hyprland', {})
    if not isinstance(hypr, dict) or set(hypr) - set(HYPR):
        raise ValueError('Unknown Hyprland setting')
    for key, value in hypr.items():
        _, low, high = HYPR[key]
        if low is None:
            if type(value) is not bool:
                raise ValueError(f'{key} must be boolean')
        else:
            number(value, low, high, high != 1)
    result['hyprland'] = hypr
    return result


def render_hypr(settings, lua):
    if not lua:
        return '# Generated by Hyprshell\n' + ''.join(f'{HYPR[k][0].replace(".", ":")} = {str(v).lower()}\n' for k, v in settings.items())
    tree = {}
    for key, value in settings.items():
        parts = HYPR[key][0].split('.')
        node = tree
        for part in parts[:-1]:
            node = node.setdefault(part, {})
        node[parts[-1]] = value
    def encode(node):
        if isinstance(node, dict):
            return '{' + ', '.join(k + ' = ' + encode(v) for k, v in node.items()) + '}'
        return str(node).lower()
    return '-- Generated by Hyprshell\nhl.config(' + encode(tree) + ')\n'


def atomic(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.hyprshell-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


@contextmanager
def lock(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w') as stream:
        fcntl.flock(stream, fcntl.LOCK_EX)
        yield


def save(data, expected=None):
    data = validate(data)
    home = Path.home()
    config = Path(os.environ.get('XDG_CONFIG_HOME') or home / '.config')
    state = Path(os.environ.get('XDG_STATE_HOME') or home / '.local/state')
    target = config / 'hyprshell/settings.json'
    with lock(state / 'hyprshell/settings.lock'):
        current = validate(json.loads(target.read_text())) if target.exists() else validate(DEFAULTS)
        if expected is not None and current != validate(expected):
            raise ValueError('Settings changed outside this window. Close and reopen settings before applying.')
        changes = {}
        hypr_changed = data['hyprland'] != current['hyprland']
        if hypr_changed:
            main = config / 'hypr/hyprland.lua'
            lua = main.exists()
            if not lua:
                main = config / 'hypr/hyprland.conf'
            if not main.is_file():
                raise ValueError('No Hyprland config found. Bar settings can still be used without Hyprland overrides.')
            override = config / ('hyprshell/overrides.lua' if lua else 'hyprshell/overrides.conf')
            changes[override] = render_hypr(data['hyprland'], lua)
            original = main.read_text()
            marker = MARKER if lua else '# Hyprshell settings override'
            if marker not in original:
                if lua:
                    source = 'dofile(' + json.dumps(str(override), ensure_ascii=False) + ')'
                else:
                    if any(c in str(override) for c in '\n\r#'):
                        raise ValueError('Unsupported characters in Hyprland source path')
                    source = 'source = ' + str(override)
                changes[main] = original.rstrip() + '\n\n' + marker + '\n' + source + '\n'
        changes[target] = json.dumps(data, indent=2) + '\n'
        changes = {p: text for p, text in changes.items() if not p.exists() or p.read_text() != text}
        if not changes:
            return {'ok': True, 'message': 'No changes to apply.'}
        backup = state / 'hyprshell/backups' / ('settings-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
        backup.mkdir(parents=True)
        previous = {p: p.read_text() if p.exists() else None for p in changes}
        manifest = []
        for index, (path, text) in enumerate(previous.items()):
            entry = {'path': str(path), 'existed': text is not None, 'file': str(index)}
            manifest.append(entry)
            if text is not None:
                (backup / str(index)).write_text(text)
        (backup / 'manifest.json').write_text(json.dumps(manifest, indent=2))
        applied = []
        reload_live = hypr_changed and bool(os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'))
        try:
            for path, text in changes.items():
                atomic(path, text)
                applied.append(path)
            if reload_live:
                subprocess.run(['hyprctl', 'reload'], check=True, capture_output=True, text=True, timeout=15)
                errors = subprocess.run(['hyprctl', 'configerrors'], check=True, capture_output=True, text=True, timeout=10)
                if errors.stdout.strip() and errors.stdout.strip().lower() != 'ok':
                    raise ValueError(errors.stdout.strip())
        except Exception:
            for path in reversed(applied):
                if previous[path] is None:
                    path.unlink(missing_ok=True)
                else:
                    atomic(path, previous[path])
            if reload_live:
                subprocess.run(['hyprctl', 'reload'], capture_output=True, timeout=15)
            raise
        return {'ok': True, 'message': 'Settings applied.' + (' Hyprland changes will load next session.' if hypr_changed and not reload_live else ''), 'backup': str(backup)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--save-json', required=True)
    parser.add_argument('--expected-json')
    args = parser.parse_args()
    try:
        result = save(json.loads(args.save_json), json.loads(args.expected_json) if args.expected_json else None)
    except Exception as error:
        print(json.dumps({'ok': False, 'message': str(error)}))
        return 1
    print(json.dumps(result))
    return 0


if __name__ == '__main__':
    sys.exit(main())
