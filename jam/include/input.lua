input_should_disconnect = 0x0

input_action_click = "click"
input_action_accept = "accept"
input_action_back = "back"
input_action_reset = "reset"
input_action_jump = "jump"
input_action_move_left = "left"
input_action_move_right = "right"
input_action_move_up = "up"
input_action_move_down = "down"
input_action_become_liquid = "become_liquid"
input_action_become_solid = "become_solid"
input_action_pause = "pause"
input_action_debug = "debug"

InputMethod = {
    KEYBOARD = "KEYBOARD",
    GAMEPAD = "GAMEPAD"
}

local _is_active = true
local _input_action_to_binding = {
    [input_action_accept] = {
        keyboard = { "space", "return" },
        gamepad  = { "b", "start" },
    },

    [input_action_back] = {
        keyboard = { "escape", "b", "backspace" },
        gamepad  = { "a", "back" },
    },

    [input_action_reset] = {
        keyboard = { "x", "backspace", },
        gamepad = { "back" }
    },

    [input_action_jump] = {
        keyboard = { "space" },
        gamepad  = {},
    },

    [input_action_move_left] = {
        keyboard = { "a", "left" },
        gamepad  = { "dpleft" },
    },

    [input_action_move_right] = {
        keyboard = { "d", "right" },
        gamepad  = { "dpright" },
    },

    [input_action_move_down] = {
        keyboard = { "s", "down" },
        gamepad  = { "dpdown" },
    },

    [input_action_move_up] = {
        keyboard = { "w", "up" },
        gamepad  = { "dpup" },
    },

    [input_action_become_liquid] = {
        keyboard = { "1", "q", "n", "o" },
        gamepad  = { "leftshoulder" },
    },

    [input_action_become_solid] = {
        keyboard = { "2", "e", "m", "p"},
        gamepad  = { "rightshould"},
    },

    [input_action_pause] = {
        keyboard = { "escape" },
        gamepad  = { "start" },
    },

    [input_action_click] = {
        keyboard = {},
        gamepad = {}
    },

    [input_action_debug] = {
        keyboard = { "^" },
        gamepad  = {},
    },
}

local _binding_to_input_action = {
    [InputMethod.KEYBOARD] = {},
    [InputMethod.GAMEPAD] = {}
}

for input_action, entry in pairs(_input_action_to_binding) do
    for _, keyboard_key in ipairs(entry.keyboard) do
        local actions = _binding_to_input_action[InputMethod.KEYBOARD][keyboard_key]
        if actions == nil then
            actions = {}
            _binding_to_input_action[InputMethod.KEYBOARD][keyboard_key] = actions
        end
        table_push(actions, input_action)
    end

    for _, gamepad_button in ipairs(entry.gamepad) do
        local actions = _binding_to_input_action[InputMethod.GAMEPAD][gamepad_button]
        if actions == nil then
            actions = {}
            _binding_to_input_action[InputMethod.GAMEPAD][gamepad_button] = actions
        end
        table_push(actions, input_action)
    end
end

local _is_input_action = {}
for _, action in ipairs({
    input_action_accept,
    input_action_back,
    input_action_reset,
    input_action_jump,
    input_action_move_left,
    input_action_move_right,
    input_action_move_up,
    input_action_move_down,
    input_action_become_liquid,
    input_action_become_solid,
    input_action_pause,
    input_action_click,
    input_action_debug
}) do
    _is_input_action[action] = true
end

input_is_input_action = function(x)
    return _is_input_action[x] == true
end

local _keyboard_key_name_mapping = {
    ["return"] = "Enter"
}

local _gamepad_button_name_mapping = {
    a = "Bottom",
    b = "Right",
    x = "Left",
    y = "Top",
    back = "Select",
    guide = "Guide Button",
    start = "Start",
    leftstick = "L3",
    rightstick = "R3",
    leftshoulder = "LB",
    rightshoulder = "RB",
    dpup = "Up",
    dpdown = "Down",
    dpleft = "Left",
    dpright = "Right",
}

