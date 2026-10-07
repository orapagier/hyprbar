#!/usr/bin/env python3
"""Persistent notification inbox beside the Waybar bell."""
from datetime import datetime
from html.parser import HTMLParser
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import traceback


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), Path(__file__).with_name(name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

_menu, _store = load('menu-popup'), load('notification-store')
Gtk, GLib, GtkLayerShell = _menu.Gtk, _menu.GLib, _menu.GtkLayerShell


class PlainText(HTMLParser):
    def __init__(self, value):
        super().__init__(convert_charrefs=True)
        self.parts = []
        self.feed(value)

    def handle_data(self, data):
        self.parts.append(data)

    def handle_starttag(self, tag, attrs):
        if tag in ('br', 'p', 'div'):
            self.parts.append('\n')


def plain(value):
    return ''.join(PlainText(value).parts).strip()


class NotificationsPopup(_menu.MenuPopup):
    def __init__(self, args):
        super().__init__(args)
        self.store = _store.Store()
        self.fingerprint = None
        self.limit = 100
        self.timer = None
        self.expanded = set()

    def panel(self):
        box, header = self.make_panel('Notifications')
        header.pack_end(self.button('Clear all', self.clear), False, False, 0)
        self.scrollable(box)
        self.more = self.button('Load more', self.load_more)
        self.more.set_no_show_all(True)
        box.pack_start(self.more, False, False, 0)
        self.status = self.label('', 'caption')
        box.pack_start(self.status, False, False, 0)
        self.refresh()
        self.timer = GLib.timeout_add(1000, self.refresh)
        return self.panel_events

    def refresh(self, *_args):
        if self.closed:
            return False
        all_rows = self.store.rows()
        rows = all_rows[:self.limit]
        fingerprint = [(row['id'], row['received'], row['active']) for row in rows]
        self.store.mark_read(row['id'] for row in rows)
        healthy = self.store.status()['class'] != 'offline'
        self.status.set_text(f'{len(all_rows)} notifications' if healthy else 'Notification capture is not running')
        self.more.set_visible(len(all_rows) > self.limit)
        if fingerprint == self.fingerprint:
            return True
        self.fingerprint = fingerprint
        for child in self.content.get_children():
            child.destroy()
        if not rows:
            self.content.pack_start(self.label('No notifications yet', 'caption'), False, False, 0)
        for row in rows:
            card = Gtk.Expander()
            card.get_style_context().add_class('notification-row')
            card.set_hexpand(True)
            header = Gtk.Box(spacing=8)
            time = datetime.fromtimestamp(row['received']).strftime('%b %d · %H:%M')
            summary = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
            summary.pack_start(self.compact_label(f"{row['app'] or 'Notification'} · {time}", 'caption'), False, False, 0)
            summary.pack_start(self.compact_label(plain(row['summary']) or 'Notification', 'card-title'), False, False, 0)
            header.pack_start(summary, True, True, 0)
            header.pack_end(self.button('×', lambda _button, row=row: self.dismiss(row), 'Remove notification'), False, False, 0)
            card.set_label_widget(header)
            card.set_label_fill(True)
            card.set_tooltip_text('Click to show notification details')
            content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
            self.inset(content, 10)
            card.add(content)
            content.pack_start(self.label(plain(row['summary']), 'card-title'), False, False, 0)
            if row['body']:
                content.pack_start(self.label(plain(row['body']), 'body'), False, False, 0)
            actions = {action: title for action, raw_title in json.loads(row['actions']).items()
                       if (title := plain(str(raw_title or '')).strip())}
            if row['active'] and row['bus_id'] and actions:
                action_box = Gtk.FlowBox(column_spacing=6, row_spacing=6)
                action_box.set_selection_mode(Gtk.SelectionMode.NONE)
                action_box.set_min_children_per_line(1)
                action_box.set_max_children_per_line(1)
                for action, title in actions.items():
                    button = self.button(title, lambda _button, row=row, action=action: self.invoke(row, action), title)
                    button.get_child().set_ellipsize(_menu.Pango.EllipsizeMode.END)
                    button.get_child().set_max_width_chars(16)
                    action_box.add(button)
                content.pack_start(action_box, False, False, 0)
            card.set_expanded(row['id'] in self.expanded)
            card.connect('notify::expanded', self.toggle_details, row['id'])
            self.content.pack_start(card, False, False, 0)
        self.content.show_all()
        GLib.idle_add(self.position_panel)
        return True

    def toggle_details(self, card, _property, row_id):
        (self.expanded.add if card.get_expanded() else self.expanded.discard)(row_id)
        GLib.idle_add(self.position_panel)

    def dismiss(self, row):
        self.store.dismiss(row['id'])
        if row['active'] and row['bus_id']:
            subprocess.Popen(['makoctl', 'dismiss', '-n', str(row['bus_id'])], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.fingerprint = None
        self.refresh()

    def clear(self, *_args):
        self.store.dismiss()
        subprocess.Popen(['makoctl', 'dismiss', '-a'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.fingerprint = None
        self.refresh()

    def invoke(self, row, action):
        subprocess.Popen(['makoctl', 'invoke', '-n', str(row['bus_id']), action], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.finish()

    def load_more(self, *_args):
        self.limit += 100
        self.refresh()

    def finish(self, result=None):
        if self.timer is not None:
            GLib.source_remove(self.timer)
            self.timer = None
        return super().finish(result)


if __name__ == '__main__':
    try:
        args = _menu.arguments()
        ready, _argv = Gtk.init_check(None)
        if not ready or not GtkLayerShell.is_supported():
            print('Notification menu: a Wayland display with layer-shell support is required', file=sys.stderr)
            sys.exit(2)
        sys.exit(NotificationsPopup(args).run())
    except Exception:
        traceback.print_exc()
        sys.exit(2)
