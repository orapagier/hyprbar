# Hyprshell shortcuts for interactive Bash.
pcm() { sudo pacman -S --needed "$@"; }

# Common names also work before their containers have been created.
fedora() { distrobox enter fedora "$@"; }
ubuntu() { distrobox enter ubuntu "$@"; }

# Register other existing boxes without replacing commands or shell functions.
# Run this again after creating a box, or open a new terminal.
hyprshell_refresh_boxes() {
    command -v distrobox >/dev/null 2>&1 || return 0
    local box
    while IFS= read -r box; do
        [[ $box =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]] || continue
        command -v "$box" >/dev/null 2>&1 && continue
        eval "$box() { distrobox enter '$box' \"\$@\"; }"
    done < <(distrobox list --no-color 2>/dev/null | awk -F '|' 'NR > 1 {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
    return 0
}
hyprshell_refresh_boxes
