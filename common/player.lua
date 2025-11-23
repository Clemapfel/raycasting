require "common.input_subscriber"
require "physics.physics"
require "common.player_body"
require "common.player_trail"
require "common.player_particles"
require "common.player_dash_particles"
require "common.random"
require "common.palette"
require "common.smoothed_motion_1d"
require "common.path"
require "common.timed_animation"
require "common.direction"

do
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

        double_press_max_delay = 30 / 60,

        player_collision_group = b2.CollisionGroup.GROUP_16,
        player_outer_body_collision_group = b2.CollisionGroup.GROUP_15,
        bounce_collision_group = b2.CollisionGroup.GROUP_14,

        ghost_collision_group = b2.CollisionGroup.GROUP_12,
        ghost_outer_body_collision_group = b2.CollisionGroup.GROUP_13,

        exempt_collision_group = b2.CollisionGroup.GROUP_11,

        ground_target_velocity_x = 300,
        air_target_velocity_x = 320,
        sprint_multiplier = 2,
        accelerator_friction_coefficient = 2.5, -- factor of velocity projected onto surface tangent
        bubble_accelerator_friction_coefficient = 1.5,

        flow_increase_velocity = 1 / 200, -- percent per second
        flow_decrease_velocity = 1,
        flow_max_velocity = 1, -- percent per second
        flow_fraction_history_n = 100, -- n samples
        flow_fraction_sample_frequency = 60, -- n samples per second

        position_history_n = 1000, -- n samples
        position_history_sample_frequency = 5, -- px

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
        bounce_max_force = 600,
        bounce_relative_velocity = 2000,
        bounce_duration = 2 / 60,

        dash_duration = 3 / 60,
        instant_dash_velocity = 600,
        sustained_dash_velocity = 8000,
        dash_cooldown = 40 / 60,
        allow_air_dash = true,

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

        friction_coefficient = 14,
        friction_compression_influence = 1, -- fraction
        down_button_friction_release_duration = 30 / 60, -- s
        platform_velocity_decay = 0.98,

        max_velocity_x = 2500,
        max_velocity_y = 2500,

        squeeze_multiplier = 1.4,

        color_a = 1.0,
        color_b = 0.6,
        hue_cycle_duration = 1,
        hue_motion_velocity = 4, -- fraction per second
        pulse_duration = 0.6, -- seconds
        pulse_radius_factor = 2, -- factor

        double_jump_source_particle_density = 0.75, -- fraction

        --debug_drawing_enabled = true,
    }
end

local _settings = setmetatable({}, {
    __index = function(self, key)
        local res = require("common.debugger").get(key)
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
    "grounded",   -- touching ground after being airborne
    "duck", -- when pressing down while grounded
    "bubble" -- (Player, Boolean), when going from non-bubble to bubble or vice versa
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
        _is_visible = true,
        _should_update = true,

        _radius = player_radius,
        _inner_body_radius = _settings.inner_body_radius,
        _outer_body_radius = (player_radius * 2 * math.pi) / _settings.n_outer_bodies / 1.5,

        _bubble_radius = player_radius * _settings.bubble_radius_factor,
        _bubble_inner_body_radius = _settings.inner_body_radius * _settings.bubble_inner_radius_scale,
        _bubble_outer_body_radius = (player_radius * _settings.bubble_radius_factor * 2 * math.pi) / _settings.n_outer_bodies / 2,

        _bubble_contour_shape = rt.PlayerBodyContourType.CIRCLE,
        _core_radius = player_radius, -- set on world enter

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

        _top_left_wall = false,
        _top_left_wall_body = nil,
        _top_left_ray = {0, 0, 0, 0},

        _top_right_wall = false,
        _top_right_wall_body = nil,
        _top_right_ray = {0, 0, 0, 0},

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

        _is_grounded = false,
        _is_ducking = false,

        -- jump
        _down_elapsed = math.huge,
        _coyote_elapsed = 0,
        _spring_multiplier = 1,

        _wall_down_elapsed = 0,
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
        _use_wall_friction = true,

        _gravity = 1, -- [-1, 1]

        _movement_disabled = false,

        _platforms = {},
        _platform_velocity_x = 0,
        _platform_velocity_y = 0,
        _is_touching_platform = false,

        -- controls
        _joystick_position_x = 0, -- x axis
        _joystick_position_y = 0,
        _use_analog_input = rt.InputManager:get_input_method() == rt.InputMethod.CONTROLLER,
        _dpad_active = false,

        _left_button_is_down = false,
        _right_button_is_down = false,
        _down_button_is_down = false,
        _up_button_is_down = false,
        _jump_button_is_down = false,
        _sprint_button_is_down = false,
        _dash_button_is_down = false,

        _left_button_is_down_elapsed = 0,
        _right_button_is_down_elapsed = 0,
        _down_button_is_down_elapsed = 0,
        _up_button_is_down_elapsed = 0,
        _jump_button_is_down_elapsed = 0,
        _sprint_button_is_down_elapsed = 0,
        _dash_button_is_down_elapsed = 0,

        _sprint_multiplier = 1,
        _next_sprint_multiplier = 1,
        _next_sprint_multiplier_update_when_grounded = false,
        _sprint_toggled = false,

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
        _hue_duration = _settings.hue_cycle_duration,
        _hue_motion_current = 0,
        _hue_motion_target = 0,

        _mass = 1,
        _gravity_direction_x = 0,
        _gravity_direction_y = 1,
        _gravity_multiplier = 1,

        _can_wall_jump = false,
        _can_jump = false,
        _is_ghost = false,
        _collision_disabled = false,

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
        _double_jump_disallowed = true,

        -- air dash
        _dash_sources = {},
        _dash_elapsed = math.huge,
        _dash_cooldown_elapsed = math.huge,
        _dash_direction = rt.Direction.RIGHT,
        _dash_allowed = false,
        _is_dashing = false,
        _dash_particles = rt.PlayerDashParticles(),
        _dash_direction_x = 0,
        _dash_direction_y = -1,

        _body_to_collision_normal = {},

        _time_dilation = 1,
        _damping = 1,

        -- animation
        _pulses = {}, -- Table<love.Timestamp>
        _pulse_mesh = nil -- rt.Mesh
    })

    for i = 1, 2 * _settings.position_history_n, 2 do
        self._position_history[i+0] = 0
        self._position_history[i+1] = 0
    end
    self._position_history_path = rt.Path(self._position_history)

    self._trail = rt.PlayerTrail(self._radius)

    self._graphics_body = rt.PlayerBody({
        radius = _settings.radius,
        max_radius = _settings.radius * _settings.bubble_radius_factor
    })
    self:_connect_input()

    self._pulse_mesh = rt.MeshCircle(0, 0, 1) -- scaled in draw
    self._pulse_mesh:set_vertex_color(1, 1, 1, 1, 0)
    for i = 2, self._pulse_mesh:get_n_vertices() do
        self._pulse_mesh:set_vertex_color(i, 1, 1, 1, 1)
    end
end