input_keyboard_key_get_cleartext_name = function(scancode)
    log_typecheck(scancode, String_t)

    local raw = love.keyboard.getKeyFromScancode(scancode)
    raw = _keyboard_key_name_mapping[raw] or raw
    return string.upper(string.sub(raw, 1, 1)) .. string.sub(raw, 2)
end

input_gamepad_button_get_cleartext_name = function(button)
    log_typecheck(button, String_t)

    local raw = _gamepad_button_name_mapping[button] or button
    return string.upper(string.sub(raw, 1, 1)) .. string.sub(raw, 2)
end

input_get_keyboard_keys = function(action)
    log_typecheck(action, String_t)
    log_assert(input_is_input_action(action), "In input_get_keyboard_keys: `", object_to_string(action), "` is not a valid input action")
    return _input_action_to_binding[action].keyboard
end

input_get_gamepad_buttons = function(action)
    log_typecheck(action, String_t)
    log_assert(input_is_input_action(action), "In input_get_gamepad_buttons: `", object_to_string(action), "` is not a valid input action")
    return _input_action_to_binding[action].gamepad
end

input_set_is_active = function(is_active)
    log_typecheck(is_active, Boolean_t)
    is_active = is_active
end

local _input_method = InputMethod.KEYBOARD

input_get_input_method = function()
    return _input_method
end

do
    local _pressed_handler_id = 0
    local _handler_id_to_callback = {}

    input_connect_pressed = function(callback, to_disconnect)
        log_typecheck(callback, Function_t)

        local id = _pressed_handler_id
        _pressed_handler_id = _pressed_handler_id + 1
        _handler_id_to_callback[id] = callback

        if to_disconnect ~= nil then input_disconnect_pressed(to_disconnect) end
        return id
    end

    input_disconnect_pressed = function(id)
        if id == nil then return end
        log_typecheck(id, Number_t)

        if _handler_id_to_callback[id] == nil then
            log_warning("In input_disconnect_pressed: no handler with id `", id, "`")
        end
        _handler_id_to_callback[id] = nil
    end

    input_emit_pressed = function(action)
        log_assert(input_is_input_action(action), "In input_emit_pressed: `", object_to_string(action), "` is not a valid input action")
        if _is_active ~= true then return end

        -- snapshot ids for mid-emission connect / disconnect
        local ids = {}
        for id in pairs(_handler_id_to_callback) do
            table_push(ids, id)
        end
        table_sort(ids)

        for _, id in ipairs(ids) do
            local callback = _handler_id_to_callback[id]
            if callback ~= nil then
                local result = log_call(callback, action)
                if result == input_should_disconnect then
                    _handler_id_to_callback[id] = nil
                end
            end
        end
    end
end

do
    local _released_handler_id = 0
    local _handler_id_to_callback = {}

    input_connect_released = function(callback, to_disconnect)
        log_typecheck(callback, Function_t)

        local id = _released_handler_id
        _released_handler_id = _released_handler_id + 1
        _handler_id_to_callback[id] = callback

        if to_disconnect ~= nil then input_disconnect_released(to_disconnect) end
        return id
    end

    input_disconnect_released = function(id)
        if id == nil then return end
        log_typecheck(id, Number_t)

        if _handler_id_to_callback[id] == nil then
            log_warning("In input_disconnect_released: no handler with id `", id, "`")
        end
        _handler_id_to_callback[id] = nil
    end

    input_emit_released = function(action)
        log_assert(input_is_input_action(action), "In input_emit_released: `", object_to_string(action), "` is not a valid input action")
        if _is_active ~= true then return end

        local ids = {}
        for id in pairs(_handler_id_to_callback) do
            table_push(ids, id)
        end
        table_sort(ids)

        for _, id in ipairs(ids) do
            local callback = _handler_id_to_callback[id]
            if callback ~= nil then
                local result = log_call(callback, action)
                if result == input_should_disconnect then
                    _handler_id_to_callback[id] = nil
                end
            end
        end
    end
