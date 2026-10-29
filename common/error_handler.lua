
-- invoke function if possible, cannot throw
local _safe_call = function(f, ...)
    if  type(f) ~= "function" or (f == nil and select("#", ...) == 0) then return end
    local result = { pcall(f, ...) }
    if result[1] ~= true then
        if _G.DEBUG then
            -- handle error inside error handler
            io.stdout:write("\n")
            io.stdout:write(debug.traceback("In love.errorhandler:" .. result[2]))
            io.stdout:write("\n")
            io.stdout:flush()
            os.exit(1)
        end
        return nil
    else
        table.remove(result, 1)
        return (table.unpack or unpack)(result)
    end
end

-- get member if possible, cannot throw
local _safe_get = function(object, ...)
    local out = nil
    if object == nil then
        return nil
    end

    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if key == nil or out == nil or out[key] == nil then
            return nil
        else
            out = out[key]
        end
    end

    return out
end


local _try_call = function(f, ...)
    if  type(f) ~= "function" or (f == nil and select("#", ...) == 0) then return end
    local result = { pcall(f, ...) }
    if result[1] ~= true then
        return nil
    else
        table.remove(result, 1)
        return (table.unpack or unpack)(result)
    end
end

function love.errorhandler(message, depth)
    local traceback = debug.traceback("Error in " .. message)
    local raw_traceback = traceback
    traceback = _safe_call(string.gsub, traceback, "\n[^\n]+$", "")

    local stream = io.stderr
    _safe_call(stream.setvbuf, stream, "no")
    _safe_call(stream.write, stream, traceback)
    _safe_call(stream.flush, stream)

    do
        if utf8 == nil then utf8 =_safe_call(require, "utf8") end
        if utf8 ~= nil then
            local sanitized = {}
            for char in string.gmatch(traceback, utf8.charpattern) do
                table.insert(sanitized, char)
            end
            traceback = table.concat(sanitized, "")
            traceback = string.gsub(traceback, "\t", "    ")
            traceback = string.gsub(traceback, "\027%[[%d;]*m", "") -- strip control characters
            traceback = string.gsub(traceback, "[^\n]*%[C%]:[^\n]*\n?", "") -- strip native C lines
            traceback = string.gsub(traceback, "stack traceback", "Stack Traceback")
        end
    end

    _safe_call(function()
        -- reset state
        if love.mouse ~= nil then
            love.mouse.setVisible(true)
            love.mouse.setGrabbed(false)
            love.mouse.setRelativeMode(false)
            if love.mouse.isCursorSupported() then
                love.mouse.setCursor()
            end
        end

        if love.joystick ~= nil then
            local joysticks = love.joystick.getJoysticks()
            if joysticks ~= nil and type(joysticks) == "table" then
                for _, joystick in pairs(joysticks) do
                    _safe_call(joystick.setVibration, joystick)
                end
            end
        end

        if love.audio ~= nil then
            _safe_call(love.audio.stop)
        end

        if love.graphics ~= nil then
            _safe_call(love.graphics.reset)
        end

        if rt ~= nil then
            _safe_call(_safe_get(rt.InputManager, "reset"), rt.InputManager)
            _safe_call(_safe_get(rt.MusicManager, "reset"), rt.MusicManager)
            _safe_call(_safe_get(rt.SoundManager, "reset"), rt.SoundManager)
            _safe_call(_safe_get(rt.ThreadManager, "request_shutdown"), rt.ThreadManager)
        end
    end)

    _safe_call(rt.SoundManager.flush, rt.SoundManager)

    local h_margin = 70 -- px
    local v_margin = 40

    local color_r, color_g, color_b, color_a = 223 / 255, 0, 89 / 255, 1
    _safe_call(function()
        local color = _safe_get(rt, "Palette", "RED_6")
        if color ~= nil then
            color_r, color_g, color_b, color_a = _safe_call(color.unpack, color)
        end
    end)

    love.graphics.clear(color_r, color_g, color_b, color_a)
    love.graphics.present()

    local pixel_scale = 1
    if rt ~= nil and rt.SceneManager:get_pixel_scale() ~= nil then
        pixel_scale = _safe_call(rt.SceneManager:get_pixel_scale()) or pixel_scale
    end

    local prefix_message = "An Error has occurred and the Application was unable to recover"

    _safe_call(function()
        if rt ~= nil then
            _try_call(require, "common.translation")
            local translation = _safe_get(rt, "Translation", "error_handler")
            if translation ~= nil then
                prefix_message = translation.prefix_message
            end
        end
    end)

    traceback = prefix_message .. "\n\n" .. traceback

    -- write to log folder

    if not _G.DEBUG then
        _safe_call(function()
            -- TODO
        end)
    end

    local default_font = love.graphics.newFont(15 * pixel_scale)

    local wrap = function(font, text)
        local _, wrapped = font:getWrap(text, love.graphics.getWidth() - 2 * h_margin - 10)
        return table.concat(wrapped, "\n"), #wrapped * font:getHeight()
    end

    local darken = 0.5
    local draw_text = function(font, text, y)
        love.graphics.setFont(font)

        love.graphics.setColor(
            darken * color_r,
            darken * color_g,
            darken * color_b,
            1
        )

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(
            text,
            h_margin, v_margin + y,
            love.graphics.getWidth() - 2 * h_margin - 10
        )
    end

    local scroll_y = 0
    local scroll_bar_background_r, scroll_bar_background_g, scroll_bar_background_b, scroll_bar_background_a = 0.2, 0.2, 0.2, 1
    local scroll_bar_foreground_r, scroll_bar_foreground_g, scroll_bar_foreground_b, scroll_bar_foreground_a = 0.4, 0.4, 0.4, 1
    local scroll_bar_divider_r, scroll_bar_divider_g, scroll_bar_divider_b, scroll_bar_divider_a = 0, 0, 0, 1

    _safe_call(function()
        if rt ~= nil and rt.Palette ~= nil then
            local background = _safe_get(rt.Palette, "RED_10")
            local foreground = _safe_get(rt.Palette, "RED_3")
            if background ~= nil and foreground ~= nil then
                scroll_bar_background_r, scroll_bar_background_g, scroll_bar_background_b, scroll_bar_background_a = background:unpack()
                scroll_bar_foreground_r, scroll_bar_foreground_g, scroll_bar_foreground_b, scroll_bar_foreground_a = foreground:unpack()
                scroll_bar_divider_r, scroll_bar_divider_g, scroll_bar_divider_b, scroll_bar_divider_a =
                darken * scroll_bar_background_r,
                darken * scroll_bar_background_g,
                darken * scroll_bar_background_b,
                1
            end
        end
    end)

    return function()
        -- input
        love.event.pump()
        for event, a, b, c, d, e, f in love.event.poll() do

            if event == "quit" then
                if love.quit then love.quit() end
                return a or 1, b
            elseif event == "key    pressed" then
                if b == "escape" then
                    return 0 -- quit
                elseif b == "return" and write_success then
                    _safe_call(love.system.openURL, "file://" .. write_path)
                elseif b == "up" then
                    scroll_y = scroll_y - 40 * pixel_scale
                elseif b == "down" then
                    scroll_y = scroll_y + 40 * pixel_scale
                elseif b == "pageup" then
                    scroll_y = scroll_y - love.graphics.getHeight() / 2
                elseif b == "pagedown" then
                    scroll_y = scroll_y + love.graphics.getHeight() / 2
                end
            elseif event == "wheelmoved" then
                scroll_y = scroll_y - b * 40 * pixel_scale
            elseif event == "gamepadpressed" then
                if b == "start" then
                    return 0
                end
            end
        end

        -- draw
        if love.graphics.isActive() then
            love.graphics.clear(color_r, color_g, color_b, color_a)

            local window_height = love.graphics.getHeight()
            local window_width = love.graphics.getWidth()

            local traceback_wrapped, traceback_height = wrap(default_font, traceback)

            local total_content_height = traceback_height + v_margin
            local max_scroll = math.max(0, (total_content_height + 2 * v_margin) - window_height)
            scroll_y = math.max(0, math.min(scroll_y, max_scroll))

            love.graphics.push()
            love.graphics.translate(0, -scroll_y)

            draw_text(default_font, traceback_wrapped, 0)
            draw_text(default_font, "TODO", 0 + traceback_height + v_margin)

            love.graphics.pop()

            if max_scroll > 0 then
                local scroll_bar_w = 10 * pixel_scale
                local scroll_bar_x = window_width - scroll_bar_w
                local corner_radius = scroll_bar_w / 2

                local view_ratio = window_height / (total_content_height + 2 * v_margin)

                local cursor_h = math.max(20 * pixel_scale, window_height * view_ratio)
                local cursor_y = (scroll_y / max_scroll) * (window_height - cursor_h)

                love.graphics.setLineWidth(2)
                love.graphics.setColor(scroll_bar_divider_r, scroll_bar_divider_g, scroll_bar_divider_b, scroll_bar_divider_a)
                love.graphics.line(scroll_bar_x, 0, scroll_bar_x, window_height)

                love.graphics.setColor(scroll_bar_background_r, scroll_bar_background_g, scroll_bar_background_b, scroll_bar_background_a)
                love.graphics.rectangle("fill", scroll_bar_x, 0, scroll_bar_w, window_height)

                love.graphics.setColor(scroll_bar_foreground_r, scroll_bar_foreground_g, scroll_bar_foreground_b, scroll_bar_foreground_a)
                love.graphics.rectangle("fill", scroll_bar_x, cursor_y, scroll_bar_w, cursor_h, corner_radius, corner_radius)
            end

            love.graphics.present()
        end

        love.timer.sleep(1 / 1000)
    end
end
