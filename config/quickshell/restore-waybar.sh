#!/usr/bin/env bash
set -euo pipefail
for program in waybar mako rofi; do
    if ! command -v "$program" >/dev/null; then
        printf 'Install the legacy dependencies first: ./setup.sh --with-fallback\n' >&2
        exit 1
    fi
done
config="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
hypr_config="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
sed -i '/^[[:space:]]*hl.exec_cmd(.*start-quickshell-bar.*)/c\    hl.exec_cmd("uwsm app -- waybar")' "$hypr_config"
sed -i '/^local menu[[:space:]]*=/c\local menu = [[uwsm app -- "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/app-launcher.sh"]]' "$hypr_config"
if ! grep -Fq 'hl.exec_cmd("uwsm app -- mako")' "$hypr_config"; then
    sed -i '/hl.exec_cmd("uwsm app -- waybar")/a\    hl.exec_cmd("uwsm app -- mako")' "$hypr_config"
fi
shell_bin=$(command -v quickshell || command -v qs || true)
if [[ -n "$shell_bin" ]]; then "$shell_bin" kill --path "$config" 2>/dev/null || true; fi
mkdir -p -- "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
if ! pgrep -u "$(id -u)" -x mako >/dev/null; then
    nohup mako >"${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/mako-fallback.log" 2>&1 </dev/null &
fi
systemctl --user enable --now waybar-notification-monitor.service
if ! pgrep -u "$(id -u)" -x waybar >/dev/null; then
    nohup waybar >"${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/waybar-fallback.log" 2>&1 </dev/null &
fi
