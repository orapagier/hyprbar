"""Exercise actual config installs in isolated homes; never invoke pacman or sudo."""
import json
import os
from pathlib import Path
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
                         'pipewire-pulse', 'upower', 'wpa_supplicant', 'ttf-go-nerd', 'nautilus'):
            self.assertIn(required, targets)
        for unrelated in ('brave-bin', 'firefox', 'chromium', 'yay', 'waybar', 'mako',
                          'rofi', 'fuzzel', 'cosmic-greeter', 'base-devel',
                          'thunar', 'thunar-volman', 'thunar-archive-plugin'):
            self.assertNotIn(unrelated, targets)
        self.assertIn('Timezone: unchanged', result.stdout)
        self.assertIn('Login screen:', result.stdout)
        self.assertFalse(self.home.exists())

    def test_satisfied_dependencies_and_providers_are_kept(self):
        self.mock_package_database()
        result = self.run_setup('--dry-run')
        self.assertIn('hyprland: installed', result.stdout)
        self.assertIn('quickshell: installed', result.stdout)
        self.assertIn('All desktop packages are installed.', result.stdout)
        self.assertNotIn('Missing desktop packages:', result.stdout)

    def test_timezone_requires_explicit_option(self):
        calls = self.mock_package_database()
        result = self.run_setup('--dry-run',
                                '--timezone', 'Europe/London')
        targets = json.loads(calls.read_text().splitlines()[-1])[1:]
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

    def test_daily_driver_apps_are_included_and_shared_packages_are_unique(self):
        calls = self.mock_package_database(('chromium', 'hypridle', 'wl-clipboard'))
        result = self.run_setup('--dry-run', '--extra')
        targets = json.loads(calls.read_text().splitlines()[-1])[1:]
        for package in ('chromium', 'hyprlock', 'hypridle', 'cmatrix', 'man-db',
                        'man-pages', 'bash-completion', 'unzip', 'zip', '7zip',
                        'file-roller', 'pacman-contrib', 'wl-clipboard', 'playerctl',
                        'xdg-utils', 'gvfs-mtp',
                        'mpv', 'imv', 'evince', 'mousepad'):
            self.assertIn(package, targets)
        self.assertEqual(len(targets), len(set(targets)))
        self.assertIn('Missing desktop packages: chromium hypridle wl-clipboard', result.stdout)
        self.assertFalse(self.home.exists())

    def test_skip_browser_excludes_chromium_in_either_option_order(self):
        calls = self.mock_package_database()
        for args in (('--extra', '--skip-browser'),
                     ('--skip-browser', '--extra')):
            self.run_setup('--dry-run', *args)
            targets = json.loads(calls.read_text().splitlines()[-1])[1:]
            self.assertNotIn('chromium', targets)
            self.assertIn('hyprlock', targets)
        self.assertFalse(self.home.exists())

    def test_config_only_with_apps_does_not_query_or_plan_packages(self):
        calls = self.mock_package_database()
        result = self.run_setup('--dry-run', '--config-only', '--extra')
        self.assertFalse(calls.exists())
        self.assertNotIn('Full Arch upgrade', result.stdout)
        self.assertFalse(self.home.exists())

    @unittest.skipUnless(Path('/etc/arch-release').is_file() and os.geteuid() != 0
                         and Path('/usr/lib/qt6/bin/qmltestrunner').is_file(),
                         'Full installer smoke test needs Arch, Qt 6, and a normal user')
    def test_full_install_with_mocked_packages_and_services_and_no_user_bus(self):
        self.mock_package_database(('hyprland', 'quickshell', 'wpa_supplicant', 'upower'))
        mock_bin = Path(self.env['PATH'].split(os.pathsep)[0])
        calls = self.root / 'system-calls.jsonl'
        # Never execute privileged operations, start services, or alter font caches.
        for name in ('sudo', 'systemctl', 'fc-cache', 'xdg-user-dirs-update', 'nautilus'):
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
        self.assertEqual(installs[0], ['sudo', 'pacman', '-Syu', '--needed', '--noconfirm',
                                     'hyprland', 'quickshell', 'wpa_supplicant', 'upower'])
        if ['sudo', 'pacman', '-S', '--needed', '--noconfirm', 'sddm'] in installs:
            self.assertIn(['sudo', 'systemctl', 'enable', 'sddm.service'], commands)
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

    def test_installs_current_payload_without_legacy_configs(self):
        self.install()
        self.assertTrue(os.access(self.config / 'hypr/wallpaper-start.sh', os.X_OK))
        self.assertTrue((self.config / 'quickshell/shell.qml').is_file())
        self.assertEqual((self.config / 'autostart/nm-applet.desktop').read_bytes(),
                         (ROOT / 'config/autostart/nm-applet.desktop').read_bytes())
        self.assertIn('uwsm app -- nautilus --new-window',
                      (self.config / 'hypr/hyprland.lua').read_text())
        self.assertTrue(os.access(self.config / 'quickshell/helpers/audio-spectrum', os.X_OK))
        for script in ('app-launcher', 'start-quickshell-bar'):
            self.assertTrue(os.access(self.home / '.local/bin' / script, os.X_OK))
        for name in ('waybar', 'mako', 'rofi', 'fuzzel', 'systemd'):
            self.assertFalse((self.config / name).exists())
        self.assertEqual(len(list((self.home / 'Pictures/Wallpapers').glob('*.jpg'))), 8)
        self.assertEqual((self.home / 'Pictures/Wallpapers/default.jpg').read_bytes(),
                         (ROOT / 'assets/wallpapers/default.jpg').read_bytes())
        self.assertIn('Wallpapers/default.jpg',
                      (self.config / 'hypr/wallpaper-start.sh').read_text())
        self.assertFalse((self.state / "hyprshell/backups").exists())
        self.assertEqual((self.state / "hyprshell/repository").read_text().strip(), str(ROOT))

    def test_rerun_keeps_identical_configs_without_unnecessary_backups(self):
        self.install()
        result = self.install()
        self.assertIn('Unchanged:', result.stdout)
        self.assertNotIn('Installed:', result.stdout)
        self.assertFalse((self.state / "hyprshell/backups").exists())
        self.assertEqual((self.state / "hyprshell/repository").read_text().strip(), str(ROOT))

    def test_changes_are_backed_up_and_unrelated_files_are_preserved(self):
        self.install()
        style = self.config / 'hypr/hyprland.lua'
        style.write_text('/* previous theme */\n')
        portal = self.config / 'xdg-desktop-portal/hyprland-portals.conf'
        portal.write_text('[preferred]\ndefault=gtk\n')
        unrelated = self.config / 'unrelated-app/settings'
        unrelated.parent.mkdir()
        unrelated.write_text('keep me')
        applet = self.config / 'autostart/nm-applet.desktop'
        applet.write_text('[Desktop Entry]\nHidden=false\n')
        other_autostart = self.config / 'autostart/other-app.desktop'
        other_autostart.write_text('[Desktop Entry]\nExec=other-app\n')
        self.install()
        backups = list((self.state / 'hyprshell/backups').iterdir())
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / 'config/hypr/hyprland.lua').read_text(),
                         '/* previous theme */\n')
        self.assertEqual((backups[0] / 'config/xdg-desktop-portal/hyprland-portals.conf').read_text(), '[preferred]\ndefault=gtk\n')
        self.assertEqual(portal.read_bytes(), (ROOT / 'config/xdg-desktop-portal/hyprland-portals.conf').read_bytes())
        self.assertEqual(unrelated.read_text(), 'keep me')
        self.assertEqual((backups[0] / 'config/autostart/nm-applet.desktop').read_text(),
                         '[Desktop Entry]\nHidden=false\n')
        self.assertEqual(applet.read_bytes(),
                         (ROOT / 'config/autostart/nm-applet.desktop').read_bytes())
        self.assertEqual(other_autostart.read_text(), '[Desktop Entry]\nExec=other-app\n')
        self.install()
        self.assertEqual(list((self.state / 'hyprshell/backups').iterdir()), backups)

    def test_symlink_config_is_backed_up_without_modifying_its_target(self):
        self.config.mkdir(parents=True)
        original = self.root / 'original hypr'
        original.mkdir()
        (original / 'hyprland.lua').write_text('keep original')
        (self.config / 'hypr').symlink_to(original, target_is_directory=True)
        self.install()
        self.assertEqual((original / 'hyprland.lua').read_text(), 'keep original')
        self.assertFalse((self.config / 'hypr').is_symlink())
        backups = list((self.state / 'hyprshell/backups').glob('*/config/hypr'))
        self.assertEqual(len(backups), 1)
        self.assertTrue(backups[0].is_symlink())

    def test_invalid_options_fail_before_installing(self):
        for args in (('--wat',), ('--timezone',)):
            self.assertNotEqual(self.run_setup(*args, check=False).returncode, 0)
        self.assertFalse(self.home.exists())


if __name__ == '__main__':
    unittest.main()
