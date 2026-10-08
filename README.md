# Hyprshell

Jelmar's Hyprland desktop for Arch Linux, now using a native Quickshell bar,
launcher, and popdowns. The transparent 32px bar has wallpaper-tinted glass
pills, a glass Arch logo, workspace buttons, scrolling media text, a twelve-band
audio visualizer, a Philippine calendar, a persistent notification inbox,
audio, Wi-Fi, Bluetooth, battery, tray, and power controls. Seven wallpapers
and the current Hyprland configuration are included.

Pills sample the wallpaper underneath each item and adjust their foreground
and tint for readable contrast. Hovering an icon opens its connected popdown;
moving into the menu keeps it open, and hovering another icon switches menus.
Click an icon to pin its menu until another click, an outside click, or Escape.
Popdowns follow their icons when moved or reordered in Settings, centering under
the trigger and staying within the screen edges, even while pinned open.
Notifications use the same side margins as other popdowns. Wi-Fi and Bluetooth
rows keep a fixed 36px height and elide long names within the menu width.

The native UI and service bindings use QML/JavaScript. A small C helper drives
the audio spectrum from the speaker output monitor. The previous Waybar, GTK,
Mako, Rofi, and Fuzzel configuration remains bundled as an optional fallback.
Hyprshell was formerly named Hyprbar.

## Settings app

Open **Hyprshell Settings** from the application launcher, or run
`~/.local/bin/hyprshell-settings` while the Hyprshell bar is running.
Install an updated checkout with `./setup.sh --config-only` to get the app.
The cog beside the Arch logo also opens a settings popdown: hover to open,
click to pin, then choose **Open Hyprshell Settings**. Its colors, position,
and visibility are configurable like other bar items.

The settings window opens floating, centered horizontally and 40px above the
vertical midpoint. Press `Super+V` to toggle between floating and tiled.

Settings runs inside the existing Quickshell process. Its UI loads only when
opened and unloads after closing once pending saves finish. Invalid or failed
edits are retained as a small draft and restored on reopening; the hidden
controls and preview are released. The application-menu entry is just a shortcut
to this module.

The native settings window includes a sample bar preview and automatic saving:

- Show or hide any built-in module, move it left/center/right, and change its order
  by dragging in the preview. Click preview items to edit them.
- Enable wallpaper colors globally or override the choice for each module.
- Override text and icon glyphs, text/icon/pill/outline colors (`#RRGGBB`),
  whole-item and pill opacity, font size, global/per-item background visibility,
  pill radius, and extra left/right spacing per item.
- Adjust bar height, margins, spacing, and the clock's Qt date/time format.
- Resize icons globally or individually from 8–48 px. Individual sizes override
  the global size; reset restores inheritance. The bar grows to fit larger icons.
- Set Hyprland gaps, border size, window rounding and opacity, blur, shadows,
  and animations. Empty Hyprland fields preserve the underlying configuration.

Preferences are stored in `$XDG_CONFIG_HOME/hyprshell/settings.json`
(`~/.config/hyprshell/settings.json` by default), outside the directories
replaced by the installer. Missing preferences use bundled defaults. Changes
save and apply automatically after a short 500 ms pause; no Apply button is
needed. Closing the window flushes pending edits. Each save
validates values, backs up changed files, and writes them atomically. Bar
settings update through a watched file without restarting the notification
service. Manual colors take priority over adaptive colors. A hidden module's
menu closes; hiding media destroys its visualizer component. Desktop services
continue running when their status items are hidden.

Hyprland overrides live in `hyprshell/overrides.lua` or `overrides.conf`, with
a source line added to the user's main config when needed. The app supports
both Lua and traditional `.conf` main configs. It reloads Hyprland when running
in a desktop session and rolls back affected files if reload fails or reports
configuration errors. Each save backs up previous files under
`$XDG_STATE_HOME/hyprshell/backups/settings-<timestamp>/`; `manifest.json` maps
each numbered backup to its original path and records newly created files.
Clearing a Hyprland field automatically removes that override.
Invalid values leave the last saved settings active and show an error; editing
the field to a valid value resumes automatic saving.

