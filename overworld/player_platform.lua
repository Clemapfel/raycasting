require "common.input_subscriber"
require "physics.physics"
require "common.blend_mode"

--[[
WISHLIST:

Wind Tunnels
    apply force while inside sensor

Teleporters:
    already done

Portals:
    render player to canvas
    slice canvas along axis of portal
    teleport player if centroid moves through portal

Bouncy Pads:
    body with a bunch of prismatic joints as springs?

Button / Motor: already done

Seasaw:
    pivot join in the middle

Fog door:
    one-sided chain shape on top
    sensor, saves when leaving sensor

Hook:
    sensor body, when player overlaps, weld joint to center
    solver should smoothly snap player to hook

Respawn Checkpoint:
    black/white cross with sensor below it
    if player enters sensor, cross turns player color

Anti-Gravity Body
    sensor, if overlap, player:setAffectedByGravity(enter_exit)
    also add small force upwards

Pause Menu

Main Menu

Keybindings



Chunked Loading?



]]--

local velocity = 200

rt.settings.overworld.player = {
    radius = 13.5,

    max_velocity_x = velocity, -- px / s
    max_velocity_y = 3 * velocity,
    grounded_ray_length_factor = 1.5,
    sprint_multiplier = 2,

    jump_total_force = 1400,
    jump_duration = 13 / 60,

    downwards_force = 10000,
    squeeze_force = 15000,
    n_outer_bodies = 31,
    ground_collision_ray_span = 0.01 * math.pi,

    digital_movement_acceleration_duration = 10 / 60,
    air_deceleration_duration = 0.8, -- n seconds until 0
    ground_deceleration_duration = 0.1,
    max_spring_length_factor = 1.5,

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
        _spring_body_radius = (player_radius * 2 * math.pi) / rt.settings.overworld.player.n_outer_bodies / 2,

        _input = rt.InputSubscriber(),

        _is_midair = true,
        _is_midair_timer = 0,
        _last_known_grounded_y = math.huge,
        _last_known_grounded_sign = 0,

        _left_wall = false,
        _right_wall = false,
        _top_wall = false,

        _velocity_sign = 0, -- left or right
        _velocity_magnitude = 0,
        _velocity_multiplier = 1,

        _next_multiplier_apply_when_grounded = false,
        _next_multiplier = 1,
        
        _jump_button_down = false,
        _jump_elapsed = 0,

        _down_button_down = false,

        -- digital movements
        _left_is_down = false,
        _right_is_down = false,
        _digital_movement_timer = 0,

        _walljump_allowed = true,

        -- analog movement
        _joystick_position = 0,

        -- softbody
        _spring_bodies = {},
        _spring_joints = {},
        _spring_colors = {},
        _spring_is_sensor = {},
    })

    self:_connect_input()
end

local _JUMP_BUTTONS = {
    [rt.InputButton.A] = true
}

local _SPRINT_BUTTON = {
    [rt.InputButton.B] = true,
    [rt.InputButton.L] = true,
    [rt.InputButton.R] = true
}

--- @brie
function ow.Player:get_is_midair()
    local _, current_y = self._body:get_position()
    if current_y >= self._last_known_grounded_y and self._is_midair_timer < rt.settings.overworld.player.coyote_time then
        return false
    else
        return self._is_midair
    end
end

--- @brief
function ow.Player:_get_can_jump()
    if self._walljump_allowed and (self._left_wall or self._right_wall) then
        return true
    else
        return not self:get_is_midair()
    end
end

--- @brief
function ow.Player:_connect_input()
    self._input:signal_connect("pressed", function(_, which)
        local is_jump_button = _JUMP_BUTTONS[which] == true
        local is_sprint_button = _SPRINT_BUTTON[which] == true

        if is_jump_button then
            if self:_get_can_jump() then
                self._jump_elapsed = 0
                self._is_midair_timer = math.huge -- prevent double jump during coyote time
            end
            self._jump_button_down = true
        elseif is_sprint_button then
            self._next_multiplier = rt.settings.overworld.player.sprint_multiplier
            self._next_multiplier_apply_when_grounded = true
        elseif which == rt.InputButton.LEFT then
            self._left_is_down = true
            if not self._right_is_down then
                self._digital_movement_timer = 0
            end
        elseif which == rt.InputButton.RIGHT then
            self._right_is_down = true
            if not self._left_is_down then
                self._digital_movement_timer = 0
            end
        elseif which == rt.InputButton.DOWN then
            self._down_button_down = true
        end
    end)

    self._input:signal_connect("released", function(_, which)
        local is_jump_button = _JUMP_BUTTONS[which] == true
        local is_sprint_button = _SPRINT_BUTTON[which] == true

        if is_jump_button then
            -- noop
        elseif is_sprint_button then
            self._next_multiplier = 1
            self._next_multiplier_apply_when_grounded = true
        end

        if which == rt.InputButton.LEFT then
            self._left_is_down = false
        elseif which == rt.InputButton.RIGHT then
            self._right_is_down = false
        elseif which == rt.InputButton.DOWN then
            self._down_button_down = false
        end
    end)

    self._input:signal_connect("left_joystick_moved", function(_, x, y)
        self._joystick_position = x
        self._down_button_down = math.abs(x) < 0.1 and y > 0.5
        self._right_is_down = math.abs(y) < 0.1 and x > 0.5
        self._left_is_down = math.abs(y) < 0.1 and x < -0.5
    end)

    self._input:signal_connect("right_joystick_moved", function(_, x, y)
        -- noop
    end)
