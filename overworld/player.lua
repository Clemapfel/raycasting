require "common.input_subscriber"
require "physics.physics"
require "common.timed_animation"
require "common.random"

local radius = 13.5
rt.settings.overworld.player = {
    radius = radius,
    inner_body_radius = 8 / 2 - 0.5,
    n_outer_bodies = 23,
    max_spring_length = radius * 3,

    bottom_wall_ray_length_factor = 1.5,
    side_wall_ray_length_factor = 1.05,
    corner_wall_ray_length_factor = 0.8,
    top_wall_ray_length_factor = 1,
    joystick_to_analog_eps = 0.35,

    player_collision_group = b2.CollisionGroup.GROUP_16,
    player_outer_body_collision_group = b2.CollisionGroup.GROUP_15,

    ground_target_velocity_x = 280,
    air_target_velocity_x = 350,
    sprint_multiplier = 2,
    ground_acceleration_duration = 20 / 60, -- seconds
    ground_deceleration_duration = 5 / 60,

    air_acceleration_duration = 15 / 60, -- seconds
    air_deceleration_duration = 15 / 60,

    coyote_time = 3 / 60,

    jump_duration = 10 / 60,
    jump_velocity = 445,

    wall_magnet_force = 300,
    wall_jump_initial_impulse = 350,
    wall_jump_sustained_impulse = 830, -- force per second
    wall_jump_initial_angle = math.rad(18) - math.pi * 0.5,
    wall_jump_sustained_angle = math.rad(5) - math.pi * 0.5,
    non_sprint_walljump_duration_multiplier = 1.4,
    wall_jump_duration = 10 / 60,
    wall_jump_freeze_duration = 7 / 60,

    bounce_min_force = 50,
    bounce_max_force = 220,
    bounce_duration = 2 / 60,

    gravity = 1500, -- px / s
    air_resistance = 0.03, -- [0, 1]
    downwards_force_factor = 2, -- times gravity
    wall_regular_friction = 0.8, -- times of gravity
    wall_slippery_friction = 0,
    ground_regular_friction = 0,
    ground_slippery_friction = -0.2,

    max_velocity_x = 8000, -- TODO
    max_velocity_y = 13000,

    respawn_duration = 2,

    squeeze_multiplier = 1.4,
    ragdoll_trigger_jump_height = 7,
    ragdoll_friction = 8,

    kill_animation_initial_impulse = 100,

    --debug_drawing_enabled = true,
}

local _settings = setmetatable({}, {
    __index = function(self, key)
        local res = debugger.get(key)
        if res == nil then
            res = rt.settings.overworld.player[key]
        end
        return res
    end
})

--- @class ow.Player
ow.Player = meta.class("OverworldPlayer")
meta.add_signals(ow.Player,
    "jump"
)

ow.PlayerState = meta.enum("OverworldPlayerState", {
    ACTIVE = 1,
    DISABLED = 2
})

