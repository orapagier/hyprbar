# Daily-driver Settings roadmap

Recorded 2026-10-09. Updated 2026-10-10.

Goal: make Hyprshell usable every day by beginners and intermediate users,
with common tasks available through Settings rather than editing Lua.

Existing foundations: Wi-Fi, Bluetooth pairing, audio output selection,
screenshots, editable shortcuts, screen locking, cleanup, and GitHub config sync.

## Priorities

1. **Displays** — resolution, refresh rate, scaling, monitor arrangement,
   rotation, and timed rollback for unconfirmed changes. Implemented 2026-10-09;
   physical monitor testing remains because the agent session cannot access desktop IPC.
2. **Mouse, touchpad and keyboard** — pointer speed, natural scrolling,
   tap-to-click, keyboard layouts, repeat speed, and layout switching. Implemented
   2026-10-10; physical device testing remains.
3. **Power and battery** — dim/off timers, automatic suspend, lid behavior,
   brightness, and supported power profiles. Locking is a separate setting.
4. **Notifications** — optional popups, Do Not Disturb, per-app preferences,
   and critical alerts. Currently notifications go straight to the inbox.
5. **Sound improvements** — microphone device selection, input meter,
   test sound, and per-app volume. Output selection and microphone volume/mute exist.
6. **Default apps and startup** — browser, file associations, startup toggles,
   and GTK/Qt theme, font, and cursor controls.
7. **Updates and recovery** — guided full system upgrades, useful failure
   messages, configuration restore, and personal-file backup status.
   GitHub config sync does not back up documents.
8. **Advanced networking** — saved-network management, hidden Wi-Fi,
   enterprise connections, VPN, and access to advanced connection settings.
9. **Accessibility and regional settings** — larger text, high contrast,
   reduced motion, language, timezone, and date/number formats.
10. **Help and diagnostics** — Settings search, first-run guide, useful service
    errors, and privacy-conscious diagnostic reports. Super+K already provides
    a shortcut guide.

Intermediate-user follow-ups: window rules and behavior, workspace preferences,
clipboard history controls, and printing/scanning access.

Suggested order: Displays → Input → Power → Notifications → Recovery.
Current personal automatic-lock timeout is 60 minutes; consider shorter presets.

## Displays acceptance criteria

- Discover connected monitors and advertised modes; show actionable errors.
- Edit resolution/refresh, scale, rotation and logical X/Y positions.
- Explicit Apply; keep changes only after confirmation within 15 seconds.
- Restore previous live layout on timeout, cancellation or UI shutdown.
- Save confirmed preferences, back up replaced files and detect concurrent edits.
- Preserve installer and GitHub sync behavior; retain automatic fallback for new hardware.
- Test transactions in isolated environments; test native QML and verify Lua.
- Physical monitor behavior must be checked in an accessible desktop session.

## Handoff for tomorrow

Displays now has advertised resolution/refresh controls, scale, rotation, automatic
arrangement, relative placement buttons, and precise X/Y fields. Apply previews the
layout; Keep commits it, with a 15-second backend timeout and rollback. Installer
and sync preserve confirmed settings. See `docs/settings.md` for implementation
limits and usage.

First check the Displays page on the real laptop (and an external screen if
available): confirm a change, allow a timeout, then check restart persistence.
The automated suite uses isolated settings and simulated compositor responses.
Priority 2 is now implemented; see the input handoff below.

Validation: 11 display checks passed (including native QML and real Lua parsing),
140 existing Qt tests passed, and native Settings lifecycle/autosave checks passed.
The broader Python run passed 81 of 82 checks; the unrelated shortcut-recording
check references a missing `config/quickshell/tests/ShortcutRecording.qml` fixture.
Native runtime dependency checks passed. Live monitor IPC was inaccessible.

Displays follow-up: fixed `hyprctl eval` rejecting a leading Lua comment as a CLI
flag. Runtime snippets now start with executable Lua; saved files keep their
header. Errors remain red after automatic refresh and command-help dumps are
replaced by concise messages. All 13 display regression checks pass, including
real CLI argument parsing in an isolated runtime. Physical preview still needs
verification in the desktop session.

The 5-percentage-point scale slider was reverted after physical testing showed
errors at values such as 105% and 110%. Scaling uses the previous preset dropdown. The laptop panel's kernel mode list reports only
1920×1080; resolution choices continue to use advertised modes.

Application theme is now available separately from topbar appearance: Dark/Light
updates desktop and GTK preferences and enables GTK integration for newly opened
Qt applications. Saved mode travels through setup and GitHub sync. Native toggle
and transaction checks cover failure recovery and unchanged bar preferences.

Launcher follow-up: desktop entries now launch through UWSM services so they
inherit the updated Qt theme environment and honor Terminal=true. UWSM's default
terminal selection chose Kitty's URL launcher; xdg-terminals.list now prefers the
real Kitty terminal. Real command generation resolves Vim to `kitty -- vim`.
Vim opened normally in an isolated PTY. GParted's installed wrapper expects
xhost, which is absent; xorg-xhost was added to packages.txt. Live installation
requires `sudo pacman -S --needed xorg-xhost` from the user's terminal because the
agent session cannot elevate privileges. Confirm remaining light apps by name.

Confirmed light apps: GParted and About Xfce. Both link GTK 3. Scoped themed
launcher entries now read the saved mode on each launch. About Xfce gets an
explicit GTK variant; GParted gets it after normal administrator authentication,
with temporary root-only display access and the upstream wrapper preserved.
Automated tests cover dark/light, argument boundaries, cancellation/error cleanup,
and preservation of existing display permissions. Check visual results by fully
closing and reopening these apps from the launcher in the desktop session.

## Input handoff — 2026-10-10

Settings → Mouse & keyboard now includes pointer speed, independent mouse and
touchpad natural scrolling, tap-to-click, disabling touchpad while typing,
common/custom keyboard layouts, layout-switch shortcuts, repeat speed/delay,
and a temporary typing test field. Preferences inherit existing input config
until edited, and each override can be removed. Device-specific rules can
still take priority. Switching overrides the existing XKB options; variants
remain configured in input.lua.

Repository and live Quickshell payloads are updated together. Setup regenerates
GUI overrides from saved settings, including input and appearance preferences,
so the existing GitHub snapshot is restorable. Physical input testing remains
because desktop IPC is inaccessible from the agent session.

Next: check input controls on the laptop, then priority 3, Power and battery.
Validation: 21 settings backend checks, 15 installer checks, 147 Qt checks,
3 native Settings lifecycle/autosave checks, and native runtime dependencies.
