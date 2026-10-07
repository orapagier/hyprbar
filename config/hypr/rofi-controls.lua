-- Rofi 2.0's Wayland backend needs compositor support for outside clicks.
-- Query the live layer bounds so this also works after filtering or scaling.
local M = {}

function M.setup(launch_command)
    local function visible_rofi()
        local visible = {}
        for _, layer in ipairs(hl.get_layers({ namespace = "rofi" })) do
            if layer.mapped then
                table.insert(visible, layer)
            end
        end
        return visible
    end

    local function close_layers(layers)
        for _, layer in ipairs(layers) do
            local pid = layer.pid
            if pid and pid > 1 then
                hl.exec_cmd("kill -TERM -- " .. string.format("%d", pid))
            end
        end
    end

    hl.bind("SUPER + Super_L", function()
        local layers = visible_rofi()
        if #layers > 0 then
            close_layers(layers)
        else
            hl.exec_cmd(launch_command)
        end
    end, { release = true, description = "Toggle application launcher" })

    local function close_if_outside()
        local layers = visible_rofi()
        if #layers == 0 then return end
        local cursor = hl.get_cursor_pos()
        if not cursor then return end

        for _, layer in ipairs(layers) do
            -- Layer coordinates are local to their output; cursor is global.
            local monitor = layer.monitor
            local x = layer.x + (monitor and monitor.x or 0)
            local y = layer.y + (monitor and monitor.y or 0)
            if cursor.x >= x and cursor.x < x + layer.w
                and cursor.y >= y and cursor.y < y + layer.h then
                return
            end
        end
        close_layers(layers)
    end

    for _, button in ipairs({ 272, 273, 274 }) do
        hl.bind("mouse:" .. button, close_if_outside, {
            non_consuming = true,
            description = "Dismiss launcher when clicking outside",
        })
    end
end

return M