end

do
    local _cursor_moved_handler_id = 0
    local _cursor_moved_handler_to_callback = {}
    local _cursor_position_x, _cursor_position_y = love.mouse.getPosition()

    input_get_cursor_position_raw = function()
        return _cursor_position_x, _cursor_position_y
    end

    input_get_cursor_position = function()
        return upscaler_from_window_position(input_get_cursor_position_raw())
    end

    input_connect_cursor_moved = function(callback, to_disconnect)
        log_typecheck(callback, Function_t)

        local id = _cursor_moved_handler_id
        _cursor_moved_handler_id = _cursor_moved_handler_id + 1
        _cursor_moved_handler_to_callback[id] = callback

        if to_disconnect ~= nil then input_disconnect_cursor_moved(to_disconnect) end
        return id
    end

    input_disconnect_cursor_moved = function(id)
        if id == nil then return end
        log_typecheck(id, Number_t)
        _cursor_moved_handler_to_callback[id] = nil
    end

    input_emit_cursor_moved = function(x, y)
        log_typecheck(x, Number_t, y, Number_t)
        if _is_active ~= true then return end

        local ids = {}
        for id in pairs(_cursor_moved_handler_to_callback) do
            table_push(ids, id)
        end
        table_sort(ids)

        for _, id in ipairs(ids) do
            local callback = _cursor_moved_handler_to_callback[id]
            if callback ~= nil then
                local result = log_call(callback, x, y)
                if result == input_should_disconnect then
                    _cursor_moved_handler_to_callback[id] = nil
                end
            end
        end
    end

    love.mousemoved = function(x, y, dx, dy, istouch)
        if istouch then return end
        if not love.window.hasMouseFocus() then return end

        _cursor_position_x = x
        _cursor_position_y = y
        if STATE ~= nil then
            input_emit_cursor_moved(upscaler_from_window_position(STATE.upscaler, x, y))
        end
    end
end

local _axis_deadzone = 0.25
local _axis_state = {}

local _emit_pressed = function(binding, input_method)
    local actions = _binding_to_input_action[input_method][binding]
    if actions ~= nil then
        for _, action in ipairs(actions) do
            input_emit_pressed(action)
        end
    end
end

local _emit_released = function(binding, input_method)
    local actions = _binding_to_input_action[input_method][binding]
    if actions ~= nil then
        for _, action in ipairs(actions) do
            input_emit_released(action)
        end
    end
end

love.keypressed = function(key, scancode, isrepeat)
    _input_method = InputMethod.KEYBOARD
    _emit_pressed(scancode, InputMethod.KEYBOARD)
end

love.keyreleased = function(key, scancode)
    _input_method = InputMethod.KEYBOARD
    _emit_released(scancode, InputMethod.KEYBOARD)
end

love.gamepadpressed = function(joystick, button)
    _input_method = InputMethod.GAMEPAD
    _emit_pressed(button, InputMethod.GAMEPAD)
end

love.gamepadreleased = function(joystick, button)
    _input_method = InputMethod.GAMEPAD
    _emit_released(button, InputMethod.GAMEPAD)
end

love.mousepressed = function(x, y, button, istouch, presses)
    if istouch then return end
    if button == 1 then
        input_emit_pressed(input_action_click, x, y)
    end
end

love.mousereleased = function(x, y, button, istouch, presses)
    if istouch then return end
    if button == 1 then
        input_emit_released(input_action_click, x, y)
    end
end

love.touchpressed = function(id, x, y, dx, dy, pressure)
    input_emit_pressed(input_action_click, x, y)
end

love.touchreleased = function(id, x, y, dx, dy, pressure)
    input_emit_released(input_action_click, x, y)
end

