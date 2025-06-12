require "common.sound_manager"
require "overworld.fireworks"

rt.settings.overworld.checkpoint = {
    celebration_particles_n = 500,

    explosion_duration = 1,
    explosion_radius_factor = 9, -- times playe radius

    ray_duration = 0.1,
    ray_width_radius_factor = 4,
    ray_fade_out_duration = 0.5,

    hue_speed = 2,
    segment_length = 7,
    gravity = 10000
}

--- @class ow.Checkpoint
ow.Checkpoint = meta.class("Checkpoint")

ow.CheckpointType = meta.enum("CheckpointTime", {
    PLAYER_SPAWN = 0,
    CHECKPOINT = 1,
    GOAL = 2
})

--- @class ow.PlayerSpawn
ow.PlayerSpawn = function(object, stage, scene) -- alias for first checkpoint
    return ow.Checkpoint(object, stage, scene, ow.CheckpointType.PLAYER_SPAWN)
end

--- @class ow.Goal
ow.Goal = function(object, stage, scene)
    return ow.Checkpoint(object, stage, scene, ow.CheckpointType.GOAL)
end

local _text_outline_shader, _text_shader
local _ray_shader, _explosion_shader

local _STATE_DEFAULT = "DEFAULT"
local _STATE_RAY = "RAY"
local _STATE_EXPLODING = "EXPLODING"
local _STATE_FIRST_ENTRY = "FIRST_ENTRY"

