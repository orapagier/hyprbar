#!/usr/bin/env bash
# Fuzzel remains usable until Rofi has been installed successfully.
set -eu

if command -v rofi >/dev/null 2>&1; then
    # Rofi automatically uses Wayland in the Hyprland session.
    exec rofi -config "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/config.rasi" \
        -show drun -monitor -1 "$@"
fi

exec fuzzel "$@"
