input_should_disconnect = 0x0

input_action_accept = "accept"
input_action_back = "back"
input_action_jump = "jump"
input_action_move_left = "left"
input_action_move_right = "right"
input_action_move_up = "up"
input_action_move_down = "down"
input_action_pause = "pause"
input_action_debug = "debug"

local _input_actions = {
    input_action_accept,
    input_action_back,
    input_action_jump,
    input_action_move_left,
    input_action_move_right,
    input_action_move_up,
    input_action_move_down,
    input_action_pause,
    input_action_debug
}

do
    local _is_input_action = {}
    for _, action in pairs(_input_actions) do _is_input_action[action] = true end

    input_is_input_action = function(x)
        return _is_input_action[x] == true
    end
end

do
    local _pressed_handler_id = 0
    local _handler_id_to_callback = {}

    input_connect_pressed = function(callback)
        log_typecheck(callback, Function_t)

        local id = _pressed_handler_id
        _pressed_handler_id = _pressed_handler_id + 1
        _handler_id_to_callback[id] = callback
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

        -- snapshot ids to handle disconnect / connect during emission
        local ids = {}
        for id in pairs(_handler_id_to_callback) do
            table_push(ids, id)
        end
        table_sort(ids)

        for _, id in ipairs(ids) do
            local callback = _handler_id_to_callback[id]
            if callback ~= nil then
                local res = log_call(callback, action)
                if res == input_should_disconnect then
                    _handler_id_to_callback[id] = nil
                end
            end
        end
    end
end

do
    local _released_handler_id = 0
    local _handler_id_to_callback = {}

    input_connect_released = function(callback)
        log_typecheck(callback, Function_t)

        local id = _released_handler_id
        _released_handler_id = _released_handler_id + 1
        _handler_id_to_callback[id] = callback
        return id
    end

    input_disconnect_released = function(id)
        if id == nil then return end
        log_typecheck(id, Number_t)

        if _handler_id_to_callback[id] == nil then
            log_warning("In input_disconnect_released: no handler with id `", id , "`")
        end
        _handler_id_to_callback[id] = nil
    end

    input_emit_released = function(action)
        log_assert(input_is_input_action(action), "In input_emit_released: `", object_to_string(action), "` is not a valid input action")

        local ids = {}
        for id in pairs(_handler_id_to_callback) do
            table_push(ids, id)
        end
        table_sort(ids)

        for _, id in ipairs(ids) do
            local callback = _handler_id_to_callback[id]
            if callback ~= nil then
                local res = log_call(callback, action)
                if res == input_should_disconnect then
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

    input_connect_cursor_moved = function(callback)
        log_typecheck(callback, Function_t)

        local id = _cursor_moved_handler_id
        _cursor_moved_handler_id = _cursor_moved_handler_id + 1
        _cursor_moved_handler_to_callback[id] = callback
        return id
    end

    input_disconnect_cursor_moved = function(id)
        if id == nil then return end
        log_typecheck(id, Number_t)
        _cursor_moved_handler_to_callback[id] = nil
    end

    input_emit_cursor_moved = function(x, y)
        log_typecheck(x, Number_t, y, Number_t)

        local ids = {}
        for id in pairs(_cursor_moved_handler_to_callback) do
            table_push(ids, id)
        end
        table_sort(ids)

        for _, id in ipairs(ids) do
            local callback = _cursor_moved_handler_to_callback[id]
            if callback ~= nil then
                local res = log_call(callback, x, y)
                if res == input_should_disconnect then
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
        input_emit_cursor_moved(upscaler_from_window_position(x, y))
    end
end

-- ### callbacks ###

local _axis_deadzone = 0.25
local _axis_left = false
local _axis_right = false
local _axis_up = false
local _axis_down = false

