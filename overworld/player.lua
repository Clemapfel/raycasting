require "common.input_subscriber"
require "physics.physics"

local max_velocity = 200
rt.settings.overworld.player = {
    radius = 10,
    max_velocity = max_velocity, -- px / s
    acceleration = 2 * max_velocity,
    deceleration = 10 * max_velocity
}

--- @class
ow.Player = meta.class("OverworldPlayer")

--- @brief
function ow.Player:instantiate(stage)

    local vertices = {}
    local radius = 3 * rt.settings.overworld.player.radius
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
        _velocity_angle = 0,
        _velocity_magnitude = 0,

        _direction_indicator_x = 0,
        _direction_indicator_y = 0,

        _position_last_x = 0,
        _position_last_y = 0,
        _n_stuck_frames = 0,

        _up_pressed = false,
        _down_pressed = false,
        _left_pressed = false,
        _right_pressed = false
    })

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
function ow.Player:draw()
    self._body:draw()

    if self._velocity_magnitude > 0 then
        love.graphics.setPointSize(5)
        love.graphics.points(self._direction_indicator_x, self._direction_indicator_y)
    end
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
    self._velocity_magnitude = math.clamp(self._velocity_magnitude, 0, rt.settings.overworld.player.max_velocity)

    local velocity_x = math.cos(self._velocity_angle)
    local velocity_y = math.sin(self._velocity_angle)

    self._body:set_velocity(velocity_x * self._velocity_magnitude, velocity_y * self._velocity_magnitude)

    local radius = rt.settings.overworld.player.radius
    local x, y = self._body:get_position()
    self._direction_indicator_x, self._direction_indicator_y = x + velocity_x * radius, y + velocity_y * radius

    -- push body in the opposite direction of collision normal
    local cx, cy = self._body:get_position()
    local lx, ly = self._position_last_x, self._position_last_y

    local eps = 10e-4
    if self._velocity_magnitude > eps and math.magnitude(cx - lx, cy - ly) < eps then
        if self._n_stuck_frames > 20 then
        end
        self._n_stuck_frames = self._n_stuck_frames + 1
    else
        self._n_stuck_frames = 0
    end

    self._position_last_x, self._position_last_y = cx, cy
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
end