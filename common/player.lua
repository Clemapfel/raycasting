require "common.input_subscriber"
require "physics.physics"
require "common.player_body"
require "common.player_trail"
require "common.random"
require "common.palette"

local radius = 13.5
rt.settings.player = {
    radius = radius,
    inner_body_radius = 10 / 2 - 0.5,
    n_outer_bodies = 27,
    max_spring_length = radius * 3,
    outer_body_spring_strength = 2,

    bottom_wall_ray_length_factor = 1.5,
    side_wall_ray_length_factor = 1.05,
    corner_wall_ray_length_factor = 0.8,
    top_wall_ray_length_factor = 1,
    joystick_to_analog_eps = 0.35,

    player_collision_group = b2.CollisionGroup.GROUP_16,
    player_outer_body_collision_group = b2.CollisionGroup.GROUP_15,
    bounce_collision_group = b2.CollisionGroup.GROUP_14,
    exempt_collision_group = b2.CollisionGroup.GROUP_13,
    ghost_collision_group = b2.CollisionGroup.GROUP_12,

    ground_target_velocity_x = 300,
    air_target_velocity_x = 320,
    sprint_multiplier = 2,
    friction_coefficient = 2.5, -- factor of velocity projected onto surface tangent
    bubble_friction_coefficient = 1.5,

    flow_increase_velocity = 1 / 200, -- percent per second
    flow_decrease_velocity = 1,
    flow_max_velocity = 1, -- percent per second
    flow_fraction_history_n = 100, -- n samples
    flow_fraction_sample_frequency = 60, -- n samples per second

    position_history_n = 1000, -- n samples
    position_history_sample_frequency = 10, -- px

    ground_acceleration_duration = 20 / 60, -- seconds
    ground_deceleration_duration = 5 / 60,

    air_acceleration_duration = 15 / 60, -- seconds
    air_deceleration_duration = 15 / 60,

    coyote_time = 3 / 60,

    jump_duration = 11 / 60,
    jump_impulse = 520, -- 4 * 32 neutral jump

    wall_magnet_force = 200,
    wall_jump_initial_impulse = 340,
    wall_jump_sustained_impulse = 1200, -- force per second
    wall_jump_initial_angle = math.rad(18) - math.pi * 0.5,
    wall_jump_sustained_angle = math.rad(5) - math.pi * 0.5,
    non_sprint_walljump_duration_multiplier = 1.4,
    wall_jump_duration = 12 / 60,
    wall_jump_freeze_duration = 7 / 60,

    accelerator_max_velocity = 2000, -- vxy magnitude
    accelerator_magnet_force = 400,

    bounce_min_force = 200,
    bounce_max_force = 400,
    bounce_duration = 2 / 60,

    double_jump_buffer_duration = 15 / 60,

    spring_multiplier = 1.2,
    spring_constant = 1.8,
    joint_force_threshold = 1000,
    joint_length_threshold = 100,

    bubble_radius_factor = 2.25,
    bubble_inner_radius_scale = 1.7,
    bubble_target_velocity = 400,
    bubble_acceleration = 2.5,
    bubble_air_resistance = 0.5, -- px / s
    bubble_gravity_factor = 0.015,

    gravity = 1500, -- px / s
    air_resistance = 0.03, -- [0, 1]
    downwards_force = 3000,
    wall_regular_friction = 0.8, -- times of gravity
    ground_regular_friction = 0,
    ground_slippery_friction = -0.2,

    max_velocity_x = 2500,
    max_velocity_y = 2500,

    idle_threshold_duration = 0.5,

    squeeze_multiplier = 1.4,

    color_a = 1.0,
    color_b = 0.6,
    hue_cylce_duration = 1,

    --debug_drawing_enabled = true,
}

local _settings = setmetatable({}, {
    __index = function(self, key)
        local res = debugger.get(key)
        if res == nil then
            res = rt.settings.player[key]
        end
        return res
    end
})

--- @class rt.Player
rt.Player = meta.class("Player")
meta.add_signals(rt.Player,
    "jump",      -- when jumping
    "grounded"   -- touching ground after being airborne
)

rt.PlayerState = meta.enum("PlayerState", {
    ACTIVE = 1,
    DISABLED = 2,
    RESPAWNING = 3
})

--- @brief
function rt.Player:instantiate()
    local player_radius = _settings.radius
    meta.install(self, {
        _stage = nil,
        _state = rt.PlayerState.ACTIVE,

        _color = rt.Palette.PLAYER,
        _opacity = 1,
        _is_visible = true,
        _should_update = true,

        _radius = player_radius,
        _inner_body_radius = _settings.inner_body_radius,
        _outer_body_radius = (player_radius * 2 * math.pi) / _settings.n_outer_bodies / 1.5,

        _bubble_radius = player_radius * _settings.bubble_radius_factor,
        _bubble_inner_body_radius = _settings.inner_body_radius * _settings.bubble_inner_radius_scale,
        _bubble_outer_body_radius = (player_radius * _settings.bubble_radius_factor * 2 * math.pi) / _settings.n_outer_bodies / 2,

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
        _spring_multiplier = 1,

        _wall_jump_elapsed = 0,
        _left_wall_jump_blocked = false,
        _right_wall_jump_blocked = false,
        _wall_jump_freeze_elapsed = math.huge,
        _wall_jump_freeze_sign = 0,

        _bounce_direction_x = 0,
        _bounce_direction_y = 0,
        _bounce_force = 0,
        _bounce_elapsed = math.huge,

        _double_jump_buffer_elapsed = math.huge,

        _last_velocity_x = 0,
        _last_velocity_y = 0,

        _velocity_multiplier_x = 1,
        _velocity_multiplier_y = 1,

        _last_bubble_force_x = 0,
        _last_bubble_force_y = 0,

        _is_frozen = false,
        _respawn_elapsed = 0,
        _use_wall_friction = true,

        _gravity = 1, -- [-1, 1]

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

        -- soft body
        _spring_bodies = {},
        _spring_joints = {},
        _spring_body_offsets_x = {},
        _spring_body_offsets_y = {},

        _bubble_spring_bodies = {},
        _bubble_spring_joints = {},
        _bubble_spring_body_offsets_x = {},
        _bubble_spring_body_offsets_y = {},

        -- hard body
        _body = nil,
        _world = nil,
        _last_position_x = 0,
        _last_position_y = 0,

        -- animation
        _trail = nil, -- rt.PlayerTrail
        _trail_visible = true,
        _graphics_body = nil,

        _hue = 0,
        _hue_duration = _settings.hue_cylce_duration,

        _mass = 1,
        _gravity_direction_x = 0,
        _gravity_direction_y = 1,
        _gravity_multiplier = 1,

        _respawn_elapsed = 0,
        _can_wall_jump = false,
        _can_jump = false,
        _is_ghost = false,

        -- flow
        _flow = 0,
        _override_flow = nil,
        _flow_velocity = 0,
        _velocity_history_x = table.rep(0, _settings.flow_fraction_history_n),
        _velocity_history_x_sum = 0,
        _velocity_history_y = table.rep(0, _settings.flow_fraction_history_n),
        _velocity_history_y_sum = 0,

        _flow_fraction_history = table.rep(0, _settings.flow_fraction_history_n),
        _flow_fraction_history_sum = 0,

        _flow_fraction_history_elapsed = 0,
        _last_flow_fraction = 0,
        _skip_next_flow_update = true, -- skip when spawning

        _flow_is_frozen = false,

        _position_history = {},

        -- bubble
        _is_bubble = false,
        _use_bubble_mesh = false, -- cf. draw
        _use_bubble_mesh_delay_n_steps = 0,

        _input = rt.InputSubscriber(),
        _idle_elapsed = 0,

        -- double jump
        _double_jump_sources = {},
        _double_jump_locked = true,

        -- particles
        _body_to_collision_normal = {}


    })

    for i = 1, 2 * _settings.position_history_n, 2 do
        self._position_history[i+0] = 0
        self._position_history[i+1] = 0
    end

    self._trail = rt.PlayerTrail(self)
    self._graphics_body = rt.PlayerBody(self)
    self:_connect_input()
