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
        _input_method = rt.InputMethod.KEYBOARD,
        _keyboard_key_to_last_pressed = {},
        _controller_button_to_last_pressed = {}
    })
end

--- @brief
function rt.InputManager:reset()
    self._subscribers = meta.make_weak({})
end

--- @brief
function rt.InputManager:_notify_pressed(which, input_method)
    local time = love.timer.getTime()
    local data = ternary(
        input_method == rt.InputMethod.KEYBOARD,
        rt.InputManager._keyboard_key_to_last_pressed,
        rt.InputManager._controller_button_to_last_pressed
    )

    local max_duration = rt.GameState:get_double_press_threshold()
    local entry = data[which]

    -- never pressed before: create entry
    if entry == nil then
        entry = {
            timestamp = time,
            count = 1
        }

        data[which] = entry
        -- never freeing this is fine, there is only a limited number of keys
    else
        local delta = time - entry.timestamp
        if delta >= max_duration then
            -- slower than threshold: reset
            entry.timestamp = time
            entry.count = 1
        else
            -- faster than threshold: increase
            entry.timestamp = time
            entry.count = entry.count + 1
        end
    end
end

--- @brief
function rt.InputManager:_notify_released(which, input_method)
    -- noop
end

--- @brief
function rt.InputManager:get_count(which, input_method)
    local data = ternary(
        input_method == rt.InputMethod.KEYBOARD,
        rt.InputManager._keyboard_key_to_last_pressed,
        rt.InputManager._controller_button_to_last_pressed
    )

    local entry = data[which]
    if entry == nil then
        return 0
    else
        return entry.count
    end
end

--- @brief
function rt.InputManager:_notify_input_mapping_changed()
    for sub in values(rt.InputManager._subscribers) do
        if sub:get_is_active() then
            sub:signal_emit("input_mapping_changed")
        end
    end
end

--- @brief
function rt.InputManager:_notify_subscriber_added(subscriber)
    meta.assert(subscriber, rt.InputSubscriber)
    table.insert(self._subscribers, 1, subscriber)
    self:_notify_priority_changed(subscriber)
end

--- @brief
function rt.InputManager:_notify_priority_changed(subscriber)
    require "common.stable_sort"
    table.stable_sort(self._subscribers, function(a, b) return a:get_priority() < b:get_priority() end)
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
                sub:signal_emit("input_method_changed")
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
        local mapping = rt.GameState:get_input_mapping(action, rt.InputMethod.KEYBOARD)
        for key in values(mapping) do
            if self:is_keyboard_key_down(key) == true then return true end
        end
        return false
    else
        local mapping = rt.GameState:get_input_mapping(action, rt.InputMethod.CONTROLLER)
        for button in values(mapping) do
            if self:is_controller_button_down(button) == true then return true end
        end
        return false
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

--- ### love callbacks ###

