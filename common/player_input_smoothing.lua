do
    local radius = 40
    rt.settings.player_input_smoothing = {
        time_to_accelerate = 9 / 60,
        time_to_decelerate = 1 / 60,

        joystick_time_to_accelerate = 3 / 60,
        joystick_time_to_decelerate = 1 / 60,

        small_radius = radius / 4,
        radius = radius,
        line_width = radius / 12,

        n_sub_steps = 2,
        n_particles = 128,
        distance_compliance = 0.0,
        collision_compliance = 0.0,
        bending_compliance = 0.01,
        home_compliance = 0.004,

        small_distance_compliance = 0.005,
        small_home_compliance = 0.002
    }
end


--- @class rt.PlayerInputSmoothing
rt.PlayerInputSmoothing = meta.class("PlayerInputSmoothing")

local _x_offset = 0
local _y_offset = 1
local _previous_x_offset = 2
local _previous_y_offset = 3
local _velocity_x_offset = 4
local _velocity_y_offset = 5
local _mass_offset = 6
local _inverse_mass_offset = 7
local _home_x_offset = 8
local _home_y_offset = 9
local _distance_lambda_offset = 10
local _bending_lambda_offset = 11
local _home_lambda_offset = 12
local _collision_lambda_offset = 13

local _stride = _collision_lambda_offset + 1
local _particle_i_to_data_offset = function(particle_i)
    return (particle_i - 1) * _stride + 1 -- 1-based
end

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
            --self:_stretch_band(self._sprint_band)
        elseif which == rt.InputAction.JUMP then
            self._jump_down = true
            --self:_stretch_band(self._jump_band)
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
    self._body_radius = rt.settings.player_input_smoothing.small_radius

    -- initialize rubber band sim
    local new_band = function(radius, n_particles, distance_compliance, bending_compliance, home_compliance, collision_compliance)
        local data, draw_data = {}, {}
        local center_x, center_y = 0, 0
        for particle_i = 1, n_particles + 1 do
            local i = #data + 1

            local angle = (particle_i - 1) / n_particles * 2 * math.pi
            local x = center_x + math.cos(angle) * radius
            local y = center_y + math.sin(angle) * radius
            data[i + _x_offset] = x
            data[i + _y_offset] = y
            data[i + _previous_x_offset] = x
            data[i + _previous_y_offset] = y
            data[i + _velocity_x_offset] = 0
            data[i + _velocity_y_offset] = 0
            data[i + _mass_offset] = 1
            data[i + _inverse_mass_offset] = 1 / data[i + _mass_offset]
            data[i + _home_x_offset] = x
            data[i + _home_y_offset] = y
            data[i + _distance_lambda_offset] = 0
            data[i + _collision_lambda_offset] = 0
            data[i + _bending_lambda_offset] = 0
            data[i + _home_lambda_offset] = 0

            assert(data[i + _home_x_offset])
            assert(data[i + _home_y_offset])

            table.insert(draw_data, x)
            table.insert(draw_data, y)
        end
        
        return {
            n_particles = n_particles,
            radius = radius,
            data = data,
            draw_data = draw_data,
            distance_compliance = distance_compliance or 0,
            apply_distance = not meta.is_nil(distance_compliance),

            bending_compliance = bending_compliance,
            apply_bending = not meta.is_nil(bending_compliance) or 0,

            home_compliance = home_compliance or 0,
            apply_home = not meta.is_nil(home_compliance),

            collision_compliance = collision_compliance or 0,
            apply_collision = not meta.is_nil(collision_compliance)
        }
    end

    local settings = rt.settings.player_input_smoothing
    local radius = settings.radius
    local small_radius = rt.settings.player_input_smoothing.small_radius

    local n_particles = rt.settings.player_input_smoothing.n_particles
    local small_n_particles = n_particles --ath.ceil(n_particles * (small_radius / radius))

    self._control_band = new_band(
        settings.radius,
        settings.n_particles,
        settings.distance_compliance,
        settings.bending_compliance,
        settings.home_compliance,
        settings.collision_compliance
    )

    self._jump_band = new_band(
        settings.small_radius,
        settings.n_particles,
        settings.small_distance_compliance,
        settings.bending_compliance,
        settings.small_home_compliance,
        nil
    )

    self._sprint_band = new_band(
        settings.small_radius,
        settings.n_particles,
        settings.small_distance_compliance,
        settings.bending_compliance,
        settings.small_home_compliance,
        nil
    )
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

    local settings = rt.settings.player_input_smoothing
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

    self:_update_band(self._control_band, delta, true) -- apply collision
    --self:_update_band(self._jump_band, delta, false)
    --self:_update_band(self._sprint_band, delta, false)
