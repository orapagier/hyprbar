#!/usr/bin/env bash
# Apply the panel changes from the user's desktop session.
set -e
systemctl --user daemon-reload
systemctl --user start waybar-notification-monitor.service
makoctl reload
if pgrep -x waybar >/dev/null; then
  pkill -SIGUSR2 -x waybar
else
  mkdir -p -- "${XDG_STATE_HOME:-$HOME/.local/state}/waybar"
  nohup waybar >"${XDG_STATE_HOME:-$HOME/.local/state}/waybar/waybar.log" 2>&1 &
fi
