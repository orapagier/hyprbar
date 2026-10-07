"""Exercise actual D-Bus monitoring with two deliveries on an isolated bus."""
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
NAME = 'org.freedesktop.Notifications'
SERVER = '''
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
name = dbus.service.BusName('org.freedesktop.Notifications', bus)
class Notifications(dbus.service.Object):
    next_id = 0
    @dbus.service.method('org.freedesktop.Notifications',
                         in_signature='susssasa{sv}i', out_signature='u')
    def Notify(self, app, replaces, icon, summary, body, actions, hints, timeout):
        self.next_id += 1
        return self.next_id
server = Notifications(name, '/org/freedesktop/Notifications')
GLib.MainLoop().run()
'''


def wait_until(predicate, description):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(.02)
    raise AssertionError('Timed out waiting for ' + description)


def exercise():
    import dbus
    spec = importlib.util.spec_from_file_location('notification_store', ROOT / 'notification-store.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    store = module.Store()
    children = []
    try:
        server = subprocess.Popen([sys.executable, '-c', SERVER])
        children.append(server)
        bus = dbus.SessionBus()
        wait_until(lambda: bus.name_has_owner(NAME), 'notification service')
        monitor = subprocess.Popen([sys.executable, str(ROOT / 'notification-monitor.py')])
        children.append(monitor)
        wait_until(lambda: bool(store.metadata('heartbeat')), 'monitor startup')
        notifications = dbus.Interface(bus.get_object(NAME, '/org/freedesktop/Notifications'), NAME)
        for number in (1, 2):
            bus_id = notifications.Notify('Bell test', dbus.UInt32(0), '', f'Test {number}', 'Body',
                                          dbus.Array([], signature='s'),
                                          dbus.Dictionary({}, signature='sv'), dbus.Int32(-1))
            wait_until(lambda: any(row['bus_id'] == bus_id for row in store.rows()),
                       f'notification {number} and its reply')
            assert monitor.poll() is None, 'Monitor exited after a delivery'
        assert len(store.rows()) == 2
        assert store.status()['class'] == 'unread'
    finally:
        for child in reversed(children):
            child.terminate()
            try:
                child.wait(timeout=3)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
        store.db.close()


@unittest.skipUnless(shutil.which('dbus-run-session'), 'dbus-run-session is required')
class NotificationDeliveryTests(unittest.TestCase):
    def test_two_notifications_and_replies_arrive_without_disconnecting_monitor(self):
        with tempfile.TemporaryDirectory(prefix='hyprbar-notifications-') as directory:
            runtime = Path(directory) / 'runtime'
            runtime.mkdir(mode=0o700)
            env = dict(os.environ, XDG_STATE_HOME=str(Path(directory) / 'state'),
                       XDG_RUNTIME_DIR=str(runtime))
            result = subprocess.run(['dbus-run-session', '--', sys.executable, str(Path(__file__).resolve()),
                                     '--exercise'], env=env, text=True, capture_output=True, timeout=20)
            if result.returncode == 127 and 'Failed to bind socket' in result.stderr and 'Operation not permitted' in result.stderr:
                self.skipTest('Sandbox does not permit an isolated D-Bus socket')
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    if '--exercise' in sys.argv:
        exercise()
    else:
        unittest.main()