end

do
    local function _pre_solve(
        position_x, position_y,
        velocity_x, velocity_y,
        mass,
        damping, delta
    )
        velocity_x = velocity_x * damping
        velocity_y = velocity_y * damping

        return
        position_x + velocity_x * delta,
        position_y + velocity_y * delta,
        velocity_x, velocity_y,
        position_x, position_y
    end

    local function _enforce_distance(
        anchor_x, anchor_y,
        target_x, target_y,
        inverse_mass_anchor, inverse_mass_target,
        rest_distance,
        alpha,
        lambda
    )
        local distance = math.distance(anchor_x, anchor_y, target_x, target_y)
        if distance < math.eps then
            return 0, 0, 0, 0, lambda
        end

        local normal_x, normal_y = math.normalize(target_x - anchor_x, target_y - anchor_y)
        local delta_lambda = -(distance - rest_distance + alpha * lambda) / (inverse_mass_anchor + inverse_mass_target + alpha)
        lambda = lambda + delta_lambda

        return
        inverse_mass_anchor * delta_lambda * -normal_x,
        inverse_mass_anchor * delta_lambda * -normal_y,
        inverse_mass_target * delta_lambda *  normal_x,
        inverse_mass_target * delta_lambda *  normal_y,
        lambda
    end

    local function _enforce_collision(
        anchor_x, anchor_y, anchor_radius, inverse_mass_anchor,
        obstacle_x, obstacle_y, obstacle_radius,
        alpha,
        lambda
    )
        local distance = math.distance(anchor_x, anchor_y, obstacle_x, obstacle_y)
        local separation = anchor_radius + obstacle_radius - distance
        lambda = lambda or 0

        if separation <= 0 and lambda >= 0 then
            return 0, 0, 0
        end

        local normal_x, normal_y = math.normalize(obstacle_x - anchor_x, obstacle_y - anchor_y)

        local delta_lambda = -(separation + alpha * lambda) / (inverse_mass_anchor + alpha)
        lambda = lambda + delta_lambda

        if lambda > 0 then
            delta_lambda = -lambda + delta_lambda
            lambda = 0
        end

        return
        inverse_mass_anchor * delta_lambda * normal_x,
        inverse_mass_anchor * delta_lambda * normal_y,
        lambda
    end

    local function _enforce_bending(
        start_x, start_y,
        mid_x, mid_y,
        end_x, end_y,
        inverse_mass_start, inverse_mass_mid, inverse_mass_end,
        rest_offset,
        alpha, lambda
    )
        local span_length = math.distance(start_x, start_y, end_x, end_y)
        if span_length < math.eps then
            return 0, 0, 0, 0, 0, 0, lambda
        end

        local tangent_x, tangent_y = (end_x - start_x) / span_length, (end_y - start_y) / span_length
        local normal_x, normal_y = -tangent_y, tangent_x

        local constraint = math.dot(0.5 * (start_x + end_x) - mid_x, 0.5 * (start_y + end_y) - mid_y, normal_x, normal_y) - rest_offset
        local delta_lambda = -(constraint + alpha * lambda) / (0.25 * inverse_mass_start + inverse_mass_mid + 0.25 * inverse_mass_end + alpha)
        lambda = lambda + delta_lambda

        return
        inverse_mass_start * delta_lambda *  0.5 * normal_x,
        inverse_mass_start * delta_lambda *  0.5 * normal_y,
        inverse_mass_mid   * delta_lambda * -1.0 * normal_x,
        inverse_mass_mid   * delta_lambda * -1.0 * normal_y,
        inverse_mass_end   * delta_lambda *  0.5 * normal_x,
        inverse_mass_end   * delta_lambda *  0.5 * normal_y,
        lambda
    end

    local function _enforce_rest_position(
        position_x, position_y,
        rest_x, rest_y,
        inverse_mass,
        alpha,
        lambda
    )
        local displacement = math.distance(position_x, position_y, rest_x, rest_y)
        if displacement < math.eps then
            return 0, 0, lambda
        end

        local delta_lambda = -(displacement + alpha * lambda) / (inverse_mass + alpha)
        lambda = lambda + delta_lambda

        return
            inverse_mass * delta_lambda * (position_x - rest_x) / displacement,
            inverse_mass * delta_lambda * (position_y - rest_y) / displacement,
            lambda
    end

    local function _post_solve(
        position_x, position_y,
        previous_x, previous_y,
        delta
    )
        local velocity_x = (position_x - previous_x) / delta
        local velocity_y = (position_y - previous_y) / delta

        return velocity_x, velocity_y
    end

    function rt.PlayerInputSmoothing:_update_band(band, delta, enforce_collision)
        require "overworld.tether"
        local tether_settings = rt.settings.overworld.tether
        local body_settings = rt.settings.player_body.non_contour
        local smoothing_settings = rt.settings.player_input_smoothing

        local damping = tether_settings.damping or body_settings.damping
        local n_sub_steps = tether_settings.n_sub_steps or body_settings.n_sub_steps
        local n_constraint_iterations = tether_settings.n_constraint_iterations or body_settings.n_constraint_iterations
        local sub_delta = delta / n_sub_steps

        local distance_alpha = band.distance_compliance / (sub_delta^2)
        local collision_alpha = band.collision_compliance / (sub_delta^2)
        local bending_alpha = band.bending_compliance / (sub_delta^2)
        local home_alpha = band.home_compliance / (sub_delta^2)

        local collider_x, collider_y = self._body_x, self._body_y
        collider_x = 0 + collider_x * smoothing_settings.radius
        collider_y = 0 + collider_y * smoothing_settings.radius

        local collider_radius = smoothing_settings.small_radius
        local collider_inverse_mass = 1

        local segment_length = (2 * math.pi * band.radius) / band.n_particles
        local node_radius = smoothing_settings.line_width
        local rest_offset = segment_length * math.cos(math.pi / band.n_particles) / (2 * math.sin(math.pi / band.n_particles))

        local data = band.data
        for _ = 1, n_sub_steps do
            for particle_index = 1, band.n_particles do
                local offset = _particle_i_to_data_offset(particle_index)
                local position_x, position_y,
                velocity_x, velocity_y,
                previous_x, previous_y = _pre_solve(
                    data[offset + _x_offset],
                    data[offset + _y_offset],
                    data[offset + _velocity_x_offset],
                    data[offset + _velocity_y_offset],
                    data[offset + _mass_offset],
                    damping, sub_delta
                )
                data[offset + _x_offset] = position_x
                data[offset + _y_offset] = position_y
                data[offset + _velocity_x_offset] = velocity_x
                data[offset + _velocity_y_offset] = velocity_y
                data[offset + _previous_x_offset] = previous_x
                data[offset + _previous_y_offset] = previous_y
                data[offset + _distance_lambda_offset] = 0
                data[offset + _collision_lambda_offset] = 0
                data[offset + _bending_lambda_offset] = 0
                data[offset + _home_lambda_offset] = 0
            end

            for _ = 1, n_constraint_iterations do
                if band.apply_distance ~= false then
                    for particle_index = 1, band.n_particles do
                        local offset_a = _particle_i_to_data_offset(particle_index)
                        local offset_b = _particle_i_to_data_offset(particle_index % band.n_particles + 1)

                        local anchor_x, anchor_y = data[offset_a + _x_offset], data[offset_a + _y_offset]
                        local target_x, target_y = data[offset_b + _x_offset], data[offset_b + _y_offset]

                        local correction_anchor_x, correction_anchor_y,
                        correction_target_x, correction_target_y,
                        distance_lambda = _enforce_distance(
                            anchor_x, anchor_y,
                            target_x, target_y,
                            data[offset_a + _inverse_mass_offset],
                            data[offset_b + _inverse_mass_offset],
                            segment_length,
                            distance_alpha,
                            data[offset_a + _distance_lambda_offset]
                        )

                        data[offset_a + _x_offset] = anchor_x + correction_anchor_x
                        data[offset_a + _y_offset] = anchor_y + correction_anchor_y
                        data[offset_b + _x_offset] = target_x + correction_target_x
                        data[offset_b + _y_offset] = target_y + correction_target_y
                        data[offset_a + _distance_lambda_offset] = distance_lambda
                    end
                end

                if band.apply_bending ~= false then
                    for particle_index = 1, band.n_particles do
                        local offset_start = _particle_i_to_data_offset((particle_index - 2) % band.n_particles + 1)
                        local offset_mid = _particle_i_to_data_offset(particle_index)
                        local offset_end = _particle_i_to_data_offset(particle_index % band.n_particles + 1)

                        local start_x, start_y = data[offset_start + _x_offset], data[offset_start + _y_offset]
                        local mid_x, mid_y = data[offset_mid + _x_offset], data[offset_mid + _y_offset]
                        local end_x, end_y = data[offset_end + _x_offset], data[offset_end + _y_offset]

                        local correction_start_x, correction_start_y,
                        correction_mid_x,   correction_mid_y,
                        correction_end_x,   correction_end_y,
                        bending_lambda = _enforce_bending(
                            start_x, start_y,
                            mid_x, mid_y,
                            end_x, end_y,
                            data[offset_start + _inverse_mass_offset],
                            data[offset_mid + _inverse_mass_offset],
                            data[offset_end + _inverse_mass_offset],
                            -rest_offset,
                            bending_alpha,
                            data[offset_mid + _bending_lambda_offset]
                        )

                        data[offset_start + _x_offset] = start_x + correction_start_x
                        data[offset_start + _y_offset] = start_y + correction_start_y
                        data[offset_mid + _x_offset] = mid_x + correction_mid_x
                        data[offset_mid + _y_offset] = mid_y + correction_mid_y
                        data[offset_end + _x_offset] = end_x + correction_end_x
                        data[offset_end + _y_offset] = end_y + correction_end_y
                        data[offset_mid + _bending_lambda_offset] = bending_lambda
                    end
                end

                if band.apply_home ~= false then
                    for particle_index = 1, band.n_particles do
                        local offset = _particle_i_to_data_offset(particle_index)
                        local position_x, position_y = data[offset + _x_offset], data[offset + _y_offset]

                        local correction_x, correction_y, home_lambda = _enforce_rest_position(
                            position_x, position_y,
                            data[offset + _home_x_offset],
                            data[offset + _home_y_offset],
                            data[offset + _inverse_mass_offset],
                            home_alpha,
                            data[offset + _home_lambda_offset]
                        )

                        data[offset + _x_offset] = position_x + correction_x
                        data[offset + _y_offset] = position_y + correction_y
                        data[offset + _home_lambda_offset] = home_lambda
                    end
                end

                if band.apply_collision ~= false then
                    for particle_index = 1, band.n_particles do
                        local offset = _particle_i_to_data_offset(particle_index)
                        local position_x, position_y = data[offset + _x_offset], data[offset + _y_offset]

                        local correction_x, correction_y, collision_lambda = _enforce_collision(
                            position_x, position_y, node_radius, data[offset + _inverse_mass_offset],
                            collider_x, collider_y, collider_radius,
                            collision_alpha,
                            data[offset + _collision_lambda_offset]
                        )

                        data[offset + _x_offset] = position_x + correction_x
                        data[offset + _y_offset] = position_y + correction_y
                        data[offset + _collision_lambda_offset] = collision_lambda
                    end
                end
            end

            for particle_index = 1, band.n_particles do
                local offset = _particle_i_to_data_offset(particle_index)
                data[offset + _velocity_x_offset], data[offset + _velocity_y_offset] = _post_solve(
                    data[offset + _x_offset],
                    data[offset + _y_offset],
                    data[offset + _previous_x_offset],
                    data[offset + _previous_y_offset],
                    sub_delta
                )
            end
        end

        local draw_i = 1
        for particle_i = 1, band.n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            band.draw_data[draw_i] = data[i + _x_offset]
            band.draw_data[draw_i + 1] = data[i + _y_offset]
            draw_i = draw_i + 2
        end

        band.draw_data[draw_i] = band.draw_data[1]
        band.draw_data[draw_i + 1] = band.draw_data[2]
    end

    function rt.PlayerInputSmoothing:_stretch_band(band)
        local data = band.data
        local stretch_amount = 5
        for particle_i = 1, band.n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local nx, ny = math.normalize(data[i + _home_x_offset], data[i + _home_y_offset])
            local new_x = nx * (band.radius + stretch_amount)
            local new_y = ny * (band.radius + stretch_amount)

            data[i + _x_offset] = new_x
            data[i + _y_offset] = new_y
            data[i + _previous_x_offset] = new_x
            data[i + _previous_y_offset] = new_y
            data[i + _velocity_x_offset] = -nx * data[i + _velocity_x_offset]
            data[i + _velocity_y_offset] = -ny * data[i + _velocity_y_offset]
            data[i + _distance_lambda_offset] = 0
            data[i + _collision_lambda_offset] = 0
            data[i + _home_lambda_offset] = 0
        end
    end
