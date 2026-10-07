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
        self.temporary = tempfile.TemporaryDirectory(prefix='hyprbar-test-')
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

    def test_installs_complete_payload_and_rendered_user_service(self):
        self.install()
        self.assertEqual((self.config / 'waybar/style.css').read_bytes(),
                         (ROOT / 'config/waybar/style.css').read_bytes())
        self.assertTrue(os.access(self.config / 'hypr/wallpaper-start.sh', os.X_OK))
        self.assertTrue(os.access(self.config / 'hypr/app-launcher.sh', os.X_OK))
        self.assertTrue((self.config / 'hypr/rofi-controls.lua').is_file())
        for name in ('config.rasi', 'glass.rasi'):
            self.assertEqual((self.config / 'rofi' / name).read_bytes(),
                             (ROOT / 'config/rofi' / name).read_bytes())
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
                         ['uwsm', 'app', '--', str(self.config / 'hypr/app-launcher.sh')])

    def test_changes_are_backed_up_and_unrelated_files_are_preserved(self):
        self.install()
        style = self.config / 'waybar/style.css'
        style.write_text('/* previous theme */\n')
        unrelated = self.config / 'unrelated-app/settings'
        unrelated.parent.mkdir()
        unrelated.write_text('keep me')
        self.install()
        backups = list((self.state / 'hyprbar/backups').iterdir())
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / 'config/waybar/style.css').read_text(),
                         '/* previous theme */\n')
        self.assertEqual(unrelated.read_text(), 'keep me')
        self.install()
        self.assertEqual(list((self.state / 'hyprbar/backups').iterdir()), backups)

    def test_symlink_config_is_backed_up_without_modifying_its_target(self):
        self.config.mkdir(parents=True)
        original = self.root / 'original waybar'
        original.mkdir()
        (original / 'style.css').write_text('keep original')
        (self.config / 'waybar').symlink_to(original, target_is_directory=True)
        self.install()
        self.assertEqual((original / 'style.css').read_text(), 'keep original')
        self.assertFalse((self.config / 'waybar').is_symlink())
        backups = list((self.state / 'hyprbar/backups').glob('*/config/waybar'))
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
