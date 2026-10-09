# Desktop map

Paths below are relative to the resolved config/state roots or checkout. Prefer actual local source over upstream examples: this checkout uses Hyprland 0.56+ Lua APIs.

| Concern | Live config / source in checkout |
| --- | --- |
| Desktop entry point | `hypr/hyprland.lua` / `config/hypr/hyprland.lua`; loads editable sections, then generated overrides |
| Monitors, programs, appearance, layouts, input, shortcuts, window rules, startup | `hyprshell/hyprland/*.lua` / `config/hyprshell/hyprland/*.lua`; section filenames describe their purpose |
| Chromium popup placement | `chromium-flags.conf` / `config/chromium-flags.conf`; XWayland exposes popup roles so Hyprland floats website popups at map time; fully exit and reopen Chromium after changing the backend |
| GUI display/appearance overrides | `hypr/hyprland-gui.lua`, required at end of main Lua file |
| Saved appearance, bar items, locking | `hyprshell/settings.json` / `config/hyprshell/settings.json` |
| Shell composition and bar | `quickshell/shell.qml`, `Bar.qml`, `DesktopServices.qml` |
| Menus | `quickshell/*Menu.qml`, `MenuController.qml`, `MenuPopover.qml` |
| Notifications | `quickshell/NotificationInbox.qml`, `NotificationCard.qml`; Quickshell owns `org.freedesktop.Notifications`; inbox history uses `Quickshell.statePath("notifications.json")` |
| Settings UI | `quickshell/Settings*.qml`, `SettingsModel.js`, `SettingsStore.qml` |
| Settings transactions and schema | `quickshell/settings/backend.py`, `defaults.json`; checkout `docs/settings.md` explains inheritance and extension points |
| Audio / spectrum | `SettingsSound.qml`, `SoundVolume.qml`, `AudioMenu.qml`, `AudioInputMeter.qml`, `SoundTest.qml`, `AudioRoute.qml`, `AudioSpectrum.qml`, `AudioSpectrumBars.qml`, `helpers/audio-spectrum.c`; shared native helper links libpulse and FFTW; input capture requires an explicit `--source` argument |
| Wallpaper | `hypr/wallpaper-start.sh`, `wallpaper-cycle.sh`; awww; `$HOME/Pictures/Wallpapers` |
| Locking | `quickshell/LockingController.qml`, `hypr/hyprlock.conf`; generated `hyprshell/hypridle.conf` belongs to Hyprshell |
| Cleanup | `hyprshell/cleanup.json`, `quickshell/settings/cleanup.py`; user `hyprshell-cleanup.timer` / `.service`; state `hyprshell/cleanup-last.json` |
| Portals | `xdg-desktop-portal/hyprland-portals.conf` |
| Launch helpers | `$HOME/.local/bin/{start-quickshell-bar,hyprshell-settings,app-launcher}` / checkout `bin/` |
| Install / package lists | checkout `setup.sh`, `tools/install_configs.py`, `packages.txt`, optional `packages-apps.txt` |
| App autostart overrides | `autostart/*.desktop` / checkout `config/autostart/*.desktop`; installer copies managed entries individually; `nm-applet.desktop` hides the duplicate network tray icon |
| Sync | `quickshell/settings/github_sync.py`; copies live configs **into** checkout, stages allowed project paths, commits and pushes |

Quickshell owns the bar, menus, notification inbox, and optional Hypridle child. Notification popups default off; Settings → Notification delivery controls popups, Do Not Disturb, critical bypass, and per-app delivery. The bell inbox keeps history. Locking is managed while Quickshell runs, not by a separate Hyprshell lock service. Cleanup is separately scheduled with a systemd user timer. Sound device defaults and volumes use PipeWire/WirePlumber state; Settings → Sound provides device selection, an opt-in input meter, a test tone, and per-stream volumes. GitHub config sync does not export sound-system state. Sound device defaults and volumes use PipeWire/WirePlumber state; Settings → Sound provides device selection, an opt-in input meter, a test tone, and per-stream volumes. GitHub config sync does not export sound-system state. Audio uses PipeWire/PipeWire Pulse and WirePlumber; network uses NetworkManager; Bluetooth uses BlueZ; battery uses UPower. Session startup uses UWSM and hyprpolkitagent.

Settings are version 1 JSON with defaults and inheritance. Inspect `backend.py`'s CLI before using `--save-json` / `--expected-json`; preserve its validation, backups, conflict detection, and rollback. Hyprland settings overrides are managed by this backend; avoid competing writes to generated blocks. Adding a preference requires checking defaults, backend validation, UI model, and consumers. Read `docs/settings.md` only for settings work.

## Focused verification

Run commands in the checkout (or use absolute paths), choosing checks for the change:

```bash
python3 tools/check_runtime.py --native
python3 -m unittest discover -s tests -v
Hyprland --verify-config --config "$PWD/config/hypr/hyprland.lua"
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software /usr/lib/qt6/bin/qmltestrunner -input config/quickshell/tests
python3 config/quickshell/tests/test_spectrum.py
```

Use the corresponding `tests/test_settings.py`, `test_locking*.py`, `test_cleanup.py`, `test_github_sync.py`, or `test_setup.py` for narrow backend changes. Runtime checker inspects dependencies; it does not prove live desktop health. Qt's unqualified qmltestrunner may be Qt 5; use the Qt 6 path above.

In an accessible desktop session, query only relevant evidence: `hyprctl -j monitors`, `hyprctl configerrors`, `quickshell list --all --json`, `wpctl status`, `nmcli device status`, `bluetoothctl show`, or service status. Bound logs with `tail -n 80 <state>/quickshell/bar.log` or `journalctl --user -b -n 80 --no-pager` with the relevant unit. Avoid reading notification history for routine diagnostics.

After validation, main Hyprland config changes use `hyprctl reload`; permissions marked restart-only in Lua require a new session. Quickshell watches QML changes. If a restart is actually needed, inspect and use `<config>/quickshell/install-and-activate.sh` (it can install Quickshell if missing). Do not kill every Quickshell process indiscriminately.

Installer replacements are backed up under `<state>/hyprshell/backups/<timestamp>`. `setup.sh --config-only` still copies whole directories, compiles the audio helper, and restores saved repo preferences. Compare live files first. Full setup uses `pacman -Syu`; avoid Arch partial upgrades. GitHub sync includes `docs/`, so this skill travels with existing sync without changing its allowlist.
