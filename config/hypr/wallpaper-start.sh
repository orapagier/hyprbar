#!/usr/bin/env bash
set -euo pipefail

if ! pgrep -x awww-daemon >/dev/null 2>&1; then
  awww-daemon &
fi
for (( attempt=0; attempt<50; attempt++ )); do
  if awww query >/dev/null 2>&1; then
    exec awww img "$HOME/Pictures/Wallpapers/default.jpg" \
      --transition-type grow --transition-pos center --transition-step 90
  fi
  sleep 0.1
done
printf 'hyprshell: wallpaper daemon did not become ready\n' >&2
exit 1