--- @brief
function ow.Player:instantiate(scene, stage)
    local player_radius = _settings.radius
    meta.install(self, {
        _scene = scene,
        _stage = stage,

        _state = ow.PlayerState.ACTIVE,

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

        _left_wall_elapsed = 0,
        _right_wall_elapsed = 0,

        -- jump
        _jump_elapsed = math.huge,
        _coyote_elapsed = 0,

        _wall_jump_elapsed = 0,
        _left_wall_jump_blocked = false,
        _right_wall_jump_blocked = false,
        _wall_jump_freeze_elapsed = math.huge,
        _wall_jump_freeze_sign = 0,

        _bounce_direction_x = 0,
        _bounce_direction_y = 0,
        _bounce_force = 0,
        _bounce_elapsed = math.huge,
        _bounce_locked = true,

        _last_velocity_x = 0,
        _last_velocity_y = 0,

        _velocity_multiplier_x = 1,
        _velocity_multiplier_y = 1,

        _is_ragdoll = false,
        _is_frozen = false,
        _respawn_elapsed = 0,

        -- controls
        _joystick_position = 0, -- x axis
        _use_controller_input = rt.InputManager:get_input_method() == rt.InputMethod.CONTROLLER,

        _left_button_is_down = false,
        _right_button_is_down = false,
        _down_button_is_down = false,
        _up_button_is_down = false,
        _jump_button_is_down = false,
        _sprint_button_is_down = false,
        _ragdoll_button_is_down = false,

        _sprint_multiplier = 1,
        _next_sprint_multiplier = 1,
        _next_sprint_multiplier_update_when_grounded = false,

        _interact_targets = {}, -- Set

        -- soft body
        _spring_bodies = {},
        _spring_joints = {},
        _spring_body_offsets_x = {},
        _spring_body_offsets_y = {},


        _outer_body_mesh = nil,
        _outer_body_mesh_origin_x = 0,
        _outer_body_mesh_origin_y = 0,
        _outer_body_center_mesh = nil,
        _outer_body_centers_x = {},
        _outer_body_centers_y = {},
        _outer_body_angles = {},
        _outer_body_scales = {},

        _outer_body_tris = {},

        _death_outer_bodies = {},
        _death_body = nil,
        _death_body_centers_x = {},
        _death_body_centers_y = {},

        -- hard body
        _body = nil,
        _world = nil,

        _mass = 1,
        _gravity_direction_x = 0,
        _gravity_direction_y = 1,
        _gravity_multiplier = 1,

        _respawn_elapsed = 0,

        _bounce_sensor = nil, -- b2.Body
        _bounce_sensor_pin = nil, -- b2.Pin
        _input = rt.InputSubscriber()
    })

    self:_connect_input()

    if self._stage ~= nil then
        self:move_to_stage(self._stage)
    end
end


