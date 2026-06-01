local _debug_traceback = debug.traceback

function love.errorhandler(message, depth)
    local traceback
    traceback = string.gsub(
        _debug_traceback("Error in " .. tostring(message), 3),
        "\n[^\n]+$", ""
    )

    io.stdout:write(traceback)
    io.stdout:flush()

    do
        if utf8 == nil then utf8 = require "utf8" end
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

    local throw_inner_error = function(...)
        io.stdout:write("\n")
        io.stdout:write("In love.errorhandler: " .. table.concat({ ... }, ""))
        io.stdout:write("\n")
        io.stdout:flush()
        os.exit(1)
    end

    local safe_call = function(f, ...)
        local result = { pcall(f, ...) }
        if result[1] ~= true then
            throw_inner_error(result[2])
            return nil
        else
            table.remove(result, 1)
            return table.unpack(result)
        end
    end

    -- reset state
    love.mouse.setVisible(true)
    love.mouse.setGrabbed(false)
    love.mouse.setRelativeMode(false)
    if love.mouse.isCursorSupported() then
        love.mouse.setCursor()
    end

    for joystick in values(love.joystick.getJoysticks()) do
        joystick:setVibration(nil)
    end

    love.audio.stop()
    love.graphics.reset()
    safe_call(rt.InputManager.reset, rt.InputManager)
    safe_call(rt.MusicManager.reset, rt.MusicManager)
    safe_call(rt.SoundManager.reset, rt.SoundManager)
    safe_call(rt.ThreadManager.request_shutdown, rt.ThreadManager)

    local color_r, color_g, color_b, color_a = 1, 0, 0, 1

    safe_call(function()
        color_r, color_g, color_b, color_a = rt.Palette.RED_6:unpack()
    end)

    local h_margin = 70 -- px
    local v_margin = 40

    love.graphics.clear(color_r, color_g, color_b, color_a)
    love.graphics.present()

    local pixel_scale = safe_call(rt.get_pixel_scale) or 1

    local prefix_message = "An Error has occurred and the Application was unable to recover."
    local wrote_stack_dump_message = "Wrote stack dump to"
    local unable_to_write_stack_dump_message = "(unable to write stack dump)"
    local stack_dump_disabled_message = "(unable to write stack dump, disabled in DEBUG mode)"
    local open_log_or_exit_message = "Press ENTER to open log file, ESCAPE to exit."
    local exit_message = "Press ESCAPE to exit"

    safe_call(function()
        require "common.translation"
        local translation = rt.Translation.error_handler
        prefix_message = translation.prefix_message
        wrote_stack_dump_message = translation.wrote_stack_dump_message
        unable_to_write_stack_dump_message = translation.unable_to_write_stack_dump_message
        open_log_or_exit_message = translation.open_log_or_exit_message
        stack_dump_disabled_message = translation.stack_dump_disabled_message
        exit_message = translation.exit_message
    end)

    local command_message

    traceback = prefix_message .. "\n\n" .. traceback

    -- write to log folder

    local write_message, write_path
    local write_success = false

    if not DEBUG then
        pcall(function()
            require "common.filesystem"
            if not bd.exists("/crash_reports") then
                bd.create_directory("/crash_reports")
            end

            -- prepare for dump

            rt.GameState.scene_manager = rt.SceneManager
            rt.GameState.music_manager = rt.MusicManager
            rt.GameState.sound_manager = rt.SoundManager
            rt.GameState.thread_manager = rt.ThreadManager
            rt.GameState.input_manager = rt.InputManager

            rt.GameState.rt = rt
            rt.GameState.meta = meta
            rt.GameState.b2 = b2
            rt.GameState.mn = mn
            rt.GameState.bd = bd

            rt.GameState.system_info = {
                image_formats = love.graphics.getTextureFormats({ canvas = false }),
                canvas_formats = love.graphics.getTextureFormats({ canvas = true }),
                renderer_info = love.graphics.getRendererInfo(),
                supported = love.graphics.getSupported(),
                system_limits = love.graphics.getSystemLimits(),
                texture_types = love.graphics.getTextureTypes(),
                os = love.system.getOS(),
                power_info = love.system.getPowerInfo(),
                processor_count = love.system.getProcessorCount(),
                version = love.getVersion()
            }

            local to_write = "return [[\n" ..traceback .. "\n]],\n" .. table.serialize(rt.GameState, {
                "function",
                "cdata",
                "thread",
                "userdata"
            })

            local id = os.time() .. "__" .. os.date("%Y_%m_%d_%H_%M_%S")
            id = bd.join_path("crash_reports", id .. ".log")

            write_success = bd.write_file(id, to_write, false) -- no overwrite

            if write_success then
                write_path = bd.join_path(bd.get_save_directory(), id)
                write_message = wrote_stack_dump_message .. "\n\t" .. write_path
                command_message = open_log_or_exit_message
            end
        end)
    end

    if not write_success then
        command_message = exit_message
    end

    local default_font = love.graphics.newFont(17 * pixel_scale)

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

        local offset = 0.5
        for offsets in range(
            { -offset,  offset },
            {  offset, -offset },
            {  offset,  offset },
            { -offset, -offset }
        ) do
            local offset_x, offset_y = table.unpack(offsets)
            love.graphics.translate(offset_x, offset_y)
            love.graphics.printf(
                text,
                h_margin, v_margin + y,
                love.graphics.getWidth() - 2 * h_margin - 10
            )
            love.graphics.translate(-offset_x, -offset_y)
        end

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

    safe_call(function()
        scroll_bar_background_r, scroll_bar_background_g, scroll_bar_background_b, scroll_bar_background_a = rt.Palette.RED_10:unpack()
        scroll_bar_foreground_r, scroll_bar_foreground_g, scroll_bar_foreground_b, scroll_bar_foreground_a = rt.Palette.RED_3:unpack()
        scroll_bar_divider_r, scroll_bar_divider_g, scroll_bar_divider_b, scroll_bar_divider_a =
            darken * scroll_bar_background_r,
            darken * scroll_bar_background_g,
            darken * scroll_bar_background_b,
            1
    end)

    return function()
        -- input
        love.event.pump()
        for event, a, b, c, d, e, f in love.event.poll() do

            if event == "quit" then
                if love.quit then love.quit() end
                return a or 1, b
            elseif event == "keypressed" then
                if b == "escape" then
                    return 0 -- quit
                elseif b == "return" and write_success then
                    safe_call(love.system.openURL, "file://" .. write_path)
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

            local write_message_wrapped, write_height
            if write_success then
                write_message_wrapped, write_height = wrap(default_font, write_message)
            elseif not DEBUG then
                write_message_wrapped, write_height = wrap(default_font, stack_dump_disabled_message)
            else
                write_message_wrapped, write_height = wrap(default_font, unable_to_write_stack_dump_message)
            end

            local command_message_wrapped, command_height = wrap(default_font, command_message)

            local total_content_height = traceback_height + v_margin + write_height + v_margin + command_height
            local max_scroll = math.max(0, (total_content_height + 2 * v_margin) - window_height)
            scroll_y = math.max(0, math.min(scroll_y, max_scroll))

            love.graphics.push()
            love.graphics.translate(0, -scroll_y)

            draw_text(default_font, traceback_wrapped, 0)
            draw_text(default_font, write_message_wrapped, 0 + traceback_height + v_margin)
            draw_text(default_font, command_message_wrapped, 0 + traceback_height + v_margin + write_height + v_margin)

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