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
        _is_accelerating = false,

        _last_position_x = 0, -- for true velocity calculation
        _last_position_y = 0,

        _facing_angle = 0, -- angle offset of camera

        _direction_indicator_x = 0, -- graphics
        _direction_indicator_y = 0,

        _velocity_magnitude_history = {}, -- position prediction
        _velocity_magnitude_sum = 0,

        _is_moving = false, -- for signal emission
    })

    self._input:signal_connect("pressed", function(_, which)
        self:_handle_button(which, true)
    end)

    self._input:signal_connect("released", function(_, which)
        self:_handle_button(which, false)
    end)

    self._input:signal_connect("left_joystick_moved", function(_, x, y)
        self:_handle_joystick(x, y, true)
    end)

    for i = 1, rt.settings.overworld.player.velocity_magnitude_history_n do
        table.insert(self._velocity_magnitude_history, 0)
    end

    if stage ~= nil then self:move_to_stage(stage) end
end

--- @brief
function ow.Player:_update_velocity_angle(dx, dy)
    if math.abs(dx) > 0 or math.abs(dy) > 0 then -- do not reset direction to 0
        self._velocity_angle = math.atan2(dy, dx)
        self._body:set_rotation(self._velocity_angle)
    end
end

--- @brief
function ow.Player:_handle_joystick(x, y, left_or_right)
    if left_or_right == true then
        self:_update_velocity_angle(x, y)
        self._is_accelerating = math.magnitude(x, y) > 0
    end
end

do

    local _left_pressed = false
    local _right_pressed = false
    local _up_pressed = false
    local _down_pressed = false

    --- @brief
    function ow.Player:_handle_button(which, pressed_or_released)
        local dx, dy = 0, 0

        if which == rt.InputButton.LEFT then
            _left_pressed = pressed_or_released
        end

        if which == rt.InputButton.RIGHT then
            _right_pressed = pressed_or_released
        end

        if which == rt.InputButton.UP then
            _up_pressed = pressed_or_released
        end

        if which == rt.InputButton.DOWN then
            _down_pressed = pressed_or_released
        end

        if _left_pressed then dx = dx - 1 end
        if _right_pressed then dx = dx + 1 end
        if _up_pressed then dy = dy - 1 end
        if _down_pressed then dy = dy + 1 end

        self:_update_velocity_angle(dx, dy)
        self._is_accelerating = _left_pressed or _right_pressed or _up_pressed or _down_pressed

        -- TODO
        if which == rt.InputButton.B then
            if pressed_or_released == false then
                self._body:set_is_solid(true)
            else
                self._body:set_is_solid(false)
                self._body._transform.x, self._body._transform.y = self._world._native:push(self._body, function() return true end, self._body._transform.x, self._body._transform.y)
            end
        end
    end
end

--- @brief
function ow.Player:update(delta)
    -- update velocity and position
    local acceleration = rt.settings.overworld.player.acceleration
    local deceleration = rt.settings.overworld.player.deceleration
    local max_velocity = rt.settings.overworld.player.velocity

    local current = self._velocity_magnitude
    if self._is_accelerating then
        self._velocity_magnitude = current + acceleration * delta
    else
        self._velocity_magnitude = current - deceleration * delta
    end
    self._velocity_magnitude = math.clamp(self._velocity_magnitude, 0, max_velocity)

    local angle_offset = 2 * math.pi - self._facing_angle
    local velocity_x = math.cos(self._velocity_angle - self._facing_angle)
    local velocity_y = math.sin(self._velocity_angle - self._facing_angle)

    self._body:set_velocity(
        velocity_x * self._velocity_magnitude * self._velocity_multiplier,
        velocity_y * self._velocity_magnitude * self._velocity_multiplier
    )

    -- update graphics
    local radius = rt.settings.overworld.player.radius
    local x, y = self._body:get_position()
    self._direction_indicator_x, self._direction_indicator_y = x + velocity_x * radius, y + velocity_y * radius

    local actual_velocity_x, actual_velocity_y = x - self._last_position_x, y - self._last_position_y
    local actual_velocity = math.magnitude(actual_velocity_x, actual_velocity_y)

    local eps = 0.01
    local past_velocity = self._velocity_magnitude_sum / #self._velocity_magnitude_history
    if actual_velocity >= eps and self._is_moving == false then
        self:signal_emit("movement_start", x, y)
        self._is_moving = true
    elseif actual_velocity <= eps and self._is_moving == true then
        self:signal_emit("movement_stop", x, y)
        self._is_moving = false
    end

    self._velocity_magnitude_sum = self._velocity_magnitude_sum + actual_velocity - self._velocity_magnitude_history[1]
    table.insert(self._velocity_magnitude_history, actual_velocity)
    table.remove(self._velocity_magnitude_history, 1)

    self._last_position_x, self._last_position_y = x, y
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
    self._body:add_tag("player")

    self:teleport_to(player_x, player_y)
end

--- @brief
function ow.Player:set_facing_angle(angle)
    self._facing_angle = angle
end

--- @brief
function ow.Player:teleport_to(x, y)
    if self._body ~= nil then
        self._body:set_position(x, y)
        self._last_position_x = x
        self._last_position_y = y
    end
end

--- @brief
function ow.Player:get_position()
    return self._body:get_position()
end

--- @brief
function ow.Player:get_velocity()
    local angle_offset = 2 * math.pi - self._facing_angle
    local velocity_x = math.cos(self._velocity_angle - self._facing_angle)
    local velocity_y = math.sin(self._velocity_angle - self._facing_angle)

    return velocity_x * self._velocity_magnitude * self._velocity_multiplier,
        velocity_y * self._velocity_magnitude * self._velocity_multiplier
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

