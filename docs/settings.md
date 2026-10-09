# Settings implementation

The settings app is part of the existing Quickshell process. `SettingsWindow.qml`
is created on demand by `SettingsController.qml` through the `bar settings` IPC
method; `bin/hyprshell-settings` and the desktop entry provide normal
application-launcher access. No web server,
browser, or additional GUI framework is required.

`SettingsController.qml` owns a `LazyLoader` that is inactive at startup. Both
the cog and launcher activate the same controller. Closing the native window
flushes pending edits; the controller waits for the writer and debounce timer
to become idle before unloading all controls and the preview. If saving fails,
only the draft, original snapshot, selected section, and error are retained in
the controller, then restored on the next open. Reopening during a save keeps
the current window and draft alive. Saved settings and desktop services remain
in the always-loaded store and service components.

`settings/defaults.json` defines schema version 1 and the built-in module IDs:
launcher, settings, workspaces, media, calendar, tray, notifications, audio, wifi,
bluetooth, battery, power. `SettingsStore.qml` merges saved preferences with
defaults, watches changes, and retains the last readable configuration when
JSON parsing fails. `SettingsModel.js` is shared by the window and the bar.

The preview captures click and drag gestures through `PreviewLayoutEditor.qml`.
Clicking selects an item's editor. Dragging shows an insertion marker; dropping
reorders within a group or moves between left, center, and right. Empty preview
space uses the corresponding third of the bar. Dropping outside cancels.
`SettingsModel.reorder` preserves appearance settings and hidden items while
assigning unique orders. The tray uses a sample icon so it can be rearranged too.
Changes enter the normal autosave flow only on drop.

**Reset item** restores the last successfully saved appearance and position,
using saved neighbours after drag operations renumber a group. It never loads
bundled item defaults. The button waits for any in-flight save to finish.
Because edits autosave, already saved edits become the new reset point.

**Bar & layout → Default appearance → Random vibrant item colors** gives
inheriting item icons and labels distinct bright colors. The shuffled palette
reshuffles when the wallpaper image changes, while staying stable during edits
and matching the preview to the live bar on the same screen. Returning to a
wallpaper restores its palette for the current session. Colors stay bright on pale and dark wallpapers. Pill backgrounds become darker
and more opaque where needed for contrast; icons without pills use a thin dark
outline. Restarting the shell reshuffles the palette. Turning it off restores the current
theme. Manual text/icon colors and explicit item adaptation on/off choices take
priority. Pill backgrounds adapt with the vibrant accent for contrast, and tray artwork remains
application-provided. The preference defaults to off on existing installations.

Background controls use an explicit **Show background pill** switch: switching
off removes the pill immediately in the preview and saves that choice. The
general control affects all inheriting items; each item can set its own switch
or choose **Use general setting** to follow the global choice again.

The editor keeps a draft and saves it automatically after 500 ms without an
edit. A bottom status message names the settings in the successfully saved
snapshot (for example, “Bluetooth settings saved!”) and clears after two seconds.
Opening the window shows no save confirmation; save errors remain visible.
Closing the window flushes pending edits. Native window closes also reset
the requested visibility, so subsequent launches remap it correctly. Opening
an already visible Settings window requests focus by its existing window address
without resetting the draft or its tiled/floating state. Each save invokes
`settings/backend.py` with an argument array, without shell
interpolation. The backend validates all values and rejects unknown settings,
duplicate module IDs, malformed colors, unsupported schema versions, and
out-of-range numbers. A file lock serializes writes, and comparison with the
editor's initial snapshot prevents overwriting settings changed by another
window or tool. Malformed stored files must be repaired before saving.
The editor captures the submitted snapshot separately from the current draft:
edits made during a write queue another save after that write completes. Invalid
values are not saved; correcting the input retries automatically. Errors do
not cause a continuous retry loop. A Reset unsaved changes button appears
when validation or saving fails.

`GlassSymbol.qml` provides a reflective vector fill and edge, shared by
`GlassLogo.qml` and `GlassCog.qml`. The cog has a rounded gear silhouette and
transparent center. Both retain the original menu hit areas and feedback;
their default pill backgrounds are hidden. Offset glass silhouettes add depth,
with a bright front rim and a smooth reflective face. The cog uses a standard
settings silhouette with an open hub.

