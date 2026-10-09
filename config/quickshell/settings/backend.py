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
import shlex
import shutil
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
    if type(bar['randomVibrantColors']) is not bool:
        raise ValueError('randomVibrantColors must be boolean')
    if bar['iconSize'] != 0 or type(bar['iconSize']) is bool:
        number(bar['iconSize'], 8, 48, True)
    if bar['background'] not in ('inherit', 'on', 'off'):
        raise ValueError('Invalid global background')
    for key, low, high in [('height', 28, 80), ('marginTop', 0, 100), ('marginSide', 0, 200), ('spacing', 0, 30), ('groupSpacing', 0, 30)]:
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
        if not isinstance(target['pillGroup'], str) or len(target['pillGroup']) > 40 or any(ord(c) < 32 for c in target['pillGroup']):
            raise ValueError('Pill group must be a name of at most 40 characters')
        for key in ('text', 'icon'):
            if not isinstance(target[key], str) or len(target[key]) > 200:
                raise ValueError('Text/icon must be at most 200 characters')
        for key in ('textColor', 'iconColor', 'backgroundColor', 'outlineColor'):
            if not isinstance(target[key], str) or (target[key] and not re.fullmatch(r'#[0-9a-fA-F]{6}', target[key])):
                raise ValueError(f'{key} must be empty or #RRGGBB')
        for key, low, high, integer in [('order', 0, 1000, True), ('opacity', 0, 1, False), ('fontSize', 0, 48, True), ('radius', -1, 50, True), ('spacingLeft', -200, 200, True), ('spacingRight', -200, 200, True), ('paddingLeft', -200, 200, True), ('paddingRight', -200, 200, True)]:
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
    locking = data.get('locking', {})
    if not isinstance(locking, dict) or set(locking) - set(result['locking']):
        raise ValueError('Unknown screen locking setting')
    result['locking'].update(locking)
    locking = result['locking']
    for key in ('enabled', 'beforeSleep'):
        if type(locking[key]) is not bool:
            raise ValueError(f'{key} must be boolean')
    number(locking['idleMinutes'], 0, 240, True)
    lock_argv(locking['command'])
    result['hyprland'] = hypr
    return result


def lock_argv(command):
    if not isinstance(command, str) or not command.strip() or len(command) > 2000 or any(c in command for c in '\n\r\0'):
        raise ValueError('Lock command must contain 1–2000 characters on one line')
    args = shlex.split(command)
    if not args or not args[0]:
        raise ValueError('Enter a locker executable and optional arguments')
    return [os.path.expanduser(arg) for arg in args]


def lock_dependencies(settings):
    if not shutil.which('hypridle'):
        raise ValueError('Install hypridle to enable automatic locking')
    if not shutil.which(lock_argv(settings['command'])[0]):
        raise ValueError('Lock program was not found. Install it or enter its full path')


def render_idle(settings):
    # Hyprlang interprets these characters before its command reaches a shell.
    path = str(Path(__file__).resolve())
    if any(c in path + sys.executable for c in '\n\r#$'):
        raise ValueError('Unsupported characters in screen locking helper path')
    command = shlex.join([sys.executable, path, '--lock'])
    text = '# Generated by Hyprshell; edit screen locking in Settings.\ngeneral {\n'
    text += '    lock_cmd = ' + command + '\n'
    if settings['beforeSleep']:
        text += '    before_sleep_cmd = loginctl lock-session\n'
    text += '}\n'
    if settings['idleMinutes']:
        text += '\nlistener {\n    timeout = ' + str(settings['idleMinutes'] * 60) + '\n    on-timeout = loginctl lock-session\n}\n'
    return text


def read_locking():
    config = Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config')
    path = config / 'hyprshell/settings.json'
    return validate(json.loads(path.read_text()) if path.exists() else DEFAULTS)['locking']


def run_locker():
    settings = read_locking()
    args = lock_argv(settings['command'])
    if not shutil.which(args[0]):
        raise ValueError('Lock program was not found: ' + args[0])
    # Hold a separate lock throughout the foreground locker lifetime, so idle,
    # sleep and manual requests cannot start multiple lock screens.
    state = Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state')
    path = state / 'hyprshell/locker.lock'
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w') as stream:
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 0
        return subprocess.run(args, check=False).returncode


def run_idle():
    settings = read_locking()
    if not settings['enabled']:
        return 0
    lock_dependencies(settings)
    existing = subprocess.run(['pgrep', '-u', str(os.getuid()), '-x', 'hypridle'], capture_output=True)
    if existing.returncode == 0:
        raise ValueError('Another hypridle is running. Disable its service or autostart before using Hyprshell automatic locking')
    config = Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config')
    path = config / 'hyprshell/hypridle.conf'
    atomic(path, render_idle(settings))
    os.execvp('hypridle', ['hypridle', '-c', str(path)])


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
        if data['locking']['enabled'] and data['locking'] != current['locking']:
            lock_dependencies(data['locking'])
            render_idle(data['locking'])
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
    parser.add_argument('--save-json')
    parser.add_argument('--lock', action='store_true')
    parser.add_argument('--idle', action='store_true')
    parser.add_argument('--expected-json')
    args = parser.parse_args()
    try:
        if args.lock:
            return run_locker()
        if args.idle:
            return run_idle()
        if not args.save_json:
            parser.error('Provide --save-json, --lock or --idle')
        result = save(json.loads(args.save_json), json.loads(args.expected_json) if args.expected_json else None)
    except Exception as error:
        if args.lock or args.idle:
            print(str(error), file=sys.stderr)
            return 1
        print(json.dumps({'ok': False, 'message': str(error)}))
        return 1
    print(json.dumps(result))
    return 0


if __name__ == '__main__':
    sys.exit(main())