--- @brief
function ow.Player:_connect_input()
    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputButton.JUMP then
            self._jump_button_is_down = true
            self._jump_elapsed = 0
            if not self._bottom_wall then
                if (self._left_wall and not self._left_wall_jump_blocked) or (self._right_wall and not self._right_wall_jump_blocked) then
                    self._wall_jump_elapsed = 0
                end
            end

            self:signal_emit("jump")
        elseif which == rt.InputButton.SPRINT then
            self._sprint_button_is_down = true
            self._next_sprint_multiplier = _settings.sprint_multiplier
            self._next_sprint_multiplier_update_when_grounded = true
        elseif which == rt.InputButton.INTERACT then
            -- interact
            for target in keys(self._interact_targets) do
                target:signal_emit("activate", self)
            end
        elseif which == rt.InputButton.RESPAWN then
            self:kill()
        elseif which == rt.InputButton.X then
            self._ragdoll_button_is_down = true
        elseif which == rt.InputButton.Y then
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
        if which == rt.InputButton.JUMP then
            self._jump_button_is_down = false
        elseif which == rt.InputButton.SPRINT then
            self._sprint_button_is_down = false
            self._next_sprint_multiplier = 1
            self._next_sprint_multiplier_update_when_grounded = true
        elseif which == rt.InputButton.X then
            self._ragdoll_button_is_down = false
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
    local gravity = _settings.gravity * delta * self._gravity_multiplier

    local function _add_blood_splatter(contact_x, contact_y, nx, ny)
        local nx_top, ny_top = math.turn_left(nx, ny)
        local nx_bottom, ny_bottom = math.turn_right(nx, ny)

        local r = math.sqrt(math.abs(select(1, self._body:get_velocity()))) / 2
        local top_x, top_y = contact_x + nx_top * r, contact_y + ny_top * r
        local bottom_x, bottom_y = contact_x + nx_bottom * r, contact_y + ny_bottom * r

        self._stage:add_blood_splatter(top_x, top_y, bottom_x, bottom_y)
    end

    if self._state == ow.PlayerState.DISABLED then
        local vx, vy = self._last_velocity_x, self._last_velocity_y
        vx = 0
        vy = vy + gravity

        if self._is_frozen then
            self._body:set_linear_velocity(0, 0)
            self._last_velocity_x, self._last_velocity_y = 0, 0
        else
            self._body:set_linear_velocity(vx, vy)
            self._last_velocity_x, self._last_velocity_y = vx, vy
        end

        self:_update_mesh()
        return
    end
    -- else _state == ACTIVE

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
    if self._next_sprint_multiplier_update_when_grounded and (self._bottom_wall or (self._left_wall or self._right_wall)) then
        self._sprint_multiplier = self._next_sprint_multiplier
    end

    local next_velocity_x, next_velocity_y = self._last_velocity_x, self._last_velocity_y

    if self._ragdoll_button_is_down then --or ((self._top_wall == false and self._right_wall == false and self._bottom_wall == false and self._left_wall == false) and not (self._up_button_is_down or self._right_button_is_down or self._down_button_is_down or self._left_button_is_down or self._sprint_button_is_down or self._jump_button_is_down) and self._joystick_position < 10e-4) then
        self._body:apply_linear_impulse(self._gravity_direction_x * gravity, self._gravity_direction_y * gravity)
        self._jump_elapsed = self._jump_elapsed + delta
        self._coyote_elapsed = self._coyote_elapsed + delta
        self._bounce_elapsed = self._bounce_elapsed + delta
        self._left_wall_elapsed = self._left_wall_elapsed + delta
        self._right_wall_elapsed = self._right_wall_elapsed + delta

        -- ragdolling
        if self._is_ragdoll == false then
            local do_jump = self._bottom_left_wall or self._bottom_wall or self._bottom_right_wall -- resets box2d contact friction
            for body in values(self._spring_bodies) do
                body:set_friction(_settings.ragdoll_friction)
                if do_jump then
                    body:apply_linear_impulse(0, -_settings.ragdoll_trigger_jump_height)
                end
            end
        end
        self._is_ragdoll = true

        goto skip_velocity_update
    end

    if self._is_ragdoll == true then
        self._is_ragdoll = false
        local do_jump = self._bottom_left_wall or self._bottom_wall or self._bottom_right_wall
        for body in values(self._spring_bodies) do
            body:set_friction(0)
            if do_jump then
                body:apply_linear_impulse(0, -_settings.ragdoll_trigger_jump_height)
            end
        end
    end

    -- update velocity
    do
        -- horizontal movement
        local magnitude
        if self._left_button_is_down and not self._right_button_is_down then
            magnitude = -1
        elseif self._right_button_is_down and not self._left_button_is_down then
            magnitude = 1
        else
            magnitude = 0
        end

        local target
        if not (self._bottom_left_wall or self._bottom_wall or self._left_wall) then
            target = _settings.air_target_velocity_x
        else
            target = _settings.ground_target_velocity_x
        end

        local target_velocity_x = magnitude * target * self._sprint_multiplier

        local current_velocity_x, current_velocity_y = self._body:get_velocity()
        current_velocity_x = current_velocity_x / self._velocity_multiplier_x
        current_velocity_y = current_velocity_y / self._velocity_multiplier_y

        local step = target_velocity_x - current_velocity_x

        local is_accelerating = (target_velocity_x > 0 and current_velocity_x > 0 and target_velocity_x > current_velocity_x) or
            (target_velocity_x < 0 and current_velocity_x < 0 and target_velocity_x < current_velocity_x) or
            (target_velocity_x < 0 and current_velocity_x > 0 or target_velocity_x > 0 and current_velocity_y < 0)

        local duration
        if is_accelerating then
            duration = self._bottom_wall and _settings.ground_acceleration_duration or _settings.air_acceleration_duration
        else
            duration = self._bottom_wall and _settings.ground_deceleration_duration or _settings.air_deceleration_duration
        end

        if self._bottom_wall == false and not (self._left_button_is_down or self._right_button_is_down or math.abs(self._joystick_position) > 10e-4) then
            duration = 10e9 -- no air resistance
        end

        if duration == 0 then
            next_velocity_x = target_velocity_x
        else
            local velocity_change = (target_velocity_x - current_velocity_x) / duration
            next_velocity_x = current_velocity_x + velocity_change * delta
        end

        -- override acceleration with analog control
        if self._use_controller_input then
            next_velocity_x = self._joystick_x * next_velocity_x
        end

        if not self._bottom_wall and not self._left_wall and not self._right_wall and not self._bottom_left_wall and not self._bottom_right_wall then
            next_velocity_x = next_velocity_x * (1 - _settings.air_resistance * self._gravity_multiplier) -- air resistance
        end

        if self._bottom_wall then -- ground friction
            local friction_coefficient = _settings.ground_regular_friction
            local surface_normal_x, surface_normal_y = bottom_nx, bottom_ny

            if bottom_wall_body:has_tag("slippery") then
                friction_coefficient = _settings.ground_slippery_friction

                -- if going upwards slippery slope
                local angle = math.angle(surface_normal_x, surface_normal_y) + math.pi * 0.5
                if (math.sign(next_velocity_x) > 0 and angle < 0 and self._right_button_is_down) or (math.sign(next_velocity_x) < 0 and angle > 0 and self._left_button_is_down) then
                    next_velocity_x = 0
                    next_velocity_y = 0
                end
            end

            local velocity_x, velocity_y = next_velocity_x, next_velocity_y
            local dot_product = velocity_x * surface_normal_x + velocity_y * surface_normal_y
            local perpendicular_x = dot_product * surface_normal_x
            local perpendicular_y = dot_product * surface_normal_y

            local parallel_x = velocity_x - perpendicular_x
            local parallel_y = velocity_y - perpendicular_y

            local friction_x = parallel_x * friction_coefficient
            local friction_y = parallel_y * friction_coefficient

            next_velocity_x = parallel_x - friction_x
            next_velocity_y = parallel_y - friction_y
        else
            -- magnetize to walls
            local magnet_force = _settings.wall_magnet_force
            if self._left_wall and not self._right_wall and self._left_button_is_down then
                next_velocity_x = next_velocity_x - magnet_force * math.distance(x, y, left_x, left_y) / (self._radius * _settings.side_wall_ray_length_factor)
            elseif self._right_wall and not self._left_wall and self._right_button_is_down then
                next_velocity_x = next_velocity_x + magnet_force * math.distance(x, y, right_x, right_y) / (self._radius * _settings.side_wall_ray_length_factor)
            end
        end

        if self._use_controller_input then
            next_velocity_x = next_velocity_x * self._joystick_x
        end

        -- vertical movement
        next_velocity_y = current_velocity_y

        local can_jump = (self._bottom_wall or (self._bottom_left_wall and not self._left_wall) or (self._bottom_right_wall and not self._right_wall))

        -- if grounded or leaving wall area, unblock walljumps
        if can_jump or (left_before == true and self._left_wall == false) then
            self._left_wall_jump_blocked = false
        end

        if can_jump or (right_before == true and self._right_wall == false) then
            self._right_wall_jump_blocked = false
        end

        local can_wall_jump = not can_jump and (
            self._wall_jump_elapsed < _settings.wall_jump_duration or (
            (self._left_wall and not self._left_wall_jump_blocked) or
            (self._right_wall and not self._right_wall_jump_blocked)
        ))

        -- override wall conditions
        if (self._bottom_wall and bottom_wall_body:has_tag("unjumpable")) or
            (self._bottom_left_wall and bottom_left_wall_body:has_tag("unjumpable")) or
            (self._bottom_right_wall and bottom_right_wall_body:has_tag("unjumpable"))
        then
            can_jump = false
        end

        if (self._left_wall and (left_wall_body:has_tag("unjumpable") or left_wall_body:has_tag("slippery"))) or
           (self._right_wall and (right_wall_body:has_tag("unjumpable") or right_wall_body:has_tag("slippery")))
        then
            can_wall_jump = false
        end


        -- reset jump button when going from air to ground, to disallow buffering jumps while falling

        if (bottom_before == false and self._bottom_wall == true) or
            (left_before == false and self._left_wall == true) or
            (right_before == false and self._right_wall == true)
        then
            self._jump_button_is_down = false
        end

        -- objects can overirde jump logic
        if self._jump_allowed_override ~= nil then
            if self._jump_allowed_override == true then
                can_jump = true
            else
                can_jump = false
            end
        end

        -- coyote time
        if can_jump then
            self._coyote_elapsed = 0
        else
            if self._coyote_elapsed < _settings.coyote_time then
                can_jump = true
            end
            self._coyote_elapsed = self._coyote_elapsed + delta
        end

        -- prevent horizontal movement after walljump
        if self._wall_jump_freeze_elapsed < _settings.wall_jump_freeze_duration and math.sign(target_velocity_x) == self._wall_jump_freeze_sign then
            next_velocity_x = current_velocity_x
        end
        self._wall_jump_freeze_elapsed = self._wall_jump_freeze_elapsed + delta

        if self._jump_button_is_down then
            if can_jump and self._jump_elapsed < _settings.jump_duration then
                -- regular jump: accelerate upwards wil jump button is down
                self._coyote_elapsed = 0
                next_velocity_y = -1 * _settings.jump_velocity * math.sqrt(self._jump_elapsed / _settings.jump_duration)
                self._jump_elapsed = self._jump_elapsed + delta
            elseif can_wall_jump then
                -- wall jump: initial burst, then small sustain
                if self._wall_jump_elapsed == 0 then -- set by jump button
                    -- initial burst
                    local dx, dy = math.cos(_settings.wall_jump_initial_angle), math.sin(_settings.wall_jump_initial_angle)

                    if self._left_wall then
                        self._left_wall_jump_blocked = true
                    elseif self._right_wall then
                        self._right_wall_jump_blocked = true
                    end

                    if self._right_wall then dx = dx * -1 end
                    local burst = _settings.wall_jump_initial_impulse + gravity
                    next_velocity_x, next_velocity_y = dx * burst, dy * burst

                    self._wall_jump_freeze_elapsed = 0

                    if self._left_wall then
                        self._wall_jump_freeze_sign = -1
                    elseif self._right_wall then
                        self._wall_jump_freeze_sign =  1
                    end
                elseif self._wall_jump_elapsed <= _settings.wall_jump_duration * (self._sprint_multiplier >= _settings.sprint_multiplier and _settings.non_sprint_walljump_duration_multiplier or 1)then
                    -- sustained jump, if not sprinting, add additional air time to make up for reduced x speed
                    local dx, dy = math.cos(_settings.wall_jump_sustained_angle), math.sin(_settings.wall_jump_sustained_angle)

                    if self._wall_jump_freeze_sign == 1 then dx = dx * -1 end
                    local force = _settings.wall_jump_sustained_impulse * delta + gravity
                    next_velocity_x = next_velocity_x + dx * force
                    next_velocity_y = next_velocity_y + dy * force
                end
            end
        end

        self._wall_jump_elapsed = self._wall_jump_elapsed + delta

        if self._jump_elapsed >= _settings.jump_duration then
            self._jump_allowed_override = nil
        end

        local wall_cling = (self._left_wall and self._left_button_is_down) or (self._right_wall and self._right_button_is_down)

        -- apply friction when wall_clinging
        local _apply_wall_friction = function(coefficient, tx, ty)
            local friction_force = coefficient * gravity * math.sign(current_velocity_y)
            friction_force = (_settings.sprint_multiplier - self._sprint_multiplier + 1) * friction_force
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


        local fraction = self._bounce_elapsed / _settings.bounce_duration
        if fraction <= 1 then
            -- bounce
            if _settings.bounce_duration == 0 then
                next_velocity_x = next_velocity_x + self._bounce_direction_x * self._bounce_force
                next_velocity_y = next_velocity_y + self._bounce_direction_y * self._bounce_force
            else
                local velocity_magnitude = math.magnitude(next_velocity_x, next_velocity_y)
                local velocity_nx, velocity_ny = math.normalize(next_velocity_x, next_velocity_y)
                local bounce_nx, bounce_ny = self._bounce_direction_x, self._bounce_direction_y

                local bounce_force = (1 - fraction) * self._bounce_force * 2
                next_velocity_x = next_velocity_x + self._bounce_direction_x * bounce_force
                next_velocity_y = next_velocity_y + self._bounce_direction_y * bounce_force
            end
        end
        self._bounce_elapsed = self._bounce_elapsed + delta

        -- downwards force
        if not frozen and self._down_button_is_down then
            local factor = _settings.downwards_force_factor
            if self._bottom_wall then factor = factor * 4 end
            next_velocity_y = next_velocity_y + factor * gravity
                * math.clamp(fraction, 0, 1) -- disable during bounce
        end

        -- gravity
        next_velocity_x = next_velocity_x + self._gravity_direction_x * gravity
        next_velocity_y = next_velocity_y + self._gravity_direction_y * gravity

        next_velocity_x = math.clamp(next_velocity_x, -_settings.max_velocity_x, _settings.max_velocity_x)
        next_velocity_y = math.clamp(next_velocity_y, -_settings.max_velocity_y, _settings.max_velocity_y)

        self._body:set_velocity(
            next_velocity_x * self._velocity_multiplier_x,
            next_velocity_y * self._velocity_multiplier_y
        )
        self._last_velocity_x, self._last_velocity_y = next_velocity_x, next_velocity_y
    end

    ::skip_velocity_update::

    -- safeguard against one of the springs catching
    for i, body in ipairs(self._spring_bodies) do
        local distance = math.distance(x, y, body:get_position())
        --body:set_is_sensor(distance > _settings.max_spring_length)
        local should_be_disabled = distance > _settings.max_spring_length--self._spring_joints[i]._prismatic_joint:getJointSpeed() > 100
        body:set_is_sensor(should_be_disabled)
    end

    if self._is_frozen then
        self._body:set_velocity(
            next_velocity_x * self._velocity_multiplier_x,
            next_velocity_y * self._velocity_multiplier_y
        )
        self._last_velocity_x, self._last_velocity_y = next_velocity_x, next_velocity_y
    end

    self:_update_mesh()

    -- add blood splatter
    local function _add_blood_splatter(contact_x, contact_y, nx, ny)
        local nx_top, ny_top = math.turn_left(nx, ny)
        local nx_bottom, ny_bottom = math.turn_right(nx, ny)

        local r = math.sqrt(math.abs(select(1, self._body:get_velocity()))) / 2
        local top_x, top_y = contact_x + nx_top * r, contact_y + ny_top * r
        local bottom_x, bottom_y = contact_x + nx_bottom * r, contact_y + ny_bottom * r

        self._stage:add_blood_splatter(top_x, top_y, bottom_x, bottom_y)
    end

    do
        if self._top_wall and math.distance(top_x, top_y, x, y) <= self._radius then
            _add_blood_splatter(top_x, top_y, top_nx, top_ny)
        end

        if self._right_wall and math.distance(right_x, right_y, x, y) <= self._radius then
            _add_blood_splatter(right_x, right_y, right_nx, right_ny)
        end

        if self._bottom_wall and math.distance(bottom_x, bottom_y, x, y) <= self._radius then
            _add_blood_splatter(bottom_x, bottom_y, bottom_nx, bottom_ny)
        end

        if self._left_wall and math.distance(left_x, left_y, x, y) <= self._radius then
            _add_blood_splatter(left_x, left_y, left_nx, left_ny)
        end
    end

    -- death bodies
    self._respawn_elapsed = self._respawn_elapsed + delta
    for body in values(self._death_outer_bodies) do
        local vx, vy = body:get_velocity()
        body:set_velocity(vx + self._gravity_direction_x * gravity, vy + self._gravity_direction_y * gravity)

        if self._respawn_elapsed < _settings.respawn_duration then
            local ray_length = self._death_body_radius * 2

            local top_dx, top_dy = 0, -ray_length
            local right_dx, right_dy = ray_length, 0
            local bottom_dx, bottom_dy = 0, ray_length
            local left_dx, left_dy = -ray_length, 0

            local x, y = body:get_position()
            local mask = bit.bnot(bit.bor(_settings.player_collision_group, _settings.player_outer_body_collision_group))

            local top_x, top_y, top_nx, top_ny, top_wall_body = self._world:query_ray_any(x, y, top_dx, top_dy, mask)
            local right_x, right_y, right_nx, right_ny, right_wall_body = self._world:query_ray(x, y, right_dx, right_dy, mask)
            local bottom_x, bottom_y, bottom_nx, bottom_ny, bottom_wall_body = self._world:query_ray(x, y, bottom_dx, bottom_dy, mask)
            local left_x, left_y, left_nx, left_ny, left_wall_body = self._world:query_ray(x, y, left_dx, left_dy, mask)

            local left_wall = left_wall_body ~= nil and not left_wall_body:get_is_sensor()
            local right_wall = right_wall_body ~= nil and not right_wall_body:get_is_sensor()
            local top_wall = top_wall_body ~= nil and not top_wall_body:get_is_sensor()
            local bottom_wall = bottom_wall_body ~= nil and not bottom_wall_body:get_is_sensor()

            if top_wall then
                _add_blood_splatter(top_x, top_y, top_nx, top_ny)
            end

            if right_wall then
                _add_blood_splatter(right_x, right_y, right_nx, right_ny)
            end

            if bottom_wall then
                _add_blood_splatter(bottom_x, bottom_y, bottom_nx, bottom_ny)
            end

            if left_wall then
                _add_blood_splatter(left_x, left_y, left_nx, left_ny)
            end
        end
    end

    self._bounce_locked = false
