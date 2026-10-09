#!/usr/bin/env python3
"""Keybinding overrides with validation, conflict detection and reload rollback."""
import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid

from backend import atomic, lock

MODIFIERS = ('SUPER', 'CTRL', 'ALT', 'SHIFT')
ALIASES = {'CONTROL': 'CTRL', 'WIN': 'SUPER', 'META': 'SUPER'}


def shortcut(value):
    if not isinstance(value, str) or len(value) > 160:
        raise ValueError('Enter a shortcut such as SUPER + SHIFT + N.')
    parts = [part.strip() for part in value.split('+')]
    if not parts or any(not part for part in parts):
        raise ValueError('Enter one key with optional Super, Ctrl, Alt or Shift modifiers.')
    mods = [ALIASES.get(part.upper(), part.upper()) for part in parts[:-1]]
    if any(mod not in MODIFIERS for mod in mods) or len(mods) != len(set(mods)):
        raise ValueError('Use each modifier only once: SUPER, CTRL, ALT, SHIFT.')
    key = parts[-1]
    if not re.fullmatch(r'[A-Za-z0-9_]+|(?:mouse|code):[0-9]+', key):
        raise ValueError('Use a key name such as N, Return, XF86AudioMute or mouse:272.')
    if len(key) == 1:
        key = key.upper()
    return ' + '.join([mod for mod in MODIFIERS if mod in mods] + [key])


def identity(value):
    return shortcut(value).upper()


def validate(entries):
    if not isinstance(entries, list) or len(entries) > 500:
        raise ValueError('Invalid keybinding list.')
    result, ids, keys, originals = [], set(), set(), set()
    for entry in entries:
        if not isinstance(entry, dict) or set(entry) != {'id', 'original', 'shortcut', 'description', 'mode', 'command'}:
            raise ValueError('Invalid keybinding fields.')
        entry = dict(entry)
        if not isinstance(entry['id'], str) or not re.fullmatch(r'[a-f0-9]{32}', entry['id']) or entry['id'] in ids:
            raise ValueError('Invalid or duplicate keybinding ID.')
        ids.add(entry['id'])
        entry['shortcut'] = shortcut(entry['shortcut'])
        key = identity(entry['shortcut'])
        if key in keys:
            raise ValueError('Two shortcuts cannot use the same key combination.')
        keys.add(key)
        if not isinstance(entry['original'], str):
            raise ValueError('Invalid original shortcut.')
        if entry['original']:
            entry['original'] = shortcut(entry['original'])
            original = identity(entry['original'])
            if original in originals:
                raise ValueError('An original shortcut can only be modified once.')
            originals.add(original)
        elif entry['mode'] != 'command':
            raise ValueError('New shortcuts need a command.')
        for field, limit in [('description', 160), ('command', 4096)]:
            value = entry[field]
            if not isinstance(value, str) or len(value) > limit or any(ord(c) < 32 for c in value):
                raise ValueError(f'Invalid {field}.')
            entry[field] = value.strip()
        if not entry['description']:
            raise ValueError('Give this shortcut an action name.')
        if entry['mode'] not in ('existing', 'command'):
            raise ValueError('Invalid action type.')
        if entry['mode'] == 'command' and not entry['command']:
            raise ValueError('Enter a command to run.')
        if entry['mode'] == 'existing' and entry['command']:
            raise ValueError('Existing actions must not include a replacement command.')
        result.append(entry)
    return result


def paths():
    config = Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config')
    state = Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state')
    return config, state


def load():
    config, _ = paths()
    target = config / 'hyprshell/keybindings.json'
    if not target.exists():
        return []
    data = json.loads(target.read_text())
    if not isinstance(data, dict) or set(data) != {'version', 'entries'} or type(data['version']) is not int or data['version'] != 1:
        raise ValueError('Unsupported keybindings file.')
    return validate(data['entries'])


def active():
    result = subprocess.run(['hyprctl', '-j', 'binds'], check=True, capture_output=True, text=True, timeout=5)
    rows = json.loads(result.stdout)
    if not isinstance(rows, list):
        raise ValueError('Invalid active keybinding list.')
    return rows


def runtime_shortcut(row):
    mask = row.get('modmask', 0)
    mods = [name for bit, name in [(64, 'SUPER'), (4, 'CTRL'), (8, 'ALT'), (1, 'SHIFT')] if mask & bit]
    key = row.get('key') or ('code:' + str(row['keycode']) if row.get('keycode') else '')
    return shortcut(' + '.join(mods + [key]))


def listing(entries, rows):
    managed = {identity(e['shortcut']): e for e in entries}
    found = {}
    for row in rows:
        if row.get('submap') or row.get('modmask', 0) & ~77:
            continue
        try:
            keys = runtime_shortcut(row)
        except ValueError:
            continue
        key = identity(keys)
        if key in found:
            continue
        entry = managed.get(key)
        found[key] = dict(entry) if entry else {
            'id': '', 'original': keys, 'shortcut': keys,
            'description': row.get('description') or 'Custom action', 'mode': 'existing', 'command': ''}
    return sorted(found.values(), key=lambda e: e['shortcut'].upper())


def lua_string(value):
    # JSON Unicode escapes are not Lua escapes; emit UTF-8 and escape controls.
    return json.dumps(value, ensure_ascii=False)


