require "common.input_subscriber"
require "physics.physics"
require "overworld.ray_cast"
require "overworld.ray_material"
require "common.blend_mode"
require "common.sound_manager"

local velocity = 200
rt.settings.overworld.player = {
    radius = 10,
    velocity = velocity, -- px / s
    acceleration = 2 * velocity,
    deceleration = 10 * velocity,
    sprint_multiplier = 3,
    velocity_magnitude_history_n = 3,

    activator_n_rays = 9,
    activator_ray_arc = (2 * math.pi) / 4,
    activator_ray_length = 30,

    activation_sound_id = "player_activation_sound"
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
        _shapes = { b2.Circle(0, 0, player_radius) },
        _radius = player_radius,
        _input = rt.InputSubscriber(),

        _velocity_angle = 0,
        _velocity_magnitude = 0,
        _velocity_multiplier = 1,
        _is_accelerating = false,

        _last_position_x = 0, -- for true velocity calculation
        _last_position_y = 0,

        _facing_angle = 0, -- angle offset of camera

        _velocity_indicator_x = 0, -- graphics
        _velocity_indicator_y = 0,

        _model_body = {},
        _model_face = {},

        _velocity_magnitude_history = {}, -- position prediction
        _velocity_magnitude_sum = 0,

        _is_moving = false, -- for signal emission
        _raycast = nil,
        _raycast_active = false,

        _activation_active = false,

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
    self._raycast:start(px, py, mx - px, my - py)
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

        if which == rt.InputButton.A then
            if self._activation_active == false and pressed_or_released then
                self:_activate()
            end
            self._activation_active = pressed_or_released
        elseif which == rt.InputButton.X then
            if pressed_or_released == true then
                self:_update_raycast()
            else
                self._raycast:stop()
            end
            self._raycast_active = pressed_or_released
        elseif which == rt.InputButton.B then
            if pressed_or_released == false then
                self._velocity_multiplier = 1
            else
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

    if actual_velocity >= eps and self._raycast_active then
        self:_update_raycast()
    end
end

--- @brief
function ow.Player:_create_physics_body(x, y)
    if self._body ~= nil then self._body:destroy() end

    self._body = b2.Body(
        self._world, b2.BodyType.DYNAMIC,
        x, y,
        self._shapes
    )
    self._body:add_tag("player")
    self._body:set_is_rotation_fixed(true)
    self._body:set_user_data(self)
    self._body:set_collision_group(ow.RayMaterial.TRANSMISSIVE)

    local mask = b2.CollisionGroup.ALL
    mask = bit.bxor(mask, ow.RayMaterial.FILTRATIVE) -- player can pass through filtrative
    self._body:set_collides_with(mask)
end

--- @brief
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
            y * ray_length,
            bit.bnot(ow.RayMaterial.TRANSMISSIVE)
        )

        if body ~= nil then
            assert(not body:has_tag("player"))
            if body:has_tag("activatable") then
                local data = body:get_user_data()
                if data == nil then
                    rt.warning("In ow.Player._activate: body has `activatable` tag but user data is not set")
                    return true
                end

                if data.signal_emit == nil or data:signal_has_signal("activate") == false then
                    rt.warning("In ow.Player._activate: body has `activatable` tag but user data `" .. meta.typeof(data) .. "` is not a signal emitter")
                    return true
                end

                local out = data:signal_try_emit("activate")
                if out == true then
                    rt.SoundManager:player(rt.settings.overworld.player.activation_sound_id)
                end
                return out
            end
        end
    end

    local hue_step = 1 / n_rays
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
        self:_create_physics_body(x, y)
    end

    self._raycast = ow.Raycast(self._scene, world)
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
    local velocity_x = math.cos(self._velocity_angle - self._facing_angle)
    local velocity_y = math.sin(self._velocity_angle - self._facing_angle)

    return velocity_x * self._velocity_magnitude * self._velocity_multiplier,
        velocity_y * self._velocity_magnitude * self._velocity_multiplier
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
    local angle = self._velocity_angle - self._facing_angle

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

    if self._activation_active then
        local ray_length = rt.settings.overworld.player.activator_ray_length
        local n_rays = rt.settings.overworld.player.activator_n_rays
        local angle_arc = rt.settings.overworld.player.activator_ray_arc
        local origin_x, origin_y = self._body:get_position() -- sic, not predicted

        local cast = function(x, y)
            love.graphics.line(
                origin_x,
                origin_y,
                origin_x + x * ray_length,
                origin_y + y * ray_length
            )
        end

        local hue_step = 1 / n_rays
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
function ow.Player:draw()
    self:_draw_model()
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
