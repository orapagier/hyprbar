#!/usr/bin/env bash
# A quiet, scrollable Wi-Fi dropdown for Waybar, using GTK and NetworkManager.
set -u

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
MENU_WIDTH=30
MAX_LINES=6
NAME_WIDTH=24
OUTPUT_ARGS=()

SIG=($'\U000F092F' $'\U000F091F' $'\U000F0922' $'\U000F0925' $'\U000F0928')
I_WIFI=$'\U000F05A9'
I_OFF=$'\U000F05AA'
I_LOCK=$'\U000F033E'
I_SCAN=$'\U000F0450'
I_DISC=$'\U000F0156'
I_CHECK=$'\U000F012C'

notify() {
  notify-send -a "Wi-Fi" -i network-wireless "Wi-Fi" "$1" 2>/dev/null || true
}

# The picker owns its panel and outside-click area in the same Wayland surface.
picker() {
  local log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/waybar"
  mkdir -p -- "$log_dir"
  python3 "$SCRIPT_DIR/wifi-popup.py" \
    --theme "$SCRIPT_DIR/wifi-menu.ini" \
    --width "$MENU_WIDTH" "${OUTPUT_ARGS[@]}" "$@" \
    2>"$log_dir/wifi-menu.log"
}

# Recompute a compact footprint whenever the menu opens. GTK handles the
# output's scale itself; these limits use logical (unscaled) display dimensions.
configure_layout() {
  local -a layout=()
  mapfile -t layout < <(hyprctl -j monitors 2>/dev/null | python3 -c '
import json, sys
try:
    monitors = json.load(sys.stdin)
    monitor = next((m for m in monitors if m.get("focused")), monitors[0])
    scale = float(monitor.get("scale", 1))
    width, height = float(monitor["width"]), float(monitor["height"])
    if int(monitor.get("transform", 0)) % 2:
        width, height = height, width
    width, height = width / scale, height / scale
    # A readable small panel, clamped to the available logical display space.
    columns = max(22, min(30, int((width * 0.36 - 30) / 8)))
    lines = max(2, min(6, int((height * 0.55 - 132) / 40)))
    print(monitor["name"])
    print(columns)
    print(lines)
    print(int(monitor.get("x", 0)))
    print(int(monitor.get("y", 0)))
except (ValueError, TypeError, KeyError, IndexError, ZeroDivisionError):
    pass
' 2>/dev/null)
  if (( ${#layout[@]} == 5 )); then
    OUTPUT_ARGS=(--output "${layout[0]}" --output-x "${layout[3]}" --output-y "${layout[4]}")
    MENU_WIDTH=${layout[1]}
    MAX_LINES=${layout[2]}
    NAME_WIDTH=$((MENU_WIDTH - 6))
  fi
}

# Display names may be shortened; connection commands always use the full SSID.
display_name() {
  local name limit=${2:-$NAME_WIDTH}
  name=$(printf '%s' "$1" | tr '\000-\037\177' ' ')
  if (( ${#name} > limit )); then
    name="${name:0:limit-1}…"
  fi
  printf '%s' "$name"
}

items=()
kinds=()
ssids=()
secs=()

add() {
  items+=("$1")
  kinds+=("$2")
  ssids+=("${3:-}")
  secs+=("${4:-}")
}

main() {
  local radio current="" placeholder prompt_icon rows inuse sig sec ssid key n badge name padding
  local lines idx kind dev pw
  local -A seen=()

  configure_layout

  if ! radio=$(nmcli radio wifi 2>/dev/null); then
    notify "NetworkManager is unavailable"
    return 1
  fi

  if [[ "$radio" == "enabled" ]]; then
    # Show cached results immediately; the refresh action requests a fresh scan.
    nmcli device wifi rescan >/dev/null 2>&1 &
    rows=$(nmcli -t --escape no -f IN-USE,SIGNAL,SECURITY,SSID \
      device wifi list --rescan no 2>/dev/null)

    # The last field keeps colons and pipes in network names intact.
    while IFS=: read -r inuse sig sec ssid; do
      [[ -n "$ssid" && "$sig" =~ ^[0-9]+$ ]] || continue
      key="$sec:$ssid"
      [[ -z "${seen[$key]+present}" ]] || continue
      seen["$key"]=1

      if (( sig >= 75 )); then n=4
      elif (( sig >= 55 )); then n=3
      elif (( sig >= 35 )); then n=2
      elif (( sig >= 15 )); then n=1
      else n=0
      fi

      badge=" "
      [[ -n "${sec// /}" && "$sec" != "--" ]] && badge="$I_LOCK"
      if [[ "$inuse" == "*" ]]; then
        current="$ssid"
        badge="$I_CHECK"
      fi

      name=$(display_name "$ssid")
      printf -v padding '%*s' "$((NAME_WIDTH - ${#name}))" ''
      add "${SIG[$n]} ${name}${padding} ${badge}" net "$ssid" "$sec"
    done < <(printf '%s\n' "$rows" | sort -t: -k1,1r -k2,2nr)

    prompt_icon=$I_WIFI
    placeholder="Wi-Fi"
    (( ${#items[@]} == 0 )) && placeholder="No networks"

    add "${I_SCAN} Refresh" scan
    [[ -n "$current" ]] && add "${I_DISC} Disconnect" disc
    add "${I_OFF} Wi-Fi off" toggle
  else
    prompt_icon=$I_OFF
    placeholder="Wi-Fi off"
    add "${I_WIFI} Wi-Fi on" toggle
  fi

  lines=${#items[@]}
  (( lines > MAX_LINES )) && lines=$MAX_LINES
  if ! idx=$(printf '%s\n' "${items[@]}" | picker --index --only-match \
    --lines "$lines" --prompt "${prompt_icon} " --placeholder "$placeholder"); then
    return 0
  fi
  [[ "$idx" =~ ^[0-9]+$ ]] || return 0
  (( idx < ${#items[@]} )) || return 0

  kind="${kinds[$idx]}"
  ssid="${ssids[$idx]}"
  sec="${secs[$idx]}"

  case "$kind" in
    toggle)
      if [[ "$radio" == "enabled" ]]; then
        nmcli radio wifi off && notify "Wi-Fi turned off"
      else
        nmcli radio wifi on && notify "Wi-Fi turned on"
      fi
      return ;;
    disc)
      dev=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null \
        | awk -F: '$2=="wifi" && $3=="connected" {print $1; exit}')
      if [[ -n "$dev" ]] && nmcli device disconnect "$dev" >/dev/null 2>&1; then
        notify "Disconnected"
      else
        notify "Could not disconnect"
      fi
      return ;;
    scan)
      if ! nmcli device wifi list --rescan yes >/dev/null 2>&1; then
        notify "Could not refresh networks"
      fi
      exec bash "${BASH_SOURCE[0]}" ;;
  esac

  [[ "$ssid" == "$current" ]] && return 0
  notify "Connecting to $ssid…"

  # Reuse saved profiles, retaining their settings and credentials.
  if nmcli -t --escape no -f NAME connection show 2>/dev/null | grep -Fxq -- "$ssid"; then
    if nmcli connection up id "$ssid" >/dev/null 2>&1; then
      notify "Connected to $ssid"
      return 0
    fi
  elif [[ -z "${sec// /}" || "$sec" == "--" ]]; then
    if nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
      notify "Connected to $ssid"
    else
      notify "Could not connect to $ssid"
    fi
    return
  fi

  if ! pw=$(picker --lines 0 --password='•' \
    --mesg "$(display_name "$ssid" "$MENU_WIDTH")" \
    --prompt "${I_LOCK} " --placeholder "Password" </dev/null); then
    return 0
  fi
  [[ -n "$pw" ]] || return 0

  if nmcli device wifi connect "$ssid" password "$pw" >/dev/null 2>&1; then
    notify "Connected to $ssid"
  else
    notify "Could not connect to $ssid · check the password"
  fi
  unset pw
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
