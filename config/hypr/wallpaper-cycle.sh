#!/usr/bin/env bash
# Cycle wallpapers in ~/Pictures/Wallpapers with awww (successor of swww).
# Usage: wallpaper-cycle.sh [next|prev]  (default: next)
set -u

WALL_DIR="$HOME/Pictures/Wallpapers"
STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/awww-wallpaper-index"
MODE="${1:-next}"
mkdir -p -- "$(dirname -- "$STATE_FILE")"

mapfile -t WALLS < <(find "$WALL_DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)

if [ "${#WALLS[@]}" -eq 0 ]; then
    exit 0
fi

# Make sure the daemon is up
if ! pgrep -x awww-daemon >/dev/null 2>&1; then
    awww-daemon &
    sleep 0.5
fi

idx="$(cat "$STATE_FILE" 2>/dev/null)"
[[ "$idx" =~ ^[0-9]+$ ]] || idx=-1

if [ "$MODE" = "prev" ]; then
    idx=$(( (idx - 1 + ${#WALLS[@]}) % ${#WALLS[@]} ))
else
    idx=$(( (idx + 1) % ${#WALLS[@]} ))
fi

TRANSITIONS=(grow wave wipe fade outer center)
TRANS="${TRANSITIONS[$RANDOM % ${#TRANSITIONS[@]}]}"

awww img "${WALLS[$idx]}" --transition-type "$TRANS" --transition-step 90 --transition-fps 60
echo "$idx" > "$STATE_FILE"