The Arch logo and settings cog are standalone glass vector shapes, with
reflective fills and edges inside their silhouettes and no default backing
pill. Hovering or pinning their menus brightens the glass.

This version configures **the Hyprshell Quickshell components**. It does not
discover or rewrite arbitrary third-party QML shells. Tray application artwork
keeps its original icons/colors; workspace styling applies to the workspace
group. Battery and media still appear only when the corresponding hardware or
playback is available. The preview uses sample statuses and a fallback palette,
while the actual bar samples the wallpaper on each output. Monitor layouts,
keybindings, window rules, popup styling, custom modules, and profile management
remain outside the settings window for now.

See [docs/settings.md](docs/settings.md) for the configuration contract and
extension points.

## Install on fresh Arch Linux

Start with an **installed x86_64 Arch Linux system**, an internet connection,
and a normal user with sudo access. Run these commands as that user:

```bash
sudo pacman -Syu --needed git
git clone https://github.com/orapagier/hyprshell.git
cd hyprshell
./setup.sh
```

The installer checks whether **Hyprland and Quickshell are already installed**,
then checks the remaining desktop dependencies using pacman's dependency
database (including package providers). It performs a full Arch upgrade and
installs missing packages with `--needed`; existing packages are updated with
the system. All packages come from official Arch repositories.

The default install provides the native Quickshell bar, launcher, notification
inbox, wallpaper colors and audio spectrum; UWSM, portals and the Polkit agent;
Kitty and Thunar for the desktop shortcuts; fonts, icons and cursors; brightness
and screenshot tools; NetworkManager with its Wi-Fi backend, BlueZ, UPower,
and PipeWire/WirePlumber. GCC, libpulse and FFTW build the spectrum helper.
The exact package list is in [packages.txt](packages.txt); transitive
dependencies are resolved by pacman.

**No browser, AUR helper, or other personal application is installed.** The
legacy Waybar/Mako/Rofi/Fuzzel packages and COSMIC Greeter are optional. The
installer preserves your timezone and existing login screen unless you choose
the corresponding option. It does not reboot or restart the running desktop.

Reboot and select **Hyprland (uwsm-managed)** on the login screen, or start
from a TTY with:

```bash
uwsm start -e -D Hyprland hyprland.desktop
```

The config uses Hyprland's Lua API and requires **Hyprland 0.56 or later**.
Arch is rolling release; `docs/original-packages.txt` records the earlier
Waybar desktop's packages rather than freezing the current installation.
Partitioning, the base OS, user creation, the bootloader, and proprietary GPU
drivers remain part of your Arch setup. The laptop's monitor override lives in
`config/hypr/hyprland-gui.lua`; other displays use the automatic preferred-mode
rule in `hyprland.lua`.

## Updating configs and backups

```bash
./setup.sh --dry-run                         # preview; changes nothing
./setup.sh --config-only                     # configs, helpers, wallpapers only
./setup.sh --with-fallback                   # also install the legacy desktop
./setup.sh --with-greeter                     # add a login screen if none exists
./setup.sh --timezone Europe/London          # choose another timezone
./setup.sh --keep-timezone                   # preserve timezone (the default)
```

`--config-only` requires Python 3, a C compiler, and the libpulse/FFTW development
files already installed. It compiles the spectrum helper but does not install
packages, enable services, reload the desktop, or change the timezone.

The installer replaces its `hypr`, `quickshell`, `waybar`, `rofi`, `fuzzel`, and
`mako` directories, installs the three session/launcher utilities from `bin/`
into `~/.local/bin/`, and installs the fallback notification service and bundled
wallpapers. Changed existing paths are backed up under:

```text
~/.local/state/hyprshell/backups/<timestamp>/
```

Unrelated app configs, utilities, and differently named wallpapers are preserved.
Repeating the installation skips identical payloads. Backups made before the
rename remain in `~/.local/state/hyprbar/backups/`; new backups use `hyprshell`.
`XDG_CONFIG_HOME` and `XDG_STATE_HOME` are respected, including paths containing spaces. Restore a
path by moving the installed copy aside and copying its original from the backup.

Quickshell watches QML changes and reloads automatically. When migrating from
Waybar/Mako in an existing desktop, install the configs and run:

