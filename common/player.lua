require "physics.physics"
require "common.input_subscriber"
require "common.joystick_gesture_detector"
require "common.player_body"
require "common.player_trail"
require "common.random"
require "common.palette"
require "common.path"
require "common.direction"

do
    local radius = 13.5
    rt.settings.player = {
        radius = radius,
        inner_body_radius = 10 / 2 - 0.5,
        n_outer_bodies = 27,
        max_spring_length = radius * 3,
        outer_body_spring_strength = 2,

        bottom_wall_ray_length_factor = 1.25,
        side_wall_ray_length_factor = 1.15,
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
        sprint_multiplier_transition_duration = 5 / 60,

        position_history_n = 1000, -- n samples
        position_history_sample_frequency = 5, -- px
        velocity_history_n = 3, -- n samples

        ground_acceleration_duration = 5 / 60, -- seconds to target velocity if currently slower
        ground_deceleration_duration = 2 / 60, -- seconds to target velocity if currently faster

        air_acceleration_duration = 8 / 60,
        air_deceleration_duration = 5 / 60,

        air_decay_duration = 25 / 60, -- seconds to 0 if controller neutral
        ground_decay_duration = 4.5 / 60, -- seconds to 0 if controller neutral

        ground_target_velocity_x = 180, -- px / s
        air_target_velocity_x = 150,

        accelerator_acceleration_duration = 20 / 60,
        accelerator_max_velocity_factor = 3.5 / 2,
        accelerator_magnet_force = 2000, -- per second

        instant_turnaround_velocity = 600,
        allow_instant_turn_around = false,

        coyote_time = 8 / 60, -- seconds after leaving ground
        wall_jump_coyote_time = 5 / 120, -- seconds after letting go of direction against wall

        platform_velocity_decay = 0.7,

        jump_duration = 11 / 60,
        jump_impulse = 550, -- 10 * 16 tiles neutral jump

        wall_jump_initial_impulse = 400,
        wall_jump_sustained_impulse = 1000,
        wall_jump_initial_angle = math.rad(18) - math.pi * 0.5,
        wall_jump_sustained_angle = math.rad(5) - math.pi * 0.5,
        wall_jump_duration = 10 / 60,
        wall_jump_freeze_duration = 8 / 60,

        bounce_min_force = 200,
        bounce_max_force = 600,
        bounce_relative_velocity = 2000,
        bounce_duration = 2 / 60,

        jump_buffer_duration = 4 / 60,
        wall_jump_buffer_duration = 3 / 60,

        bubble_radius_factor = 2.5,
        bubble_inner_radius_scale = 1.7,
        bubble_target_velocity = 400,
        bubble_acceleration = 2.5,
        bubble_gravity_factor = 0.015,
        bubble_air_resistance = 0.5, -- px / s

        gravity = 1500, -- px / s
        air_resistance = 0.03, -- [0, 1]
        downwards_force = 3000,

        friction_coefficient = 100,
        down_button_friction_release_duration = 10 / 60, -- s

        max_velocity = 10000,

        hue_cycle_duration = 30, -- seconds

        pulse_duration = 0.6, -- seconds
        pulse_radius_factor = 2, -- factor

        flow_source_default_magnitude = 0.05, -- % per second
        flow_source_default_duration = 120 / 60,
        flow_decay_per_second = 0.015, -- % per second

        input_subscriber_priority = 1
    }
end

local settings = setmetatable({}, {
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
    "bubble", -- (Player, Boolean), when going from non-bubble to bubble or vice versa
    "spawned",
    "died" -- when respawning after a death
)


local _clear = function(t) for key in keys(t) do t[key] = nil end end

--- @brief
function rt.Player:instantiate()
    local player_radius = settings.radius
    meta.install(self, {
        _stage = nil,

        _radius = player_radius,
        _inner_body_radius = settings.inner_body_radius,
        _outer_body_radius = (player_radius * 2 * math.pi) / settings.n_outer_bodies / 1.5,

        _bubble_radius = player_radius * settings.bubble_radius_factor,
        _bubble_inner_body_radius = settings.inner_body_radius * settings.bubble_inner_radius_scale,
        _bubble_outer_body_radius = (player_radius * settings.bubble_radius_factor * 2 * math.pi) / settings.n_outer_bodies / 2,

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

        _is_grounded = false,
        _is_ducking = false,

        _queue_turn_around = false,
        _queue_turn_around_direction = rt.Direction.NONE,

        _jump_buffer_elapsed = math.huge,
        _left_wall_jump_buffer_elapsed = math.huge,
        _right_wall_jump_buffer_elapsed = math.huge,

        _jump_elapsed = math.huge,
        _jump_blocked = true,
        _coyote_elapsed = math.huge,
        _left_wall_coyote_elapsed = math.huge,
        _right_wall_coyote_elapsed = math.huge,

        _wall_jump_elapsed = math.huge,
        _left_wall_jump_blocked = true,
        _right_wall_jump_blocked = true,
        _wall_jump_freeze_elapsed = math.huge,
        _wall_jump_freeze_sign = 0,

        _double_jump_sources = {}, -- cf. add_double_jump_source
        _bounce_sources = {}, -- cf. bounce
        _flow_sources = {}, -- cf. add_flow_source

        _last_velocity_x = 0,
        _last_velocity_y = 0,
        _last_bubble_force_x = 0,
        _last_bubble_force_y = 0,
        _last_position_x = 0,
        _last_position_y = 0,

        _position_override_active = false,
        _position_override_x = nil, -- Number
        _position_override_y = nil, -- Number

        _platforms = {},
        _platform_velocity_x = 0,
        _platform_velocity_y = 0,

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

        _use_analog_input = rt.InputManager:get_input_method() == rt.InputMethod.CONTROLLER,

        -- sprint
        _current_sprint_multiplier = 1,
        _target_sprint_multiplier = 1,
        _next_sprint_multiplier = 1,
        _next_sprint_multiplier_update_when_grounded = false,

        -- physics
        _spring_bodies = {},
        _spring_joints = {},
        _spring_body_offsets_x = {},
        _spring_body_offsets_y = {},

        _bubble_spring_bodies = {},
        _bubble_spring_joints = {},
        _bubble_spring_body_offsets_x = {},
        _bubble_spring_body_offsets_y = {},

        _body = nil,
        _mass = 1,
        _world = nil,
        _body_to_collision_normal = {},
        _use_bubble_mesh_delay_n_steps = 0,

        -- animation
        _trail = nil, -- rt.PlayerTrail
        _graphics_body = nil, -- rt.PlayerBody
        _pulses = {}, -- Table<love.Timestamp>
        _pulse_mesh = nil, -- rt.Mesh,

        _hue = 0,
        _hue_elapsed = 0,

        _current_color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, 0, 1)),

        _current_flow = 0,

        _input = rt.InputSubscriber(settings.input_subscriber_priority),
        _joystick_gesture = rt.JoystickGestureDetector(),

        _idle_elapsed = 0,
    })

    do -- request pattern tables
        self._request_ids = {}

        for request in range(
            "is_visible",
            "is_frozen",
            "is_disabled",
            "is_ghost",
            "is_bubble",
            "is_movement_disabled",
            "is_jump_disabled",
            "is_jump_allowed_override",
            "is_trail_visible",
            "is_flow_frozen",
            "is_idle_timer_frozen",

            "opacity",
            "time_dilation",
            "gravity_multiplier",

            "gravity_direction",
            "force",

            "damping"
        ) do
            local table_id = "_" .. request .. "_requests"
            self[table_id] = meta.make_weak({})

            table.insert(self._request_ids, "_" .. request .. "_requests")
        end
    end

    -- initialize history
    self._position_history = {}
    for i = 1, 2 * settings.position_history_n, 2 do
        self._position_history[i+0] = 0
        self._position_history[i+1] = 0
    end
    self._position_history_path = rt.Path(self._position_history)

    self._velocity_history = {}
    for i = 1, 2 * settings.velocity_history_n, 2 do
        self._velocity_history[i+0] = 0
        self._velocity_history[i+1] = 0
    end

    -- graphics
    self._trail = rt.PlayerTrail(self._radius)
    self._graphics_body = rt.PlayerBody(0, 0)

    self._pulse_mesh = rt.MeshCircle(0, 0, 1, 1, 32) -- scaled in draw
    self._pulse_mesh:set_vertex_color(1, 1, 1, 1, 0)
    for i = 2, self._pulse_mesh:get_n_vertices() do
        self._pulse_mesh:set_vertex_color(i, 1, 1, 1, 1)
    end

    self:_connect_input()
end

--- @brief
function rt.Player:_connect_input()
    self._input:signal_connect("pressed", function(_, which, count)
        local is_disabled = self:get_is_disabled()
        if is_disabled then return end

        local queue_sprint = function()
            self._next_sprint_multiplier = settings.sprint_multiplier
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

            if is_disabled then return end

            if not self:jump() then
                self._jump_buffer_elapsed = 0
                self._left_wall_jump_buffer_elapsed = 0
                self._right_wall_jump_buffer_elapsed = 0
            end
        elseif which == rt.InputAction.SPRINT then
            self._sprint_button_is_down = true
            self._sprint_button_is_down_elapsed = 0

            queue_sprint()
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
        if self:get_is_disabled() then return end

        if which == rt.InputAction.JUMP then
            self._jump_button_is_down = false
            self._jump_button_is_down_elapsed = math.huge
        elseif which == rt.InputAction.SPRINT then
            self._sprint_button_is_down = false
            self._sprint_button_is_down_elapsed = math.huge

            self._next_sprint_multiplier = 1
            self._next_sprint_multiplier_update_when_grounded = true
        elseif which == rt.InputAction.LEFT then
            self._left_button_is_down = false
            self._left_button_is_down_elapsed = 0
        elseif which == rt.InputAction.RIGHT then
            self._right_button_is_down = false
            self._right_button_is_down_elapsed = math.huge
        elseif which == rt.InputAction.DOWN then
            self._down_button_is_down = false
            self._down_button_is_down_elapsed = math.huge
        elseif which == rt.InputAction.UP then
            self._up_button_is_down = false
            self._up_button_is_down_elapsed = math.huge
        end
    end)

    self._joystick_gesture:signal_connect("pressed", function(_, which, count)
        if self:get_is_disabled() then return end

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
    end)

    self._input:signal_connect("left_joystick_moved", function(_, x, y)
        -- direction handled in joystick gesture
        self._joystick_position_x = x
        self._joystick_position_y = y
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

    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "g" then
            local current = self:get_is_bubble()
            if current == false then
                self:request_is_bubble(self, true)
            else
                self:request_is_bubble(self, nil)
            end
        end
    end)
