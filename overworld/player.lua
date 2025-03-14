require "common.input_subscriber"
require "physics.physics"
require "overworld.raycast"
require "common.blend_mode"

local velocity = 200
rt.settings.overworld.player = {
    radius = 10,
    activator_radius_factor = 1,
    velocity = velocity, -- px / s
    acceleration = 2 * velocity,
    deceleration = 10 * velocity,
    sprint_multiplier = 3,
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

ow.PlayerCollisionGroup = b2.CollisionGroup.GROUP_16

function ow.Player:instantiate(scene, stage)
    local player_radius = rt.settings.overworld.player.radius
    local activator_radius = rt.settings.overworld.player.activator_radius_factor * player_radius

    meta.install(self, {
        _scene = scene,
        _shapes = { b2.Circle(0, 0, player_radius) },
        _activator_shapes = { b2.Circle(0, 0, activator_radius) },
        _radius = player_radius,
        _activator_radius = activator_radius,
        _input = rt.InputSubscriber(),

        _velocity_angle = 0,
        _velocity_magnitude = 0,
        _velocity_multiplier = 1,
        _is_accelerating = false,

        _last_position_x = 0, -- for true velocity calculation
        _last_position_y = 0,

        _facing_angle = 0, -- angle offset of camera

        _activator = nil, -- b2.Body

        _velocity_indicator_x = 0, -- graphics
        _velocity_indicator_y = 0,

        _model_body = {},
        _model_face = {},

        _velocity_magnitude_history = {}, -- position prediction
        _velocity_magnitude_sum = 0,

        _is_moving = false, -- for signal emission
        _raycast = nil,
        _raycast_active = false,

        _timeout_elapsed = 0,
        _is_disabled = false
    })

    self:_update_model()

    self._input:signal_connect("pressed", function(_, which)
        self:_handle_button(which, true)
    end)

    self._input:signal_connect("released", function(_, which)
        self:_handle_button(which, false)
    end)

    self._input:signal_connect("left_joystick_moved", function(_, x, y)
        self:_handle_joystick(x, y, true)
    end)

    self._input:signal_connect("mouse_moved", function(_, x, y)
        if self._raycast_active then self:_update_raycast() end
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

--- @brief [internal]
function ow.Player:_update_raycast()
    local px, py = self._body:get_position()
    local mx, my = love.mouse.getPosition()
    mx, my = self._scene._camera:screen_xy_to_world_xy(mx, my)

    local angle = math.atan(py - my, px - mx)
    self._raycast:cast(px, py, mx - px, my - py)
    self._raycast_active = true
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

        if which == rt.InputButton.A and self._raycast ~= nil then
            self._activator:set_is_enabled(pressed_or_released)
            if pressed_or_released == true then self:_update_raycast() end
            self._raycast_active = pressed_or_released
        end

        if which == rt.InputButton.B then
            if pressed_or_released == false then
                self._body:set_collides_with(b2.CollisionGroup.ALL)
                self._velocity_multiplier = 1
            else
                self._body:set_collides_with(b2.CollisionGroup.NONE)
                self._velocity_multiplier = rt.settings.overworld.player.sprint_multiplier
            end
        end
    end
end

--- @brief
function ow.Player:update(delta)
    self._timeout_elapsed = self._timeout_elapsed - delta

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

    local velocity_x = math.cos(self._velocity_angle - self._facing_angle)
    local velocity_y = math.sin(self._velocity_angle - self._facing_angle)

    if self._is_disabled or self._timeout_elapsed > 0 then
        velocity_x = 0
        velocity_y = 0
    end

    self._body:set_velocity(
        velocity_x * self._velocity_magnitude * self._velocity_multiplier,
        velocity_y * self._velocity_magnitude * self._velocity_multiplier
    )

    local activator_x, activator_y = self._body:get_predicted_position()
    local angle = self._velocity_angle + self._facing_angle
    activator_x = activator_x + math.cos(angle) * (self._radius + 0.5 * self._activator_radius)
    activator_y = activator_y + math.sin(angle) * (self._radius + 0.5 * self._activator_radius)
    self._activator:set_position(
        activator_x, activator_y
    )

    -- update graphics
    local x, y = self._body:get_position()
    self._velocity_indicator_x = x + math.cos(self._velocity_angle + self._facing_angle) * self._radius
    self._velocity_indicator_y = y + math.sin(self._velocity_angle + self._facing_angle) * self._radius

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

    if actual_velocity >= eps and self._raycast_active then
        self:_update_raycast()
    end

    if self._activation_active then
        self._activation_active = false
    end
end

--- @brief
function ow.Player:_create_physics_body(x, y)
    if self._body ~= nil then self._body:destroy() end
    if self._activator ~= nil then self._activator:destroy() end

    self._body = b2.Body(
        self._world, b2.BodyType.DYNAMIC,
        x, y,
        self._shapes
    )
    self._body:add_tag("player")
    self._body:set_is_rotation_fixed(true)
    self._body:set_user_data(self)
    self._body:set_collision_group(b2.CollisionGroup.GROUP_16)

    self._activator = b2.Body(
        self._world, b2.BodyType.DYNAMIC,
        x, y,
        self._activator_shapes
    )
    self._activator:set_is_sensor(true)
    self._activator:add_tag("activator")
    self._activator:set_does_not_collide_with(b2.CollisionGroup.GROUP_16)
    self._activator:set_is_enabled(false)

    self._activation_candidates = {}
    local n_candidates = 0

    self._activator:signal_connect("collision_start", function(a, other)
        other:add_tag("draw")
    end)

    self._activator:signal_connect("collision_end",  function(_, other)
        other:remove_tag("draw")
    end)
end

--- @brief
function ow.Player:_activate()
end

--- @brief
function ow.Player:move_to_stage(stage, x, y)
    local world = stage:get_physics_world()
    if x == nil then
        x, y = stage:get_player_spawn()
    end

    if self._world ~= world then
        self._world = world
        self:_create_physics_body(x, y)
    end

    self._raycast = ow.Raycast(world)
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
function ow.Player:set_timeout(seconds)
    self._timeout_elapsed = seconds
end

--- @brief [internal]
function ow.Player:_update_model()
    local x, y = 0, 0
    local radius = self._radius
    self._model_face = { -- polygon vertices
        x, y - radius,
        x + 1.5 * radius, y,
        x, y + radius
    }

    self._model_body = { -- ellipse
        x, y,
        radius, radius
    }
end

--- @brief [internal]
function ow.Player:_draw_model()
    local x, y = self._body:get_predicted_position()
    local angle = self._velocity_angle + self._facing_angle

    love.graphics.setLineWidth(1)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)

    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.polygon("fill", table.unpack(self._model_face))
    love.graphics.ellipse("fill", table.unpack(self._model_body))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.polygon("line", table.unpack(self._model_face))
    love.graphics.ellipse("line", table.unpack(self._model_body))

    love.graphics.pop()
end

--- @brief
function ow.Player:draw()
    self:_draw_model()

   -- if self._activation_active then
        self._activator:draw()
    --end

    if self._velocity_magnitude > 0 then
        love.graphics.setPointSize(5)
        love.graphics.points(self._velocity_indicator_x, self._velocity_indicator_y)
    end

    if self._raycast_active then self._raycast:draw() end
end

--- @brief
function ow.Player:set_is_disabled(b)
    self._is_disabled = b
end

--- @brief
function ow.Player:get_is_disabled()
    return self._is_disabled
end

--- @brief
function ow.Player:get_radius()
    return self._radius
end
