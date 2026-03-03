rt.settings.settings.player_input_smoothing = {
    time_to_accelerate = 9 / 60,
    time_to_decelerate = 1 / 60,

    joystick_time_to_accelerate = 3 / 60,
    joystick_time_to_decelerate = 1 / 60
}

--- @class rt.PlayerInputSmoothing
rt.PlayerInputSmoothing = meta.class("PlayerInputSmoothing")

--- @brief
function rt.PlayerInputSmoothing:instantiate()
    self._input = rt.InputSubscriber()

    self._sprint_down, self._jump_down = false

    self._joystick_x, self._joystick_y = 0, 0
    self._input:signal_connect("left_joystick_moved", function(_, x, y)
        self._joystick_x, self._joystick_y = x, y
    end)

    self._dpad_x, self._dpad_y = 0, 0
    self._input:signal_connect("controller_button_pressed", function(_, which)
        if which == rt.ControllerButton.DPAD_LEFT then
            self._dpad_x = self._dpad_x - 1
        elseif which == rt.ControllerButton.DPAD_RIGHT then
            self._dpad_x = self._dpad_x + 1
        elseif which == rt.ControllerButton.DPAD_UP then
            self._dpad_y = self._dpad_y - 1
        elseif which == rt.ControllerButton.DPAD_DOWN then
            self._dpad_y = self._dpad_y + 1
        end
    end)

    self._input:signal_connect("controller_button_released", function(_, which)
        if which == rt.ControllerButton.DPAD_LEFT then
            self._dpad_x = self._dpad_x + 1
        elseif which == rt.ControllerButton.DPAD_RIGHT then
            self._dpad_x = self._dpad_x - 1
        elseif which == rt.ControllerButton.DPAD_UP then
            self._dpad_y = self._dpad_y + 1
        elseif which == rt.ControllerButton.DPAD_DOWN then
            self._dpad_y = self._dpad_y - 1
        end
    end)

    self._digital_x, self._digital_y = 0, 0
    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputAction.LEFT then
            self._digital_x = self._digital_x - 1
        elseif which == rt.InputAction.RIGHT then
            self._digital_x = self._digital_x + 1
        elseif which == rt.InputAction.UP then
            self._digital_y = self._digital_y - 1
        elseif which == rt.InputAction.DOWN then
            self._digital_y = self._digital_y + 1
        elseif which == rt.InputAction.SPRINT then
            self._sprint_down = true
        elseif which == rt.InputAction.JUMP then
            self._jump_down = true
        end
    end)

    self._input:signal_connect("released", function(_, which)
        if which == rt.InputAction.LEFT then
            self._digital_x = self._digital_x + 1
        elseif which == rt.InputAction.RIGHT then
            self._digital_x = self._digital_x - 1
        elseif which == rt.InputAction.UP then
            self._digital_y = self._digital_y + 1
        elseif which == rt.InputAction.DOWN then
            self._digital_y = self._digital_y - 1
        elseif which == rt.InputAction.SPRINT then
            self._sprint_down = false
        elseif which == rt.InputAction.JUMP then
            self._jump_down = false
        end
    end)

    self._body_x, self._body_y = 0, 0
    self._body_velocity_x, self._body_velocity_y = 0, 0
end

--- @brief
function rt.PlayerInputSmoothing:update(delta)
    local target_x, target_y

    local joystick_used = false
    if rt.InputManager:get_input_method() == rt.InputMethod.CONTROLLER then
        if math.magnitude(self._dpad_x, self._dpad_y) > math.eps then
            target_x, target_y = self._dpad_x, self._dpad_y
        else
            target_x, target_y = self._joystick_x, self._joystick_y
            joystick_used = true
        end
    else
        target_x, target_y = self._digital_x, self._digital_y
    end

    local target_magnitude = math.magnitude(target_x, target_y)
    if target_magnitude > 1 then
        target_x, target_y = math.normalize(target_x, target_y)
    end

    local settings = rt.settings.settings.player_input_smoothing
    local is_moving_toward_origin = math.magnitude(target_x, target_y) < math.magnitude(self._body_x, self._body_y)

    local time_parameter
    if not joystick_used then
        time_parameter = ternary(is_moving_toward_origin,
            settings.time_to_decelerate,
            settings.time_to_accelerate
        )
    else
        time_parameter = ternary(is_moving_toward_origin,
            settings.joystick_time_to_decelerate,
            settings.joystick_time_to_accelerate
        )
    end

    local omega = 4 / time_parameter
    local spring_constant = omega * omega
    local damping_coefficient = 2 * omega

    local acceleration_x = spring_constant * (target_x - self._body_x) - damping_coefficient * self._body_velocity_x
    local acceleration_y = spring_constant * (target_y - self._body_y) - damping_coefficient * self._body_velocity_y

    self._body_velocity_x = self._body_velocity_x + acceleration_x * delta
    self._body_velocity_y = self._body_velocity_y + acceleration_y * delta

    local next_body_x = self._body_x + self._body_velocity_x * delta
    local next_body_y = self._body_y + self._body_velocity_y * delta

    local crosses_target_x = (self._body_x - target_x) * (next_body_x - target_x) < 0
    local crosses_target_y = (self._body_y - target_y) * (next_body_y - target_y) < 0

    if crosses_target_x then
        next_body_x = target_x
        self._body_velocity_x = 0
    end
    if crosses_target_y then
        next_body_y = target_y
        self._body_velocity_y = 0
    end

    self._body_x = next_body_x
    self._body_y = next_body_y

    if math.abs(self._body_x) > 1 then
        self._body_x = math.sign(self._body_x)
    end

    if math.abs(self._body_y) > 1 then
        self._body_y = math.sign(self._body_y)
    end