end

--- @brief
function ow.Player:move_to_stage(stage, x, y)
    meta.assert(stage, "Stage", x, "Number", y, "Number")
    local world = stage:get_physics_world()
    if world == self._world then return end

    self._stage = stage
    self._world = world
    self._world:set_gravity(0, 0)

    self.DISABLED, self._last_respawn_y = x, y

    -- hard body
    local inner_body_shape = b2.Circle(0, 0, self._inner_body_radius)
    self._body = b2.Body(
        self._world, b2.BodyType.DYNAMIC, x, y,
        inner_body_shape
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
    self._spring_bodies = {}
    self._spring_joints = {}
    self._spring_body_offsets_x = {}
    self._spring_body_offsets_y = {}

    local outer_radius = self._radius - self._outer_body_radius
    local outer_body_shape = b2.Circle(0, 0, self._outer_body_radius)
    local step = (2 * math.pi) / _settings.n_outer_bodies

    local mask = bit.bnot(_settings.player_outer_body_collision_group)

    for angle = 0, 2 * math.pi, step do
        local offset_x = math.cos(angle) * outer_radius
        local offset_y = math.sin(angle) * outer_radius
        local cx = x + offset_x
        local cy = y + offset_y

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
        table.insert(self._spring_body_offsets_x, offset_x)
        table.insert(self._spring_body_offsets_y, offset_y)
    end

    -- true mass
    self._mass = self._body:get_mass()
    for body in values(self._spring_bodies) do
        self._mass = self._mass + body:get_mass()
    end

    -- death animation proxies
    self._death_body_angles = {}
    local death_body_shape = b2.Circle(0, 0, self._inner_body_radius)
    self._death_body_radius = self._inner_body_radius
    self._death_outer_bodies = {}
    local death_mask = bit.bnot(bit.bor(_settings.player_collision_group, _settings.player_outer_body_collision_group))
    for i = 1, _settings.n_outer_bodies do
        local body = b2.Body(self._world, b2.BodyType.DYNAMIC, 0, 0, death_body_shape)
        body:set_is_enabled(false)
        body:set_mass(1)
        body:set_restitution(0.5)
        body:set_is_rotation_fixed(true)
        body:set_collides_with(death_mask)
        body:set_collision_group(_settings.player_outer_body_collision_group)
        table.insert(self._death_outer_bodies, body)
        table.insert(self._death_body_angles, math.angle(self._spring_body_offsets_x[i], self._spring_body_offsets_y[i]) + math.pi)
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

    if self._state == ow.PlayerState.DISABLED then
        self:disable()
    end
end

function ow.Player:_update_mesh()
    -- update mesh
    local player_x, player_y = self._body:get_predicted_position()
    local to_polygonize = {}

    for i, body in ipairs(self._spring_bodies) do
        local cx, cy = body:get_predicted_position()
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
            --success, new_tris = pcall(slick.triangulate, {to_polygonize})
            self._outer_body_tris = {}
        end

        if success then
            self._outer_body_tris = new_tris
        end
    end

    -- update death bodies
    self._death_body_centers_x = {}
    self._death_body_centers_y = {}
    for i, body in ipairs(self._death_outer_bodies) do
        local x, y = body:get_predicted_position()
        self._death_body_centers_x[i] = x
        self._death_body_centers_y[i] = y
    end
end

--- @brief
function ow.Player:draw()
    -- draw body
    rt.Palette.MINT_1:bind()
    love.graphics.draw(self._outer_body_center_mesh:get_native(), self._body:get_position())

    local r, g, b, a = rt.Palette.MINT_2:unpack()
    local rag_a, rag_g, rag_b = rt.Palette.GRAY_2:unpack()

    if self._is_ragdoll then
        love.graphics.setColor(rag_a, rag_g, rag_b, 0.3)
    else
        love.graphics.setColor(r, g, b, 0.3)
    end

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

    if self._is_ragdoll then
        love.graphics.setColor(rag_a, rag_g, rag_b, 1)
    else
        love.graphics.setColor(r, g, b, 1)
    end

    -- draw death bodies
    rt.Palette.MINT_1:bind()
    for i, body in ipairs(self._death_outer_bodies) do
        local x = self._death_body_centers_x[i]
        local y = self._death_body_centers_y[i]
        love.graphics.draw(self._outer_body_center_mesh:get_native(),
            x, y,
            self._death_body_angles[i] + body:get_rotation()
        )
    end

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
    self._wall_jump_elapsed = 0
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
    self._interact_targets[target] = nil
end

local _before = nil

--- @brief
function ow.Player:disable()
    if self._state ~= ow.PlayerState.DISABLED then
        _before = self._state
    end

    self._state = ow.PlayerState.DISABLED
end

--- @brief
function ow.Player:enable()
    if _before == nil then
        self._state = ow.PlayerState.ACTIVE
    else
        self._state = _before
    end
end

--- @brief
function ow.Player:set_velocity(x, y)
    if self._body ~= nil then
        self._body:set_velocity(x, y)
    end
    self._last_velocity_x, self._last_velocity_y = x, y
end

--- @brief
function ow.Player:get_velocity()
    return self._last_velocity_x, self._last_velocity_y
end

--- @brief
function ow.Player:get_is_ragdoll()
    return self._is_ragdoll
end

--- @brief
function ow.Player:bounce(nx, ny, force)
    if self._bounce_locked then return end

    self._bounce_force = math.clamp(math.magnitude(self._last_velocity_x, self._last_velocity_y), _settings.bounce_min_force, _settings.bounce_max_force)
    self._bounce_direction_x = nx
    self._bounce_direction_y = ny
    self._bounce_elapsed = 0
    self._bounce_locked = true
end

--- @brief
function ow.Player:set_is_frozen(b)
    self._is_frozen = b
end

--- @brief
function ow.Player:kill()
    self._respawn_elapsed = 0

    local x, y = self._body:get_position()
    local vx, vy = self._body:get_velocity()

    local speed = _settings.kill_animation_initial_impulse
    for i, body in ipairs(self._death_outer_bodies) do
        local offset_x, offset_y = self._spring_body_offsets_x[i], self._spring_body_offsets_y[i]
        body:set_position(x + offset_x, y + offset_y)
        local dx, dy = math.normalize(offset_x, offset_y)
        body:set_velocity(dx * speed, dy * speed)
        body:set_is_enabled(true)
    end

    if self._last_spawn ~= nil then
        self._last_spawn:spawn()
    end
end

--- @brief
function ow.Player:set_last_player_spawn(spawn)
    self._last_spawn = spawn
end



