require "common.input_mapping"

rt.settings.input_manager = {
    joystick_deadzone = 0.15,
    trigger_deadzone = 0.05
}

--- @class rt.InputManager
rt.InputManager = meta.class("rt.InputManager")

rt.InputMethod = meta.enum("InputMethod", {
    KEYBOARD = true,
    CONTROLLER = false
})

--- @brief [internal]
function rt.InputManager:instantiate()
    meta.install(self, {
        _subscribers = meta.make_weak({}),
        _cursor_in_bounds = true,
        _last_active_joystick = nil,
        _input_method = rt.InputMethod.KEYBOARD
    })
end

--- @brief [internal]
function rt.InputManager:_set_input_method(method)
    if method ~= self._input_method then
        for subscriber in values(self._subscribers) do
            if method == rt.InputManager.KEYBOARD then
                subscriber:signal_emit(rt.InputCallbackID.INPUT_METHOD_CHANGED, nil)
            elseif method == rt.InputMethod.CONTROLLER then
                subscriber:signal_emit(rt.InputCallbackID.INPUT_METHOD_CHANGED, self._last_active_joystick:getID())
            end
        end
    end
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
        return joystick:isGamepadDown(button)
    end
end

rt.InputManager = rt.InputManager() -- static singleton instance

--- ### set love callbacks

love.keypressed = function(key, scancode)
    rt.InputManager:_set_input_method(rt.InputMethod.KEYBOARD)

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
    rt.InputManager:_set_input_method(rt.InputMethod.KEYBOARD)

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
    rt.InputManager:_set_input_method(rt.InputMethod.CONTROLLER)

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
    rt.InputManager:_set_input_method(rt.InputMethod.CONTROLLER)

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

local _axis_warning_printed = {}

love.gamepadaxis = function(joystick, axis, value)
    rt.InputManager._last_active_joystick = joystick
    rt.InputManager:_set_input_method(rt.InputMethod.CONTROLLER)
    local joystick_deadzone = rt.settings.input_manager.joystick_deadzone
    local apply_joystick_deadzone = function(x)
        if x > joystick_deadzone then
            return (x - joystick_deadzone) / (1 - joystick_deadzone)
        elseif x < -joystick_deadzone then
            return (x + joystick_deadzone) / (1 - joystick_deadzone)
        else
            return 0
        end
    end

    local trigger_deadzone = rt.settings.input_manager.trigger_deadzone
    local apply_trigger_deadzone = function(x)
        if x < trigger_deadzone then
            return 0
        else
            return (x - trigger_deadzone) / (1 - trigger_deadzone)
        end
    end

    if axis == "leftx" or axis == "lefty" then
        for sub in values(rt.InputManager._subscribers) do
            sub:signal_emit(rt.InputCallbackID.LEFT_JOYSTICK_MOVED,
                apply_joystick_deadzone(joystick:getGamepadAxis("leftx")),
                apply_joystick_deadzone(joystick:getGamepadAxis("lefty")),
                joystick:getID()
            )
        end
    elseif axis == "rightx" or axis == "righty" then
        for sub in values(rt.InputManager._subscribers) do
            sub:signal_emit(rt.InputCallbackID.RIGHT_JOYSTICK_MOVED,
                apply_joystick_deadzone(joystick:getGamepadAxis("rightx")),
                apply_joystick_deadzone(joystick:getGamepadAxis("righty")),
                joystick:getID()
            )
        end
    elseif axis == "triggerleft" then
        for sub in values(rt.InputManager._subscribers) do
            sub:signal_emit(rt.InputCallbackID.LEFT_TRIGGER_MOVED,
                apply_trigger_deadzone(joystick:getGamepadAxis("triggerleft")),
                joystick:getID()
            )
        end
    elseif axis == "triggerright" then
        for sub in values(rt.InputManager._subscribers) do
            sub:signal_emit(rt.InputCallbackID.RIGHT_TRIGGER_MOVED,
                apply_trigger_deadzone(joystick:getGamepadAxis("triggerright")),
                joystick:getID()
            )
        end
    else
        if _axis_warning_printed[axis] == nil then
            rt.warning("In rt.InputManager.gamepadaxis: unhandled axis `" .. axis .. "`")
            _axis_warning_printed[axis] = true
        end
    end
end
