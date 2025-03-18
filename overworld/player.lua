require "common.input_subscriber"
require "physics.physics"
require "overworld.ray_cast"
require "overworld.ray_material"
require "overworld.player_body"
require "common.blend_mode"
require "common.sound_manager"
require "common.timed_animation"

local velocity = 200
rt.settings.overworld.player = {
    radius = 10,

    velocity = velocity, -- px / s
    sprint_multiplier = 2.5,
    digital_movement_acceleration_duration = 10 / 60, -- time until 100% speed is reached

    velocity_magnitude_history_n = 3,

    activator_n_rays = 16,
    activator_ray_arc = (2 * math.pi) / 4,
    activator_ray_length = 40,

    activation_sound_id = "player_activation",
    bump_sound_id = "player_bump",
}

--- @class ow.Player
--- @signal movement_start (self, position_x, position_y) -> nil
--- @signal movement_stop (self, position_x, position_y) -> nil
ow.Player = meta.class("OverworldPlayer")
meta.add_signals(ow.Player,
    "movement_start",
    "movement_stop"
)

function ow.Player:instantiate(scene, stage)
    local player_radius = rt.settings.overworld.player.radius

    meta.install(self, {
        _scene = scene,
        _shapes = { b2.Circle(0, 0, player_radius * 0.5) },
        _radius = player_radius,
        _input = rt.InputSubscriber(),

        _velocity_angle = 0,
        _velocity_magnitude = 0,
        _velocity_multiplier = 1,
        _is_accelerating = false,

        _last_position_x = 0, -- for true velocity calculation
        _last_position_y = 0,
        _velocity_magnitude_history = table.rep(0, rt.settings.overworld.player.velocity_magnitude_history_n), -- position prediction
        _velocity_magnitude_sum = 0,
        _is_moving = false, -- for signal emission

        _digital_control_activate = true,
        _up_pressed_timer = 0,
        _right_pressed_timer = 0,
        _down_pressed_timer = 0,
        _left_pressed_timer = 0,
        _up_pressed = false,
        _right_pressed = false,
        _down_pressed = false,
        _left_pressed = false,

        _facing_angle = 0, -- angle offset of camera

        _model_body = {},
        _model_face = {},

        _raycast = nil,

        _activation_active = false,
        _timeout_elapsed = 0,

        _grabbed = nil
    })

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

    self:_connect_input()
end

--- @brief
function ow.Player:_update_velocity_angle(dx, dy)
    if math.abs(dx) > 0 or math.abs(dy) > 0 then -- do not reset direction on 0
        self._velocity_angle = math.atan2(dy, dx)
        self._body:set_rotation(self._velocity_angle)
    end
end

--- @brief
function ow.Player:_connect_input()
    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputButton.A then
            if self._activation_active == false then
                self:_activate()
                self._activation_active = true
            end
            return
        elseif which == rt.InputButton.B then
            self._velocity_multiplier = rt.settings.overworld.player.sprint_multiplier
            return
        end

        if which == rt.InputButton.UP then
            self._up_pressed = true
            self._up_pressed_timer = 0
        elseif which == rt.InputButton.RIGHT then
            self._right_pressed = true
            self._right_pressed_timer = 0
        elseif which == rt.InputButton.DOWN then
            self._down_pressed = true
            self._down_pressed_timer = 0
        elseif which == rt.InputButton.LEFT then
            self._left_pressed = true
            self._left_pressed_timer = 0
        end
    end)

    self._input:signal_connect("released", function(_, which)
        if which == rt.InputButton.A then
            self._activation_active = false
            return
        elseif which == rt.InputButton.B then
            self._velocity_multiplier = 1
            return
        end

        if which == rt.InputButton.UP then
            self._up_pressed = false
            self._up_pressed_timer = 0
        elseif which == rt.InputButton.RIGHT then
            self._right_pressed = false
            self._right_pressed_timer = 0
        elseif which == rt.InputButton.DOWN then
            self._down_pressed = false
            self._down_pressed_timer = 0
        elseif which == rt.InputButton.LEFT then
            self._left_pressed = false
            self._left_pressed_timer = 0
        end
    end)

    self._input:signal_connect("left_joystick_moved", function(_, x, y)
        self:_update_velocity_angle(x, y)
        self._velocity_magnitude = math.magnitude(x, y)
    end)

    self._input:signal_connect("right_joystick_moved", function(_, x, y)
        if self._velocity_magnitude <= 0 then
            self:_update_velocity_angle(x, y)
        end
    end)
