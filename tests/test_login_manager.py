"""Check login-manager detection without changing the host's services."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class LoginManagerTests(unittest.TestCase):
    def test_preserves_configured_and_installed_managers(self):
        source = (ROOT / 'setup.sh').read_text()
        function = source[source.index('has_login_manager() {'):source.index('check_packages() {')]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            alias = root / 'display-manager.service'
            function = function.replace('/etc/systemd/system/display-manager.service', str(alias))
            systemctl = root / 'systemctl'
            systemctl.write_text('#!/bin/sh\nprintf "%s\\n" "$MANAGER_UNITS"\nexit "${MANAGER_STATUS:-0}"\n')
            systemctl.chmod(0o755)
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH'])
            script = 'set -euo pipefail\ndie() { exit 42; }\n' + function + '\nif has_login_manager; then exit 0; else exit 1; fi'
            for units, status, expected in [
                ('', '0', 1),
                ('sddm.service disabled disabled', '0', 0),
                ('gdm.service enabled disabled', '0', 0),
                ('greetd.service disabled disabled', '0', 0),
                ('unrelated.service enabled enabled', '0', 1),
                ('', '1', 42),
            ]:
                with self.subTest(units=units, status=status):
                    result = subprocess.run(['bash', '-c', script], env=dict(
                        env, MANAGER_UNITS=units, MANAGER_STATUS=status), capture_output=True)
                    self.assertEqual(result.returncode, expected, result.stderr)
            alias.symlink_to(root / 'missing-manager.service')
            result = subprocess.run(['bash', '-c', script], env=dict(
                env, MANAGER_UNITS='', MANAGER_STATUS='1'), capture_output=True)
            self.assertEqual(result.returncode, 0)