--- @brief
function ow.Checkpoint:instantiate(object, stage, scene, type)
    if type == nil then type = ow.CheckpointType.CHECKPOINT end

    if _text_outline_shader == nil then
        _text_outline_shader = love.graphics.newShader("overworld/objects/checkpoint_text.glsl", { defines = { MODE = 0 }})
        _text_outline_shader:send("outline_color", { rt.Palette.BLACK:unpack() })
    end

    if _text_shader == nil then
        _text_shader = love.graphics.newShader("overworld/objects/checkpoint_text.glsl", { defines = { MODE = 1 }})
    end

    if _ray_shader == nil then
        _ray_shader = rt.Shader("overworld/objects/checkpoint_ray.glsl")
    end

    if _explosion_shader == nil then
        _explosion_shader = love.graphics.newShader("overworld/objects/checkpoint_explosion.glsl")
    end

    assert(object:get_type() == ow.ObjectType.POINT, "In ow.Checkpoint: object is not a point")

    meta.install(self, {
        _scene = scene,
        _stage = stage,
        _world = stage:get_physics_world(),
        _type = type,
        _is_first_spawn = type == ow.CheckpointType.PLAYER_SPAWN,

        _state = _STATE_DEFAULT,
        _passed = false,

        _object = object,
        _x = object.x,
        _y = object.y,

        _top_x = math.huge,
        _top_y = math.huge,
        _bottom_x = math.huge,
        _bottom_y = math.huge,

        _current_player_spawn_x = object.x,
        _current_player_spawn_y = object.y,

        _color = { rt.Palette.CHECKPOINT:unpack() },
        _hue = rt.random.number(0, 1),

        _ray_fraction = math.huge,
        _ray_fade_out_fraction = math.huge,
        _ray_size = {0, 0},
        _ray_fade_out_elapsed = math.huge,

        _explosion_elapsed = math.huge,
        _explosion_fraction = math.huge,
        _explosion_player_position = { 0, 0 },
        _explosion_size = {0, 0},

        _elapsed = 0,
        _color = {0, 0, 0, 0},

        -- shader uniform
        _camera_offset = { 0, 0 },
        _camera_scale = 1,

        _segment_bodies = {},
        _segment_joints = {},
        _is_broken = false,
        _should_despawn = false,
    })

    stage:add_checkpoint(self, object.id, self._type)
    stage:signal_connect("initialized", function()
        -- cast ray up an down to get local bounds
        local inf = 10e9

        local bottom_x, bottom_y, _, _, _ = self._world:query_ray(self._x, self._y, 0, inf)
        if bottom_x == nil then
            bottom_x = self._x
            bottom_y = self._y
        end

        local top_x, top_y, _, _, _ = self._world:query_ray(self._x, self._y, 0, -inf)
        if top_x == nil then
            top_x = self._x
            top_y = self._y - inf
        end

        local player = self._scene:get_player()

        self._bottom_x, self._bottom_y = bottom_x, bottom_y
        self._top_x, self._top_y = top_x, top_y

        self._body = b2.Body(self._stage:get_physics_world(), b2.BodyType.STATIC,
            self._x, self._y,
            b2.Segment(
                top_x - self._x, top_y - self._y,
                bottom_x - self._x, bottom_y - self._y
            )
        )
        self._body:set_collides_with(bit.bor(
            rt.settings.player.player_collision_group,
            rt.settings.player.player_outer_body_collision_group
        ))

        self._body:set_collides_with(rt.settings.player.bounce_collision_group)
        self._body:set_collision_group(rt.settings.player.bounce_collision_group)

        self._body:set_use_continuous_collision(true)
        self._body:set_is_sensor(true)
        self._body:signal_connect("collision_start", function(_)
            if self._passed == false then
                self:pass()

                if self._type == ow.CheckpointType.CHECKPOINT then
                    self:_break()
                end
                --TODO return meta.DISCONNECT_SIGNAL
            end
        end)

        if self._type == ow.CheckpointType.CHECKPOINT then
            local height = self._bottom_y - self._top_y
            local n_segments = math.max(math.floor(height / rt.settings.overworld.checkpoint.segment_length), 2)
            local segment_length = height / (n_segments - 1)
            local radius = segment_length / 2

            self._n_segments = n_segments

            local collision_group = b2.CollisionGroup.GROUP_13

            local current_x, current_y = self._top_x, self._top_y
            for i = 1, n_segments do
                local body
                if i == 1 or i == n_segments then
                    local anchor_width = 10
                    body = b2.Body(self._world, b2.BodyType.STATIC, current_x, current_y, b2.Rectangle(-0.5 * anchor_width, -1 * radius, anchor_width, 2 * radius))
                    body:set_mass(1)
                else
                    body = b2.Body(self._world, b2.BodyType.DYNAMIC, current_x, current_y, b2.Circle(0, 0, radius))
                    body:set_mass(height / n_segments * 0.015)
                end

                body:set_collides_with(bit.bnot(rt.settings.player.exempt_collision_group))
                body:set_collision_group(rt.settings.player.exempt_collision_group)
                body:set_is_rotation_fixed(false)

                self._segment_bodies[i] = body
                current_y = current_y + segment_length
            end

            for i = 1, n_segments - 1 do
                local a, b = self._segment_bodies[i], self._segment_bodies[i+1]
                local a_x, a_y = a:get_position()
                local b_x, b_y = b:get_position()

                if i ~= 1 and i ~= n_segments then
                    a_y = a_y + radius
                    b_y = b_y - radius
                end

                local anchor_x, anchor_y = math.mix2(a_x, a_y, b_x, b_y, 0.5)
                local axis_x, axis_y = math.normalize(b_x - a_x, b_y - a_y)
                local joint = love.physics.newPrismaticJoint(
                    a:get_native(), b:get_native(),
                    anchor_x, anchor_y,
                    axis_x, axis_y,
                    false
                )
                joint:setLimitsEnabled(true)
                joint:setLimits(0, 0)

                self._segment_joints[i] = joint
            end

            self._fireworks = ow.Fireworks(self._scene)
        end

        return meta.DISCONNECT_SIGNAL
    end)

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "6" then
            _ray_shader:recompile()
            _explosion_shader = love.graphics.newShader("overworld/objects/checkpoint_explosion.glsl")
        end
    end)
end

--- @brief
function ow.Checkpoint:pass()
    self._passed = true
end

