function love.errorhandler(message, depth)
    local error_message = tostring(message)
    local traceback = "Error in " .. error_message

    if debug and debug.traceback then
        traceback = debug.traceback(traceback, 2)
    end

    traceback = string.gsub(traceback, "\t", "    ")
    traceback = string.gsub(traceback, "\27%[[%d;]*m", "")

    if io and io.stderr then
        local stderr = io.stderr

        if stderr.setvbuf then
            stderr:setvbuf("no")
        end

        stderr:write(traceback, "\n")
        stderr:flush()
    end

    local love_api = love
    local log_path

    if type(rt) == "table" and type(rt.Log) == "table" and rt.Log.get_active_path then
        log_path = rt.Log:get_active_path()
    end

    if type(log_path) ~= "string" or log_path == "" then
        log_path = nil
    end

    local mouse_api = love_api and love_api.mouse

    if mouse_api then
        if mouse_api.setVisible then
            mouse_api.setVisible(true)
        end

        if mouse_api.setGrabbed then
            mouse_api.setGrabbed(false)
        end

        if mouse_api.setRelativeMode then
            mouse_api.setRelativeMode(false)
        end

        if mouse_api.isCursorSupported and mouse_api.isCursorSupported() and mouse_api.setCursor then
            mouse_api.setCursor()
        end
    end

    local joystick_api = love_api and love_api.joystick

    if joystick_api and joystick_api.getJoysticks then
        local joysticks = joystick_api.getJoysticks()

        if type(joysticks) == "table" then
            for _, joystick in pairs(joysticks) do
                if joystick and joystick.setVibration then
                    joystick:setVibration(0, 0)
                end
            end
        end
    end

    local graphics = love_api and love_api.graphics
    local pixel_scale_value = tonumber(pixel_scale) or 1

    if pixel_scale_value <= 0 then
        pixel_scale_value = 1
    end

    local font_size = math.max(1, math.floor(15 * pixel_scale_value))
    local font

    if graphics and graphics.newFont then
        font = graphics.newFont(font_size)
    end

    if font == nil and graphics and graphics.getFont then
        font = graphics.getFont()
    end

    if font ~= nil and graphics and graphics.setFont then
        graphics.setFont(font)
    end

    local footer

    if type(rt) == "table"
        and type(rt.Translation) == "table"
        and type(rt.Translation.error_handler) == "table"
    then
        footer = rt.Translation.error_handler.footer
    end

    if type(footer) ~= "string" then
        footer = "Press ESC to quit. Press ENTER to open the current log file."
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

    local layout_width
    local traceback_wrapped = traceback
    local traceback_height = 0
    local footer_wrapped = footer
    local footer_height = 0

    local function wrap(text, width)
        width = math.max(1, tonumber(width) or 1)

        local lines

        if font then
            local _, wrapped_lines = font:getWrap(text, width)

            if type(wrapped_lines) == "table" then
                lines = wrapped_lines
            end
        end

        if type(lines) ~= "table" or #lines == 0 then
            lines = { text }
        end

        local wrapped = table.concat(lines, "\n")
        local line_height = font_size

        if font then
            local font_height = tonumber(font:getHeight())
            local font_line_height = tonumber(font:getLineHeight())
            line_height = (font_height or font_size) * (font_line_height or 1)
        end

        line_height = math.max(1, line_height)

        return wrapped, math.max(1, #lines) * line_height
    end

    local function open_log()
        if log_path == nil then
            return
        end

        local system_api = love_api and love_api.system

        if system_api and system_api.openURL then
            system_api.openURL("file://" .. log_path)
        end
    end

    local event_api = love_api and love_api.event

    if not event_api or not event_api.poll then
        return function()
            return 1
        end
    end

    local timer_api = love_api and love_api.timer

    return function()
        if love_api ~= nil and love_api.graphics ~= nil then
            love.graphics.setShader(nil)
            love.graphics.setCanvas(nil)
        end

        while true do
            if event_api.pump then
                event_api.pump()
            end

            local iterator, state, control = event_api.poll()

            if type(iterator) ~= "function" then
                return 1
            end

            for event, a, b, c, d, e, f in iterator, state, control do
                if event == "quit" then
                    if love_api.quit then
                        love_api.quit()
                    end

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
                        local height = graphics and graphics.getHeight and graphics.getHeight() or 600
                        scroll_y = scroll_y - height / 2
                    elseif a == "pagedown" then
                        local height = graphics and graphics.getHeight and graphics.getHeight() or 600
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

            local window_width = tonumber(graphics and graphics.getWidth and graphics.getWidth()) or 800
            local window_height = tonumber(graphics and graphics.getHeight and graphics.getHeight()) or 600

            window_width = math.max(1, window_width)
            window_height = math.max(1, window_height)

            local width = math.max(1, window_width - 2 * h_margin - 10)

            if width ~= layout_width then
                layout_width = width
                traceback_wrapped, traceback_height = wrap(traceback, width)
                footer_wrapped, footer_height = wrap(footer, width)
            end

            local footer_y = v_margin + traceback_height + v_margin
            local total_height = footer_y + footer_height + v_margin
            local max_scroll = math.max(0, total_height - window_height)

            if type(scroll_y) ~= "number" or scroll_y ~= scroll_y then
                scroll_y = 0
            elseif scroll_y == math.huge then
                scroll_y = max_scroll
            elseif scroll_y == -math.huge then
                scroll_y = 0
            else
                scroll_y = math.max(0, math.min(scroll_y, max_scroll))
            end

            if graphics and graphics.isActive and graphics.isActive() then
                graphics.origin()
                graphics.clear(0.87450980392157, 0, 0.34901960784314, 1)
                graphics.translate(0, -scroll_y)
                graphics.setColor(1, 1, 1, 1)

                graphics.printf(traceback_wrapped, h_margin, v_margin, layout_width)
                graphics.printf(footer_wrapped, h_margin, footer_y, layout_width)
                graphics.origin()

                if max_scroll > 0 then
                    local scroll_bar_w = math.min(10 * pixel_scale_value, window_width)
                    local scroll_bar_x = math.max(0, window_width - scroll_bar_w)
                    local corner_radius = scroll_bar_w / 2
                    local view_ratio = math.min(1, window_height / math.max(1, total_height))
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

                    graphics.setLineWidth(2)
                    graphics.setColor(
                        scroll_bar_divider_r,
                        scroll_bar_divider_g,
                        scroll_bar_divider_b,
                        scroll_bar_divider_a
                    )
                    graphics.line(scroll_bar_x, 0, scroll_bar_x, window_height)

                    graphics.setColor(
                        scroll_bar_background_r,
                        scroll_bar_background_g,
                        scroll_bar_background_b,
                        scroll_bar_background_a
                    )
                    graphics.rectangle("fill", scroll_bar_x, 0, scroll_bar_w, window_height)

                    graphics.setColor(
                        scroll_bar_foreground_r,
                        scroll_bar_foreground_g,
                        scroll_bar_foreground_b,
                        scroll_bar_foreground_a
                    )
                    graphics.rectangle(
                        "fill",
                        scroll_bar_x,
                        cursor_y,
                        scroll_bar_w,
                        cursor_h,
                        corner_radius,
                        corner_radius
                    )
                end

                graphics.present()
            end

            if timer_api and timer_api.sleep then
                timer_api.sleep(1 / 1000)
            end
        end
    end
end
