require "common.input_manager"

--- @class rt.InputSubscriber
rt.InputSubscriber = meta.class("InputSubscriber")

meta.add_signals(rt.InputSubscriber,
    -- input action pressed
    -- (rt.InputSubscriber, rt.InputAction, count) -> nil
    "pressed",
    
    -- input action released
    -- (rt.InputSubscriber, rt.InputAction, count) -> nil
    "released",
    
    -- cursor moves while inside the windows bounds
    -- (rt.InputSubscriber, x, y, dx, dy) -> nil
    "mouse_moved",
    
    -- mouse or touchscreen tap while inside windows bounds
    -- (rt.InputSubscriber, love.MouseButton, x, y, count) -> nil -- cf. https://love2d.org/wiki/love.mousepressed
    "mouse_pressed",
    
    -- mouse or touchscreen release
    -- (rt.InputSubscriber, love.MouseButton, x, y, count) -> nil -- cf. https://love2d.org/wiki/love.mousereleased
    "mouse_released",
    
    -- mouse cursor left the window
    -- (rt.InputSubscriber) -> nil
    "mouse_left_screen",
    
    -- mouse wheel move
    -- (rt.InputSubscriber, dx, dy) -> nil
    "mouse_wheel_moved",
    
    -- mouse cursor entered the window
    -- (rt.InputSubscriber) -> nil
    "mouse_entered_screen",
    
    -- keyboard key was pressed
    -- (rt.InputSubscriber, love.KeyConstant, count) -> nil -- cf. https://love2d.org/wiki/KeyConstant
    "keyboard_key_pressed",
    
    -- keyboard key was released
    -- (rt.InputSubscriber, love.KeyConstant, count) -> nil
    "keyboard_key_released",
    
    -- controller button (excluding triggers) was pressed
    -- (rt.InputSubscriber, love.JoystickButton, count, ControllerID) -> nil -- cf. https://love2d.org/wiki/ControllerButton
    "controller_button_pressed",
    
    -- controller button (excluding triggers) was released
    -- (rt.InputSubscriber, love.JoystickButton, count, ControllerID) -> nil -- cf. https://love2d.org/wiki/ControllerButton
    "controller_button_released",
    
    -- left joystick (not dpad) changes position
    -- (rt.InputSubscriber, x, y, ControllerID) -> nil
    "left_joystick_moved",
    
    -- right joystick changes position
    -- (rt.InputSubscriber, x, y, ControllerID) -> nil
    "right_joystick_moved",
    
    -- left trigger changes value
    -- (rt.InputSubscriber, left, ControllerID) -> nil
    "left_trigger_moved",
    
    -- left trigger changes value
    -- (rt.InputSubscriber, right, ControllerID) -> nil
    "right_trigger_moved",
    
    -- (rt.InputSubscriber, method, ControllerID?) -> nil
    "input_method_changed",

    -- (rt.InputSubscriber) -> nil
    "input_mapping_changed"
)

--- @brief
function rt.InputSubscriber:instantiate(priority)
    self._n_inactive_frames = 0
    self._activate_frame = -1
    self._priority = priority or 0
    rt.InputManager:_notify_subscriber_added(self)
end

--- @brief
function rt.InputSubscriber:get_mouse_position()
    return love.mouse.getPosition()
end

--- @brief
function rt.InputSubscriber:get_is_down(input_action)
    local keyboard_keys, controller_buttons = rt.GameState:get_input_mapping(input_action)

    for key in values(keyboard_keys) do
        if rt.InputManager:is_keyboard_key_down(key) then return true end
    end

    for button in values(controller_buttons) do
        if rt.InputManager:is_controller_button_down(button) then return true end
    end

    return false
end

--- @brief
function rt.InputSubscriber:get_input_method()
    return rt.InputManager:get_input_method()
end

--- @brief
function rt.InputSubscriber:get_count()
    return rt.InputManager:get_count()
end

--- @brief
function rt.InputSubscriber:deactivate(n_frames)
    if n_frames == nil then n_frames = math.huge end
    self._n_inactive_frames = n_frames
    self._activate_frame = rt.SceneManager:get_frame_index()
end

--- @brief
function rt.InputSubscriber:activate()
    self._n_inactive_frames = 0
end

--- @brief
function rt.InputSubscriber:get_is_active()
    return self._n_inactive_frames <= 0 and rt.SceneManager:get_frame_index() > self._activate_frame
end

--- @brief
function rt.InputSubscriber:_notify_end_of_frame()
    self._n_inactive_frames = self._n_inactive_frames - 1
end

--- @brief
function rt.InputSubscriber:set_priority(priority)
    if self._priority ~= priority then
        self._priority = priority
        rt.InputManager:_notify_priority_changed(self)
    end
end

--- @brief
function rt.InputSubscriber:get_priority()
    return self._priority
end

-- TODO
if DEBUG then
    DEBUG_INPUT = rt.InputSubscriber()
end