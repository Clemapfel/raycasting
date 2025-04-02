require "common.input_subscriber"
require "physics.physics"


rt.settings.overworld.player = {
    radius = 13.5,
    inner_body_radius = 8 / 2 - 0.5,
    n_outer_bodies = 31,
    max_spring_length = 13.5 * 1.5,

    restitution = 0.2,
    friction = 0,

    max_velocity_x = 200,
    max_velocity_y = 3 * 200,
    sprint_multiplier = 2.3,
    air_deceleration_duration = 0.8, -- n seconds until 0
    ground_deceleration_duration = 0.1,
    coyote_time = 6 / 60,
    gravity = 1500,

    bottom_wall_ray_length_factor = 1.5,
    side_wall_ray_length_factor = 1,
    top_wall_ray_length_factor = 1,

    jump_total_force = 1400,
    jump_duration = 13 / 60,

    downwards_force = 10e3,

    joystick_to_analog_eps = 0.1,

    player_collision_group = b2.CollisionGroup.GROUP_16,
    player_outer_body_collision_group = b2.CollisionGroup.GROUP_15,

    debug_drawing_enabled = true
}

local _settings = rt.settings.overworld.player

--- @class ow.Player
ow.Player = meta.class("OverworldPlayer")
meta.add_signals(ow.Player,
    "jump"
)

--- @brief
function ow.Player:instantiate(scene, stage)
    local player_radius = _settings.radius
    meta.install(self, {
        _scene = scene,
        _stage = stage,

        _radius = player_radius,
        _inner_body_radius = _settings.inner_body_radius,
        _outer_body_radius = (player_radius * 2 * math.pi) / _settings.n_outer_bodies / 2,

        _left_wall = false,
        _left_wall_body = nil,
        _left_ray = {0, 0, 0, 0},

        _right_wall = false,
        _right_wall_body = nil,
        _right_ray = {0, 0, 0, 0},

        _top_wall = false,
        _top_wall_body = nil,
        _top_ray = {0, 0, 0, 0},

        _bottom_wall = false,
        _bottom_wall_body = nil,
        _bottom_ray = {0, 0, 0, 0},

        _velocity_sign = 0, -- left or right
        _velocity_magnitude = 0,
        _velocity_multiplier = 1,

        _acceleration_timer = 0,

        _next_velocity_multiplier = 1,
        _next_velocity_mutiplier_apply_when_grounded = false,

        _last_known_grounded_y = 0,
        _is_midair_timer = 0,

        _jump_button_down = false,
        _jump_elapsed = 0,
        _jump_allowed_override = false,
        _jump_direction_x = 0,
        _jump_direction_y = 1,

        _joystick_position = 0, -- x axis

        _left_button_is_down = false,
        _right_button_is_down = false,
        _down_button_is_down = false,
        _up_button_is_down = false,
        _jump_button_is_down = false,

        -- soft body
        _spring_bodies = {},
        _spring_joints = {},

        -- hard body
        _body = nil,
        _world = nil,

        _input = rt.InputSubscriber()
    })

    self:_connect_input()

    if self._stage ~= nil then
        self:move_to_stage(self._stage)
    end
end


local _JUMP_BUTTONS = {
    [rt.InputButton.A] = true
}

local _SPRINT_BUTTON = {
    [rt.InputButton.B] = true,
    [rt.InputButton.L] = true,
    [rt.InputButton.R] = true
}

--- @brief
function ow.Player:get_is_jump_button(which)
    return _JUMP_BUTTONS[which] == true
end

--- @brief
function ow.Player:get_is_sprint_button(which)
    return _SPRINT_BUTTON[which] == true
end

--- @brief
function ow.Player:_get_is_midair()
    if self._body == nil then return false end
    local current_y = select(2, self._body:get_position())
    if current_y >= self._last_known_grounded_y and self._is_midair_timer < _settings.coyote_time then
        return false
        -- coyote time, player can jump midair when running of a cliff
    else
        return not self._bottom_wall
    end
end

--- @brief
function ow.Player:_get_can_jump()
    if self._jump_allowed_override then
        self._jump_allowed_override = false
        return true -- midair jump
    end

    if self._bottom_wall == false and (self._left_wall == true or self._right_wall == true) then
        if (self._left_wall and self._left_wall_body:has_tag("slippery")) or
            (self._right_wall and self._right_wall_body:has_tag("slippery"))
        then
            return false -- prevent walljump for slippery
        end

        return true -- wall jump
    else
        return not self:_get_is_midair() -- grounded jump
    end
end

