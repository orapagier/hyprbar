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

Background controls use an explicit **Show background pill** switch: switching
off removes the pill immediately in the preview and saves that choice. The
general control affects all inheriting items; each item can set its own switch
or choose **Use general setting** to follow the global choice again.

The editor keeps a draft and saves it automatically after 500 ms without an
edit. Closing the window flushes pending edits. Native window closes also reset
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

The top-level keys are `version`, `bar`, `items`, and `hyprland`. Item entries
are keyed by `id`; missing entries/properties inherit bundled defaults.
`side` accepts `left`, `center`, or `right`; `order` sorts within that side.
The three groups are positioned independently, so unusually wide custom text
or an overcrowded center group can overlap adjacent groups. Shorten overrides,
reduce font size, hide modules, or distribute items between groups in that case.

`bar.spacing` sets the general gap between visible items. Each item's
`spacingLeft` and `spacingRight` add 0–200 px of space outside its pill;
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
