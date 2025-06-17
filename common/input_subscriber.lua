require "common.input_manager"

--- @class InputCallbackID
--- @brief list of available input event callbacks, see input_subscriber.lua on how to connect to these
rt.InputCallbackID = meta.enum("InputCallbackID", {
    -- input button pressed
    INPUT_BUTTON_PRESSED = "pressed",

    INPUT_BUTTON_RELEASED = "released",

    -- cursor moves while inside the windows bounds
    -- callback: (x, y, dx, dy) -> nil
    MOUSE_MOVED = "mouse_moved",

    -- mouse or touchscreen tap while inside windows bounds
    -- callback: (love.MouseButton, x, y) -> nil -- cf. https://love2d.org/wiki/love.mousepressed
    MOUSE_BUTTON_PRESSED = "mouse_pressed",

    -- mouse or touchscreen release
    -- callback: (love.MouseButton, x, y) -> nil -- cf. https://love2d.org/wiki/love.mousereleased
    MOUSE_BUTTON_RELEASED = "mouse_released",

    -- mouse cursor left the window
    -- callback: () -> nil
    MOUSE_LEFT_SCREEN = "mouse_left_screen",

    -- mouse wheel move
    -- callback: (dx, dy) -> nil
    MOUSE_WHEEL_MOVED = "mouse_wheel_moved",

    -- mouse cursor entered the window
    -- callback: () -> nil
    MOUSE_ENTERED_SCREEN = "mouse_entered_screen",

    -- keyboard key was pressed
    -- callback: (love.KeyConstant) -> nil -- cf. https://love2d.org/wiki/KeyConstant
    KEYBOARD_KEY_PRESSED = "keyboard_key_pressed",

    -- keyboard key was released
    -- callback: (love.KeyConstant) -> nil
    KEYBOARD_KEY_RELEASED = "keyboard_key_released",

    -- controller button (excluding triggers) was pressed
    -- callback: (love.JoystickButton, ControllerID) -> nil -- cf. https://love2d.org/wiki/ControllerButton
    CONTROLLER_BUTTON_PRESSED = "controller_button_pressed",

    -- controller button (excluding triggers) was released
    -- callback: (love.JoystickButton, ControllerID) -> nil -- cf. https://love2d.org/wiki/ControllerButton
    CONTROLLER_BUTTON_RELEASED = "controller_button_released",

    -- left joystick (not dpad) changes position
    -- callback: (x, y, ControllerID) -> nil
    LEFT_JOYSTICK_MOVED = "left_joystick_moved",

    -- right joystick changes position
    -- callback: (x, y, ControllerID) -> nil
    RIGHT_JOYSTICK_MOVED = "right_joystick_moved",

    -- left trigger changes value
    -- callback: (left, ControllerID) -> nil
    LEFT_TRIGGER_MOVED = "left_trigger_moved",

    -- left trigger changes value
    -- callback: (right, ControllerID) -> nil
    RIGHT_TRIGGER_MOVED = "right_trigger_moved",

    -- input
    -- callback: (method, ControllerID?) -> nil
    INPUT_METHOD_CHANGED = "input_method_changed",

    -- callback () -> nil
    INPUT_MAPPING_CHANGED = "input_mapping_changed",

    -- callback () -> nil
    WINDOW_RESIZED = "window_resized",
})

--- @class rt.InputSubscriber
rt.InputSubscriber = meta.class("InputSubscriber")

local to_add = { "pressed", "released" }
for name in values(meta.instances(rt.InputCallbackID)) do
    table.insert(to_add, name)
end
meta.add_signals(rt.InputSubscriber, table.unpack(to_add))

--- @brief
function rt.InputSubscriber:instantiate(is_active)
    if is_active == nil then is_active = true end
    table.insert(rt.InputManager._subscribers, self)
    meta.install(self, {
        _callback_id_to_callback = {},
        _callback_id_to_is_blocked = {},
        _override_warning_printed = false,
        _is_active = is_active
    })
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
function rt.InputSubscriber:deactivate()
    self._is_active = false
end

--- @brief
function rt.InputSubscriber:activate()
    self._is_active = true
end



