require "common.input_subscriber"
require "physics.physics"


rt.settings.overworld.player = {
    radius = 13.5,
    inner_body_radius = 8 / 2 - 0.5,
    n_outer_bodies = 31,
    max_spring_length = 13.5 * 1.5,

    bottom_wall_ray_length_factor = 1.5,
    side_wall_ray_length_factor = 1.05,
    corner_wall_ray_length_factor = 0.8,
    top_wall_ray_length_factor = 1,
    joystick_to_analog_eps = 0.35,

    player_collision_group = b2.CollisionGroup.GROUP_16,
    player_outer_body_collision_group = b2.CollisionGroup.GROUP_15,

    target_velocity_x = 300,
    sprint_multiplier = 2,
    ground_acceleration_duration = 0.15, -- seconds
    ground_deceleration_duration = 0.05,

    air_acceleration_duration = 0.1, -- seconds
    air_deceleration_duration = 0.1,

    coyote_time = 8 / 60,

    jump_duration = 10 / 60,
    jump_velocity = 400,

    wall_jump_velocity = 1000,
    wall_jump_angle = 35, -- degrees
    wall_jump_freeze_duration = 10 / 60,
    wall_magnet_force = 300,

    gravity = 1500, -- px / s
    downwards_force_factor = 2, -- times gravity
    ground_regular_friction = 0,
    ground_slippery_friction = -1000,
    wall_regular_friction = 0.8, -- times of gravity
    wall_slippery_friction = 0,

    max_velocity_x = 8000, -- TODO
    max_velocity_y = 13000,
    squeeze_multiplier = 1.4,

    debug_drawing_enabled = false,
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

        -- geometry detection
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

        _bottom_left_wall = false,
        _bottom_left_wall_body = nil,
        _bottom_left_ray = {0, 0, 0, 0},

        _bottom_right_wall = false,
        _bottom_right_wall_body = nil,
        _bottom_right_ray = {0, 0, 0, 0},

        -- jump
        _jump_elapsed = 0,
        _coyote_elapsed = 0,

        _wall_jump_freeze_elapsed = math.huge,
        _wall_jump_freeze_sign = 0,
        _wall_jump_left_blocked = false,
        _wall_jump_right_blocked = false,
        _wall_jump_button_locked = false,

        _bounce_impulse_x = 0,
        _bounce_impulse_y = 0,
        _should_apply_bounce_impulse = false,

        -- controls
        _joystick_position = 0, -- x axis
        _use_controller_input = rt.InputManager:get_input_method() == rt.InputMethod.CONTROLLER,

        _left_button_is_down = false,
        _right_button_is_down = false,
        _down_button_is_down = false,
        _up_button_is_down = false,
        _jump_button_is_down = false,
        _sprint_button_is_down = false,

        _sprint_multiplier = 1,
        _next_sprint_multiplier = 1,
        _next_sprint_multiplier_update_when_grounded = false,

        _interact_targets = {}, -- Set
        _is_disabled = false,

        -- soft body
        _spring_bodies = {},
        _spring_joints = {},

        _outer_body_mesh = nil,
        _outer_body_mesh_origin_x = 0,
        _outer_body_mesh_origin_y = 0,
        _outer_body_center_mesh = nil,
        _outer_body_centers_x = {},
        _outer_body_centers_y = {},
        _outer_body_angles = {},
        _outer_body_scales = {},

        _outer_body_tris = {},

        -- hard body
        _body = nil,
        _world = nil,

        _mass = 1,
        _bounce_sensor = nil, -- b2.Body
        _bounce_sensor_pin = nil, -- b2.Pin
        _input = rt.InputSubscriber()
    })

    self:_connect_input()

    if self._stage ~= nil then
        self:move_to_stage(self._stage)
    end
end


local _JUMP_BUTTONS = {
    [rt.InputButton.B] = true
}

local _SPRINT_BUTTON = {
    [rt.InputButton.Y] = true,
    [rt.InputButton.L] = true,
    [rt.InputButton.R] = true
}

