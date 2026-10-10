.pragma library

// Shared, opaque surfaces keep Settings readable independently of the wallpaper.
var background = "#202020";
var sidebar = "#282828";
var surface = "#303030";
var field = "#252525";
var button = "#414141";
var hover = "#494949";
var pressed = "#545454";
var border = "#484848";
var controlBorder = "#858585";
var separator = "#383838";
var text = "#f5f5f5";
var muted = "#b8b8b8";
var disabled = "#858585";
var accent = "#2874cc";
var accentHover = "#2c76ca";
var accentPressed = "#2462ad";
var accentText = "#8ec1ff";
var selection = "#33455b";
var onAccent = "#ffffff";
var success = "#8fd4a0";
var warning = "#f1ce88";
var danger = "#ff9ca5";
var bodySize = 14;
var captionSize = 12;
var sectionSize = 15;
var titleSize = 26;
var radius = 12;
var controlRadius = 8;
var controlHeight = 38;

function duration(item, milliseconds) {
    // Pages inherit the user's existing desktop animation preference.
    for (var parent = item; parent; parent = parent.parent) {
        if (parent.settingsMotionEnabled !== undefined)
            return parent.settingsMotionEnabled ? milliseconds : 0;
    }
    return milliseconds;
}
