#!/usr/bin/env python3
"""BlueZ device picker with scanning, pairing and connection controls."""
import importlib.util
from pathlib import Path
import sys
import traceback

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop

_spec = importlib.util.spec_from_file_location('menu_popup', Path(__file__).with_name('menu-popup.py'))
_menu = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_menu)
Gtk, GLib, GtkLayerShell = _menu.Gtk, _menu.GLib, _menu.GtkLayerShell
BLUEZ, ADAPTER, DEVICE, PROPS = 'org.bluez', 'org.bluez.Adapter1', 'org.bluez.Device1', 'org.freedesktop.DBus.Properties'
AGENT = 'org.bluez.Agent1'


class Rejected(dbus.DBusException):
    _dbus_error_name = 'org.bluez.Error.Rejected'


class PairingAgent(dbus.service.Object):
    def __init__(self, bus, popup):
        self.popup = popup
        super().__init__(bus, '/org/waybar/BluetoothAgent')

    def request(self, device, text, kind, reply, error):
        if str(device) != self.popup.busy_device:
            error(Rejected('No pairing was requested for this device'))
            return
        self.popup.request_pairing(text, kind, reply, error)

    @dbus.service.method(AGENT, in_signature='o', out_signature='s', async_callbacks=('reply', 'error'))
    def RequestPinCode(self, device, reply, error):
        self.request(device, 'Enter the PIN shown on your device', 'pin', reply, error)

    @dbus.service.method(AGENT, in_signature='o', out_signature='u', async_callbacks=('reply', 'error'))
    def RequestPasskey(self, device, reply, error):
        self.request(device, 'Enter the six-digit passkey', 'passkey', reply, error)

    @dbus.service.method(AGENT, in_signature='ou', out_signature='', async_callbacks=('reply', 'error'))
    def RequestConfirmation(self, device, passkey, reply, error):
        self.request(device, f'Does this code match your device?\n{int(passkey):06d}', 'confirm', reply, error)

    @dbus.service.method(AGENT, in_signature='o', out_signature='', async_callbacks=('reply', 'error'))
    def RequestAuthorization(self, device, reply, error):
        self.request(device, 'Allow pairing with this device?', 'confirm', reply, error)

    @dbus.service.method(AGENT, in_signature='os', out_signature='', async_callbacks=('reply', 'error'))
    def AuthorizeService(self, device, uuid, reply, error):
        self.request(device, 'Allow this device to connect?', 'confirm', reply, error)

    @dbus.service.method(AGENT, in_signature='os', out_signature='')
    def DisplayPinCode(self, device, pincode):
        self.popup.status.set_text(f'Type {pincode} on your device, then press Enter')

    @dbus.service.method(AGENT, in_signature='ouq', out_signature='')
    def DisplayPasskey(self, device, passkey, entered):
        self.popup.status.set_text(f'Type {int(passkey):06d} on your device, then press Enter')

    @dbus.service.method(AGENT, in_signature='', out_signature='')
    def Cancel(self):
        self.popup.cancel_prompt()

    @dbus.service.method(AGENT, in_signature='', out_signature='')
    def Release(self):
        self.popup.cancel_prompt()
        self.popup.agent_ready = False


def device_rows(objects, adapter, query=''):
    result = []
    for path, interfaces in objects.items():
        props = interfaces.get(DEVICE)
        if not props or str(props.get('Adapter', '')) != adapter:
            continue
        name = str(props.get('Alias') or props.get('Name') or props.get('Address') or 'Bluetooth device')
        address = str(props.get('Address', ''))
        if query.casefold() not in (name + ' ' + address).casefold():
            continue
        battery = interfaces.get('org.bluez.Battery1', {}).get('Percentage')
        result.append({'path': str(path), 'name': name, 'address': address,
                       'connected': bool(props.get('Connected')), 'paired': bool(props.get('Paired')),
                       'battery': int(battery) if battery is not None else None})
    return sorted(result, key=lambda row: (not row['connected'], not row['paired'], row['name'].casefold()))