love.keypressed = function(key, scancode)
    rt.InputManager:_set_input_method(rt.InputMethod.KEYBOARD)
    rt.InputManager:_notify_pressed(key, rt.InputMethod.KEYBOARD)

    for sub in values(rt.InputManager._subscribers) do
        if sub:get_is_active() then
            sub:signal_emit("keyboard_key_pressed",
                key,
                rt.InputManager:get_count(key, rt.InputMethod.KEYBOARD)
            )
        end
    end

    for mapped in values(rt.GameState:get_reverse_input_mapping(key, rt.InputMethod.KEYBOARD)) do
        for sub in values(rt.InputManager._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit("pressed",
                    mapped,
                    rt.InputManager:get_count(key, rt.InputMethod.KEYBOARD)
                )
            end
        end
    end
end

love.keyreleased = function(key, scancode)
    rt.InputManager:_set_input_method(rt.InputMethod.KEYBOARD)
    rt.InputManager:_notify_released(key, rt.InputMethod.KEYBOARD)

    for sub in values(rt.InputManager._subscribers) do
        if sub:get_is_active() then
            sub:signal_emit("keyboard_key_released",
                key,
                rt.InputManager:get_count(key, rt.InputMethod.KEYBOARD)
            )
        end
    end

    for mapped in values(rt.GameState:get_reverse_input_mapping(key, rt.InputMethod.KEYBOARD)) do
        for sub in values(rt.InputManager._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit("released",
                    mapped,
                    rt.InputManager:get_count(key, rt.InputMethod.KEYBOARD)
                )
            end
        end
    end
end

love.mousepressed = function(x, y, button_id, is_touch, count)
    rt.InputManager:_set_input_method(rt.InputMethod.KEYBOARD)

    for sub in values(rt.InputManager._subscribers) do
        if sub:get_is_active() then
            sub:signal_emit("mouse_pressed", button_id, x, y, count)
        end
    end
end

love.mousereleased = function(x, y, button_id, is_touch, count)
    rt.InputManager:_set_input_method(rt.InputMethod.KEYBOARD)

    for sub in values(rt.InputManager._subscribers) do
        if sub:get_is_active() then
            sub:signal_emit("mouse_released", button_id, x, y, count)
        end
    end
end

love.mousemoved = function(x, y, dx, dy)
    rt.InputManager:_set_input_method(rt.InputMethod.KEYBOARD)
    for sub in values(rt.InputManager._subscribers) do
        if sub:get_is_active() then
            sub:signal_emit("mouse_moved", x, y, dx, dy)
        end
    end
end

love.mousefocus = function(b)
    if b == false then
        for sub in values(rt.InputManager._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit("mouse_left_screen")
            end
        end
    else
        for sub in values(rt.InputManager._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit("mouse_entered_screen")
            end
        end
    end
end

love.wheelmoved = function(x, y)
    rt.InputManager:_set_input_method(rt.InputMethod.KEYBOARD)
    for sub in values(rt.InputManager._subscribers) do
        if sub:get_is_active() then
            sub:signal_emit("mouse_wheel_moved", x, y)
        end
    end
end

love.gamepadpressed = function(joystick, button)
    rt.InputManager._last_active_joystick = joystick
    rt.InputManager:_set_input_method(rt.InputMethod.CONTROLLER)
    rt.InputManager:_notify_pressed(button, rt.InputMethod.CONTROLLER)

    for sub in values(rt.InputManager._subscribers) do
        if sub:get_is_active() then
            sub:signal_emit("controller_button_pressed",
                button,
                rt.InputManager:get_count(button, rt.InputMethod.CONTROLLER),
                joystick:getID()
            )
        end
    end

    for mapped in values(rt.GameState:get_reverse_input_mapping(button, rt.InputMethod.CONTROLLER)) do
        for sub in values(rt.InputManager._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit("pressed",
                    mapped,
                    rt.InputManager:get_count(button, rt.InputMethod.CONTROLLER),
                    joystick:getID()
                )
            end
        end
    end
end

love.gamepadreleased = function(joystick, button)
    rt.InputManager._last_active_joystick = joystick
    rt.InputManager:_set_input_method(rt.InputMethod.CONTROLLER)
    rt.InputManager:_notify_released(button, rt.InputMethod.CONTROLLER)

    for sub in values(rt.InputManager._subscribers) do
        if sub:get_is_active() then
            sub:signal_emit("controller_button_released",
                button,
                rt.InputManager:get_count(button, rt.InputMethod.CONTROLLER),
                joystick:getID()
            )
        end
    end

    for mapped in values(rt.GameState:get_reverse_input_mapping(button, rt.InputMethod.CONTROLLER)) do
        for sub in values(rt.InputManager._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit("released",
                    mapped,
                    rt.InputManager:get_count(button, rt.InputMethod.CONTROLLER),
                    joystick:getID()
                )
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
                sub:signal_emit("left_joystick_moved",
                    apply_joystick_deadzone(joystick:getGamepadAxis("leftx")),
                    apply_joystick_deadzone(joystick:getGamepadAxis("lefty")),
                    joystick:getID()
                )
            end
        end
    elseif axis == "rightx" or axis == "righty" then
        for sub in values(rt.InputManager._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit("right_joystick_moved",
                    apply_joystick_deadzone(joystick:getGamepadAxis("rightx")),
                    apply_joystick_deadzone(joystick:getGamepadAxis("righty")),
                    joystick:getID()
                )
            end
        end
    elseif axis == "triggerleft" then
        for sub in values(rt.InputManager._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit("left_trigger_moved",
                    apply_trigger_deadzone(joystick:getGamepadAxis("triggerleft")),
                    joystick:getID()
                )
            end
        end
    elseif axis == "triggerright" then
        for sub in values(rt.InputManager._subscribers) do
            if sub:get_is_active() then
                sub:signal_emit("right_trigger_moved",
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
