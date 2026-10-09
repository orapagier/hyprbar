#!/usr/bin/env bash
# Install the native Hyprshell desktop into the current user's Arch system.
set -Eeuo pipefail
umask 022

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
MODE=install
DRY_RUN=0
INSTALL_GREETER=0
INSTALL_APPS=0
SKIP_BROWSER=0
TIMEZONE=

usage() {
  cat <<'HELP'
Usage: ./setup.sh [options]

Run as your normal user, with sudo access, on an installed Arch Linux system.
  --dry-run          Check installed packages and show the plan; change nothing
  --config-only      Copy configs, compile helpers, and copy wallpapers only
  --with-greeter     Install COSMIC Greeter if no display manager is configured
  --extra            Also install daily-driver apps from packages-apps.txt
  --skip-browser     Exclude Chromium from --extra
  --timezone ZONE    Set the system timezone (default: preserve current timezone)
  --keep-timezone    Leave the system timezone unchanged
  -h, --help         Show this help

Hyprland and Quickshell are checked first; missing desktop dependencies are
installed from official Arch repositories. Daily-driver apps are opt-in;
no AUR apps are installed. --config-only skips all package installation.
Existing configs are backed up under ~/.local/state/hyprshell/backups/.
XDG_CONFIG_HOME and XDG_STATE_HOME are respected. A reboot is recommended.
HELP
}

die() { printf 'hyprshell: %s\n' "$*" >&2; exit 1; }
log() { printf '\n==> %s\n' "$*"; }
trap 'printf "hyprshell: setup failed at line %s. Fix the reported error and rerun setup.sh.\n" "$LINENO" >&2' ERR

