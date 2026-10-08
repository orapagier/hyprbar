.pragma library

function copy(value) { return JSON.parse(JSON.stringify(value)); }
function item(config, id) { return (config.items || []).find(i => i.id === id) || {}; }
function adaptive(config, id) {
    let mode = item(config, id).adaptiveColors;
    return mode === 'on' || (mode !== 'off' && (!config.bar || config.bar.adaptiveColors !== false));
}
function merge(defaults, saved) {
    if (!saved || saved.version !== 1) throw new Error('Unsupported settings version');
    let result = copy(defaults);
    result.bar = Object.assign(result.bar, saved.bar || {});
    result.hyprland = saved.hyprland || {};
    result.items = result.items.map(i => Object.assign(i, item(saved, i.id)));
    // Retire experimental motion preferences from older saved files.
    for (let section of [result.bar, ...result.items])
        for (let key of ['genieEffect', 'genieOpenDuration', 'genieCloseDuration']) delete section[key];
    return result;
}

// Resolve item appearance while preserving component defaults in inherit mode.
function appearance(config, id) {
    let result = Object.assign({}, item(config, id));
    if (!result.background || result.background === 'inherit')
        result.background = (config.bar && config.bar.background) || 'inherit';
    result.iconSize = result.iconSize || (config.bar && config.bar.iconSize) || 0;
    return result;
}

// Insert before a destination item, or append to the chosen side.
function reorder(config, id, side, beforeId) {
    let next = copy(config);
    let moving = item(next, id);
    if (!moving.id || ['left', 'center', 'right'].indexOf(side) < 0 || beforeId === id)
        return next;
    let previousSide = moving.side;
    let group = next.items.filter(i => i.id !== id && i.side === side).sort((a, b) => a.order - b.order);
    let index = group.findIndex(i => i.id === beforeId);
    group.splice(index < 0 ? group.length : index, 0, moving);
    moving.side = side;
    group.forEach((i, n) => i.order = n);
    if (previousSide !== side)
        next.items.filter(i => i.side === previousSide).sort((a, b) => a.order - b.order).forEach((i, n) => i.order = n);
    return next;
}

function restoreItem(config, saved, id) {
    let original = item(config, id), previous = item(saved, id);
    if (!original.id || !previous.id) return copy(config);
    let next = copy(config);
    next.items[next.items.findIndex(i => i.id === id)] = copy(previous);
    if (original.side === previous.side && original.order === previous.order) return next;
    // Dragging renumbers a group. Restore the saved position relative to its
    // neighbours rather than treating its old numeric order as a new rank.
    let savedGroup = saved.items.filter(i => i.side === previous.side).sort((a,b) => a.order-b.order);
    let index = savedGroup.findIndex(i => i.id === id);
    let following = savedGroup.slice(index+1).find(i => item(next,i.id).side === previous.side);
    let beforeId = following ? following.id : "";
    if (!following) {
        let preceding = savedGroup.slice(0,index).reverse().find(i => item(next,i.id).side === previous.side);
        let group = next.items.filter(i => i.id !== id && i.side === previous.side).sort((a,b) => a.order-b.order);
        let after = preceding ? group.findIndex(i => i.id === preceding.id)+1 : group.length;
        beforeId = after < group.length ? group[after].id : "";
    }
    return reorder(next, id, previous.side, beforeId);
}