end

--- @brief
function rt.Player:_connect_input()
    self._input:signal_connect("pressed", function(_, which)
        if self._state == rt.PlayerState.DISABLED then return end

        if which == rt.InputAction.JUMP then
            self:jump()

            -- unlock double jump by re-pressing mid-air
            local is_midair = self._bottom_left_wall == false and self._bottom_wall == false and self._bottom_right_wall == false
            if #self._double_jump_sources > 0 and is_midair then
                self._double_jump_locked = false
            end

            -- allow buffered double jumps
            if #self._double_jump_sources == 0 and is_midair then
                self._double_jump_buffer_elapsed = 0
            end
        elseif which == rt.InputAction.SPRINT then
            self._sprint_button_is_down = true
            self._next_sprint_multiplier = _settings.sprint_multiplier
            self._next_sprint_multiplier_update_when_grounded = true
        elseif which == rt.InputAction.Y then
        elseif which == rt.InputAction.LEFT then
            self._left_button_is_down = true
        elseif which == rt.InputAction.RIGHT then
            self._right_button_is_down = true
        elseif which == rt.InputAction.DOWN then
            self._down_button_is_down = true
        elseif which == rt.InputAction.UP then
            self._up_button_is_down = true
        end
    end)

    self._input:signal_connect("released", function(_, which)
        if self._state == rt.PlayerState.DISABLED then return end

        if which == rt.InputAction.JUMP then
            self._jump_button_is_down = false
            self._spring_multiplier = 1
        elseif which == rt.InputAction.SPRINT then
            self._sprint_button_is_down = false
            self._next_sprint_multiplier = 1
            self._next_sprint_multiplier_update_when_grounded = true
        elseif which == rt.InputAction.LEFT then
            self._left_button_is_down = false
        elseif which == rt.InputAction.RIGHT then
            self._right_button_is_down = false
        elseif which == rt.InputAction.DOWN then
            self._down_button_is_down = false
        elseif which == rt.InputAction.UP then
            self._up_button_is_down = false
        end
    end)

    self._input:signal_connect("input_method_changed", function(_, which)
        self._use_controller_input = which == rt.InputMethod.CONTROLLER
    end)

    self._input:signal_connect("left_joystick_moved", function(_, x, y)
        if self._state == rt.PlayerState.DISABLED then return end

        self._joystick_position = x

        -- convert joystick inputs to digital
        local eps = _settings.joystick_to_analog_eps
        self._up_button_is_down = y < -eps
        self._down_button_is_down = y > eps
        self._right_button_is_down = x > eps
        self._left_button_is_down = x < -eps
    end)

    local is_sleeping = false
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "g" then -- TODO
            self:set_is_bubble(not self:get_is_bubble())
        elseif which == "r" then
            self:set_is_ghost(not self:get_is_ghost())
        elseif false then --which == "h" then
            is_sleeping = not is_sleeping

            if is_sleeping then
                for i, spring in ipairs(self._spring_joints) do
                    local x = self._spring_body_offsets_x[i]
                    local y = self._spring_body_offsets_y[i]
                    local angle = math.angle(x, y)
                    if angle > 0 then
                        spring:set_tolerance(-0.5 * self._radius, 0)
                    end
                end
            else
                for i, spring in ipairs(self._spring_joints) do
                    local x = self._spring_body_offsets_x[i]
                    local y = self._spring_body_offsets_y[i]
                    local angle = math.angle(x, y)
                    if angle > 0 then
                        spring:set_tolerance(0, 0)
                    end
                end
            end
        end
    end)
end