end

--- @brief
function ow.Player:update(delta)
    local max_velocity = rt.settings.overworld.player.max_velocity_x
    local fraction = self._digital_movement_timer / rt.settings.overworld.player.digital_movement_acceleration_duration

    local _accel = function(x)
        if self:get_is_midair() then
            return 1 -- instant acceleration and not sprint for air horizontal movements
        else
            return math.min(x, 1)^2.5
        end
    end

    if self._left_is_down then
        self._velocity_sign = self._velocity_sign + -1
        self._velocity_magnitude = _accel(fraction)
    end

    if self._right_is_down then
        self._velocity_sign = self._velocity_sign + 1
        self._velocity_magnitude = _accel(fraction)
    end

    if self._velocity_sign < -1 then self._velocity_sign = -1 end
    if self._velocity_sign > 1 then self._velocity_sign = 1 end

    local midair_turn_active = false
    if self._is_midair and self._velocity_sign ~= self._last_known_grounded_sign and self._velocity_multiplier ~= 1 then
        -- if doing mid-air turnaround, reset sprint multiplier, but start sprinting again once grounded
        -- if sprint button is after this, it will be overriden
        local before = self._velocity_multiplier
        self._velocity_multiplier = 1
        self._next_multiplier = before
        self._next_multiplier_apply_when_grounded = true
        self._digital_movement_timer = 0
        midair_turn_active = true
    end

    if self._left_is_down or self._right_is_down then
        self._digital_movement_timer = self._digital_movement_timer + delta
    end

    local deceleration
    if self._is_midair then
        deceleration = rt.settings.overworld.player.air_deceleration_duration * self._velocity_multiplier
    else
        deceleration = rt.settings.overworld.player.ground_deceleration_duration * self._velocity_multiplier
    end

    if deceleration == 0 then
        self._velocity_magnitude = 0
    else
        self._velocity_magnitude = math.max(self._velocity_magnitude - (1 / deceleration) * delta, 0)
    end

    if self._joystick_position ~= 0 then
        -- overrides when using a analog controls
        self._velocity_sign = math.sign(self._joystick_position)
        self._velocity_magnitude = math.abs(self._joystick_position)
    end

    local velocity_x = self._velocity_sign * self._velocity_magnitude * self._velocity_multiplier * max_velocity

    if self._jump_button_down then
        self._jump_elapsed = self._jump_elapsed + delta
        local impulse = (rt.settings.overworld.player.jump_total_force * delta) / rt.settings.overworld.player.jump_duration
        self._body:apply_linear_impulse(0, -1 * impulse * (1 - math.min(self._jump_elapsed / rt.settings.overworld.player.jump_duration, 1)))
    end

    local vx, vy = self._body:get_velocity()

    local max_velocity_y = rt.settings.overworld.player.max_velocity_y
    self._body:set_velocity(
        velocity_x,
        math.clamp(vy, -1 * max_velocity_y, 3 * max_velocity_y) -- only limit upwards speed
    )

    local downwards_force = rt.settings.overworld.player.downwards_force
    if self._down_button_down and (self:get_is_midair() or self._velocity_magnitude < 10e-3) then
        self._body:apply_force(0, downwards_force)
    end

    if self._left_is_down and self._top_wall and not (self._is_midair) then
        self._body:apply_force(-1 * rt.settings.overworld.player.squeeze_force, 0)
    elseif self._right_is_down and self._top_wall and not (self._is_midair) then
        self._body:apply_force(rt.settings.overworld.player.squeeze_force, 0)
    end

    local x, y = self._body:get_position()
    local r = self._radius * rt.settings.overworld.player.grounded_ray_length_factor
    local mask = bit.bnot(b2.CollisionGroup.GROUP_15)
    local before = self._is_midair

    local span = rt.settings.overworld.player.ground_collision_ray_span
    local hit = false
    for angle = math.rad(90) - span, math.rad(90) + span, span do
        if self._world:query_ray_any(
            x,
            y,
            math.cos(angle) * r,
            math.sin(angle) * r,
        mask) ~= nil then
            hit = true
            break
        end
    end

    self._is_midair = not hit

    if self._is_midair == true then
        self._last_known_grounded_y = select(2, self._body:get_position())
        self._last_known_grounded_sign = self._velocity_sign
    end

    self._is_midair_timer = self._is_midair_timer + delta
    if before == false and self._is_midair == true then
        self._is_midair_timer = 0
    end

    local ray_length = self._radius - self._spring_body_radius

    local _, _, _, _, left_wall_body = self._world:query_ray_any(x, y, -ray_length, 0, mask)
    local _, _, _, _, right_wall_body = self._world:query_ray_any(x, y, ray_length, 0, mask)
    local _, _, _, _, top_wall_body = self._world:query_ray_any(x, y, 0, -ray_length, mask)
    self._left_wall = left_wall_body ~= nil
    self._right_wall = right_wall_body ~= nil
    self._top_wall = top_wall_body ~= nil

    if not self._is_midair and self._next_multiplier_apply_when_grounded then
        self._velocity_multiplier = self._next_multiplier
        self._next_multiplier_apply_when_grounded = false
    end

    -- slide down walls
    if (self._left_wall or self._right_wall) and not hit then
        local is_slippery = false
        if self._left_wall and left_wall_body:has_tag("slippery") then
            is_slippery = true
        end

        if self._right_wall and right_wall_body:has_tag("slippery") then
            is_slippery = true
        end

        if is_slippery then
            self._body:apply_force(0, downwards_force)
        end
    end

    -- safeguard against one of the springs catching
    for i, body in ipairs(self._spring_bodies) do
        local translation = self._spring_joints[i]:get_distance()
        body:set_is_sensor(translation > self._max_spring_length)
    end

    self._soft_body:update()
