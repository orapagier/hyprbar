#!/usr/bin/env python3
"""Application color preference, separate from Hyprshell's bar colors."""
import argparse
import configparser
from datetime import datetime
import json
import os
from pathlib import Path
import subprocess
import sys

from backend import atomic, lock

SCHEMA = 'org.gnome.desktop.interface'


def roots():
    return (Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config'),
            Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state'))


def validate(data):
    if not isinstance(data, dict) or set(data) != {'version', 'mode'} or type(data['version']) is not int or data['version'] != 1 or data['mode'] not in ('dark', 'light'):
        raise ValueError('Application theme must be Dark or Light')
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


def gtk_file(original, mode):
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    parser.read_string(original or '')
    if not parser.has_section('Settings'):
        parser.add_section('Settings')
    parser['Settings']['gtk-theme-name'] = 'Adwaita-dark' if mode == 'dark' else 'Adwaita'
    parser['Settings']['gtk-application-prefer-dark-theme'] = 'true' if mode == 'dark' else 'false'
    import io
    stream = io.StringIO()
    parser.write(stream)
    return stream.getvalue()


def environment(original):
    begin = '# BEGIN Hyprshell application theme'
    end = '# END Hyprshell application theme'
    block = begin + '\nexport QT_QPA_PLATFORMTHEME=gtk3\n' + end
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
    return {'ok': True, 'mode': mode}


def apply(mode, expected=None):
    data = validate({'version': 1, 'mode': mode})
    config, state = roots()
    with lock(state / 'hyprshell/theme.lock'):
        if expected is not None and status()['mode'] != expected:
            raise ValueError('Application theme changed elsewhere. Refresh before switching.')
        old = {key: setting('get', key) for key in ('color-scheme', 'gtk-theme')}
        desired = {'color-scheme': 'prefer-dark' if mode == 'dark' else 'prefer-light',
                   'gtk-theme': 'Adwaita-dark' if mode == 'dark' else 'Adwaita'}
        changes = {}
        for version in ('3.0', '4.0'):
            path = config / ('gtk-' + version) / 'settings.ini'
            changes[path] = gtk_file(path.read_text() if path.exists() else '', mode)
        path = config / 'uwsm/env-hyprland'
        changes[path] = environment(path.read_text() if path.exists() else '')
        changes[config / 'hyprshell/theme.json'] = json.dumps(data, indent=2) + '\n'
        previous = {path: path.read_text() if path.exists() else None for path in changes}
        if all(previous[path] == text for path, text in changes.items()) and all(old[key] == "'" + value + "'" for key, value in desired.items()):
            return activate_qt(mode)
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
                setting('set', key, value)
                if setting('get', key) != "'" + value + "'":
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
        return activate_qt(mode)


def activate_qt(mode):
    # UWSM launches apps through the user manager. Existing applications may
    # need reopening; the saved UWSM environment also covers the next login.
    try:
        result = subprocess.run(['systemctl', '--user', 'set-environment', 'QT_QPA_PLATFORMTHEME=gtk3'], capture_output=True, text=True, timeout=10)
        qt_ready = result.returncode == 0
    except (OSError, subprocess.SubprocessError):
        qt_ready = False
    message = 'Application theme set to ' + mode.capitalize() + '. Reopen apps that do not update automatically.'
    if not qt_ready:
        message += ' Qt integration will activate at your next login.'
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
            result = apply(data['mode'])
        else:
            request = json.loads(args.request_json or '{}')
            if request.get('operation') == 'status':
                result = status()
            elif request.get('operation') == 'save':
                result = apply(request['mode'], request['expected'])
            else:
                raise ValueError('Unknown appearance action')
    except Exception as error:
        print(json.dumps({'ok': False, 'message': str(error)}))
        return 1
    print(json.dumps(result))
    return 0


if __name__ == '__main__':
    sys.exit(main())
