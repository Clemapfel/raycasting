function love.errorhandler(message)
    local traceback
    traceback = string.gsub(
        debug.traceback("Error in " .. tostring(message), 3),
        "\n[^\n]+$", ""
    )

    traceback = string.gsub(traceback, "stack traceback:", "Traceback:")

    io.stdout:write(traceback)
    io.stdout:flush()

    local sanitized = {}
    for char in string.gmatch(traceback, utf8.charpattern) do
        table.insert(sanitized, char)
    end
    traceback = table.concat(sanitized, "")

    traceback = string.gsub(traceback, "\t", "    ")
    traceback = string.gsub(traceback, "\027%[[%d;]*m", "") -- strip control characters

    local throw_inner_error = function(...)
        io.stdout:write("\n")
        io.stdout:write("In love.errorhandler: " .. table.concat({ ... }, ""))
        io.stdout:write("\n")
        io.stdout:flush()
    end

    local safe_call = function(f, ...)
        local success, error_or_result = pcall(f, ...)
        if not success then
            throw_inner_error(error_or_result)
        else
            return error_or_result
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

    -- set default font
    love.graphics.setFont(love.graphics.newFont(15))

    local SHOULD_QUIT = true
    local SHOULD_NOT_QUIT = false

    local restart = function()
        safe_call(rt.ThreadManager.request_shutdown, rt.ThreadManager)
        love.event.restart()
        return SHOULD_NOT_QUIT
    end

    local function show_messages()
        if rt.Translation == nil then return end
        local entry = rt.Translation.error_handler
        if entry == nil then return end

        local buttons
        if love.system.getOS() == "windows" then
            buttons = { entry.open_log, entry.restart, entry.exit }
        else
            buttons = { entry.exit, entry.restart, entry.open_log }
        end

        local result = love.window.showMessageBox(
            entry.title,
            entry.message,
            buttons,
            "error",
            false
        )

        if buttons[result] == entry.restart then
            restart()
            return SHOULD_NOT_QUIT
        elseif buttons[result] == entry.exit then
            return SHOULD_QUIT
        end
    end

    return function()
        love.event.pump()

        -- check for events
        for event, a, b, c, d, e, f in love.event.poll() do
            if event == "quit" then
                return a or 1, b
            elseif event == "keypressed" then
                local key = b
                if key == "space" or key == "return" then
                    restart()
                elseif key == "escape" then
                    return 0 -- quit
                else
                    if show_messages() == SHOULD_QUIT then
                        return 0
                    end
                end
            elseif event == "touchpressed"
                or event == "mousepressed"
                or event == "gamepadpressed"
            then
                if show_messages() == SHOULD_QUIT then
                    return 0
                end
            end
        end

        -- draw
        if love.graphics.isActive() then
            if rt and rt.Palette and rt.Palette.RED_5 then
                love.graphics.clear(rt.Palette.RED_5:unpack())
            else
                love.graphics.clear(1, 0, 0.2, 1)
            end

            local margin = 70
            love.graphics.printf(
                traceback,
                margin, margin,
                love.graphics.getWidth() - 2 * margin
            )
            love.graphics.present()
        end

        -- connect debugger after error is shown on screen
        if DEBUG and debugger ~= nil and not debugger:get_is_connected() then
            pcall(debugger.connect)
            if debugger.get_is_active() then
                debugger.break_here()
            end
        end

        love.timer.sleep(1 / 1000)
    end
end