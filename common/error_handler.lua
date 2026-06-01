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

    local r, g, b, a = safe_call(function()
        return rt.Palette.RED_6:unpack()
    end)

    if r == nil then
        r, g, b, a = 1, 0, 0, 1
    end

    local h_margin = 70 -- px
    local v_margin = 40

    love.graphics.clear(r, g, b, a)

    local pixel_scale = safe_call(rt.get_pixel_scale) or 1

    local prefix_message = "An Error has occurred and the Application was unable to recover."
    local wrote_stack_dump_message = "Wrote stack dump to"
    local unable_to_write_stack_dump_message = "(unable to write stack dump)"
    local open_log_or_exit_message = "Press ENTER to open log file, ESCAPE to exit."
    local exit_message = "Press ESCAPE to exit"

    safe_call(function()
        require "common.translation"
        local translation = rt.Translation.error_handler
        prefix_message = translation.prefix_message
        wrote_stack_dump_message = translation.wrote_stack_dump_message
        unable_to_write_stack_dump_message = translation.unable_to_write_stack_dump_message
        open_log_or_exit_message = translation.open_log_or_exit_message
        exit_message = translation.exit_message
    end)

    local command_message

    traceback = prefix_message .. "\n\n" .. traceback

    -- write to log folder

    local write_message, write_path
    local write_success = false

    if not DEBUG then

        local success, error_maybe = pcall(function()
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
    local big_font = love.graphics.newFont(23 * pixel_scale)

    local wrap = function(font, text)
        local _, wrapped = font:getWrap(text, love.graphics.getWidth() - 2 * h_margin)
        return table.concat(wrapped, "\n"), #wrapped * font:getHeight()
    end

    local draw_text = function(font, text, y)
        love.graphics.setFont(font)

        local darken = 0.5
        love.graphics.setColor(darken * r, darken * g, darken * b, 1)
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
                love.graphics.getWidth() - 2 * h_margin
            )
            love.graphics.translate(-offset_x, -offset_y)
        end

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(
            text,
            h_margin, v_margin + y,
            love.graphics.getWidth() - 2 * h_margin
        )
    end

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
                end
            elseif event == "gamepadpressed" then
                if b == "start" then
                    return 0
                end
            end
        end

        -- draw
        if love.graphics.isActive() then
            love.graphics.clear(r, g, b, a)

            local traceback_wrapped, traceback_height = wrap(default_font, traceback)
            draw_text(default_font, traceback_wrapped, 0)

            local write_message_wrapped, write_height
            if write_success then
                write_message_wrapped, write_height = wrap(default_font, write_message)
            else
                write_message_wrapped, write_height = wrap(default_font, unable_to_write_stack_dump_message)
            end

            draw_text(default_font, write_message_wrapped, 0 + traceback_height + v_margin)
            draw_text(default_font, command_message, 0 + traceback_height + v_margin + write_height + v_margin)

            love.graphics.present()
        end

        love.timer.sleep(1 / 1000)
    end
end