while (( $# )); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --config-only) MODE=config-only ;;
    --with-greeter) INSTALL_GREETER=1 ;;
    --extra) INSTALL_APPS=1 ;;
    --no-greeter) INSTALL_GREETER=0 ;; # Compatibility with the old installer.
    --skip-browser) SKIP_BROWSER=1 ;;
    --keep-timezone) TIMEZONE= ;;
    --timezone)
      (( $# >= 2 )) || die '--timezone requires a timezone name'
      TIMEZONE=$2
      shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1 (see --help)" ;;
  esac
  shift
done

[[ -n "${HOME:-}" && "$HOME" == /* ]] || die 'HOME must be an absolute path'
CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}
[[ "$CONFIG_DIR" == /* && "$STATE_DIR" == /* ]] || die 'XDG paths must be absolute'
[[ -f "$REPO_DIR/config/quickshell/shell.qml" && -f "$REPO_DIR/packages.txt" ]] || die 'Run setup.sh from a complete clone of the repository'
mapfile -t PACKAGES < <(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$REPO_DIR/packages.txt")
if (( INSTALL_APPS )); then
  [[ -f "$REPO_DIR/packages-apps.txt" ]] || die 'Missing packages-apps.txt; use a complete clone of the repository'
  mapfile -t APP_PACKAGES < <(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$REPO_DIR/packages-apps.txt")
  for package in "${APP_PACKAGES[@]}"; do
    if (( SKIP_BROWSER )) && [[ "$package" == chromium ]]; then continue; fi
    PACKAGES+=("$package")
  done
fi
# Optional lists may share packages (for example playerctl).
declare -A SEEN_PACKAGES=()
UNIQUE_PACKAGES=()
for package in "${PACKAGES[@]}"; do
  if [[ -z "${SEEN_PACKAGES[$package]:-}" ]]; then
    UNIQUE_PACKAGES+=("$package")
    SEEN_PACKAGES[$package]=1
  fi
done
PACKAGES=("${UNIQUE_PACKAGES[@]}")

check_packages() {
  log 'Checking Hyprland and Quickshell'
  local package missing_text status
  for package in hyprland quickshell; do
    if pacman -T "$package" >/dev/null 2>&1; then
      printf '%s: installed (will be updated with the system)\n' "$package"
    else
      printf '%s: missing (will be installed)\n' "$package"
    fi
  done
  # -T understands providers such as hyprland-git, unlike pacman -Q hyprland.
  missing_text=$(pacman -T "${PACKAGES[@]}") || {
    status=$?
    (( status == 127 )) || die 'Could not query the pacman dependency database'
  }
  MISSING_PACKAGES=()
  if [[ -n "$missing_text" ]]; then
    mapfile -t MISSING_PACKAGES <<< "$missing_text"
  fi
  if ((${#MISSING_PACKAGES[@]})); then
    printf 'Missing desktop packages: %s\n' "${MISSING_PACKAGES[*]}"
  else
    printf 'All desktop packages are installed.\n'
  fi
}

if (( DRY_RUN )); then
  log 'Preview only; no files, packages, services, or settings will change'
  if [[ "$MODE" == install ]]; then
    if command -v pacman >/dev/null; then check_packages; fi
    printf 'Full Arch upgrade; ensure desktop packages: %s\n' "${PACKAGES[*]}"
    (( INSTALL_GREETER == 0 )) || printf 'Login screen: install/enable cosmic-greeter only if no display manager is configured\n'
    printf 'Enable NetworkManager, Bluetooth, UPower, PipeWire, and WirePlumber; Quickshell owns the notification inbox\n'
    printf 'Timezone: %s\n' "${TIMEZONE:-unchanged}"
  fi
  printf 'Config destination: %s\nWallpaper destination: %s\n' "$CONFIG_DIR" "$HOME/Pictures/Wallpapers"
  printf 'Backups: %s/hyprshell/backups/\n' "$STATE_DIR"
  exit 0
fi

(( EUID != 0 )) || die 'Run as your normal desktop user, not root or sudo ./setup.sh'
if [[ "$MODE" == install ]]; then
  [[ -f /etc/arch-release ]] || die 'This installer supports Arch Linux'
  [[ $(uname -m) == x86_64 ]] || die 'This setup currently supports x86_64 Arch Linux'
  command -v sudo >/dev/null || die 'Install sudo and grant your user sudo access first'
  command -v pacman >/dev/null || die 'pacman is required'
  if [[ -n "$TIMEZONE" ]]; then
    [[ "$TIMEZONE" != /* && "$TIMEZONE" != *..* && -f "/usr/share/zoneinfo/$TIMEZONE" ]] || die "Unknown timezone: $TIMEZONE"
  fi
  check_packages
  sudo -v
  log 'Upgrading Arch and installing missing desktop dependencies'
  # Always upgrade together with installation to avoid unsupported partial upgrades.
  # Already-satisfied packages keep their existing explicit/dependency status.
  sudo pacman -Syu --needed --noconfirm "${MISSING_PACKAGES[@]}"

  python3 - <<'PY'
import json, re, subprocess
info = json.loads(subprocess.check_output(['Hyprland', '--version-json'], text=True))
version = tuple(map(int, re.findall(r'\d+', info['version'])[:3]))
if version < (0, 56, 0):
    raise SystemExit('Hyprland 0.56 or newer is required; update your Arch mirrors and rerun.')
print('Hyprland version:', info['version'])
PY
fi

command -v python3 >/dev/null || die 'Python 3 is required for --config-only'
log 'Installing configs and wallpapers, with backups for changed files'
python3 "$REPO_DIR/tools/install_configs.py" "$REPO_DIR"

if [[ "$MODE" == config-only ]]; then
  log 'Configs installed. Packages, services, and timezone were left unchanged.'
  exit 0
fi

log 'Validating the installed configuration and refreshing fonts'
python3 "$REPO_DIR/tools/check_runtime.py" --native
# Arch's unqualified qmltestrunner may be Qt 5; this config requires Qt 6.
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software /usr/lib/qt6/bin/qmltestrunner -input "$CONFIG_DIR/quickshell/tests"
Hyprland --verify-config --config "$CONFIG_DIR/hypr/hyprland.lua"
fc-cache -f
xdg-user-dirs-update

log 'Enabling networking, Bluetooth, battery information, and audio'
sudo systemctl enable --now NetworkManager.service bluetooth.service
# UPower is D-Bus activated (a static unit), so start it rather than enable it.
sudo systemctl start upower.service
if [[ -n "$TIMEZONE" ]]; then
  sudo timedatectl set-timezone "$TIMEZONE"
fi

# Enabling units works from a TTY even when there is no active user bus.
systemctl --user --root=/ --no-reload enable pipewire.socket pipewire-pulse.socket wireplumber.service
if systemctl --user daemon-reload; then
  systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service
else
  printf 'User services are enabled and will start at the next login.\n'
fi

if (( INSTALL_GREETER )) && [[ ! -e /etc/systemd/system/display-manager.service ]]; then
  log 'Installing the optional COSMIC login screen'
  sudo pacman -S --needed --noconfirm cosmic-greeter
  sudo systemctl enable cosmic-greeter.service
  sudo systemctl set-default graphical.target
fi

log 'Setup complete'
printf 'Reboot, then select "Hyprland (uwsm-managed)" if you use a login screen.\n'
printf 'From a TTY run: uwsm start -e -D Hyprland hyprland.desktop\n'
printf 'SUPER+T opens Kitty; SUPER+E opens Nautilus; press and release SUPER for the launcher.\n'
printf 'Existing config backups: %s/hyprshell/backups/\n' "$STATE_DIR"
