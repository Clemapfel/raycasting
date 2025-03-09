require "common.input_mapping"

--- @class rt.InputManager
rt.InputManager = meta.class("rt.InputManager")

--- @brief [internal]
function rt.InputManager:instantiate()
    meta.install(self, {
        _subscribers = meta.make_weak({}),
        _cursor_in_bounds = true,
        _last_active_joystick = nil
    })
end

--- @brief
function rt.InputManager:is_keyboard_key_down(key)
    return love.keyboard.isDown(key)
end

--- @brief
function rt.InputManager:is_controller_button_down(button)
    local joystick = self._last_active_joystick
    if joystick == nil then joystick = love.joystick.getJoysticks()[1] end
    if joystick == nil then
        return false
    else
        return joystick:isDown(button)
    end
end

rt.InputManager = rt.InputManager() -- static singleton instance

--- ### set love callbacks

love.keypressed = function(key, scancode)
    for sub in values(rt.InputManager._subscribers) do
        sub:signal_emit(rt.InputCallbackID.KEYBOARD_KEY_PRESSED, key)
    end

    local mapped = rt.InputMapping:map(key, true)
    if mapped ~= nil then
        for sub in values(rt.InputManager._subscribers) do
            sub:signal_emit("pressed", mapped, -1)
        end
    end
end

love.keyreleased = function(key, scancode)
    for sub in values(rt.InputManager._subscribers) do
        sub:signal_emit(rt.InputCallbackID.KEYBOARD_KEY_RELEASED, key)
    end

    local mapped = rt.InputMapping:map(key, true)
    if mapped ~= nil then
        for sub in values(rt.InputManager._subscribers) do
            sub:signal_emit("released", mapped, -1)
        end
    end
end

love.mousepressed = function(x, y, button_id)
    if rt.InputManager._upscaler ~= nil and rt.InputManager._convert_to_native_resolution == true then
        x, y = rt.InputManager._upscaler:convertWindowToNativePosition(x, y)
    end

    for sub in values(rt.InputManager._subscribers) do
        sub:signal_emit(rt.InputCallbackID.MOUSE_BUTTON_PRESSED, button_id, x, y)
    end
end

love.mousereleased = function(x, y, button_id)
    if rt.InputManager._upscaler ~= nil and rt.InputManager._convert_to_native_resolution == true then
        x, y = rt.InputManager._upscaler:convertWindowToNativePosition(x, y)
    end

    for sub in values(rt.InputManager._subscribers) do
        sub:signal_emit(rt.InputCallbackID.MOUSE_BUTTON_RELEASED, button_id, x, y)
    end
end

love.mousemoved = function(x, y, dx, dy)
    if rt.InputManager._upscaler ~= nil then
        -- check if cursor left upscaler area and emit as if it left window
        local before = rt.InputManager._cursor_in_bounds
        local current = rt.InputManager._upscaler:getIsCursorInBounds(x, y)
        if before == false and current == true then
            for sub in values(rt.InputManager._subscribers) do
                sub:signal_emit(rt.InputCallbackID.MOUSE_ENTERED_SCREEN)
            end
        elseif before == true and current == false then
            for sub in values(rt.InputManager._subscribers) do
                sub:signal_emit(rt.InputCallbackID.MOUSE_LEFT_SCREEN)
            end
        end

        rt.InputManager._cursor_in_bounds = current
    end

    if rt.InputManager._upscaler ~= nil and rt.InputManager._convert_to_native_resolution == true then
        x, y = rt.InputManager._upscaler:convertWindowToNativePosition(x, y)
        dx, dy = rt.InputManager._upscaler:convertWindowToNativePosition(dx, dy) -- sic
    end

    for sub in values(rt.InputManager._subscribers) do
        sub:signal_emit(rt.InputCallbackID.MOUSE_MOVED, x, y, dx, dy)
    end
end

love.mousefocus = function(b)
    if b == false then
        for sub in values(rt.InputManager._subscribers) do
            sub:signal_emit(rt.InputCallbackID.MOUSE_LEFT_SCREEN)
        end
    else
        for sub in values(rt.InputManager._subscribers) do
            sub:signal_emit(rt.InputCallbackID.MOUSE_ENTERED_SCREEN)
        end
    end
end

love.gamepadpressed = function(joystick, button)
    rt.InputManager._last_active_joystick = joystick

    for sub in values(rt.InputManager._subscribers) do
        sub:signal_emit(rt.InputCallbackID.CONTROLLER_BUTTON_PRESSED, button, joystick:getID())
    end

    local mapped = rt.InputMapping:map(button, false)
    if mapped ~= nil then
        for sub in values(rt.InputManager._subscribers) do
            sub:signal_emit("pressed", mapped, joystick:getID())
        end
    end
end

love.gamepadreleased = function(joystick, button)
    rt.InputManager._last_active_joystick = joystick

    for sub in values(rt.InputManager._subscribers) do
        sub:signal_emit(rt.InputCallbackID.CONTROLLER_BUTTON_RELEASED, button, joystick:getID())
    end

    local mapped = rt.InputMapping:map(button, false)
    if mapped ~= nil then
        for sub in values(rt.InputManager._subscribers) do
            sub:signal_emit("released", mapped, joystick:getID())
        end
    end
end

love.gamepadaxis = function(joystick, axis, value)
    rt.InputManager._last_active_joystick = joystick

    if axis == "leftx" or axis == "lefty" then
        for sub in values(rt.InputManager._subscribers) do
            sub:signal_emit(rt.InputCallbackID.LEFT_JOYSTICK_MOVED, joystick:getAxis("leftx"), joystick:getAxis("lefty"), joystick:getID())
        end
    elseif axis == "rightx" or axis == "righty" then
        for sub in values(rt.InputManager._subscribers) do
            sub:signal_emit(rt.InputCallbackID.RIGHT_JOYSTICK_MOVED, joystick:getAxis("rightx"), joystick:getAxis("righty"), joystick:getID())
        end
    elseif axis == "triggerleft" then
        for sub in values(rt.InputManager._subscribers) do
            sub:signal_emit(rt.InputCallbackID.LEFT_TRIGGER_MOVED, value, joystick:getID())
        end
    elseif axis == "triggerright" then
        for sub in values(rt.InputManager._subscribers) do
            sub:signal_emit(rt.InputCallbackID.RIGHT_TRIGGER_MOVED, value, joystick:getID())
        end
    else
        rt.warning("In love.gamepadaxis: unhandled axis `" .. axis .. "`")
    end
end
