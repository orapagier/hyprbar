#!/usr/bin/env bash
set -u
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/wifi-menu.sh"
configure_layout
log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/waybar"
mkdir -p -- "$log_dir"
python3 "$SCRIPT_DIR/notifications-popup.py" --theme "$SCRIPT_DIR/notifications-menu.ini" \
  --width "$MENU_WIDTH" "${OUTPUT_ARGS[@]}" --lines 0 2>"$log_dir/notifications-menu.log"
