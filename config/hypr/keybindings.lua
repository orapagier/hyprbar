-- Preserve original Lua actions when Settings remaps a shortcut.
local M = {}
local captured = {}
local bind = hl.bind
local modifiers = { SUPER = true, CTRL = true, ALT = true, SHIFT = true }
local function normalize(shortcut)
    local mods, key = {}, nil
    for part in shortcut:gmatch('[^+]+') do
        local token = part:match('^%s*(.-)%s*$'):upper()
        if modifiers[token] then mods[token] = true else key = token end
    end
    local parts = {}
    for _, mod in ipairs({ 'SUPER', 'CTRL', 'ALT', 'SHIFT' }) do
        if mods[mod] then table.insert(parts, mod) end
    end
    table.insert(parts, key or '')
    return table.concat(parts, ' + ')
end
function M.capture()
    captured = {}
    hl.bind = function(keys, action, options)
        table.insert(captured, { keys = keys, action = action, options = options or {} })
        return bind(keys, action, options)
    end
end
function M.apply()
    hl.bind = bind
    local config = (os.getenv('XDG_CONFIG_HOME') or os.getenv('HOME') .. '/.config')
    local path = config .. '/hyprshell/keybindings.lua'
    local file = io.open(path, 'r')
    if not file then return end
    file:close()
    local entries = dofile(path)
    local originals = {}
    -- Find all original actions before changing any bindings.
    for _, entry in ipairs(entries) do
        if entry.original ~= '' then
            local matches = {}
            for _, record in ipairs(captured) do
                if normalize(record.keys) == normalize(entry.original) then
                    table.insert(matches, record)
                end
            end
            assert(#matches > 0, 'Original keybinding no longer exists: ' .. entry.original)
            originals[entry.id] = matches
        end
    end
    for _, entry in ipairs(entries) do
        for _, record in ipairs(originals[entry.id] or {}) do hl.unbind(record.keys) end
    end
    for _, entry in ipairs(entries) do
        if entry.mode == 'command' then
            bind(entry.shortcut, hl.dsp.exec_cmd(entry.command), { description = entry.description })
        else
            for _, record in ipairs(originals[entry.id]) do
                local options = {}
                for key, value in pairs(record.options) do options[key] = value end
                options.description = entry.description
                bind(entry.shortcut, record.action, options)
            end
        end
    end
end
return M
