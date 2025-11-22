require "common.input_action"

--- @class rt.InputManager
rt.InputManager = meta.class("InputManager")

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

--- @brief
function rt.InputManager:_notify_input_mapping_changed()
    for sub in values(rt.InputManager._subscribers) do
        if sub:get_is_active() then
            sub:signal_emit(rt.InputCallbackID.INPUT_MAPPING_CHANGED)
        end
    end
end

local _compare_function = function(a, b)
    return a:get_priority() > b:get_priority()
end

--- @brief
function rt.InputManager:_notify_subscriber_added(subscriber)
    meta.assert(subscriber, rt.InputSubscriber)
    table.insert(self._subscribers, 1, subscriber)
end

--- @brief
function rt.InputManager:_notify_end_of_frame()
    for sub in values(self._subscribers) do
        sub:_notify_end_of_frame()
    end
end

--- @brief [internal]
function rt.InputManager:_set_input_method(method)
    local before = self._input_method
    self._input_method = method

    if before ~= self._input_method then
        for sub in values(self._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit(rt.InputCallbackID.INPUT_METHOD_CHANGED)
            end
        end
    end
end

--- @brief
function rt.InputManager:get_input_method()
    return self._input_method
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

--- @brief
function rt.InputManager:get_is_down(action)
    if self._input_method == rt.InputMethod.KEYBOARD then
        return self:is_keyboard_key_down(rt.GameState:get_input_mapping(action, rt.InputMethod.KEYBOARD))
    else
        return self:is_controller_button_down(rt.GameState:get_input_mapping(action, rt.InputMethod.CONTROLLER))
    end
end

--- @brief
function rt.InputManager:get_left_joystick()
    local joystick = self._last_active_joystick
    if joystick == nil then joystick = love.joystick.getJoysticks()[1] end
    if joystick == nil then return 0, 0 end

    local dx = joystick:getGamepadAxis("leftx")
    local dy = joystick:getGamepadAxis("lefty")

    local deadzone = rt.GameState:get_joystick_deadzone()
    local apply = function(x)
        if x > deadzone then
            return (x - deadzone) / (1 - deadzone)
        elseif x < -deadzone then
            return (x + deadzone) / (1 - deadzone)
        else
            return 0
        end
    end

    return apply(dx), apply(dy)
end

--- @brief
function rt.InputManager:get_right_joystick()
    local joystick = self._last_active_joystick
    if joystick == nil then joystick = love.joystick.getJoysticks()[1] end
    if joystick == nil then return 0, 0 end

    local dx = joystick:getGamepadAxis("rightx")
    local dy = joystick:getGamepadAxis("righty")

    local deadzone = rt.GameState:get_joystick_deadzone()
    local apply = function(x)
        if x > deadzone then
            return (x - deadzone) / (1 - deadzone)
        elseif x < -deadzone then
            return (x + deadzone) / (1 - deadzone)
        else
            return 0
        end
    end

    return apply(dx), apply(dy)
end


rt.InputManager = rt.InputManager() -- static singleton instance

--- ### set love callbacks

love.keypressed = function(key, scancode)
    rt.InputManager:_set_input_method(rt.InputMethod.KEYBOARD)

    for sub in values(rt.InputManager._subscribers) do
        if sub:get_is_active() then
            sub:signal_emit(rt.InputCallbackID.KEYBOARD_KEY_PRESSED, key)
        end
    end

    for mapped in values(rt.GameState:get_reverse_input_mapping(key, rt.InputMethod.KEYBOARD)) do
        for sub in values(rt.InputManager._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit("pressed", mapped, -1)
            end
        end
    end
end

love.keyreleased = function(key, scancode)
    rt.InputManager:_set_input_method(rt.InputMethod.KEYBOARD)

    for sub in values(rt.InputManager._subscribers) do
        if sub:get_is_active() then
            sub:signal_emit(rt.InputCallbackID.KEYBOARD_KEY_RELEASED, key)
        end
    end

    for mapped in values(rt.GameState:get_reverse_input_mapping(key, rt.InputMethod.KEYBOARD)) do
        for sub in values(rt.InputManager._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit("released", mapped, -1)
            end
        end
    end
end

love.mousepressed = function(x, y, button_id)
    rt.InputManager:_set_input_method(rt.InputMethod.KEYBOARD)

    for sub in values(rt.InputManager._subscribers) do
        if sub:get_is_active() then
            sub:signal_emit(rt.InputCallbackID.MOUSE_BUTTON_PRESSED, button_id, x, y)
        end
    end
end

love.mousereleased = function(x, y, button_id)
    rt.InputManager:_set_input_method(rt.InputMethod.KEYBOARD)

    for sub in values(rt.InputManager._subscribers) do
        if sub:get_is_active() then
            sub:signal_emit(rt.InputCallbackID.MOUSE_BUTTON_RELEASED, button_id, x, y)
        end
    end
end

love.mousemoved = function(x, y, dx, dy)
    rt.InputManager:_set_input_method(rt.InputMethod.KEYBOARD)
    for sub in values(rt.InputManager._subscribers) do
        if sub:get_is_active() then
            sub:signal_emit(rt.InputCallbackID.MOUSE_MOVED, x, y, dx, dy)
        end
    end
end

love.mousefocus = function(b)
    if b == false then
        for sub in values(rt.InputManager._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit(rt.InputCallbackID.MOUSE_LEFT_SCREEN)
            end
        end
    else
        for sub in values(rt.InputManager._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit(rt.InputCallbackID.MOUSE_ENTERED_SCREEN)
            end
        end
    end
end

love.wheelmoved = function(x, y)
    rt.InputManager:_set_input_method(rt.InputMethod.KEYBOARD)
    for sub in values(rt.InputManager._subscribers) do
        if sub:get_is_active() then
            sub:signal_emit(rt.InputCallbackID.MOUSE_WHEEL_MOVED, x, y)
        end
    end
end

love.gamepadpressed = function(joystick, button)
    rt.InputManager._last_active_joystick = joystick
    rt.InputManager:_set_input_method(rt.InputMethod.CONTROLLER)

    for sub in values(rt.InputManager._subscribers) do
        if sub:get_is_active() then
            sub:signal_emit(rt.InputCallbackID.CONTROLLER_BUTTON_PRESSED, button, joystick:getID())
        end
    end

    for mapped in values(rt.GameState:get_reverse_input_mapping(button, rt.InputMethod.CONTROLLER)) do
        for sub in values(rt.InputManager._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit("pressed", mapped, joystick:getID())
            end
        end
    end
end

love.gamepadreleased = function(joystick, button)
    rt.InputManager._last_active_joystick = joystick
    rt.InputManager:_set_input_method(rt.InputMethod.CONTROLLER)

    for sub in values(rt.InputManager._subscribers) do
        if sub:get_is_active() then
            sub:signal_emit(rt.InputCallbackID.CONTROLLER_BUTTON_RELEASED, button, joystick:getID())
        end
    end

    for mapped in values(rt.GameState:get_reverse_input_mapping(button, rt.InputMethod.CONTROLLER)) do
        for sub in values(rt.InputManager._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit("released", mapped, joystick:getID())
            end
        end
    end
end

local _axis_warning_printed = {}

love.gamepadaxis = function(joystick, axis, value)
    rt.InputManager._last_active_joystick = joystick
    rt.InputManager:_set_input_method(rt.InputMethod.CONTROLLER)
    local joystick_deadzone = rt.GameState:get_joystick_deadzone()
    local apply_joystick_deadzone = function(x)
        if x > joystick_deadzone then
            return (x - joystick_deadzone) / (1 - joystick_deadzone)
        elseif x < -joystick_deadzone then
            return (x + joystick_deadzone) / (1 - joystick_deadzone)
        else
            return 0
        end
    end

    local trigger_deadzone = rt.GameState:get_trigger_deadzone()
    local apply_trigger_deadzone = function(x)
        if x < trigger_deadzone then
            return 0
        else
            return (x - trigger_deadzone) / (1 - trigger_deadzone)
        end
    end

    if axis == "leftx" or axis == "lefty" then
        for sub in values(rt.InputManager._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit(rt.InputCallbackID.LEFT_JOYSTICK_MOVED,
                    apply_joystick_deadzone(joystick:getGamepadAxis("leftx")),
                    apply_joystick_deadzone(joystick:getGamepadAxis("lefty")),
                    joystick:getID()
                )
            end
        end
    elseif axis == "rightx" or axis == "righty" then
        for sub in values(rt.InputManager._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit(rt.InputCallbackID.RIGHT_JOYSTICK_MOVED,
                    apply_joystick_deadzone(joystick:getGamepadAxis("rightx")),
                    apply_joystick_deadzone(joystick:getGamepadAxis("righty")),
                    joystick:getID()
                )
            end
        end
    elseif axis == "triggerleft" then
        for sub in values(rt.InputManager._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit(rt.InputCallbackID.LEFT_TRIGGER_MOVED,
                    apply_trigger_deadzone(joystick:getGamepadAxis("triggerleft")),
                    joystick:getID()
                )
            end
        end
    elseif axis == "triggerright" then
        for sub in values(rt.InputManager._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit(rt.InputCallbackID.RIGHT_TRIGGER_MOVED,
                    apply_trigger_deadzone(joystick:getGamepadAxis("triggerright")),
                    joystick:getID()
                )
            end
        end
    else
        if _axis_warning_printed[axis] == nil then
            rt.warning("In rt.InputManager.gamepadaxis: unhandled axis `", axis, "`")
            _axis_warning_printed[axis] = true
        end
    end
end