end

--- @brief
function ow.Player:update(delta)
    self._timeout_elapsed = self._timeout_elapsed - delta

    local max_velocity = rt.settings.overworld.player.velocity
    local velocity_x, velocity_y

    local up, right, down, left = self._up_pressed, self._right_pressed, self._down_pressed, self._left_pressed
    if self._input:get_input_method() == rt.InputMethod.KEYBOARD then

        if up then self._up_pressed_timer = self._up_pressed_timer + delta end
        if right then self._right_pressed_timer = self._right_pressed_timer + delta end
        if down then self._down_pressed_timer = self._down_pressed_timer + delta end
        if left then self._left_pressed_timer = self._left_pressed_timer + delta end

        local max_t = rt.settings.overworld.player.digital_movement_acceleration_duration
        local _accel = function(x) return x^3.5 end
        local factor = 1 + self._velocity_magnitude

        local up_pressed_t = _accel(math.min(factor * self._up_pressed_timer / max_t, 1))
        local right_pressed_t = _accel(math.min(factor * self._right_pressed_timer / max_t, 1))
        local down_pressed_t = _accel(math.min(factor * self._down_pressed_timer / max_t, 1))
        local left_pressed_t = _accel(math.min(factor * self._left_pressed_timer / max_t, 1))

        -- digital movement
        local dx, dy = 0, 0

        if up then dy = dy - up_pressed_t end
        if right then dx = dx + right_pressed_t end
        if down then dy = dy + down_pressed_t end
        if left then dx = dx - left_pressed_t end

        if math.abs(dx) > 0 or math.abs(dy) > 0 then
            self._velocity_magnitude = math.magnitude(dx, dy)
            self._velocity_angle = math.atan2(math.normalize(dy, dx))
        else
            self._velocity_magnitude = 0
        end
    end

    -- analog sets these directly
    velocity = math.clamp(self._velocity_magnitude, 0, 1) * max_velocity
    velocity_x = math.cos(self._velocity_angle - self._facing_angle)
    velocity_y = math.sin(self._velocity_angle - self._facing_angle)

    if self._timeout_elapsed > 0 then
        velocity_x = 0
        velocity_y = 0
    end

    self._body:set_velocity(
        velocity_x * velocity * self._velocity_multiplier,
        velocity_y * velocity * self._velocity_multiplier
    )

    self._bump_sensor:set_position(self._body:get_position())

    -- update graphics
    local x, y = self._body:get_predicted_position()
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

    self._soft_body:update(delta)
end

--- @brief [internal]
function ow.Player:_activate()
    local angle = self._velocity_angle - self._facing_angle
    local ray_length = rt.settings.overworld.player.activator_ray_length
    local n_rays = rt.settings.overworld.player.activator_n_rays
    local angle_arc = rt.settings.overworld.player.activator_ray_arc
    local origin_x, origin_y = self._body:get_position() -- sic, not predicted

    local cast = function(x, y)
        local cx, cy, _, _, body = self._world:query_ray_any(
            origin_x,
            origin_y,
            x * ray_length,
            y * ray_length
        )

        if body ~= nil then
            assert(not body:has_tag("player"))
            if body:signal_try_emit("activate") then
                rt.SoundManager:play(rt.settings.overworld.player.activation_sound_id)
                return true
            end
        end

        return false
    end

    if cast(math.cos(angle), math.sin(angle)) then return end
    for i = 2, n_rays do
        if i % 2 == 0 then
            local offset = (i / 2) * (angle_arc / n_rays)
            if cast(math.cos(angle - offset), math.sin(angle - offset)) then
                return
            end
        else
            local offset = (i - 1) / 2 * (angle_arc / n_rays)
            if cast(math.cos(angle + offset), math.sin(angle + offset)) then
                return
            end
        end
    end
