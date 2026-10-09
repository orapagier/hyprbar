.pragma library
function appKey(notification) { return notification.desktopEntry || notification.appName || "Unknown application"; }
function delivery(settings, key, critical) {
    settings = settings || {};
    let mode = (settings.apps || {})[key];
    return {inbox: mode !== "off", popup: mode !== "off" && mode !== "inbox" && !!settings.popups && (!settings.doNotDisturb || (critical && settings.criticalBypass !== false))};
}