love.keypressed = function(key, scancode, isrepeat)
    if isrepeat then return end

    if key == "space" or key == "m" or key == "return" or key == "kpenter" then
        input_emit_pressed(input_action_accept)
        input_emit_pressed(input_action_jump)
    end

    if key == "backspace" or key == "n" or key == "b" or key == "escape" then
        input_emit_pressed(input_action_back)
    end

    if key == "left" or key == "a" or key == "kp4" then
        input_emit_pressed(input_action_move_left)
    end

    if key == "right" or key == "d" or key == "kp6" then
        input_emit_pressed(input_action_move_right)
    end

    if key == "down" or key == "s" or key == "kp2" then
        input_emit_pressed(input_action_move_down)
    end

    if key == "up" or key == "w" or key == "kp8" then
        input_emit_pressed(input_action_move_up)
    end

    if key == "^" then
        input_emit_pressed(input_action_debug)
    end
end

love.keyreleased = function(key)
    if key == "space" or key == "m" or key == "return" or key == "kpenter" then
        input_emit_released(input_action_accept)
        input_emit_released(input_action_jump)
    end

    if key == "backspace" or key == "n" or key == "b" or key == "escape" then
        input_emit_released(input_action_back)
    end

    if key == "left" or key == "a" or key == "kp4" then
        input_emit_released(input_action_move_left)
    end

    if key == "right" or key == "d" or key == "kp6" then
        input_emit_released(input_action_move_right)
    end

    if key == "down" or key == "s" or key == "kp2" then
        input_emit_released(input_action_move_down)
    end

    if key == "up" or key == "w" or key == "kp8" then
        input_emit_released(input_action_move_up)
    end
end

love.mousepressed = function(x, y, button, istouch, presses)
    if istouch then return end

    if button == 1 then
        input_emit_pressed(input_action_accept)
    end
end

love.mousereleased = function(x, y, button, istouch, presses)
    if istouch then return end

    if button == 1 then
        input_emit_released(input_action_accept)
    end
end

love.touchpressed = function(id, x, y, dx, dy, pressure)
    input_emit_pressed(input_action_accept)
    input_emit_pressed(input_action_jump)
end

love.touchreleased = function(id, x, y, dx, dy, pressure)
    input_emit_released(input_action_accept)
    input_emit_released(input_action_jump)
end

love.gamepadpressed = function(joystick, button)
    if button == "b" or button == "start" then
        input_emit_pressed(input_action_accept)
        input_emit_pressed(input_action_jump)
    end

    if button == "a" or button == "back" then
        input_emit_pressed(input_action_back)
    end

    if button == "dpleft" then
        input_emit_pressed(input_action_move_left)
    end

    if button == "dpright" then
        input_emit_pressed(input_action_move_right)
    end

    if button == "dpdown" then
        input_emit_pressed(input_action_move_down)
    end

    if button == "dpup" then
        input_emit_pressed(input_action_move_up)
    end
end

love.gamepadreleased = function(joystick, button)
    if button == "b" or button == "start" then
        input_emit_released(input_action_accept)
        input_emit_released(input_action_jump)
    end

    if button == "a" or button == "back" then
        input_emit_released(input_action_back)
    end

    if button == "dpleft" then
        input_emit_released(input_action_move_left)
    end

    if button == "dpright" then
        input_emit_released(input_action_move_right)
    end

    if button == "dpdown" then
        input_emit_released(input_action_move_down)
    end

    if button == "dpup" then
        input_emit_released(input_action_move_up)
    end
end

love.gamepadaxis = function(joystick, axis, value)
    if axis == "leftx" then
        local left = value < -_axis_deadzone
        local right = value > _axis_deadzone

        if left ~= _axis_left then
            _axis_left = left
            if left then
                input_emit_pressed(input_action_move_left)
            else
                input_emit_released(input_action_move_left)
            end
        end

        if right ~= _axis_right then
            _axis_right = right
            if right then
                input_emit_pressed(input_action_move_right)
            else
                input_emit_released(input_action_move_right)
            end
        end
    end

    if axis == "lefty" then
        local up = value < -_axis_deadzone
        local down = value > _axis_deadzone

        if up ~= _axis_up then
            _axis_up = up
            if up then
                input_emit_pressed(input_action_move_up)
            else
                input_emit_released(input_action_move_up)
            end
        end

        if down ~= _axis_down then
            _axis_down = down
            if down then
                input_emit_pressed(input_action_move_down)
            else
                input_emit_released(input_action_move_down)
            end
        end
    end
end