end

--- @brief
function ow.Player:move_to_stage(stage, x, y)
    meta.assert(stage, "Stage", x, "Number", y, "Number")

    local world = stage:get_physics_world()
    if self._world ~= world then
        self._world = world

        -- create physics bodies
        self._body = b2.Body(
            self._world, b2.BodyType.DYNAMIC,
            x, y,
            self._shapes
        )
        self._body:add_tag("player")
        self._body:set_is_rotation_fixed(false)
        self._body:set_user_data(self)
        self._body:set_collision_group(ow.RayMaterial.ABSORPTIVE)

        self._bump_sensor = b2.Body(
            self._world, b2.BodyType.DYNAMIC,
            x, y,
            b2.Circle(0, 0, self._radius)
        )
        self._bump_sensor:set_collides_with(b2.CollisionGroup.GROUP_01)
        self._bump_sensor:set_collision_group(self._body:get_collision_group())
        self._bump_sensor:set_is_sensor(true)

        local _bumped = {}
        self._bump_sensor:signal_connect("collision_start", function(_, other)
            if _bumped[other] ~= true then
                if meta.typeof(other:get_user_data()) == "OverworldHitbox" then
                    rt.SoundManager:play(rt.settings.overworld.player.bump_sound_id)
                    _bumped[other] = true
                end
            end
        end)

        self._bump_sensor:signal_connect("collision_end", function(_, other)
            _bumped[other] = nil
        end)

        local mask = b2.CollisionGroup.ALL
        mask = bit.bxor(mask, ow.RayMaterial.FILTRATIVE) -- player can pass through filtrative
        self._body:set_collides_with(mask)

        self._soft_body = ow.PlayerBody(self._world, self._radius, self._body)
    end
end

--- @brief
function ow.Player:draw()

    local x, y = self._body:get_predicted_position()
    local angle = self._velocity_angle - self._facing_angle

    love.graphics.setLineWidth(1)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)

    --[[
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.polygon("fill", table.unpack(self._model_face))
    love.graphics.ellipse("fill", table.unpack(self._model_body))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.polygon("line", table.unpack(self._model_face))
    love.graphics.ellipse("line", table.unpack(self._model_body))
    ]]--
    love.graphics.pop()

    --self._bump_sensor:draw()
    self._soft_body:draw()

    if self._grabbed ~= nil then
        self._grabbed:draw()
    end

    if self._activation_active then
        local ray_length = rt.settings.overworld.player.activator_ray_length
        local n_rays = rt.settings.overworld.player.activator_n_rays
        local angle_arc = rt.settings.overworld.player.activator_ray_arc
        local origin_x, origin_y = self._body:get_position()

        local cast = function(x, y)
            love.graphics.line(
                origin_x,
                origin_y,
                origin_x + x * ray_length,
                origin_y + y * ray_length
            )
        end

        cast(math.cos(angle), math.sin(angle))
        for i = 2, n_rays do
            if i % 2 == 0 then
                local offset = (i / 2) * (angle_arc / n_rays)
                cast(math.cos(angle - offset), math.sin(angle - offset))
            else
                local offset = (i - 1) / 2 * (angle_arc / n_rays)
                cast(math.cos(angle + offset), math.sin(angle + offset))
            end
        end
    end
end

--- @brief
function ow.Player:set_facing_angle(angle)
    self._facing_angle = angle
end

--- @brief
function ow.Player:get_position()
    return self._body:get_position()
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
function ow.Player:get_velocity()
    local velocity_x = math.cos(self._velocity_angle - self._facing_angle)
    local velocity_y = math.sin(self._velocity_angle - self._facing_angle)

    return velocity_x * self._velocity_magnitude * self._velocity_multiplier,
    velocity_y * self._velocity_magnitude * self._velocity_multiplier
end

--- @brief
function ow.Player:set_timeout(seconds)
    self._timeout_elapsed = seconds
end

--- @brief
function ow.Player:get_radius()
    return self._radius
end
