#!/usr/bin/env bash
# Fuzzel remains usable until Rofi has been installed successfully.
set -eu

if command -v rofi >/dev/null 2>&1; then
    contrast=$(python3 "${XDG_CONFIG_HOME:-$HOME/.config}/waybar/adaptive-glass.py" --rofi 2>/dev/null) || contrast='* { glass: rgba(30,30,46,0.99); muted: #bac2de; }'
    # Rofi automatically uses Wayland in the Hyprland session.
    exec rofi -config "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/config.rasi" \
        -show drun -monitor -1 -theme-str "$contrast" "$@"
fi

exec fuzzel "$@"
