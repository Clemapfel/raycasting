require "common.input_manager"

--- @class InputCallbackID
--- @brief list of available input event callbacks, see input_subscriber.lua on how to connect to these
rt.InputCallbackID = meta.enum("InputCallbackID", {
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

    -- mouse cursor entered the window
    -- callback: () -> nil
    MOUSE_ENTERED_SCREEN = "mouse_entered_screen",

    -- keyboard key was pressed
    -- callback: (love.KeyConstant) -> nil -- cf. https://love2d.org/wiki/KeyConstant
    KEYBOARD_KEY_PRESSED = "key_pressed",

    -- keyboard key was released
    -- callback: (love.KeyConstant) -> nil
    KEYBOARD_KEY_RELEASED = "key_released",

    -- controller button (excluding triggers) was pressed
    -- callback: (love.JoystickButton, ControllerID) -> nil -- cf. https://love2d.org/wiki/GamepadButton
    CONTROLLER_BUTTON_PRESSED = "button_pressed",

    -- controller button (excluding triggers) was released
    -- callback: (love.JoystickButton, ControllerID) -> nil -- cf. https://love2d.org/wiki/GamepadButton
    CONTROLLER_BUTTON_RELEASED = "button_released",

    -- left joystick (not dpad) changes position
    -- callback: (x, y, ControllerID) -> nil
    LEFT_JOYSTICK_MOVED = "left_joystick_moved",

    -- right joystick changes position
    -- callback: (x, y, ControllerID) -> nil
    RIGHT_JOYSTICK_MOVED = "right_joystick_moved",

    -- left trigger changes value
    -- callback: (value, ControllerID) -> nil
    LEFT_TRIGGER_MOVED = "left_trigger_moved",

    -- right trigger changes value
    -- callback: (value, ControllerID) -> nil
    RIGHT_TRIGGER_MOVED = "right_trigger_moved"
})

--- @class rt.InputSubscriber
rt.InputSubscriber = meta.class("InputSubscriber")

--- @brief
function rt.InputSubscriber:instantiate()
    table.insert(rt.InputManager._subscribers, self)
    meta.install(self, {
        _callback_id_to_callback = {},
        _callback_id_to_is_blocked = {},
        _override_warning_printed = false
    })
end

meta.add_signals(rt.InputSubscriber,
    "pressed",
    "released",
    rt.InputCallbackID.MOUSE_MOVED,
    rt.InputCallbackID.MOUSE_BUTTON_PRESSED,
    rt.InputCallbackID.MOUSE_BUTTON_RELEASED,
    rt.InputCallbackID.MOUSE_LEFT_SCREEN,
    rt.InputCallbackID.MOUSE_ENTERED_SCREEN,
    rt.InputCallbackID.KEYBOARD_KEY_PRESSED,
    rt.InputCallbackID.KEYBOARD_KEY_RELEASED,
    rt.InputCallbackID.CONTROLLER_BUTTON_PRESSED,
    rt.InputCallbackID.CONTROLLER_BUTTON_RELEASED,
    rt.InputCallbackID.LEFT_JOYSTICK_MOVED,
    rt.InputCallbackID.RIGHT_JOYSTICK_MOVED,
    rt.InputCallbackID.LEFT_TRIGGER_MOVED,
    rt.InputCallbackID.RIGHT_TRIGGER_MOVED
)


