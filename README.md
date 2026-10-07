# Hyprbar

Jelmar's Hyprland desktop for Arch Linux: a compact, transparent Waybar with
individual pastel glass backgrounds, rounded borders, and compositor blur.
Includes a compact glass Rofi launcher, the complete current Hyprland
configuration, and seven wallpapers.

The bar has workspace buttons, a scrolling media title and eight-band audio
visualizer, a clock with a Philippine calendar, a persistent notification inbox,
and audio, Wi-Fi, Bluetooth, battery, and tray modules. Clicking the status icons
opens matching GTK popups with the launcher's translucent tint, subtle highlight,
and frosted blur. The calendar and notification history work offline. The active
workspace has a lavender underline, and the clock matches the lavender icons.

## Install on fresh Arch Linux

Start with an **installed x86_64 Arch Linux system**, an internet connection,
and a normal user with sudo access. Run these commands as that user:

```bash
sudo pacman -Syu --needed git
git clone https://github.com/orapagier/hyprbar.git
cd hyprbar
./setup.sh
```

The installer upgrades Arch and installs everything needed for this desktop:

- Hyprland, UWSM, Waybar, wallpaper daemon, Mako, Rofi, Kitty, and Thunar.
- Fuzzel as a fallback launcher.
- GTK layer-shell, Python bindings, D-Bus, Playerctl, FFTW, and PulseAudio tools.
- PipeWire/WirePlumber, NetworkManager, Bluetooth, portals, and the Polkit agent.
- DejaVu, GoMono Nerd Font, Noto fonts, Pop/Adwaita icons, and Adwaita cursors.
- Brave (`brave-bin`, built from the AUR as your user).
- COSMIC Greeter when no display manager is already configured.
- Configs, all seven wallpapers, and the persistent notification user service.
- System timezone `Asia/Manila`, matching the original desktop.

Reboot and select **Hyprland (uwsm-managed)** on the login screen. If you prefer
a TTY, start the session with:

```bash
uwsm start -e -D Hyprland hyprland.desktop
```

This config uses [Hyprland's Lua configuration](https://wiki.hypr.land/Configuring/Start/)
and requires **Hyprland 0.56 or later**. The original versions are recorded in
`docs/original-packages.txt`. Arch is rolling release: the installer uses the
current packages while preserving the config and wallpaper assets. It does not
freeze the entire operating system to those recorded versions.

The base OS, disk partitioning, user creation, bootloader, and any proprietary
GPU driver configuration remain part of your Arch installation. Mesa and Linux
firmware are installed for the desktop. On NVIDIA hardware, set up the driver
appropriate for your GPU before starting Hyprland. The original laptop monitor
override is in `config/hypr/hyprland-gui.lua`; other displays use the automatic
preferred-mode rule in `hyprland.lua`.

## Installer options and backups

```bash
./setup.sh --dry-run                         # preview; changes nothing
./setup.sh --config-only                     # configs and wallpapers only
./setup.sh --skip-browser --no-greeter        # use your existing apps/login
./setup.sh --timezone Europe/London          # choose another timezone
./setup.sh --keep-timezone                   # preserve the system timezone
```

`--config-only` does not install packages, enable services, reload the desktop,
or change the timezone. It is useful when the dependencies are already present.

The installer replaces its `hypr`, `waybar`, `rofi`, and `fuzzel` config directories and
backs up changed existing paths under:

```text
~/.local/state/hyprbar/backups/<timestamp>/
```

It also backs up any replaced notification service or wallpaper. Unrelated app
configs and differently named wallpapers are preserved. Repeating an install
does not back up files that already match. `XDG_CONFIG_HOME` and `XDG_STATE_HOME`
are respected, and paths are quoted so usernames/home directories may differ.
To restore a config, move the installed directory aside and copy its original
from the backup's `config/` directory. Reload the session afterward.

An existing display manager is kept. Installing the greeter enables it for the
next boot and does not interrupt your current desktop. The script does not
automatically reboot. Package downloads, AUR builds, and sudo may take time.

## Controls

| Shortcut / action | Result |
| --- | --- |
| `Super+T` | Kitty terminal |
| Press and release `Super` | Toggle the glass Rofi launcher |
| `Super+E` | Thunar file manager |
| `Super+B` | Brave |
| `Super+Q` | Close focused window |
| `Super+M` | Maximize / restore |
| `Super+V` | Toggle floating |
| `Super+1…0` | Workspace 1…10 |
| `Super+Shift+1…0` | Move window to workspace |
| `Super+H` / `Super+Shift+H` | Hide / restore window |
| `Super+W` / `Super+Shift+W` | Next / previous wallpaper |
| `Super+Shift+M` | End the Hyprland session |
| Click clock | Philippine calendar |
| Click bell / audio / Wi-Fi / Bluetooth | Open the matching popup |

The wallpaper on login is `cloudsnight.jpg`. The launcher closes with another
tap of Super, Escape, or an outside click. Popups close with Escape or an outside
click. Rofi uses fuzzy app search, app icons, and a compact results list that
shrinks as matches narrow. Its theme lives in `config/rofi/glass.rasi`.

The media module reads playback metadata and the default audio
output; it never records the microphone. Notifications are stored locally under
`~/.local/state/waybar/notifications/` until cleared from the inbox.

## Checks and troubleshooting

```bash
python3 -m unittest discover -s tests -v
python3 -m unittest discover -s config/waybar/tests -v
python3 tools/check_runtime.py config/waybar
Hyprland --verify-config --config "$PWD/config/hypr/hyprland.lua"
```

Installer tests use isolated temporary home directories. Runtime and bar checks
require the desktop dependencies; they do not need a running desktop.

If the bar needs restarting after a manual config update, run
`~/.config/waybar/apply-panel-updates.sh` from a desktop terminal. For the inbox,
inspect `journalctl --user -u waybar-notification-monitor.service`. Popup errors
are logged under `~/.local/state/waybar/`. Wi-Fi requires NetworkManager and
Bluetooth requires a supported adapter and the BlueZ daemon.

After updating the launcher or popdown configuration, run `hyprctl reload` and
close/reopen the menus. The blur rules ignore transparent pixels outside the
panels, so their invisible click areas do not blur the whole screen. Rofi 2.0
needs the included Hyprland controls for outside-click dismissal on Wayland.

The calendar contains the holiday rules/data in `ph-calendar.py`; special
government declarations may require updating that file. Wallpaper images are
copied from the original desktop; no new ownership or license over those
third-party images is claimed here.
