#!/usr/bin/env python3
"""Application color preference, separate from Hyprshell's bar colors."""
import argparse
import ast
import configparser
import hashlib
from datetime import datetime
import json
import os
import re
import shlex
from pathlib import Path
import subprocess
import sys

from backend import atomic, lock

SCHEMA = 'org.gnome.desktop.interface'


def roots():
    return (Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config'),
            Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state'))


def validate(data):
    if not isinstance(data, dict) or set(data) - {'version', 'mode', 'font', 'cursorTheme', 'cursorSize'} or type(data.get('version')) is not int or data['version'] != 1 or data.get('mode') not in ('dark', 'light'):
        raise ValueError('Application theme must be Dark or Light')
    for key in ('font', 'cursorTheme'):
        if key in data and (not isinstance(data[key], str) or not data[key].strip() or len(data[key]) > 200 or any(ord(c) < 32 for c in data[key])):
            raise ValueError('Invalid application font or cursor theme')
    if 'font' in data:
        match = re.fullmatch(r'(.+) (\d+)', data['font'])
        if not match or not 6 <= int(match[2]) <= 32:
            raise ValueError('Choose a font size from 6 to 32 points')
    if 'cursorTheme' in data and not re.fullmatch(r'[A-Za-z0-9_.+-]+', data['cursorTheme']):
        raise ValueError('Invalid cursor theme')
    if 'cursorSize' in data and (type(data['cursorSize']) is not int or not 16 <= data['cursorSize'] <= 64):
        raise ValueError('Choose a cursor size from 16 to 64 pixels')
    return data


def saved():
    config, _ = roots()
    target = config / 'hyprshell/theme.json'
    return validate(json.loads(target.read_text())) if target.exists() else None


def setting(action, key, value=None):
    args = ['gsettings', action, SCHEMA, key]
    if value is not None:
        args.append(value)
    result = subprocess.run(args, capture_output=True, text=True, timeout=10)
    if result.returncode or (action == 'set' and result.stderr.strip()):
        raise ValueError('Could not update application appearance. Try again from your desktop session.')
    return result.stdout.strip()


def gtk_file(original, mode, appearance=None):
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    parser.read_string(original or '')
    if not parser.has_section('Settings'):
        parser.add_section('Settings')
    parser['Settings']['gtk-theme-name'] = 'Adwaita-dark' if mode == 'dark' else 'Adwaita'
    parser['Settings']['gtk-application-prefer-dark-theme'] = 'true' if mode == 'dark' else 'false'
    for key, gtk in [('font', 'gtk-font-name'), ('cursorTheme', 'gtk-cursor-theme-name'), ('cursorSize', 'gtk-cursor-theme-size')]:
        if key in (appearance or {}):
            parser['Settings'][gtk] = str(appearance[key])
    import io
    stream = io.StringIO()
    parser.write(stream)
    return stream.getvalue()


def environment(original, appearance=None):
    begin = '# BEGIN Hyprshell application theme'
    end = '# END Hyprshell application theme'
    lines = ['export QT_QPA_PLATFORMTHEME=gtk3']
    for key, names in [('cursorTheme', ['XCURSOR_THEME']), ('cursorSize', ['XCURSOR_SIZE', 'HYPRCURSOR_SIZE'])]:
        if key in (appearance or {}):
            lines.extend('export ' + name + '=' + shlex.quote(str(appearance[key])) for name in names)
    block = begin + '\n' + '\n'.join(lines) + '\n' + end
    text = original or ''
    if begin in text:
        if end not in text:
            raise ValueError('Incomplete Hyprshell application theme environment block')
        start = text.index(begin)
        finish = text.index(end, start) + len(end)
        return text[:start] + block + text[finish:]
    return text.rstrip() + '\n\n' + block + '\n'


def status():
    data = saved()
    mode = data['mode'] if data else ('dark' if setting('get', 'color-scheme') == "'prefer-dark'" else 'light')
    appearance = effective(data)
    font = appearance['font'].rsplit(' ', 1)
    return {'ok': True, 'mode': mode, **appearance, 'fontFamily': font[0],
            'fontSize': int(float(font[1])) if len(font) == 2 and font[1].replace('.', '', 1).isdigit() else 11,
            'fonts': font_families(), 'cursors': cursor_themes(), 'revision': revision()}


def revision():
    config, _ = roots()
    digest = hashlib.sha256()
    for name in ('hyprshell/theme.json', 'gtk-3.0/settings.ini', 'gtk-4.0/settings.ini', 'uwsm/env-hyprland'):
        path = config / name
        digest.update(path.read_bytes() if path.exists() else b'<missing>')
        digest.update(b'\0')
    for key in ('color-scheme', 'gtk-theme', 'font-name', 'cursor-theme', 'cursor-size'):
        digest.update(setting('get', key).encode()); digest.update(b'\0')
    return digest.hexdigest()


def effective(data=None):
    data = data or {}
    result = {}
    for key, setting_key in [('font', 'font-name'), ('cursorTheme', 'cursor-theme'), ('cursorSize', 'cursor-size')]:
        if key in data:
            result[key] = data[key]
        else:
            value = setting('get', setting_key)
            result[key] = int(value) if key == 'cursorSize' else ast.literal_eval(value)
    return result


def font_families():
    result = subprocess.run(['fc-list', '--format', '%{family[0]}\n'], capture_output=True, text=True, timeout=10)
    if result.returncode:
        raise ValueError('Could not read installed fonts')
    return sorted(set(filter(None, result.stdout.splitlines())), key=str.casefold)


def cursor_themes():
    data_home = Path(os.environ.get('XDG_DATA_HOME') or Path.home() / '.local/share')
    roots = [Path.home() / '.icons', data_home / 'icons']
    roots.extend(Path(path) / 'icons' for path in (os.environ.get('XDG_DATA_DIRS') or '/usr/local/share:/usr/share').split(':') if path)
    names = {path.name for root in roots for path in root.glob('*') if (path / 'cursors').is_dir() and re.fullmatch(r'[A-Za-z0-9_.+-]+', path.name)}
    return sorted(names, key=str.casefold)


def apply(mode, expected=None, appearance=None, expected_appearance=None, expected_revision=None, restoring=False):
    if appearance is not None and (not isinstance(appearance, dict) or set(appearance) - {'font', 'cursorTheme', 'cursorSize'}):
        raise ValueError('Invalid application appearance')
    config, state = roots()
    with lock(state / 'hyprshell/theme.lock'):
        # Keep old, two-key snapshots compatible while preserving new preferences.
        data = dict(saved() or {'version': 1})
        data['mode'] = mode
        data.update(appearance or {})
        validate(data)
        if expected_revision is not None and expected_revision != revision():
            raise ValueError('Application appearance changed elsewhere. Refresh before saving.')
        if expected is not None and status()['mode'] != expected:
            raise ValueError('Application theme changed elsewhere. Refresh before switching.')
        if expected_appearance is not None and effective(saved()) != expected_appearance:
            raise ValueError('Application appearance changed elsewhere. Refresh before saving.')
        if appearance and 'font' in appearance and appearance['font'].rsplit(' ', 1)[0] not in font_families():
            raise ValueError('This font is no longer installed. Refresh and choose another.')
        if appearance and 'cursorTheme' in appearance and appearance['cursorTheme'] not in cursor_themes():
            raise ValueError('This cursor theme is no longer installed. Refresh and choose another.')
        active = data.copy()
        if restoring:
            if 'font' in active and active['font'].rsplit(' ', 1)[0] not in font_families():
                active.pop('font')
            if 'cursorTheme' in active and active['cursorTheme'] not in cursor_themes():
                active.pop('cursorTheme'); active.pop('cursorSize', None)
        old = {key: setting('get', key) for key in ('color-scheme', 'gtk-theme')}
        desired = {'color-scheme': 'prefer-dark' if mode == 'dark' else 'prefer-light',
                   'gtk-theme': 'Adwaita-dark' if mode == 'dark' else 'Adwaita'}
        for key, setting_key in [('font', 'font-name'), ('cursorTheme', 'cursor-theme'), ('cursorSize', 'cursor-size')]:
            if key in active:
                old[setting_key] = setting('get', setting_key)
                desired[setting_key] = active[key]
        changes = {}
        for version in ('3.0', '4.0'):
            path = config / ('gtk-' + version) / 'settings.ini'
            changes[path] = gtk_file(path.read_text() if path.exists() else '', mode, active)
        path = config / 'uwsm/env-hyprland'
        changes[path] = environment(path.read_text() if path.exists() else '', active)
        changes[config / 'hyprshell/theme.json'] = json.dumps(data, indent=2) + '\n'
        previous = {path: path.read_text() if path.exists() else None for path in changes}
        variant = lambda value: str(value) if type(value) is int else repr(value)
        if all(previous[path] == text for path, text in changes.items()) and all(old[key] == variant(value) for key, value in desired.items()):
            return activate_qt(mode, active)
        backup = state / 'hyprshell/backups' / ('theme-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
        backup.mkdir(parents=True)
        manifest = []
        for index, (path, text) in enumerate(previous.items()):
            manifest.append({'path': str(path), 'existed': text is not None, 'file': str(index)})
            if text is not None:
                (backup / str(index)).write_text(text)
        (backup / 'manifest.json').write_text(json.dumps(manifest, indent=2))
        updated = []
        try:
            for key, value in desired.items():
                updated.append(key)
                setting('set', key, variant(value))
                if setting('get', key) != variant(value):
                    raise ValueError('Application appearance did not update. Try again from your desktop session.')
            for path, text in changes.items():
                atomic(path, text)
        except Exception:
            failures = []
            for path, text in previous.items():
                try:
                    if text is None:
                        path.unlink(missing_ok=True)
                    else:
                        atomic(path, text)
                except Exception as error:
                    failures.append(str(error))
            for key in reversed(updated):
                try:
                    setting('set', key, old[key])
                except Exception as error:
                    failures.append(str(error))
            if failures:
                raise ValueError('Theme update failed; desktop preferences could not be restored. Reopen Settings and try again.')
            raise
        return activate_qt(mode, active)


def activate_qt(mode, appearance=None):
    # UWSM launches apps through the user manager. Existing applications may
    # need reopening; the saved UWSM environment also covers the next login.
    try:
        env = ['QT_QPA_PLATFORMTHEME=gtk3']
        for key, names in [('cursorTheme', ['XCURSOR_THEME']), ('cursorSize', ['XCURSOR_SIZE', 'HYPRCURSOR_SIZE'])]:
            if key in (appearance or {}):
                env.extend(name + '=' + str(appearance[key]) for name in names)
        result = subprocess.run(['systemctl', '--user', 'set-environment', *env], capture_output=True, text=True, timeout=10)
        qt_ready = result.returncode == 0
    except (OSError, subprocess.SubprocessError):
        qt_ready = False
    message = 'Application theme set to ' + mode.capitalize() + '. Reopen apps that do not update automatically.'
    if not qt_ready:
        message += ' Qt integration will activate at your next login.'
    if appearance and 'cursorTheme' in appearance and 'cursorSize' in appearance:
        try:
            cursor = subprocess.run(['hyprctl', 'setcursor', appearance['cursorTheme'], str(appearance['cursorSize'])], capture_output=True, text=True, timeout=10)
            if cursor.returncode:
                message += ' The desktop cursor will update at your next login.'
        except (OSError, subprocess.SubprocessError):
            message += ' The desktop cursor will update at your next login.'
    return {'ok': True, 'mode': mode, 'message': message}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--request-json')
    parser.add_argument('--restore', action='store_true')
    args = parser.parse_args()
    try:
        if args.restore:
            data = saved()
            if data is None:
                return 0
            result = apply(data['mode'], restoring=True)
        else:
            request = json.loads(args.request_json or '{}')
            if request.get('operation') == 'status':
                result = status()
            elif request.get('operation') == 'save':
                result = apply(request['mode'], request['expected'], request.get('appearance'), request.get('expectedAppearance'), request.get('expectedRevision'))
                result.update(status())
            else:
                raise ValueError('Unknown appearance action')
    except Exception as error:
        print(json.dumps({'ok': False, 'message': str(error)}))
        return 1
    print(json.dumps(result))
    return 0


if __name__ == '__main__':
    sys.exit(main())