end

--- @brief
function rt.Player:update(delta)
    if self._body == nil then return end
    if self._should_update == false then return end

    local is_bubble = self:get_is_bubble()
    local time_dilation = self:get_time_dilation()

    local function update_graphics()
        do -- notify body of new anchor positions
            local positions, center_x, center_y
            if is_bubble then
                center_x, center_y = self._bubble_body:get_predicted_position()
                positions = {}

                for i = 1, #self._spring_bodies do
                    table.insert(positions, self._spring_body_offsets_x[i])
                    table.insert(positions, self._spring_body_offsets_y[i])
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
                self._graphics_body:set_color(self._current_color)
                self._graphics_body:set_opacity(self:get_opacity())

                if self:get_is_bubble() then
                    self._graphics_body:set_use_contour(true)
                else
                    self._graphics_body:set_use_contour(false)
                end

                self._graphics_body:update(delta)
            end
        end

        self._trail:set_position(self:get_position())
        self._trail:set_velocity(self:get_velocity())
        self._trail:set_hue(self:get_hue())
        self._trail:set_opacity(self:get_opacity())
        self._trail:update(delta)

        do
            local to_remove = {}
            for i, pulse in ipairs(self._pulses) do
                local elapsed = love.timer.getTime() - pulse.timestamp
                if elapsed > settings.pulse_duration then
                    table.insert(to_remove, i)
                end
            end

            for i = #to_remove, 1, -1 do
                table.remove(self._pulses, i)
            end
        end

        self._hue_elapsed = self._hue_elapsed + delta / settings.hue_cycle_duration
        self._hue = math.fract(self._hue_elapsed)
        self:_update_color()
    end

    local use_analog_input = math.magnitude(self._joystick_position_x, self._joystick_position_y) > math.eps
        and not self._left_button_is_down
        and not self._right_button_is_down
        and not self._down_button_is_down
        and not self._up_button_is_down

    self._use_analog_input = use_analog_input

    local gravity_direction_x, gravity_direction_y = self:get_gravity_direction()
    local gravity = time_dilation * self:get_gravity_multiplier() * settings.gravity * delta

    local is_disabled = self:get_is_disabled()
    local is_ghost = self:get_is_ghost()
    local is_frozen = self:get_is_frozen()
    local is_movement_disabled = self:get_is_movement_disabled()
    local should_decay_platform_velocity = true

    -- if diables, simply continue velocity path
    if is_disabled then
        local vx, vy = self._last_velocity_x, self._last_velocity_y
        vy = vy + gravity

        if is_bubble then
            if is_frozen then
                self._bubble_body:set_velocity(0, 0)
                self._last_velocity_x, self._last_velocity_y = 0, 0
            else
                self._bubble_body:set_velocity(vx, vy)
                self._last_velocity_x, self._last_velocity_y = vx, vy
            end
        else
            if is_frozen then
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

    -- raycast to check for walls
    local x, y
    if is_bubble then
        x, y = self._bubble_body:get_position()
    else
        x, y = self._body:get_position()
    end

    local mask
    if is_ghost == false then
        mask = bit.bnot(0x0) -- everything
        mask = bit.band(mask, bit.bnot(settings.player_outer_body_collision_group))
        mask = bit.band(mask, bit.bnot(settings.exempt_collision_group))
    else
        mask = 0x0 -- nothing
        mask = bit.bor(mask, settings.ghost_collision_group)
    end

    local bubble_factor = 1
    if is_bubble then
        bubble_factor = settings.bubble_radius_factor
    end

    local top_ray_length = self._radius * settings.top_wall_ray_length_factor * bubble_factor
    local right_ray_length = self._radius * settings.side_wall_ray_length_factor * bubble_factor
    local left_ray_length = right_ray_length * bubble_factor
    local bottom_ray_length = self._radius * settings.bottom_wall_ray_length_factor * bubble_factor
    local bottom_left_ray_length = self._radius * settings.corner_wall_ray_length_factor * bubble_factor
    local bottom_right_ray_length = bottom_left_ray_length * bubble_factor
    local top_left_ray_length = self._radius * settings.corner_wall_ray_length_factor * bubble_factor
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

    do -- check ground state
        local radius = self._radius
        local left = left_wall_body ~= nil and math.distance(x, y, left_x, left_y) <= radius
        local bottom_left = bottom_left_wall_body ~= nil and math.distance(x, y, bottom_left_x, bottom_left_y) <= radius
        local bottom = bottom_wall_body ~= nil and math.distance(x, y, bottom_x, bottom_y) <= radius
        local bottom_right = bottom_right_wall_body ~= nil and math.distance(x, y, bottom_right_x, bottom_right_y) <= radius
        local right = right_wall_body ~= nil and math.distance(x, y, right_x, right_y) <= radius

        -- do not count walls detected by diagonal down rays
        is_grounded = bottom
            or (bottom_left and bottom_left_wall_body ~= left_wall_body)
            or (bottom_right and bottom_right_wall_body ~= right_wall_body)
    end

    self._is_grounded = is_grounded

    do -- update graphics body
        local lines = {}
        local add_collision = function(body, cx, cy, nx, ny)
            if body == nil then return end

            if body:has_tag("hitbox") then
                local x1, y1 = math.add(cx, cy, math.turn_left(nx, ny))
                local x2, y2 = math.add(cx, cy, math.turn_right(nx, ny))
                table.insert(lines, {
                    contact_x = cx,
                    contact_y = cy,
                    x1 = x1,
                    y1 = y1,
                    x2 = x2,
                    y2 = y2,
                    normal_x = nx,
                    normal_y = ny
                })
            end
        end

        if is_bubble then
            add_collision(top_wall_body, top_x, top_y, top_nx, top_ny)
            add_collision(top_right_wall_body, top_right_x, top_right_y, top_right_nx, top_right_ny)
            add_collision(right_wall_body, right_x, right_y, right_nx, right_ny)
            add_collision(left_wall_body, left_x, left_y, left_nx, left_ny)
            add_collision(top_left_wall_body, top_left_x, top_left_y, top_left_nx, top_left_ny)
        end

        if is_bubble or is_grounded then
            add_collision(bottom_right_wall_body, bottom_right_x, bottom_right_y, bottom_right_nx, bottom_right_ny)
            add_collision(bottom_wall_body, bottom_x, bottom_y, bottom_nx, bottom_ny)
            add_collision(bottom_left_wall_body, bottom_left_x, bottom_left_y, bottom_left_nx, bottom_left_ny)
        end

        self._graphics_body:set_colliding_lines(lines) -- empty if non-bubble and mid air

        do -- query stencils
            local w = 2 * self._bubble_radius
            local h = w
            local mask = bit.bnot(0x0)
            mask = bit.band(mask, bit.bnot(settings.player_outer_body_collision_group))
            mask = bit.band(mask, bit.bnot(settings.player_collision_group))
            mask = bit.band(mask, bit.bnot(settings.bounce_collision_group))

            local x, y = self:get_position()
            local bodies = self._world:query_aabb(
                x - 0.5 * w, y - 0.5 * h, w, h,
                mask
            )

            local body_stencil = {}
            local core_stencil = {}
            for body in values(bodies) do
                if not body:get_is_sensor() then
                    if body:has_tag("stencil") or body:has_tag("body_stencil") then
                        table.insert(body_stencil, body)
                    end

                    if body:has_tag("core_stencil") then
                        table.insert(core_stencil, body)
                    end
                end
            end

            self._graphics_body:set_stencil_bodies(body_stencil)
            self._graphics_body:set_core_stencil_bodies(core_stencil)
        end
    end

    -- input method agnostic button state
    local left_is_down = self._left_button_is_down or use_analog_input and
        self._joystick_gesture:get_magnitude(rt.InputAction.LEFT) > settings.joystick_magnitude_left_threshold

    local right_is_down = self._right_button_is_down or use_analog_input and
        self._joystick_gesture:get_magnitude(rt.InputAction.RIGHT) > settings.joystick_magnitude_right_threshold

    local up_is_down = self._up_button_is_down or use_analog_input and
        self._joystick_gesture:get_magnitude(rt.InputAction.UP) > settings.joystick_magnitude_up_threshold

    local down_is_down = self._down_button_is_down or use_analog_input and
        self._joystick_gesture:get_magnitude(rt.InputAction.DOWN) > settings.joystick_magnitude_down_threshold

    -- buffered jump
    if rt.GameState:get_is_input_buffering_enabled() then
        local left_allowed, right_allowed = self:_get_walljump_allowed()
        local up_allowed = self:_get_jump_allowed()

        -- buffered up jump
        if self._jump_buffer_elapsed <= settings.jump_buffer_duration
            and not left_allowed -- prioritize wall jump
            and not right_allowed
            and up_allowed
        then
            local cx = bottom_x or bottom_left_x or bottom_right_x
            local cy = bottom_y or bottom_left_y or bottom_right_y
            if cx ~= nil and cy ~= nil and math.distance(x, y, cx, cy) <= self._radius then
                if self:jump() then
                    self._jump_buffer_elapsed = math.huge
                end
            end
        end
        self._jump_buffer_elapsed = self._jump_buffer_elapsed + delta

        -- buffer left wall jump, left has priority
        if self._left_wall_jump_buffer_elapsed < settings.wall_jump_buffer_duration
            and left_allowed
        then
            if self:jump() then
                self._left_wall_jump_buffer_elapsed = math.huge
            end
        -- else try buffer right wall jump
        elseif self._right_wall_jump_buffer_elapsed < settings.wall_jump_buffer_duration
            and right_allowed
        then
            if self:jump() then
                self._left_wall_jump_buffer_elapsed = math.huge
            end
        end

        self._left_wall_jump_buffer_elapsed = self._left_wall_jump_buffer_elapsed + delta
        self._right_wall_jump_buffer_elapsed = self._right_wall_jump_buffer_elapsed + delta
    end

    -- check if tethers should be cleared
    if not is_bubble then
        local should_clear = false

        local check_body = function(body)
            if is_grounded then
                -- any ground clears
                return body ~= nil and body:has_tag("hitbox")
            else
                -- only sticky walls clear
                return body ~= nil and body:has_tag("hitbox") and not body:has_tag("slippery")
            end
        end

        for tuple in range(
            { bottom_wall_body, bottom_x, bottom_y },
            { bottom_left_wall_body, bottom_left_x, bottom_left_y },
            { bottom_right_wall_body, bottom_right_x, bottom_right_y },
            { left_wall_body, left_x, left_y },
            { right_wall_body, right_x, right_y }
        ) do
            local body, ray_x, ray_y = table.unpack(tuple)
            if check_body(body) then
                if math.distance(x, y, ray_x, ray_y) < self._radius then
                    should_clear = true
                    break
                end
            end
        end

        if should_clear then
            for instance in values(self._double_jump_sources) do
                if instance.signal_try_emit ~= nil then instance:signal_try_emit("removed") end
            end

            _clear(self._double_jump_sources)
        end
    end

    do -- compute current normal for all colliding walls
        local wall_mask = bit.bnot(bit.bor(settings.player_outer_body_collision_group, settings.player_collision_group))
        local body = is_bubble and self._bubble_body or self._body
        local outer_bodies = is_bubble and self._bubble_spring_bodies or self._spring_bodies
        local offset_x = is_bubble and self._bubble_spring_body_offsets_x or self._spring_body_offsets_x
        local offset_y = is_bubble and self._bubble_spring_body_offsets_y or self._spring_body_offsets_y

        local self_x, self_y = body:get_position()
        local ray_length = self:get_radius() + 2 * self._outer_body_radius

        local body_to_ray_data = {}
        for i, outer in pairs(outer_bodies) do
            local cx, cy = outer:get_position()
            local dx, dy = math.normalize(offset_x[i], offset_y[i])

            local ray_x, ray_y, ray_nx, ray_ny, ray_wall_body = self._world:query_ray(
                self_x, self_y,
                dx * ray_length, dy * ray_length,
                wall_mask
            )

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
        _clear(self._body_to_collision_normal)
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

        do -- update down squish
            local is_ducking = false

            -- on analog, prioritize, disregarding side inputs
            local should_duck
            if use_analog_input then
                should_duck = self._joystick_gesture:get_magnitude(rt.InputAction.DOWN) > settings.joystick_magnitude_down_threshold
                    and self._joystick_gesture:get_magnitude(rt.InputAction.LEFT) < settings.joystick_magnitude_left_threshold
                    and self._joystick_gesture:get_magnitude(rt.InputAction.RIGHT) < settings.joystick_magnitude_right_threshold
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
            self._is_ducking = is_ducking
        end

        -- update side squish
        local should_squish = function(button, ...)
            if button then
                for i = 1, select("#", ...) do
                    local wall_body = select(i, ...)
                    if wall_body ~= nil then
                        local entry = self._body_to_collision_normal[wall_body]
                        if entry ~= nil then
                            return true,
                                entry.normal_x, entry.normal_y,
                                entry.contact_x, entry.contact_y
                        end
                    end
                end
            end

            return false
        end

        self._graphics_body:set_left_squish(should_squish(
            left_is_down,
            left_wall_body or bottom_left_wall_body or top_left_wall_body
        ))

        self._graphics_body:set_right_squish(should_squish(
            right_is_down,
            right_wall_body or bottom_right_wall_body or top_right_wall_body
        ))

        self._graphics_body:set_up_squish(should_squish(
            up_is_down,
            top_wall_body or top_left_wall_body or top_right_wall_body
        ))
    end

    -- non-bubble movement
    if not is_bubble then

        if rt.GameState:get_player_sprint_mode() == rt.PlayerSprintMode.MANUAL then
            -- update sprint once landed
            if self._next_sprint_multiplier_update_when_grounded and is_grounded then
                self._target_sprint_multiplier = self._next_sprint_multiplier
            end

            -- lerp instead of transitioning instantly
            self._current_sprint_multiplier = math.mix(
                self._current_sprint_multiplier,
                self._target_sprint_multiplier,
                1 - math.exp(-1 / settings.sprint_multiplier_transition_duration * delta)
            )
        else
            -- always sprint
            self._current_sprint_multiplier = settings.sprint_multiplier
        end

        local current_velocity_x, current_velocity_y = self._body:get_velocity()
        current_velocity_x = current_velocity_x - self._platform_velocity_x
        current_velocity_y = current_velocity_y - self._platform_velocity_y

        local next_velocity_x, next_velocity_y = current_velocity_x, current_velocity_y
        local start_velocity_x, start_velocity_y = next_velocity_x, next_velocity_y

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

        if self._wall_jump_freeze_elapsed < settings.wall_jump_freeze_duration then
            input_magnitude = 0
        end

        -- if on unwalkable, player will have no way to influence horizontal movement
        local is_unwalkable = (self._bottom_wall and self._bottom_wall_body:has_tag("unwalkable"))
            or (self._bottom_left_wall and self._bottom_left_wall_body:has_tag("unwalkable"))
            or (self._bottom_right_wall and self._bottom_right_wall_body:has_tag("unwalkable"))

        if is_unwalkable then
            input_magnitude = 0
            left_is_down = false
            right_is_down = false
        end

        local target_velocity_x = input_magnitude * self._current_sprint_multiplier * ternary(is_grounded,
            settings.ground_target_velocity_x,
            settings.air_target_velocity_x
        )

        -- make player harder to steer if they are above the desired top speed
        local velocity_easing
        do
            local target
            if is_grounded then
                target = settings.ground_target_velocity_x * settings.sprint_multiplier
            else
                target = settings.air_target_velocity_x * settings.sprint_multiplier
            end

            -- clamp to factor 1 for any regular velocity, only ease above target speed
            local alpha = math.max(0, math.abs(current_velocity_x) / target - 1)

            local easing = function(x)
                -- sinusoid ease in, goes towards linear for x -> 1, then linear
                if x < 1 then
                    -- \left(\cos\left(\frac{\pi}{2}\ \left(x-2\right)\right)+1\right)\ \left\{0<x<1\right\}
                    return math.cos((math.pi / 2) * (x - 2)) + 1
                else
                    -- 1+\left(\frac{\pi}{2}\left(x-1\right)\right)\left\{x>1\right\}
                    return 1 + (math.pi / 2) * (x - 1)
                end
            end

            velocity_easing = 1 + easing(alpha)
        end

        -- on input, accelerates towards new target velocity / direction
        if input_magnitude ~= 0 then
            local velocity_delta = target_velocity_x - current_velocity_x
            local is_accelerating = (math.sign(target_velocity_x) == math.sign(current_velocity_x)) and
                (math.abs(target_velocity_x) > math.abs(current_velocity_x))

            local acceleration_duration
            if is_grounded then
                if is_accelerating then
                    acceleration_duration = settings.ground_acceleration_duration
                else
                    acceleration_duration = settings.ground_deceleration_duration
                end
            else
                if is_accelerating then
                    acceleration_duration = settings.air_acceleration_duration
                else
                    acceleration_duration = settings.air_deceleration_duration
                end
            end

            acceleration_duration = acceleration_duration * velocity_easing

            if acceleration_duration < math.eps then
                next_velocity_x = target_velocity_x
            elseif math.sign(target_velocity_x) ~= math.sign(current_velocity_x)
                or math.abs(target_velocity_x) >= math.abs(current_velocity_x)
            then
                -- maintain momentum, if going in the same direction only apply positive acceleration
                local acceleration_rate = math.abs(target_velocity_x) / acceleration_duration
                local velocity_step = acceleration_rate * delta
                next_velocity_x = current_velocity_x + math.clamp(velocity_delta, -velocity_step, velocity_step)
            end
        else -- on no directional input, decay towards 0
            local decay_duration
            if is_grounded then
                decay_duration = settings.ground_decay_duration
            else
                decay_duration = settings.air_decay_duration
            end

            decay_duration = decay_duration * velocity_easing

            local should_slide = is_grounded
                and not left_is_down
                and not right_is_down

            if should_slide and
                (self._bottom_wall and self._bottom_wall_body:has_tag("slippery"))
                or (self._bottom_left_wall and self._bottom_left_wall_body:has_tag("slippery"))
                or (self._bottom_right_wall and self._bottom_right_wall_body:has_tag("slippery"))
            then
                -- do not decay
            else
                -- linear decay
                next_velocity_x = current_velocity_x * math.exp(-delta / decay_duration) -- lerp is exponential
            end
        end

        local should_apply_friction = true

        do -- accelerators
            local player_vx, player_vy = next_velocity_x, next_velocity_y

            local new_velocity_x, new_velocity_y = 0, 0
            local should_override = false

            local max_velocity = self._current_sprint_multiplier * settings.accelerator_max_velocity_factor * settings.ground_target_velocity_x * settings.sprint_multiplier
            local acceleration = max_velocity / settings.accelerator_acceleration_duration

            local already_handled = {}
            for surface in range( -- order matters
                { left_wall_body, left_nx, left_ny },
                { right_wall_body, right_nx, right_ny },

                { bottom_wall_body, bottom_nx, bottom_ny },
                { bottom_left_wall_body, bottom_left_nx, bottom_left_ny },
                { bottom_right_wall_body, bottom_right_nx, bottom_right_ny },

                { top_wall_body, top_nx, top_ny },
                { top_left_wall_body, top_left_nx, top_left_ny },
                { top_right_wall_body, top_right_nx, top_right_ny }
            ) do
                local body, normal_x, normal_y = table.unpack(surface)
                if body ~= nil and body:has_tag("use_friction") and already_handled[body] ~= true then
                    already_handled[body] = true

                    -- get surface tangent
                    local tangent_x, tangent_y = math.turn_left(normal_x, normal_y)
                    local tangent_sign = math.sign(math.dot(
                        tangent_x, tangent_y,
                        player_vx, player_vy
                    ))

                    tangent_x, tangent_y = tangent_sign * tangent_x, tangent_sign * tangent_y

                    -- check if input aligns with tangent
                    local input_alignment
                    if use_analog_input then
                        local input_x, input_y = self._joystick_position_x, self._joystick_position_y
                        input_alignment = math.max(0, math.dot(input_x, input_y, tangent_x, tangent_y))
                    else
                        local candidates = { 0, 0 }

                        if left_is_down then
                            table.insert(candidates, -1)
                            table.insert(candidates,  0)
                        end

                        if right_is_down then
                            table.insert(candidates,  1)
                            table.insert(candidates,  0)
                        end

                        if down_is_down then
                            table.insert(candidates,  0)
                            table.insert(candidates,  1)
                        end

                        if up_is_down then
                            table.insert(candidates,  0)
                            table.insert(candidates, -1)
                        end

                        -- check all of the 8 input vectors the button state allows
                        -- chose the best one, this gives keyboard players a better chance to
                        -- perfectly align with the surface
                        input_alignment = 0
                        for a_i = 1, #candidates, 2 do
                            for b_i = 1, #candidates, 2 do
                                if a_i ~= b_i then
                                    local ax, ay = candidates[a_i], candidates[a_i+1]
                                    local bx, by = candidates[b_i], candidates[b_i+1]

                                    local candidate_x = ax + bx
                                    local candidate_y = ay + by

                                    input_alignment = math.max(input_alignment, math.dot(
                                        tangent_x, tangent_y,
                                        math.normalize(candidate_x, candidate_y)
                                    ))
                                end
                            end
                        end
                    end

                    -- easing based on input vector direction and surface tangent
                    -- if farther away than threshold, 0, else, 0 to 1
                    input_alignment = math.max(0, input_alignment)

                    if input_alignment > math.eps then
                        -- accelerate along surface
                        new_velocity_x = new_velocity_x + input_alignment * tangent_x * acceleration * delta
                        new_velocity_y = new_velocity_y + input_alignment * tangent_y * acceleration * delta

                        -- magnet easing
                        local magnet = math.min(1, math.abs(input_alignment))
                        magnet = magnet * settings.accelerator_magnet_force

                        -- magnetize to wall
                        new_velocity_x = new_velocity_x + magnet * -normal_x * delta
                        new_velocity_y = new_velocity_y + magnet * -normal_y * delta

                        local magnet_eps = 0.05
                        if magnet > magnet_eps then should_apply_friction = false end
                    end
                end
            end

            if math.magnitude(new_velocity_x, new_velocity_y) > 1 then
                -- overrides velocity logic so far
                next_velocity_x = math.clamp(start_velocity_x + new_velocity_x, -max_velocity, max_velocity)
                next_velocity_y = math.clamp(start_velocity_y + new_velocity_y, -max_velocity, max_velocity)
            end
        end

        -- override on disable
        if is_movement_disabled then next_velocity_x = 0 end

        -- wall friction
        local net_friction_x, net_friction_y = 0, 0
        do
            local seen = {}

            -- apply friction along tangent, also magnetize towards surface
            local apply_friction = function(normal_x, normal_y, body, use_input_modifier)
                local player_vx, player_vy = self._body:get_velocity()
                local body_vx, body_vy = body:get_velocity()

                -- compute relative velocity
                local relative_vx = player_vx - body_vx
                local relative_vy = player_vy - body_vy

                -- only apply friction to mostly vertical walls
                local wall_coefficient = math.dot(normal_x, normal_y, 0, 1) + 1
                local slope_factor = 1 - math.abs(wall_coefficient - 1)

                -- if ground slope, no friction
                if slope_factor < 0.5 then return end

                -- else weigh by how close to vertical the wall is
                slope_factor = (slope_factor - 0.5) * 2

                -- get tangent
                local gravity_x, gravity_y = gravity_direction_x, gravity_direction_y

                local tangent_x, tangent_y
                if math.dot(gravity_x, gravity_y, math.turn_left(normal_x, normal_y)) < 0 then
                    tangent_x, tangent_y = math.turn_left(normal_x, normal_y)
                else
                    tangent_x, tangent_y = math.turn_right(normal_x, normal_y)
                end

                local input_modifier = 1.0
                if use_input_modifier then
                    if use_analog_input then
                        -- easing determined by joystick input, aggressive for lower values
                        local easing = function(x) return 1 - x^(1 / 4)  end
                        input_modifier = easing(math.max(0, math.dot(
                            0, 1,
                            math.normalize(self._joystick_position_x, self._joystick_position_y)
                        )))
                    elseif down_is_down then
                        -- easing determined by how long down was held
                        input_modifier = 1 - math.min(1, self._down_button_is_down_elapsed / settings.down_button_friction_release_duration)
                    end
                end

                local friction_force = input_modifier * slope_factor * settings.friction_coefficient
                net_friction_x = net_friction_x + tangent_x * friction_force
                net_friction_y = net_friction_y + tangent_y * friction_force
            end

            local use_input_modifier, do_not_use_input_modifier = true, false

            if self._left_wall
                and not self._left_wall_body:has_tag("slippery")
                and left_is_down
            then
                apply_friction(
                    left_nx, left_ny,
                    self._left_wall_body,
                    use_input_modifier
                )
            end

            if self._right_wall
                and not self._right_wall_body:has_tag("slippery")
                and right_is_down
            then
                apply_friction(
                    right_nx, right_ny,
                    self._right_wall_body,
                    use_input_modifier
                )
            end

            if self._top_left_wall
                and not self._top_left_wall_body:has_tag("slippery")
                and left_is_down
            then
                apply_friction(
                    top_left_nx, top_left_ny,
                    self._top_left_wall_body,
                    do_not_use_input_modifier
                )
            end

            if self._top_wall
                and not self._top_wall_body:has_tag("slippery")
            then
                apply_friction(
                    top_nx, top_ny,
                    self._top_wall_body,
                    do_not_use_input_modifier
                )
            end

            if self._top_right_wall
                and not self._top_right_wall_body:has_tag("slippery")
                and right_is_down
            then
                apply_friction(
                    top_right_nx, top_right_ny,
                    self._top_right_wall_body,
                    do_not_use_input_modifier
                )
            end

            if self._bottom_left_wall
                and not self._bottom_left_wall_body:has_tag("slippery")
                and not down_is_down
                and not is_unwalkable
            then
                apply_friction(
                    bottom_left_nx, bottom_left_ny,
                    self._bottom_left_wall_body,
                   do_not_use_input_modifier
                )
            end

            if self._bottom_wall
                and not self._bottom_wall_body:has_tag("slippery")
                and not down_is_down
            then
                apply_friction(
                    bottom_nx, bottom_ny,
                    self._bottom_wall_body,
                    do_not_use_input_modifier
                )
            end

            if self._bottom_right_wall
                and not self._bottom_right_wall_body:has_tag("slippery")
                and not down_is_down
            then
                apply_friction(
                    bottom_right_nx, bottom_right_ny,
                    self._bottom_right_wall_body,
                    do_not_use_input_modifier
                )
            end

            -- clamp friction
            local velocity_magnitude = math.magnitude(current_velocity_x, current_velocity_y)

            local friction_dx, friction_dy = math.normalize(net_friction_x, net_friction_y)
            local velocity_along_friction = math.dot(
                current_velocity_x, current_velocity_y,
                friction_dx, friction_dy
            )

            -- only oppose motion along friction direction
            if velocity_along_friction < 0 then
                local clamped_magnitude = math.min(
                    math.magnitude(net_friction_x, net_friction_y),
                    -velocity_along_friction
                )

                net_friction_x = friction_dx * clamped_magnitude
                net_friction_y = friction_dy * clamped_magnitude
            else
                net_friction_x = 0
                net_friction_y = 0
            end
        end -- wall friction

        -- vertical movement
        if is_grounded then
            self._jump_blocked = false
        end

        if is_grounded or (left_before == true and self._left_wall == false) then
            self._left_wall_jump_blocked = false
        end

        if is_grounded or (right_before == true and self._right_wall == false) then
            self._right_wall_jump_blocked = false
        end

        -- prevent horizontal movement after walljump
        if self._wall_jump_freeze_elapsed / time_dilation < settings.wall_jump_freeze_duration
            and math.sign(target_velocity_x) == self._wall_jump_freeze_sign
        then
            next_velocity_x = current_velocity_x
        end

        local is_jumping = false
        if not is_movement_disabled and not self:get_is_jump_disabled() then
            if self._jump_elapsed <= settings.jump_duration then
                -- regular jump
                if self._jump_button_is_down then
                    next_velocity_y = -1 * time_dilation * settings.jump_impulse * math.sqrt(self._jump_elapsed / settings.jump_duration)
                    is_jumping = true
                end
            elseif self._wall_jump_elapsed <= settings.wall_jump_duration then
                -- wall jump: initial burst, then small sustain
                if self._wall_jump_elapsed == 0 then
                    local dx, dy = math.cos(settings.wall_jump_initial_angle), math.sin(settings.wall_jump_initial_angle)

                    local should_skip = false

                    local left_wall_jump_allowed, right_wall_jump_allowed = self:_get_walljump_allowed()

                    if left_wall_jump_allowed then
                        self._wall_jump_freeze_sign = -1
                    elseif right_wall_jump_allowed then
                        self._wall_jump_freeze_sign =  1
                    else
                        -- unknown sign, do not wall jump
                        self._wall_jump_elapsed = math.huge
                        should_skip = true
                    end

                    if not should_skip then
                        dx = dx * -1 * self._wall_jump_freeze_sign

                        local burst = settings.wall_jump_initial_impulse + gravity
                        next_velocity_x, next_velocity_y = dx * burst, dy * burst

                        self._wall_jump_freeze_elapsed = 0

                        should_apply_friction = false
                        is_jumping = true
                    end
                elseif self._jump_button_is_down then
                    -- sustained jump, if not sprinting, add additional air time to make up for reduced x speed
                    local dx, dy = math.cos(settings.wall_jump_sustained_angle), math.sin(settings.wall_jump_sustained_angle)

                    if self._wall_jump_freeze_sign == 1 then dx = dx * -1 end
                    local force = settings.wall_jump_sustained_impulse * delta + gravity
                    next_velocity_x = next_velocity_x + dx * force * time_dilation
                    next_velocity_y = next_velocity_y + dy * force * time_dilation

                    should_apply_friction = false
                    is_jumping = true
                end
            else
                -- noop
            end

            self._wall_jump_freeze_elapsed = self._wall_jump_freeze_elapsed + delta
            self._jump_elapsed = self._jump_elapsed + delta
            self._wall_jump_elapsed = self._wall_jump_elapsed + delta

            self._left_wall_coyote_elapsed = self._left_wall_coyote_elapsed + delta
            if left_before == true and self._left_wall == false then
                self._left_wall_coyote_elapsed = 0
            end

            self._right_wall_coyote_elapsed = self._right_wall_coyote_elapsed + delta
            if right_before == true and self._right_wall == false then
                self._right_wall_coyote_elapsed = 0
            end

            self._coyote_elapsed = self._coyote_elapsed + delta
            if is_grounded then
                self._coyote_elapsed = 0
                self._left_wall_coyote_elapsed = math.huge
                self._right_wall_coyote_elapsed = math.huge
            end
        end

        do -- bounce
            local bounce_dx, bounce_dy = self:_update_bounce(delta)
            next_velocity_x = next_velocity_x + bounce_dx
            next_velocity_y = next_velocity_y + bounce_dy
        end

        local is_sliding = false

        -- downwards force
        if not is_movement_disabled
            and not is_frozen
            and down_is_down
            and not ((left_is_down and self._left_wall) or (right_is_down and self._right_wall))
            -- exclude wall clinging, handled by explicit friction release in apply_friction
        then
            local force = 1 / velocity_easing * settings.downwards_force * delta
            if use_analog_input then
                force = force * math.max(0, self._joystick_position_y) -- linear easing, only detect down
            end

            local dx, dy = gravity_direction_x, gravity_direction_y

            if is_grounded then
                local ground_normal_x = bottom_nx or bottom_left_nx or bottom_right_nx
                local ground_normal_y = bottom_ny or bottom_left_ny or bottom_right_ny

                if next_velocity_x > 0 and self._bottom_left_wall then
                    ground_normal_x, ground_normal_y = bottom_left_nx, bottom_left_ny
                elseif next_velocity_x < 0 and self._bottom_right_wall then
                    ground_normal_x, ground_normal_y = bottom_right_nx, bottom_right_ny
                end

                local ground_tangent_x, ground_tangent_y = math.turn_left(ground_normal_x, ground_normal_y)
                local dot = math.dot(ground_tangent_x, ground_tangent_y, next_velocity_x, next_velocity_y)
                local sign = math.sign(dot)

                ground_tangent_x = ground_tangent_x * sign
                ground_tangent_y = ground_tangent_y * sign

                if ground_tangent_y <= 0 then
                    dx, dy = gravity_direction_x, gravity_direction_y
                else
                    dx, dy = ground_tangent_x, ground_tangent_y
                end
            end

            next_velocity_x = next_velocity_x + dx * force
            next_velocity_y = next_velocity_y + dy * force

            if is_grounded then is_sliding = true end
        end

        -- friction
        if not is_sliding and should_apply_friction then
            next_velocity_x = next_velocity_x + net_friction_x
            next_velocity_y = next_velocity_y + net_friction_y
        end

        local is_touching_platform = false
        do -- inherit platform velocity
            local velocity_x, velocity_y, n = 0, 0, 0
            local min_magnitude = 0

            -- heuristically choose which platform to inherit if multiple
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

        -- gravity
        next_velocity_x = next_velocity_x + gravity_direction_x * gravity
        next_velocity_y = next_velocity_y + gravity_direction_y * gravity

        if not is_sliding then
            -- clamp max velocity, sliding removes limit
            next_velocity_x = math.clamp(next_velocity_x, -settings.max_velocity, settings.max_velocity)
            next_velocity_y = math.clamp(next_velocity_y, -settings.max_velocity, settings.max_velocity)
        end

        -- componensate when going up slopes, which would slow down player in stock box2d
        if not is_jumping and self._bottom_wall and (self._bottom_left_wall or self._bottom_right_wall) then
            local should_skip = false
            for body in range(
                self._bottom_left_wall_body,
                self._bottom_right_wall_body,
                self._bottom_wall_body
            ) do
                -- skip accelerators
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

                        -- gravity component along the slope
                        local gravity_along_slope = math.dot(0, gravity, ground_tangent_x, ground_tangent_y)

                        next_velocity_x, next_velocity_y = math.multiply2(
                            ground_tangent_x, ground_tangent_y, (tangent_dot - gravity_along_slope)
                        )
                    end
                end
            end
        end

        -- instant turn around
        if settings.allow_instant_turn_around and self._queue_turn_around == true then
            local vx, vy = current_velocity_x, current_velocity_y
            if self._queue_turn_around_direction == rt.Direction.RIGHT and is_grounded then
                next_velocity_x = math.max(math.abs(vx), settings.instant_turnaround_velocity)
            elseif self._queue_turn_around_direction == rt.Direction.LEFT and is_grounded then
                next_velocity_x = -1 * math.max(math.abs(vx), settings.instant_turnaround_velocity)
            elseif self._queue_turn_around_direction == rt.Direction.DOWN then -- even in air
                next_velocity_y = math.max(math.abs(vy), settings.instant_turnaround_velocity)
            elseif self._queue_turn_around_direction == rt.Direction.UP then
                -- noop
            end

            self._queue_turn_around = false
        end

        next_velocity_x, next_velocity_y = self:apply_damping(next_velocity_x, next_velocity_y)
        next_velocity_x = self._platform_velocity_x + next_velocity_x
        next_velocity_y = self._platform_velocity_y + next_velocity_y

        local net_force_x, net_force_y = self:get_requested_forces()
        self._body:set_velocity(
            next_velocity_x + net_force_x * delta,
            next_velocity_y + net_force_y * delta
        )

        self._last_velocity_x, self._last_velocity_y = next_velocity_x, next_velocity_y

        if is_frozen then
            self._body:set_velocity(next_velocity_x, next_velocity_y)
            self._last_velocity_x, self._last_velocity_y = next_velocity_x, next_velocity_y
        end
    else -- is_bubble == true
        -- bubble movement
        local mass_multiplier = self:get_bubble_mass_factor()
        local bubble_gravity = time_dilation * gravity * (mass_multiplier / delta) * settings.bubble_gravity_factor
        local max_velocity = time_dilation * settings.bubble_target_velocity
        local target_x, target_y = 0, 0
        local current_x, current_y = self._bubble_body:get_velocity()

        if not is_movement_disabled then
            target_x, target_y = self:get_input_direction()
        end

        local next_force_x, next_force_y
        if not (target_x == 0 and target_y == 0) then
            target_x = target_x * max_velocity * mass_multiplier
            target_y = target_y * max_velocity * mass_multiplier
            local acceleration = time_dilation * settings.bubble_acceleration

            next_force_x = (target_x - current_x) * acceleration
            next_force_y = (target_y - current_y) * acceleration
        else
            if gravity > 0 then
                next_force_x = -current_x * settings.bubble_air_resistance * delta
                next_force_y = -current_y * settings.bubble_air_resistance * delta
            else
                next_force_x = 0
                next_force_y = 0
            end
        end

        do -- apply external forces
            local net_force_x, net_force_y = self:get_requested_forces()
            next_force_x = next_force_x + net_force_x
            next_force_y = next_force_y + net_force_y
        end

        self._bubble_body:apply_force(next_force_x, next_force_y)
        self._last_bubble_force_x, self._last_bubble_force_y = next_force_x, next_force_y

        local bounce_dx, bounce_dy = self:_update_bounce(delta)

        if math.magnitude(bounce_dx, bounce_dy) > math.eps then
            self._bubble_body:apply_linear_impulse(
                bounce_dx * mass_multiplier,
                bounce_dy * mass_multiplier
            )
        end

        self._bubble_body:apply_force(
            gravity_direction_x * bubble_gravity,
            gravity_direction_y * bubble_gravity
        )

        self._bubble_body:set_velocity(self:apply_damping(self._bubble_body:get_velocity()))

        self._graphics_body:set_up_squish(false)
        self._graphics_body:set_down_squish(false)
        self._graphics_body:set_left_squish(false)
        self._graphics_body:set_right_squish(false)
    end

    if should_decay_platform_velocity then
        if was_grounded == false and is_grounded == true then
           self._platform_velocity_x = 0
           self._platform_velocity_y = 0
        else
           local decay = math.pow(settings.platform_velocity_decay, delta)
           self._platform_velocity_x = self._platform_velocity_x * decay
           self._platform_velocity_y = self._platform_velocity_y * decay
        end
    end

    -- detect idle
    if not is_disabled and
        use_analog_input
        or self._up_button_is_down
        or self._right_button_is_down
        or self._down_button_is_down
        or self._left_button_is_down
        or self._jump_button_is_down
        or (not is_bubble and not is_grounded)
    then
        self._idle_elapsed = 0
    elseif self:get_is_idle_timer_frozen() == false
        and not is_disabled
        and not is_movement_disabled
        and not is_frozen
    then
        self._idle_elapsed = self._idle_elapsed + delta
    end

    -- detect being squished by moving objects
    if not is_ghost then
        local center_body, to_check, x_positions, y_positions
        if not is_bubble then
            center_body = self._body
            x_positions = self._spring_body_offsets_x
            y_positions = self._spring_body_offsets_y
        else
            center_body = self._bubble_body
            x_positions = self._bubble_spring_body_offsets_x
            y_positions = self._bubble_spring_body_offsets_y
        end

        local r = self:get_radius()
        local center_x, center_y = center_body:get_position()

        -- get all nearby bodies, raycast too unreliable
        local not_player_mask = bit.bnot(bit.bor(settings.player_collision_group, settings.player_outer_body_collision_group))
        local hitbox_mask = rt.settings.overworld.hitbox.collision_group
        local bodies = self._world:query_aabb(
            center_x - r, center_y - r, 2 * r, 2 * r,
            bit.band(not_player_mask, hitbox_mask)
        )

        -- check if all player bodies are inside at least one other body
        local is_squished = function(x, y)
            local squished = false
            for body in values(bodies) do
                if body:get_is_sensor() ~= true and body:test_point(center_x, center_y) then
                    squished = true
                    break
                end
            end

            return squished
        end

        if is_squished(center_x, center_y) then -- least likely to be squished, early exit
            local should_kill = true
            for i = 1, #x_positions do
                local test_x = center_x + x_positions[i]
                local test_y = center_y + y_positions[i]

                if not is_squished(test_x, test_y) then
                    should_kill = false
                    break
                end
            end

            if should_kill then
                self:kill()
            end
        end
    end

    -- update flow
    if self._stage ~= nil and not is_disabled then
        self:_update_flow(delta)
    end

    do -- update trail
        local value = rt.InterpolationFunctions.LINEAR(math.clamp(self:get_flow(), 0, 1))
        self._trail:set_glow_intensity(value)
        self._trail:set_boom_intensity(value * ternary(is_bubble, 0, 1))
        self._trail:set_trail_intensity(value)
    end

    -- timers
    if down_is_down then self._down_button_is_down_elapsed = self._down_button_is_down_elapsed + delta end
    if up_is_down then self._up_button_is_down_elapsed = self._up_button_is_down_elapsed + delta end
    if left_is_down then self._left_button_is_down_elapsed = self._left_button_is_down_elapsed + delta end
    if right_is_down then self._right_button_is_down_elapsed = self._right_button_is_down_elapsed + delta end
    if self._jump_button_is_down then self._jump_button_is_down_elapsed = self._jump_button_is_down_elapsed + delta end
    if self._sprint_button_is_down then self._sprint_button_is_down_elapsed = self._sprint_button_is_down_elapsed + delta end

    -- add blood splatter
    local color_r, color_g, color_b, _ = self._current_color:unpack()
    if self._stage ~= nil and not is_ghost then
        local cx, cy = self:get_position()
        local radius = self:get_radius()
        if is_bubble then
            radius = settings.radius * settings.bubble_radius_factor * 0.5
        end

        local function _add_blood_splatter(contact_x, contact_y, last_contact_x, last_contact_y)
            -- at high velocities, interpolate
            if last_contact_x ~= nil and last_contact_y ~= nil then
                local lcx, lcy = last_contact_x, last_contact_y
                local dx = cx - lcx
                local dy = cy - lcy
                local distance = math.magnitude(dx, dy)

                local step_size = radius * 0.5
                local num_steps = math.max(1, math.ceil(distance / step_size))

                for i = 0, num_steps do
                    local t = i / num_steps
                    local interpolation_x = lcx + dx * t
                    local interpolation_y = lcy + dy * t

                    if math.distance(
                        self._last_position_x, self._last_position_y,
                        interpolation_x, interpolation_y
                    ) < radius then
                        self._stage:get_blood_splatter():add(interpolation_x, interpolation_y, radius, color_r, color_g, color_b, 1)
                    end
                end
            else
                self._stage:get_blood_splatter():add(cx, cy, radius, color_r, color_g, color_b, 1)
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

    do -- update position history
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
        local step = settings.position_history_sample_frequency

        table.remove(self._position_history, #self._position_history)
        table.remove(self._position_history, #self._position_history)
        table.insert(self._position_history, 1, current_y)
        table.insert(self._position_history, 1, current_x)

        self._position_history_path_needs_update = true
    end

    do -- update velocity history
        local body = ternary(is_bubble, self._bubble_body, self._body)
        local current_vx, current_vy = body:get_velocity() -- use sim velocity
        local n = #self._velocity_history
        table.remove(self._velocity_history, #self._velocity_history)
        table.remove(self._velocity_history, #self._velocity_history)
        table.insert(self._velocity_history, 1, current_vy)
        table.insert(self._velocity_history, 1, current_vx)
    end

    if not is_bubble then
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

--- @brief
function rt.Player:move_to_stage(stage)
    self._stage = stage

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
    self._last_flow_fraction = 0

    if world == self._world then return end

    self._world = world
    self._world:set_gravity(0, 0)

    self._last_position_x, self._last_position_y = x, y

    -- hard body
    local inner_body_shape = b2.Circle(0, 0, self._inner_body_radius)
    self._body = b2.Body(
        self._world, b2.BodyType.DYNAMIC, x, y,
        inner_body_shape
    )

    local inner_mask = bit.bnot(settings.exempt_collision_group)
    function initialize_inner_body(body, is_bubble)
        body:set_is_enabled(false)
        body:set_user_data(self)
        body:set_use_continuous_collision(true)
        body:add_tag("player")
        body:set_is_rotation_fixed(true)
        body:set_collision_group(settings.player_collision_group)
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
    local bounce_group = settings.bounce_collision_group
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
    local step = (2 * math.pi) / settings.n_outer_bodies

    local outer_mask = bit.bnot(bit.bor(
        settings.player_outer_body_collision_group,
        settings.exempt_collision_group
    ))

    function initialize_outer_body(body, is_bubble)
        body:set_is_enabled(false)
        body:set_collision_group(settings.player_outer_body_collision_group)
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
        body:set_mass(10e-4 * settings.outer_body_spring_strength)

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

    local bubble_inner_body_shape = b2.Circle(0, 0, self._inner_body_radius * settings.bubble_inner_radius_scale)
    self._bubble_body = b2.Body(
        self._world, b2.BodyType.DYNAMIC, x, y, bubble_inner_body_shape
    )

    initialize_inner_body(self._bubble_body, true)
    self._bubble_body:add_tag("player_bubble")

    local bubble_bounce_shape = love.physics.newCircleShape(self._bubble_body:get_native(), x, y, self._radius * settings.bubble_radius_factor * 0.8)
    bubble_bounce_shape:setFilterData(bounce_group, bounce_group, 0)
    self._bubble_bounce_shape = b2.Circle(0, 0, self._radius * settings.bubble_radius_factor)
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
        body:add_tag("player_bubble")
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

    self:_update_bubble(self:get_is_bubble())

    -- reset history
    self._world:signal_connect("step", function()
        local x, y = self:get_position()
        for i = 1, 2 * settings.position_history_n, 2 do
            self._position_history[i+0] = x
            self._position_history[i+1] = y
        end

        for i = 1, 2 * settings.velocity_history_n, 2 do
            self._velocity_history[i+0] = 0
            self._velocity_history[i+1] = 0
        end

        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function rt.Player:draw_bloom()
    if self:get_is_visible() == false then return end

    if self:get_flow() == 0 then
        self._graphics_body:draw_bloom()
    end
end

--- @brief
function rt.Player:draw_body()
    if self:get_is_visible() == false then return end

    local trail_visible = self:get_is_trail_visible()
    if trail_visible then
        self._trail:draw_below()
    end

    self._graphics_body:draw_body()

    if trail_visible then
        self._trail:draw_above()
    end
end

--- @brief
function rt.Player:draw_core()
    if self:get_is_visible() == false then return end

    local radius = self._core_radius
    local x, y = self:get_position()

    if #self._pulses > 0 then
        local time = love.timer.getTime()
               local mesh = self._pulse_mesh:get_native()
        for pulse in values(self._pulses) do
            local t = 1 - rt.InterpolationFunctions.SINUSOID_EASE_OUT((time - pulse.timestamp) / settings.pulse_duration)

            love.graphics.push()
            love.graphics.translate(x, y)
            love.graphics.scale(2 * radius * settings.pulse_radius_factor * (1 - t))
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
    if self:get_is_visible() == false then return end

    self:draw_body()
    self:draw_core()
end

--- @brief
function rt.Player:get_position(is_bubble)
    if self._body == nil then return 0, 0 end
    if is_bubble == nil then is_bubble = self:get_is_bubble() end

    if is_bubble then
        return self._bubble_body:get_position()
    else
        return self._body:get_position()
    end
end

--- @brief average position, takes deformation into account
function rt.Player:get_centroid(is_bubble)
    if is_bubble == nil then is_bubble = self:get_is_bubble() end

    if self._body == nil then return 0, 0 end
    local body, outer_bodies
    if is_bubble then
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
function rt.Player:teleport_to(x, y, relax_body)
    if relax_body == nil then relax_body = true end

    meta.assert(x, "Number", y, "Number")

    local is_bubble = self:get_is_bubble()

    if self._body ~= nil and self._bubble_body ~= nil then
        if not is_bubble then
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

        if relax_body then
            self._graphics_body:set_position(self:get_position())
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
function rt.Player:get_radius(is_bubble)
    if is_bubble == nil then is_bubble = self:get_is_bubble() end
    if not is_bubble then
        return self._radius
    else
        return self._bubble_radius
    end
end

--- @brief
function rt.Player:get_physics_world()
    return self._world
end

--- @brief
function rt.Player:get_physics_body(is_bubble)
    if is_bubble == nil then is_bubble = self:get_is_bubble() end

    if is_bubble == true then
        return self._bubble_body
    elseif is_bubble == false then
        return self._body
    end
end

--- @brief
function rt.Player:set_velocity(x, y)
    meta.assert(x, "Number", y, "Number")

    if self:get_is_bubble() and self._bubble_body ~= nil then
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
function rt.Player:_update_color()
    local r, g, b, a = rt.lcha_to_rgba(0.8, 1, self._hue, 1)
    self._current_color.r = r
    self._current_color.g = g
    self._current_color.b = b
    self._current_color.a = a
end

--- @brief
function rt.Player:get_hue()
    return self._hue
end

--- @brief
function rt.Player:get_color()
    return self._current_color
end

--- @brief
function rt.Player:get_is_idle()
    return self._idle_elapsed > settings.idle_threshold_duration
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
function rt.Player:_get_walljump_allowed()
    local left_is_down = self._left_button_is_down
        or self._joystick_gesture:get_magnitude(rt.InputAction.LEFT) > settings.joystick_magnitude_left_threshold

    local right_is_down = self._right_button_is_down
        or self._joystick_gesture:get_magnitude(rt.InputAction.RIGHT) > settings.joystick_magnitude_right_threshold

    local left_wall_invalid = (self._left_wall and (self._left_wall_body:has_tag("slippery") or self._left_wall_body:has_tag("unjumpable")))
        or (self._top_left_wall and (self._top_left_wall_body:has_tag("slippery") or self._top_left_wall_body:has_tag("unjumpable")))
        or (self._bottom_left_wall and (self._bottom_left_wall_body:has_tag("slippery") or self._bottom_left_wall_body:has_tag("unjumpable")))

    local right_wall_invalid = (self._right_wall and (self._right_wall_body:has_tag("slippery") or self._right_wall_body:has_tag("unjumpable")))
        or (self._top_right_wall and (self._top_right_wall_body:has_tag("slippery") or self._top_right_wall_body:has_tag("unjumpable")))
        or (self._bottom_right_wall and (self._bottom_right_wall_body:has_tag("slippery") or self._bottom_right_wall_body:has_tag("unjumpable")))

    -- by default, player needs to be pressing towards wall
    local left_wall_jump_allowed = left_is_down and self._left_wall and not left_wall_invalid
    local right_wall_jump_allowed = right_is_down and self._right_wall and not right_wall_invalid

    -- both conditions can be overriden by coyote time
    if not self._is_grounded then
        if not left_wall_jump_allowed then
            left_wall_jump_allowed = self._left_wall_coyote_elapsed < settings.wall_jump_coyote_time and not left_wall_invalid
        end

        if not right_wall_jump_allowed then
            right_wall_jump_allowed = self._right_wall_coyote_elapsed < settings.wall_jump_coyote_time and not right_wall_invalid
        end
    end

    return left_wall_jump_allowed, right_wall_jump_allowed
end

--- @brief
function rt.Player:_get_jump_allowed()
    local bottom = (self._bottom_wall and not self._bottom_wall_body:has_tag("unjumpable"))
        or (not self._left_wall and not self._right_wall and self._coyote_elapsed <= settings.coyote_time)

    local regular_jump_allowed = not self._jump_blocked and bottom

    -- only bottom counts for grounded check, but bottom left/right can override with tags
    if self._bottom_left_wall and self._bottom_left_wall_body:has_tag("unjumpable") or
        self._bottom_right_wall and self._bottom_right_wall_body:has_tag("unjumpable")
    then
        regular_jump_allowed = false
    end

    return regular_jump_allowed
end

--- @brief
function rt.Player:jump()
    local jumped = false

    -- evaluate wall conditions
    local left_wall_jump_allowed, right_wall_jump_allowed = self:_get_walljump_allowed()

    -- wall jumps have priority, left before right
    if left_wall_jump_allowed then
        self._wall_jump_elapsed = 0
        jumped = true
        self._left_wall_jump_blocked = true
    elseif right_wall_jump_allowed then
        self._wall_jump_elapsed = 0
        jumped = true
        self._right_wall_jump_blocked = true
    else
        -- else try regular jump
        local regular_jump_allowed = self:_get_jump_allowed()

        local jump_allowed_override = self:get_jump_allowed_override()
        if jump_allowed_override == true then
            self._jump_blocked = false
            self._left_wall_jump_blocked = false
            self._right_wall_jump_blocked = false
        end

        if jump_allowed_override ~= nil then
            regular_jump_allowed = jump_allowed_override
        end

        if not self._is_grounded
            and regular_jump_allowed == false
            and not table.is_empty(self._double_jump_sources)
        then
            -- consume double jump source if necessary
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

            regular_jump_allowed = true
        end

        if regular_jump_allowed then
            self._jump_elapsed = 0
            self._jump_blocked = true
            jumped = true
        end
    end

    if jumped then
        self:signal_emit("jump")
        self._jump_buffer_elapsed = math.huge
    end

    return jumped
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
    local velocity_x, velocity_y = self._position_history_path:tangent_at(t)
    return position_x, position_y, velocity_x, velocity_y
end

--- @brief
function rt.Player:get_past_position_path(distance)
    if self._position_history_path_needs_update == true then
        self._position_history_path:create_from_and_reparameterize(self._position_history)
        self._position_history_path_needs_update = nil
    end

    return self._position_history_path
end

--- @brief
function rt.Player:get_idle_elapsed()
    return self._idle_elapsed
end

--- @brief
function rt.Player:get_is_ducking()
    return self._is_ducking
end

--- @brief
function rt.Player:reset()
    self:set_velocity(0, 0)

    self._platform_velocity_x = 0
    self._platform_velocity_y = 0
    self._position_override_active = false
    self._position_override_x = nil
    self._position_override_y = nil

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
        self._current_sprint_multiplier = settings.sprint_multiplier
        self._target_sprint_multiplier = settings.sprint_multiplier
        self._next_sprint_multiplier = settings.sprint_multiplier
        self._next_sprint_multiplier_update_when_grounded = false
    else
        self._current_sprint_multiplier = 1
        self._target_sprint_multiplier = 1
        self._next_sprint_multiplier = 1
        self._next_sprint_multiplier_update_when_grounded = false
    end

    _clear(self._double_jump_sources)
    _clear(self._bounce_sources)
    _clear(self._flow_sources)

    for which in range(
        self._is_visible_requests,
        self._is_frozen_requests,
        self._is_disabled_requests,
        self._is_ghost_requests,
        self._is_bubble_requests,
        self._is_movement_disabled_requests,
        self._is_jump_disabled_requests,
        self._is_jump_allowed_override_requests,
        self._is_trail_visible_requests,
        self._is_flow_froze_requests,
        self._is_idle_timer_frozen_requests,
        self._opacity_requests,
        self._time_dilation_requests,
        self._gravity_multiplier_requests,
        self._gravity_direction_requests,
        self._force_requests,
        self._damping_requests
    ) do
        _clear(which)
    end

    local is_bubble = self:get_is_bubble()
    self._graphics_body:set_use_contour(is_bubble)
    self._graphics_body:relax()
    self._graphics_body:set_position(self:get_position())

    self._graphics_body:set_down_squish(false)
    self._graphics_body:set_left_squish(false)
    self._graphics_body:set_right_squish(false)
    self._graphics_body:set_up_squish(false)
end

--- @brief
function rt.Player:relax()
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
        local is_bubble = self:get_is_bubble()

        for body in values(self._spring_bodies) do
            body:set_is_enabled(not is_bubble)
        end

        for body in values(self._bubble_spring_bodies) do
            body:set_is_enabled(is_bubble)
        end

        return meta.DISCONNECT_SIGNAL
    end)

    self._last_velocity_x, self._last_velocity_y = 0, 0
    self._last_position_x, self._last_position_y = self:get_position()

    self._graphics_body:set_position(self._last_position_x, self._last_position_y)
    self._graphics_body:relax()
end

--- @brief
function rt.Player:pulse(color_maybe)
    if color_maybe ~= nil then
        meta.assert(color_maybe, rt.RGBA)
    end

    table.insert(self._pulses, {
        timestamp = love.timer.getTime(),
        color = color_maybe or self._current_color
    })
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

--- @brief
function rt.Player:get_bubble_mass_factor()
    return self._bubble_mass / self._mass
end

--- @brief
function rt.Player:kill(should_explode)
    if self._stage ~= nil then
        if should_explode == nil then should_explode = true end
        self._stage:get_active_checkpoint():spawn(true, should_explode)
    end
end

--- @brief
function rt.Player:get_input_direction()
    local dx, dy = 0, 0
    if not self._use_analog_input then
        if self._left_button_is_down then
            dx = -1
        end

        if self._right_button_is_down then
            dx = 1
        end

        if self._up_button_is_down then
            dy = -1
        end

        if self._down_button_is_down then
            dy = 1
        end
    else
        dx, dy = self._joystick_position_x, self._joystick_position_y
    end

    return dx, dy
end

--- @brief
function rt.Player:get_use_analog_input()
    return self._use_analog_input
end

--- @brief
function rt.Player:get_trail_is_visible()
    for source in values(self._trail_is_visible_requests) do
        if source.is_visible == false then return false end
    end

    return true
end

--- @brief
function rt.Player:get_jump_allowed_override()
    local override = nil

    for key, source in pairs(self._is_jump_allowed_override_requests) do
        if source.is_allowed == false then override = false end
        if source.is_allowed == true then return true end
    end

    return override
end

--- @brief
function rt.Player:get_opacity()
    local factor = 1
    for source in values(self._opacity_requests) do
        factor = factor * source.opacity
    end
    return factor
end


for tuple in range(
--- @alias request_is_visible fun(id: Object, is_visible: Boolean)
    { "is_visible", { [1] = { "is_visible", "Boolean" }}},

--- @alias request_is_frozen fun(id: Object, is_frozen: Boolean)
    { "is_frozen", { [1] = { "is_frozen", "Boolean" }}},

--- @alias request_is_disabled fun(id: Object, is_disabled: Boolean)
    { "is_disabled", { [1] = { "is_disabled", "Boolean" }}},

--- @alias request_is_movement_disabled fun(id: Object, is_disabled: Boolean)
    { "is_movement_disabled", { [1] = { "is_disabled", "Boolean" }}},

--- @alias request_is_jump_disabled fun(id: Object, is_disabled: Boolean)
    { "is_jump_disabled", { [1] = { "is_disabled", "Boolean" }}},

--- @alias request_is_jump_allowed_override fun(id: Object, is_allowed: Boolean)
    { "is_jump_allowed_override", { [1] = { "is_allowed", "Boolean" }}},

--- @alias request_is_trail_visible fun(id: Object, is_visible: Boolean)
    { "is_trail_visible", { [1] = { "is_visible", "Boolean" }}},

--- @alias request_is_flow_frozen fun(id: Object, is_frozen: Boolean)
    { "is_flow_frozen", { [1] = { "is_frozen", "Boolean" }}},

--- @alias request_is_idle_timer_frozen fun(id: Object, is_frozen: Boolean)
    { "is_idle_timer_frozen", { [1] = { "is_frozen", "Boolean" }}},

--- @alias request_opacity fun(id: Object, opacity: Number)
    { "opacity", { [1] = { "opacity", "Number" }}},

--- @alias request_time_dilation fun(id: Object, factor: Number)
    { "time_dilation", { [1] = { "dilation", "Number" }}},

--- @alias request_gravity_multiplier fun(id: Object, factor: Number)
    { "gravity_multiplier", { [1] = { "multiplier", "Number" }}},

--- @alias request_gravity_direction fun(id: Object, dx: Number, dy: Number)
    { "gravity_direction", { [1] = { "dx", "Number" }, [2] = { "dy", "Number" }}},

--- @alias request_force fun(id: Object, dx: Number, dy: Number)
    { "force", { [1] = { "dx", "Number" }, [2] = { "dy", "Number" }}}
) do
    local which, args_table = table.unpack(tuple)
    rt.Player["request_" .. which] = function(self, id, ...)
        if id == nil then
            rt.error("In ", "request_" .. which, ": argument #1 is nil")
        end

        local requests = self["_" .. which .. "_requests"]

        local should_remove = true
        for i = 1, select("#", ...) do
            if select(i, ...) ~= nil then
                should_remove = false
                break
            end
        end

        if should_remove then
            -- remove request
            requests[id] = nil
            return id
        else
            local entry = requests[id]
            if entry == nil then
                entry = {}
                requests[id] = entry
            end

            for arg_i = 1, #args_table do
                local arg = select(arg_i, ...)
                local arg_name, arg_type = table.unpack(args_table[arg_i])
                meta.assert_typeof(arg, arg_type, arg_i + 1)
                entry[arg_name] = arg
            end

            return id
        end
    end
end

--- @brief
function rt.Player:get_is_visible()
    for source in values(self._is_visible_requests) do
        if source.is_visible == false then return false end
    end

    return true
end

--- @brief
function rt.Player:get_is_frozen()
    for source in values(self._is_frozen_requests) do
        if source.is_frozen == true then return true end
    end

    return false
end

--- @brief
function rt.Player:get_is_disabled()
    for source in values(self._is_disabled_requests) do
        if source.is_disabled == true then return true end
    end

    return false
end

--- @brief
function rt.Player:request_is_ghost(id, is_ghost)
    local before = self:get_is_ghost()

    local requests = self._is_ghost_requests
    local should_remove = is_ghost == nil

    if should_remove then
        requests[id] = nil
    else
        local entry = requests[id]
        if entry == nil then
            entry = {}
            requests[id] = entry
        end

        entry.is_ghost = is_ghost
    end

    local after self:get_is_ghost()

    if before ~= after then
        self:_set_is_ghost(after)
    end
end

--- @brief
function rt.Player:_set_is_ghost(b)
    if self._body == nil or self._bubble_body == nil then return end

    local inner_group, outer_group
    local inner_mask, outer_mask

    if b == true then
        inner_group, outer_group = settings.ghost_collision_group, settings.ghost_outer_body_collision_group
        inner_mask, outer_mask = settings.ghost_collision_group, settings.ghost_collision_group
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
    local bounce_group = settings.bounce_collision_group
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
    for source in values(self._is_ghost_requests) do
        if source.is_ghost == true then return true end
    end

    return false
end

--- @brief
function rt.Player:get_is_bubble()
    for key, source in pairs(self._is_bubble_requests) do
        if source.is_bubble == true then
            return true
        end
    end

    return false
end

--- @brief
function rt.Player:request_is_bubble(id, is_bubble)
    local before = self:get_is_bubble()

    local requests = self._is_bubble_requests
    local should_remove = is_bubble == nil

    if should_remove then
        requests[id] = nil
    else
        local entry = requests[id]
        if entry == nil then
            entry = {}
            requests[id] = entry
        end

        entry.is_bubble = is_bubble
    end

    local after = self:get_is_bubble()

    if before ~= after then
        self:_update_bubble(after)
    end

    return id
end

--- @brief
function rt.Player:_update_bubble(is_bubble)
    self._last_bubble_force_x = 0
    self._last_bubble_force_y = 0
    _clear(self._body_to_collision_normal)

    self._jump_elapsed = math.huge
    self._wall_jump_elapsed = math.huge
    self._bounce_elapsed = math.huge
    self._wall_jump_freeze_elapsed = math.huge

    if self._world == nil then return end

    -- disable both to avoid interaction
    self._body:set_is_enabled(false)
    for body in values(self._spring_bodies) do
        body:set_is_enabled(false)
    end

    self._bubble_body:set_is_enabled(false)
    for body in values(self._bubble_spring_bodies) do
        body:set_is_enabled(false)
    end

    if is_bubble == true then
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
    if not is_bubble then
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

    -- delay to after next physics update, because solver needs time to resolve spring after synch teleport
    self._use_bubble_mesh_delay_n_steps = 4
    self._world:signal_connect("step", function()
        if self._use_bubble_mesh_delay_n_steps <= 0 then
            local is_bubble = self:get_is_bubble()
            self._use_bubble_mesh = is_bubble
            self:signal_emit("bubble", is_bubble)

            return meta.DISCONNECT_SIGNAL
        else
            self._use_bubble_mesh_delay_n_steps = self._use_bubble_mesh_delay_n_steps - 1
        end
    end)
end

--- @brief
function rt.Player:get_is_movement_disabled()
    for source in values(self._is_movement_disabled_requests) do
        if source.is_disabled == true then return true end
    end

    return false
end

--- @brief
function rt.Player:get_is_jump_disabled()
    for source in values(self._is_jump_disabled_requests) do
        if source.is_disabled == true then return true end
    end

    return false
end

--- @brief
function rt.Player:get_is_trail_visible()
    for source in values(self._is_trail_visible_requests) do
        if source.is_visible == false then return false end
    end

    return true
end

--- @brief
function rt.Player:get_is_flow_frozen()
    for source in values(self._is_flow_froze_requests) do
        if source.is_frozen == true then return true end
    end

    return true
end

--- @brief
function rt.Player:get_is_idle_timer_frozen()
    for source in values(self._is_idle_timer_frozen_requests) do
        if source.is_frozen == true then return true end
    end

    return true
end

--- @brief
function rt.Player:get_time_dilation()
    local t = 1
    for source in values(self._time_dilation_requests) do
        t = t * source.dilation
    end

    return t
end

--- @brief
function rt.Player:get_gravity_multiplier()
    local factor = 1
    for source in values(self._gravity_multiplier_requests) do
        factor = factor * source.multiplier
    end

    return factor
end

--- @brief
function rt.Player:get_gravity_direction()
    local dx, dy = 0, 1
    for source in values(self._gravity_direction_requests) do
        dx = dx + source.dx
        dy = dy + source.dy
    end

    return math.normalize(dx, dy)
end

--- @brief
function rt.Player:get_requested_forces()
    local net_force_x, net_force_y = 0, 0
    for entry in values(self._force_requests) do
        net_force_x = net_force_x + (entry.dx or 0)
        net_force_y = net_force_y + (entry.dy or 0)
    end

    return net_force_x, net_force_y
end

--- @brief
function rt.Player:request_damping(id, up, right, down, left)
    local requests = self._damping_requests
    local should_remove = up == nil and right == nil and down == nil and left == nil

    if should_remove then
        requests[id] = nil
        return id
    else
        if up ~= nil then meta.assert_typeof(up, "Number", 2) end
        if right ~= nil then meta.assert_typeof(up, "Number", 3) end
        if down ~= nil then meta.assert_typeof(up, "Number", 4) end
        if left ~= nil then meta.assert_typeof(up, "Number", 5) end

        local entry = requests[id]
        if entry == nil then
            entry = {}
            requests[id] = entry
        end

        entry.up = up or 1
        entry.right = right or 1
        entry.down = down or 1
        entry.left = left or 1

        return id
    end
end

--- @brief
function rt.Player:apply_damping(vx, vy)
    for entry in values(self._damping_requests) do
        if vx < 0 then vx = vx * entry.left end
        if vx > 0 then vx = vx * entry.right end
        if vy < 0 then vy = vy * entry.up end
        if vy > 0 then vy = vy * entry.down end
    end

    return vx, vy
end

--- @brief
function rt.Player:bounce(direction_x, direction_y, magnitude)
    if magnitude == nil then
        local nvx, nvy = self._last_velocity_x, self._last_velocity_y
        magnitude = math.mix(
            settings.bounce_min_force,
            settings.bounce_max_force,
            math.min(1, math.magnitude(nvx, nvy) / settings.bounce_relative_velocity)
        )
    end

    meta.assert(direction_x, "Number", direction_y, "Number", magnitude, "Number")

    -- keep direction non-normalized

    local entry = {
        direction_x = direction_x,
        direction_y = direction_y,
        magnitude = magnitude,
        elapsed = 0
    }

    table.insert(self._bounce_sources, entry)

    return magnitude / settings.bounce_max_force
end

--- @brief
function rt.Player:_update_bounce(delta)
    delta = delta * self:get_time_dilation()

    local impulse_x, impulse_y = 0, 0
    local to_remove = {}
    for i, source in ipairs(self._bounce_sources) do
        local fraction = math.min(1, source.elapsed / settings.bounce_duration)

        local magnitude = (1 - fraction) * source.magnitude
        impulse_x = impulse_x + source.direction_x * magnitude
        impulse_y = impulse_y + source.direction_y * magnitude
        source.elapsed = source.elapsed + delta

        if fraction >= 1 then
            table.insert(to_remove, 1, i)
        end
    end

    for i in values(to_remove) do
        table.remove(self._bounce_sources, i)
    end

    return impulse_x, impulse_y
end

--- @brief
function rt.Player:add_flow_source(id, duration, flow_per_second)
    local requests = self._flow_sources
    local should_remove = duration == nil and flow_per_second == nil

    if should_remove then
        requests[id] = nil
        return id
    else
        if duration == nil then duration = settings.flow_source_default_duration end
        if flow_per_second == nil then flow_per_second = settings.flow_source_default_magnitude end

        local entry = requests[id]
        if entry == nil then
            entry = {}
            requests[id] = entry
        end

        entry.duration = duration
        entry.elapsed = 0
        entry.flow_per_second = flow_per_second

        return id
    end
end

--- @brief
function rt.Player:remove_flow_source(id)
    self._flow_sources[id] = nil
end

--- @brief
function rt.Player:reset_flow(value)
    _clear(self._flow_sources)
    self._current_flow = value or 0
end

--- @brief
function rt.Player:get_flow()
    return self._current_flow
end

--- @brief
function rt.Player:_update_flow(delta)
    if self:get_is_flow_frozen() then return end

    local to_add = 0

    local to_remove = {}
    for id, source in values(self._flow_sources) do
        to_add = to_add + source.flow_per_second * delta

        source.elapsed = source.elapsed + delta
        if source.elapsed >= source.duration then
            table.insert(to_remove, id)
        end
    end

    for id in values(to_remove) do
        self._flow_sources[id] = nil
    end

    to_add = to_add - settings.flow_decay_per_second * delta

    self._current_flow = math.clamp(self._current_flow + to_add, 0, 1)
end