--- @brief
function ow.Checkpoint:spawn(also_kill)
    if also_kill == nil then also_kill = true end

    self._stage:signal_emit("respawn")
    self._world:set_time_dilation(1)
    local player = self._scene:get_player()
    player:set_velocity(0, 0)
    player:reset_flow()
    player:set_is_bubble(false)
    player:disable()

    if self._is_first_spawn then -- skip ray animation
        self:_set_state(_STATE_FIRST_ENTRY)
    elseif also_kill then
        self:_set_state(_STATE_EXPLODING)
    else
        self:_set_state(_STATE_RAY)
    end

    local camera = self._scene:get_camera()

    -- get highest possible point or just above off-screen
    local previous_x, previous_y = camera:get_position()
    camera:set_position(self._bottom_x, self._bottom_y) -- preview camera position for computation
    local _, screen_h = camera:world_xy_to_screen_xy(0, self._bottom_y)
    camera:set_position(previous_x, previous_y)

    if not self._is_first_spawn then
        local player_y = math.max(self._top_y + 2 * player:get_radius(), self._bottom_y - screen_h - 2 * player:get_radius())
        self._current_player_spawn_x, self._current_player_spawn_y = self._top_x, player_y
        player:teleport_to(self._current_player_spawn_x, self._current_player_spawn_y)
    end

    self._stage:set_active_checkpoint(self)
    self._passed = true
end

--- @brief
function ow.Checkpoint:_set_state(state)
    self._state = state
    local player = self._scene:get_player()
    if state == _STATE_EXPLODING then
        self._scene:set_camera_mode(ow.CameraMode.MANUAL)
        self._explosion_elapsed = 0
        self._explosion_fraction = 0

        player:disable()
        player:set_velocity(0, 0)
        player:set_gravity(0)
        player:set_opacity(0)

        self._explosion_player_position = { self._scene:get_player():get_position() }
        local player_radius = self._scene:get_player():get_radius()
        local factor = rt.settings.overworld.checkpoint.explosion_radius_factor
        self._explosion_size = { 2 * factor * player_radius, 2 * factor * player_radius }
        player:set_is_bubble(false) -- delay after radius query

    elseif state == _STATE_RAY then
        self._scene:set_camera_mode(ow.CameraMode.MANUAL)
        self._ray_fade_out_elapsed = 0
        self._ray_fraction = 0
        self._ray_fade_out_fraction = 0

        player:disable()
        player:set_hue(rt.random.number(0, 1))
        player:set_velocity(0, 1000)
        player:set_gravity(0)
        player:set_opacity(0)
        player:set_flow(0.5) -- purely for visuals
        player:set_flow_velocity(-1)
        player:set_trail_visible(false)

        local camera = self._scene:get_camera()
        camera:move_to(self._bottom_x, self._bottom_y)

        local factor = rt.settings.overworld.checkpoint.ray_width_radius_factor
        self._ray_size = { 2 * factor * player:get_radius(), self._bottom_y - self._top_y }

    elseif state == _STATE_DEFAULT then
        self._scene:set_camera_mode(ow.CameraMode.AUTO)

        player:set_gravity(1)
        player:set_opacity(1)
        player:set_is_bubble(false)
        player:set_trail_visible(true)
        player:enable()
    elseif state == _STATE_FIRST_ENTRY then
        self._scene:set_camera_mode(ow.CameraMode.MANUAL)

        -- skip ray animation
        player:disable()
        player:set_is_bubble(true)
        player:set_velocity(0, 0)
        player:set_gravity(0)
        player:set_opacity(0)
        player:set_flow(0)
        player:set_flow_velocity(0)
        player:set_trail_visible(false)
        player:teleport_to(self._bottom_x, self._bottom_y)

        local camera = self._scene:get_camera()
        camera:set_position(self._bottom_x, self._bottom_y)

        self:_set_state(_STATE_DEFAULT)
    end
end