--- @brief
function rt.Player:_connect_input()
    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputAction.DASH then
            self._dash_button_is_down = true
            self._dash_button_is_down_elapsed = 0

            if self._state == rt.PlayerState.DISABLED then return end

            self:dash()
        elseif which == rt.InputAction.JUMP then
            self._jump_button_is_down = true
            self._jump_button_is_down_elapsed = 0

            if self._state == rt.PlayerState.DISABLED then return end

            self:jump()

            -- unlock double jump by re-pressing mid-air
            local is_midair = self._bottom_left_wall == false and self._bottom_wall == false and self._bottom_right_wall == false
            if #self._double_jump_sources > 0 and is_midair then
                self._double_jump_disallowed = false
            end
        elseif which == rt.InputAction.SPRINT then
            self._sprint_button_is_down = true
            self._sprint_button_is_down_elapsed = 0

            self._sprint_toggled = not self._sprint_toggled
            if rt.GameState:get_player_sprint_mode() == rt.PlayerSprintMode.TOGGLE then
                self._next_sprint_multiplier = ternary(self._sprint_toggled, _settings.sprint_multiplier, 1)
            else
                self._next_sprint_multiplier = _settings.sprint_multiplier
            end
            self._next_sprint_multiplier_update_when_grounded = true
        elseif which == rt.InputAction.Y then
            -- noop
        elseif which == rt.InputAction.LEFT then
            self._left_button_is_down = true
            self._left_button_is_down_elapsed = 0
        elseif which == rt.InputAction.RIGHT then
            self._right_button_is_down = true
            self._right_button_is_down_elapsed = 0
        elseif which == rt.InputAction.DOWN then
            self._down_button_is_down = true
            self._down_button_is_down_elapsed = 0
        elseif which == rt.InputAction.UP then
            self._up_button_is_down = true
            self._up_button_is_down_elapsed = 0
        end
    end)

    self._input:signal_connect("released", function(_, which)
        if self._state == rt.PlayerState.DISABLED then return end

        if which == rt.InputAction.DASH then
            self._dash_button_is_down = false
            self._dash_button_is_down_elapsed = 0
            self._is_dashing = false -- dash needs to be held to complete

        elseif which == rt.InputAction.JUMP then
            self._jump_button_is_down = false
            self._spring_multiplier = 1
            self._jump_button_is_down_elapsed = 0
        elseif which == rt.InputAction.SPRINT then
            self._sprint_button_is_down = false
            self._sprint_button_is_down_elapsed = 0

            if rt.GameState:get_player_sprint_mode() == rt.PlayerSprintMode.HOLD then
                self._next_sprint_multiplier = 1
                self._next_sprint_multiplier_update_when_grounded = true
            end
        elseif which == rt.InputAction.LEFT then
            self._left_button_is_down = false
            self._left_button_is_down_elapsed = 0
        elseif which == rt.InputAction.RIGHT then
            self._right_button_is_down = false
            self._right_button_is_down_elapsed = 0
        elseif which == rt.InputAction.DOWN then
            self._down_button_is_down = false
            self._down_button_is_down_elapsed = 0
        elseif which == rt.InputAction.UP then
            self._up_button_is_down = false
            self._up_button_is_down_elapsed = 0
        end
    end)

    self._input:signal_connect("input_method_changed", function(_, which)
        self._use_analog_input = which == rt.InputMethod.CONTROLLER
    end)

    self._input:signal_connect("left_joystick_moved", function(_, x, y)
        if self._state == rt.PlayerState.DISABLED then return end

        self._joystick_position = x

        -- convert joystick inputs to digital
        local eps = _settings.joystick_to_analog_eps

        local before_up, before_down, before_right, before_left = self._up_button_is_down_elapsed,
            self._down_button_is_down,
            self._right_button_is_down,
            self._left_button_is_down

        self._up_button_is_down = y < -eps
        self._down_button_is_down = y > eps
        self._right_button_is_down = x > eps
        self._left_button_is_down = x < -eps

        if before_up ~= self._up_button_is_down then self._up_button_is_down_elapsed = 0 end
        if before_down ~= self._down_button_is_down then self._down_button_is_down_elapsed = 0 end
        if before_right ~= self._right_button_is_down then self._right_button_is_down_elapsed = 0 end
        if before_left ~= self._left_button_is_down then self._left_button_is_down_elapsed = 0 end
    end)

    self._input:signal_connect("controller_button_pressed", function(_, which)
        if which == rt.ControllerButton.DPAD_UP then
            self._up_button_is_down = true
            self._dpad_active = true
        elseif which == rt.ControllerButton.DPAD_RIGHT then
            self._right_button_is_down = true
            self._dpad_active = true
        elseif which == rt.ControllerButton.DPAD_DOWN then
            self._down_button_is_down = true
            self._dpad_active = true
        elseif which == rt.ControllerButton.DPAD_LEFT then
            self._left_button_is_down = true
            self._dpad_active = true
        end
    end)

    self._input:signal_connect("controller_button_released", function(_, which)
        if which == rt.ControllerButton.DPAD_UP then
            self._up_button_is_down = false
            self._dpad_active = false
        elseif which == rt.ControllerButton.DPAD_RIGHT then
            self._right_button_is_down = false
            self._dpad_active = false
        elseif which == rt.ControllerButton.DPAD_DOWN then
            self._down_button_is_down = false
            self._dpad_active = false
        elseif which == rt.ControllerButton.DPAD_LEFT then
            self._left_button_is_down = false
            self._dpad_active = false
        end
    end)

    local is_sleeping = false
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "g" then -- TODO
            self:set_is_bubble(not self:get_is_bubble())
        elseif which == "o" then
            local x, y = self:get_position()
            local r = 50
            local angle = rt.random.number(0, 2 * math.pi)
            x = x + r * math.cos(angle)
            y = y + r * math.sin(angle)
            self._graphics_body:set_attraction(x, y, 2)
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

    local t = self._time_dilation
    local should_decay_platform_velocity = true

    local function update_graphics()
        do -- notify body of new anchor positions
            local positions, center_x, center_y
            if self._is_bubble then
                center_x, center_y = self._bubble_body:get_predicted_position()
                positions = {}

                for body in values(self._bubble_spring_bodies) do
                    local x, y = body:get_predicted_position()
                    table.insert(positions, x)
                    table.insert(positions, y)
                end
            else
                local body_x, body_y = self._body:get_predicted_position()
                local dx, dy = delta * self._platform_velocity_x, delta * self._platform_velocity_y

                center_x, center_y = body_x + dx, body_y + dy
                positions = {}

                for body in values(self._spring_bodies) do
                    local x, y = body:get_predicted_position()
                    table.insert(positions, x + dx - center_x) -- body expects local coords
                    table.insert(positions, y + dy - center_y)
                end
            end

            if self._use_bubble_mesh_delay_n_steps <= 0 then
                self._graphics_body:set_shape(positions)
                self._graphics_body:set_position(center_x, center_y)
                self._graphics_body:set_color(rt.RGBA(rt.lcha_to_rgba(0.8, 1, self._hue_motion_current, 1)))

                if self:get_is_bubble() then
                    self._graphics_body:set_use_contour(true, self._bubble_contour_shape)
                else
                    self._graphics_body:set_use_contour(false)
                end

                self._graphics_body:update(delta)
            end
        end

        self._trail:set_position(self:get_position())
        self._trail:set_velocity(self:get_velocity())
        self._trail:set_hue(self:get_hue())
        self._trail:update(delta)

        self._dash_particles:update(delta)

        do
            local to_remove = {}
            for i, pulse in ipairs(self._pulses) do
                local elapsed = love.timer.getTime() - pulse.timestamp
                if elapsed > _settings.pulse_duration then
                    table.insert(to_remove, i)
                end
            end

            for i = #to_remove, 1, -1 do
                table.remove(self._pulses, i)
            end
        end

        self._hue = math.fract(self._hue + 1 / self._hue_duration * delta / 4 * math.min(self:get_flow()^0.7 + 0.1, 1))
        self._hue_motion_target = self._hue

        do -- move gradually towards hue target, periodic in [0, 1]
            local to, from = self._hue_motion_target, self._hue_motion_current
            local dist = to - from
            dist = dist + (dist > 0.5 and -1 or (dist < -0.5 and 1 or 0))

            local step = math.min(math.abs(dist), _settings.hue_motion_velocity * delta)
            if dist < 0 then step = -step end

            self._hue_motion_current = math.fract(from + step)
        end
    end

    -- detect idle
    if self._state == rt.PlayerState.ACTIVE and
        self._up_button_is_down or
        self._right_button_is_down or
        self._down_button_is_down or
        self._left_button_is_down or
        self._jump_button_is_down or
        (not self._is_bubble and self._bottom_wall == false) or
        self._state ~= rt.PlayerState.ACTIVE
    then
        self._idle_elapsed = 0
    else
        self._idle_elapsed = self._idle_elapsed + delta
    end

    local gravity = t * _settings.gravity * delta * self._gravity_multiplier

    -- if diables, simply continue velocity path
    if self._state == rt.PlayerState.DISABLED then
        local vx, vy = self._last_velocity_x, self._last_velocity_y
        vy = vy + gravity

        if self._is_bubble then
            if self._is_frozen then
                self._bubble_body:set_velocity(0, 0)
                self._last_velocity_x, self._last_velocity_y = 0, 0
            else
                self._bubble_body:set_velocity(vx, vy)
                self._last_velocity_x, self._last_velocity_y = vx, vy
            end
        else
            if self._is_frozen then
                self._body:set_velocity(0, 0)
                self._last_velocity_x, self._last_velocity_y = 0, 0
            else
                self._body:set_velocity(vx, vy)
                self._last_velocity_x, self._last_velocity_y = vx, vy
            end
        end

        update_graphics()
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

    local mask
    if self._is_ghost == false then
        mask = bit.bor(
            rt.settings.overworld.hitbox.collision_group,
            _settings.bounce_relative_velocity,
            bit.bnot(bit.bor(_settings.player_outer_body_collision_group, _settings.exempt_collision_group))
        )
    else
        mask = bit.band(_settings.ghost_collision_group, bit.bnot(_settings.exempt_collision_group))
    end

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
    local top_left_ray_length = self._radius * _settings.corner_wall_ray_length_factor * bubble_factor
    local top_right_ray_length = top_left_ray_length * bubble_factor

    local top_dx, top_dy = 0, -top_ray_length
    local right_dx, right_dy = right_ray_length, 0
    local bottom_dx, bottom_dy = 0, bottom_ray_length
    local left_dx, left_dy = -left_ray_length, 0
    local bottom_left_dx, bottom_left_dy = -bottom_left_ray_length, bottom_left_ray_length
    local bottom_right_dx, bottom_right_dy = bottom_right_ray_length, bottom_right_ray_length
    local top_left_dx, top_left_dy = -top_left_ray_length, -top_left_ray_length
    local top_right_dx, top_right_dy = top_right_ray_length, -top_right_ray_length

    local top_x, top_y, top_nx, top_ny, top_wall_body = self._world:query_ray(x, y, top_dx, top_dy, mask)
    local right_x, right_y, right_nx, right_ny, right_wall_body = self._world:query_ray(x, y, right_dx, right_dy, mask)
    local bottom_x, bottom_y, bottom_nx, bottom_ny, bottom_wall_body = self._world:query_ray(x, y, bottom_dx, bottom_dy, mask)
    local left_x, left_y, left_nx, left_ny, left_wall_body = self._world:query_ray(x, y, left_dx, left_dy, mask)
    local bottom_left_x, bottom_left_y, bottom_left_nx, bottom_left_ny, bottom_left_wall_body = self._world:query_ray(x, y, bottom_left_dx, bottom_left_dy, mask)
    local bottom_right_x, bottom_right_y, bottom_right_nx, bottom_right_ny, bottom_right_wall_body = self._world:query_ray(x, y, bottom_right_dx, bottom_right_dy, mask)
    local top_left_x, top_left_y, top_left_nx, top_left_ny, top_left_wall_body = self._world:query_ray(x, y, top_left_dx, top_left_dy, mask)
    local top_right_x, top_right_y, top_right_nx, top_right_ny, top_right_wall_body = self._world:query_ray(x, y, top_right_dx, top_right_dy, mask)

    local left_before = self._left_wall
    local right_before = self._right_wall
    local bottom_before = self._bottom_wall
    local bottom_left_before = self._bottom_left_wall
    local bottom_right_before = self._bottom_right_wall
    local top_left_before = self._top_left_wall
    local top_right_before = self._top_right_wall

    self._top_wall = top_wall_body ~= nil and not top_wall_body:get_is_sensor()
    self._top_wall_body = top_wall_body
    self._top_ray = { x, y, x + top_dx, y + top_dy }

    self._top_right_wall = top_right_wall_body ~= nil and not top_right_wall_body:get_is_sensor()
    self._top_right_wall_body = top_right_wall_body
    self._top_right_ray = { x, y, x + top_right_dx, y + top_right_dy }

    self._right_wall = right_wall_body ~= nil and not right_wall_body:get_is_sensor()
    self._right_wall_body = right_wall_body
    self._right_ray = { x, y, x + right_dx, y + right_dy }

    self._bottom_right_wall = bottom_right_wall_body ~= nil and not bottom_right_wall_body:get_is_sensor()
    self._bottom_right_wall_body = bottom_right_wall_body
    self._bottom_right_ray = { x, y, x + bottom_right_dx, y + bottom_right_dy }

    self._bottom_wall = bottom_wall_body ~= nil and not bottom_wall_body:get_is_sensor()
    self._bottom_wall_body = bottom_wall_body
    self._bottom_ray = { x, y, x + bottom_dx, y + bottom_dy }

    self._bottom_left_wall = bottom_left_wall_body ~= nil and not bottom_left_wall_body:get_is_sensor()
    self._bottom_left_wall_body = bottom_left_wall_body
    self._bottom_left_ray = { x, y, x + bottom_left_dx, y + bottom_left_dy }

    self._left_wall = left_wall_body ~= nil and not left_wall_body:get_is_sensor()
    self._left_wall_body = left_wall_body
    self._left_ray = { x, y, x + left_dx, y + left_dy }

    self._top_left_wall = top_left_wall_body ~= nil and not top_left_wall_body:get_is_sensor()
    self._top_left_wall_body = top_left_wall_body
    self._top_left_ray = { x, y, x + top_left_dx, y + top_left_dy }

    local is_grounded = false
    if not is_grounded and self._bottom_left_wall then
        if math.distance(x, y, bottom_left_x, bottom_left_y) <= self._radius then
            is_grounded = true
        end
    end

    if not is_grounded and self._bottom_wall then
        if math.distance(x, y, bottom_x, bottom_y) <= self._radius then
            is_grounded = true
        end
    end

    if not is_grounded and self._bottom_right_wall then
        if math.distance(x, y, bottom_right_x, bottom_right_y) <= self._radius then
            is_grounded = true
        end
    end

    -- when going from air to ground, signal emission and re-lock double jump
    if self._is_grounded == false and is_grounded == true then
        self:signal_emit("grounded")
        self._double_jump_disallowed = true
    end
    self._is_grounded = is_grounded

    -- check if tethers should be cleared
    if not self._is_bubble then
        local should_clear = false
        for tuple in range(
            { bottom_wall_body, bottom_x, bottom_y },
            { bottom_left_wall_body, bottom_left_x, bottom_left_y },
            { bottom_right_wall_body, bottom_right_x, bottom_right_y },
            { left_wall_body, left_x, left_y },
            { right_wall_body, right_x, right_y }
        ) do
            local body, ray_x, ray_y = table.unpack(tuple)
            if body ~= nil and body:has_tag("hitbox") then
                local distance = math.distance(x, y, ray_x, ray_y)
                if distance < self._radius then
                    should_clear = true
                    break
                end
            end
        end

        if should_clear then
            for instance in values(self._double_jump_sources) do
                if instance.signal_try_emit ~= nil then instance:signal_try_emit("removed") end
            end

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

        -- update down animation
        local is_ducking = false
        if self._down_button_is_down then
            for body in range(self._bottom_body, self._bottom_left_body, self._bottom_wall_body) do
                local entry = self._body_to_collision_normal[body]
                if entry ~= nil then
                    self._graphics_body:set_is_ducking(true,
                        entry.normal_x, entry.normal_y,
                        entry.contact_x, entry.contact_y
                    )
                    is_ducking = true
                end
            end
        end

        if not is_ducking then self._graphics_body:set_is_ducking(false) end

        if self._is_ducking == false and is_ducking == true then
            self:signal_emit("duck")
        end
        self._is_ducking = is_ducking
    end

    if not self._is_bubble then
        -- update sprint once landed
        if self._next_sprint_multiplier_update_when_grounded and (self._bottom_wall or (self._left_wall or self._right_wall)) then
            self._sprint_multiplier = self._next_sprint_multiplier
        end

        local next_velocity_x, next_velocity_y = self._last_velocity_x, self._last_velocity_y
        local current_velocity_x, current_velocity_y = self._body:get_velocity()

        -- update velocity
        local acceleration_t = 0
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

            local sprint_multiplier = self._sprint_multiplier
            local target_velocity_x = magnitude * target * sprint_multiplier

            if magnitude ~= 0 then
                -- update dash direction, remembers last intended direction
                if target_velocity_x < 0 then
                    self._dash_direction = rt.Direction.LEFT
                elseif target_velocity_x > 0 then
                    self._dash_direction = rt.Direction.RIGHT
                end
            end

            current_velocity_x = current_velocity_x - self._platform_velocity_x
            current_velocity_y = current_velocity_y - self._platform_velocity_y

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
            if self._bottom_wall == false and not (self._left_button_is_down or self._right_button_is_down or math.abs(self._joystick_position_x) > 10e-4) then
                duration = math.huge
            end

            -- if ducking, slide freely
            if not is_accelerating and self._bottom_wall == true and (self._down_button_is_down and not (self._left_button_is_down or self._right_button_is_down)) then
                duration = math.huge
            end

            duration = duration / t

            if duration == 0 then
                next_velocity_x = target_velocity_x
            else
                local velocity_change = (target_velocity_x - current_velocity_x) / duration
                next_velocity_x = current_velocity_x + velocity_change * delta
            end

            if self._dpad_active then self._use_analog_input = false end

            -- override acceleration with analog control
            if self._use_analog_input then
                next_velocity_x = self._joystick_x * next_velocity_x
            end

            if self._movement_disabled then next_velocity_x = 0 end

            if not self._bottom_wall and not self._left_wall and not self._right_wall and not self._bottom_left_wall and not self._bottom_right_wall then
                next_velocity_x = next_velocity_x * (1 - _settings.air_resistance * self._gravity_multiplier) -- air resistance
            end

            if self._use_analog_input then
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
                t * self._wall_down_elapsed < _settings.wall_jump_duration or (
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

            -- wall friction
            local net_friction_x, net_friction_y = 0, 0
            local surface_verticality_easing = function(x)
                -- narrow gaussian pushed towards x = 1
                return math.exp(-180 * (x-1) * (x-1))
            end

            local add_friction = function(
                normal_x, normal_y,
                contact_x, contact_y,
                body,
                ray_length
            )
                local player_x, player_y = self._body:get_position()
                local player_vx, player_vy = self._body:get_velocity()
                local body_velocity_x, body_velocity_y = body:get_velocity()

                local relative_vx = player_vx - body_velocity_x
                local relative_vy = player_vy - body_velocity_y

                local tangent_x, tangent_y = math.turn_right(normal_x, normal_y)

                -- velocity along tangent
                local slide_speed = math.dot(relative_vx, relative_vy, tangent_x, tangent_y)

                local friction_direction_x, friction_direction_y
                if math.abs(slide_speed) < math.eps then
                    friction_direction_x, friction_direction_y = 0, 0
                elseif slide_speed < 0 then
                    friction_direction_x, friction_direction_y = tangent_x, tangent_y
                else
                    friction_direction_x, friction_direction_y = math.flip(tangent_x, tangent_y)
                end

                -- friction should increase with player pressing into the surface
                local contact_distance = math.distance(player_x, player_y, contact_x, contact_y)
                local compression = (1 - contact_distance / ray_length) * _settings.friction_compression_influence

                local velocity_into_surface = -math.dot(relative_vx, relative_vy, normal_x, normal_y)

                -- weight friction such that walls have maximum friction, horizontal surface have none
                local surface_verticality = surface_verticality_easing(math.abs(normal_x))
                local normal_force = compression + math.max(0, velocity_into_surface)
                local max_friction_force = _settings.friction_coefficient * normal_force * surface_verticality

                if self._down_button_is_down and not self._use_analog_input then
                    -- on keyboard, press down to slowly release wall cling
                    local fraction = math.min(1, self._down_button_is_down_elapsed / _settings.down_button_friction_release_duration)
                    local factor =  rt.InterpolationFunctions.SQUARE_ACCELERATION(1 - fraction, 3.5) -- manually chosen for smoothest release
                    max_friction_force = max_friction_force * factor
                elseif self._use_analog_input then
                    -- on controller use down analog input and input pressing against wall, linear reasing
                    max_friction_force = max_friction_force * math.max(self._joystick_position_y, 0)
                end

                -- clamp to avoid moving in opposite direction
                local friction_magnitude = math.min(math.abs(slide_speed), max_friction_force)

                net_friction_x = friction_direction_x * friction_magnitude
                net_friction_y = friction_direction_y * friction_magnitude
            end

            if self._left_wall
                and not self._left_wall_body:has_tag("slippery")
                and (self._left_button_is_down or self._joystick_position_x < 0)
            then
                local vx, vy = self._left_wall_body:get_velocity()
                add_friction(
                    left_nx, left_ny,
                    left_x, left_y,
                    self._left_wall_body,
                    math.magnitude(left_dx, left_y)
                )
            end

            if self._right_wall
                and not self._right_wall_body:has_tag("slippery")
                and (self._right_button_is_down or self._joystick_position_x > 0)
            then
                local vx, vy = self._right_wall_body:get_velocity()
                add_friction(
                    right_nx, right_ny,
                    right_x, right_y,
                    self._right_wall_body,
                    math.magnitude(right_dx, right_y)
                )
            end

            if self._top_left_wall
                and not self._top_left_wall_body:has_tag("slippery")
            then
                local vx, vy = self._top_left_wall_body:get_velocity()
                add_friction(
                    top_left_nx, top_left_ny,
                    top_left_x, top_left_y,
                    self._top_left_wall_body,
                    math.magnitude(top_left_dx, top_left_y)
                )
            end

            if self._top_wall
                and not self._top_wall_body:has_tag("slippery")
            then
                local vx, vy = self._top_wall_body:get_velocity()
                add_friction(
                    top_nx, top_ny,
                    top_x, top_y,
                    self._top_wall_body,
                    math.magnitude(top_dx, top_y)
                )
            end

            if self._top_right_wall
                and not self._top_right_wall_body:has_tag("slippery")
            then
                local vx, vy = self._top_right_wall_body:get_velocity()
                add_friction(
                    top_right_nx, top_right_ny,
                    top_right_x, top_right_y,
                    self._top_right_wall_body,
                    math.magnitude(top_right_dx, top_right_y)
                )
            end

            if self._bottom_left_wall
                and not self._bottom_left_wall_body:has_tag("slippery")
                and not self._down_button_is_down
            then
                local vx, vy = self._bottom_left_wall_body:get_velocity()
                add_friction(
                    bottom_left_nx, bottom_left_ny,
                    bottom_left_x, bottom_left_y,
                    self._bottom_left_wall_body,
                    math.magnitude(bottom_left_dx, bottom_left_y)
                )
            end

            if self._bottom_wall
                and not self._bottom_wall_body:has_tag("slippery")
                and not self._down_button_is_down
            then
                local vx, vy = self._bottom_wall_body:get_velocity()
                add_friction(
                    bottom_nx, bottom_ny,
                    bottom_x, bottom_y,
                    self._bottom_wall_body,
                    math.magnitude(bottom_dx, bottom_y)
                )
            end

            if self._bottom_right_wall
                and not self._bottom_right_wall_body:has_tag("slippery")
                and not self._down_button_is_down
            then
                local vx, vy = self._bottom_right_wall_body:get_velocity()
                add_friction(
                    bottom_right_nx, bottom_right_ny,
                    bottom_right_x, bottom_right_y,
                    self._bottom_right_wall_body,
                    math.magnitude(bottom_right_dx, bottom_right_y)
                )
            end

            if current_velocity_x > 0 then
                net_friction_x = math.min(net_friction_x, 0)
            elseif current_velocity_x < 0 then
                net_friction_x = math.max(net_friction_x, 0)
            end

            if current_velocity_y > 0 then
                net_friction_y = math.min(net_friction_y, 0)
            elseif current_velocity_y < 0 then
                net_friction_y = math.max(net_friction_y, 0)
            end

            next_velocity_x = next_velocity_x + net_friction_x

            -- only apply friction when sliding down
            if net_friction_y < 0 then
                next_velocity_y = next_velocity_y + net_friction_y
            end

            -- downwards force, disabled when wall clinging, handled in friction handler
            if self._down_button_is_down
                and not self._movement_disabled
                and not ((self._left_button_is_down and left_wall_body) or (self._right_button_is_down and right_wall_body))
            then
                next_velocity_y = next_velocity_y + _settings.downwards_force * delta * t
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
                if t * self._coyote_elapsed < _settings.coyote_time then
                    can_jump = true
                end
                self._coyote_elapsed = self._coyote_elapsed + delta
            end

            -- prevent horizontal movement after walljump
            if self._wall_jump_freeze_elapsed / t < _settings.wall_jump_freeze_duration and math.sign(target_velocity_x) == self._wall_jump_freeze_sign then
                next_velocity_x = current_velocity_x
            end
            self._wall_jump_freeze_elapsed = self._wall_jump_freeze_elapsed + delta

            -- double jump buffer input
            self._double_jump_buffer_elapsed = self._double_jump_buffer_elapsed + delta

            self._can_jump = can_jump
            self._can_wall_jump = can_wall_jump

            local is_jumping = false

            if self._jump_button_is_down and not self._movement_disabled then
                if self._jump_allowed_override ~= nil then
                    -- jump override
                    if self._jump_allowed_override == true then
                        can_jump = true
                    else
                        goto skip_jump
                    end
                    self._jump_allowed_override = nil
                elseif not self._double_jump_disallowed and #self._double_jump_sources > 0 then
                    -- double jump
                    can_jump = true
                    self._down_elapsed = 0
                    self._double_jump_disallowed = true

                    -- pop oldest source
                    if self._jump_allowed_override ~= true then
                        local instance = self._double_jump_sources[#self._double_jump_sources]
                        if instance ~= nil then
                            self:remove_double_jump_source(instance)
                            local color
                            if instance.get_color ~= nil then
                                color = instance:get_color()
                                if meta.isa(color, rt.RGBA) then
                                    self:pulse(color)
                                end
                            else
                                color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, self:get_hue(), 1))
                            end

                            if instance.signal_try_emit ~= nil then instance:signal_try_emit("removed") end
                        end
                    end
                end

                if can_jump and t * self._down_elapsed < _settings.jump_duration then
                    -- regular jump: accelerate upwards wiljump  button is down
                    self._coyote_elapsed = 0
                    next_velocity_y = -t * _settings.jump_impulse * math.sqrt(self._down_elapsed / _settings.jump_duration) * self._spring_multiplier
                    self._down_elapsed = self._down_elapsed + delta
                    is_jumping = true
                elseif not can_jump and can_wall_jump then
                    -- wall jump: initial burst, then small sustain
                    if self._wall_down_elapsed == 0 then -- set by jump button
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

                        is_jumping = true
                    elseif t * self._wall_down_elapsed <= _settings.wall_jump_duration * (self._sprint_multiplier >= _settings.sprint_multiplier and _settings.non_sprint_walljump_duration_multiplier or 1)then
                        -- sustained jump, if not sprinting, add additional air time to make up for reduced x speed
                        local dx, dy = math.cos(_settings.wall_jump_sustained_angle), math.sin(_settings.wall_jump_sustained_angle)

                        if self._wall_jump_freeze_sign == 1 then dx = dx * -1 end
                        local force = _settings.wall_jump_sustained_impulse * delta + gravity
                        next_velocity_x = next_velocity_x + dx * force * t
                        next_velocity_y = next_velocity_y + dy * force * t

                        is_jumping = true
                    end
                end

                ::skip_jump::
            end

            if self._down_elapsed >= _settings.jump_duration then self._spring_multiplier = 1 end
            self._wall_down_elapsed = self._wall_down_elapsed + delta

            -- bounce
            local fraction = t * self._bounce_elapsed / _settings.bounce_duration
            if fraction <= 1 then
                if _settings.bounce_duration == 0 then
                    next_velocity_x = next_velocity_x + self._bounce_direction_x * self._bounce_force * t
                    next_velocity_y = next_velocity_y + self._bounce_direction_y * self._bounce_force * t
                else
                    local bounce_force = (1 - fraction) * self._bounce_force
                    next_velocity_x = next_velocity_x + self._bounce_direction_x * bounce_force * t
                    next_velocity_y = next_velocity_y + self._bounce_direction_y * bounce_force * t
                end
            else
                self._bounce_force = 0
            end
            self._bounce_elapsed = self._bounce_elapsed + delta

            next_velocity_y = next_velocity_y * self._damping

            -- friction
            if not self._down_button_is_down then
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
                        local friction = body:get_friction() -- accelerators have negative friction

                        local tx, ty = math.turn_left(nx, ny)
                        local vx, vy = next_velocity_x, next_velocity_y
                        local dot_product = vx * tx + vy * ty

                        local tangent_velocity_x = dot_product * tx
                        local tangent_velocity_y = dot_product * ty

                        local friction_force_x = -tangent_velocity_x * friction * _settings.accelerator_friction_coefficient
                        local friction_force_y = -tangent_velocity_y * friction * _settings.accelerator_friction_coefficient

                        -- apply tangential force
                        next_velocity_x = next_velocity_x + t * friction_force_x * delta
                        next_velocity_y = next_velocity_y + t * friction_force_y * delta

                        -- magnetize to surface
                        local flipped_x, flipped_y = math.flip(nx, ny)
                        next_velocity_x = next_velocity_x + flipped_x * delta * _settings.accelerator_magnet_force
                        next_velocity_y = next_velocity_y + flipped_y * delta * _settings.accelerator_magnet_force
                    end

                    local accelerator_max_velocity = t * _settings.accelerator_max_velocity
                    if math.magnitude(next_velocity_x, next_velocity_y) > accelerator_max_velocity then
                        next_velocity_x, next_velocity_y = math.normalize(next_velocity_x, next_velocity_y)
                        next_velocity_x = next_velocity_x * accelerator_max_velocity
                        next_velocity_y = next_velocity_y * accelerator_max_velocity
                    end
                end
            end

            local is_touching_platform = false
            do -- inherit platform velocity
                local velocity_x, velocity_y, n = 0, 0, 0

                local is_platform = {}
                for body in range(
                    self._top_wall_body,
                    self._top_right_wall_body,
                    self._right_wall_body,
                    self._bottom_right_wall_body,
                    self._bottom_wall_body,
                    self._bottom_left_wall_body,
                    self._left_wall_body
                ) do
                    local body_vx, body_vy = body:get_velocity()
                    if body:get_type() ~= b2.BodyType.STATIC and math.magnitude(body_vy, body_vy) > math.eps then
                        velocity_x = velocity_x + body_vx
                        velocity_y = velocity_y + body_vy
                        n = n + 1

                        is_platform[body] = true
                    end
                end

                is_touching_platform = (is_platform[self._top_wall_body]
                        or is_platform[self._top_left_wall_body]
                        or is_platform[self._top_right_wall_body]
                    )
                    or is_platform[self._bottom_wall_body]
                    or (math.to_number(is_platform[self._bottom_left_wall_body])
                    + math.to_number(is_platform[self._bottom_wall_body])
                    + math.to_number(is_platform[self._bottom_right_wall_body])
                ) >= 2
                    or (is_platform[self._left_wall_body] and self._left_button_is_down)
                    or (is_platform[self._right_wall_body] and self._right_button_is_down)

                if is_touching_platform == true then
                    if n == 0 then
                        self._platform_velocity_x = 0
                        self._platform_velocity_y = 0
                    else
                        self._platform_velocity_x = velocity_x / n
                        self._platform_velocity_y = velocity_y / n
                    end

                    should_decay_platform_velocity = false
                else
                    -- decay, shared after bubble logic
                end
            end

            if is_touching_platform then
                self._graphics_body:set_relative_velocity(self._platform_velocity_x, self._platform_velocity_y)
            else
                self._graphics_body:set_relative_velocity(0, 0)
            end

            self._is_touching_platform = is_touching_platform

            next_velocity_x = next_velocity_x + self._gravity_direction_x * gravity
            next_velocity_y = next_velocity_y + self._gravity_direction_y * gravity

            next_velocity_x = math.clamp(next_velocity_x, -_settings.max_velocity_x, _settings.max_velocity_x)
            next_velocity_y = math.clamp(next_velocity_y, -_settings.max_velocity_y, _settings.max_velocity_y)

            -- componensate when going up slopes, which would slow down player in stock box2d
            local before_projection_x, before_projection_y = next_velocity_x, next_velocity_y
            if not is_jumping and self._bottom_wall and (self._bottom_left_wall or self._bottom_right_wall) then
                local friction = 0
                for body in values({
                    self._bottom_left_wall_body,
                    self._bottom_right_wall_body,
                    self._bottom_wall_body
                }) do
                    friction = math.min(friction, body:get_friction())
                end

                if friction > 0 then -- skip accelerators
                    local next_magnitude = math.magnitude(next_velocity_x, next_velocity_y)
                    if next_magnitude > math.eps then
                        -- prefer normal in direction of movement, if available
                        local ground_normal_x, ground_normal_y = bottom_nx, bottom_ny
                        if next_velocity_x > 0 then
                            if self._bottom_left_wall then
                                ground_normal_x, ground_normal_y = bottom_left_nx, bottom_left_ny
                            end
                        else
                            if self._bottom_right_wall then
                                ground_normal_x, ground_normal_y = bottom_right_nx, bottom_right_ny
                            end
                        end

                        -- compute ground tangent
                        local ground_tangent_x, ground_tangent_y = 0, 0
                        if next_velocity_x > 0 then
                            ground_tangent_x, ground_tangent_y = math.turn_right(ground_normal_x, ground_normal_y)
                        elseif next_velocity_x < 0 then
                            ground_tangent_x, ground_tangent_y = math.turn_left(ground_normal_x, ground_normal_y)
                        end

                        -- if going up slopes
                        if ground_tangent_y < 0 then
                            -- project current velocity onto the ground tangent
                            local tangent_dot = math.dot(next_velocity_x, next_velocity_y, ground_tangent_x, ground_tangent_y)

                            -- calculate gravity component along the slope (opposing movement)
                            local gravity_along_slope = math.dot(0, gravity, ground_tangent_x, ground_tangent_y)

                            next_velocity_x, next_velocity_y = math.multiply2(
                                ground_tangent_x, ground_tangent_y, (tangent_dot - gravity_along_slope)
                            )
                        end
                    end
                end
            end

            do
                local before = self._is_dashing
                self._dash_cooldown_elapsed = self._dash_cooldown_elapsed + delta

                local hit, contact_x, contact_y, normal_x, normal_y = self:_get_ground_normal()
                if not hit then
                    contact_x, contact_y = self:get_position()
                    normal_x, normal_y = math.flip(math.normalize(self:get_velocity()))
                end

                if self._is_dashing then
                    local dash_fraction = math.min(self._dash_elapsed / _settings.dash_duration, 1)
                    self._dash_elapsed = self._dash_elapsed + delta
                    local t = rt.InterpolationFunctions.CONSTANT(dash_fraction, 1)

                    if (_settings.allow_air_dash or hit or self._down_button_is_down) and dash_fraction < 1 then
                        next_velocity_x = next_velocity_x + t * self._dash_direction_x * _settings.sustained_dash_velocity * delta
                        next_velocity_y = next_velocity_y + t * self._dash_direction_y * _settings.sustained_dash_velocity * delta

                        if dash_fraction == 0 then
                            self._dash_particles:start( -- start new trail
                                contact_x, contact_y,
                                normal_x, normal_y,
                                self:get_hue()
                            )
                        elseif dash_fraction <= 1 then
                            self._dash_particles:append( -- start new trail
                                contact_x, contact_y,
                                normal_x, normal_y,
                                self:get_hue()
                            )
                        end

                        if self._down_button_is_down == false and not _settings.allow_air_dash and not hit then
                            self._is_dashing = false
                        end
                    else
                        self._is_dashing = false
                    end
                end
            end

            next_velocity_x = self._platform_velocity_x + next_velocity_x * self._velocity_multiplier_x
            next_velocity_y = self._platform_velocity_y + next_velocity_y * self._velocity_multiplier_y

            self._body:set_velocity(next_velocity_x, next_velocity_y)
            self._last_velocity_x, self._last_velocity_y = before_projection_x - self._platform_velocity_x, before_projection_y - self._platform_velocity_y
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
        local bubble_gravity = t * gravity * (mass_multiplier / delta) * _settings.bubble_gravity_factor
        local max_velocity = t * _settings.bubble_target_velocity
        local target_x, target_y = 0, 0
        local current_x, current_y = self._bubble_body:get_velocity()

        if not self._use_analog_input then
            if self._left_button_is_down then
                target_x = -1
            end

            if self._right_button_is_down then
                target_x = 1
            end

            if self._up_button_is_down then
                target_y = -1
            end

            if self._down_button_is_down then
                target_y = 1
            end
        else
            target_x, target_y = self._joystick_position_x, self._joystick_position_y
        end

        local next_force_x, next_force_y
        if not (target_x == 0 and target_y == 0) then
            target_x = target_x * max_velocity * mass_multiplier
            target_y = target_y * max_velocity * mass_multiplier
            local acceleration = t * _settings.bubble_acceleration

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

                local friction_force_x = -tangent_velocity_x * friction * _settings.bubble_accelerator_friction_coefficient
                local friction_force_y = -tangent_velocity_y * friction * _settings.bubble_accelerator_friction_coefficient

                -- apply tangential force
                next_force_x = next_force_x + t * friction_force_x
                next_force_y = next_force_y + t * friction_force_y
            end
        end

        self._bubble_body:apply_force(next_force_x, next_force_y)
        self._last_bubble_force_x, self._last_bubble_force_y = next_force_x, next_force_y

        if self._bounce_elapsed <= _settings.bounce_duration then
            -- single impulse in bubble mode
            self._bubble_body:apply_linear_impulse(
                t * self._bounce_direction_x * self._bounce_force * mass_multiplier,
                t * self._bounce_direction_y * self._bounce_force * mass_multiplier
            )

            self._bounce_elapsed = math.huge
            self._bounce_force = 0
        end

        self._bubble_body:apply_force(0, bubble_gravity)
    end

    if should_decay_platform_velocity then
        local body = ternary(self._is_bubble, self._bubble_body, self._body)
        local player_nvx, player_nvy = math.normalize(body:get_velocity())
        local platform_nvx, platform_nvy = math.normalize(self._platform_velocity_x, self._platform_velocity_y)
        local decay_factor = (math.dot(player_nvx, player_nvy, platform_nvx, platform_nvy) + 1) / 2 -- 0 if misaligned, 1 if aligned

        local default_decay = _settings.platform_velocity_decay
        local decay = math.clamp(math.mix(0.8 * default_decay, default_decay, decay_factor), 0, 1)
        self._platform_velocity_x = self._platform_velocity_x * decay
        self._platform_velocity_y = self._platform_velocity_y * decay
    end

    -- detect being squished by moving objects
    if not self._is_ghost then
        local center_body, to_check, xs, ys
        if not self._is_bubble then
            center_body = self._body
            xs = self._spring_body_offsets_x
            ys = self._spring_body_offsets_y
        else
            center_body = self._bubble_body
            xs = self._bubble_spring_body_offsets_x
            ys = self._bubble_spring_body_offsets_y
        end

        local r = self:get_radius()
        local center_x, center_y = center_body:get_position()

        -- get all nearby bodies, raycast too unreliable
        local not_player_mask = bit.bnot(bit.bor(_settings.player_collision_group, _settings.player_outer_body_collision_group))
        local hitbox_mask = rt.settings.overworld.hitbox.collision_group
        local bodies = self._world:query_aabb(
            center_x - r, center_y - r, 2 * r, 2 * r,
            bit.band(not_player_mask, hitbox_mask)
        )

        -- check if all player bodies are inside at least one other body
        local is_squished = function(x, y)
            local squished = false
            for body in values(bodies) do
                if body:test_point(center_x, center_y) then
                    squished = true
                    break
                end
            end

            return squished
        end

        if is_squished(center_x, center_y) then -- least likely to be squished, early exit
            local should_kill = true
            for i = 1, #xs do
                local test_x = center_x + xs[i]
                local test_y = center_y + ys[i]

                if not is_squished(test_x, test_y) then
                    should_kill = false
                    break
                end
            end

            if should_kill then
                self._stage:get_active_checkpoint():spawn(true)
            end
        end
    end

    do -- safeguard against springs catching
        local inner_x, inner_y = self._body:get_position()
        local max_distance = self._radius + self._inner_body_radius
        for body_i, outer_body in ipairs(self._spring_bodies) do
            if math.distance(inner_x, inner_y, outer_body:get_position()) > max_distance then
                -- reset, let spring handle repositioning against geometry
                outer_body:set_position(
                    inner_x + self._spring_body_offsets_x[body_i],
                    inner_y + self._spring_body_offsets_y[body_i]
                )
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

    do -- update trail
        local flow = rt.InterpolationFunctions.SINUSOID_EASE_IN(self._flow)
        local dash = rt.InterpolationFunctions.ENVELOPE(
            1 - math.min(1, self._dash_cooldown_elapsed / _settings.dash_cooldown),
            0.05,
            0.2
        )
        dash = 0

        local value = math.max(flow, dash)
        self._trail:set_glow_intensity(value)
        self._trail:set_boom_intensity(value)
        self._trail:set_trail_intensity(value)
    end

    -- timers
    if self._down_button_is_down then self._down_button_is_down_elapsed = self._down_button_is_down_elapsed + delta end
    if self._up_button_is_down then self._up_button_is_down_elapsed = self._up_button_is_down_elapsed + delta end
    if self._left_button_is_down then self._left_button_is_down_elapsed = self._left_button_is_down_elapsed + delta end
    if self._right_button_is_down then self._right_button_is_down_elapsed = self._right_button_is_down_elapsed + delta end
    if self._jump_button_is_down then self._jump_button_is_down_elapsed = self._jump_button_is_down_elapsed + delta end
    if self._sprint_button_is_down then self._sprint_button_is_down_elapsed = self._sprint_button_is_down_elapsed + delta end

    -- add blood splatter
    if self._stage ~= nil and not self._is_ghost then
        local function _add_blood_splatter(contact_x, contact_y, last_contact_x, last_contact_y)
            local r = _settings.radius
            local cx, cy = contact_x, contact_y

            -- at high velocities, interpolate
            if last_contact_x ~= nil and last_contact_y ~= nil then
                local lcx, lcy = last_contact_x, last_contact_y
                local dx = cx - lcx
                local dy = cy - lcy
                local distance = math.sqrt(dx * dx + dy * dy)

                local step_size = r * 0.5
                local num_steps = math.max(1, math.ceil(distance / step_size))

                for i = 0, num_steps do
                    local t = i / num_steps
                    local interp_x = lcx + dx * t
                    local interp_y = lcy + dy * t

                    self._stage:get_blood_splatter():add(interp_x, interp_y, r, self._hue, 1)
                end
            else
                self._stage:get_blood_splatter():add(cx, cy, r, self._hue, 1)
            end
        end

        if self._top_left_wall
            and not top_left_wall_body:has_tag("slippery")
            and not top_left_wall_body:has_tag("no_blood")
        then
            _add_blood_splatter(top_left_x, top_left_y, self._last_top_left_x, self._last_top_left_y)
        end

        if self._top_wall
            and not top_wall_body:has_tag("slippery")
            and not top_wall_body:has_tag("no_blood")
        then
            _add_blood_splatter(top_x, top_y, self._last_top_x, self._last_top_y)
        end

        if self._top_right_wall
            and not top_right_wall_body:has_tag("slippery")
            and not top_right_wall_body:has_tag("no_blood")
        then
            _add_blood_splatter(top_right_x, top_right_y, self._last_top_right_x, self._last_top_right_y)
        end

        if self._right_wall
            and not right_wall_body:has_tag("slippery")
            and not right_wall_body:has_tag("no_blood")
        then
            _add_blood_splatter(right_x, right_y, self._last_right_x, self._last_right_y)
        end

        if self._bottom_right_wall
            and not bottom_right_wall_body:has_tag("slippery")
            and not bottom_right_wall_body:has_tag("no_blood")
        then
            _add_blood_splatter(bottom_right_x, bottom_right_y, self._last_bottom_right_x, self._last_bottom_right_y)
        end

        if self._bottom_wall
            and not bottom_wall_body:has_tag("slippery")
            and not bottom_wall_body:has_tag("no_blood")
        then
            _add_blood_splatter(bottom_x, bottom_y, self._last_bottom_x, self._last_bottom_y)
        end

        if self._bottom_left_wall
            and not bottom_left_wall_body:has_tag("slippery")
            and not bottom_left_wall_body:has_tag("no_blood")
        then
            _add_blood_splatter(bottom_left_x, bottom_left_y, self._last_bottom_left_x, self._last_bottom_left_y)
        end

        if self._left_wall
            and not left_wall_body:has_tag("slippery")
            and not left_wall_body:has_tag("no_blood")
        then
            _add_blood_splatter(left_x, left_y, self._last_left_x, self._last_left_y)
        end
    end

    -- update position history
    do
        local last_x, last_y = self._position_history[#self._position_history - 1], self._position_history[#self._position_history]
        local current_x, current_y = self:get_position()
        local distance = math.distance(current_x, current_y, last_x, last_y)
        local dx, dy = math.normalize(current_x - last_x, current_y - last_y)
        local step = _settings.position_history_sample_frequency

        table.remove(self._position_history, #self._position_history)
        table.remove(self._position_history, #self._position_history)
        table.insert(self._position_history, 1, current_y)
        table.insert(self._position_history, 1, current_x)

        self._position_history_path_needs_update = true
    end

    if not self._is_bubble then
        self._last_position_x, self._last_position_y = self._body:get_position()
    else
        self._last_position_x, self._last_position_y = self._bubble_body:get_position()
    end

    self._last_top_left_x, self._last_top_left_y = top_left_x, top_left_y
    self._last_top_x, self._last_top_y = top_x, top_y
    self._last_top_right_x, self._last_top_right_y = top_right_x, top_right_y
    self._last_right_x, self._last_right_y = right_x, right_y
    self._last_bottom_right_x, self._last_bottom_right_y = bottom_right_x, bottom_right_y
    self._last_bottom_x, self._last_bottom_y = bottom_x, bottom_y
    self._last_bottom_left_x, self._last_bottom_left_y = bottom_left_x, bottom_left_y
    self._last_left_x, self._last_left_y = left_x, left_y

    update_graphics()
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
    self._inner_collision_group = self._body:get_collision_group()
    self._inner_collision_mask = self._body:get_collides_with()

    -- add wrapping shape to body, for cleaner collision with bounce pads
    local bounce_shape = love.physics.newCircleShape(self._body:get_native(), x, y, self._radius * 1.05)
    local bounce_group = _settings.bounce_collision_group
    bounce_shape:setFilterData(bounce_group, bounce_group, 0)
    self._bounce_shape = b2.Circle(0, 0, self._radius * 0.8)
    self._bounce_physics_shape = bounce_shape

    -- soft body
    self._spring_bodies = {}
    self._spring_joints = {}
    self._spring_body_offsets_x = {}
    self._spring_body_offsets_y = {}

    local core_radius = self._radius - self._outer_body_radius
    self._core_radius = core_radius

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

    self._outer_collision_group, self._outer_collision_mask = nil, nil

    local mask = bit.bnot(rt.settings.player.player_outer_body_collision_group)
    for angle = 0, 2 * math.pi, step do
        local offset_x = math.cos(angle) * core_radius
        local offset_y = math.sin(angle) * core_radius
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

        if self._outer_collision_group == nil then self._outer_collision_group = body:get_collision_group() end
        if self._outer_collision_mask == nil then self._outer_collision_mask = body:get_collides_with() end
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
    self._bubble_bounce_physics_shape = bubble_bounce_shape

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
    self:set_collision_disabled(self._collision_disabled)

    self._graphics_body:set_world(world)

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

--- @brief
function rt.Player:draw_bloom()
    if self._is_visible == false then return end

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

    if self._trail_visible then
        self._trail:draw_below()
    end

    self._graphics_body:draw_body()

    if self._trail_visible then
        self._trail:draw_above()
    end

end

--- @brief
function rt.Player:draw_core()
    if self._is_visible == false then return end

    self._dash_particles:draw()

    local radius = self._core_radius
    local x, y = self:get_predicted_position()

    if #self._pulses > 0 then
        local time = love.timer.getTime()
               local mesh = self._pulse_mesh:get_native()
        for pulse in values(self._pulses) do
            local t = 1 - rt.InterpolationFunctions.SINUSOID_EASE_OUT((time - pulse.timestamp) / _settings.pulse_duration)

            love.graphics.push()
            love.graphics.translate(x, y)
            love.graphics.scale(2 * radius * _settings.pulse_radius_factor * (1 - t))
            love.graphics.translate(-x, -y)
            local r, g, b, a = pulse.color:unpack()
            love.graphics.setColor(r, g, b, a * t)
            love.graphics.draw(self._pulse_mesh:get_native(), x, y)
            love.graphics.pop()
        end
    end

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
    if self._is_bubble then
        return self._bubble_body:get_position()
    else
        return self._body:get_position()
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

    self._last_top_left_x, self._last_top_left_y = x, y
    self._last_top_x, self._last_top_y = x, y
    self._last_top_right_x, self._last_top_right_y = x, y
    self._last_right_x, self._last_right_y = x, y
    self._last_bottom_right_x, self._last_bottom_right_y = x, y
    self._last_bottom_x, self._last_bottom_y = x, y
    self._last_bottom_left_x, self._last_bottom_left_y = x, y
    self._last_left_x, self._last_left_y = x, y
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
function rt.Player:get_core_radius()
    return self._core_radius
end

--- @brief
function rt.Player:set_jump_allowed(b)
    self._jump_allowed_override = b

    if b == true then
        self._down_elapsed = 0
        self._wall_down_elapsed = 0
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
    self._idle_elapsed = 0

    self._up_button_is_down = self._input:get_is_down(rt.InputAction.UP)
    self._right_button_is_down = self._input:get_is_down(rt.InputAction.RIGHT)
    self._down_button_is_down = self._input:get_is_down(rt.InputAction.DOWN)
    self._left_button_is_down = self._input:get_is_down(rt.InputAction.LEFT)
    self._sprint_button_is_down = self._input:get_is_down(rt.InputAction.SPRINT)

    self._platform_velocity_x, self._platform_velocity_y = 0, 0
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
    self._platform_velocity_x = 0
    self._platform_velocity_y = 0
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
function rt.Player:bounce(nx, ny, magnitude)
    self._bounce_direction_x = nx
    self._bounce_direction_y = ny

    local nvx, nvy = self._last_velocity_x, self._last_velocity_y

    if magnitude == nil then
        magnitude = math.mix(_settings.bounce_min_force, _settings.bounce_max_force, math.min(1, math.magnitude(nvx, nvy) / _settings.bounce_relative_velocity))
    end

    self._bounce_force = magnitude
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
    self._hue_motion_target = value
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
        self._down_elapsed = math.huge
        self._bounce_elapsed = math.huge
    end

    -- delay to after next physics update, because solver needs time to resolve spring after synch teleport
    self._use_bubble_mesh_delay_n_steps = 4
    self._world:signal_connect("step", function()
        if self._use_bubble_mesh_delay_n_steps <= 0 then
            self._use_bubble_mesh = self._is_bubble
            self:signal_emit("bubble", self._is_bubble)
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
    return self._is_grounded
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
    if self._body == nil or self._bubble_body == nil then return end

    local inner_group, outer_group
    local inner_mask, outer_mask

    if b == true then
        inner_group, outer_group = _settings.ghost_collision_group, _settings.ghost_outer_body_collision_group
        inner_mask, outer_mask = _settings.ghost_collision_group, _settings.ghost_collision_group
    else
        local default = bit.bnot(0x0)
        inner_group, outer_group = self._inner_collision_group or default, self._outer_collision_group or default
        inner_mask, outer_mask = self._inner_collision_mask or default, self._outer_collision_mask or default
    end

    self._body:set_collision_group(inner_group)
    self._body:set_collides_with(inner_mask)

    self._bubble_body:set_collision_group(inner_group)
    self._bubble_body:set_collides_with(inner_mask)

    -- bounce shapes need to be reset, because body:set_collision_group also affects them
    local bounce_group = _settings.bounce_collision_group
    self._bounce_physics_shape:setFilterData(bounce_group, bounce_group, 0)
    self._bubble_bounce_physics_shape:setFilterData(bounce_group, bounce_group, 0)

    for body in values(self._spring_bodies) do
        body:set_collision_group(outer_group)
        body:set_collides_with(outer_mask)
    end

    for body in values(self._bubble_spring_bodies) do
        body:set_collision_group(outer_group)
        body:set_collides_with(outer_mask)
    end
end

--- @brief
function rt.Player:get_is_ghost()
    return self._is_ghost
end

--- @brief
function rt.Player:set_collision_disabled(b)
    self._collision_disabled = b
    if self._body == nil or self._bubble_body == nil then return end

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
    self._down_elapsed = 0

    if not self._bottom_wall then
        if (self._left_wall and not self._left_wall_jump_blocked) or (self._right_wall and not self._right_wall_jump_blocked) then
            self._wall_down_elapsed = 0
        end
    end

    self:signal_emit("jump")
end

--- @brief
function rt.Player:_get_ground_normal()
    local mask
    if self._is_ghost == false then
        mask = bit.bor(
            rt.settings.overworld.hitbox.collision_group,
            _settings.bounce_relative_velocity,
            bit.bnot(bit.bor(_settings.player_outer_body_collision_group, _settings.exempt_collision_group))
        )
    else
        mask = bit.band(_settings.ghost_collision_group, bit.bnot(_settings.exempt_collision_group))
    end

    -- check if grounded
    local body = ternary(self._is_bubble, self._bubble_body, self._body)
    local x, y = body:get_position()
    local dx, dy = math.normalize(0, 1)
    local ray_length = self._radius * _settings.bottom_wall_ray_length_factor * ternary(self._is_bubble, _settings.bubble_radius_factor, 1)

    local contact_x, contact_y, normal_x, normal_y, hit = self._world:query_ray(
        x, y, dx * ray_length, dy * ray_length, mask
    )

    hit = hit ~= nil -- convert to boolean
    return hit, contact_x, contact_y, normal_x, normal_y
end

--- @brief
function rt.Player:dash(axis_x, axis_y)
    if self._dash_direction == rt.Direction.NONE
        or self._dash_cooldown_elapsed < _settings.dash_cooldown
    then return end

    local controller_x, controller_y = rt.InputManager:get_left_joystick()

    if math.abs(controller_x) < 0.5 then controller_x = 0 end
    if math.abs(controller_y) < 0.5 then controller_y = 0 end

    local dx, dy = 0, 0
    if rt.InputManager:get_is_down(rt.InputAction.LEFT) or controller_x < 0 then
        dx = dx - 1
    end

    if rt.InputManager:get_is_down(rt.InputAction.RIGHT) or controller_x > 0 then
        dx = dx + 1
    end

    if rt.InputManager:get_is_down(rt.InputAction.UP) or controller_y < 0 then
        dy = dy - 1
    end

    if rt.InputManager:get_is_down(rt.InputAction.DOWN) or controller_y > 0 then
        dy = dy + 1
    end

    local hit, contact_x, contact_y, normal_x, normal_y = self:_get_ground_normal()
    if hit then
        if _settings.allow_air_dash and dx == 0 and dy == -1 then -- if neutral, dash upwards
            dx, dy = 0, -1
        else
            if dx < 0 then
                dx, dy = math.turn_left(normal_x, normal_y)
            elseif dx > 0 then
                dx, dy = math.turn_right(normal_x, normal_y)
            else -- else, use last known direction
                if self._dash_direction == rt.Direction.LEFT then
                    dx, dy = math.turn_left(normal_x, normal_y)
                elseif self._dash_direction == rt.Direction.RIGHT then
                    dx, dy = math.turn_right(normal_x, normal_y)
                end
            end
        end
    elseif not _settings.allow_air_dash then
        return
    end

    if math.equals(math.magnitude(dx, dy), 0) then end -- air neutral or grounded with no known direction

    self._dash_direction_x, self._dash_direction_y = math.normalize(dx, dy)
    self._is_dashing = true
    self._dash_cooldown_elapsed = 0
    self._dash_elapsed = 0
    self._graphics_body:set_is_ducking(false) -- "pump" motion

    -- instantly accelerate to dash speed
    self:set_velocity(
        self._dash_direction_x * _settings.instant_dash_velocity,
        self._dash_direction_y * _settings.instant_dash_velocity
    )
end

--- @brief
function rt.Player:add_double_jump_source(instance)
    table.insert(self._double_jump_sources, 1, instance)
end

--- @brief
function rt.Player:remove_double_jump_source(instance)
    local to_remove_is = {}
    for i, other in ipairs(self._double_jump_sources) do
        if other == instance then table.insert(to_remove_is, i) end
    end

    table.sort(to_remove_is,function(a, b) return a > b end)
    for i in values(to_remove_is) do
        table.remove(self._double_jump_sources, i)
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

--- @return Number, Number, Number, Number position_x, position_y, velocity_x, velocity_y
function rt.Player:get_past_position(distance)
    if self._position_history_path_needs_update == true then
        self._position_history_path:create_from_and_reparameterize(self._position_history)
        self._position_history_path_needs_update = nil
    end

    local length = self._position_history_path:get_length()

    local t
    if length == 0 or distance > length then
        t = 1
    else
        t = distance / length
    end

    local position_x, position_y = self._position_history_path:at(t)
    local velocity_x, velocity_y = self._position_history_path:get_tangent(t)
    return position_x, position_y, velocity_x, velocity_y
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

--- @brief
function rt.Player:get_is_ducking()
    return self._down_button_is_down and self:get_is_grounded()
end

--- @brief
function rt.Player:reset()
    self:set_jump_allowed(true)
    self:set_use_wall_friction(true)
    self:set_is_ghost(false)
    self:set_is_bubble(false)
    self:set_is_visible(true)
    self:set_is_frozen(false)
    self:set_collision_disabled(false)
    self:set_trail_visible(true)
    self:reset_flow()
    self:set_gravity(1)
    self:set_velocity(0, 0)
    self:set_time_dilation(1)

    self._platform_velocity_x = 0
    self._platform_velocity_y = 0
    if self._world ~= nil then self._world:set_time_dilation(1) end

    self._top_wall = false
    self._top_right_wall = false
    self._right_wall = false
    self._bottom_right_wall = false
    self._bottom_wall = false
    self._bottom_left_wall = false
    self._left_wall = false
    self._top_left_wall = false

    self._is_dashing = false
    self._dash_elapsed = math.huge

    self._jump_button_is_down = self._input:get_is_down(rt.InputAction.JUMP)
    self._dash_button_is_down = self._input:get_is_down(rt.InputAction.DASH)
    self._sprint_button_is_down = self._input:get_is_down(rt.InputAction.SPRINT)
    self._up_button_is_down = self._input:get_is_down(rt.InputAction.UP)
    self._down_button_is_down = self._input:get_is_down(rt.InputAction.DOWN)
    self._right_button_is_down = self._input:get_is_down(rt.InputAction.RIGHT)
    self._left_button_is_down = self._input:get_is_down(rt.InputAction.LEFT)
end

--- @brief
function rt.Player:clear_forces()
    if self._world == nil then return end

    self._body:set_velocity(0, 0)
    local px, py = self._body:get_position()
    for i, body in ipairs(self._spring_bodies) do
        body:set_velocity(0, 0)
        body:set_position(px, py)-- + self._spring_body_offsets_x[i], py + self._spring_body_offsets_y[i])
        body:set_is_enabled(false)
    end

    self._bubble_body:set_velocity(0, 0)
    px, py = self._bubble_body:get_position()
    for i, body in ipairs(self._bubble_spring_bodies) do
        body:set_velocity(0, 0)
        body:set_position(px, py)-- + self._bubble_spring_body_offsets_x[i], py + self._bubble_spring_body_offsets_y[i])
        body:set_is_enabled(false)
    end

    self._world:signal_connect("step", function(_)
        for body in values(self._spring_bodies) do
            body:set_is_enabled(not self._is_bubble)
        end

        for body in values(self._bubble_spring_bodies) do
            body:set_is_enabled(self._is_bubble)
        end

        return meta.DISCONNECT_SIGNAL
    end)

    self._last_velocity_x, self._last_velocity_y = 0, 0
    self._graphics_body:relax()
end

--- @brief
function rt.Player:set_time_dilation(t)
    self._time_dilation = math.clamp(t, math.eps, 1)
end

--- @brief
function rt.Player:set_movement_disabled(b)
    self._movement_disabled = b
end

--- @brief
function rt.Player:get_movement_disabled()
    return self._movement_disabled
end

--- @brief
function rt.Player:pulse(color_maybe)
    if color_maybe ~= nil then
        meta.assert(color_maybe, rt.RGBA)
    end

    table.insert(self._pulses, {
        timestamp = love.timer.getTime(),
        color = color_maybe or rt.RGBA(rt.lcha_to_rgba(0.8, 1, self._hue, 1))
    })
end
