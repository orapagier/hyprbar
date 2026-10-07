#!/usr/bin/env bash
# Install the complete Hyprbar desktop into the current user's Arch system.
set -Eeuo pipefail
umask 022

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
MODE=install
DRY_RUN=0
INSTALL_BROWSER=1
INSTALL_GREETER=1
TIMEZONE=Asia/Manila
BUILD_DIR=

usage() {
  cat <<'EOF'
Usage: ./setup.sh [options]

Run as your normal user, with sudo access, on an installed Arch Linux system.
  --dry-run          Show the plan without changing anything
  --config-only      Copy configs and wallpapers only; no packages or services
  --skip-browser     Skip installing Brave from the AUR
  --no-greeter       Skip setting up COSMIC Greeter on systems without a greeter
  --timezone ZONE    Set the system timezone (default: Asia/Manila)
  --keep-timezone    Leave the system timezone unchanged
  -h, --help         Show this help

Existing configs are backed up under ~/.local/state/hyprbar/backups/.
XDG_CONFIG_HOME and XDG_STATE_HOME are respected. A reboot is recommended.
EOF
}

die() { printf 'hyprbar: %s\n' "$*" >&2; exit 1; }
log() { printf '\n==> %s\n' "$*"; }
cleanup() { [[ -z "$BUILD_DIR" ]] || rm -rf -- "$BUILD_DIR"; }
trap cleanup EXIT
trap 'printf "hyprbar: setup failed at line %s. Fix the reported error and rerun setup.sh.\n" "$LINENO" >&2' ERR

while (( $# )); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --config-only) MODE=config-only ;;
    --skip-browser) INSTALL_BROWSER=0 ;;
    --no-greeter) INSTALL_GREETER=0 ;;
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
[[ -f "$REPO_DIR/config/waybar/style.css" ]] || die 'Run setup.sh from a complete clone of the repository'
mapfile -t PACKAGES < <(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$REPO_DIR/packages.txt")

if (( DRY_RUN )); then
  log 'Preview only; no files, packages, services, or settings will change'
  if [[ "$MODE" == install ]]; then
    printf 'Full Arch upgrade and packages: %s\n' "${PACKAGES[*]}"
    (( INSTALL_BROWSER == 0 )) || printf 'Browser: build and install brave-bin from the AUR as the current user\n'
    (( INSTALL_GREETER == 0 )) || printf 'Login screen: install/enable cosmic-greeter only if no display manager is configured\n'
    printf 'Enable NetworkManager, Bluetooth, PipeWire, WirePlumber, and the notification inbox\n'
    printf 'Timezone: %s\n' "${TIMEZONE:-unchanged}"
  fi
  printf 'Config destination: %s\nWallpaper destination: %s\n' "$CONFIG_DIR" "$HOME/Pictures/Wallpapers"
  printf 'Backups: %s/hyprbar/backups/\n' "$STATE_DIR"
  exit 0
fi

(( EUID != 0 )) || die 'Run as your normal desktop user, not root or sudo ./setup.sh'
if [[ "$MODE" == install ]]; then
  [[ -f /etc/arch-release ]] || die 'This installer supports Arch Linux'
  [[ $(uname -m) == x86_64 ]] || die 'This setup currently supports x86_64 Arch Linux'
  command -v sudo >/dev/null || die 'Install sudo and grant your user sudo access first'
  if [[ -n "$TIMEZONE" ]]; then
    [[ "$TIMEZONE" != /* && "$TIMEZONE" != *..* && -f "/usr/share/zoneinfo/$TIMEZONE" ]] || die "Unknown timezone: $TIMEZONE"
  fi
  sudo -v
  log 'Upgrading Arch and installing the desktop dependencies'
  sudo pacman -Syu --needed --noconfirm "${PACKAGES[@]}"

  # The configuration uses the Lua APIs available in the original 0.56 desktop.
  python3 - <<'PY'
import json, re, subprocess
info = json.loads(subprocess.check_output(['Hyprland', '--version-json'], text=True))
version = tuple(map(int, re.findall(r'\d+', info['version'])[:3]))
if version < (0, 56, 0):
    raise SystemExit('Hyprland 0.56 or newer is required; update your Arch mirrors and rerun.')
print('Hyprland version:', info['version'])
PY

  if (( INSTALL_BROWSER )) && ! pacman -Q brave-bin >/dev/null 2>&1; then
    log 'Building Brave from the AUR as your user'
    BUILD_DIR=$(mktemp -d -t hyprbar-brave.XXXXXXXX)
    git clone --depth 1 https://aur.archlinux.org/brave-bin.git "$BUILD_DIR/brave-bin"
    (cd -- "$BUILD_DIR/brave-bin" && makepkg --syncdeps --install --needed --noconfirm)
  fi

  if (( INSTALL_GREETER )) && [[ ! -e /etc/systemd/system/display-manager.service ]]; then
    log 'Installing the COSMIC login screen'
    sudo pacman -S --needed --noconfirm cosmic-greeter
    # Enable for the next boot; do not interrupt the current login session.
    sudo systemctl enable cosmic-greeter.service
    sudo systemctl set-default graphical.target
  fi
fi

command -v python3 >/dev/null || die 'Python 3 is required for --config-only'
log 'Installing configs and wallpapers, with backups for changed files'
python3 "$REPO_DIR/tools/install_configs.py" "$REPO_DIR"

if [[ "$MODE" == config-only ]]; then
  log 'Configs installed. Packages, services, and timezone were left unchanged.'
  exit 0
fi

log 'Validating the installed configuration and refreshing fonts'
python3 "$REPO_DIR/tools/check_runtime.py" "$CONFIG_DIR/waybar"
Hyprland --verify-config --config "$CONFIG_DIR/hypr/hyprland.lua"
fc-cache -f
xdg-user-dirs-update

log 'Enabling networking, Bluetooth, and audio'
sudo systemctl enable --now NetworkManager.service bluetooth.service
if [[ -n "$TIMEZONE" ]]; then
  sudo timedatectl set-timezone "$TIMEZONE"
fi

# Enabling units works from a TTY even when there is no active user bus.
systemctl --user --root=/ --no-reload enable pipewire.socket pipewire-pulse.socket wireplumber.service waybar-notification-monitor.service
if systemctl --user daemon-reload; then
  systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service waybar-notification-monitor.service
else
  printf 'User services are enabled and will start at the next login.\n'
fi

log 'Setup complete'
printf 'Reboot, then select "Hyprland (uwsm-managed)" on the login screen.\n'
printf 'From a TTY you can also run: uwsm start -e -D Hyprland hyprland.desktop\n'
printf 'SUPER+T opens a terminal; press and release SUPER for the launcher.\n'
printf 'Existing config backups: %s/hyprbar/backups/\n' "$STATE_DIR"