local _INTERACT_BUTTON = {
    [rt.InputButton.A] = true
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
function ow.Player:get_is_interact_button(which)
    return _INTERACT_BUTTON[which] == true
end

--- @brief
function ow.Player:_connect_input()
    self._input:signal_connect("pressed", function(_, which)
        if self:get_is_jump_button(which) then
            self._jump_button_is_down = true
            self._jump_elapsed = 0 -- jump
            self:signal_emit("jump")
        elseif self:get_is_sprint_button(which) then
            self._sprint_button_is_down = true
            self._next_sprint_multiplier = _settings.sprint_multiplier
            self._next_sprint_multiplier_update_when_grounded = true
        elseif self:get_is_interact_button(which) then
            -- interact
            for target in keys(self._interact_targets) do
                target:signal_emit("activate", self)
            end
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
            self._wall_jump_button_locked = false
        elseif self:get_is_sprint_button(which) then
            self._sprint_button_is_down = false
            self._next_sprint_multiplier = 1
            self._next_sprint_multiplier_update_when_grounded = true
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

    self._input:signal_connect("input_method_changed", function(_, which)
        self._use_controller_input = which == rt.InputMethod.CONTROLLER
    end)

    self._input:signal_connect("left_joystick_moved", function(_, x, y)
        self._joystick_position = x

        -- convert joystick inputs to digital
        local eps = _settings.joystick_to_analog_eps
        self._up_button_is_down = y < -eps
        self._down_button_is_down = y > eps
        self._right_button_is_down = x > eps
        self._left_button_is_down = x < -eps
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
    local bottom_left_ray_length = self._radius * _settings.corner_wall_ray_length_factor
    local bottom_right_ray_length = bottom_left_ray_length

    local top_dx, top_dy = 0, -top_ray_length
    local right_dx, right_dy = right_ray_length, 0
    local bottom_dx, bottom_dy = 0, bottom_ray_length
    local left_dx, left_dy = -left_ray_length, 0
    local bottom_left_dx, bottom_left_dy = -bottom_left_ray_length, bottom_left_ray_length
    local bottom_right_dx, bottom_right_dy = bottom_right_ray_length, bottom_right_ray_length

    local top_x, top_y, top_nx, top_ny, top_wall_body = self._world:query_ray_any(x, y, top_dx, top_dy, mask)
    local right_x, right_y, right_nx, right_ny, right_wall_body = self._world:query_ray(x, y, right_dx, right_dy, mask)
    local bottom_x, bottom_y, bottom_nx, bottom_ny, bottom_wall_body = self._world:query_ray(x, y, bottom_dx, bottom_dy, mask)
    local left_x, left_y, left_nx, left_ny, left_wall_body = self._world:query_ray(x, y, left_dx, left_dy, mask)
    local bottom_left_x, bottom_left_y, bottom_left_nx, bottom_left_ny, bottom_left_wall_body = self._world:query_ray(x, y, bottom_left_dx, bottom_left_dy, mask)
    local bottom_right_x, bottom_right_y, bottom_right_nx, bottom_right_ny, bottom_right_wall_body = self._world:query_ray(x, y, bottom_right_dx, bottom_right_dy, mask)

    local left_before = self._left_wall
    local right_before = self._right_wall
    local bottom_before = self._bottom_wall
    local bottom_left_before = self._bottom_left_wall
    local bottom_right_before = self._bottom_right_wall

    self._left_wall = left_wall_body ~= nil and not left_wall_body:get_is_sensor()
    self._left_wall_body = left_wall_body
    self._left_ray = {x, y, x + left_dx, y + left_dy}

    self._right_wall = right_wall_body ~= nil and not right_wall_body:get_is_sensor()
    self._right_wall_body = right_wall_body
    self._right_ray = {x, y, x + right_dx, y + right_dy}

    self._top_wall = top_wall_body ~= nil and not top_wall_body:get_is_sensor()
    self._top_wall_body = top_wall_body
    self._top_ray = {x, y, x + top_dx, y + top_dy}

    self._bottom_wall = bottom_wall_body ~= nil and not bottom_wall_body:get_is_sensor()
    self._bottom_wall_body = bottom_wall_body
    self._bottom_ray = {x, y, x + bottom_dx, y + bottom_dy}

    self._bottom_left_wall = bottom_left_wall_body ~= nil and not bottom_left_wall_body:get_is_sensor()
    self._bottom_left_wall_body = bottom_left_wall_body
    self._bottom_left_ray = {x, y, x + bottom_left_dx, y + bottom_left_dy}

    self._bottom_right_wall = bottom_right_wall_body ~= nil and not bottom_right_wall_body:get_is_sensor()
    self._bottom_right_wall_body = bottom_right_wall_body
    self._bottom_right_ray = {x, y, x + bottom_right_dx, y + bottom_right_dy}

    -- update sprint once landed
    if self._next_sprint_multiplier_update_when_grounded and (self._bottom_wall or self._bottom_left_wall or self._bottom_right_wall) then
        self._sprint_multiplier = self._next_sprint_multiplier
    end

    -- update velocity
    local next_velocity_x, next_velocity_y
    do
        -- do not allow for directional input after walljump
        self._wall_jump_freeze_elapsed = self._wall_jump_freeze_elapsed + delta
        local frozen = self._wall_jump_freeze_elapsed < _settings.wall_jump_freeze_duration

        -- horizontal movement
        local magnitude
        if self._left_button_is_down and not self._right_button_is_down then
            magnitude = -1
        elseif self._right_button_is_down and not self._left_button_is_down then
            magnitude = 1
        else
            magnitude = 0
        end

        if self._use_controller_input then
            magnitude = self._joystick_position -- analog control when using joystick overrides digital
        end

        local target_velocity_x = magnitude * _settings.target_velocity_x * self._sprint_multiplier
        if frozen and math.sign(target_velocity_x) ~= 0 and math.sign(target_velocity_x) == self._wall_jump_freeze_sign then
            target_velocity_x = 0
        end

        local current_velocity_x, current_velocity_y = self._body:get_velocity()

        local duration
        if (math.sign(target_velocity_x) == math.sign(current_velocity_x) and math.abs(target_velocity_x) > math.abs(current_velocity_x)) then
            duration = self._bottom_wall and _settings.ground_acceleration_duration or _settings.air_deceleration_duration
        else
            duration = self._bottom_wall and _settings.ground_deceleration_duration or _settings.air_deceleration_duration
        end

        if duration == 0 then
            next_velocity_x = target_velocity_x
        else
            local velocity_change = (target_velocity_x - current_velocity_x) / duration
            next_velocity_x = current_velocity_x + velocity_change * delta
        end

        if self._bottom_wall then -- ground friction
            local friction_coefficient = _settings.ground_regular_friction
            if bottom_wall_body:has_tag("slippery") then
                friction_coefficient = _settings.ground_slippery_friction
            end

            local friction_force = friction_coefficient * math.sign(current_velocity_x)
            next_velocity_x = next_velocity_x - friction_force * delta
        else
            -- magnetize to walls
            if not frozen then
                local magnet_force = _settings.wall_magnet_force
                if self._left_wall and not self._right_wall and self._left_button_is_down then
                    next_velocity_x = next_velocity_x - magnet_force * math.distance(x, y, left_x, left_y) / (self._radius * _settings.side_wall_ray_length_factor)
                elseif self._right_wall and not self._left_wall and self._right_button_is_down then
                    next_velocity_x = next_velocity_x + magnet_force * math.distance(x, y, right_x, right_y) / (self._radius * _settings.side_wall_ray_length_factor)
                end
            end
        end

        -- vertical movement
        next_velocity_y = current_velocity_y

        if left_before == true and self._left_wall == false then self._left_wall_jump_blocked = false end
        if right_before == true and self._right_wall == false then self._right_wall_jump_blocked = false end

        local can_jump = (self._bottom_wall or self._bottom_left_wall or self._bottom_right_wall) and not (self._left_wall or self._right_wall or self._top_wall)
        local can_wall_jump = not can_jump and not frozen and not self._wall_jump_button_locked and ((self._left_wall and not self._left_wall_jump_blocked) or (self._right_wall and not self._right_wall_jump_blocked))

        if (self._bottom_wall and bottom_wall_body:has_tag("unjumpable")) or
            (self._bottom_left_wall and bottom_left_wall_body:has_tag("unjumpable")) or
            (self._bottom_right_wall and bottom_right_wall_body:has_tag("unjumpable"))
        then
            can_jump = false
        end

        if (self._left_wall and left_wall_body:has_tag("slippery")) or
            (self._right_wall and right_wall_body:has_tag("slippery"))
        then
            can_wall_jump = false
        end

        -- reset jump button when going from air to ground, to disallow buffering jumps while falling
        local grounded_before = bottom_before -- only use bottom, not corner
        local grounded_now = self._bottom_wall
        if grounded_before == false and grounded_now == true then
            self._jump_button_is_down = false
        end

        -- override jump logic
        if self._jump_allowed_override ~= nil then
            if self._jump_allowed_override == true then
                can_jump = true
            else
                can_jump = false
            end
        end

        if can_jump then
            self._coyote_elapsed = 0
        else
            if self._coyote_elapsed < _settings.coyote_time then
                can_jump = true
            end
            self._coyote_elapsed = self._coyote_elapsed + delta
        end

        if self._jump_button_is_down then
            if can_jump and self._jump_elapsed < _settings.jump_duration then
                -- regular jump
                next_velocity_y = -1 * _settings.jump_velocity * math.sqrt(self._jump_elapsed / _settings.jump_duration)
                self._jump_elapsed = self._jump_elapsed + delta
                self._wall_jump_button_locked = true
            elseif can_wall_jump then

                local dx, dy = math.rotate(0, -1, -math.rad(_settings.wall_jump_angle))
                if self._left_wall then dx = -1 * dx end

                local force = _settings.wall_jump_velocity
                next_velocity_x, next_velocity_y = dx * force, dy * force
                self._wall_jump_freeze_elapsed = 0
                self._wall_jump_freeze_sign = -1 * math.sign(dx)
                self._wall_jump_button_locked = true

                if self._left_wall then
                    self._left_wall_jump_blocked = true
                elseif self._right_wall then
                    self._right_wall_jump_blocked = true
                end
            end
        end

        if self._jump_elapsed >= _settings.jump_duration then
            self._jump_allowed_override = nil
        end

        local wall_cling = (self._left_wall and self._left_button_is_down) or (self._right_wall and self._right_button_is_down)

        -- apply friction when wall_clinging
        local _apply_wall_friction = function(coefficient, tx, ty)
            local friction_force = coefficient * _settings.gravity * delta * math.sign(current_velocity_y)
            next_velocity_y = next_velocity_y - friction_force
        end

        if wall_cling and self._left_wall then _apply_wall_friction(
            left_wall_body:has_tag("slippery") and _settings.wall_slippery_friction or _settings.wall_regular_friction,
            math.turn_left(left_nx, left_ny)
        ) end

        if wall_cling and self._right_wall then _apply_wall_friction(
            right_wall_body:has_tag("slippery") and _settings.wall_slippery_friction or _settings.wall_regular_friction,
            math.turn_right(right_nx, right_ny)
        ) end

        -- gravity and downwards force
        if not frozen and self._down_button_is_down then
            local factor = _settings.downwards_force_factor
            if self._bottom_wall then factor = factor * 4 end
            next_velocity_y = next_velocity_y + factor * _settings.gravity * delta
        end
        next_velocity_y = next_velocity_y + _settings.gravity * delta

        -- add force when squeezing through gaps
        if (self._top_wall and self._bottom_wall) then
            next_velocity_x = next_velocity_x * _settings.squeeze_multiplier
        end

        if (self._left_wall and self._right_wall) then
            next_velocity_y = next_velocity_y * _settings.squeeze_multiplier
        end

        -- bounce
        if self._should_apply_bounce_impulse then
            next_velocity_x = self._bounce_impulse_x
            next_velocity_y = self._bounce_impulse_y
            --self._should_apply_bounce_impulse = false
        end

        next_velocity_x = math.clamp(next_velocity_x, -_settings.max_velocity_x, _settings.max_velocity_x)
        next_velocity_y = math.clamp(next_velocity_y, -_settings.max_velocity_y, _settings.max_velocity_y)

        -- apply to body
        if self._is_disabled then
            self._body:set_velocity(0, current_velocity_y + _settings.gravity * delta)
        else
            self._body:set_velocity(next_velocity_x, next_velocity_y)
        end
    end

    -- safeguard against one of the springs catching
    local disabled = false
    for i, body in ipairs(self._spring_bodies) do
        local distance = math.distance(x, y, body:get_position())
        --body:set_is_sensor(distance > _settings.max_spring_length)
        local should_be_disabled = distance > _settings.max_spring_length--self._spring_joints[i]._prismatic_joint:getJointSpeed() > 100
        body:set_is_sensor(should_be_disabled)
        if should_be_disabled == true then disabled = true end
    end

    if disabled then
        self._body:set_velocity(0, 0)
    end

    -- update mesh
    local player_x, player_y = self._body:get_position()
    local to_polygonize = {}
    for i, body in ipairs(self._spring_bodies) do
        local cx, cy = body:get_position()
        self._outer_body_centers_x[i] = cx
        self._outer_body_centers_y[i] = cy
        local dx, dy = cx - player_x, cy - player_y
        self._outer_body_angles[i] = math.angle(dx, dy) + math.pi

        local scale = 1 + self._spring_joints[i]:get_distance() / (self._radius - self._outer_body_radius)
        self._outer_body_scales[i] = math.max(scale / 2, 0)

        table.insert(to_polygonize, cx)
        table.insert(to_polygonize, cy)
    end

    do
        -- triangulate body for see-through part
        -- try love, if fails, try slick (because slick is slower), if it fails, do not change body
        local success, new_tris
        success, new_tris = pcall(love.math.triangulate, to_polygonize)
        if not success then
            success, new_tris = pcall(slick.triangulate, {to_polygonize})
        end

        if success then
            self._outer_body_tris = new_tris
        end
    end

    -- add blood splatter
    local function _add_blood_splatter(contact_x, contact_y, nx, ny)
        local nx_top, ny_top = math.turn_left(nx, ny)
        local nx_bottom, ny_bottom = math.turn_right(nx, ny)

        local r = math.sqrt(math.abs(select(1, self._body:get_velocity()))) / 2
        local top_x, top_y = contact_x + nx_top * r, contact_y + ny_top * r
        local bottom_x, bottom_y = contact_x + nx_bottom * r, contact_y + ny_bottom * r

        self._stage:add_blood_splatter(top_x, top_y, bottom_x, bottom_y)
    end

    if self._top_wall then
        _add_blood_splatter(top_x, top_y, top_nx, top_ny)
    end

    if self._right_wall then
        _add_blood_splatter(right_x, right_y, right_nx, right_ny)
    end

    if self._bottom_wall then
        _add_blood_splatter(bottom_x, bottom_y, bottom_nx, bottom_ny)
    end

    if self._left_wall then
        _add_blood_splatter(left_x, left_y, left_nx, left_ny)
    end
end

--- @brief
function ow.Player:move_to_stage(stage, x, y)
    meta.assert(stage, "Stage", x, "Number", y, "Number")
    local world = stage:get_physics_world()
    if world == self._world then return end

    self._stage = stage
    self._world = world

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
    self._body:set_friction(0)
    self._body:set_use_manual_velocity(true)

    -- soft body
    local outer_radius = self._radius - self._outer_body_radius
    local outer_body_shape = b2.Circle(0, 0, self._outer_body_radius)
    local step = (2 * math.pi) / _settings.n_outer_bodies

    local mask = bit.bnot(_settings.player_outer_body_collision_group)

    for angle = 0, 2 * math.pi, step do
        local cx = x + math.cos(angle) * outer_radius
        local cy = y + math.sin(angle) * outer_radius

        local body = b2.Body(self._world, b2.BodyType.DYNAMIC, cx, cy, outer_body_shape)
        body:set_mass(10e-4)
        body:set_collision_group(_settings.player_outer_body_collision_group)
        body:set_collides_with(mask)
        body:set_friction(0)
        body:set_is_rotation_fixed(false)
        body:set_use_continuous_collision(true)
        body:set_user_data(self)
        body:add_tag("player_outer_body")

        local joint = b2.Spring(self._body, body, x, y, cx, cy)

        table.insert(self._spring_bodies, body)
        table.insert(self._spring_joints, joint)
    end

    -- bounce sensor
    self._bounce_sensor = b2.Body(self._world, b2.BodyType.DYNAMIC, x, y, b2.Circle(0, 0, 1.5 * self._radius))
    self._bounce_sensor:set_mass(10e-4)
    self._bounce_sensor:set_collides_with(b2.CollisionGroup.GROUP_14)
    self._bounce_sensor_pin = b2.Pin(self._body, self._bounce_sensor, x, y)

    self._bounce_sensor:signal_connect("collision_start", function(_, other, normal_x, normal_y, contact)

    end)

    self._bounce_sensor:signal_connect("collision_end", function(_, other)
        --self._should_apply_bounce_impulse = false
    end)

    -- true mass
    self._mass = self._body:get_mass() + self._bounce_sensor:get_mass()
    for body in values(self._spring_bodies) do
        self._mass = self._mass + body:get_mass()
    end

    -- two tone colors for gradients
    local ar, ag, ab = 1, 1, 1
    local br, bg, bb = 0.3, 0.3, 0.3

    if self._outer_body_mesh == nil then
        local n_outer_vertices = 32

        -- generate vertices for outer body mesh
        local radius = self._radius
        local x_radius = radius / 2

        local n_bodies = rt.settings.overworld.player.n_outer_bodies
        local circumference = 2 * math.pi * radius
        local y_radius = (circumference / n_bodies)

        local small_radius = self._outer_body_radius
        local cx, cy = 0, 0
        local vertices = {
            {cx, cy}
        }

        local m = 4
        local n = 0
        local step = 2 * math.pi / n_outer_vertices
        for angle = 0, 2 * math.pi + step, step do
            local x = cx + math.cos(angle) * x_radius
            local y = cy + (math.sin(angle) * math.sin(0.5 * angle)^m) * y_radius
            table.insert(vertices, {x, y})
            n = n + 1
        end

        -- generate mesh data
        local data = {}
        local indices = {}
        for i = 1, n do
            local x, y = vertices[i][1], vertices[i][2]

            local r, g, b, a
            if i == 1 then
                r, g, b, a = ar, ag, ab, 1
            else
                r, g, b, a = br, bg, bb, 1
            end

            table.insert(data, {x, y,  0, 0,  r, g, b, a})

            if i < n then
                for index in range(i, i + 1, 1) do
                    table.insert(indices, index)
                end
            end
        end

        for index in range(n, 1, 2) do
            table.insert(indices, index)
        end

        self._outer_body_mesh = rt.Mesh(data, rt.MeshDrawMode.TRIANGLES)
        self._outer_body_mesh:set_vertex_map(indices)
        self._outer_body_mesh_origin_x, self._outer_body_mesh_origin_y = -x_radius, 0 -- top of left bulb

        self._outer_body_center_mesh = rt.MeshCircle(0, 0, _settings.inner_body_radius)
        for i = 1, self._outer_body_center_mesh:get_n_vertices() do
            if i == 1 then
                self._outer_body_center_mesh:set_vertex_color(i, ar, ag, ab, 1)
            else
                self._outer_body_center_mesh:set_vertex_color(i, br, bg, bb, 1)
            end
        end
    end

    self._outer_body_centers_x = {}
    self._outer_body_centers_y = {}
    self._outer_body_scales = {}
    self._outer_body_angles = {}

end

--- @brief
function ow.Player:draw()
    -- draw mesh
    love.graphics.push()

    local x, y = self._body:get_predicted_position()
    love.graphics.translate(x, y)
    love.graphics.rotate(self._body:get_rotation())
    love.graphics.translate(-x, -y)

    local r, g, b, a = rt.Palette.MINT_2:unpack()

    love.graphics.setColor(r, g, b, 0.3)
    for tri in values(self._outer_body_tris) do
        love.graphics.polygon("fill", tri)
    end

    love.graphics.setColor(r, g, b, 1)
    for i, scale in ipairs(self._outer_body_scales) do
        local x = self._outer_body_centers_x[i]
        local y = self._outer_body_centers_y[i]

        local origin_x = self._outer_body_mesh_origin_x
        local origin_y = self._outer_body_mesh_origin_y

        local angle = self._outer_body_angles[i]
        love.graphics.draw(self._outer_body_mesh:get_native(),
            x, y,
            angle, -- rotation
            scale, 1, -- scale
            origin_x, origin_y -- origin
        )
    end

    love.graphics.draw(self._outer_body_center_mesh:get_native(), self._body:get_position())

    love.graphics.pop()

    if _settings.debug_drawing_enabled then
        self._body:draw()
        for body in values(self._spring_bodies) do
            --body:draw()
        end

        love.graphics.setLineWidth(1)

        for wall_ray in range(
            { self._top_wall, self._top_ray },
            { self._right_wall, self._right_ray },
            { self._bottom_wall, self._bottom_ray },
            { self._left_wall, self._left_ray },
            { self._bottom_left_wall, self._bottom_left_ray },
            { self._bottom_right_wall, self._bottom_right_ray }
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
    return self._body:get_velocity()
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
    self._jump_elapsed = 0
end

--- @brief
function ow.Player:get_physics_body()
    return self._body
end

--- @brief
function ow.Player:add_interact_target(target)
    self._interact_targets[target] = true
end

--- @brief
function ow.Player:remove_interact_target(target)
    self._interact_targets[target] = false
end

--- @brief
function ow.Player:set_is_disabled(b)
    self._is_disabled = b
end

--- @brief
function ow.Player:get_is_disabled()
    return self._is_disabled
end