def render(entries):
    lines = ['-- Generated by Hyprshell Settings. Edit through the Keybindings page.', 'return {']
    for entry in entries:
        lines.append('    { ' + ', '.join(key + ' = ' + lua_string(value) for key, value in entry.items()) + ' },')
    return '\n'.join(lines + ['}', ''])


def save(entries, expected, rows=None):
    entries = validate(entries)
    config, state = paths()
    with lock(state / 'hyprshell/keybindings.lock'):
        current = load()
        if current != validate(expected):
            raise ValueError('Shortcuts changed outside this page. Refresh before saving.')
        if entries == current:
            return {'ok': True, 'message': 'No changes to save.', 'entries': current}
        main = config / 'hypr/hyprland.lua'
        if not main.exists() or 'hyprshellKeybindings.apply()' not in main.read_text():
            raise ValueError('The Hyprshell keybinding hook is missing from your Lua config.')
        rows = active() if rows is None else rows
        occupied = set()
        for row in rows:
            if row.get('submap') or row.get('modmask', 0) & ~77:
                continue
            try:
                occupied.add(identity(runtime_shortcut(row)))
            except ValueError:
                continue
        old = {e['id']: e for e in current}
        for entry in entries:
            prior = old.get(entry['id'])
            if prior and entry['original'] != prior['original']:
                raise ValueError('The original action cannot be changed. Create a new shortcut instead.')
            if entry['mode'] == 'existing' and ('mouse:' in entry['original']) != ('mouse:' in entry['shortcut']):
                raise ValueError('Mouse drag actions need a mouse-button shortcut.')
            allowed = identity(prior['shortcut']) if prior else identity(entry['original']) if entry['original'] else None
            if identity(entry['shortcut']) in occupied and identity(entry['shortcut']) != allowed:
                raise ValueError('That shortcut is already in use. Choose a different combination.')
            if not prior and entry['original'] and identity(entry['original']) not in occupied:
                raise ValueError('The original shortcut is no longer active. Refresh the list.')
        # Reverting a remap must not restore a base shortcut over a new command.
        removed = [e for e in current if e['id'] not in {n['id'] for n in entries}]
        destinations = {identity(e['shortcut']) for e in entries}
        for entry in removed:
            if entry['original'] and identity(entry['original']) in destinations:
                raise ValueError('Another customization uses the original shortcut. Reset it first.')
        target = config / 'hyprshell/keybindings.json'
        generated = config / 'hyprshell/keybindings.lua'
        changes = {target: json.dumps({'version': 1, 'entries': entries}, indent=2) + '\n', generated: render(entries)}
        previous = {p: p.read_text() if p.exists() else None for p in changes}
        backup = state / 'hyprshell/backups' / ('keybindings-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
        backup.mkdir(parents=True)
        manifest = []
        for index, (path, content) in enumerate(previous.items()):
            manifest.append({'path': str(path), 'existed': content is not None, 'file': str(index)})
            if content is not None:
                (backup / str(index)).write_text(content)
        (backup / 'manifest.json').write_text(json.dumps(manifest, indent=2))
        applied = []
        try:
            for path, content in changes.items():
                atomic(path, content)
                applied.append(path)
            verified = subprocess.run(['Hyprland', '--verify-config', '--config', str(main)], check=True, capture_output=True, text=True, timeout=15)
            if 'config ok' not in verified.stdout.lower():
                raise ValueError('Hyprland config validation failed: ' + verified.stdout[-2000:])
            subprocess.run(['hyprctl', 'reload'], check=True, capture_output=True, text=True, timeout=15)
            errors = subprocess.run(['hyprctl', 'configerrors'], check=True, capture_output=True, text=True, timeout=5).stdout.strip()
            if errors and errors.lower() != 'ok':
                raise ValueError(errors)
        except Exception:
            for path in reversed(applied):
                if previous[path] is None:
                    path.unlink(missing_ok=True)
                else:
                    atomic(path, previous[path])
            try:
                subprocess.run(['hyprctl', 'reload'], capture_output=True, timeout=15)
            except (OSError, subprocess.SubprocessError):
                pass
            raise
        return {'ok': True, 'message': 'Shortcut saved and applied.', 'entries': entries}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--request-json', required=True)
    args = parser.parse_args()
    try:
        request = json.loads(args.request_json)
        operation = request['operation']
        if operation == 'status':
            entries = load()
            result = {'ok': True, 'entries': entries, 'bindings': listing(entries, active())}
        elif operation in ('save', 'reset'):
            expected = request['expected']
            entries = validate(expected)
            if operation == 'save':
                entry = dict(request['entry'])
                if not entry['id']:
                    entry['id'] = uuid.uuid4().hex
                entries = [e for e in entries if e['id'] != entry['id']] + [entry]
            else:
                entries = [e for e in entries if e['id'] != request['id']]
            result = save(entries, expected)
            result['bindings'] = listing(result['entries'], active())
            if operation == 'reset':
                result['message'] = 'Customization reset.'
        else:
            raise ValueError('Unknown keybinding operation.')
    except Exception as exc:
        detail = (exc.stderr or exc.stdout or '').strip() if isinstance(exc, subprocess.CalledProcessError) else ''
        print(json.dumps({'ok': False, 'message': detail[-2000:] or str(exc)}))
        return 1
    print(json.dumps(result))
    return 0


if __name__ == '__main__':
    sys.exit(main())