class BluetoothPopup(_menu.MenuPopup):
    def __init__(self, args):
        super().__init__(args)
        self.bus = None
        self.agent = None
        self.agent_ready = False
        self.adapter = ''
        self.powered = False
        self.objects = {}
        self.busy_device = ''
        self.pending_prompt = None
        self.scanning = False
        self.scan_timer = None
        self.timer = None
        self.refresh_pending = False
        self.fingerprint = None

    def panel(self):
        box, header = self.make_panel('Bluetooth')
        self.power = self.button('Turn on', self.toggle_power)
        self.power.set_sensitive(False)
        header.pack_end(self.power, False, False, 0)
        self.prompt_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.prompt_box.set_no_show_all(True)
        self.prompt_text = self.label('', 'body')
        self.prompt_box.pack_start(self.prompt_text, False, False, 0)
        self.pin = Gtk.Entry()
        self.pin.set_max_length(16)
        self.pin.connect('activate', self.confirm_prompt)
        self.prompt_box.pack_start(self.pin, False, False, 0)
        buttons = Gtk.Box(spacing=8)
        buttons.pack_start(self.button('Confirm', self.confirm_prompt), False, False, 0)
        buttons.pack_start(self.button('Cancel', lambda *_: self.cancel_prompt()), False, False, 0)
        self.prompt_box.pack_start(buttons, False, False, 0)
        box.pack_start(self.prompt_box, False, False, 0)
        self.scrollable(box)
        self.scan = self.button('Scan for devices', self.scan_devices)
        self.scan.set_sensitive(False)
        box.pack_start(self.scan, False, False, 0)
        self.status = self.label('Loading Bluetooth…', 'caption')
        box.pack_start(self.status, False, False, 0)
        GLib.idle_add(self.refresh)
        self.timer = GLib.timeout_add(2000, self.refresh)
        return self.panel_events

    def interface(self, path, interface):
        return dbus.Interface(self.bus.get_object(BLUEZ, path, introspect=False), interface)

    def refresh(self, *_args):
        if self.closed:
            return False
        if self.refresh_pending:
            return True
        try:
            if self.bus is None:
                self.bus = dbus.SystemBus(private=True)
            if not self.bus.name_has_owner(BLUEZ):
                self.unavailable('Bluetooth service is unavailable')
                return True
            self.refresh_pending = True
            self.interface('/', 'org.freedesktop.DBus.ObjectManager').GetManagedObjects(
                reply_handler=self.snapshot, error_handler=self.snapshot_error, timeout=5)
        except dbus.DBusException:
            self.unavailable('Bluetooth service is unavailable')
        return True

    def unavailable(self, message):
        self.refresh_pending = False
        self.adapter = ''
        self.objects = {}
        self.powered = False
        self.busy_device = ''
        self.cancel_prompt()
        if self.scan_timer:
            GLib.source_remove(self.scan_timer)
            self.scan_timer = None
        self.scanning = False
        self.scan.set_label('Scan for devices')
        if self.agent is not None:
            self.agent.remove_from_connection()
            self.agent = None
        self.agent_ready = False
        self.power.set_sensitive(False)
        self.scan.set_sensitive(False)
        self.status.set_text(message)
        self.render()

    def snapshot_error(self, error):
        self.unavailable('Could not read Bluetooth devices')

    def snapshot(self, objects):
        self.refresh_pending = False
        if self.closed:
            return
        self.objects = objects
        adapters = [str(path) for path, interfaces in objects.items() if ADAPTER in interfaces]
        if not adapters:
            self.unavailable('No Bluetooth adapter found')
            return
        new_adapter = self.adapter not in adapters
        if new_adapter:
            self.adapter = next((path for path in adapters if objects[path][ADAPTER].get('Powered')), adapters[0])
        self.powered = bool(objects[self.adapter][ADAPTER].get('Powered'))
        self.power.set_label('Turn off' if self.powered else 'Turn on')
        self.power.set_sensitive(not self.busy_device)
        self.scan.set_sensitive(self.powered and not self.busy_device)
        if not self.busy_device:
            self.status.set_text('Scanning for nearby devices…' if self.scanning else ('Select a device to connect' if self.powered else 'Bluetooth is turned off'))
        if not self.agent_ready and self.agent is None:
            self.agent = PairingAgent(self.bus, self)
            self.interface('/org/bluez', 'org.bluez.AgentManager1').RegisterAgent(
                dbus.ObjectPath(self.agent._object_path), 'KeyboardDisplay',
                reply_handler=self.registered, error_handler=self.agent_error)
        self.render()
        if new_adapter and self.powered:
            self.scan_devices()

    def registered(self):
        self.agent_ready = True
        self.fingerprint = None
        self.render()

    def agent_error(self, error):
        self.agent_ready = False
        self.status.set_text('Pairing is unavailable; saved devices can still connect')

    def render(self, *_args):
        rows = device_rows(self.objects, self.adapter)
        fingerprint = (repr(rows), self.powered, self.busy_device)
        if fingerprint == self.fingerprint:
            return
        self.fingerprint = fingerprint
        for child in self.content.get_children():
            child.destroy()
        if not rows:
            self.content.pack_start(self.label('No devices found', 'caption'), False, False, 0)
        for row in rows:
            button = Gtk.Button()
            button.get_style_context().add_class('device-row')
            button.set_size_request(-1, self.row_height)
            card = Gtk.Box(spacing=10)
            self.inset(card, 8)
            button.add(card)
            icon = Gtk.Label(label='󰂯')
            icon.set_size_request(20, -1)
            icon.get_style_context().add_class('network-icon')
            card.pack_start(icon, False, False, 0)
            name = self.compact_label(row['name'])
            name.set_tooltip_text(None)
            state = 'Connected' if row['connected'] else ('Paired' if row['paired'] else 'Available')
            if row['battery'] is not None:
                state += f" · {row['battery']}% battery"
            card.pack_start(name, True, True, 0)
            action = 'Disconnect' if row['connected'] else ('Connect' if row['paired'] else 'Pair')
            button.connect('clicked', lambda _button, row=row: self.activate(row))
            button.set_tooltip_text(action + ' · ' + row['name'] + '\n' + state)
            button.set_sensitive(self.powered and not self.busy_device and (row['paired'] or row['connected'] or self.agent_ready))
            badge = Gtk.Label(label='󰄬' if row['connected'] else ('󰂱' if row['paired'] else '+'))
            badge.get_style_context().add_class('network-badge')
            if row['connected']:
                badge.get_style_context().add_class('connected')
            card.pack_end(badge, False, False, 0)
            self.content.pack_start(button, False, False, 0)
        self.content.show_all()
        GLib.idle_add(self.position_panel)

    def toggle_power(self, *_args):
        if self.adapter:
            self.interface(self.adapter, PROPS).Set(ADAPTER, 'Powered', dbus.Boolean(not self.powered),
                reply_handler=lambda: self.refresh(), error_handler=lambda error: self.operation_error('Could not change Bluetooth power', error))

    def scan_devices(self, *_args):
        if not self.adapter or not self.powered or self.scanning:
            return
        def started():
            if self.closed:
                self.stop_scan()
                return
            self.scanning = True
            self.scan.set_label('Scanning…')
            self.status.set_text('Scanning for nearby devices…')
            self.scan_timer = GLib.timeout_add_seconds(20, self.stop_scan)
        self.interface(self.adapter, ADAPTER).StartDiscovery(reply_handler=started,
            error_handler=lambda error: self.operation_error('Could not scan for devices', error))

    def stop_scan(self):
        if self.scanning and self.adapter:
            self.interface(self.adapter, ADAPTER).StopDiscovery(reply_handler=lambda: None, error_handler=lambda error: None)
        self.scanning = False
        self.scan_timer = None
        if not self.closed:
            self.scan.set_label('Scan for devices')
            self.refresh()
        return False

    def activate(self, row):
        self.busy_device = row['path']
        self.render()
        self.status.set_text(('Disconnecting from ' if row['connected'] else 'Connecting to ') + row['name'] + '…')
        device = self.interface(row['path'], DEVICE)
        def connect():
            device.Connect(reply_handler=self.completed, error_handler=lambda error: self.operation_error('Could not connect to the device', error), timeout=45)
        if row['connected']:
            device.Disconnect(reply_handler=self.completed, error_handler=lambda error: self.operation_error('Could not disconnect the device', error), timeout=15)
        elif row['paired']:
            connect()
        else:
            def paired():
                self.interface(row['path'], PROPS).Set(DEVICE, 'Trusted', dbus.Boolean(True),
                    reply_handler=connect, error_handler=lambda error: self.operation_error('Could not save the paired device', error))
            device.Pair(reply_handler=paired, error_handler=lambda error: self.operation_error('Could not pair with the device', error), timeout=120)

    def completed(self):
        self.busy_device = ''
        self.cancel_prompt()
        self.refresh()

    def operation_error(self, message, error):
        if self.closed:
            return
        self.busy_device = ''
        self.cancel_prompt()
        self.status.set_text(message)
        self.render()
        print(f'Bluetooth: {error}', file=sys.stderr)

    def request_pairing(self, text, kind, reply, error):
        self.cancel_prompt()
        self.pending_prompt = (kind, reply, error)
        self.prompt_text.set_text(text)
        self.pin.set_text('')
        self.pin.set_max_length(6 if kind == 'passkey' else 16)
        self.prompt_box.show_all()
        self.pin.set_visible(kind != 'confirm')
        if kind != 'confirm':
            self.pin.grab_focus()
        GLib.idle_add(self.position_panel)

    def confirm_prompt(self, *_args):
        if not self.pending_prompt:
            return
        kind, reply, error = self.pending_prompt
        value = self.pin.get_text()
        if kind == 'pin' and not 1 <= len(value) <= 16:
            self.prompt_text.set_text('Enter a PIN between 1 and 16 characters')
            return
        if kind == 'passkey' and (not value.isascii() or not value.isdigit() or not 0 <= int(value) <= 999999):
            self.prompt_text.set_text('Enter a numeric passkey from 000000 to 999999')
            return
        self.pending_prompt = None
        self.prompt_box.hide()
        reply() if kind == 'confirm' else reply(dbus.UInt32(int(value)) if kind == 'passkey' else value)
        GLib.idle_add(self.position_panel)

    def cancel_prompt(self):
        pending, self.pending_prompt = self.pending_prompt, None
        if pending:
            pending[2](Rejected('Pairing canceled'))
        self.prompt_box.hide()

    def finish(self, result=None):
        if not self.closed:
            self.cancel_prompt()
            if self.busy_device:
                self.interface(self.busy_device, DEVICE).CancelPairing(reply_handler=lambda: None, error_handler=lambda error: None)
            if self.timer:
                GLib.source_remove(self.timer)
                self.timer = None
            if self.scan_timer:
                GLib.source_remove(self.scan_timer)
            self.stop_scan()
            if self.agent_ready:
                self.interface('/org/bluez', 'org.bluez.AgentManager1').UnregisterAgent(
                    dbus.ObjectPath(self.agent._object_path), reply_handler=lambda: None, error_handler=lambda error: None)
        return super().finish(result)

    def run(self):
        try:
            return super().run()
        finally:
            if self.bus is not None:
                # Closing this client's bus connection also releases discovery
                # sessions if the popup closed while StartDiscovery was pending.
                self.bus.close()


if __name__ == '__main__':
    try:
        DBusGMainLoop(set_as_default=True)
        args = _menu.arguments()
        ready, _argv = Gtk.init_check(None)
        if not ready or not GtkLayerShell.is_supported():
            print('Bluetooth menu: a Wayland display with layer-shell support is required', file=sys.stderr)
            sys.exit(2)
        sys.exit(BluetoothPopup(args).run())
    except Exception:
        traceback.print_exc()
        sys.exit(2)
