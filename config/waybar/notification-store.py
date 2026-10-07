"""Private, persistent notification inbox shared by the monitor and popup."""
import json
import os
from pathlib import Path
import sqlite3
import time


class Store:
    def __init__(self, path=None):
        if path is None:
            state = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state'))
            directory = state / 'waybar/notifications'
            directory.mkdir(parents=True, exist_ok=True, mode=0o700)
            path = directory / 'inbox.sqlite3'
        self.db = sqlite3.connect(path, timeout=5)
        os.chmod(path, 0o600)
        self.db.row_factory = sqlite3.Row
        self.db.executescript('''
            CREATE TABLE IF NOT EXISTS notifications (
                id INTEGER PRIMARY KEY, bus_id INTEGER, owner TEXT,
                app TEXT, summary TEXT, body TEXT, actions TEXT,
                received REAL, unread INTEGER DEFAULT 1,
                dismissed INTEGER DEFAULT 0, active INTEGER DEFAULT 1);
            CREATE INDEX IF NOT EXISTS notification_bus ON notifications(owner, bus_id);
            CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT);
        ''')

    def receive(self, app, summary, body, actions, owner='', replaces=0, bus_id=None, active=True):
        old = self.db.execute('SELECT id FROM notifications WHERE owner=? AND bus_id=? ORDER BY id DESC LIMIT 1',
                              (owner, replaces)).fetchone() if replaces else None
        values = (str(app), str(summary), str(body), json.dumps(actions), time.time(), int(active))
        with self.db:
            if old:
                self.db.execute('UPDATE notifications SET app=?, summary=?, body=?, actions=?, received=?, active=?, unread=1, dismissed=0 WHERE id=?',
                                (*values, old['id']))
                return old['id']
            cursor = self.db.execute('INSERT INTO notifications (app,summary,body,actions,received,active,owner,bus_id) VALUES (?,?,?,?,?,?,?,?)',
                                     (*values, owner, bus_id))
            return cursor.lastrowid

    def identify(self, row_id, bus_id, owner):
        with self.db:
            self.db.execute('UPDATE notifications SET bus_id=?, owner=? WHERE id=?', (bus_id, owner, row_id))

    def close(self, bus_id, owner):
        with self.db:
            self.db.execute('UPDATE notifications SET active=0 WHERE bus_id=? AND owner=?', (bus_id, owner))

    def rows(self, query=''):
        rows = self.db.execute('SELECT * FROM notifications WHERE dismissed=0 ORDER BY received DESC, id DESC').fetchall()
        query = query.casefold()
        return [dict(row) for row in rows if query in (' '.join((row['app'], row['summary'], row['body']))).casefold()]

    def mark_read(self, ids):
        with self.db:
            self.db.executemany('UPDATE notifications SET unread=0 WHERE id=?', ((value,) for value in ids))

    def dismiss(self, row_id=None):
        with self.db:
            if row_id is None:
                self.db.execute("UPDATE notifications SET dismissed=1, unread=0, app='', summary='', body='', actions='{}'")
            else:
                self.db.execute("UPDATE notifications SET dismissed=1, unread=0, app='', summary='', body='', actions='{}' WHERE id=?", (row_id,))

    def metadata(self, key, value=None):
        if value is not None:
            with self.db:
                self.db.execute('INSERT OR REPLACE INTO metadata VALUES (?,?)', (key, str(value)))
        row = self.db.execute('SELECT value FROM metadata WHERE key=?', (key,)).fetchone()
        return row[0] if row else ''

    def status(self):
        count = self.db.execute('SELECT COUNT(*) FROM notifications WHERE unread=1 AND dismissed=0').fetchone()[0]
        healthy = time.time() - float(self.metadata('heartbeat') or 0) < 20
        return {'text': '󰂚' + (f' {count}' if count else ''),
                'class': 'offline' if not healthy else ('unread' if count else 'empty'),
                'tooltip': (f'{count} unread notifications' if count else 'Notifications') +
                           ('\nNotification capture is not running' if not healthy else '')}
