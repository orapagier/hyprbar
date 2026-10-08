#!/usr/bin/env bash
# Run in the desktop terminal after installing the repository configs.
set -euo pipefail
config="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
hypr_config="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
if ! hyprctl -j monitors >/dev/null 2>&1; then
    printf 'Run this command in a terminal inside your Hyprland desktop session.\n' >&2
    exit 1
fi
if ! command -v quickshell >/dev/null && ! command -v qs >/dev/null; then
    sudo pacman -S --needed quickshell
fi
shell_bin=$(command -v quickshell || command -v qs)
# Stop this shell even when an existing instance was launched from a different path.
shell_id=$(sed -n 's/^\/\/@ pragma ShellId //p' "$config/shell.qml")
while IFS= read -r instance_id; do
    "$shell_bin" kill --id "$instance_id" 2>/dev/null || true
done < <("$shell_bin" list --all --json | awk -F '"' -v expected="$shell_id" '
    /"id":/ { instance = $4 }
    /"shell_id":/ && $4 == expected { print instance }
')
"$shell_bin" kill --path "$config" 2>/dev/null || true
if ! "$HOME/.local/bin/start-quickshell-bar" --require-quickshell; then
    if command -v waybar >/dev/null && ! pgrep -u "$(id -u)" -x waybar >/dev/null; then
        nohup waybar >"${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/waybar-fallback.log" 2>&1 </dev/null &
    fi
    exit 1
fi
backup="$hypr_config.bak-before-native-quickshell-$(date +%Y%m%d-%H%M%S)"
cp -p -- "$hypr_config" "$backup"
sed -i 's|hl.exec_cmd("uwsm app -- waybar")|hl.exec_cmd("uwsm app -- \\"$HOME/.local/bin/start-quickshell-bar\\"")|' "$hypr_config"
sed -i '/^local menu[[:space:]]*=/c\local menu = [[uwsm app -- "$HOME/.local/bin/app-launcher"]]' "$hypr_config"
sed -i '/^[[:space:]]*hl.exec_cmd("uwsm app -- mako")[[:space:]]*$/d' "$hypr_config"
printf 'Native Quickshell is active, including the notification inbox.\nAutostart backup: %s\n' "$backup"