The top-level keys are `version`, `bar`, `items`, `hyprland`, `locking`, and `power`. Item entries
are keyed by `id`; missing entries/properties inherit bundled defaults.
`side` accepts `left`, `center`, or `right`; `order` sorts within that side.
The three groups are positioned independently, so unusually wide custom text
or an overcrowded center group can overlap adjacent groups. Shorten overrides,
reduce font size, hide modules, or distribute items between groups in that case.

`bar.spacing` sets the general gap between visible items. Select a module in
the sidebar or preview and use its **Item spacing** card to adjust **Space before adjustment** and **Space after adjustment** independently of that global gap.
Reset either slider to restore the global gap on that side. Each item's
`spacingLeft` and `spacingRight` adjust space outside its pill by −200–200 px; negative values reduce gaps,
positive values add space, and the final gap is clamped at zero to avoid overlap.
Outer group margins are also clamped at zero;
these margins also count toward group alignment. For example, general spacing
of 5 plus Wi-Fi's `spacingRight: 10` leaves 15 px before Bluetooth (with
Bluetooth's left spacing at 0). Hidden items contribute no spacing.

`bar.background` accepts `inherit`, `on`, or `off`. Inherit preserves each
component's original background; on/off shows/hides all item pills. Individual
`background` overrides take priority; inherit follows the global choice.

`adaptiveColors` and `background` on items accept `inherit`, `on`, or `off`.
Empty text/icon/color strings inherit original values. `hideText` and
`hideIcon` explicitly hide those parts. `backgroundOpacity: -1`, `radius: -1`,
and `fontSize: 0` inherit component defaults. Manual color fields override
adaptive results without disabling adaptation for the other fields. Colors
are RGB; alpha comes from the separate opacity controls. Font glyphs use the
installed Nerd Font; image files are not accepted as custom icons yet.
For controls whose original glyph is in the text field (Wi-Fi, Bluetooth,
notifications, power), use the text/glyph override to replace it. Icon color
also colors these original glyphs. Launcher icon color colors the glass logo;
media icon color colors the spectrum, and Hide icon hides the spectrum.
Tray artwork remains application-provided; text/icon overrides do not replace it.

`Bar.qml` keeps existing component identities and service connections while
computing each item's position from its group, order, visibility, and width.
Menu anchors read those coordinates directly. Each popdown card is centered
under its trigger and clamped to 12px screen margins, so moving or reordering
an item updates both the card and connector, including while pinned open. `Pill.qml` implements reusable appearance
overrides; a null sampler selects original static colors. Notifications and
other shared services are independent of status-item visibility.

Hyprland controls are explicit overrides, not a full configuration editor.
The app never assumes the visible numbers in a user's Lua file are the effective
runtime values. An empty field means unmanaged, including on first launch.
`backend.py` contains a whitelist mapping GUI keys to Hyprland configuration
paths. It generates Lua tables or traditional config options; user strings
never become executable Lua. The Lua source hook in the bundled config runs
after `hyprland-gui.lua`, so the settings app's explicit overrides take priority.
Other users' main configs receive a source hook only on their first Hyprland
appearance change. Hyprland source integration assumes the conventional
`$XDG_CONFIG_HOME/hypr/hyprland.lua` or `hyprland.conf` path.

To extend the app with another built-in module, add its defaults, register its
component in `Bar.moduleItems`, bind visibility/position/appearance, and add its
display name in `SettingsWindow.qml`. Extend backend validation and regression
checks when adding a setting. Supporting another Quickshell shell requires an
adapter that implements these settings against that shell's components; parsing
arbitrary QML is not a reliable substitute.

Checks:

```sh
python3 -m unittest discover -s tests -v
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  /usr/lib/qt6/bin/qmltestrunner -input config/quickshell/tests
```

Python checks isolate XDG directories and exercise validation, concurrent edits,
backups, Lua/conf source integration, and rollback after reload/write failures.
Native UI checks also close/reopen real windows and exercise on-demand loading,
queued writes during close, destruction after saving, failed-draft restoration,
and reopening during a write.
QML checks cover visibility/layout changes, ordering, menu anchors, global and
per-item adaptation, manual style overrides, and hidden media lifecycle, alongside
the existing service/component regression suite.

