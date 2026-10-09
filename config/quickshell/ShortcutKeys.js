.pragma library

function modifiers(mask) {
    let result = [];
    for (let entry of [[Qt.MetaModifier, "SUPER"], [Qt.ControlModifier, "CTRL"], [Qt.AltModifier, "ALT"], [Qt.ShiftModifier, "SHIFT"]])
        if (mask & entry[0]) result.push(entry[1]);
    return result;
}
function modifierFlag(key) {
    if (key === Qt.Key_Meta || key === Qt.Key_Super_L || key === Qt.Key_Super_R) return Qt.MetaModifier;
    if (key === Qt.Key_Control) return Qt.ControlModifier;
    if (key === Qt.Key_Alt) return Qt.AltModifier;
    if (key === Qt.Key_Shift) return Qt.ShiftModifier;
    return 0;
}
function keyName(key, scanCode, mask) {
    if (mask & Qt.KeypadModifier) {
        if (key >= Qt.Key_0 && key <= Qt.Key_9) return "KP_" + String.fromCharCode(key);
        let keypad = {};
        for (let entry of [[Qt.Key_Plus, "KP_Add"], [Qt.Key_Minus, "KP_Subtract"], [Qt.Key_Asterisk, "KP_Multiply"], [Qt.Key_Slash, "KP_Divide"], [Qt.Key_Period, "KP_Decimal"], [Qt.Key_Enter, "KP_Enter"], [Qt.Key_Left, "KP_Left"], [Qt.Key_Right, "KP_Right"], [Qt.Key_Up, "KP_Up"], [Qt.Key_Down, "KP_Down"], [Qt.Key_Home, "KP_Home"], [Qt.Key_End, "KP_End"], [Qt.Key_PageUp, "KP_Prior"], [Qt.Key_PageDown, "KP_Next"], [Qt.Key_Insert, "KP_Insert"], [Qt.Key_Delete, "KP_Delete"]]) keypad[entry[0]] = entry[1];
        if (keypad[key]) return keypad[key];
    }
    if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key);
    if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key);
    if (key >= Qt.Key_F1 && key <= Qt.Key_F35) return "F" + (key - Qt.Key_F1 + 1);
    let names = {};
    for (let entry of [
        [Qt.Key_Escape, "Escape"], [Qt.Key_Tab, "Tab"], [Qt.Key_Backtab, "Tab"],
        [Qt.Key_Backspace, "BackSpace"], [Qt.Key_Return, "Return"], [Qt.Key_Enter, "KP_Enter"],
        [Qt.Key_Insert, "Insert"], [Qt.Key_Delete, "Delete"], [Qt.Key_Space, "space"],
        [Qt.Key_Home, "Home"], [Qt.Key_End, "End"], [Qt.Key_PageUp, "Prior"], [Qt.Key_PageDown, "Next"],
        [Qt.Key_Left, "Left"], [Qt.Key_Right, "Right"], [Qt.Key_Up, "Up"], [Qt.Key_Down, "Down"],
        [Qt.Key_Print, "Print"], [Qt.Key_Pause, "Pause"], [Qt.Key_Menu, "Menu"],
        [Qt.Key_CapsLock, "Caps_Lock"], [Qt.Key_NumLock, "Num_Lock"], [Qt.Key_ScrollLock, "Scroll_Lock"],
        [Qt.Key_VolumeUp, "XF86AudioRaiseVolume"], [Qt.Key_VolumeDown, "XF86AudioLowerVolume"],
        [Qt.Key_VolumeMute, "XF86AudioMute"], [Qt.Key_MicMute, "XF86AudioMicMute"],
        [Qt.Key_MediaPlay, "XF86AudioPlay"], [Qt.Key_MediaPause, "XF86AudioPause"],
        [Qt.Key_MediaTogglePlayPause, "XF86AudioPlay"], [Qt.Key_MediaNext, "XF86AudioNext"],
        [Qt.Key_MediaPrevious, "XF86AudioPrev"], [Qt.Key_MediaStop, "XF86AudioStop"],
        [Qt.Key_MonBrightnessUp, "XF86MonBrightnessUp"], [Qt.Key_MonBrightnessDown, "XF86MonBrightnessDown"]
    ]) names[entry[0]] = entry[1];
    if (names[key]) return names[key];
    // Native XKB keycodes keep punctuation/layout-specific keys exact, including Shift.
    if (scanCode > 0) return "code:" + scanCode;
    return "";
}
function combination(key, mask, scanCode) {
    let name = keyName(key, scanCode, mask);
    return name ? modifiers(mask).concat([name]).join(" + ") : "";
}
function display(key) {
    return ({SUPER:"Super", CTRL:"Ctrl", ALT:"Alt", SHIFT:"Shift", Return:"Enter", KP_Enter:"Enter ↵", BackSpace:"Backspace", Prior:"Page Up", Next:"Page Down", space:"Space", Left:"←", Right:"→", Up:"↑", Down:"↓", "mouse:272":"Left mouse", "mouse:273":"Right mouse"})[key] || (key.startsWith("code:") ? "Key " + key.slice(5) : key);
}