--- @brief
function ow.Player:_connect_input()
    self._input:signal_connect("pressed", function(_, which)
        if self:get_is_jump_button(which) then
            -- jump
            if self:_get_can_jump() then
                self._jump_button_is_down = true
                self._jump_elapsed = 0 -- reset jump timer
                self:signal_emit("jump")
            end

        elseif self:get_is_sprint_button(which) then
            -- queue sprint once grounded
            self._next_velocity_multiplier = _settings.sprint_multiplier
            self._next_velocity_mutiplier_apply_when_grounded = true

        elseif which == rt.InputButton.LEFT then
            self._left_button_is_down = true

        elseif which == rt.InputButton.RIGHT then
            self._right_button_is_down = true

        elseif which == rt.InputButton.DOWN then
            self._down_button_is_down = true

        elseif which == rt.InputButton.UP then
            self._up_button_is_down = true
        end
    end)

    self._input:signal_connect("released", function(_, which)
        if self:get_is_jump_button(which) then
            self._jump_button_is_down = false

        elseif self:get_is_sprint_button(which) then
            -- reset sprint once grounded
            self._next_velocity_multiplier = 1
            self._next_velocity_multiplier_apply_when_grounded = true

        elseif which == rt.InputButton.LEFT then
            self._left_button_is_down = false

        elseif which == rt.InputButton.RIGHT then
            self._right_button_is_down = false

        elseif which == rt.InputButton.DOWN then
            self._down_button_is_down = false

        elseif which == rt.InputButton.UP then
            self._up_button_is_down = false
        end
    end)

    self._input:signal_connect("left_joystick_moved", function(_, x, y)
        self._joystick_position = x

        -- convert joystick inputs to digital
        local eps = _settings.joystick_to_analog_eps
        self._up_button_is_down = math.abs(x) < eps and y < 0.5
        self._down_button_is_down = math.abs(x) < eps and y > 0.5
        self._right_button_is_down = math.abs(y) < eps and x > 0.5
        self._left_button_is_down = math.abs(y) < eps and x < -0.5
    end)
end

--- @brief
function ow.Player:update(delta)
    local midair_before = not self._bottom_wall

    -- raycast to check for walls
    local x, y = self._body:get_position()
    local mask = bit.bnot(_settings.player_outer_body_collision_group)

    local top_ray_length = self._radius * _settings.top_wall_ray_length_factor
    local right_ray_length = self._radius * _settings.side_wall_ray_length_factor
    local left_ray_length = right_ray_length
    local bottom_ray_length = self._radius * _settings.bottom_wall_ray_length_factor

    local top_dx, top_dy = 0, -top_ray_length
    local right_dx, right_dy = right_ray_length, 0
    local bottom_dx, bottom_dy = 0, bottom_ray_length
    local left_dx, left_dy = -left_ray_length, 0

    local top_x, top_y, top_nx, top_ny, top_wall_body = self._world:query_ray_any(x, y, top_dx, top_dy, mask)
    local right_x, right_y, right_nx, right_ny, right_wall_body = self._world:query_ray(x, y, right_dx, right_dy, mask)
    local bottom_x, bottom_y, bottom_nx, bottom_ny, bottom_wall_body = self._world:query_ray_any(x, y, bottom_dx, bottom_dy, mask)
    local left_x, left_y, left_nx, left_ny, left_wall_body = self._world:query_ray(x, y, left_dx, left_dy, mask)

    self._left_wall = left_wall_body ~= nil
    self._left_wall_body = left_wall_body
    self._left_ray = {x, y, x + left_dx, y + left_dy}

    self._right_wall = right_wall_body ~= nil
    self._right_wall_body = right_wall_body
    self._right_ray = {x, y, x + right_dx, y + right_dy}

    self._top_wall = top_wall_body ~= nil
    self._top_wall_body = top_wall_body
    self._top_ray = {x, y, x + top_dx, y + top_dy}

    self._bottom_wall = bottom_wall_body ~= nil
    self._bottom_wall_body = bottom_wall_body
    self._bottom_ray = {x, y, x + bottom_dx, y + bottom_dy}

    -- update velocity
    if self._joystick_position ~= 0 then
        self._velocity_sign = math.sign(self._joystick_position)
        self._velocity_magnitude = math.abs(self._joystick_position)
    elseif self._left_button_is_down or self._right_button_is_down then
        if self._left_button_is_down and not self._right_button_is_down then
            self._velocity_sign = -1
            self._velocity_magnitude = 1
        elseif self._right_button_is_down and not self._left_button_is_down then
            self._velocity_sign = 1
            self._velocity_magnitude = 1
        end
    else
        -- decelerate
        local deceleration
        if self:_get_is_midair() then
            deceleration = _settings.air_deceleration_duration
        else
            deceleration = _settings.ground_deceleration_duration
        end

        self._velocity_magnitude = self._velocity_magnitude - (1 / math.max(deceleration, 10e-4)) * delta
        if self._velocity_magnitude < 0 then self._velocity_magnitude = 0 end
    end

    -- update multiplier
    if not self:_get_is_midair() and self._next_velocity_mutiplier_apply_when_grounded then
        self._velocity_multiplier = self._next_velocity_multiplier
        self._next_velocity_mutiplier_apply_when_grounded = false
    end

    local current_velocity_x, current_velocity_y = self._body:get_linear_velocity()
    local next_velocity_x = self._velocity_sign * self._velocity_magnitude * self._velocity_multiplier * _settings.max_velocity_x

    self._body:set_velocity(
        next_velocity_x,
        math.clamp(current_velocity_y, - _settings.max_velocity_y, _settings.max_velocity_y)
    )

    -- apply jump force
    if self._jump_button_is_down then
        self._jump_elapsed = self._jump_elapsed + delta
        local impulse = (_settings.jump_total_force * delta) / _settings.jump_duration
        local fraction = math.min(self._jump_elapsed / _settings.jump_duration, 1)
        local magnitude = -1 * impulse * (1 - fraction)
        self._body:apply_linear_impulse(self._jump_direction_x * magnitude, self._jump_direction_y * magnitude)
    end

    -- apply downwards force
    if self._down_button_is_down then
        local midair = self:_get_is_midair()
        local standing_still = not self:_get_is_midair() and self._velocity_magnitude == 0
        if midair or standing_still then
            self._body:apply_force(0, _settings.downwards_force)
        end
    end

    -- update last grounded position
    local midair_now = not self._bottom_wall
    if midair_before == true and midair_before == false then
        self._last_known_grounded_y = y
    end

    if midair_before == false and midair_now == true then
        self._is_midair_timer = 0
    end

    if midair_now then
        self._is_midair_timer = self._is_midair_timer + delta
    end

    -- safeguard against one of the springs catching
    for i, body in ipairs(self._spring_bodies) do
        local distance = math.distance(x, y, body:get_position())
        body:set_is_sensor(distance >= _settings.max_spring_length)
    end
