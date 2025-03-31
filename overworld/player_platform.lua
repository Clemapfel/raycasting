require "common.input_subscriber"
require "physics.physics"
require "common.blend_mode"

local velocity = 200

rt.settings.overworld.player = {
    radius = 10,

    velocity = velocity, -- px / s
    grounded_ray_length_factor = 1.5,
    sprint_multiplier = 2.5,

    jump_n_ticks = 10,
    jump_tick_strength = 0.08, -- times gravity
    jump_tick_duration = 1 / 60
}

--- @class ow.Player
--- @signal movement_start (self, position_x, position_y) -> nil
--- @signal movement_stop (self, position_x, position_y) -> nil
ow.Player = meta.class("OverworldPlayer")
meta.add_signals(ow.Player,
    "movement_start",
    "movement_stop"
)

local _gravity = 1000

function ow.Player:instantiate(scene, stage)
    local player_radius = rt.settings.overworld.player.radius

    meta.install(self, {
        _scene = scene,
        _shapes = { b2.Circle(0, 0, player_radius) },
        _radius = player_radius,
        _input = rt.InputSubscriber(),

        _is_midair = true,
        _left_wall = false,
        _right_wall = false,

        _velocity_sign = 0, -- left or right
        _velocity_magnitude = 0,
        _velocity_multiplier = 1,
        
        _jump_button_down = false,
        _jump_n_ticks_left = 0,
        _jump_tick_elapsed = 0,
    })

    self:_connect_input()
end

--- @brief
function ow.Player:_connect_input()
    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputButton.A then
            if not self._is_midair then
                self._jump_n_ticks_left = rt.settings.overworld.player.jump_n_ticks
                self._jump_tick_elapsed = 0
                local vx, vy = self._body:get_velocity()
                self._body:set_velocity(vx, 0)
            end
            self._jump_button_down = true
        elseif which == rt.InputButton.B then
        end
    end)

    self._input:signal_connect("released", function(_, which)
        if which == rt.InputButton.A then
            self._jump_button_down = false
            self._jump_n_ticks_left = 0
        elseif which == rt.InputButton.B then
        end
    end)

    self._input:signal_connect("left_joystick_moved", function(_, x, y)
        self._velocity_sign = math.sign(x)
        self._velocity_magnitude = math.magnitude(x, y)
    end)

    self._input:signal_connect("right_joystick_moved", function(_, x, y)
        -- noop
    end)
end


--- @brief
function ow.Player:update(delta)
    local max_velocity = rt.settings.overworld.player.velocity
    local acceleration_duration = rt.settings.overworld.player.digital_movement_acceleration_duration

    if self._jump_button_down then
        self._jump_tick_elapsed = self._jump_tick_elapsed + delta
        local step = rt.settings.overworld.player.jump_tick_duration
        local max_ticks = rt.settings.overworld.player.jump_n_ticks
        local strength = rt.settings.overworld.player.jump_tick_strength
        while self._jump_tick_elapsed > step and self._jump_n_ticks_left > 0 do
            self._body:apply_linear_impulse(0, -1 * strength * _gravity)
            self._jump_tick_elapsed = self._jump_tick_elapsed - step
            self._jump_n_ticks_left = self._jump_n_ticks_left - 1
        end
    end

    local velocity_x = self._velocity_sign * self._velocity_magnitude * max_velocity
    local vx, vy = self._body:get_velocity()
    self._body:set_velocity(velocity_x, vy)

    local x, y = self._body:get_position()
    local r = self._radius * rt.settings.overworld.player.grounded_ray_length_factor
    local mask = bit.bnot(b2.CollisionGroup.GROUP_16)
    self._is_midair = self._world:query_ray_any(x, y, 0, r, mask) == nil
    self._left_wall = self._world:query_ray_any(x, y, -r, 0, mask) ~= nil
    self._right_wall = self._world:query_ray_any(x, y, r, 0, mask) ~= nil
end

--- @brief
function ow.Player:move_to_stage(stage, x, y)
    meta.assert(stage, "Stage", x, "Number", y, "Number")

    local world = stage:get_physics_world()
    if self._world ~= world then
        self._world = world
        self._world:set_gravity(0, _gravity)

        -- create physics bodies
        self._body = b2.Body(
            self._world, b2.BodyType.DYNAMIC,
            x, y,
            self._shapes
        )
        self._body:add_tag("player")
        self._body:set_is_rotation_fixed(true)
        self._body:set_collision_group(b2.CollisionGroup.GROUP_16)
        self._body:set_mass(1)
    end
end

--- @brief
function ow.Player:draw()
    self._body:draw()

    if not self._is_midair then rt.Palette.GREEN:bind() else rt.Palette.RED:bind() end
    local x, y = self._body:get_position()
    local r = self._radius * rt.settings.overworld.player.grounded_ray_length_factor
    love.graphics.line(x, y, x + 0, y + r)

    if self._left_wall then rt.Palette.GREEN:bind() else rt.Palette.RED:bind() end
    love.graphics.line(x, y, x - r, y)

    if self._right_wall then rt.Palette.GREEN:bind() else rt.Palette.RED:bind() end
    love.graphics.line(x, y, x + r, y)
end

--- @brief
function ow.Player:get_position()
    return self._body:get_position()
end

--- @brief
function ow.Player:teleport_to(x, y)
    if self._body ~= nil then
        self._body:set_position(x, y)
    end
end

--- @brief
function ow.Player:get_velocity()
    local _, vy = self._body:get_velocity()
    return self._velocity_sign * self._velocity_magnitude * self._velocity_multiplier, vy
end

--- @brief
function ow.Player:set_facing_angle()
    --rt.warning("ow.Player.set_facing_angle: TODO")
end

--- @brief
function ow.Player:get_radius()
    return self._radius
end