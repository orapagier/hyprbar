#!/usr/bin/env python3
"""Capture every desktop Notify call for the bell while Mako handles delivery."""
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

_spec = importlib.util.spec_from_file_location('notification_store', Path(__file__).with_name('notification-store.py'))
_store = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_store)
Store = _store.Store
NAME = 'org.freedesktop.Notifications'


class Monitor:
    def __init__(self, store, owner='', scope=''):
        self.store, self.owner = store, owner
        self.scope = scope
        self.pending = {}

    def owner_key(self, owner=None):
        owner = self.owner if owner is None else owner
        return self.scope + '/' + owner if self.scope else owner

    def message(self, _connection, message):
        kind = message.get_type()
        if kind == dbus.lowlevel.MESSAGE_TYPE_METHOD_CALL and message.get_interface() == NAME and message.get_member() == 'Notify':
            values = message.get_args_list()
            if len(values) != 8:
                return dbus.lowlevel.HANDLER_RESULT_HANDLED
            app, replaces, _icon, summary, body, actions, _hints, _timeout = values
            actions = {str(actions[index]): str(actions[index + 1]) for index in range(0, len(actions) - 1, 2)}
            row_id = self.store.receive(app, summary, body, actions, self.owner_key(), int(replaces))
            self.pending[(message.get_sender(), message.get_serial())] = (row_id, time.monotonic())
            # A client can disconnect without a reply. Bound only this transient
            # correlation map; the inbox itself retains the received message.
            now = time.monotonic()
            self.pending = {key: value for key, value in self.pending.items() if now - value[1] < 120}
        elif kind in (dbus.lowlevel.MESSAGE_TYPE_METHOD_RETURN, dbus.lowlevel.MESSAGE_TYPE_ERROR):
            pending = self.pending.pop((message.get_destination(), message.get_reply_serial()), None)
            if pending and kind == dbus.lowlevel.MESSAGE_TYPE_METHOD_RETURN:
                values = message.get_args_list()
                if values:
                    self.store.identify(pending[0], int(values[0]), self.owner_key(str(message.get_sender())))
        elif kind == dbus.lowlevel.MESSAGE_TYPE_SIGNAL:
            if message.get_interface() == NAME and message.get_member() == 'NotificationClosed':
                self.store.close(int(message.get_args_list()[0]), self.owner_key(str(message.get_sender())))
            elif message.get_member() == 'NameOwnerChanged':
                name, _old, new = message.get_args_list()
                if name == NAME:
                    self.owner = str(new)
                    with self.store.db:
                        self.store.db.execute('UPDATE notifications SET active=0 WHERE owner<>?', (self.owner_key(),))
        # A monitoring connection must never dispatch observed method calls or
        # send a reply on another application's behalf.
        return dbus.lowlevel.HANDLER_RESULT_HANDLED

    def seed(self):
        if not self.owner:
            return
        for command in ('history', 'list'):
            result = subprocess.run(['makoctl', command, '-j'], capture_output=True, text=True, timeout=3)
            if result.returncode:
                continue
            for item in reversed(json.loads(result.stdout)):
                exists = self.store.db.execute('SELECT 1 FROM notifications WHERE owner=? AND bus_id=?', (self.owner_key(), item['id'])).fetchone()
                if not exists:
                    self.store.receive(item.get('app_name') or '', item.get('summary') or '', item.get('body') or '',
                                       item.get('actions') or {}, self.owner_key(), bus_id=int(item['id']), active=command == 'list')
                else:
                    with self.store.db:
                        self.store.db.execute('UPDATE notifications SET active=? WHERE owner=? AND bus_id=?',
                                              (int(command == 'list'), self.owner_key(), item['id']))


def watch(store, connection):
    loop = GLib.MainLoop()
    disconnected = False

    def connection_lost(_connection):
        nonlocal disconnected
        disconnected = True
        store.metadata('heartbeat', 0)
        print('Notification capture: monitoring connection lost; restarting', file=sys.stderr)
        loop.quit()

    connection.call_on_disconnection(connection_lost)

    def heartbeat():
        if not connection.get_is_connected():
            connection_lost(connection)
            return True
        store.metadata('heartbeat', time.time())
        return True

    heartbeat()
    if disconnected:
        return 1
    timer = GLib.timeout_add_seconds(5, heartbeat)

    def stop():
        loop.quit()
        return True

    signals = [GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signum, stop)
               for signum in (signal.SIGINT, signal.SIGTERM)]
    try:
        loop.run()
    finally:
        GLib.source_remove(timer)
        for source in signals:
            GLib.source_remove(source)
        store.metadata('heartbeat', 0)
    return int(disconnected)


def main():
    os.umask(0o077)
    store = Store()
    directory = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'waybar/notifications'
    lock = (directory / 'monitor.lock').open('w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return 0
    DBusGMainLoop(set_as_default=True)
    control = dbus.SessionBus()
    owner = str(control.get_name_owner(NAME)) if control.name_has_owner(NAME) else ''
    scope = str(control.call_blocking('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'GetId', '', ()))
    monitor = Monitor(store, owner, scope)
    with store.db:
        store.db.execute('UPDATE notifications SET active=0')
    connection = dbus.bus.BusConnection(os.environ['DBUS_SESSION_BUS_ADDRESS'])
    connection.add_message_filter(monitor.message)
    rules = [f"type='method_call',interface='{NAME}',member='Notify'",
             f"type='method_return',sender='{NAME}'", f"type='error',sender='{NAME}'",
             f"type='signal',interface='{NAME}',member='NotificationClosed'",
             f"type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged',arg0='{NAME}'"]
    connection.call_blocking('org.freedesktop.DBus', '/org/freedesktop/DBus',
                             'org.freedesktop.DBus.Monitoring', 'BecomeMonitor', 'asu',
                             (dbus.Array(rules, signature='s'), dbus.UInt32(0)))
    try:
        monitor.seed()
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(f'Notification history import: {error}', file=sys.stderr)
    return watch(store, connection)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (dbus.DBusException, OSError) as error:
        print(f'Notification capture: {error}', file=sys.stderr)
        sys.exit(1)