end

--- @brief
function rt.PlayerInputSmoothing:get_magnitude()
    return self._body_x, self._body_y
end

function rt.PlayerInputSmoothing:draw(center_x, center_y)

    local draw_band = function(band, x, y)
        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.line(band.draw_data)
        love.graphics.pop()
    end

    local radius = rt.settings.player_input_smoothing.radius
    local small_radius = rt.settings.player_input_smoothing.small_radius
    local line_width = rt.settings.player_input_smoothing.line_width

    love.graphics.push("all")

    local margin = math.max((small_radius + line_width) / 2, 2 * rt.settings.margin_unit)

    love.graphics.setLineWidth(line_width)
    love.graphics.setLineStyle("rough")
    love.graphics.setColor(1, 1, 1, 0.5)

    if self._small_outline == nil or self._small_outline_radius ~= small_radius then
        local vertices = {}
        local n_vertices = 32
        for i = 1, n_vertices + 1 do
            local angle = (i - 1) / n_vertices * 2 * math.pi
            table.insert(vertices, 0 + math.cos(angle) * small_radius)
            table.insert(vertices, 0 + math.sin(angle) * small_radius)
        end
        self._small_outline = vertices
        self._small_outline_radius = small_radius
    end

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

    love.graphics.push()
    love.graphics.translate(center_x, center_y)
    love.graphics.line(self._control_band.draw_data)
    love.graphics.pop()

    love.graphics.circle("fill", body_screen_x, body_screen_y, small_radius)

    love.graphics.push()
    love.graphics.translate(body_screen_x, body_screen_y)
    love.graphics.line(self._small_outline)
    love.graphics.pop()

    local offset_x = radius + small_radius
    local offset_y = radius - small_radius

    do
        love.graphics.push()
        love.graphics.translate(center_x + offset_x, center_y + offset_y)
        if self._sprint_down then
            love.graphics.circle("fill", 0, 0, small_radius)
        end
        love.graphics.line(self._sprint_band.draw_data)
        love.graphics.pop()
    end

    do
        love.graphics.push()
        love.graphics.translate(center_x + offset_x + 2 * small_radius + line_width + rt.settings.margin_unit / 2,
            center_y + offset_y)
        if self._jump_down then
            love.graphics.circle("fill", 0, 0, small_radius)
        end
        love.graphics.line(self._sprint_band.draw_data)
        love.graphics.pop()
    end

    love.graphics.pop()
end