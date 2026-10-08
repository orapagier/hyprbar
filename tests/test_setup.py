"""Exercise actual config installs in isolated homes; never invoke pacman or sudo."""
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='hyprshell-test-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.home = self.root / 'desktop home'
        self.config = self.home / 'custom config'
        self.state = self.home / 'custom state'
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.config),
                        XDG_STATE_HOME=str(self.state), PYTHONDONTWRITEBYTECODE='1')

    def run_setup(self, *args, check=True):
        return subprocess.run(['bash', str(ROOT / 'setup.sh'), *args],
                              env=self.env, text=True, capture_output=True, check=check)

    def install(self):
        return self.run_setup('--config-only')

    def test_preview_has_no_side_effects_for_both_modes_and_option_orders(self):
        for args in (('--dry-run',), ('--config-only', '--dry-run'),
                     ('--dry-run', '--config-only')):
            result = self.run_setup(*args)
            self.assertIn('Preview only', result.stdout)
            self.assertFalse(self.home.exists())

    def mock_package_database(self, missing=()):
        mock_bin = self.root / 'package commands'
        mock_bin.mkdir()
        calls = self.root / 'package-calls.jsonl'
        pacman = mock_bin / 'pacman'
        pacman.write_text(
            '#!/usr/bin/env python3\nimport json, sys\n'
            f'with open({str(calls)!r}, "a") as log:\n'
            '    log.write(json.dumps(sys.argv[1:]) + "\\n")\n'
            'if sys.argv[1] != "-T": raise SystemExit("unexpected mutation")\n'
            f'missing = set({list(missing)!r})\n'
            'result = [p for p in sys.argv[2:] if p in missing]\n'
            'if result: print("\\n".join(result))\n'
            'raise SystemExit(127 if result else 0)\n')
        pacman.chmod(0o755)
        self.env['PATH'] = str(mock_bin) + os.pathsep + self.env['PATH']
        return calls

    def test_fresh_install_preview_checks_core_first_and_reports_missing_packages(self):
        calls = self.mock_package_database(('hyprland', 'quickshell', 'upower', 'wpa_supplicant'))
        result = self.run_setup('--dry-run')
        queries = [json.loads(line) for line in calls.read_text().splitlines()]
        self.assertEqual(queries[:2], [['-T', 'hyprland'], ['-T', 'quickshell']])
        self.assertIn('hyprland: missing', result.stdout)
        self.assertIn('quickshell: missing', result.stdout)
        self.assertIn('Missing desktop packages: hyprland quickshell wpa_supplicant upower', result.stdout)
        targets = queries[2][1:]
        for required in ('hyprpolkitagent', 'qt6-wayland', 'gcc', 'libpulse', 'fftw',
                         'pipewire-pulse', 'upower', 'wpa_supplicant', 'ttf-go-nerd'):
            self.assertIn(required, targets)
        for unrelated in ('brave-bin', 'firefox', 'chromium', 'yay', 'waybar', 'mako',
                          'rofi', 'fuzzel', 'cosmic-greeter', 'base-devel'):
            self.assertNotIn(unrelated, targets)
        self.assertIn('Timezone: unchanged', result.stdout)
        self.assertNotIn('Login screen:', result.stdout)
        self.assertFalse(self.home.exists())

    def test_satisfied_dependencies_and_providers_are_kept(self):
        self.mock_package_database()
        result = self.run_setup('--dry-run')
        self.assertIn('hyprland: installed', result.stdout)
        self.assertIn('quickshell: installed', result.stdout)
        self.assertIn('All desktop packages are installed.', result.stdout)
        self.assertNotIn('Missing desktop packages:', result.stdout)

    def test_fallback_greeter_and_timezone_require_explicit_options(self):
        calls = self.mock_package_database()
        result = self.run_setup('--dry-run', '--with-fallback', '--with-greeter',
                                '--timezone', 'Europe/London')
        targets = json.loads(calls.read_text().splitlines()[-1])[1:]
        for package in ('waybar', 'mako', 'rofi', 'fuzzel', 'python-gobject', 'gtk-layer-shell'):
            self.assertIn(package, targets)
        self.assertIn('Login screen:', result.stdout)
        self.assertIn('Timezone: Europe/London', result.stdout)
        self.assertNotIn('brave-bin', result.stdout)
        self.assertFalse(self.home.exists())

    def test_package_database_failure_stops_before_installing(self):
        self.mock_package_database()
        mock_pacman = Path(self.env['PATH'].split(os.pathsep)[0]) / 'pacman'
        mock_pacman.write_text('#!/bin/sh\nexit 1\n')
        result = self.run_setup('--dry-run', check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Could not query', result.stderr)
        self.assertFalse(self.home.exists())

    @unittest.skipUnless(Path('/etc/arch-release').is_file() and os.geteuid() != 0
                         and Path('/usr/lib/qt6/bin/qmltestrunner').is_file(),
                         'Full installer smoke test needs Arch, Qt 6, and a normal user')
    def test_full_install_with_mocked_packages_and_services_and_no_user_bus(self):
        self.mock_package_database(('hyprland', 'quickshell', 'wpa_supplicant', 'upower'))
        mock_bin = Path(self.env['PATH'].split(os.pathsep)[0])
        calls = self.root / 'system-calls.jsonl'
        # Never execute privileged operations, start services, or alter font caches.
        for name in ('sudo', 'systemctl', 'fc-cache', 'xdg-user-dirs-update'):
            program = mock_bin / name
            program.write_text(
                '#!/usr/bin/env python3\nimport json, sys\n'
                f'with open({str(calls)!r}, "a") as log:\n'
                f'    log.write(json.dumps([{name!r}] + sys.argv[1:]) + "\\n")\n'
                'raise SystemExit(1 if sys.argv[1:] == ["--user", "daemon-reload"] else 0)\n')
            program.chmod(0o755)
        result = self.run_setup()
        commands = [json.loads(line) for line in calls.read_text().splitlines()]
        installs = [c for c in commands if c[:2] == ['sudo', 'pacman']]
        self.assertEqual(installs, [['sudo', 'pacman', '-Syu', '--needed', '--noconfirm',
                                     'hyprland', 'quickshell', 'wpa_supplicant', 'upower']])
        self.assertIn(['sudo', 'systemctl', 'enable', '--now',
                       'NetworkManager.service', 'bluetooth.service'], commands)
        self.assertIn(['sudo', 'systemctl', 'start', 'upower.service'], commands)
        self.assertIn(['systemctl', '--user', '--root=/', '--no-reload', 'enable',
                       'pipewire.socket', 'pipewire-pulse.socket', 'wireplumber.service'], commands)
        self.assertFalse(any('timedatectl' in c or 'cosmic-greeter' in c for c in commands))
        self.assertIn('will start at the next login', result.stdout)
        self.assertIn('Setup complete', result.stdout)
        self.assertTrue((self.config / 'quickshell/helpers/audio-spectrum').is_file())
        self.assertIn('float-modal-dialogs', (self.config / 'hypr/hyprland.lua').read_text())

    def test_installs_complete_payload_and_rendered_user_service(self):
        self.install()
        self.assertEqual((self.config / 'waybar/style.css').read_bytes(),
                         (ROOT / 'config/waybar/style.css').read_bytes())
        self.assertTrue(os.access(self.config / 'hypr/wallpaper-start.sh', os.X_OK))
        self.assertTrue(os.access(self.config / 'hypr/app-launcher.sh', os.X_OK))
        self.assertTrue((self.config / 'quickshell/shell.qml').is_file())
        self.assertTrue(os.access(self.config / 'quickshell/helpers/audio-spectrum', os.X_OK))
        for script in ('app-launcher', 'start-quickshell-bar', 'cleanup-old-launchers'):
            self.assertTrue(os.access(self.home / '.local/bin' / script, os.X_OK))
        self.assertTrue((self.config / 'hypr/rofi-controls.lua').is_file())
        for name in ('config.rasi', 'glass.rasi'):
            self.assertEqual((self.config / 'rofi' / name).read_bytes(),
                             (ROOT / 'config/rofi' / name).read_bytes())
        self.assertEqual((self.config / 'mako/config').read_bytes(),
                         (ROOT / 'config/mako/config').read_bytes())
        self.assertTrue(os.access(self.config / 'waybar/wifi-menu.sh', os.X_OK))
        service = (self.config / 'systemd/user/waybar-notification-monitor.service').read_text()
        self.assertIn(f'"{self.config}/waybar/notification-monitor.py"', service)
        self.assertEqual(len(list((self.home / 'Pictures/Wallpapers').glob('*.jpg'))), 7)
        self.assertFalse(self.state.exists())

    def test_rerun_keeps_identical_configs_without_unnecessary_backups(self):
        self.install()
        result = self.install()
        self.assertIn('Unchanged:', result.stdout)
        self.assertNotIn('Installed:', result.stdout)
        self.assertFalse(self.state.exists())

    def test_installed_launcher_uses_custom_config_paths_and_preserves_arguments(self):
        self.install()
        mock_bin = self.root / 'mock bin'
        mock_bin.mkdir()
        mock_rofi = mock_bin / 'rofi'
        mock_rofi.write_text('#!/usr/bin/python3\nimport json, sys\nprint(json.dumps(sys.argv[1:]))\n')
        mock_rofi.chmod(0o755)
        env = dict(self.env, PATH=str(mock_bin) + os.pathsep + self.env['PATH'])
        output = subprocess.check_output(
            [str(self.config / 'hypr/app-launcher.sh'), '-filter', 'app with spaces'],
            env=env, text=True)
        args = json.loads(output)
        self.assertEqual(args[:6], [
            '-config', str(self.config / 'rofi/config.rasi'),
            '-show', 'drun', '-monitor', '-1'])
        self.assertEqual(args[6], '-theme-str')
        self.assertIn('glass: rgba(', args[7])
        self.assertEqual(args[8:], ['-filter', 'app with spaces'])

        text = (self.config / 'hypr/hyprland.lua').read_text()
        command = re.search(r"^local menu\s*=\s*'([^']+)'", text, re.MULTILINE)[1]
        words = subprocess.check_output(
            ['bash', '-c', 'set -- ' + command + '; printf "%s\\0" "$@"'], env=self.env)
        self.assertEqual(words.decode().split('\0')[:-1],
                         ['uwsm', 'app', '--', str(self.home / '.local/bin/app-launcher')])

    def test_changes_are_backed_up_and_unrelated_files_are_preserved(self):
        self.install()
        style = self.config / 'waybar/style.css'
        style.write_text('/* previous theme */\n')
        mako = self.config / 'mako/config'
        mako.write_text('max-visible=5\n')
        unrelated = self.config / 'unrelated-app/settings'
        unrelated.parent.mkdir()
        unrelated.write_text('keep me')
        self.install()
        backups = list((self.state / 'hyprshell/backups').iterdir())
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / 'config/waybar/style.css').read_text(),
                         '/* previous theme */\n')
        self.assertEqual((backups[0] / 'config/mako/config').read_text(), 'max-visible=5\n')
        self.assertEqual(mako.read_bytes(), (ROOT / 'config/mako/config').read_bytes())
        self.assertEqual(unrelated.read_text(), 'keep me')
        self.install()
        self.assertEqual(list((self.state / 'hyprshell/backups').iterdir()), backups)

    def test_symlink_config_is_backed_up_without_modifying_its_target(self):
        self.config.mkdir(parents=True)
        original = self.root / 'original waybar'
        original.mkdir()
        (original / 'style.css').write_text('keep original')
        (self.config / 'waybar').symlink_to(original, target_is_directory=True)
        self.install()
        self.assertEqual((original / 'style.css').read_text(), 'keep original')
        self.assertFalse((self.config / 'waybar').is_symlink())
        backups = list((self.state / 'hyprshell/backups').glob('*/config/waybar'))
        self.assertEqual(len(backups), 1)
        self.assertTrue(backups[0].is_symlink())

    def test_waybar_commands_expand_to_installed_files_with_spaces_in_paths(self):
        self.install()
        text = (self.config / 'waybar/config.jsonc').read_text()
        pattern = r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/'
        config = json.loads(re.sub(pattern, lambda m: m[0] if m[0].startswith('"') else '', text))
        count = 0
        for module in config.values():
            if not isinstance(module, dict):
                continue
            for key in ('exec', 'on-click'):
                command = module.get(key)
                if command:
                    # Expand the command's words without running any programs.
                    result = subprocess.check_output(['bash', '-c',
                        'set -- ' + command + '; printf "%s\\0" "$@"'], env=self.env)
                    paths = [p.decode() for p in result.split(b'\0')
                             if b'/waybar/' in p or b'/hypr/' in p]
                    self.assertEqual(len(paths), 1)
                    self.assertTrue(Path(paths[0]).is_file(), command)
                    count += 1
        self.assertEqual(count, 9)

    def test_unit_path_escaping(self):
        spec = importlib.util.spec_from_file_location('installer', ROOT / 'tools/install_configs.py')
        installer = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(installer)
        self.assertEqual(installer.systemd_quote('/home/a%u/$name/"config"'),
                         '"/home/a%%u/$$name/\\"config\\""')

    def test_invalid_options_fail_before_installing(self):
        for args in (('--wat',), ('--timezone',)):
            self.assertNotEqual(self.run_setup(*args, check=False).returncode, 0)
        self.assertFalse(self.home.exists())


if __name__ == '__main__':
    unittest.main()