--- @brief
function rt.Player:update(delta)
    if self._body == nil then return end
    if self._should_update == false then return end

    self:_update_mesh(delta)
    if self._trail_visible then
        self._trail:update(delta)
    end

    self._hue = math.fract(self._hue + 1 / self._hue_duration * delta / 4 * math.min(self:get_flow()^0.7 + 0.1, 1))

    if self._state == rt.PlayerState.ACTIVE and
        self._up_button_is_down or
        self._right_button_is_down or
        self._down_button_is_down or
        self._left_button_is_down or
        self._jump_button_is_down or
        (not self._is_bubble and self._bottom_wall == false)
    then
        self._idle_elapsed = 0
    else
        self._idle_elapsed = self._idle_elapsed + delta
    end

    local gravity = _settings.gravity * delta * self._gravity_multiplier

    if self._state == rt.PlayerState.DISABLED then
        local vx, vy = self._last_velocity_x, self._last_velocity_y
        vy = vy + gravity

        if self._is_bubble then
            if self._is_frozen then
                self._bubble_body:set_linear_velocity(0, 0)
                self._last_velocity_x, self._last_velocity_y = 0, 0
            else
                self._bubble_body:set_linear_velocity(vx, vy)
                self._last_velocity_x, self._last_velocity_y = vx, vy
            end
        else
            if self._is_frozen then
                self._body:set_linear_velocity(0, 0)
                self._last_velocity_x, self._last_velocity_y = 0, 0
            else
                self._body:set_linear_velocity(vx, vy)
                self._last_velocity_x, self._last_velocity_y = vx, vy
            end
        end

        return
    end

    local midair_before = not self._bottom_wall

    -- raycast to check for walls
    local x, y
    if self._is_bubble then
        x, y = self._bubble_body:get_position()
    else
        x, y = self._body:get_position()
    end

    local mask = bit.bnot(bit.bor(_settings.player_outer_body_collision_group, _settings.exempt_collision_group))

    local bubble_factor = 1
    if self._is_bubble then
        bubble_factor = _settings.bubble_radius_factor
    end

    local top_ray_length = self._radius * _settings.top_wall_ray_length_factor * bubble_factor
    local right_ray_length = self._radius * _settings.side_wall_ray_length_factor * bubble_factor
    local left_ray_length = right_ray_length * bubble_factor
    local bottom_ray_length = self._radius * _settings.bottom_wall_ray_length_factor * bubble_factor
    local bottom_left_ray_length = self._radius * _settings.corner_wall_ray_length_factor * bubble_factor
    local bottom_right_ray_length = bottom_left_ray_length * bubble_factor

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

    if self._is_ghost then
        self._left_wall = false
        self._right_wall = false
        self._top_wall = false
        self._bottom_wall = false
        self._bottom_left_wall = false
        self._bottom_right_wall = false
    end

    -- when going from air to ground, signal emission and re-lock double jump
    if (bottom_left_before == false and bottom_before == false and bottom_right_before == false) and
        (self._bottom_left_wall == true or self._bottom_wall == true or self._bottom_right_wall == true)
    then
        self:signal_emit("grounded")
        self._double_jump_locked = true
    end

    if not self._is_bubble then -- reset double jump counter when touching wall or ground
        local is_grounded = self._bottom_left_wall or self._bottom_left_wall or self._bottom_wall
        local is_touching_wall = self._left_wall or self._right_wall
        if is_grounded or (not is_grounded and is_touching_wall) then
            self._double_jump_sources = {}
        end
    end

    do -- compute current normal for all colliding walls
        local mask = bit.bnot(bit.bor(_settings.player_outer_body_collision_group, _settings.player_collision_group))
        local body = self._is_bubble and self._bubble_body or self._body
        local outer_bodies = self._is_bubble and self._bubble_spring_bodies or self._spring_bodies
        local offset_x = self._is_bubble and self._bubble_spring_body_offsets_x or self._spring_body_offsets_x
        local offset_y = self._is_bubble and self._bubble_spring_body_offsets_y or self._spring_body_offsets_y

        local self_x, self_y = body:get_position()
        local ray_length = self:get_radius() + 2 * self._outer_body_radius

        local body_to_ray_data = {}
        for i, outer in pairs(outer_bodies) do
            local cx, cy = outer:get_position()
            local dx, dy = math.normalize(offset_x[i], offset_y[i])

            local ray_x, ray_y, ray_nx, ray_ny, ray_wall_body = self._world:query_ray(self_x, self_y, dx * ray_length, dy * ray_length, mask)

            if ray_wall_body ~= nil then
                local hash = ray_wall_body
                local entry = body_to_ray_data[hash]
                if entry == nil then
                    entry = {}
                    body_to_ray_data[hash] = entry
                end

                table.insert(entry, {
                    contact_x = ray_x,
                    contact_y = ray_y,
                    normal_x = ray_nx,
                    normal_y = ray_ny,
                    penetration = 1 - math.distance(self_x, self_y, ray_x, ray_y) / ray_length
                })
            end
        end

        -- compute true contact normal for bodies
        self._body_to_collision_normal = {}
        for wall_body, hits in pairs(body_to_ray_data) do
            local nx_sum, ny_sum, n = 0, 0, 0
            local x_sum, y_sum = 0, 0
            for entry in values(hits) do
                nx_sum = nx_sum + entry.normal_x
                ny_sum = ny_sum + entry.normal_y
                x_sum = x_sum + entry.contact_x
                y_sum = y_sum + entry.contact_y
                n = n + 1
            end

            self._body_to_collision_normal[wall_body] = {
                normal_x = nx_sum / n,
                normal_y = ny_sum / n,
                contact_x = x_sum / n,
                contact_y = y_sum / n
            }
        end
    end

    if not self._is_bubble then
        -- update sprint once landed
        if self._next_sprint_multiplier_update_when_grounded and (self._bottom_wall or (self._left_wall or self._right_wall)) then
            self._sprint_multiplier = self._next_sprint_multiplier
        end

        local next_velocity_x, next_velocity_y = self._last_velocity_x, self._last_velocity_y

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

            local is_accelerating = (target_velocity_x > 0 and current_velocity_x > 0 and target_velocity_x > current_velocity_x) or
                (target_velocity_x < 0 and current_velocity_x < 0 and target_velocity_x < current_velocity_x) or
                (target_velocity_x < 0 and current_velocity_x > 0 or target_velocity_x > 0 and current_velocity_y < 0)

            local duration
            local ground_deceleration = _settings.ground_deceleration_duration

            if is_accelerating then
                duration = self._bottom_wall and _settings.ground_acceleration_duration or _settings.air_acceleration_duration
            else
                duration = self._bottom_wall and ground_deceleration or _settings.air_deceleration_duration
            end

            -- no air resistance
            if self._bottom_wall == false and not (self._left_button_is_down or self._right_button_is_down or math.abs(self._joystick_position) > 10e-4) then
                duration = math.huge
            end

            -- if ducking, slide freely
            if not is_accelerating and self._bottom_wall == true and (self._down_button_is_down and not (self._left_button_is_donw or self._right_button_is_down)) then
                duration = math.huge
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

            if self._use_wall_friction then
                -- magnetize to walls, decrease based on how far wall is from vertical
                local magnet_force = _settings.wall_magnet_force
                if self._left_wall and not self._right_wall and self._left_button_is_down and not left_wall_body:has_tag("slippery")then
                    local force = magnet_force * math.distance(x, y, left_x, left_y) / (self._radius * _settings.side_wall_ray_length_factor)
                    force = force * (1 - math.abs(math.dot(left_nx, left_ny, 0, 1)))
                    next_velocity_x = next_velocity_x - force
                elseif self._right_wall and not self._left_wall and self._right_button_is_down and not right_wall_body:has_tag("slippery") then
                    local force = magnet_force * math.distance(x, y, right_x, right_y) / (self._radius * _settings.side_wall_ray_length_factor)
                    force = force * (1 - math.abs(math.dot(right_nx, right_ny, 0, 1)))
                    next_velocity_x = next_velocity_x + force
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

            -- double jump buffer input
            self._double_jump_buffer_elapsed = self._double_jump_buffer_elapsed + delta

            self._can_jump = can_jump
            self._can_wall_jump = can_wall_jump

            if self._jump_button_is_down then
                if self._jump_allowed_override ~= nil then
                    -- jump override
                    if self._jump_allowed_override == true then
                        can_jump = true
                    else
                        goto skip_jump
                    end
                    self._jump_allowed_override = nil
                elseif not self._double_jump_locked and #self._double_jump_sources > 0 then
                    -- double jump
                    can_jump = true
                    self._jump_elapsed = 0
                    assert(table.pop(self._double_jump_sources) ~= nil)
                    self._double_jump_locked = true
                end

                if can_jump and self._jump_elapsed < _settings.jump_duration then
                    -- regular jump: accelerate upwards wil jump button is down
                    self._coyote_elapsed = 0
                    next_velocity_y = -1 * _settings.jump_impulse * math.sqrt(self._jump_elapsed / _settings.jump_duration) * self._spring_multiplier
                    self._jump_elapsed = self._jump_elapsed + delta
                elseif not can_jump and can_wall_jump then
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

                ::skip_jump::
            end

            if self._jump_elapsed >= _settings.jump_duration then self._spring_multiplier = 1 end

            self._wall_jump_elapsed = self._wall_jump_elapsed + delta

            -- bounce
            local fraction = self._bounce_elapsed / _settings.bounce_duration
            if fraction <= 1 then
                if _settings.bounce_duration == 0 then
                    next_velocity_x = next_velocity_x + self._bounce_direction_x * self._bounce_force
                    next_velocity_y = next_velocity_y + self._bounce_direction_y * self._bounce_force
                else
                    local bounce_force = (1 - fraction) * self._bounce_force
                    next_velocity_x = next_velocity_x + self._bounce_direction_x * bounce_force
                    next_velocity_y = next_velocity_y + self._bounce_direction_y * bounce_force
                end
            else
                self._bounce_force = 0
            end
            self._bounce_elapsed = self._bounce_elapsed + delta

            -- downwards force
            if self._down_button_is_down then
                next_velocity_y = next_velocity_y + _settings.downwards_force * delta
            end

            -- accelerators
            for surface in range(
                { left_wall_body, left_nx, left_ny },
                { top_wall_body, top_nx, top_ny },
                { right_wall_body, right_nx, right_ny },
                { bottom_left_wall_body, bottom_left_nx, bottom_left_ny },
                { bottom_right_wall_body, bottom_right_nx, bottom_right_ny },
                { bottom_wall_body, bottom_nx, bottom_ny }
            ) do
                local body, nx, ny = table.unpack(surface)
                if body ~= nil and body:has_tag("use_friction") then
                    local friction = body:get_friction()

                    local tx, ty = -ny, nx
                    local vx, vy = next_velocity_x, next_velocity_y
                    local dot_product = vx * tx + vy * ty

                    local tangent_velocity_x = dot_product * tx
                    local tangent_velocity_y = dot_product * ty

                    local friction_force_x = -tangent_velocity_x * friction * _settings.friction_coefficient
                    local friction_force_y = -tangent_velocity_y * friction * _settings.friction_coefficient

                    -- apply tangential force
                    next_velocity_x = next_velocity_x + friction_force_x * delta
                    next_velocity_y = next_velocity_y + friction_force_y * delta

                    -- magnetize to surface
                    local flipped_x, flipped_y = math.flip(nx, ny)
                    next_velocity_x = next_velocity_x + flipped_x * delta * _settings.accelerator_magnet_force
                    next_velocity_y = next_velocity_y + flipped_y * delta * _settings.accelerator_magnet_force
                end

                if math.magnitude(next_velocity_x, next_velocity_y) > _settings.accelerator_max_velocity then
                    next_velocity_x, next_velocity_y = math.normalize(next_velocity_x, next_velocity_y)
                    next_velocity_x = next_velocity_x * _settings.accelerator_max_velocity
                    next_velocity_y = next_velocity_y * _settings.accelerator_max_velocity
                end
            end

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

        if self._is_frozen then
            self._body:set_velocity(
                next_velocity_x * self._velocity_multiplier_x,
                next_velocity_y * self._velocity_multiplier_y
            )
            self._last_velocity_x, self._last_velocity_y = next_velocity_x, next_velocity_y
        end

    else -- self._is_bubble == true
        -- bubble movement
        local mass_multiplier = self._bubble_mass / self._mass
        local bubble_gravity = gravity * (mass_multiplier / delta) * _settings.bubble_gravity_factor
        local max_velocity = _settings.bubble_target_velocity
        local target_x, target_y = 0, 0
        local current_x, current_y = self._bubble_body:get_velocity()

        if self._left_button_is_down then
            target_x = -1
        end

        if self._right_button_is_down then
            target_x = 1
        end

        if self._up_button_is_down or self._jump_button_is_down then
            target_y = -1
        end

        if self._down_button_is_down then
            target_y = 1
        end

        local next_force_x, next_force_y
        if not (target_x == 0 and target_y == 0) then
            target_x = target_x * max_velocity * mass_multiplier
            target_y = target_y * max_velocity * mass_multiplier
            local acceleration = _settings.bubble_acceleration

            next_force_x = (target_x - current_x) * acceleration
            next_force_y = (target_y - current_y) * acceleration
        else
            if gravity > 0 then
                next_force_x = -current_x * _settings.bubble_air_resistance * delta
                next_force_y = -current_y * _settings.bubble_air_resistance * delta
            else
                next_force_x = 0
                next_force_y = 0
            end
        end

        -- accelerators
        local current_velocity_x, current_velocity_y = self._bubble_body:get_velocity()
        for surface in range(
            { left_wall_body, left_nx, left_ny },
            { top_wall_body, top_nx, top_ny },
            { right_wall_body, right_nx, right_ny },
            { bottom_left_wall_body, bottom_left_nx, bottom_left_ny },
            { bottom_right_wall_body, bottom_right_nx, bottom_right_ny },
            { bottom_wall_body, bottom_nx, bottom_ny }
        ) do
            local body, nx, ny = table.unpack(surface)
            if body ~= nil and body:has_tag("use_friction") then
                local friction = body:get_friction()

                local tx, ty = -ny, nx
                local vx, vy = self._bubble_body:get_velocity()
                local dot_product = vx * tx + vy * ty

                local tangent_velocity_x = dot_product * tx
                local tangent_velocity_y = dot_product * ty

                local friction_force_x = -tangent_velocity_x * friction * _settings.bubble_friction_coefficient
                local friction_force_y = -tangent_velocity_y * friction * _settings.bubble_friction_coefficient

                -- apply tangential force
                next_force_x = next_force_x + friction_force_x
                next_force_y = next_force_y + friction_force_y

                --[[
                local flipped_x, flipped_y = math.flip(nx, ny)
                next_force_x = next_force_x + flipped_x * delta * _settings.wall_magnet_force
                next_force_y = next_force_y + flipped_y * delta * _settings.wall_magnet_force
                ]]--
            end
        end

        self._bubble_body:apply_force(next_force_x, next_force_y)
        self._last_bubble_force_x, self._last_bubble_force_y = next_force_x, next_force_y

        if self._bounce_elapsed <= _settings.bounce_duration then
            -- single impulse in bubble mode
            self._bubble_body:apply_linear_impulse(
                self._bounce_direction_x * self._bounce_force * mass_multiplier,
                self._bounce_direction_y * self._bounce_force * mass_multiplier
            )

            self._bounce_elapsed = math.huge
            self._bounce_force = 0
        end

        self._bubble_body:apply_force(0, bubble_gravity)
    end

    do
        -- safeguard against springs catching
        local bodies, joints, offset_x, offset_y
        if self._is_bubble then
            bodies, joints = self._bubble_spring_bodies, self._bubble_spring_joints
            offset_x, offset_y = self._bubble_spring_body_offsets_x, self._bubble_spring_body_offsets_y
        else
            bodies, joints = self._spring_bodies, self._spring_joints
            offset_x, offset_y = self._spring_body_offsets_x, self._spring_body_offsets_y
        end

        if not self._is_ghost then
            for i, body in ipairs(bodies) do
                local joint = joints[i]
                local over_threshold = joint:get_distance() > self:get_radius()
                body:set_is_sensor(over_threshold)
                joint:set_enabled(not over_threshold)
                if over_threshold then
                    local px, py = self._body:get_position()
                    body:set_velocity(0, 0)
                    body:set_position(px + self._spring_body_offsets_x[i], py + self._spring_body_offsets_y[i])
                end
            end
        end
    end

    -- update flow
    if self._stage ~= nil and not self._flow_frozen and not (self._skip_next_flow_update == true) and self._state ~= rt.PlayerState.DISABLED then
        self._flow_fraction_history_elapsed = self._flow_fraction_history_elapsed + delta

        -- compute whether the player was making progress over the last n samples
        local next_flow_fraction = self._stage:get_flow_fraction()
        local n = _settings.flow_fraction_history_n
        local step = 1 / _settings.flow_fraction_sample_frequency
        while self._flow_fraction_history_elapsed > step do
            local first_fraction = self._flow_fraction_history[1]
            local new_fraction = (next_flow_fraction - self._last_flow_fraction) > 0 and 1 or -1
            table.remove(self._flow_fraction_history, 1)
            table.insert(self._flow_fraction_history, new_fraction)
            self._flow_fraction_history_sum = self._flow_fraction_history_sum - first_fraction + new_fraction

            self._flow_fraction_history_elapsed = self._flow_fraction_history_elapsed - step
        end

        self._last_flow_fraction = next_flow_fraction

        local fraction_average = self._flow_fraction_history_sum / n
        local should_increase = fraction_average > 0

        local target_velocity
        if should_increase then
            target_velocity = _settings.flow_increase_velocity
        else
            target_velocity = -1 * _settings.flow_decrease_velocity
        end

        local acceleration = (target_velocity - self._flow_velocity)
        self._flow_velocity = math.clamp(self._flow_velocity + acceleration * delta, -1 * _settings.flow_max_velocity, _settings.flow_max_velocity)
        self._flow = self._flow + self._flow_velocity * delta
        self._flow = math.clamp(self._flow, 0, 1)
    end

    if self._skip_next_flow_update == true then
        self._skip_next_flow_update = false
    end

    -- add blood splatter
    if self._stage ~= nil and not self._is_ghost then
        local function _add_blood_splatter(contact_x, contact_y, last_contact_x, last_contact_y)
            local r = self._radius / 2
            local cx, cy = contact_x, contact_y

            if last_contact_x ~= nil then
                local dx, dy = contact_x - last_contact_x, contact_y - last_contact_y
                r = math.magnitude(dx, dy) / 2
            end

            self._stage:get_blood_splatter():add(cx, cy, r, self._hue)
        end

        do
            if self._top_wall and
                not top_wall_body:has_tag("slippery") and
                not top_wall_body:has_tag("no_blood") and
                math.distance(top_x, top_y, x, y) <= self._radius
            then
                _add_blood_splatter(top_x, top_y, self._last_top_x, self._last_top_y)
            end

            if self._right_wall and
                not right_wall_body:has_tag("slippery") and
                not right_wall_body:has_tag("no_blood") and
                math.distance(right_x, right_y, x, y) <= self._radius
            then
                _add_blood_splatter(right_x, right_y, self._last_right_x, self._last_right_y)
            end

            if self._bottom_wall and
                not bottom_wall_body:has_tag("slippery") and
                not bottom_wall_body:has_tag("no_blood") and
                math.distance(bottom_x, bottom_y, x, y) <= self._radius
            then
                _add_blood_splatter(bottom_x, bottom_y, self._last_bottom_x, self._last_bottom_y)
            end

            if self._left_wall and
                not left_wall_body:has_tag("slippery") and
                not left_wall_body:has_tag("no_blood") and
                math.distance(left_x, left_y, x, y) <= self._radius
            then
                _add_blood_splatter(left_x, left_y, self._last_left_x, self._last_left_y)
            end
        end
    end

    -- update position history
    do
        local last_x, last_y = self._position_history[#self._position_history - 1], self._position_history[#self._position_history]
        local current_x, current_y = self:get_position()
        local distance = math.distance(current_x, current_y, last_x, last_y)
        local dx, dy = math.normalize(current_x - last_x, current_y - last_y)
        local step = _settings.position_history_sample_frequency
        repeat
            table.insert(self._position_history, current_x)
            table.insert(self._position_history, current_y)
            table.remove(self._position_history, 1)
            table.remove(self._position_history, 1)

            current_x = current_x + dx * step
            current_y = current_y + dy * step

            distance = distance - step
        until distance < step;
    end

    if not self._is_bubble then
        self._last_position_x, self._last_position_y = self._body:get_position()
    else
        self._last_position_x, self._last_position_y = self._bubble_body:get_position()
    end

    self._last_top_x, self._last_top_y = top_x, top_y
    self._last_right_x, self._last_right_y = right_x, right_y
    self._last_bottom_x, self._last_bottom_y = bottom_x, bottom_y
    self._last_left_x, self._last_left_y = left_x, left_y
end

local _signal_id

--- @brief
function rt.Player:move_to_stage(stage)
    self._stage = stage

    if self._world ~= nil then
        self._world:signal_disconnect("step", _signal_id)
        _signal_id = nil
    end

    local world = nil
    if stage ~= nil then
        world = stage:get_physics_world()
    end

    self:move_to_world(world)

    if stage ~= nil and stage:get_active_checkpoint() ~= nil then
        stage:get_active_checkpoint():spawn(false)
    end
end

function rt.Player:move_to_world(world)
    if world ~= nil then
        meta.assert(world, b2.World)
    end

    if world == nil then
        self._stage = nil
        self._world = nil
        self._body = nil
        self._spring_bodies = {}
        self._spring_joints = {}
        self._bubble_body = nil
        self._bubble_spring_bodies = {}
        self._bubble_spring_joints = {}
        return
    end

    local x, y = 0, 0

    self._trail:clear()
    self:reset_flow()
    self._last_flow_fraction = 0
    self._gravity_multiplier = 1

    if world == self._world then return end

    self._world = world
    self._world:set_gravity(0, 0)

    self._last_position_x, self._last_position_y = x, y
    self._skip_next_flow_update = true

    local bubble_group = b2.CollisionGroup.GROUP_13
    local non_bubble_group = b2.CollisionGroup.GROUP_12

    -- hard body
    local inner_body_shape = b2.Circle(0, 0, self._inner_body_radius)
    self._body = b2.Body(
        self._world, b2.BodyType.DYNAMIC, x, y,
        inner_body_shape
    )

    function initialize_inner_body(body, is_bubble)
        body:set_is_enabled(false)
        body:set_user_data(self)
        body:set_use_continuous_collision(true)
        body:add_tag("player")
        body:set_is_rotation_fixed(true)
        body:set_collision_group(_settings.player_collision_group)
        body:set_mass(1)
        body:set_friction(0)
        body:set_use_manual_velocity(true)
        body:set_use_interpolation(true)
    end

    initialize_inner_body(self._body, false)

    -- add wrapping shape to body, for cleaner collision with bounce pads
    local bounce_shape = love.physics.newCircleShape(self._body:get_native(), x, y, self._radius * 0.8)
    local bounce_group = _settings.bounce_collision_group
    bounce_shape:setFilterData(bounce_group, bounce_group, 0)
    self._bounce_shape = b2.Circle(0, 0, self._radius * 0.8)

    -- soft body
    self._spring_bodies = {}
    self._spring_joints = {}
    self._spring_body_offsets_x = {}
    self._spring_body_offsets_y = {}

    local outer_radius = self._radius - self._outer_body_radius
    local outer_body_shape = b2.Circle(0, 0, self._outer_body_radius)
    local step = (2 * math.pi) / _settings.n_outer_bodies

    function initialize_outer_body(body, is_bubble)
        body:set_is_enabled(false)
        body:set_collision_group(_settings.player_outer_body_collision_group)
        body:set_friction(0)
        body:set_is_rotation_fixed(false)
        body:set_use_continuous_collision(true)
        body:set_user_data(self)
        body:set_use_interpolation(true)
        body:add_tag("player_outer_body")
    end

    local mask = bit.bnot(rt.settings.player.player_outer_body_collision_group)
    for angle = 0, 2 * math.pi, step do
        local offset_x = math.cos(angle) * outer_radius
        local offset_y = math.sin(angle) * outer_radius
        local cx = x + offset_x
        local cy = y + offset_y

        local body = b2.Body(self._world, b2.BodyType.DYNAMIC, cx, cy, outer_body_shape)
        initialize_outer_body(body, false)
        body:set_mass(10e-4 * _settings.outer_body_spring_strength)
        body:set_collides_with(mask)

        local joint = b2.Spring(self._body, body, x, y, cx, cy)
        joint:set_tolerance(0, 1) -- for animation only

        table.insert(self._spring_bodies, body)
        table.insert(self._spring_joints, joint)
        table.insert(self._spring_body_offsets_x, offset_x)
        table.insert(self._spring_body_offsets_y, offset_y)
    end

    self._mass = self._body:get_mass()
    for body in values(self._spring_bodies) do
        self._mass = self._mass + body:get_mass()
    end

    -- bubble

    local bubble_inner_body_shape = b2.Circle(0, 0, self._inner_body_radius * _settings.bubble_inner_radius_scale)
    self._bubble_body = b2.Body(
        self._world, b2.BodyType.DYNAMIC, x, y, bubble_inner_body_shape
    )

    initialize_inner_body(self._bubble_body, true)

    local bubble_bounce_shape = love.physics.newCircleShape(self._bubble_body:get_native(), x, y, self._radius * _settings.bubble_radius_factor * 0.8)
    bubble_bounce_shape:setFilterData(bounce_group, bounce_group, 0)
    self._bubble_bounce_shape = b2.Circle(0, 0, self._radius * _settings.bubble_radius_factor)

    self._bubble_spring_bodies = {}
    self._bubble_spring_joints = {}
    self._bubble_spring_body_offsets_x = {}
    self._bubble_spring_body_offsets_y = {}

    local bubble_outer_radius = self._bubble_radius - self._bubble_outer_body_radius
    local bubble_outer_body_shape = b2.Circle(0, 0, self._inner_body_radius) -- sic

    for angle = 0, 2 * math.pi, step do
        local offset_x = math.cos(angle) * bubble_outer_radius
        local offset_y = math.sin(angle) * bubble_outer_radius
        local cx = x + offset_x
        local cy = y + offset_y

        local body = b2.Body(self._world, b2.BodyType.DYNAMIC, cx, cy, bubble_outer_body_shape)
        initialize_outer_body(body, true)
        body:set_mass(0.001) -- experimentally determined for best bubble deformation

        local joint = b2.Spring(self._bubble_body, body, x, y, cx, cy)
        joint:set_tolerance(-0.5, 0.5) -- animation only

        table.insert(self._bubble_spring_bodies, body)
        table.insert(self._bubble_spring_joints, joint)
        table.insert(self._bubble_spring_body_offsets_x, offset_x)
        table.insert(self._bubble_spring_body_offsets_y, offset_y)
    end

    self._bubble_mass = self._bubble_body:get_mass()
    for body in values(self._bubble_spring_bodies) do
        self._bubble_mass = self._bubble_mass + body:get_mass()
    end

    if self._state == rt.PlayerState.DISABLED then
        self:disable()
    end

    local is_bubble = self._is_bubble
    self._is_bubble = nil
    self:set_is_bubble(is_bubble)
    self:set_is_ghost(self._is_ghost)

    -- reset history
    self._world:signal_connect("step", function()
        local x, y = self:get_position()
        for i = 1, 2 * _settings.position_history_n, 2 do
            self._position_history[i+0] = x
            self._position_history[i+1] = y
        end
        return meta.DISCONNECT_SIGNAL
    end)
end

function rt.Player:_update_mesh(delta, force_initialize)
    local positions
    if self._is_bubble then
        positions = {
            self._bubble_body:get_predicted_position()
        }

        for body in values(self._bubble_spring_bodies) do
            local x, y = body:get_predicted_position()
            table.insert(positions, x)
            table.insert(positions, y)
        end
    else
        positions = {
            self._body:get_predicted_position()
        }

        for body in values(self._spring_bodies) do
            local x, y = body:get_predicted_position()
            table.insert(positions, x)
            table.insert(positions, y)
        end
    end

    if self._use_bubble_mesh_delay_n_steps <= 0 then
        self._graphics_body:initialize(positions, force_initialize)
        self._graphics_body:update(delta)
    end
end

--- @brief
function rt.Player:draw_bloom()
    if self._is_visible == false then return end

    local r, g, b, a = self._color:unpack()

    if self:get_flow() == 0 then
        self._graphics_body:draw_bloom()
    elseif self._trail_visible then
        self._trail:draw_below()
        self._trail:draw_above()
    end
end

--- @brief
function rt.Player:draw_body()
    if self._is_visible == false then return end

    local r, g, b, a = self._color:unpack()

    if self._trail_visible then
        self._trail:draw_below()
    end

    self._graphics_body:draw_body()

    if self._trail_visible then
        self._trail:draw_above()
    end

    if _settings.debug_drawing_enabled then
        if not self._use_bubble_mesh then
            self._body:draw()
            for body in values(self._spring_bodies) do
                body:draw()
            end

            love.graphics.push()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.translate(self._body:get_predicted_position())
            self._bounce_shape:draw()
            love.graphics.pop()
        else
            self._bubble_body:draw()
            for body in values(self._bubble_spring_bodies) do
                body:draw()
            end

            love.graphics.push()
            love.graphics.translate(self._bubble_body:get_predicted_position())
            love.graphics.setColor(1, 1, 1, 1)
            self._bubble_bounce_shape:draw()
            love.graphics.pop()
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

    love.graphics.push()
    love.graphics.origin()
    if false then -- draw flow meter
        local w, h = 10, 100
        local x, y = 50, 50
        local padding = 1
        local y_pos = self._flow * (h - 2 * padding)
        love.graphics.setLineWidth(1)

        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", x, y, w, h, 5)

        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("line", x, y, w, h, 5)

        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", x - 0.25 * w, y + h - y_pos, w * 1.5, 3)

        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("line", x - 0.25 * w, y + h - y_pos, w * 1.5, 3)
    end
    love.graphics.pop()
end

--- @brief
function rt.Player:draw_core()
    if self._is_visible == false then return end

    self._graphics_body:draw_core()
end

--- @brief
function rt.Player:draw()
    self:draw_body()
    self:draw_core()
end

--- @brief
function rt.Player:get_position()
    if self._body == nil then return 0, 0 end

    if not self._is_bubble then
        return self._body:get_position()
    else
        return self._bubble_body:get_position()
    end
end

--- @brief
function rt.Player:get_predicted_position()
    if self._body == nil then return 0, 0 end

    if not self._is_bubble then
        return self._body:get_predicted_position()
    else
        return self._bubble_body:get_predicted_position()
    end
end

--- @brief
function rt.Player:get_velocity()
    if not self._is_bubble then
        return self._body:get_velocity()
    else
        return self._bubble_body:get_velocity()
    end
end

--- @brief
function rt.Player:teleport_to(x, y, relax_body)
    if relax_body == nil then relax_body = true end

    meta.assert(x, "Number", y, "Number")
    if self._body ~= nil then
        self._body:set_position(x, y)
        for i, body in ipairs(self._spring_bodies) do
            body:set_position(
                x + self._spring_body_offsets_x[i],
                y + self._spring_body_offsets_y[i]
            )
        end

        self._bubble_body:set_position(x, y)
        for i, body in ipairs(self._bubble_spring_bodies) do
            body:set_position(
                x + self._bubble_spring_body_offsets_x[i],
                y + self._bubble_spring_body_offsets_y[i]
            )
        end

        self._skip_next_flow_update = true

        if relax_body then
            self._graphics_body:relax()
        end
    end
end

--- @brief
function rt.Player:get_radius()
    if not self._is_bubble then
        return self._radius
    else
        return self._bubble_radius
    end
end

--- @brief
function rt.Player:set_jump_allowed(b)
    self._jump_allowed_override = b

    if b == true then
        self._jump_elapsed = 0
        self._wall_jump_elapsed = 0
    end
end

--- @brief
function rt.Player:get_physics_world()
    return self._world
end

--- @brief
function rt.Player:get_physics_body(is_bubble)
    if is_bubble == nil then
        if not self._is_bubble then
            return self._body
        else
            return self._bubble_body
        end
    elseif is_bubble == true then
        return self._bubble_body
    elseif is_bubble == false then
        return self._body
    else
        meta.assert(is_bubble, "Boolean")
    end
end

--- @brief
function rt.Player:destroy_physics_body()
    self._body:destroy()
    for body in values(self._spring_bodies) do
        body:destroy()
    end

    self._bubble_body:destroy()
    for body in values(self._bubble_spring_bodies) do
        body:destroy()
    end
end

local _before = nil

--- @brief
function rt.Player:disable()
    if self._state ~= rt.PlayerState.DISABLED then
        _before = self._state
    end

    self._state = rt.PlayerState.DISABLED
    self._up_button_is_down, self._right_button_is_down, self._down_button_is_down, self._left_button_is_down, self._jump_button_is_down = false, false, false, false, false
    -- sic, don't reset sprint
end

--- @brief
function rt.Player:enable()
    if _before == nil then
        self._state = rt.PlayerState.ACTIVE
    else
        self._state = _before
    end

    self._state = rt.PlayerState.ACTIVE
end

--- @brief
function rt.Player:set_velocity(x, y)
    meta.assert(x, "Number", y, "Number")

    if self._is_bubble and self._bubble_body ~= nil then
        self._bubble_body:set_velocity(x, y)
    elseif self._body ~= nil then
        self._body:set_velocity(x, y)
    end

    self._last_velocity_x, self._last_velocity_y = x, y
end

--- @brief
function rt.Player:get_velocity()
    return self._last_velocity_x, self._last_velocity_y
end

--- @brief
function rt.Player:set_use_wall_friction(b)
    self._use_wall_friction = b
end

--- @brief
function rt.Player:get_use_wall_friction()
    return self._use_wall_friction
end

--- @brief
function rt.Player:bounce(nx, ny)
    self._bounce_direction_x = nx
    self._bounce_direction_y = ny
    self._bounce_force = math.max(self._bounce_force, math.abs(math.dot(self._last_velocity_x, self._last_velocity_y, nx, ny)))
    self._bounce_force = math.clamp(self._bounce_force, _settings.bounce_min_force, _settings.bounce_max_force)
    self._bounce_elapsed = 0

    return self._bounce_force / _settings.bounce_max_force
end

--- @brief
function rt.Player:set_is_frozen(b)
    self._is_frozen = b
end

--- @brief
function rt.Player:set_trail_visible(b)
    meta.assert(b, "Boolean")
    if b ~= self._trail_visible then
        self._trail:clear()
    end

    self._trail_visible = b
end

--- @brief
function rt.Player:get_flow()
    return self._override_flow or self._flow
end

--- @brief
function rt.Player:set_flow(x)
    self._flow = math.clamp(x, 0, 1)
end

--- @brief
function rt.Player:reset_flow()
    self._flow = 0
    self._flow_fraction_history_sum = 0
    self._flow_fraction_history = table.rep(0, _settings.flow_fraction_history_n)
end

--- @brief
function rt.Player:set_override_flow(flow_or_nil)
    self._override_flow = flow_or_nil
end

--- @brief
function rt.Player:get_flow()
    return self._flow
end

--- @brief
function rt.Player:set_flow_velocity(x)
    self._flow_velocity = math.clamp(x, -1 * _settings.flow_max_velocity, _settings.flow_max_velocity)
end

--- @brief
function rt.Player:get_flow_velocity()
    return self._flow_velocity
end

--- @brief
function rt.Player:set_flow_is_frozen(b)
    self._flow_frozen = b
end

--- @brief
function rt.Player:get_hue()
    return self._hue
end

--- @brief
function rt.Player:set_hue(value)
    self._hue = math.fract(value)
end

--- @brief
function rt.Player:set_gravity(x)
    self._gravity_multiplier = x
end

--- @brief
function rt.Player:get_gravity()
    return self._gravity_multiplier
end

--- @brief
function rt.Player:set_is_bubble(b)
    if b == self._is_bubble then
        return
    else
        self._last_bubble_force_x = 0
        self._last_bubble_force_y = 0
        self._body_to_collision_normal = {}
    end

    local before = self._is_bubble
    self._is_bubble = b
    -- do not update self._use_bubble_mesh until solver properly updated positions

    if self._body == nil then return end

    -- disable both to avoid interaction
    self._body:set_is_enabled(false)
    for body in values(self._spring_bodies) do
        body:set_is_enabled(false)
    end

    self._bubble_body:set_is_enabled(false)
    for body in values(self._bubble_spring_bodies) do
        body:set_is_enabled(false)
    end

    if self._is_bubble == true then
        local x, y = self._body:get_position()
        self._bubble_body:set_position(x, y)
        self._bubble_body:set_velocity(self._body:get_velocity())
        for i, body in ipairs(self._bubble_spring_bodies) do
            body:set_position(
                x + self._bubble_spring_body_offsets_x[i],
                y + self._bubble_spring_body_offsets_y[i]
            )
            body:set_velocity(self._spring_bodies[i]:get_velocity())
        end
    else
        local x, y = self._bubble_body:get_position()
        self._body:set_position(x, y)
        self._body:set_velocity(self._bubble_body:get_velocity())
        for i, body in ipairs(self._spring_bodies) do
            body:set_position(
                x + self._spring_body_offsets_x[i],
                y + self._spring_body_offsets_y[i]
            )
            body:set_velocity(self._bubble_spring_bodies[i]:get_velocity())
        end
    end

    -- then update
    if not b then
        self._body:set_is_enabled(true)
        self._body:set_is_sensor(false)
        for body in values(self._spring_bodies) do
            body:set_is_enabled(true)
            body:set_is_sensor(false)
        end
    else
        self._bubble_body:set_is_enabled(true)
        self._bubble_body:set_is_sensor(false)
        for body in values(self._bubble_spring_bodies) do
            body:set_is_enabled(true)
            body:set_is_sensor(false)
        end
    end

    if before ~= b then
        self._jump_elapsed = math.huge
        self._bounce_elapsed = math.huge
    end

    -- delay to after next physics update, because solver needs time to resolve spring after synch teleport
    self._use_bubble_mesh_delay_n_steps = 4
    self._world:signal_connect("step", function()
        if self._use_bubble_mesh_delay_n_steps <= 0 then
            self._use_bubble_mesh = self._is_bubblen
            return meta.DISCONNECT_SIGNAL
        else
            self._use_bubble_mesh_delay_n_steps = self._use_bubble_mesh_delay_n_steps - 1
        end
    end)

    self:set_is_ghost(self._is_ghost)
end

--- @brief
function rt.Player:get_is_bubble()
    return self._is_bubble
end

--- @brief
function rt.Player:set_opacity(alpha)
    self._opacity = alpha
end

--- @brief
function rt.Player:get_opacity()
    return self._opacity
end

--- @brief
function rt.Player:get_state()
    return self._state
end

--- @brief
function rt.Player:get_walls()
    local out = {}
    if self._top_wall_body ~= nil then table.insert(out, self._top_wall_body) end
    if self._right_wall_body ~= nil then table.insert(out, self._right_wall_body) end
    if self._bottom_right_wall_body ~= nil then table.insert(out, self._bottom_right_wall_body) end
    if self._bottom_wall_body ~= nil then table.insert(out, self._bottom_wall_body) end
    if self._bottom_left_wall_body ~= nil then table.insert(out, self._bottom_left_wall_body) end
    if self._left_wall_body ~= nil then table.insert(out, self._left_wall_body) end
    return out
end

--- @brief
function rt.Player:get_is_idle()
    return self._idle_elapsed > _settings.idle_threshold_duration
end

--- @brief
function rt.Player:get_world()
    return self._world
end

--- @brief
function rt.Player:get_is_grounded()
    return self._bottom_left_wall or self._bottom_wall or self._bottom_right_wall
end

--- @brief
function rt.Player:get_is_colliding_with(body)
    return self._body_to_collision_normal[body] ~= nil
end

--- @brief
function rt.Player:get_collision_normal(body)
    local entry = self._body_to_collision_normal[body]
    if entry == nil then return nil end
    return entry.normal_x, entry.normal_y, entry.contact_x, entry.contact_y
end

--- @brief
function rt.Player:get_contact_point(body)
    local entry = self._body_to_collision_normal[body]
    if entry == nil then return nil end
    return entry.contact_x, entry.contact_y, entry.normal_x, entry.normal_y
end

--- @brief
function rt.Player:set_is_ghost(b)
    self._is_ghost = b

    self._body:set_is_sensor(b)
    self._bubble_body:set_is_sensor(b)

    for body in values(self._spring_bodies) do
        body:set_is_sensor(b)
    end

    for body in values(self._bubble_spring_bodies) do
        body:set_is_sensor(b)
    end
end

--- @brief
function rt.Player:get_is_ghost()
    return self._is_ghost
end

--- @brief
function rt.Player:set_collision_disabled(b)
    self._body:set_collision_disabled(b)
    for body in values(self._spring_bodies) do
        body:set_collision_disabled(true)
    end

    self._bubble_body:set_collision_disabled(b)
    for body in values(self._bubble_spring_bodies) do
        body:set_collision_disabled(true)
    end
end

--- @brief
function rt.Player:jump()
    self._jump_button_is_down = true
    self._jump_elapsed = 0

    if not self._bottom_wall then
        if (self._left_wall and not self._left_wall_jump_blocked) or (self._right_wall and not self._right_wall_jump_blocked) then
            self._wall_jump_elapsed = 0
        end
    end

    self:signal_emit("jump")
end

--- @brief
function rt.Player:add_double_jump_source(instance)
    table.insert(self._double_jump_sources, 1, instance)

    -- override lock for buffered jumps
    if self._double_jump_buffer_elapsed < _settings.double_jump_buffer_duration then
        self._double_jump_locked = false
    end
end

--- @brief
function rt.Player:get_is_double_jump_source(instance)
    if table.is_empty(self._double_jump_sources) then return false end

    for other in values(self._double_jump_sources) do
        if meta.hash(other) == meta.hash(instance) then
            return true
        end
    end
    return false
end

--- @brief
function rt.Player:get_past_position(distance)
    local n = #self._position_history
    local i = n
    local walked = 0
    local current_x, current_y = self._position_history[n-1], self._position_history[n]
    while walked < distance do
        i = i - 2
        if i < 1 then break end

        local next_x, next_y = self._position_history[i-1], self._position_history[i-0]
        walked = walked + math.distance(current_x, current_y, next_x, next_y)
        current_x, current_y = next_x, next_y
    end

    return current_x, current_y
end

--- @brief
function rt.Player:get_idle_duration()
    return self._idle_elapsed
end

--- @brief
function rt.Player:get_is_visible()
    return self._is_visible
end

--- @brief
function rt.Player:set_is_visible(b)
    self._is_visible = b
end

--- @brief
function rt.Player:set_should_update(b)
    self._should_update = b
end

--- @brief
function rt.Player:get_should_update()
    return self._should_update
end

