"""Exercise login installation and rollback without touching system files."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import install_login_theme as login
import install_boot_splash as boot


class LoginThemeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='hyprshell-login-test-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.put('usr/bin/sddm-greeter-qt6', 'test greeter')

    def put(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def test_install_preserves_authentication_and_applies_only_theme_settings(self):
        original = '[Autologin]\nUser=local-user\nSession=hyprland-uwsm\n[General]\nDisplayServer=wayland\n[Theme]\nCurrent=old\nThemeDir=/custom/themes\nCursorSize=28\n'
        config = self.put('etc/sddm.conf', original)
        runner = Mock()
        plan = login.build_login_plan(self.root)
        boot.apply_plan(plan, [], set(), self.root / 'backups', runner, component='Login theme')
        runner.assert_not_called()
        self.assertEqual(config.read_text(), original.replace('Current=old', 'Current=hyprshell-glass').replace('ThemeDir=/custom/themes', 'ThemeDir=/usr/share/sddm/themes'))
        metadata = self.root / 'usr/share/sddm/themes/hyprshell-glass/metadata.desktop'
        self.assertIn('QtVersion=6', metadata.read_text())
        self.assertEqual(len(list((self.root / 'backups').iterdir())), 1)
        boot.apply_plan(login.build_login_plan(self.root), [], set(), self.root / 'backups', runner)
        self.assertEqual(len(list((self.root / 'backups').iterdir())), 1)

    def test_combined_failed_boot_rebuild_restores_sddm_and_kernel_preset(self):
        import json
        original = '[Theme]\nCurrent=old\n'
        config = self.put('etc/sddm.conf', original)
        self.put('etc/mkinitcpio.conf', 'HOOKS=(base udev kms block filesystems)\n')
        preset = self.put('etc/mkinitcpio.d/linux.preset', 'PRESETS=(default)\ndefault_uki="/boot/EFI/Linux/linux.efi"\ndefault_options="--splash /usr/share/systemd/bootctl/splash-arch.bmp"\n')
        original_preset = preset.read_text()
        self.put('etc/kernel/cmdline', 'root=UUID=local rw\n')
        preference = json.loads((ROOT / 'config/boot/plymouth.json').read_text())
        plan, commands, outputs = boot.build_plan(self.root, preference)
        plan.update(login.build_login_plan(self.root))
        runner = Mock(side_effect=subprocess.CalledProcessError(1, ['mkinitcpio', '-P']))
        with self.assertRaises(subprocess.CalledProcessError):
            boot.apply_plan(plan, commands, outputs, self.root / 'backups', runner)
        self.assertEqual(config.read_text(), original)
        self.assertEqual(preset.read_text(), original_preset)
        self.assertFalse((self.root / 'usr/share/sddm/themes/hyprshell-glass/Main.qml').exists())
        self.assertFalse((self.root / 'usr/share/hyprshell/uki-splash.bmp').exists())

    def test_other_login_manager_and_missing_qt6_greeter_are_rejected(self):
        manager = self.root / 'etc/systemd/system/display-manager.service'
        manager.parent.mkdir(parents=True)
        manager.symlink_to('/usr/lib/systemd/system/gdm.service')
        with self.assertRaises(boot.UnsupportedBoot):
            login.build_login_plan(self.root)
        manager.unlink()
        (self.root / 'usr/bin/sddm-greeter-qt6').unlink()
        with self.assertRaises(boot.UnsupportedBoot):
            login.build_login_plan(self.root)
        self.assertFalse((self.root / 'etc/sddm.conf').exists())

    def test_symlinked_config_and_asset_directory_are_rejected(self):
        config = self.root / 'etc/sddm.conf'
        target = self.put('etc/local-sddm.conf', '[Theme]\nCurrent=old\n')
        config.symlink_to(target)
        with self.assertRaises(boot.UnsupportedBoot):
            login.build_login_plan(self.root)
        config.unlink()
        directory = self.root / 'usr/share/sddm/themes'
        directory.parent.mkdir(parents=True)
        directory.symlink_to(self.root / 'other-themes', target_is_directory=True)
        with self.assertRaises(boot.UnsupportedBoot):
            login.build_login_plan(self.root)

    def test_duplicate_settings_are_rejected_and_header_without_newline_is_supported(self):
        self.assertEqual(login.login_config('[Theme]'), '[Theme]\nCurrent=hyprshell-glass\nThemeDir=/usr/share/sddm/themes\n')
        for text in ('[Theme]\nCurrent=a\nCurrent=b\n', '[Theme]\nCurrent=a\n[Theme]\nCurrent=b\n'):
            with self.assertRaises(boot.UnsupportedBoot):
                login.login_config(text)


if __name__ == '__main__':
    unittest.main()