The Hyprland appearance page groups controls into transparency, glass and blur,
window geometry, and motion/depth cards. The bar preview is hidden on this page
to leave room for the compositor controls. Cards use two columns on wider
windows and stack controls at narrower widths. Sliders support dragging, clicking,
and keyboard arrows. Transparency is displayed as 0–100% and saved as inverse
opacity (25% transparency means `activeOpacity: 0.75`).

Glass controls map `blurSize` (1–20), `blurPasses` (1–4), and `blurVibrancy`
(0–1, displayed as a percentage) to `decoration.blur.size`, `.passes`, and
`.vibrancy`. These ranges provide bounded controls for the options documented in
[Hyprland's blur reference](https://wiki.hypr.land/0.54.0/Configuring/Variables/#blur).
Blur sliders are disabled when blur is explicitly off; their saved values remain
available when it is enabled again. Translucency is needed to see blur behind
otherwise opaque windows; application-specific opacity rules can take priority.

Unmanaged sliders read “Use config” and show a suggested thumb position, not
an inferred runtime value. They do not write an override until interacted with.
Each reset arrow removes just that override and restores configuration inheritance.
Sliders use the same validated, debounced autosave and rollback path as other
settings. There are no new overrides on upgrade or when merely opening the page.

Icon sizing is available in **Overview and bar** and each item's editor.
`bar.iconSize` sets all icons to 8–48 px; `0` keeps original sizes. Each item's
`iconSize` overrides the global value, with `0` following the global setting.
Reset arrows restore original sizes globally or inheritance individually.
Glyph icons, the glass logo and cog, tray artwork, and the media spectrum resize
in the live preview and the running bar. Labels and the battery percentage retain
their own font sizes. Larger icons expand their hit areas and the bar height to
avoid clipping. Items without a built-in icon use this size for icon overrides.
Old experimental motion preferences are ignored and removed on the next save;
popdowns use the original fade-and-slide transition.

All settings pages share the same card structure and spacing. **Bar & layout**
groups layout sliders, default appearance, and clock formatting with a sample.
Item pages group visibility/position, text/icon overrides, colors/background,
and shape/transparency. Grids stack into one column below 600 px of editor
width; background switches and inheritance actions also stack in narrow cards.
The live bar preview scales to fit narrower windows. Sliders display pixel or
percentage units; reset arrows restore bundled bar defaults or the original item
appearance as appropriate. The final item restore action retains its existing
last-saved semantics. Hover, focus, and switch transitions use the shared native
controls; no new configuration keys or startup services are introduced.

## Screen locking

The Screen locking page selects a foreground Wayland locker command, an idle
period (0–240 whole minutes; 0 disables the timer), and locking before sleep.
Automatic locking defaults to off. Existing preferences inherit these defaults.
Lock now runs the last saved command without enabling automatic locking.
Commands accept quoted arguments and `~` paths; no shell operators or environment
variable expansion is performed. Configure the chosen locker's appearance in
its own configuration file, for example `hypr/hyprlock.conf`.

`LockingController.qml` owns a Hypridle child while automatic locking is enabled,
restarting it only when locking preferences change. Closing Settings does not
stop locking or a manually started locker. The controller reports startup and
locker errors in Settings. Backend validation checks installed dependencies when
enabling/changing automatic locking. An existing Hypridle process is left alone
and reported as a conflict; disable its user service/autostart before enabling
Hyprshell management. The generated `hyprshell/hypridle.conf` belongs to Hyprshell;
`hypr/hypridle.conf` and locker configuration files are preserved. This controller
runs only with Hyprshell; it does not install a separate background service.

The backend's `--lock` executes the configured argv directly and serializes
foreground locker requests. `--idle` generates Hypridle configuration with only
fixed helper commands; user commands are never interpolated into Hyprlang or Lua.
Automatic locking uses Hypridle's normal inhibitor handling and D-Bus sleep/lock
events. Custom lockers must support your session and remain in the foreground
until unlocked; test authentication with Lock now before relying on automation.

### System cleanup

Open **System cleanup** in Hyprshell Settings. Choose Off, Daily, Weekly, or
Monthly, select cleanup categories, then click **Save cleanup settings**. This
separate save manages `hyprshell-cleanup.timer` in your systemd user session.
Scheduling defaults to Off; the age limit defaults to 30 days and the newest
five Hyprshell backup sets are retained.

Cleanup includes old thumbnail cache files, your own regular files in `/tmp`
and `/var/tmp`, and old files in Hyprshell's configuration backup directory
(`$XDG_STATE_HOME/hyprshell/backups`, normally `~/.local/state/hyprshell/backups`).
Recently accessed, modified, or changed files are kept. Symlinks are skipped,
empty directories remain, and active configurations are excluded.

**Clean System Now…** displays the eligible paths, individual sizes, and total
size using the saved choices. **Delete previewed files** confirms deletion;
if the eligible files changed, preview again. Scheduled runs apply the same
rules without prompting. Results are recorded in
`$XDG_STATE_HOME/hyprshell/cleanup-last.json` and the service journal.

The page also reports the existing system `paccache.timer` status. Package-cache
cleanup stays with that timer; it is independent of the user cleanup schedule
and manual file preview.


### GitHub sync

Use ** Sync to GitHub** in the settings header. Authenticate with GitHub; the
popup automatically finds `<your-account>/hyprshell` and displays that target.
Your GitHub username and account ID supply the commit identity using GitHub's
noreply email, so there are no name or email fields. Sync saves that identity
only in this checkout's Git config.

Both forks and standalone repositories named `hyprshell` work. If your account
has no accessible repository with that name, the popup offers **Fork Hyprshell**
and **Create repository** links. Finish creating it in your own account, then
click **Check again**. For a new standalone repo, leave README, license, and
.gitignore initialization unchecked so the first push can populate it. Sync is
enabled once the repository exists and the signed-in account has push access.

Authenticate opens Kitty with GitHub CLI browser sign-in and sets up its Git
credential helper. If GitHub CLI is missing, the terminal offers to install
`github-cli` through pacman. No password or token is entered into Hyprshell.
The account and repository are checked again on each sync, including after an
account switch. The checkout's origin remote is preserved; the push explicitly
targets the authenticated user's repository.

Sync snapshots live `hypr/` and `quickshell/` config directories and saved
`hyprshell/settings.json` into the local checkout first, then commits the snapshot
and pushes the current branch. It also captures saved cleanup preferences and
the live versions of installer-managed portal files, autostart entries, launcher
scripts, application entries, and bundled wallpapers. Only names already managed
by the checkout are copied from these shared directories; missing optional files
keep their installer payload. Unrelated application files are never imported.
Deleted config files are reflected in the snapshot. Backups, Python caches,
logs, and the compiled audio helper are excluded. Project configurations, utilities, assets, tools, tests, documentation,
workflows, package manifests, README, and installer changes are included. Files
outside these explicit project paths are left uncommitted. The button waits for settings autosave and displays progress
and Git errors.

Setup records the checkout in `$XDG_STATE_HOME/hyprshell/repository` (default
`~/.local/state/hyprshell/repository`); older installations fall back to
`~/repos/hyprshell`. Re-running setup restores synced settings with the configs.
Resolve existing staged changes or an ongoing merge/rebase first. Pushes never
force or automatically merge remote changes. A failed push keeps the local
commit for retry after resolving authentication or remote divergence.

## Shared bar pills

Select a module and open **Shared pill**. Enter a group name to create a pill,
then select that name on any other modules to join it. Choose **Own pill** or
clear the name to remove a module. All built-in modules can share a pill;
there is no smaller membership limit. Modules remain individually clickable,
and their menus follow their positions. Hidden modules do not occupy space.

Members are kept together in their existing order. Joining a pill adopts its
alignment; changing a member's alignment moves the whole pill. Dragging a
member to another alignment removes it from its old pill. Dragging within the
same alignment retains membership. Use Earlier/Later or the preview to reorder.
**Bar & layout → Inside shared pills** sets the base gap between members;
individual before/after adjustments still apply. The regular gap separates
pills and standalone items.

The first visible member supplies the shared pill's background colors, opacity,
and radius. Individual backgrounds are suppressed while grouped, preserving
each module's stored appearance for removal. Named pills display a shared
background even when the global background switch is off. Group names
(`items[].pillGroup`, up to 40 characters) and internal spacing
(`bar.groupSpacing`, 0–30 px) use the normal validated autosave. Existing saved
settings default to separate pills.

Per-module **Padding inside pill** adjusts the left and right space inside
its click area. Increase the first member's left padding or the last member's
right padding to inset content from a shared pill's edges. Unlike gap adjustments,
this space is covered by the shared background. `paddingLeft` and `paddingRight`
are signed adjustments (−200–200 px) to original padding; final padding stops at
zero. Reset restores the original padding. Media keeps space for its spectrum.

Every Settings slider includes **−** and **+** buttons to change its displayed
value by one step (usually 1 px or one percentage point). Buttons stop at the
slider limits, follow disabled controls, and use the normal autosave path.
For inherited values, the first click adjusts the suggested value; reset
restores inheritance.

## Keybindings

Open **Keybindings** in Settings to browse a searchable shortcut list. Select an
action or click **+ New** to open the compact editor. Use **Record shortcut**
(or **Record again**) and press the desired combination; release all keys to
confirm. Escape cancels recording without changing the draft. Recording enables
Quickshell's Wayland `ShortcutInhibitor` on the Settings window and releases it
when recording ends, loses focus, or the page closes. If inhibition is unavailable,
recording reports that instead of pretending to capture compositor shortcuts.
**Enter manually** remains available for mouse buttons and unusual key names.

Action and command fields stay out of the recording focus path. Key combinations
appear as keycap badges; conflicts are shown inline before saving. Incomplete or
unchanged drafts cannot be saved. Save closes the editor with a brief confirmation;
Cancel discards the editor draft. Refresh and selecting another row wait until
an edited draft is saved or cancelled.

To add command shortcuts or edit the keys and labels of active desktop shortcuts,
select an action in the searchable list,
choose **Keep existing action** to preserve its Lua callback and flags, or
choose **Run a command instead**. **Save shortcut** validates and applies the
change immediately. Duplicate combinations are rejected. **Restore original**
removes a saved override; **Remove shortcut** removes a newly added command.
This page uses an explicit save so incomplete commands never become active.

The Super+K QML overlay reads active Hyprland bindings on opening and refreshes
every 1.5 seconds while open, preserving the current search. Its action labels
come from the binding description. It remains a centered layer-shell overlay
with keyboard focus, Escape dismissal, and dismissal on pointer movement outside.

Preferences live in `hyprshell/keybindings.json`; the backend generates
`hyprshell/keybindings.lua`. The bundled `hypr/keybindings.lua` captures original
binding actions while loading the main Lua config, then applies overrides at
the end. Original Lua callbacks (such as the minimize stack) and bind flags are
preserved when remapped. Base configuration files are not rewritten by edits.
The editor lists ordinary bindings in the default submap; custom submap and
extra-modifier bindings remain configured in Lua.

The Python backend locks writes, checks for concurrent edits, backs up replaced
files, verifies the Lua configuration, reloads Hyprland, checks configuration
errors, and rolls back files if validation or reload fails. Commands are passed
as quoted Lua strings to `hl.dsp.exec_cmd` and run only on a shortcut press.
Hyprland's [binding API](https://wiki.hypr.land/configuring/core/binds/) supplies
the bind, unbind, and description behavior. GitHub sync captures the saved JSON
and regenerates its Lua payload; setup restores both along with the Lua hook.

## Topbar visibility

**Bar & layout → Topbar visibility → Show topbar** hides or shows the bar on
all monitors. `bar.visible` defaults to true for existing settings. Hiding
unmaps the panel and releases its reserved space so tiled windows can expand;
showing it restores the usual bar height and margins. Popdowns close when the
bar is hidden. Desktop services, Super+K, and the application launcher shortcut
remain available. Open **Hyprshell Settings** from the application launcher to
show the bar again. The choice uses the normal validated autosave path.

## Popdown glass

**Bar & layout → Popdown glass → Popdown translucency** controls the background
of all inheriting popdowns and Super+K. The default is 6% translucency (94%
opacity), keeping text and controls fully visible. Each module has its own
**Popdown glass** slider; reset follows the general setting. These controls are
separate from bar item and pill opacity. `bar.popdownTranslucency` accepts 0–1;
`items[].popdownTranslucency` accepts 0–1 or −1 for inheritance.

Popdowns and Super+K share a dark, wallpaper-tinted gradient and reflective rim.
They sample the wallpaper region behind the card and update when it changes.
Compositor layer blur supplies the frosted background.

### Bar and popdown shortcuts

Alt+T toggles saved topbar visibility. Alt+C opens the calendar, Alt+S opens
Settings, Alt+N notifications, Alt+A audio, Alt+W Wi-Fi, Alt+V Bluetooth,
Alt+B battery, and Alt+P power options. Either Alt key works for these shortcuts. Menu shortcuts toggle their card
on the focused monitor and close menus on other monitors. Escape or an outside
click closes them. When the bar is hidden, cards appear detached at the top
center; showing the bar restores their item anchors and connectors.

The shortcuts call `hyprshell-shortcut`, installed with the other launch helpers.
Topbar toggles use the existing settings writer when Settings is loaded;
otherwise `backend.py --toggle-bar` updates only visibility under the settings
lock, preserving concurrent changes and all other preferences.

With the power menu open, press L to lock, X to shut down, R to reboot, S to
sleep, or O to log out. Alt+P opens the menu first; Alt may remain held while
pressing the action key or be released. The menu consumes these action keys
only while it is open, and ignores auto-repeat. These sequences are listed in
Super+K and beside the corresponding power buttons. Escape cancels the menu.

## Displays

Open **Displays** in Settings. Each active monitor shows its advertised resolutions
and refresh rates, scale, rotation (including flipped orientations), and position.
**Recommended (automatic)** selects the preferred mode. Resolution choices come
from the monitor’s advertised modes; a panel advertising only 1920×1080 has
that resolution plus Recommended. Scale uses the preset dropdown: Automatic, 75%, 100%, 125%, 150%, 175%,
200%, 250%, 300%, and 400%. **Arrange automatically**
lets Hyprland position that output. For multiple screens, choose another output and
use **Left / Right / Above / Below**; the placement accounts for scale and rotation
and fixes both positions. Logical X/Y fields allow precise adjustment.

Click **Apply changes…**, inspect the screen, then click **Keep changes** within
15 seconds. **Revert**, timeout, leaving the page, stdin closure, or termination
of the preview helper restores the previous layout. The helper owns the countdown,
so UI event-loop stalls do not extend it. A hard kill of the helper or compositor
failure cannot guarantee rollback; saved preferences remain unchanged until kept.
An unavailable session socket is reported as an error rather than an empty screen list.

Confirmed preferences live in `hyprshell/displays.json`; the backend generates
`hyprshell/displays.lua`, loaded at the end of the main Lua config. Preview changes
use `hyprctl eval` and never write tentative preferences. Confirmed saves are atomic
per file, backed up under `hyprshell/backups/displays-*`, and restored on a write
failure. A nonblocking transaction lock prevents simultaneous previews; stale
preferences and hotplug require refreshing. Disconnected outputs retain saved
preferences. Outputs without a saved rule retain the base automatic fallback;
connector names identify screens, so review preferences when replacing hardware.

Setup restores both files when present. GitHub sync snapshots confirmed JSON and
regenerates its Lua payload. No additional packages or permanent service are needed.
The initial page manages active screens; disabling outputs, mirroring, HDR, ICC
profiles, and VRR remain in the base configuration. Rollback reloads that base
configuration before restoring the prior live geometry.

Display fields follow the official [Hyprland monitor API](https://wiki.hypr.land/configuring/core/monitors/).
Regression tests cover preview/confirm/revert, hotplug, stale writers, rejected modes,
file-write rollback, sync, and real Quickshell controls with a simulated backend.
Physical modes and authentication-free desktop IPC require an accessible live session.

## Application theme

Open **Application theme** and toggle **Dark theme**; off selects Light. The
change saves immediately, independently of topbar preferences. The backend sets
`org.gnome.desktop.interface` color-scheme and GTK theme (Adwaita/Adwaita-dark),
and merges theme keys into GTK 3/4 `settings.ini` while keeping unrelated keys.
The [libadwaita appearance API](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/1.8/property.StyleManager.color-scheme.html)
defines how apps follow the system preference. Applications can override it.

New Qt apps launched through UWSM use the installed `gtk3` platform theme plugin.
The helper updates the user manager environment and a managed block in
`uwsm/env-hyprland`. Existing apps may need reopening. If user-manager access
fails, Qt integration takes effect on next login. Hyprshell's explicit topbar
colors are not edited by this setting. Apps with custom styles or their own
appearance choice may require selecting Follow system.

Confirmed preferences are saved in `hyprshell/theme.json`, captured by GitHub
sync, restored by setup, and reapplied at Hyprland session startup. Without a
saved preference, startup leaves application appearance alone. Writes are locked,
checked for stale preferences, backed up, and rolled back together with the
GSettings keys after failure. Reapplying an already matching theme creates no
new backup. Credentials and unrelated GTK preferences are not imported into Git.

The installer explicitly includes GTK 3, GLib's GSettings tools, and GNOME desktop
schemas. Tests isolate desktop preferences and files and exercise the native toggle,
failed saves, rollback, sync, and preservation of topbar settings.

## Application launching and theme propagation

The launcher opens desktop entry IDs using `uwsm app -t service`. UWSM processes
Terminal, field codes and working directory metadata, and systemd starts the
application with the current user-manager environment. This carries the selected
Qt platform theme into new launcher apps even when Quickshell started before the
application-theme toggle was changed. Existing application processes may need
closing fully before relaunching (including background instances).

`xdg-terminals.list` selects `kitty.desktop` and excludes Kitty's URL launcher;
setup restores this managed file, and GitHub sync captures user edits to it.
The [Quickshell DesktopEntry API](https://quickshell.org/docs/v0.2.0/types/Quickshell/DesktopEntry/)
exposes terminal metadata, which the original direct launch path did not handle.

GParted's installed wrapper uses `xhost` to grant root temporary XWayland access
and revokes access when it exits. Hyprshell now includes `xorg-xhost` in its
package list; existing installations missing it must install that package before
using GParted. See [GParted's Wayland startup workaround](https://gparted.org/news.php?item=214).
No persistent display permission change or passwordless policy is configured.
Application-owned themes, terminal color schemes and elevated applications may
use separate preferences from the desktop color-scheme setting.

## Legacy GTK application exceptions

GParted and About Xfce have managed desktop entries that call
`hyprshell-themed-app`. The helper reads the saved application theme each time;
About Xfce receives a scoped `GTK_THEME=Adwaita:dark` or `Adwaita` override.
This uses GTK's documented [theme variant override](https://docs.gtk.org/gtk3/running.html)
only for these apps; it is not exported to every app or the topbar.

GParted authenticates normally through pkexec, then launches its upstream wrapper
with fixed theme and XWayland environment values. The authentication prompt may
identify `/usr/bin/env`, which passes those values to `/usr/bin/gparted`. Root's
HOME is retained. Only root is temporarily granted display access; the helper
revokes a grant it made when the command exits or authentication is cancelled.
Pre-existing access is preserved. Upstream singleton checks and automount
inhibition still run. No root configuration or authorization policy is edited.

Setup installs the helper and the two app entries, and GitHub sync captures them
as managed files. Entries use TryExec so absent applications are not advertised.
If no application theme has been saved, the helper uses the ordinary upstream
launch command. Close and reopen these apps from the launcher after a theme
change. The ordinary `/usr/bin/gparted` command uses its normal root preferences.

## Mouse, touchpad and keyboard

Open **Mouse & keyboard** for pointer sensitivity, separate mouse/touchpad
natural scrolling, tap-to-click, disabling the touchpad while typing, keyboard
layouts and switching, and key repeat rate/delay. Controls share the normal
validated autosave transaction, backups, conflict checks, and reload rollback.
Opening the page leaves existing configuration unchanged. **Use config** or
↺ removes only that explicit override. Slider positions are suggested values,
not readings from connected devices; per-device configuration can take priority.

Common layout presets have descriptive names. Custom input accepts one to four
comma-separated installed XKB layout codes (for example `us,gb`). Configured
variants remain inherited; variants and other advanced keyboard options can be
edited in `hyprshell/hyprland/input.lua`. Switching choices are Alt+Shift,
Super+Space, and Caps Lock. Choosing one replaces `kb_options`, including any
existing Compose/remapping options; Use config restores the original options.
The typing field is temporary and never saved.

Settings saves layout strings as quoted Lua data. The installer validates saved
preferences and regenerates `hyprshell/overrides.lua` before restoring them, so
GUI input and appearance preferences survive setup on another machine. GitHub
sync already captures the saved settings JSON. No device identifiers are saved.
The installed Hyprland Lua parser accepts `input.touchpad.tap_to_click`; native
config validation covers that spelling and every new input option.

Validation covers invalid/injected values, fractional sensitivity, settings
round trips, override removal, real Hyprland parsing, native UI interactions,
and fresh-install restoration. Physical devices still require checking in an
accessible desktop session: adjust/reset pointer speed and scroll direction,
toggle tapping, switch between two layouts, test held-key repeat, and check
restart persistence.

## Power and battery

Open **Power & battery** for the battery summary, live laptop brightness,
inactivity timers, session lid behavior, and supported power profiles. The
brightness slider changes hardware immediately and does not save a startup
brightness preference. It discovers a backlight on the current machine rather
than saving a device identifier. External monitors without a backlight interface
need their own controls. Hardware/service errors appear alongside the relevant
control; Refresh checks again without changing preferences.

Power preferences use the existing validated autosave, backups, and concurrent
edit protection. All timers default to disabled, and lid/profile defaults leave
system behavior in control. Timer values are 0–240 whole minutes; enabled timers
must increase in order: dim, screen off, then suspend. Dimmed brightness is
1–100%, defaulting to 20%. Dimming never increases an already darker screen.
Separate AC/battery policies are not implemented in this first version.

`LockingController.qml` owns one shared Hypridle supervisor for locking and
power timers. Power timers can work with locking disabled; enabling them does
not turn locking on. Existing locking preferences remain separate. Hypridle
uses its normal inhibitor handling. Generated screen-off/wake commands use
Hyprland's Lua DPMS dispatcher. The supervisor stops its Hypridle child and
restores managed screen state on settings changes or normal shell shutdown.

`settings/power.py` keeps a private, locked brightness snapshot under
`$XDG_STATE_HOME/hyprshell`. Activity restores the previous raw brightness only
if the backlight still matches the dimmed value. Manual slider adjustments clear
the snapshot, and brightness-key changes are preserved when their value differs
from the dimmed value. Returning activity wakes managed screen-off state.
PowerController also attempts recovery of stale managed state when the shell
starts. These temporary records are not part of GitHub sync.

**Use system behavior** leaves laptop lid handling to logind. **Suspend when
closed** and **Keep running when closed** use a session `handle-lid-switch`
inhibitor and read available kernel ACPI lid sensors once per second. The
inhibitor is acquired before the watcher starts and is released when it exits;
no administrator configuration is rewritten. Unsupported sensors or denied
inhibitor access are reported as runtime errors and leave system handling in
control. Custom behavior applies even with external displays attached. A shell
starting with its lid already closed does not trigger an immediate suspend;
suspend occurs on the next open-to-closed transition. Closing Settings leaves
session controls running. Custom lid behavior ends with Hyprshell.

Power profiles come from `powerprofilesctl`/`power-profiles-daemon`. The dropdown
contains only advertised profiles, and saves a preference applied when the shell
starts or the saved choice changes. Unsupported saved preferences on another
machine report an error; choose another supported profile or **Use system
setting**. That choice leaves the currently active profile in place. Profile
application errors do not undo the saved preference, and the page distinguishes
the preference from the active service profile. External profile changes are
left alone until the preference changes or Hyprshell restarts.

The core installer now includes Hypridle and power-profiles-daemon; Hypridle
moves out of the optional app list. Saved power preferences already travel in
the settings JSON through setup and GitHub sync. `check_runtime.py` checks the
new command dependencies. No timers, custom lid behavior, profile preference,
or existing locking preference are enabled by this upgrade.

Automated checks cover validation and timer ordering, backwards compatibility,
brightness restoration and manual adjustments, Lua DPMS commands, profile and
lid failures, actual supervisor termination, native Hypridle configuration
parsing without a compositor, native UI/controller interactions, and setup/sync.
Physical brightness, display wake, suspend/resume, inhibitors, and lid behavior
must still be checked from an accessible desktop session. The implementation
uses the documented [Hypridle listener/sleep hooks](https://wiki.hypr.land/Hypr-Ecosystem/hypridle/)
and [systemd lid-switch inhibition](https://www.freedesktop.org/software/systemd/man/latest/systemd-inhibit.html).
