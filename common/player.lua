require "common.input_subscriber"
require "physics.physics"
require "common.player_body"
require "common.player_trail"
require "common.random"
require "common.palette"
require "common.smoothed_motion_1d"
require "common.path"
require "common.timed_animation"
require "common.direction"
require "common.joystick_gesture_detector"

do
    local radius = 13.5
    rt.settings.player = {
        radius = radius,
        inner_body_radius = 10 / 2 - 0.5,
        n_outer_bodies = 27,
        max_spring_length = radius * 3,
        outer_body_spring_strength = 2,

        bottom_wall_ray_length_factor = 1.15,
        side_wall_ray_length_factor = 1.05,
        corner_wall_ray_length_factor = 0.8,
        top_wall_ray_length_factor = 1,

        joystick_magnitude_left_threshold = 0.15,
        joystick_magnitude_right_threshold = 0.15,
        joystick_magnitude_up_threshold = 0.05,
        joystick_magnitude_down_threshold = 0.05,

        player_collision_group = b2.CollisionGroup.GROUP_16,
        player_outer_body_collision_group = b2.CollisionGroup.GROUP_15,
        bounce_collision_group = b2.CollisionGroup.GROUP_14,

        ghost_collision_group = b2.CollisionGroup.GROUP_12,
        ghost_outer_body_collision_group = b2.CollisionGroup.GROUP_13,

        exempt_collision_group = b2.CollisionGroup.GROUP_11,

        sprint_multiplier = 2,
        accelerator_friction_coefficient = 2.5, -- factor of velocity projected onto surface tangent
        bubble_accelerator_friction_coefficient = 1.5,

        flow_increase_velocity = 1 / 200, -- percent per second
        flow_decrease_velocity = 1,
        flow_max_velocity = 1, -- percent per second
        flow_fraction_history_n = 100, -- n samples
        flow_fraction_sample_frequency = 60, -- n samples per second
        velocity_interpolation_history_duration = 5 / 60, -- seconds

        position_history_n = 1000, -- n samples
        position_history_sample_frequency = 5, -- px
        velocity_history_n = 3, -- n samples

        ground_acceleration_duration = 20 / 60, -- seconds
        ground_deceleration_duration = 5 / 60,

        air_acceleration_duration = 15 / 60, -- seconds
        air_deceleration_duration = 15 / 60,

        instant_turnaround_velocity = 600,

        coyote_time = 8 / 60,

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

        jump_buffer_duration = 3 / 60,

        spring_constant = 1.8,
        joint_force_threshold = 1000,
        joint_length_threshold = 100,

        spring_damping = 1000,
        spring_stiffness = 10,

        bubble_radius_factor = 2.25,
        bubble_inner_radius_scale = 1.7,
        bubble_target_velocity = 400,
        bubble_acceleration = 2.5,
        bubble_air_resistance = 0.5, -- px / s
        bubble_gravity_factor = 0.015,

        gravity = 1500, -- px / s
        air_resistance = 0.03, -- [0, 1]
        downwards_force = 3000,

        friction_coefficient = 12,
        moving_body_friction_coefficient_factor = 2, -- factor
        down_button_friction_release_duration = 10 / 60, -- s

        platform_velocity_decay = 0.98,
        max_velocity = math.huge, -- 2500

        squeeze_multiplier = 1.4,

        color_a = 1.0,
        color_b = 0.6,
        hue_cycle_duration = 1,
        hue_motion_velocity = 4, -- fraction per second
        pulse_duration = 0.6, -- seconds
        pulse_radius_factor = 2, -- factor

        double_jump_source_particle_density = 0.75, -- fraction

        input_subscriber_priority = 1,

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
    "bubble", -- (Player, Boolean), when going from non-bubble to bubble or vice versa
    "died" -- when respawning after a death
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

        _queue_turn_around = false,
        _queue_turn_around_direction = rt.Direction.NONE,

        -- jump
        _up_x = 0.5,
        _up_y = -1,

        _queue_jump_duration = math.huge, -- for buffering
        _jump_elapsed = math.huge,
        _jump_blocked = true,
        _coyote_elapsed = 0,

        _wall_jump_elapsed = math.huge,
        _left_wall_jump_blocked = true,
        _right_wall_jump_blocked = true,
        _wall_jump_freeze_elapsed = math.huge,
        _wall_jump_freeze_sign = 0,

        _jump_allowed_override = nil, -- Boolean
        _jump_disabled = nil, -- Boolean

        _bounce_direction_x = 0,
        _bounce_direction_y = 0,
        _bounce_force = 0,
        _bounce_elapsed = math.huge,

        _double_jump_buffer_elapsed = math.huge,

        _last_velocity_x = 0,
        _last_velocity_y = 0,

        _last_bubble_force_x = 0,
        _last_bubble_force_y = 0,

        _is_frozen = false,
        _use_wall_friction = true,

        _movement_disabled = false,

        _platforms = {},
        _platform_velocity_x = 0,
        _platform_velocity_y = 0,
        _is_touching_platform = false,

        -- controls
        _joystick_position_x = 0,
        _joystick_position_y = 0,

        _left_button_is_down = false,
        _right_button_is_down = false,
        _down_button_is_down = false,
        _up_button_is_down = false,
        _jump_button_is_down = false,
        _sprint_button_is_down = false,

        _left_button_is_down_elapsed = 0,
        _right_button_is_down_elapsed = 0,
        _down_button_is_down_elapsed = 0,
        _up_button_is_down_elapsed = 0,
        _jump_button_is_down_elapsed = 0,
        _sprint_button_is_down_elapsed = 0,

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

        _direction_to_damping = {
            [rt.Direction.UP] = 1,
            [rt.Direction.RIGHT] = 1,
            [rt.Direction.DOWN] = 1,
            [rt.Direction.LEFT] = 1
        },

        _can_wall_jump = false,
        _can_jump = false,
        _is_ghost = false,
        _collision_disabled = false,

        _position_override_active = false,
        _position_override_x = nil, -- Number
        _position_override_y = nil, -- Number

        -- flow
        _flow = 0,
        _override_flow = nil,
        _flow_velocity = 0,

        _flow_fraction_history = table.rep(0, _settings.flow_fraction_history_n),
        _flow_fraction_history_sum = 0,

        _flow_fraction_history_elapsed = 0,
        _last_flow_fraction = 0,
        _skip_next_flow_update = true, -- skip when spawning

        _flow_is_frozen = false,

        _position_history = {},
        _velocity_history = {},

        -- bubble
        _is_bubble = false,
        _use_bubble_mesh = false, -- cf. draw
        _use_bubble_mesh_delay_n_steps = 0,

        _input = rt.InputSubscriber(_settings.input_subscriber_priority),
        _ignore_jump_stack = 0,
        _joystick_gesture = rt.JoystickGestureDetector(),
        _idle_elapsed = 0,
        _idle_timer_frozen = false,

        -- double jump
        _double_jump_sources = {},

        _use_analog_input = rt.InputManager:get_input_method() == rt.InputMethod.CONTROLLER,

        _body_to_collision_normal = {},

        _time_dilation = 1,
        _damping = 1,

        -- animation
        _pulses = {}, -- Table<love.Timestamp>
        _pulse_mesh = nil, -- rt.Mesh,
    })

    for i = 1, 2 * _settings.position_history_n, 2 do
        self._position_history[i+0] = 0
        self._position_history[i+1] = 0
    end
    self._position_history_path = rt.Path(self._position_history)

    for i = 1, 2 * _settings.velocity_history_n, 2 do
        self._velocity_history[i+0] = 0
        self._velocity_history[i+1] = 0
    end

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

    self._up_x, self._up_y = math.normalize(self._up_x, self._up_y)