```bash
~/.config/quickshell/install-and-activate.sh
hyprctl reload
```

The session helper confirms the native bar and notification server are ready
before stopping Waybar and disabling its Python notification collector. If
Quickshell cannot start, it uses Waybar/Mako as a fallback when those optional
packages are installed. Add them with `./setup.sh --with-fallback`. The native
launcher retries shell startup if necessary. An existing enabled Mako user
service may need disabling if it is independently configured to reclaim the
notification service.

## Controls

| Shortcut / action | Result |
| --- | --- |
| `Super+T` | Kitty terminal |
| Press and release `Super` / click Arch logo | Toggle native app launcher |
| `Super+E` | Thunar file manager |
| `Super+B` | Brave, if separately installed |
| `Super+Q` | Close focused window |
| `Super+M` | Maximize / restore |
| `Super+V` | Toggle floating |
| `Super+1…0` | Workspace 1…10 |
| `Super+Shift+1…0` | Move window to workspace |
| `Super+H` / `Super+Shift+H` | Hide / restore window |
| `Super+W` / `Super+Shift+W` | Next / previous wallpaper |
| `Print` / `Insert` | Select screenshot region, then edit in Swappy |
| `Super+Shift+M` | End the Hyprland session |
| Hover / click clock or status icon | Open / pin its popdown |

Popup dialogs float and center while regular application windows remain tiled.
Modal windows, Thunar rename/properties dialogs, file chooser portals and common
browser dialogs have explicit rules; apps that do not advertise a dialog may
need an additional rule. The wallpaper on login is `cloudsnight.jpg`. Audio
controls support dragging and clicking the volume and microphone sliders,
muting, and selecting outputs.
Wi-Fi uses NetworkManager; Bluetooth uses BlueZ and a supported adapter, with
pairing prompts inside the menu. Battery details include charge and health
information when the hardware supplies them. Power controls include logout,
which returns to the login screen.

Notifications go directly into the bell's inbox without toast popups. Click a
notification to expand its complete title/body, scroll long messages, and use
the corner × to dismiss it. Search and Clear all are included. Existing history
is imported once from `~/.local/state/waybar/notifications/` using read-only
SQLite access; new history uses `Quickshell.statePath("notifications.json")`.
The media visualizer reads the speaker output monitor, never the microphone.

## Checks and troubleshooting

```bash
python3 -m unittest discover -s tests -v
# Optional legacy checks require the packages in packages-fallback.txt:
python3 -m unittest discover -s config/waybar/tests -v
cc -O2 config/quickshell/helpers/audio-spectrum.c \
  -o config/quickshell/helpers/audio-spectrum -lpulse-simple -lpulse -lfftw3 -lm
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  /usr/lib/qt6/bin/qmltestrunner -input config/quickshell/tests
python3 config/quickshell/tests/test_spectrum.py
Hyprland --verify-config --config "$PWD/config/hypr/hyprland.lua"
```

Installer checks use temporary home directories. Offscreen QML checks cover the
bar, hover and pinned menus, audio controls, notification expansion and long
message scrolling, battery states, media bars, and wallpaper sampling/contrast.
Synthetic audio checks verify frequency separation and capture lifecycle.
GitHub Actions checks the installer/fallback on Ubuntu and the native desktop
package resolution, Hyprland config, and panel on Arch Linux. These checks do
not replace a full installation and login test on fresh hardware.

Startup output is in `~/.local/state/quickshell/bar.log`. Native components and
service details are documented in [config/quickshell/README.md](config/quickshell/README.md).
To return to Waybar/Mako, run `~/.config/quickshell/restore-waybar.sh` and reload
Hyprland. Install the optional dependencies with `./setup.sh --with-fallback`
before using this option.
The optional `~/.local/bin/cleanup-old-launchers` utility previews its package
removal list; `--apply` removes the listed old launcher packages only after it
confirms Quickshell is running. No cleanup runs during installation.

The calendar's holiday rules/data live in `config/quickshell/Calendar.js`;
special government declarations may require updates. Wallpapers are copied
from the original desktop; no new ownership or license over those third-party
images is claimed here.