end

--- @brief
function ow.Player:move_to_stage(stage, x, y)
    meta.assert(stage, "Stage", x, "Number", y, "Number")

    local world = stage:get_physics_world()
    if world == self._world then return end

    self._world = world
    self._world:set_gravity(0, _gravity)

    -- create physics bodies
    self._body = b2.Body(
        self._world, b2.BodyType.DYNAMIC,
        x, y,
        b2.Circle(0, 0, 3.4) -- half of 8, plus polygon skin allowance
    )
    self._body:set_is_sensor(false) -- TODO
    self._body._native:setBullet(true)
    self._body:add_tag("player")
    self._body:set_is_rotation_fixed(true)
    self._body:set_collision_group(b2.CollisionGroup.GROUP_16)
    self._body:set_mass(1)

    local n_outer_bodies = rt.settings.overworld.player.n_outer_bodies
    local outer_radius = self._radius - self._spring_body_radius
    local outer_body_shape = b2.Circle(0, 0, self._spring_body_radius)
    local step = (2 * math.pi) / n_outer_bodies
    for angle = 0, 2 * math.pi - step, step do
        local cx = x + math.cos(angle) * outer_radius
        local cy = y + math.sin(angle) * outer_radius

        local body = b2.Body(self._world, b2.BodyType.DYNAMIC, cx, cy, outer_body_shape)
        body:set_mass(10e-4)
        body:set_collision_group(b2.CollisionGroup.GROUP_15)
        body:set_collides_with(bit.bnot(b2.CollisionGroup.GROUP_15))
        body._native:setBullet(true)

        local joint = b2.Spring(self._body, body, x, y, cx, cy)

        table.insert(self._spring_bodies, body)
        table.insert(self._spring_joints, joint)
        table.insert(self._spring_colors, rt.LCHA(0.8, 1, angle / (2 * math.pi), 1))
        table.insert(self._spring_is_sensor, false)
    end

    self._max_spring_length = outer_radius * rt.settings.overworld.player.max_spring_length_factor
    self._soft_body = ow.PlayerBody(self)
end

--- @brief
function ow.Player:draw()

    --self._body:draw()
    self._soft_body:draw()

    local x, y = self._body:get_position()
    local r = self._radius * rt.settings.overworld.player.grounded_ray_length_factor

    local mask = bit.bnot(b2.CollisionGroup.GROUP_15)
    local span = rt.settings.overworld.player.ground_collision_ray_span
    for angle = math.rad(90) - span, math.rad(90) + span, span do
        local dx, dy =  math.cos(angle) * r, math.sin(angle) * r
        local hit = self._world:query_ray_any(
            x,
            y,
            dx,
            dy,
            mask
        ) ~= nil

        if hit then rt.Palette.GREEN:bind() else rt.Palette.RED:bind() end
        love.graphics.line(x, y, x + dx, y + dy)
    end


    local r = self._radius - self._spring_body_radius
    love.graphics.line(x, y, x + 0, y + r)

    if self._left_wall then rt.Palette.GREEN:bind() else rt.Palette.RED:bind() end
    love.graphics.line(x, y, x - r / 2, y)

    if self._right_wall then rt.Palette.GREEN:bind() else rt.Palette.RED:bind() end
    love.graphics.line(x, y, x + r / 2, y)

    if self._top_wall then rt.Palette.GREEN:bind() else rt.Palette.RED:bind() end
    love.graphics.line(x, y, x, y - r)

    for i, spring in ipairs(self._spring_bodies) do
        self._spring_colors[i]:bind()
        spring:draw()
    end
end

--- @brief
function ow.Player:get_position()
    return self._body:get_position()
end

--- @brief
function ow.Player:teleport_to(x, y)
    if self._body ~= nil then
        self._body:set_position(x, y)

        for body in values(self._spring_bodies) do
            body:set_position(x, y)
        end
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

--- @brief
function ow.Player:set_walljump_allowed(b)
    self._walljump_allowed = b
end