--- @brief
function ow.Checkpoint:update(delta)
    if self._should_despawn then
        local seen = false
        for body in values(self._segment_bodies) do
            if self._scene:get_is_body_visible(body) then
                seen = true
                break
            end
        end

        if seen == false then
            self:_despawn()
        end
    end

    if self._is_broken then
        self._fireworks:update(delta)

        local gravity = rt.settings.overworld.checkpoint.gravity * delta
        for body in values(self._segment_bodies) do
            body:apply_force(0, gravity)
        end

        for joint in values(self._segment_joints) do
            if not joint:isDestroyed() and joint:getJointSpeed() > 1000 then
                self:_despawn()
                break
            end -- safeguard against solver freaking out
        end
    end

    if not self._is_broken then
        self._color = { rt.lcha_to_rgba(0.8, 1, self._scene:get_player():get_hue(), 1) }
    end

    if self._state == _STATE_EXPLODING then
        local duration = rt.settings.overworld.checkpoint.explosion_duration
        self._explosion_fraction = self._explosion_elapsed / duration
        self._explosion_elapsed = self._explosion_elapsed + delta

        if self._explosion_elapsed > duration then
            self:_set_state(_STATE_RAY)
        end
    elseif self._state == _STATE_RAY then
        local player = self._scene:get_player()
        local player_x, player_y = player:get_position()

        local camera = self._scene:get_camera()
        self._camera_offset = { camera:get_offset() }
        self._camera_scale = camera:get_scale()

        local threshold = self._bottom_y - player:get_radius() * 2
        if self._ray_fade_out_elapsed <= 0 and self._ray_fraction < 1 then
            self._ray_fraction = (player_y - self._top_y) / (threshold - self._top_y)
            player:set_opacity(self._ray_fraction)
        end

        local fade_out_duration = rt.settings.overworld.checkpoint.ray_fade_out_duration
        self._ray_fade_out_fraction = self._ray_fade_out_elapsed / fade_out_duration

        -- once player reaches ground
        if player_y >= threshold or player:get_state() ~= rt.PlayerState.DISABLED then
            if player:get_state() == rt.PlayerState.DISABLED then
                player:set_gravity(1)
                player:enable()
                player:bounce(0, -0.3)
            end
            self._scene:set_camera_mode(ow.CameraMode.AUTO)
            if self._ray_fade_out_elapsed > fade_out_duration then
                self:_set_state(_STATE_DEFAULT)
            end
            self._ray_fade_out_elapsed = self._ray_fade_out_elapsed + delta
        end
    elseif self._state == _STATE_DEFAULT and self._scene:get_is_body_visible(self._body) then
        if self._ray_fade_out_fraction > 1 then
            self._elapsed = self._elapsed + delta
        end
    elseif self._state == _STATE_FIRST_ENTRY then

    end

    if not self._is_broken then
        self._hue = math.fract(self._hue + delta / rt.settings.overworld.checkpoint.hue_speed)
        self._color = { rt.lcha_to_rgba(0.8, 1, self._hue, 1) }
    end
end

--- @brief
function ow.Checkpoint:_break()
    if self._is_broken then return end

    local player = self._scene:get_player()
    local player_x, player_y = player:get_position()
    local impulse = 0.05

    local joint_broken = false
    for i, joint in ipairs(self._segment_joints) do
        if i > self._n_segments - 1 then break end

        local a_x, a_y = self._segment_bodies[i]:get_position()
        local b_x, b_y = self._segment_bodies[i+1]:get_position()
        if player_y >= a_y and player_y <= b_y then
            joint_broken = true
            joint:destroy()

            self._hue = math.fract(self._hue + i / self._n_segments)
            local hue_offset = 0.2
            local hue_min, hue_max = self._hue - hue_offset, self._hue + hue_offset
            local n_particles = 200 --0.5 * rt.settings.overworld.checkpoint.celebration_particles_n-- * (1 + player:get_flow())
            local vx, vy = player:get_velocity()
            local velocity = 0.5 * player:get_radius()
            self._fireworks:spawn(n_particles, velocity, player_x, player_y + 2 * player:get_radius(), 0, -1.5, hue_min, hue_max) -- spew upwards
            break
        end
    end

    if joint_broken then
        self._stage:finish_stage(self._timestamp)
        self._segment_bodies[1]:set_type(b2.BodyType.DYNAMIC)
        self._segment_bodies[self._n_segments]:set_type(b2.BodyType.DYNAMIC)

        local offset = player:get_radius()
        local vx, vy = player:get_velocity()
        if vx > 0 then offset = -offset end
        impulse = impulse * math.magnitude(vx, vy)

        for body in values(self._segment_bodies) do
            body:set_collides_with(bit.bnot(bit.bor(
                rt.settings.player.player_collision_group,
                rt.settings.player.player_outer_body_collision_group
            )))

            local body_x, body_y = body:get_position()
            local dx, dy = math.normalize(body_x - (player_x + offset), body_y - player_y)
            body:apply_linear_impulse(dx * impulse, dy * impulse)
        end
        self._is_broken = true
        self._should_despawn = true

        self._scene:get_player():set_hue(self._hue)
    end
