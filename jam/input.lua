input_should_disconnect = 0x0

input_action_accept = "accept"
input_action_back = "back"
input_action_jump = "jump"
input_action_move_left = "left"
input_action_move_right = "right"
input_action_move_up = "up"
input_action_move_down = "down"
input_action_pause = "pause"

local _input_actions = {
    input_action_accept,
    input_action_back,
    input_action_jump,
    input_action_move_left,
    input_action_move_right,
    input_action_move_up,
    input_action_move_down,
    input_action_pause
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
    local _pressed_input_action_to_handler_to_callback = {}

    for _, action in ipairs(_input_actions) do
        _pressed_input_action_to_handler_to_callback[action] = {}
    end

    input_connect_pressed = function(action, callback)
        log_typecheck(action, String_t, callback, Function_t)
        log_assert(input_is_input_action(action), "In input_connect_pressed: `", object_to_string(action), "` is not a valid input action")

        local id = _pressed_handler_id
        _pressed_handler_id = _pressed_handler_id + 1
        _pressed_input_action_to_handler_to_callback[action][id] = callback
        return id
    end

    input_disconnect_pressed = function(id)
        log_typecheck(id, Number_t)

        local removed = false
        for _, handler_to_callback in pairs(_pressed_input_action_to_handler_to_callback) do
            if handler_to_callback[id] ~= nil then
                handler_to_callback[id] = nil
                removed = true
                break
            end
        end

        if not removed then
            log_warning("In input_disconnect_pressed: no handler with id `", id, "` connected")
        end
    end

    input_emit_pressed = function(action)
        log_assert(input_is_input_action(action), "In input_emit_pressed: `", object_to_string(action), "` is not a valid input action")

        local handler_to_callback = _pressed_input_action_to_handler_to_callback[action]

        -- snapshot ids to handle disconnect / connect during emission
        local ids = {}
        for id in pairs(handler_to_callback) do
            table.insert(ids, id)
        end
        table.sort(ids)

        for _, id in ipairs(ids) do
            local callback = handler_to_callback[id]
            if callback ~= nil then
                local res = log_call(callback, action)
                if res == input_should_disconnect then
                    handler_to_callback[id] = nil
                end
            end
        end
    end
end

do
    local _released_handler_id = 0
    local _released_input_action_to_handler_to_callback = {}

    for _, action in ipairs(_input_actions) do
        _released_input_action_to_handler_to_callback[action] = {}
    end

    input_connect_released = function(action, callback)
        log_typecheck(action, String_t, callback, Function_t)
        log_assert(input_is_input_action(action), "In input_connect_released: `", object_to_string(action), "` is not a valid input action")

        local id = _released_handler_id
        _released_handler_id = _released_handler_id + 1
        _released_input_action_to_handler_to_callback[action][id] = callback
        return id
    end

    input_disconnect_released = function(id)
        log_typecheck(id, Number_t)

        local removed = false
        for _, handler_to_callback in pairs(_released_input_action_to_handler_to_callback) do
            if handler_to_callback[id] ~= nil then
                handler_to_callback[id] = nil
                removed = true
                break
            end
        end

        if not removed then
            log_warning("In input_disconnect_released: no handler with id `", id, "` connected")
        end
    end

    input_emit_released = function(action)
        log_assert(input_is_input_action(action), "In input_emit_released: `", object_to_string(action), "` is not a valid input action")

        local handler_to_callback = _released_input_action_to_handler_to_callback[action]

        local ids = {}
        for id in pairs(handler_to_callback) do
            table.insert(ids, id)
        end
        table.sort(ids)

        for _, id in ipairs(ids) do
            local callback = handler_to_callback[id]
            if callback ~= nil then
                local res = log_call(callback, action)
                if res == input_should_disconnect then
                    handler_to_callback[id] = nil
                end
            end
        end
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
        input_emit_pressed(input_action_jump)
    end
end

love.mousereleased = function(x, y, button, istouch, presses)
    if istouch then return end

    if button == 1 then
        input_emit_released(input_action_accept)
        input_emit_released(input_action_jump)
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