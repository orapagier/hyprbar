"""Scoped legacy GTK appearance and authenticated GParted launch, without GUI/root."""
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('themed_app', str(ROOT / 'bin/hyprshell-themed-app'))
spec = importlib.util.spec_from_loader(loader.name, loader)
helper = importlib.util.module_from_spec(spec)
loader.exec_module(helper)


class ThemedAppTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.config = Path(temporary.name)
        (self.config / 'hyprshell').mkdir()
        self.path = self.config / 'hyprshell/theme.json'
        env = patch.dict(os.environ, XDG_CONFIG_HOME=str(self.config), DISPLAY=':1')
        env.start(); self.addCleanup(env.stop)

    def mode(self, value):
        self.path.write_text(json.dumps({'version': 1, 'mode': value}))

    def test_xfce_about_receives_selected_theme_and_keeps_argument_boundaries(self):
        for mode in ('dark', 'light'):
            self.mode(mode)
            with patch.object(helper.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as run:
                self.assertEqual(helper.launch('xfce4-about', ['--help']), 0)
            self.assertEqual(run.call_args.args[0], ['/usr/bin/xfce4-about', '--help'])
            self.assertEqual(run.call_args.kwargs['env']['GTK_THEME'], 'Adwaita:dark' if mode == 'dark' else 'Adwaita')

    def test_gparted_passes_fixed_theme_after_authentication_and_revokes_access(self):
        self.mode('dark')
        with patch.object(helper.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, 'access control enabled\n', '')) as run:
            helper.launch('gparted', ['/dev/disk with spaces'])
        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(commands, [['xhost'], ['xhost', '+SI:localuser:root'],
            ['pkexec', '/usr/bin/env', 'DISPLAY=:1', 'GDK_BACKEND=x11', 'GTK_THEME=Adwaita:dark', '/usr/bin/gparted', '/dev/disk with spaces'],
            ['xhost', '-SI:localuser:root']])

    def test_existing_root_display_permission_is_preserved(self):
        self.mode('light')
        with patch.object(helper.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, 'SI:localuser:root\n', '')) as run:
            helper.launch('gparted', [])
        self.assertEqual(len(run.call_args_list), 2)
        self.assertIn('GTK_THEME=Adwaita', run.call_args_list[1].args[0])

    def test_authentication_error_or_cancellation_still_revokes_permission(self):
        self.mode('dark')
        for raised in (False, True):
            def run(command, **kwargs):
                if command[0] == 'pkexec' and raised:
                    raise OSError('Could not authenticate')
                return subprocess.CompletedProcess(command, 126 if command[0] == 'pkexec' else 0, '', '')
            with patch.object(helper.subprocess, 'run', side_effect=run) as mock:
                if raised:
                    with self.assertRaises(OSError): helper.launch('gparted', [])
                else:
                    self.assertEqual(helper.launch('gparted', []), 126)
            self.assertEqual(mock.call_args.args[0], ['xhost', '-SI:localuser:root'])

    def test_without_saved_mode_uses_upstream_launch_unchanged(self):
        with patch.object(helper.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as run:
            helper.launch('gparted', [])
        self.assertEqual(run.call_args.args[0], ['/usr/bin/gparted'])

    def test_unsupported_app_or_invalid_theme_never_executes(self):
        self.path.write_text('{"version":1,"mode":"invalid"}')
        with patch.object(helper.subprocess, 'run') as run:
            with self.assertRaises(ValueError): helper.launch('gparted', [])
            with self.assertRaises(ValueError): helper.launch('/usr/bin/sh', [])
        run.assert_not_called()
