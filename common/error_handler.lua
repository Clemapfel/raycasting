local try_get = function(x, name)
    if x == nil then return nil end

    local success, value = pcall(function()
        return x[name]
    end)

    if success then return value end
end

local try_call = function(x, name, ...)
    if x == nil then return end

    local get_success, method = pcall(function()
        return x[name]
    end)

    if not get_success or type(method) ~= "function" then return end

    local success, a, b, c = pcall(method, x, ...)

    if success then return a, b, c end
end

local try_function = function(x, name, ...)
    if x == nil then return end

    local get_success, method = pcall(function()
        return x[name]
    end)

    if not get_success or type(method) ~= "function" then return end

    local success, a, b, c = pcall(method, ...)

    if success then return a, b, c end
end

local safe_tostring = function(value)
    local success, result = pcall(tostring, value)

    if success and type(result) == "string" then
        return result
    end

    return "Unknown error"
end

local write_error = function(text)
    local stderr = try_get(io, "stderr")

    try_call(stderr, "setvbuf", "no")
    try_call(stderr, "write", text, "\n")
    try_call(stderr, "flush")
end

function love.errorhandler(message, depth)
    local error_message = safe_tostring(message)
    local traceback = "Error in " .. error_message

    local generated_traceback = try_function(
        debug,
        "traceback",
        traceback,
        2
    )

    if type(generated_traceback) == "string" then
        traceback = generated_traceback
    end

    local sanitize_success, sanitized = pcall(function()
        local result = string.gsub(traceback, "\t", "    ")
        result = string.gsub(result, "\27%[[%d;]*m", "")
        return result
    end)

    if sanitize_success and type(sanitized) == "string" then
        traceback = sanitized
    end

    write_error(traceback)

    local love_api = love

    local log_path = nil

    if rt ~= nil then
        local log_manager = try_get(rt, "Log")
        log_path = try_call(log_manager, "get_active_path")
    end

    if type(log_path) ~= "string" or log_path == "" then
        log_path = nil
    end

    local mouse_api = try_get(love_api, "mouse")

    try_function(mouse_api, "setVisible", true)
    try_function(mouse_api, "setGrabbed", false)
    try_function(mouse_api, "setRelativeMode", false)

    local cursor_supported = try_function(mouse_api, "isCursorSupported")

    if cursor_supported then
        try_function(mouse_api, "setCursor")
    end

    local joystick_api = try_get(love_api, "joystick")
    local joysticks = try_function(joystick_api, "getJoysticks")

    if type(joysticks) == "table" then
        pcall(function()
            for _, joystick in pairs(joysticks) do
                try_call(joystick, "setVibration", 0, 0)
            end
        end)
    end

    local graphics = try_get(love_api, "graphics")

    local pixel_scale_value = tonumber(pixel_scale) or 1

    if pixel_scale_value <= 0 then
        pixel_scale_value = 1
    end

    local font_size = math.max(1, math.floor(15 * pixel_scale_value))

    local font = try_function(graphics, "newFont", font_size)

    if font == nil then
        font = try_function(graphics, "getFont")
    end

    if font ~= nil then
        try_function(graphics, "setFont", font)
    end

    local clear_r = tonumber(color_r) or 0
    local clear_g = tonumber(color_g) or 0
    local clear_b = tonumber(color_b) or 0
    local clear_a = tonumber(color_a) or 1

    local footer = footer_message

    if type(footer) ~= "string" then
        footer = "Press ESC to quit. Press ENTER to open the log file."
    end

    local h_margin = 70
    local v_margin = 40

    local scroll_y = 0
    local scroll_speed = 40 * pixel_scale_value

    local scroll_bar_background_r = 0.49411764705882
    local scroll_bar_background_g = 0
    local scroll_bar_background_b = 0.19607843137255
    local scroll_bar_background_a = 1

    local scroll_bar_foreground_r = 1
    local scroll_bar_foreground_g = 0.25098039215686
    local scroll_bar_foreground_b = 0.54901960784314
    local scroll_bar_foreground_a = 1

    local darken = 0.5

    local scroll_bar_divider_r = darken * scroll_bar_background_r
    local scroll_bar_divider_g = darken * scroll_bar_background_g
    local scroll_bar_divider_b = darken * scroll_bar_background_b
    local scroll_bar_divider_a = 1

    local layout_width = nil

    local traceback_wrapped = traceback
    local traceback_height = 0

    local footer_wrapped = footer
    local footer_height = 0

    local wrap = function(text, width)
        text = safe_tostring(text)
        width = math.max(1, tonumber(width) or 1)

        local lines = nil

        if font ~= nil then
            local _, wrapped_lines = try_call(font, "getWrap", text, width)

            if type(wrapped_lines) == "table" then
                lines = wrapped_lines
            end
        end

        if type(lines) ~= "table" or #lines == 0 then
            lines = { text }
        end

        local concat_success, wrapped = pcall(table.concat, lines, "\n")

        if not concat_success or type(wrapped) ~= "string" then
            wrapped = text
            lines = { text }
        end

        local line_height = font_size

        if font ~= nil then
            local font_height = tonumber(try_call(font, "getHeight"))
            local font_line_height = tonumber(try_call(font, "getLineHeight"))

            line_height = (font_height or font_size) * (font_line_height or 1)
        end

        line_height = math.max(1, line_height)

        return wrapped, math.max(1, #lines) * line_height
    end

    local update_layout = function(window_width)
        local width = math.max(1, window_width - 2 * h_margin - 10)

        if width == layout_width then return end

        layout_width = width

        traceback_wrapped, traceback_height = wrap(traceback, width)
        footer_wrapped, footer_height = wrap(footer, width)
    end

    local clamp_scroll = function(value, max_value)
        if type(value) ~= "number" or value ~= value then
            value = 0
        end

        if value == math.huge then
            return max_value
        elseif value == -math.huge then
            return 0
        end

        return math.max(0, math.min(value, max_value))
    end

    local open_log = function()
        if log_path == nil then return end

        local system_api = try_get(love_api, "system")

        try_function(system_api, "openURL", "file://" .. log_path)
    end

    local handle_event = function(event, a, b)
        if event == "quit" then
            try_function(love_api, "quit")
            return a or 1, b

        elseif event == "keypressed" then
            if a == "escape" then
                return 0

            elseif a == "return" or a == "kpenter" then
                open_log()

            elseif a == "up" then
                scroll_y = scroll_y - scroll_speed

            elseif a == "down" then
                scroll_y = scroll_y + scroll_speed

            elseif a == "pageup" then
                local height = tonumber(try_function(graphics, "getHeight")) or 600
                scroll_y = scroll_y - height / 2

            elseif a == "pagedown" then
                local height = tonumber(try_function(graphics, "getHeight")) or 600
                scroll_y = scroll_y + height / 2

            elseif a == "home" then
                scroll_y = 0

            elseif a == "end" then
                scroll_y = math.huge
            end

        elseif event == "wheelmoved" then
            scroll_y = scroll_y - (tonumber(b) or 0) * scroll_speed

        elseif event == "gamepadpressed" then
            if b == "start" then
                return 0

            elseif b == "x" or b == "y" or b == "a" or b == "b" then
                open_log()
            end
        end
    end

    local draw_screen = function(
        window_width,
        window_height,
        total_height,
        max_scroll
    )
        if not try_function(graphics, "isActive") then return end

        try_function(graphics, "origin")
        try_function(graphics, "clear", clear_r, clear_g, clear_b, clear_a)

            try_function(graphics, "translate", 0, -scroll_y)
        try_function(graphics, "setColor", 1, 1, 1, 1)

        try_function(
            graphics,
            "printf",
            traceback_wrapped,
            h_margin,
            v_margin,
            layout_width
        )

        try_function(
            graphics,
            "printf",
            footer_wrapped,
            h_margin,
            v_margin + traceback_height + v_margin,
            layout_width
        )

                    try_function(graphics, "origin")

        if max_scroll > 0 then
            local scroll_bar_w = math.min(
                10 * pixel_scale_value,
                window_width
            )

            local scroll_bar_x = math.max(0, window_width - scroll_bar_w)
            local corner_radius = scroll_bar_w / 2

            local view_ratio = math.min(
                1,
                window_height / math.max(1, total_height)
            )

            local cursor_h = math.min(
                window_height,
                math.max(
                    math.min(20 * pixel_scale_value, window_height),
                    window_height * view_ratio
                )
            )

            local cursor_travel = math.max(0, window_height - cursor_h)

            local cursor_y = 0

            if max_scroll > 0 then
                cursor_y = (scroll_y / max_scroll) * cursor_travel
            end

            cursor_y = math.max(0, math.min(cursor_y, cursor_travel))

            try_function(graphics, "setLineWidth", 2)

            try_function(
                graphics,
                "setColor",
                scroll_bar_divider_r,
                scroll_bar_divider_g,
                scroll_bar_divider_b,
                scroll_bar_divider_a
            )

            try_function(
                graphics,
                "line",
                scroll_bar_x,
                0,
                scroll_bar_x,
                window_height
            )

            try_function(
                graphics,
                "setColor",
                scroll_bar_background_r,
                scroll_bar_background_g,
                scroll_bar_background_b,
                scroll_bar_background_a
            )

            try_function(
                graphics,
                "rectangle",
                "fill",
                scroll_bar_x,
                0,
                scroll_bar_w,
                window_height
            )

            try_function(
                graphics,
                "setColor",
                scroll_bar_foreground_r,
                scroll_bar_foreground_g,
                scroll_bar_foreground_b,
                scroll_bar_foreground_a
            )

            try_function(
                graphics,
                "rectangle",
                "fill",
                scroll_bar_x,
                cursor_y,
                scroll_bar_w,
                cursor_h,
                corner_radius,
                corner_radius
            )
        end

        try_function(graphics, "present")
    end

    local event_api = try_get(love_api, "event")

    if event_api == nil then
        return function()
            return 1
        end
    end

    local timer_api = try_get(love_api, "timer")

    return function()
        while true do
            try_function(event_api, "pump")

            local iterator, state, control = try_function(event_api, "poll")

            if type(iterator) ~= "function" then
                return 1
            end

            local event_success, exit_code, exit_data = pcall(function()
                for event, a, b, c, d, e, f in iterator, state, control do
                    local handled, code, data = pcall(
                        handle_event,
                        event,
                        a,
                        b,
                        c,
                        d,
                        e,
                        f
                    )

                    if handled and code ~= nil then
                        return code, data
                    end
                end
            end)

            if not event_success then
                return 1
            end

            if exit_code ~= nil then
                return exit_code, exit_data
            end

            local window_width = tonumber(
                try_function(graphics, "getWidth")
            ) or 800

            local window_height = tonumber(
                try_function(graphics, "getHeight")
            ) or 600

            window_width = math.max(1, window_width)
            window_height = math.max(1, window_height)

            update_layout(window_width)
            local footer_y = v_margin + traceback_height + v_margin

            local total_height = footer_y + footer_height + v_margin
            local max_scroll = math.max(0, total_height - window_height)

            scroll_y = clamp_scroll(scroll_y, max_scroll)

            if font ~= nil and graphics ~= nil then
                pcall(
                    draw_screen,
                    window_width,
                    window_height,
                    total_height,
                    max_scroll
                )
            end

            try_function(timer_api, "sleep", 1 / 1000)
        end
    end
end