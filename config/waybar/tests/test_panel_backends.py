"""Backend regressions that run without a desktop or Bluetooth hardware."""
import importlib.util
from pathlib import Path
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), ROOT / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


store_module = load('notification-store')
monitor_module = load('notification-monitor')
bluetooth = load('bluetooth-popup')
notifications = load('notifications-popup')


class Message:
    def __init__(self, kind, args, sender=':1.20', serial=1, destination=None, reply_serial=0,
                 interface=monitor_module.NAME, member='Notify'):
        self.kind, self.args = kind, args
        self.sender, self.serial = sender, serial
        self.destination, self.reply_serial = destination, reply_serial
        self.interface, self.member = interface, member

    def get_type(self): return self.kind
    def get_args_list(self): return self.args
    def get_sender(self): return self.sender
    def get_serial(self): return self.serial
    def get_destination(self): return self.destination
    def get_reply_serial(self): return self.reply_serial
    def get_interface(self): return self.interface
    def get_member(self): return self.member


class InboxTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.path = Path(self.temporary.name) / 'inbox.db'
        self.store = store_module.Store(self.path)
        self.monitor = monitor_module.Monitor(self.store, ':1.10')

    def tearDown(self):
        self.store.db.close()
        self.temporary.cleanup()

    def notify(self, title='Message', replaces=0, sender=':1.20', serial=1):
        message = Message(1, ['Chat', replaces, '', title, 'Body', ['default', 'Open'], {'transient': True}, 1], sender=sender, serial=serial)
        self.assertTrue(self.monitor.message(None, message))

    def reply(self, bus_id=7, sender=':1.20', serial=1):
        self.assertTrue(self.monitor.message(None, Message(2, [bus_id], sender=':1.10', destination=sender, reply_serial=serial)))

    def test_expired_transient_notifications_remain_after_reopening(self):
        self.notify()
        self.reply()
        self.monitor.message(None, Message(4, [7, 1], sender=':1.10', member='NotificationClosed'))
        reopened = store_module.Store(self.path)
        self.assertEqual(reopened.rows()[0]['summary'], 'Message')
        self.assertEqual(reopened.rows()[0]['active'], 0)
        self.assertEqual(reopened.rows()[0]['unread'], 1)
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)
        reopened.db.close()

    def test_replacements_update_the_same_notification_and_become_unread(self):
        self.notify()
        self.reply()
        self.store.mark_read([self.store.rows()[0]['id']])
        self.notify('Updated message', replaces=7, serial=2)
        self.reply(serial=2)
        self.assertEqual(len(self.store.rows()), 1)
        self.assertEqual(self.store.rows()[0]['summary'], 'Updated message')
        self.assertEqual(self.store.rows()[0]['unread'], 1)

    def test_simultaneous_clients_with_same_serial_receive_correct_ids(self):
        self.notify('First', sender=':1.20')
        self.notify('Second', sender=':1.21')
        self.reply(11, sender=':1.21')
        self.reply(12, sender=':1.20')
        values = {row['summary']: row['bus_id'] for row in self.store.rows()}
        self.assertEqual(values, {'First': 12, 'Second': 11})

    def test_clearing_erases_text_and_does_not_restore_on_import(self):
        self.notify()
        self.reply()
        self.store.dismiss()
        self.assertEqual(self.store.rows(), [])
        row = self.store.db.execute('SELECT * FROM notifications').fetchone()
        self.assertEqual((row['summary'], row['body'], row['actions']), ('', '', '{}'))
        self.assertEqual(row['bus_id'], 7)
        self.notify('New update', replaces=7, serial=2)
        self.assertEqual(self.store.rows()[0]['summary'], 'New update')

    def test_restart_does_not_confuse_reused_notification_ids(self):
        self.notify()
        self.reply()
        self.monitor.message(None, Message(4, [monitor_module.NAME, ':1.10', ':1.30'], interface='org.freedesktop.DBus', member='NameOwnerChanged'))
        self.notify('After daemon restart', replaces=7, serial=2)
        self.assertEqual(len(self.store.rows()), 2)
        original = next(row for row in self.store.rows() if row['summary'] == 'Message')
        self.assertEqual(original['active'], 0)

    def test_unread_count_search_and_monitor_health(self):
        self.notify('Project reminder')
        self.store.metadata('heartbeat', time.time())
        self.assertEqual(self.store.status()['class'], 'unread')
        self.assertEqual(len(self.store.rows('PROJECT')), 1)
        self.store.mark_read(row['id'] for row in self.store.rows())
        self.assertEqual(self.store.status()['class'], 'empty')
        self.store.metadata('heartbeat', 0)
        self.assertEqual(self.store.status()['class'], 'offline')

    def test_new_login_keeps_inbox_when_bus_names_and_ids_repeat(self):
        self.monitor.scope = 'first-session'
        self.notify('Before logout')
        self.reply()
        self.monitor.scope = 'next-session'
        self.notify('After login', replaces=7, serial=2)
        self.reply(serial=2)
        self.assertEqual(len(self.store.rows()), 2)


class BluetoothTests(unittest.TestCase):
    def test_devices_are_scoped_sorted_and_searchable(self):
        objects = {
            '/a/one': {bluetooth.DEVICE: {'Adapter': '/a', 'Alias': 'Speaker', 'Connected': True, 'Paired': True}, 'org.bluez.Battery1': {'Percentage': 70}},
            '/a/two': {bluetooth.DEVICE: {'Adapter': '/a', 'Alias': 'Keyboard', 'Paired': True}},
            '/a/three': {bluetooth.DEVICE: {'Adapter': '/a', 'Alias': 'Available headset'}},
            '/b/four': {bluetooth.DEVICE: {'Adapter': '/b', 'Alias': 'Other adapter'}},
        }
        rows = bluetooth.device_rows(objects, '/a')
        self.assertEqual([row['name'] for row in rows], ['Speaker', 'Keyboard', 'Available headset'])
        self.assertEqual(rows[0]['battery'], 70)
        self.assertEqual(len(bluetooth.device_rows(objects, '/a', 'KEYBOARD')), 1)
        self.assertEqual(bluetooth.device_rows({}, '/a'), [])

    def test_notification_markup_is_displayed_as_plain_text(self):
        self.assertEqual(notifications.plain('<b>Hello</b><br>Tom &amp; Jane'), 'Hello\nTom & Jane')


if __name__ == '__main__':
    unittest.main()
