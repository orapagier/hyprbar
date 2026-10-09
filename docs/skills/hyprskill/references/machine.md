# Observed local machine

Inspected 2026-10-09. These facts describe ramlej's machine, not every Hyprshell installation. Versions and preferences are snapshots; verify only those relevant to the request.

- User home `/home/ramlej`; checkout `/home/ramlej/repos/hyprshell`; state repository pointer confirms it. Default XDG paths currently contain the installed files.
- Arch Linux x86_64; kernel `7.2.9-arch1-1`; installed Hyprland `0.56.2-4`, Quickshell `0.3.2-1`, UWSM `0.27.0-1`.
- Intel Core i5-1235U (10 cores, 12 threads); integrated Alder Lake Iris Xe; about 16 GiB RAM and 4 GiB swap. Intel CNVi Wi-Fi and Intel PCH audio.
- Main monitor config uses preferred/auto; `hyprland-gui.lua` overrides eDP-1 to 1920×1080 at 60.01 Hz, scale 1, position 0x0, sRGB. This was verified in files, not via live monitor IPC.
- `/etc/systemd/system/display-manager.service` points to SDDM. Hyprland startup launches the bar through UWSM, hyprpolkitagent, and the wallpaper helper.
- Kitty terminal, Nautilus file manager; Super release opens launcher; Super+B invokes Brave (binding alone does not prove browser installation). Super+W / Super+Shift+W cycle wallpaper. Print and Insert both screenshot because this keyboard's Print emits Insert.
- Wallpaper startup selects `$HOME/Pictures/Wallpapers/cloudsnight.jpg` through awww.
- Saved locking: enabled, `hyprlock`, 60 idle minutes, before sleep. Confirm current settings before changing locking.
- Saved bar: adaptive colors on, height 32, top margin 5, side margin 10, spacing 3; individual item preferences remain in settings.json.
- Native dependency checker passed. This inspection could not access Hyprland IPC or system/user D-Bus from the agent sandbox; running service status, active display state, and actual locking behavior were not verified.

Do not infer hostname, disk layout, active radios, service health, or current package versions from this profile. Use narrow live queries when needed. Keep serial numbers, MAC addresses, network names, tokens, and private history out of this file.