end

--- @brief
function rt.PlayerInputSmoothing:get_magnitude()
    return self._body_x, self._body_y
end

function rt.PlayerInputSmoothing:draw(center_x, center_y, radius)
    love.graphics.setLineWidth(0.75 * math.max(2, 1 / 10 * radius))

    local body_screen_x = center_x + self._body_x * radius
    local body_screen_y = center_y + self._body_y * radius

    local target_x, target_y

    local joystick_used = false
    if rt.InputManager:get_input_method() == rt.InputMethod.CONTROLLER then
        if math.magnitude(self._dpad_x, self._dpad_y) > math.eps then
            target_x, target_y = self._dpad_x, self._dpad_y
        else
            target_x, target_y = self._joystick_x, self._joystick_y
            joystick_used = true
        end
    else
        target_x, target_y = self._digital_x, self._digital_y
    end

    target_x, target_y = math.normalize(target_x, target_y)

    local inner_radius = math.max(0.1 * radius, rt.settings.margin_unit)

    local has_target = math.magnitude(target_x, target_y) > math.eps
    local target_screen_x, target_screen_y, direction_angle

    if has_target then
        target_screen_x = center_x + target_x * radius
        target_screen_y = center_y + target_y * radius
        direction_angle = math.atan2(target_y, target_x)
    else
        target_screen_x = center_x
        target_screen_y = center_y
        direction_angle = 0
    end

    love.graphics.setColor(1, 1, 1, 0.25)
    if has_target then
        local gap_angular_width = math.asin((inner_radius + 3) / radius) * 2
        love.graphics.arc("line", "open", center_x, center_y, radius,
            direction_angle + gap_angular_width / 2,
            direction_angle + 2 * math.pi - gap_angular_width / 2)
    else
        love.graphics.circle("line", center_x, center_y, radius)
    end

    if has_target then
        local offset = math.pi
        love.graphics.arc("line", "open", target_screen_x, target_screen_y, inner_radius + 3,
            direction_angle + math.pi / 2 - offset, direction_angle + 3 * math.pi / 2 - offset)
    else
        local x, y, r = center_x, center_y, inner_radius
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.circle("fill", x, y, r)
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.circle("line", x, y, r)
    end

    if math.magnitude(target_x, target_y) > math.eps then
        local x, y, r = body_screen_x, body_screen_y, inner_radius
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.circle("fill", x, y, r)
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.circle("line", x, y, r)
    end

    local small_radius = 10
    local spacing = rt.settings.margin_unit
    local offset_x = radius + small_radius
    local offset_y = radius - small_radius

    do
        local x, y, r = center_x + offset_x, center_y + offset_y, small_radius
        if self._sprint_down then
            love.graphics.setColor(1, 1, 1, 0.25)
            love.graphics.circle("fill", x, y, r)
            love.graphics.setColor(1, 1, 1, 0.25)
            love.graphics.circle("line", x, y, r)
        else
            love.graphics.setColor(1, 1, 1, 0.25)
            love.graphics.circle("line", x, y, r)
        end
    end

    do
        local x, y, r = center_x + offset_x + small_radius * 2 + 0.5 * spacing + love.graphics.getLineWidth(), center_y + offset_y, small_radius
        if self._jump_down then
            love.graphics.setColor(1, 1, 1, 0.25)
            love.graphics.circle("fill", x, y, r)
            love.graphics.setColor(1, 1, 1, 0.25)
            love.graphics.circle("line", x, y, r)
        else
            love.graphics.setColor(1, 1, 1, 0.25)
            love.graphics.circle("line", x, y, r)
        end
    end
end