end

--- @brief
function ow.Player:move_to_stage(stage, x, y)
    meta.assert(stage, "Stage", x, "Number", y, "Number")
    local world = stage:get_physics_world()
    if world == self._world then return end

    self._world = world
    self._world:set_gravity(0, _settings.gravity)

    -- hard body
    self._body = b2.Body(
        self._world, b2.BodyType.DYNAMIC, x, y,
        b2.Circle(0, 0, self._inner_body_radius)
    )

    self._body:set_user_data(self)
    self._body:set_use_continuous_collision(true)
    self._body:add_tag("player")
    self._body:set_is_rotation_fixed(true)
    self._body:set_collision_group(_settings.player_collision_group)
    self._body:set_mass(1)
    self._body:set_restitution(_settings.restitution)
    self._body:set_friction(0)

    -- soft body
    local outer_radius = self._radius - self._outer_body_radius
    local outer_body_shape = b2.Circle(0, 0, self._outer_body_radius)
    local step = (2 * math.pi) / _settings.n_outer_bodies

    local mask = bit.bnot(_settings.player_outer_body_collision_group)

    for angle = 0, 2 * math.pi - step, step do
        local cx = x + math.cos(angle) * outer_radius
        local cy = y + math.sin(angle) * outer_radius

        local body = b2.Body(self._world, b2.BodyType.DYNAMIC, cx, cy, outer_body_shape)
        body:set_mass(10e-4)
        body:set_collision_group(_settings.player_outer_body_collision_group)
        body:set_collides_with(mask)
        body:set_restitution(_settings.restitution)
        body:set_friction(_settings.friction)
        body:set_use_continuous_collision(true)

        local joint = b2.Spring(self._body, body, x, y, cx, cy)

        table.insert(self._spring_bodies, body)
        table.insert(self._spring_joints, joint)
    end

    -- TODO: soft body graphics
end

--- @brief
function ow.Player:draw()
    if _settings.debug_drawing_enabled then
        self._body:draw()
        for body in values(self._spring_bodies) do
            body:draw()
        end

        love.graphics.setLineWidth(1)

        for wall_ray in range(
            { self._top_wall, self._top_ray },
            { self._right_wall, self._right_ray },
            { self._bottom_wall, self._bottom_ray },
            { self._left_wall, self._left_ray }
        ) do
            local wall, ray = table.unpack(wall_ray)
            if wall then rt.Palette.GREEN:bind() else rt.Palette.RED:bind() end
            love.graphics.line(ray)
        end
    end
end

--- @brief
function ow.Player:get_position()
    return self._body:get_position()
end

--- @brief
function ow.Player:get_velocity()
    local _, vy = self._body:get_velocity()
    return self._velocity_sign * self._velocity_magnitude * self._velocity_multiplier, vy
end

--- @brief
function ow.Player:teleport_to(x, y)
    if self._body ~= nil then
        self._body:set_position(x, y)

        for body in values(self._spring_bodies) do
            body:set_position(x, y) -- springs will correct to normal after one step
        end
    end
end

--- @brief
function ow.Player:get_radius()
    return self._radius
end

--- @brief
function ow.Player:set_jump_allowed(b)
    self._jump_allowed_override = b
end