end

--- @brief
function rt.Player:_connect_input()
    self._input:signal_connect("pressed", function(_, which, count)
        if self._state == rt.PlayerState.DISABLED then return end

        local queue_sprint = function()
            self._sprint_toggled = not self._sprint_toggled
            if rt.GameState:get_player_sprint_mode() == rt.PlayerSprintMode.TOGGLE then
                self._next_sprint_multiplier = ternary(self._sprint_toggled, _settings.sprint_multiplier, 1)
            else
                self._next_sprint_multiplier = _settings.sprint_multiplier
            end
            self._next_sprint_multiplier_update_when_grounded = true
        end

        local queue_turnaround = function(direction)
            self._queue_turn_around = true
            self._queue_turn_around_direction = direction
            queue_sprint()
        end

        if which == rt.InputAction.JUMP then
            self._jump_button_is_down = true
            self._jump_button_is_down_elapsed = 0

            if self._state == rt.PlayerState.DISABLED then return end

            self._queue_jump_duration = 0
        elseif which == rt.InputAction.SPRINT then
            self._sprint_button_is_down = true
            self._sprint_button_is_down_elapsed = 0

            queue_sprint()
        elseif which == rt.InputAction.Y then
            -- noop
        elseif which == rt.InputAction.LEFT then
            self._left_button_is_down = true
            self._left_button_is_down_elapsed = 0

            -- on double press, instant turnaround
            if count == 2 then
                queue_turnaround(rt.Direction.LEFT)
            end
        elseif which == rt.InputAction.RIGHT then
            self._right_button_is_down = true
            self._right_button_is_down_elapsed = 0

            if count == 2 then
                queue_turnaround(rt.Direction.RIGHT)
            end
        elseif which == rt.InputAction.DOWN then
            self._down_button_is_down = true
            self._down_button_is_down_elapsed = 0

            if count == 2 then
                queue_turnaround(rt.Direction.DOWN)
            end
        elseif which == rt.InputAction.UP then
            self._up_button_is_down = true
            self._up_button_is_down_elapsed = 0

            if count == 2 then
                queue_turnaround(rt.Direction.UP)
            end
        end
    end)

    self._input:signal_connect("released", function(_, which, count)
        if self._state == rt.PlayerState.DISABLED then return end

        if which == rt.InputAction.JUMP then
            self._jump_button_is_down = false
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

    self._joystick_gesture:signal_connect("pressed", function(_, which, count)
        -- detect double tap gesture on joystick
        if count == 2 then
            self._queue_turn_around = true
            if which == rt.InputAction.LEFT then
                self._queue_turn_around_direction = rt.Direction.LEFT
            elseif which == rt.InputAction.RIGHT then
                self._queue_turn_around_direction = rt.Direction.RIGHT
            elseif which == rt.InputAction.DOWN then
                self._queue_turn_around_direction = rt.Direction.DOWN
            elseif which == rt.InputAction.UP then
                self._queue_turn_around_direction = rt.Direction.UP
            end
        end

        self._use_analog_input = true
    end)

    self._input:signal_connect("left_joystick_moved", function(_, x, y)
        -- direction handled in joystick gesture
        self._joystick_position_x = x
        self._joystick_position_y = y
        self._use_analog_input = true
    end)

    self._input:signal_connect("controller_button_pressed", function(_, which)
        local dpad_active = false
        if which == rt.ControllerButton.DPAD_UP then
            self._up_button_is_down = true
            dpad_active = true
        elseif which == rt.ControllerButton.DPAD_RIGHT then
            self._right_button_is_down = true
            dpad_active = true
        elseif which == rt.ControllerButton.DPAD_DOWN then
            self._down_button_is_down = true
            dpad_active = true
        elseif which == rt.ControllerButton.DPAD_LEFT then
            self._left_button_is_down = true
            dpad_active = true
        end

        if dpad_active then self._use_analog_input = false end
    end)

    self._input:signal_connect("controller_button_released", function(_, which)
        if which == rt.ControllerButton.DPAD_UP then
            self._up_button_is_down = false
        elseif which == rt.ControllerButton.DPAD_RIGHT then
            self._right_button_is_down = false
        elseif which == rt.ControllerButton.DPAD_DOWN then
            self._down_button_is_down = false
        elseif which == rt.ControllerButton.DPAD_LEFT then
            self._left_button_is_down = false
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

    local time_dilation = self._time_dilation
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

    local use_analog_input = self._use_analog_input

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
    elseif self._idle_timer_frozen == false then
        self._idle_elapsed = self._idle_elapsed + delta
    end

    local gravity = time_dilation * _settings.gravity * delta * self._gravity_multiplier

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
        mask = bit.bnot(0x0) -- everything
        mask = bit.band(mask, bit.bnot(_settings.player_outer_body_collision_group))
        mask = bit.band(mask, bit.bnot(_settings.exempt_collision_group))
    else
        mask = 0x0 -- nothing
        mask = bit.bor(mask, _settings.ghost_collision_group)
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
    local was_grounded = self._is_grounded

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
    if was_grounded == false and is_grounded == true then
        self:signal_emit("grounded")
    end
    self._is_grounded = is_grounded

    -- damping here so it's vailable for both bubble and non-bubble
    local function _apply_damping(next_velocity_x, next_velocity_y)
        if next_velocity_x < 0 then next_velocity_x = next_velocity_x * self._direction_to_damping[rt.Direction.LEFT] end
        if next_velocity_x > 0 then next_velocity_x = next_velocity_x * self._direction_to_damping[rt.Direction.RIGHT] end
        if next_velocity_y < 0 then next_velocity_y = next_velocity_y * self._direction_to_damping[rt.Direction.UP] end
        if next_velocity_y > 0 then next_velocity_y = next_velocity_y * self._direction_to_damping[rt.Direction.DOWN] end
        return next_velocity_x, next_velocity_y
    end

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

    -- input method agnostic button state
    local left_is_down = self._left_button_is_down or
        self._joystick_gesture:get_magnitude(rt.InputAction.LEFT) > _settings.joystick_magnitude_left_threshold

    local right_is_down = self._right_button_is_down or
        self._joystick_gesture:get_magnitude(rt.InputAction.RIGHT) > _settings.joystick_magnitude_right_threshold

    local up_is_down = self._up_button_is_down or
        self._joystick_gesture:get_magnitude(rt.InputAction.UP) > _settings.joystick_magnitude_up_threshold

    local down_is_down = self._down_button_is_down or
        self._joystick_gesture:get_magnitude(rt.InputAction.DOWN) > _settings.joystick_magnitude_down_threshold

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

        -- update down squish
        if self._is_bubble then
            self._graphics_body:set_down_squish(false)
            self._graphics_body:set_left_squish(false)
            self._graphics_body:set_right_squish(false)
        else
            local is_ducking = false

            -- on analog, prioritize disregarding side inputs
            local should_duck
            if self._use_analog_input then
                should_duck = self._joystick_gesture:get_magnitude(rt.InputAction.DOWN) > _settings.joystick_magnitude_down_threshold
                    and self._joystick_gesture:get_magnitude(rt.InputAction.LEFT) < _settings.joystick_magnitude_left_threshold
                    and self._joystick_gesture:get_magnitude(rt.InputAction.RIGHT) < _settings.joystick_magnitude_right_threshold
            else
                should_duck = down_is_down and not left_is_down and not right_is_down
            end

            if should_duck then
                for wall_body in range(self._bottom_body, self._bottom_left_body, self._bottom_wall_body) do
                    local entry = self._body_to_collision_normal[wall_body]
                    if entry ~= nil then
                        self._graphics_body:set_down_squish(true,
                            entry.normal_x, entry.normal_y,
                            entry.contact_x, entry.contact_y
                        )
                        is_ducking = true
                    end
                end
            end

            if not is_ducking then self._graphics_body:set_down_squish(false) end

            if self._is_ducking == false and is_ducking == true then
                self:signal_emit("duck")
            end
            self._is_ducking = is_ducking
        end

        local should_squish = function(button, ...)
            local apply = button
            for i = 1, select("#", ...) do
                if select(i, ...) == nil then
                    apply = false
                    break
                end
            end

            if apply then
                for i = 1, select("#", ...) do
                    local wall_body = select(i, ...)
                    if wall_body ~= nil then
                        local entry = self._body_to_collision_normal[wall_body]
                        if entry == nil then return end

                        return true,
                        entry.normal_x, entry.normal_y,
                        entry.contact_x, entry.contact_y
                    end
                end
            end

            return false
        end

        self._graphics_body:set_left_squish(should_squish(
            left_is_down,
            left_wall_body
        ))

        self._graphics_body:set_right_squish(should_squish(
            right_is_down,
            right_wall_body
        ))
    end

    if not self._is_bubble then
        -- update sprint once landed
        if self._next_sprint_multiplier_update_when_grounded and (
            self._bottom_wall
            or self._bottom_left_wall
            or self._bottom_right_wall_body
            or self._left_wall
            or self._right_wall
        ) then
            self._sprint_multiplier = self._next_sprint_multiplier
        end

        local current_velocity_x, current_velocity_y = self._body:get_velocity()
        local next_velocity_x, next_velocity_y = current_velocity_x, current_velocity_y

        current_velocity_x = current_velocity_x - self._platform_velocity_x
        current_velocity_y = current_velocity_y - self._platform_velocity_y

        -- x velocity update
        local input_magnitude
        if use_analog_input then
            input_magnitude = self._joystick_position_x
        else
            if self._left_button_is_down and not self._right_button_is_down then
                input_magnitude = -1
            elseif self._right_button_is_down and not self._left_button_is_down then
                input_magnitude = 1
            else
                input_magnitude = 0
            end
        end

        local sprint_multiplier = self._sprint_multiplier
        local target_velocity_x = input_magnitude * sprint_multiplier * _settings.target_velocity_x

        if input_magnitude ~= 0 then
            local velocity_delta = target_velocity_x - current_velocity_x
            local is_accelerating = (math.sign(target_velocity_x) == math.sign(current_velocity_x)) and
                (math.abs(target_velocity_x) > math.abs(current_velocity_x))

            local acceleration_duration
            if is_grounded then
                acceleration_duration = ternary(is_accelerating,
                    _settings.ground_acceleration_duration,
                    _settings.ground_deceleration_duration
                )
            else
                acceleration_duration = ternary(is_accelerating,
                    _settings.air_acceleration_duration,
                    _settings.air_deceleration_duration
                )
            end

            if acceleration_duration == 0 then
                next_velocity_x = target_velocity_x
            else
                local acceleration_rate = math.abs(target_velocity_x) / acceleration_duration
                local velocity_step = acceleration_rate * delta
                next_velocity_x = current_velocity_x + math.clamp(velocity_delta, -velocity_step, velocity_step)
            end
        else
            local decay_duration = ternary(is_grounded,
                _settings.ground_decay_duration,
                _settings.air_decay_duration
            )

            next_velocity_x = current_velocity_x * math.exp(-delta / decay_duration)
        end

        -- override on disable
        if self._movement_disabled then next_velocity_x = 0 end

        -- wall friction
        local net_friction_x, net_friction_y = 0, 0
        do
            -- use average velocity instead of current for friction stability
            local average_vx, average_vy = 0, 0
            local max_magnitude = -math.huge
            for i = 1, #self._velocity_history, 2 do
                average_vx = average_vx + self._velocity_history[i+0]
                average_vy = average_vy + self._velocity_history[i+1]
                max_magnitude = math.max(max_magnitude, math.magnitude(self._velocity_history[i+0], self._velocity_history[i+1]))
            end

            do
                average_vx = average_vx / _settings.velocity_history_n
                average_vy = average_vy / _settings.velocity_history_n
                local sign_x, sign_y = math.sign(average_vx), math.sign(average_vy)
                average_vx, average_vy = math.normalize(average_vx, average_vy)
                average_vx = average_vx * max_magnitude
                average_vy = average_vy * max_magnitude
            end

            -- apply friction along tangent, also magnetize towards surface
            local apply_friction = function(normal_x, normal_y, body, contact_x, contact_y, ray_length)
                local player_vx, player_vy = average_vx, average_vy
                local body_vx, body_vy = body:get_velocity()

                -- compute relative velocity
                player_vx = player_vx - body_vx
                player_vy = player_vy - body_vy

                -- only apply friction to mostly vertical walls
                local wall_coefficient = math.dot(normal_x, normal_y, 0, 1) + 1
                local slope_factor = 1 - math.abs(wall_coefficient - 1)

                -- if ground slope, no friction
                if slope_factor < 0.5 then return end

                -- else weigh by how close to vertical the wall is
                slope_factor = (slope_factor - 0.5) * 2

                -- get tangent
                local tangent_x, tangent_y = math.turn_right(normal_x, normal_y)
                if math.dot(player_vx, player_vy, tangent_x, tangent_y) > 0 then
                    tangent_x, tangent_y = math.flip(tangent_x, tangent_y)
                end

                -- increase if body is moving in opposite direction
                local relative_nvx, relative_nvy = math.normalize(
                    math.reverse_subtract(
                        body_vx, body_vy,
                        self._body:get_velocity() -- use sim velocity instead of average
                    )
                )
                local opposing_motion = 1 + math.max(0,
                    math.dot(
                        -1 * relative_nvx,
                        -1 * relative_nvy,
                        math.normalize(body_vx, body_vy)
                    )
                )

                local moving_body_factor = 1 + opposing_motion * _settings.moving_body_friction_coefficient_factor

                local input_modifier = 1.0
                if use_analog_input then
                    local push_factor = math.dot(
                        self._joystick_position_x,
                        self._joystick_position_y,
                        -normal_x, -normal_y
                    )
                    input_modifier = math.max(0, push_factor)
                elseif down_is_down then
                    local release_progress = math.min(1, self._down_button_is_down_elapsed / _settings.down_button_friction_release_duration)
                    input_modifier = 1 - release_progress -- linear easing
                end

                local friction_force = moving_body_factor * input_modifier * slope_factor * _settings.friction_coefficient
                net_friction_x = net_friction_x + tangent_x * friction_force
                net_friction_y = net_friction_y + tangent_y * friction_force

                local px, py = self._body:get_position()
                local dx, dy = math.normalize(math.subtract(px, py, contact_x, contact_x))
                local penetration = math.min(1, math.distance(px, py, contact_x, contact_y) / self._radius)
                net_friction_x = net_friction_x + normal_x * friction_force * penetration
                net_friction_y = net_friction_y + normal_y * friction_force * penetration
            end

            if self._left_wall
                and not self._left_wall_body:has_tag("slippery")
                and left_is_down
            then
                apply_friction(
                    left_nx, left_ny,
                    self._left_wall_body,
                    left_x, left_y, left_ray_length
                )
            end

            if self._right_wall
                and not self._right_wall_body:has_tag("slippery")
                and right_is_down
            then
                apply_friction(
                    right_nx, right_ny,
                    self._right_wall_body,
                    right_x, right_y, right_ray_length
                )
            end

            if self._top_left_wall
                and not self._top_left_wall_body:has_tag("slippery")
            then
                local vx, vy = self._top_left_wall_body:get_velocity()
                apply_friction(
                    top_left_nx, top_left_ny,
                    self._top_left_wall_body,
                    top_left_x, top_left_y, top_left_ray_length
                )
            end

            if self._top_wall
                and not self._top_wall_body:has_tag("slippery")
            then
                local vx, vy = self._top_wall_body:get_velocity()
                apply_friction(
                    top_nx, top_ny,
                    self._top_wall_body,
                    top_x, top_y, top_ray_length
                )
            end

            if self._top_right_wall
                and not self._top_right_wall_body:has_tag("slippery")
            then
                local vx, vy = self._top_right_wall_body:get_velocity()
                apply_friction(
                    top_right_nx, top_right_ny,
                    self._top_right_wall_body,
                    top_right_x, top_right_y, top_right_ray_length
                )
            end

            if self._bottom_left_wall
                and not self._bottom_left_wall_body:has_tag("slippery")
                and not down_is_down
            then
                local vx, vy = self._bottom_left_wall_body:get_velocity()
                apply_friction(
                    bottom_left_nx, bottom_left_ny,
                    self._bottom_left_wall_body,
                    bottom_left_x, bottom_left_y, bottom_ray_length
                )
            end

            if self._bottom_wall
                and not self._bottom_wall_body:has_tag("slippery")
                and not down_is_down
            then
                local vx, vy = self._bottom_wall_body:get_velocity()
                apply_friction(
                    bottom_nx, bottom_ny,
                    self._bottom_wall_body,
                    bottom_x, bottom_y, bottom_ray_length
                )
            end

            if self._bottom_right_wall
                and not self._bottom_right_wall_body:has_tag("slippery")
                and not down_is_down
            then
                local vx, vy = self._bottom_right_wall_body:get_velocity()
                apply_friction(
                    bottom_right_nx, bottom_right_ny,
                    self._bottom_right_wall_body,
                    bottom_right_x, bottom_right_y, bottom_right_ray_length
                )
            end

            -- prevent friction moving player backwards
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
        end -- wall friction

        -- vertical movement
        next_velocity_y = current_velocity_y

        if is_grounded then
            self._jump_blocked = false
        end

        if is_grounded or (left_before == true and self._left_wall == false) then
            self._left_wall_jump_blocked = false
        end

        if is_grounded or (right_before == true and self._right_wall == false) then
            self._right_wall_jump_blocked = false
        end

        -- buffered jump
        if self._queue_jump_duration < _settings.jump_buffer_duration then
            if self:jump() == true then
                self._queue_jump_duration = math.huge
            end
        end
        self._queue_jump_duration = self._queue_jump_duration + delta

        -- prevent horizontal movement after walljump
        if self._wall_jump_freeze_elapsed / time_dilation < _settings.wall_jump_freeze_duration
            and math.sign(target_velocity_x) == self._wall_jump_freeze_sign
        then
            next_velocity_x = current_velocity_x
        end

        local should_apply_friction = true
        local is_jumping = false

        if self._jump_elapsed < _settings.jump_duration then
            -- regular jump
            if self._jump_button_is_down then
                next_velocity_y = -1 * time_dilation * _settings.jump_impulse * math.sqrt(self._jump_elapsed / _settings.jump_duration)
                is_jumping = true
            end
        elseif self._wall_jump_elapsed < _settings.wall_jump_duration then
            -- wall jump: initial burst, then small sustain
            if self._wall_jump_elapsed == 0 then
                local dx, dy = math.cos(_settings.wall_jump_initial_angle), math.sin(_settings.wall_jump_initial_angle)

                if self._right_wall then dx = dx * -1 end
                local burst = _settings.wall_jump_initial_impulse + gravity
                next_velocity_x, next_velocity_y = dx * burst, dy * burst

                self._wall_jump_freeze_elapsed = 0

                if self._left_wall then
                    self._wall_jump_freeze_sign = -1
                elseif self._right_wall then
                    self._wall_jump_freeze_sign =  1
                end

                should_apply_friction = false
                is_jumping = true
            elseif self._jump_button_is_down then
                -- sustained jump, if not sprinting, add additional air time to make up for reduced x speed
                local dx, dy = math.cos(_settings.wall_jump_sustained_angle), math.sin(_settings.wall_jump_sustained_angle)

                if self._wall_jump_freeze_sign == 1 then dx = dx * -1 end
                local force = _settings.wall_jump_sustained_impulse * delta + gravity
                next_velocity_x = next_velocity_x + dx * force * time_dilation
                next_velocity_y = next_velocity_y + dy * force * time_dilation

                is_jumping = true
            end
        end

        self._wall_jump_freeze_elapsed = self._wall_jump_freeze_elapsed + delta
        self._jump_elapsed = self._jump_elapsed + delta
        self._wall_jump_elapsed = self._wall_jump_elapsed + delta
        self._coyote_elapsed = self._coyote_elapsed + delta

        if is_grounded then
            self._coyote_elapsed = 0

            -- when touching ground, reset all jump states
            if was_grounded == false then
                self._wall_jump_elapsed = math.huge
                self._wall_jump_freeze_elapsed = math.huge
                self._jump_elapsed = math.huge
            end
        end

        -- bounce
        local fraction = time_dilation * self._bounce_elapsed / _settings.bounce_duration
        if fraction <= 1 then
            if _settings.bounce_duration == 0 then
                next_velocity_x = next_velocity_x + self._bounce_direction_x * self._bounce_force * time_dilation
                next_velocity_y = next_velocity_y + self._bounce_direction_y * self._bounce_force * time_dilation
            else
                local bounce_force = (1 - fraction) * self._bounce_force
                next_velocity_x = next_velocity_x + self._bounce_direction_x * bounce_force * time_dilation
                next_velocity_y = next_velocity_y + self._bounce_direction_y * bounce_force * time_dilation
            end
        else
            self._bounce_force = 0
        end
        self._bounce_elapsed = self._bounce_elapsed + delta

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
            if body ~= nil and (body:has_tag("use_friction") or body:get_friction() < 0) then
                local friction = body:get_friction()

                local tx, ty = math.turn_left(nx, ny)
                local vx, vy = next_velocity_x, next_velocity_y
                local dot_product = vx * tx + vy * ty

                local tangent_velocity_x = dot_product * tx
                local tangent_velocity_y = dot_product * ty

                local friction_force_x = -tangent_velocity_x * friction * _settings.accelerator_friction_coefficient
                local friction_force_y = -tangent_velocity_y * friction * _settings.accelerator_friction_coefficient

                -- apply tangential force
                next_velocity_x = next_velocity_x + time_dilation * friction_force_x * delta
                next_velocity_y = next_velocity_y + time_dilation * friction_force_y * delta

                -- magnetize to surface
                local flipped_x, flipped_y = math.flip(nx, ny)
                next_velocity_x = next_velocity_x + flipped_x * delta * _settings.accelerator_magnet_force
                next_velocity_y = next_velocity_y + flipped_y * delta * _settings.accelerator_magnet_force

                should_apply_friction = false
            end

            local accelerator_max_velocity = time_dilation * _settings.accelerator_max_velocity
            if math.magnitude(next_velocity_x, next_velocity_y) > accelerator_max_velocity then
                next_velocity_x, next_velocity_y = math.normalize(next_velocity_x, next_velocity_y)
                next_velocity_x = next_velocity_x * accelerator_max_velocity
                next_velocity_y = next_velocity_y * accelerator_max_velocity
            end
        end

        -- downwards force
        if not self._movement_disabled
            and down_is_down
            and not ((left_is_down and self._left_wall) or (right_is_down and self._right_wall))
            -- exclude wall clinging, handled by explicit friction release in apply_friction
        then
            next_velocity_x = next_velocity_x + self._gravity_direction_x * _settings.downwards_force * delta
            next_velocity_y = next_velocity_y + self._gravity_direction_y * _settings.downwards_force * delta
        end

        local is_touching_platform = false
        do -- inherit platform velocity
            local velocity_x, velocity_y, n = 0, 0, 0
            local min_magnitude = 0

            local chosen_body = nil
            if down_is_down then
                for first in range( -- automatically skips nils
                    self._bottom_wall_body,
                    self._bottom_left_wall_body,
                    self._bottom_right_wall_body
                ) do
                    chosen_body = first
                    break
                end
            elseif left_is_down and self._left_wall_body then
                for first in range(
                    self._left_wall_body,
                    self._bottom_left_wall_body,
                    self._bottom_wall_body,
                    self._bottom_right_wall_body
                ) do
                    chosen_body = first
                    break
                end
            elseif right_is_down and self.right_wall_body then
                for first in range(
                    self._right_wall_body,
                    self._bottom_left_wall_body,
                    self._bottom_wall_body,
                    self._bottom_right_wall_body
                ) do
                    chosen_body = first
                    break
                end
            else
                for body in range( -- priority queue
                    self._left_wall_body,
                    self._right_wall_body,

                    self._bottom_wall_body,
                    self._bottom_left_wall_body,
                    self._bottom_right_wall_body,

                    self._top_wall_body,
                    self._top_left_wall_body,
                    self._top_right_wall_body
                ) do
                    local body_vx, body_vy = body:get_velocity()
                    local magnitude = math.magnitude(body_vx, body_vy)
                    if body:get_type() ~= b2.BodyType.STATIC and not body:get_is_sensor() then
                        velocity_x, velocity_y = body_vx, body_vy
                        min_magnitude = magnitude
                        chosen_body = body
                    end
                end
            end

            is_touching_platform = chosen_body ~= nil

            if is_touching_platform then
                self._platform_velocity_x, self._platform_velocity_y = chosen_body:get_velocity()
                should_decay_platform_velocity = false
            else
                should_decay_platform_velocity = true
                -- decay, shared after bubble logic
            end
        end

        if is_touching_platform then
            self._graphics_body:set_relative_velocity(self._platform_velocity_x, self._platform_velocity_y)
        else
            self._graphics_body:set_relative_velocity(0, 0)
        end

        self._is_touching_platform = is_touching_platform

        -- friction
        if should_apply_friction then
            next_velocity_x = next_velocity_x + net_friction_x
            next_velocity_y = next_velocity_y + net_friction_y
        end

        -- gravity
        next_velocity_x = next_velocity_x + self._gravity_direction_x * gravity
        next_velocity_y = next_velocity_y + self._gravity_direction_y * gravity

        -- clamp
        next_velocity_x = math.clamp(next_velocity_x, -_settings.max_velocity, _settings.max_velocity)
        next_velocity_y = math.min(next_velocity_y, _settings.max_velocity) -- downwards unbounded

        -- componensate when going up slopes, which would slow down player in stock box2d
        if not is_jumping and self._bottom_wall and (self._bottom_left_wall or self._bottom_right_wall) then
            local should_skip = false
            for body in range(
                self._bottom_left_wall_body,
                self._bottom_right_wall_body,
                self._bottom_wall_body
            ) do
                if body:has_tag("use_friction") then
                    should_skip = true
                    break
                end
            end

            if not should_skip then
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

        -- instant turn around
        if self._queue_turn_around == true then
            local vx, vy = current_velocity_x, current_velocity_y
            if self._queue_turn_around_direction == rt.Direction.RIGHT and is_grounded then
                next_velocity_x = math.max(math.abs(vx), _settings.instant_turnaround_velocity)
            elseif self._queue_turn_around_direction == rt.Direction.LEFT and is_grounded then
                next_velocity_x = -1 * math.max(math.abs(vx), _settings.instant_turnaround_velocity)
            elseif self._queue_turn_around_direction == rt.Direction.DOWN then -- even in air
                next_velocity_y = math.max(math.abs(vy), _settings.instant_turnaround_velocity)
            end

            -- noop on rt.Direction.UP
            self._queue_turn_around = false
        end

        next_velocity_x, next_velocity_y = _apply_damping(next_velocity_x, next_velocity_y)
        next_velocity_x = self._platform_velocity_x + next_velocity_x
        next_velocity_y = self._platform_velocity_y + next_velocity_y

        self._body:set_velocity(next_velocity_x, next_velocity_y)
        self._last_velocity_x, self._last_velocity_y = next_velocity_x, next_velocity_y

        ::skip_velocity_update::

        if self._is_frozen then
            self._body:set_velocity(next_velocity_x, next_velocity_y)
            self._last_velocity_x, self._last_velocity_y = next_velocity_x, next_velocity_y
        end
    else -- self._is_bubble == true
        -- bubble movement
        local mass_multiplier = self._bubble_mass / self._mass
        local bubble_gravity = time_dilation * gravity * (mass_multiplier / delta) * _settings.bubble_gravity_factor
        local max_velocity = time_dilation * _settings.bubble_target_velocity
        local target_x, target_y = 0, 0
        local current_x, current_y = self._bubble_body:get_velocity()

        if not self._movement_disabled then
            if not use_analog_input then
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
                local threshold = _settings.joystick_magnitude_threshold
                if self._joystick_gesture:get_magnitude(rt.InputAction.LEFT) > threshold then
                    target_x = -1
                end

                if self._joystick_gesture:get_magnitude(rt.InputAction.RIGHT) > threshold then
                    target_x = 1
                end

                if self._joystick_gesture:get_magnitude(rt.InputAction.UP) > threshold then
                    target_y = -1
                end

                if self._joystick_gesture:get_magnitude(rt.InputAction.DOWN) > threshold then
                    target_y = 1
                end
            end
        end

        local next_force_x, next_force_y
        if not (target_x == 0 and target_y == 0) then
            target_x = target_x * max_velocity * mass_multiplier
            target_y = target_y * max_velocity * mass_multiplier
            local acceleration = time_dilation * _settings.bubble_acceleration

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
                next_force_x = next_force_x + time_dilation * friction_force_x
                next_force_y = next_force_y + time_dilation * friction_force_y
            end
        end

        self._bubble_body:apply_force(_apply_damping(next_force_x, next_force_y))
        self._last_bubble_force_x, self._last_bubble_force_y = next_force_x, next_force_y

        if self._bounce_elapsed <= _settings.bounce_duration then
            -- single impulse in bubble mode
            self._bubble_body:apply_linear_impulse(
                time_dilation * self._bounce_direction_x * self._bounce_force * mass_multiplier,
                time_dilation * self._bounce_direction_y * self._bounce_force * mass_multiplier
            )

            self._bounce_elapsed = math.huge
            self._bounce_force = 0
        end

        self._bubble_body:apply_force(0, bubble_gravity)
    end

    if should_decay_platform_velocity then
        local player_nvx, player_nvy = math.normalize(self:get_velocity())
        local platform_nvx, platform_nvy = math.normalize(self._platform_velocity_x, self._platform_velocity_y)
        local decay_factor = math.clamp(math.dot(player_nvx, player_nvy, platform_nvx, platform_nvy), 0, 1) -- 0 if misaligned, 1 if aligned

        local default_decay = _settings.platform_velocity_decay
        local decay = decay_factor * default_decay
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
        local value = rt.InterpolationFunctions.SINUSOID_EASE_IN(self._flow)
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
            local r = self:get_radius()
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
                    local interpolation_x = lcx + dx * t
                    local interpolation_y = lcy + dy * t

                    if math.distance(
                        self._last_position_x, self._last_position_y,
                        interpolation_x, interpolation_y
                    ) < r then
                        self._stage:get_blood_splatter():add(interpolation_x, interpolation_y, r, self._hue, 1)
                    end
                end
            else
                if math.distance(self._last_position_x, self._last_position_y, cx, cy) < r then
                    self._stage:get_blood_splatter():add(cx, cy, r, self._hue, 1)
                end
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

        if self._position_override_active then
            if self._position_override_x ~= nil then
                current_x = self._position_override_x
            end

            if self._position_override_y ~= nil then
                current_y = self._position_override_y
            end
        end

        local distance = math.distance(current_x, current_y, last_x, last_y)
        local dx, dy = math.normalize(current_x - last_x, current_y - last_y)
        local step = _settings.position_history_sample_frequency

        table.remove(self._position_history, #self._position_history)
        table.remove(self._position_history, #self._position_history)
        table.insert(self._position_history, 1, current_y)
        table.insert(self._position_history, 1, current_x)

        self._position_history_path_needs_update = true
    end

    -- update velocity history
    do
        local body = ternary(self._is_bubble, self._bubble_body, self._body)
        local current_vx, current_vy = body:get_velocity() -- use sim velocity
        local n = #self._velocity_history
        table.remove(self._velocity_history, #self._velocity_history)
        table.remove(self._velocity_history, #self._velocity_history)
        table.insert(self._velocity_history, 1, current_vy)
        table.insert(self._velocity_history, 1, current_vx)
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

    self._input:signal_emit("pressed", rt.InputAction.SPRINT) -- start map with sprint active
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

    local inner_mask = bit.bnot(_settings.exempt_collision_group)
    function initialize_inner_body(body, is_bubble)
        body:set_is_enabled(false)
        body:set_user_data(self)
        body:set_use_continuous_collision(true)
        body:add_tag("player")
        body:set_is_rotation_fixed(true)
        body:set_collision_group(_settings.player_collision_group)
        body:set_collides_with(inner_mask)
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

    local outer_mask = bit.bnot(bit.bor(
        _settings.player_outer_body_collision_group,
        _settings.exempt_collision_group
    ))
    function initialize_outer_body(body, is_bubble)
        body:set_is_enabled(false)
        body:set_collision_group(_settings.player_outer_body_collision_group)
        body:set_collides_with(outer_mask)
        body:set_friction(0)
        body:set_is_rotation_fixed(false)
        body:set_use_continuous_collision(true)
        body:set_user_data(self)
        body:set_use_interpolation(true)
        body:add_tag("player_outer_body")
    end

    self._outer_collision_group, self._outer_collision_mask = nil, nil

    for angle = 0, 2 * math.pi, step do
        local offset_x = math.cos(angle) * core_radius
        local offset_y = math.sin(angle) * core_radius
        local cx = x + offset_x
        local cy = y + offset_y

        local body = b2.Body(self._world, b2.BodyType.DYNAMIC, cx, cy, outer_body_shape)
        initialize_outer_body(body, false)
        body:set_mass(10e-4 * _settings.outer_body_spring_strength)

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

--- @brief average position, takes deformation into account
function rt.Player:get_centroid()
    if self._body == nil then return 0, 0 end
    local body, outer_bodies
    if self._is_bubble then
        body = self._bubble_body
        outer_bodies = self._bubble_spring_bodies
    else
        body = self._body
        outer_bodies = self._spring_bodies
    end

    local x, y = body:get_position()
    local n = 1
    for other in values(outer_bodies) do
        local other_x, other_y = other:get_position()
        x = x + other_x
        y = y + other_y
        n = n + 1
    end

    return x / n, y / n
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
    if self._body ~= nil and self._bubble_body ~= nil then
        if not self._is_bubble then
            self._body:set_is_enabled(false)
            for body in values(self._spring_bodies) do body:set_is_enabled(false) end

            self._body:set_position(x, y)
            for i, body in ipairs(self._spring_bodies) do
                body:set_position(
                    x + self._spring_body_offsets_x[i],
                    y + self._spring_body_offsets_y[i]
                )
            end

            self._world:signal_connect("step", function(_)
                self._body:set_is_enabled(true)
                for body in values(self._spring_bodies) do body:set_is_enabled(true) end

                return meta.DISCONNECT_SIGNAL
            end)
        else
            self._bubble_body:set_is_enabled(false)
            for body in values(self._bubble_spring_bodies) do body:set_is_enabled(false) end

            self._bubble_body:set_position(x, y)
            for i, body in ipairs(self._bubble_spring_bodies) do
                body:set_position(
                    x + self._bubble_spring_body_offsets_x[i],
                    y + self._bubble_spring_body_offsets_y[i]
                )
            end

            self._world:signal_connect("step", function(_)
                self._bubble_body:set_is_enabled(true)
                for body in values(self._bubble_spring_bodies) do body:set_is_enabled(true) end

                return meta.DISCONNECT_SIGNAL
            end)
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

    self:update(0) -- relax physics body
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
        self._jump_blocked = false
        self._left_wall_jump_blocked = false
        self._right_wall_jump_blocked = false
    end
end

--- @brief
function rt.Player:set_jump_disabled(b)
    self._jump_disabled = b
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
function rt.Player:set_directional_damping(direction, x)
    meta.assert_enum_value(direction, rt.Direction, 1)
    meta.assert_typeof(x, "Number", 2)

    self._direction_to_damping[direction] = x
end

--- @brief
function rt.Player:get_directional_damping(direction)
    meta.assert_enum_value(direction, rt.Direction, 1)

    return self._direction_to_damping[direction]
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
        self._wall_jump_elapsed = math.huge
        self._bounce_elapsed = math.huge
        self._wall_jump_freeze_elapsed = math.huge
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
function rt.Player:get_colliding_bodies()
    local bodies = {}
    for body in keys(self._body_to_collision_normal) do
        table.insert(bodies, body)
    end
    return bodies
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
    local jumped = false

    local function allow_vertical_jump()
        self._jump_elapsed = 0
        self._jump_blocked = true
        jumped = true
    end

    -- override disable
    if self._jump_allowed_override == false then
        self._jump_allowed_override = nil
        return false
    end

    local should_wall_jump = (self._left_wall or self._right_wall) and not self._bottom_wall

    -- overridden enable
    if self._jump_allowed_override == true then
        allow_vertical_jump()
        self._jump_allowed_override = nil

    -- regular jump
    elseif self._is_grounded and not should_wall_jump and not self._jump_is_blocked then
        allow_vertical_jump()

    -- double jump
    elseif not self._is_grounded and not table.is_empty(self._double_jump_sources) then
        allow_vertical_jump()

        -- consume double jump source
        local instance = self._double_jump_sources[#self._double_jump_sources]
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

    -- wall jump
    elseif self._wall_jump_freeze_elapsed > _settings.wall_jump_freeze_duration then
        local can_wall_jump = (self._left_wall and not self._left_wall_jump_blocked) or
            (self._right_wall and not self._right_wall_jump_blocked)

        if can_wall_jump then
            self._wall_jump_elapsed = 0
            jumped = true

            if self._left_wall then
                self._left_wall_jump_blocked = true
            elseif self._right_wall then
                self._right_wall_jump_blocked = true
            end
        end
    end

    if jumped then
        self:signal_emit("jump")
    end

    return jumped
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

    if #to_remove_is > 0 then
        if instance.signal_try_emit ~= nil then
            instance:signal_try_emit("removed")
        end
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
    return self._is_ducking
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
    self._position_override_active = false
    self._position_override_x = nil
    self._position_override_y = nil
    if self._world ~= nil then self._world:set_time_dilation(1) end

    self._top_wall = false
    self._top_right_wall = false
    self._right_wall = false
    self._bottom_right_wall = false
    self._bottom_wall = false
    self._bottom_left_wall = false
    self._left_wall = false
    self._top_left_wall = false

    self._jump_button_is_down = self._input:get_is_down(rt.InputAction.JUMP)
    self._sprint_button_is_down = self._input:get_is_down(rt.InputAction.SPRINT)
    self._up_button_is_down = self._input:get_is_down(rt.InputAction.UP)
    self._down_button_is_down = self._input:get_is_down(rt.InputAction.DOWN)
    self._right_button_is_down = self._input:get_is_down(rt.InputAction.RIGHT)
    self._left_button_is_down = self._input:get_is_down(rt.InputAction.LEFT)

    if self._sprint_button_is_down then
        self._sprint_multiplier = _settings.sprint_multiplier
        self._next_sprint_multiplier = _settings.sprint_multiplier
        self._next_sprint_multiplier_update_when_grounded = false
    else
        self._sprint_multiplier = 1
        self._next_sprint_multiplier = 1
        self._next_sprint_multiplier_update_when_grounded = false
    end
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
    local changed = b ~= self._movement_disabled
    self._movement_disabled = b

    if changed then
        self._left_button_is_down = false
        self._right_button_is_down = false
        self._down_button_is_down = false
        self._up_button_is_down = false
        self._jump_button_is_down = false
        self._sprint_button_is_down = false
    end
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

--- @brief
function rt.Player:set_ignore_next_jump(b)
    if b == true then
        self._ignore_jump_stack = self._ignore_jump_stack + 1
    elseif b == false then
        self._ignore_jump_stack = math.max(0, self._ignore_jump_stack - 1)
    end
end

--- @brief
function rt.Player:set_damping(t)
    self._damping = t
end

--- @brief
function rt.Player:set_idle_timer_frozen(b)
    self._idle_timer_frozen = b
    if b == false then self._idle_elapsed = 0 end
end

--- @brief
function rt.Player:get_idle_timer_frozen()
    return self._idle_timer_frozen
end

--- @brief
--- @param x_or_nil Number?
--- @param y Number
function rt.Player:set_position_override(x_or_nil, y_or_nil)
    self._position_override_x, self._position_override_y = x_or_nil, y_or_nil
end

--- @brief
function rt.Player:set_position_override_active(b)
    self._position_override_active = b
end
