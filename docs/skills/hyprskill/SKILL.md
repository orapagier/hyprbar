---
name: hyprskill
description: Diagnose, customize, or maintain this user's Linux machine and desktop, including requests about my system, laptop, display, shortcuts, bar, menus, notifications, wallpaper, audio, Wi-Fi, Bluetooth, locking, or desktop settings. Knows the local Hyprshell setup without the user naming it. Excludes unrelated application or repository work.
---

# Hyprskill

This machine uses Arch Linux, Hyprland **Lua** configuration, and Hyprshell's native Qt 6 Quickshell desktop. Do not assume hyprland.conf, Waybar, Rofi, or a separate notification daemon.

Resolve paths independently of the working directory:
- Config root: `${XDG_CONFIG_HOME:-$HOME/.config}`.
- State root: `${XDG_STATE_HOME:-$HOME/.local/state}`.
- Checkout: read `<state>/hyprshell/repository`; verify it contains `setup.sh` and `config/quickshell/shell.qml`. Fallback: `$HOME/repos/hyprshell`. If neither exists, ask for its location rather than searching the entire home directory.

For a machine request, start with the relevant installed config and focused runtime evidence. For a project implementation, inspect the checkout and `git status --short`. Installed configs are **copies**, not symlinks: compare the relevant live and repo files before editing. A desktop change should normally be preserved in the checkout and applied to the matching live file when authorized by the request; reconcile differing edits rather than overwriting either copy. State which copies changed.

The user's standing preference is to preserve desktop and machine setup in
Hyprshell so running `setup.sh` on a fresh Arch laptop restores the saved
desktop. For future customizations, update the repository payload and installer
as needed, then apply the matching live change. Keep hardware-specific settings
adaptable and credentials outside the repository. Do not promise identical
hardware behavior on a different laptop.

Read only the reference needed:
- [Desktop map](references/desktop.md): ownership, exact paths, settings workflow, checks, logs, and reloads.
- [Machine facts](references/machine.md): this laptop's observed hardware and personal configuration; read for hardware or machine-specific questions.

Use targeted reads and bounded logs; do not inventory packages or read the entire README on every request. Verify changing facts only when relevant. Session socket/D-Bus access failures in an agent sandbox do not establish that the desktop or services are broken. Report inaccessible checks precisely; do not guess socket paths or bypass sandbox restrictions.

Do not run the full installer for a small edit: it upgrades packages and config-only still replaces config directories. Validate the affected component before reloading. Commit/push, cleanup deletion, and ending the session require task authorization; this skill does not supply it. Keep credentials, notification contents, and unrelated personal files out of repository documentation. Update these references when a verified setup change makes them stale.
