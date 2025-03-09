require "common.input_subscriber"
require "physics.physics"

local velocity = 200
rt.settings.overworld.player = {
    radius = 10,
    velocity = velocity, -- px / s
    acceleration = 2 * velocity,
    deceleration = 10 * velocity,
    velocity_magnitude_history_n = 3
}

--- @class ow.Player
--- @signal movement_start (self, position_x, position_y) -> nil
--- @signal movement_stop (self, position_x, position_y) -> nil
ow.Player = meta.class("OverworldPlayer")

meta.add_signals(ow.Player,
    "movement_start",
    "movement_stop"
)

--- @brief
function ow.Player:instantiate(stage)
    local vertices = {}
    local radius = rt.settings.overworld.player.radius
    local n_outer_vertices = 6
    local angle_step = (2 * math.pi) / n_outer_vertices
    local offset = 0
    for angle = 0, 2 * math.pi, angle_step do
        table.insert(vertices, 0 + radius * math.cos(angle - offset))
        table.insert(vertices, 0 + radius * math.sin(angle - offset))
    end

    meta.install(self, {
        _shapes = { b2.Polygon(vertices), b2.Circle(0, 0, radius * 0.95) },
        _input = rt.InputSubscriber(),

        _facing_angle = 0,

        _velocity_angle = 0,
        _velocity_magnitude = 0,
        _velocity_multiplier = 1,

        _direction_indicator_x = 0,
        _direction_indicator_y = 0,

        _position_last_x = 0,
        _position_last_y = 0,
        _n_stuck_frames = 0,

        _up_pressed = false,
        _down_pressed = false,
        _left_pressed = false,
        _right_pressed = false,

        _velocity_magnitude_history = {},
        _velocity_magnitude_sum = 0,
        _is_moving = false
    })

    for i = 1, rt.settings.overworld.player.velocity_magnitude_history_n do
        table.insert(self._velocity_magnitude_history, 0)
    end

    self._input:signal_connect("pressed", function(_, which)
        self:_handle_button(which, true)
    end)

    self._input:signal_connect("released", function(_, which)
        self:_handle_button(which, false)
    end)

    if stage ~= nil then self:move_to_stage(stage) end
end

--- @brief
function ow.Player:move_to_stage(stage)
    local world = stage:get_physics_world()
    local player_x, player_y = stage:get_player_spawn()

    self._world = world
    self._body = b2.Body(
        world, b2.BodyType.KINEMATIC,
        player_x, player_y,
        self._shapes
    )

    self:teleport_to(player_x, player_y)
end

--- @brief
function ow.Player:teleport_to(x, y)
    self._position_last_x = x
    self._position_last_y = y
    self._position_current_x = x
    self._position_current_y = y
    if self._body ~= nil then
        self._body:set_position(x, y)
    end
end

--- @brief
function ow.Player:get_position()
    return self._body:get_position()
end

--- @brief
function ow.Player:get_predicted_position(delta)
    local magnitude = self._velocity_magnitude_sum / rt.settings.overworld.player.velocity_magnitude_history_n
    local velocity_x = math.cos(self._velocity_angle) * magnitude * delta
    local velocity_y = math.sin(self._velocity_angle) * magnitude * delta

    local x, y = self._body:get_position()
    return x + velocity_x * delta, y + velocity_y * delta
end

--- @brief
function ow.Player:draw()
    self._body:draw()

    if self._velocity_magnitude > 0 then
        love.graphics.setPointSize(5)
        love.graphics.points(self._direction_indicator_x, self._direction_indicator_y)
    end
end

--- @brief
function ow.Player:set_facing_angle(angle)
    self._facing_angle = angle
end

local _last_x, _last_y

--- @brief
function ow.Player:update(delta)
    local acceleration = rt.settings.overworld.player.acceleration
    local deceleration = rt.settings.overworld.player.deceleration
    local current = self._velocity_magnitude
    if self._up_pressed or self._right_pressed or self._down_pressed or self._left_pressed then
        self._velocity_magnitude = current + acceleration * delta
    else
        self._velocity_magnitude = current - deceleration * delta
    end
    self._velocity_magnitude = math.clamp(self._velocity_magnitude, 0, rt.settings.overworld.player.velocity)

    local angle_offset = 2 * math.pi - self._facing_angle
    local velocity_x = math.cos(self._velocity_angle + angle_offset)
    local velocity_y = math.sin(self._velocity_angle + angle_offset)

    self._body:set_velocity(
        velocity_x * self._velocity_magnitude * self._velocity_multiplier,
        velocity_y * self._velocity_magnitude * self._velocity_multiplier
    )

    local radius = rt.settings.overworld.player.radius
    local x, y = self._body:get_position()
    self._direction_indicator_x, self._direction_indicator_y = x + velocity_x * radius, y + velocity_y * radius

    -- push body in the opposite direction of collision normal
    local cx, cy = self._body:get_position()
    local lx, ly = self._position_last_x, self._position_last_y

    local actual_velocity_x, actual_velocity_y = cx - self._position_last_x, cy - self._position_last_y
    local actual_velocity = math.magnitude(actual_velocity_x, actual_velocity_y)

    local eps = 0.01
    local past_velocity = self._velocity_magnitude_sum / #self._velocity_magnitude_history
    if actual_velocity >= eps and self._is_moving == false then
        self:signal_emit("movement_start", cx, cy)
        self._is_moving = true
    elseif actual_velocity <= eps and self._is_moving == true then
        self:signal_emit("movement_stop", cx, y)
        self._is_moving = false
    end

    self._velocity_magnitude_sum = self._velocity_magnitude_sum + actual_velocity - self._velocity_magnitude_history[1]
    table.insert(self._velocity_magnitude_history, actual_velocity)
    table.remove(self._velocity_magnitude_history, 1)

    self._position_last_x, self._position_last_y = self._body:get_position()
end

--- @brief
function ow.Player:_handle_button(which, pressed_or_released)
    if which == rt.InputButton.LEFT then
        self._left_pressed = pressed_or_released
    end

    if which == rt.InputButton.RIGHT then
        self._right_pressed = pressed_or_released
    end

    if which == rt.InputButton.UP then
        self._up_pressed = pressed_or_released
    end

    if which == rt.InputButton.DOWN then
        self._down_pressed = pressed_or_released
    end

    local dx = 0
    local dy = 0

    if self._left_pressed then dx = dx - 1 end
    if self._right_pressed then dx = dx + 1 end
    if self._up_pressed then dy = dy - 1 end
    if self._down_pressed then dy = dy + 1 end

    if math.abs(dx) > 0 or math.abs(dy) > 0 then -- do not reset direction to 0
        self._velocity_angle = math.atan2(dy, dx)
        self._body:set_rotation(self._velocity_angle)
    end

    if which == rt.InputButton.A then
        if pressed_or_released then
            self._body:set_collision_response_type(b2.CollisionResponseType.GHOST)
        else
            local before = self._body:get_collision_response_type()
            self._body:set_collision_response_type(b2.CollisionResponseType.SLIDE)
            if before ~= b2.CollisionResponseType.SLIDE then
                self._world:_notify_push_needed(self._body)
            end
        end
    end

    if which == rt.InputButton.B then
        if pressed_or_released then
            self._velocity_multiplier = 2
        else
            self._velocity_multiplier = 1
        end
    end
end