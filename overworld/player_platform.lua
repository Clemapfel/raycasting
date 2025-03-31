require "common.input_subscriber"
require "physics.physics"
require "common.blend_mode"

local velocity = 200

rt.settings.overworld.player = {
    radius = 10,

    max_velocity_x = velocity, -- px / s
    max_velocity_y = 3 * velocity,
    grounded_ray_length_factor = 1.5,
    sprint_multiplier = 2.5,

    jump_total_force = 1600,
    jump_duration = 13 / 60,

    coyote_time = 6 / 60
}

--- @class ow.Player
--- @signal movement_start (self, position_x, position_y) -> nil
--- @signal movement_stop (self, position_x, position_y) -> nil
ow.Player = meta.class("OverworldPlayer")
meta.add_signals(ow.Player,
    "movement_start",
    "movement_stop"
)

local _gravity = 1500

function ow.Player:instantiate(scene, stage)
    local player_radius = rt.settings.overworld.player.radius

    meta.install(self, {
        _scene = scene,
        _shapes = { b2.Circle(0, 0, player_radius) },
        _radius = player_radius,
        _input = rt.InputSubscriber(),

        _is_midair = true,
        _is_midair_timer = 0,
        _last_known_grounded_y = math.huge,

        _left_wall = false,
        _right_wall = false,

        _velocity_sign = 0, -- left or right
        _velocity_magnitude = 0,
        _velocity_multiplier = 1,

        _next_multiplier_apply_when_grounded = false,
        _next_multiplier = 1,
        
        _jump_button_down = false,
        _jump_elapsed = 0
    })

    self:_connect_input()
end

--- @brie
function ow.Player:get_is_midair()
    local _, current_y = self._body:get_position()
    current_y = math.huge --current_y + self._radius
    dbg(self._is_midair_timer < rt.settings.overworld.player.coyote_time)
    if current_y >= self._last_known_grounded_y and self._is_midair_timer < rt.settings.overworld.player.coyote_time then
        return false
    else
        return self._is_midair
    end
end

--- @brief
function ow.Player:_connect_input()
    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputButton.A then
            if not self:get_is_midair() then
                self._jump_elapsed = 0
                self._is_midair_timer = math.huge -- prevent double jump during coyote time
            end
            self._jump_button_down = true
        elseif which == rt.InputButton.B then
            self._next_multiplier = rt.settings.overworld.player.sprint_multiplier
            self._next_multiplier_apply_when_grounded = true
        end
    end)

    self._input:signal_connect("released", function(_, which)
        if which == rt.InputButton.A then
        elseif which == rt.InputButton.B then
            self._next_multiplier = 1
            self._next_multiplier_apply_when_grounded = true
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
    local max_velocity = rt.settings.overworld.player.max_velocity_x
    local acceleration_duration = rt.settings.overworld.player.digital_movement_acceleration_duration

    local velocity_x = self._velocity_sign * self._velocity_magnitude * self._velocity_multiplier * max_velocity

    if self._jump_button_down then
        self._jump_elapsed = self._jump_elapsed + delta
        local total_force = rt.settings.overworld.player.jump_total_force
        local multiplier = self._velocity_multiplier -- in [1, ...]
        local magnitude = self._velocity_magnitude -- in [0, 1]
        local adjusted_force = total_force
        local duration = rt.settings.overworld.player.jump_duration
        local fraction = math.min(self._jump_elapsed / duration, 1)
        local impulse = (adjusted_force * delta) / duration
        self._body:apply_linear_impulse(0, -1 * impulse * (1 - fraction))
    end

    local vx, vy = self._body:get_velocity()
    self._body:set_velocity(
        velocity_x,
        math.max(vy, -1 * rt.settings.overworld.player.max_velocity_y) -- only limit upwards speed
    )

    local x, y = self._body:get_position()
    local r = self._radius * rt.settings.overworld.player.grounded_ray_length_factor
    local mask = bit.bnot(b2.CollisionGroup.GROUP_16)
    local before = self._is_midair
    self._is_midair = self._world:query_ray_any(x, y, 0, r, mask) == nil

    if self._is_midair == true then
        self._last_known_grounded_y = select(2, self._body:get_position()) + self._radius
    end

    self._is_midair_timer = self._is_midair_timer + delta
    if before == false and self._is_midair == true then
        self._is_midair_timer = 0
    end


    self._left_wall = self._world:query_ray_any(x, y, -r, 0, mask) ~= nil
    self._right_wall = self._world:query_ray_any(x, y, r, 0, mask) ~= nil

    if not self._is_midair and self._next_multiplier_apply_when_grounded then
        self._velocity_multiplier = self._next_multiplier
        self._next_multiplier_apply_when_grounded = false
    end
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