#!/usr/bin/env bash
# Use the same monitor-aware layout as the other panel menus.
set -u
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/wifi-menu.sh"
configure_layout
log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/waybar"
mkdir -p -- "$log_dir"
python3 "$SCRIPT_DIR/power-popup.py" --theme "$SCRIPT_DIR/power-menu.ini" \
  --width "$MENU_WIDTH" "${OUTPUT_ARGS[@]}" --lines 0 \
  2>"$log_dir/power-menu.log"