end

--- @brief
function ow.Checkpoint:_despawn()
    for joint in values(self._segment_joints) do
        if not joint:isDestroyed() then
            joint:destroy()
        end
    end

    for body in values(self._segment_bodies) do
        body:destroy()
    end

    self._segment_bodies = {}
    self._segment_joints = {}
    self._should_despawn = false
end

--- @brief
function ow.Checkpoint:draw()
    love.graphics.setColor(1, 1, 1, 1)
    --self._body:draw()
    --love.graphics.circle("fill", self._current_player_spawn_x, self._current_player_spawn_y, 5)

    local hue = self._scene:get_player():get_hue()
    if self._state == _STATE_EXPLODING then
        love.graphics.setShader(_explosion_shader)
        _explosion_shader:send("fraction", self._explosion_fraction)
        _explosion_shader:send("size", self._explosion_size)
        _explosion_shader:send("hue", hue)

        local x, y = table.unpack(self._explosion_player_position)
        local w, h = table.unpack(self._explosion_size)
        love.graphics.rectangle("fill", x - 0.5 * w, y - 0.5 * h, w, h)
        love.graphics.setShader(nil)
    elseif self._state == _STATE_RAY then
        love.graphics.setShader(_ray_shader:get_native())
        _ray_shader:send("fraction", self._ray_fraction)
        _ray_shader:send("fade_out_fraction", self._ray_fade_out_fraction)
        _ray_shader:send("size", self._ray_size)
        _ray_shader:send("elapsed", self._elapsed)
        _ray_shader:send("hue", hue)
        _ray_shader:send("camera_offset", self._camera_offset)
        _ray_shader:send("camera_scale", self._camera_scale)
        local w, h = table.unpack(self._ray_size)
        local x, y = self._top_x - 0.5 * w, self._top_y
        love.graphics.rectangle("fill", x, y, w, h)
        love.graphics.setShader()
    else
        if self._type == ow.CheckpointType.CHECKPOINT then

            local line_width = 6
            love.graphics.setLineWidth(line_width + 4)
            rt.Palette.BLACK:bind()
            for i, joint in ipairs(self._segment_joints) do
                if not joint:isDestroyed() then
                    local a_x, a_y = self._segment_bodies[i+0]:get_position()
                    local b_x, b_y = self._segment_bodies[i+1]:get_position()

                    love.graphics.line(a_x, a_y, b_x, b_y)

                    if i == 1 then
                        love.graphics.circle("fill", a_x, a_y, line_width / 2)
                    elseif i == self._n_segments then
                        love.graphics.circle("fill", b_x, b_y, line_width / 2)
                    end
                end
            end

            love.graphics.setLineWidth(6)

            if self._is_broken then
                love.graphics.setColor(rt.lcha_to_rgba(0.8, 1, self._scene:get_player():get_hue(), 1))

                for i, joint in ipairs(self._segment_joints) do
                    if not joint:isDestroyed() then
                        local a_x, a_y = self._segment_bodies[i+0]:get_position()
                        local b_x, b_y = self._segment_bodies[i+1]:get_position()
                        love.graphics.line(a_x, a_y, b_x, b_y)

                        if i == 1 then
                            love.graphics.circle("fill", a_x, a_y, line_width / 2)
                        elseif i == self._n_segments then
                            love.graphics.circle("fill", b_x, b_y, line_width / 2)
                        end
                    end
                end
            else
                for i, joint in ipairs(self._segment_joints) do
                    if not joint:isDestroyed() then
                        local a_x, a_y = self._segment_bodies[i+0]:get_position()
                        local b_x, b_y = self._segment_bodies[i+1]:get_position()
                        love.graphics.setColor(rt.lcha_to_rgba(0.8, 1, math.fract(self._hue + i / self._n_segments), 1))
                        love.graphics.line(a_x, a_y, b_x, b_y)

                        if i == 1 then
                            love.graphics.circle("fill", a_x, a_y, line_width / 2)
                        elseif i == self._n_segments then
                            love.graphics.circle("fill", b_x, b_y, line_width / 2)
                        end
                    end
                end
            end

            self._fireworks:draw()
        end
    end
end

--- @brief
function ow.Checkpoint:get_render_priority()
    return 0
end
