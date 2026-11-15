local try_call = function(x, name, ...)
    if not type(x) == "table" then return end
    local success, out = pcall(x[name], x, ...)
    if success then return out else return nil end
end

function love.errorhandler(message, depth)
    local traceback = debug.traceback("Error in " .. message)
    local raw_traceback = traceback
    traceback = string.gsub(traceback, "\n[^\n]+$", "")

    -- flush traceback to console
    io.stdout:setvbuf("no")
    local stream = io.stderr
    stream:setvbuf("no")
    stream:write(traceback .. "\n")
    stream:flush()

    -- strip controls characters in preparation for logging
    local uft8_success, utf8 = pcall(require, "utf8")
    if uft8_success and utf8 ~= nil then
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

    -- reset love state

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
                joystick:setVibration(0)
            end
        end
    end

    local log_path = nil

    if rt ~= nil then
        if rt.InputManager ~= nil then try_call(rt.InputManager, "reset") end
        if rt.MusicManager ~= nil then try_call(rt.MusicManager, "reset") end
        if rt.SoundManager ~= nil then
            try_call(rt.SoundManager, "reset")
            try_call(rt.SoundManager, "flush")
        end
        if rt.ThreadManager ~= nil then try_call(rt.ThreadManager, "request_shutdown") end

        if rt.Log ~= nil then
            log_path = try_call(rt.Log, "get_active_path")

            -- serialize entire gamestate
            local to_dump
            if table.serialize ~= nil then
                to_dump = table.serialize({
                    InputManager = rt.InputManager,
                    MusicManager = rt.MusicManager,
                    SoundManager = rt.SoundManager,
                    ThreadManager = rt.ThreadManager,
                    Log = rt.Log,
                    SceneManager = rt.SceneManager
                })
            end

            if DEBUG and to_dump then
                if love.filesystem ~= nil then
                    pcall(love.filesystem.append, log_path, rt.Log._message_types.DUMP .. " " .. to_dump)
                    pcall(love.filesystem.append, log_path, rt.Log._message_types.FATAL .. " " .. traceback)
                end
            end

            dbg(to_dump)
        end
    end

    -- drawing

    if love.graphics == nil then return end

    local color_r, color_g, color_b, color_a = 0.87450980392157, 0, 0.34901960784314, 1

    if love.graphics ~= nil then
        love.graphics.reset()
        love.graphics.clear(color_r, color_g, color_b, color_a)
    end

    local pixel_scale = 1
    if rt ~= nil and rt.SceneManager ~= nil then
        local read = try_call(rt.SceneManager, "get_pixel_scale")
        if read ~= nil then
            pixel_scale = read
        end
    end

    local prefix_message = "An Error has occurred and the Application was unable to recover"
    local footer_message = "Press %s to exit, %s to open log file"

    if rt ~= nil and rt.Translation ~= nil then
        local success = pcall(require, "common.translation")
        if success and rt.Translation ~= nil then
            if rt.Translation.error_handler ~= nil then
                prefix_message = rt.Translation.error_handler.prefix_message or prefix_message
                footer_message = rt.Translation.error_handler.footer_message or footer_message
            end
        end
    end

    traceback = prefix_message .. "\n\n" .. traceback
    footer_message = string.format(footer_message, "ESCAPE", "ENTER")

    -- drawing

    local h_margin = 70 -- px
    local v_margin = 40
    local font = love.graphics.newFont(15 * pixel_scale)
    love.graphics.setFont(font)

    local draw_text = function(text, x, y)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(
            text,
            h_margin + x, v_margin + y,
            love.graphics.getWidth() - 2 * h_margin - 10
        )
    end

    local scroll_y = 0

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

    local scroll_speed = 40

    local wrap = function(text)
        local _, wrapped = font:getWrap(text, love.graphics.getWidth() - 2 * h_margin - 10)
        return table.concat(wrapped, "\n"), #wrapped * font:getHeight()
    end

    return function()
        love.event.pump()
        for event, a, b, c, d, e, f in love.event.poll() do
            if event == "quit" then
                if love.quit then love.quit() end
                return a or 1, b
            elseif event == "keypressed" then
                if a == "escape" then
                    return 0 -- quit
                elseif a == "return" or a == "kpenter" then
                    if love.system ~= nil and log_path ~= nil then
                        love.system.openURL( "file://" .. log_path)
                    end
                elseif a == "up" then
                    scroll_y = scroll_y - scroll_speed * pixel_scale
                elseif a == "down" then
                    scroll_y = scroll_y + scroll_speed * pixel_scale
                elseif a == "pageup" then
                    scroll_y = scroll_y - love.graphics.getHeight() / 2
                elseif a == "pagedown" then
                    scroll_y = scroll_y + love.graphics.getHeight() / 2
                end
            elseif event == "wheelmoved" then
                scroll_y = scroll_y - b * scroll_speed * pixel_scale
            elseif event == "gamepadpressed" then
                if b == "start" then
                    return 0 -- exit
                elseif b == "x" or b == "y" or b == "a" or b == "b" then
                    if love.system ~= nil and log_path ~= nil then
                        love.system.openURL("file://" .. log_path)
                    end
                end
            end
        end

        if love.graphics.isActive() then
            love.graphics.clear(color_r, color_g, color_b, color_a)

            local window_height = love.graphics.getHeight()
            local window_width = love.graphics.getWidth()

            local traceback_wrapped, traceback_height = wrap(traceback)

            local total_content_height = traceback_height + v_margin
            local max_scroll = math.max(0, (total_content_height + 2 * v_margin) - window_height)
            scroll_y = math.max(0, math.min(scroll_y, max_scroll))

            love.graphics.translate(0, -scroll_y)

            draw_text(traceback_wrapped, 0, -scroll_y)
            draw_text(footer_message, 0, traceback_height + v_margin)

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