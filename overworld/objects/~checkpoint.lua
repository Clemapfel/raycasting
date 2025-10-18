require "common.sound_manager"
require "overworld.fireworks"
require "overworld.shatter_surface"
require "overworld.objects.checkpoint_rope"
require "overworld.objects.checkpoint_platform"
require "common.label"

rt.settings.overworld.checkpoint = {
    explosion_duration = 1,
    explosion_radius_factor = 9, -- times player radius

    ray_duration = 0.1,
    ray_width_radius_factor = 4,
    ray_fade_out_duration = 0.5,
}

--- @class ow.Checkpoint
--- @types Point
ow.Checkpoint = meta.class("Checkpoint")

--- @class ow.CheckpointTye
ow.CheckpointType = meta.enum("CheckpointType", {
    PLAYER_SPAWN = 0,
    MIDWAY = 1
})

--- @class ow.PlayerSpawn
--- @types Point
ow.PlayerSpawn = function(object, stage, scene) -- alias for first checkpoint
    return ow.Checkpoint(object, stage, scene, ow.CheckpointType.PLAYER_SPAWN)
end

local _ray_shader = rt.Shader("overworld/objects/checkpoint_ray.glsl")
local _explosion_shader = rt.Shader("overworld/objects/checkpoint_explosion.glsl")

local _STATE_DEFAULT = "DEFAULT"
local _STATE_RAY = "RAY"
local _STATE_EXPLODING = "EXPLODING"
local _STATE_STAGE_ENTRY = "STAGE_ENTRY"

--- @brief
function ow.Checkpoint:instantiate(object, stage, scene, type)
    if type == nil then type = ow.CheckpointType.MIDWAY end
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.Checkpoint: object is not a point")

    meta.install(self, {
        _scene = scene,
        _stage = stage,
        _world = stage:get_physics_world(),
        _type = type,

        _state = _STATE_DEFAULT,
        _passed = false,
        _coin_savestate = {}, -- Set<Integer>

        _object = object,
        _x = object.x,
        _y = object.y,

        _top_x = math.huge,
        _top_y = math.huge,
        _bottom_x = math.huge,
        _bottom_y = math.huge,

        _color = { 1, 1, 1, 1 },

        _ray_fraction = math.huge,
        _ray_fade_out_fraction = math.huge,
        _ray_size = { 0, 0 },
        _ray_fade_out_elapsed = math.huge,

        _explosion_elapsed = math.huge,
        _explosion_fraction = math.huge,
        _explosion_player_position = { 0, 0 },
        _explosion_size = { 0, 0 },

        _elapsed = 0,
        _split_send = false,

        -- shader uniform
        _camera_offset = { 0, 0 },
        _camera_scale = 1,

        -- start checkpoint: player spawn
        _spawn_barrier = nil, -- b2.Body

        -- midway checkpoint:
        _fireworks = nil, -- ow.Fireworks
        _fireworks_visible = false,

        _rope = nil -- ow.CheckpointRope, only if midpoint
    })

    stage:signal_connect("initialized", function()
        -- cast ray up an down to get local bounds
        local inf = love.graphics.getHeight() * 2

        local bottom_x, bottom_y = self._x, self._y

        local top_x, top_y, _, _, _ = self._world:query_ray(self._x, self._y, 0, -inf)
        if top_x == nil then
            top_x = self._x
            top_y = self._y - inf
        end

        local player = self._scene:get_player()

        self._bottom_x, self._bottom_y = bottom_x, bottom_y
        self._top_x, self._top_y = top_x, top_y + 2 * player:get_radius()

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

        local collision_mask, collision_group = rt.settings.player.bounce_collision_group, rt.settings.player.bounce_collision_group
        self._body:set_collides_with(collision_mask)
        self._body:set_collision_group(collision_group)

        self._body:set_use_continuous_collision(true)
        self._body:set_is_sensor(true)

        if self._type == ow.CheckpointType.PLAYER_SPAWN then
            self._fireworks = ow.Fireworks(self._scene:get_player())

            self._body:signal_connect("collision_start", function(_, other)
                if self._passed == false then
                    -- spawn does not split
                    self._passed = true
                    self._coin_savestate = {} -- no coins
                    self._stage:set_active_checkpoint(self)
                end
            end)

            -- add ghost-safe collision
            local r = rt.settings.overworld.checkpoint_rope.radius

            -- match slope of ground
            local width = rt.settings.player.radius * 4
            local left_x, left_y, _, _, _ = self._world:query_ray(self._x - width, self._y, 0, inf)
            local right_x, right_y, _, _, _ = self._world:query_ray(self._x + width, self._y, 0, inf)

            left_x = left_x or bottom_x
            left_y = left_y or bottom_y
            right_x = right_x or bottom_x
            right_y = right_y or bottom_y

            -- match shape at spawn, could be convex
            self._platform = ow.CheckpointPlatform(
                left_x, left_y,
                right_x, right_y,
                r
            )

            self._spawn_barrier = b2.Body(self._stage:get_physics_world(), b2.BodyType.STATIC, 0, 0,
                b2.Polygon(
                    left_x, math.min(left_y, self._y),
                    right_x, math.min(right_y, self._y,
                        right_x, math.min(right_y + r, self._y),
                        left_x, math.min(left_y + r, self._y)
                    )
                ))

            self._spawn_barrier:set_collision_group(
                rt.settings.player.ghost_collision_group
            )
            self._spawn_barrier:add_tag("stencil", "hitbox")

        elseif self._type == ow.CheckpointType.MIDWAY then
            self._fireworks = ow.Fireworks(self._scene:get_player())
            self._rope = ow.CheckpointRope(self._scene, self._stage, self._world, self._top_x, self._top_y, self._bottom_x, self._bottom_y)

            self._body:signal_connect("collision_start", function(_, other)
                if self._rope:get_is_cut() == false then
                    self._rope:cut() -- checks player position automatically

                    -- fireworks
                    local player = self._scene:get_player()
                    local n_particles = 300
                    local start_x, start_y = self._bottom_x, self._bottom_y
                    local max_distance = math.distance(self._bottom_x, self._bottom_y, self._top_x, self._top_y)

                    for i = 1, 6 do
                        local distance = rt.random.number(0, max_distance)
                        local vy = -1 -- always upwards
                        local vx = rt.random.number(-0.5, 0.5)
                        local hue = rt.random.number(0, 1)
                        local end_x, end_y = start_x + vx * distance, start_y + vy * distance
                        self._fireworks:spawn(
                            n_particles,
                            start_x, start_y, -- start pos
                            end_x, end_y, -- end
                            hue - 0.2, hue + 0.2
                        )
                    end
                    self._fireworks_visible = true
                end

                if self._passed == false then
                    self:_send_split()
                    self._stage:set_active_checkpoint(self)
                    self._coin_savestate = {}
                    for coin_i = 1, self._stage:get_n_coins() do
                        if self._stage:get_coin_is_collected(coin_i) then
                            self._coin_savestate[coin_i] = true
                        end
                    end
                    self._passed = true
                end
            end)
        end

        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function ow.Checkpoint:spawn(also_kill)
    if also_kill == nil then also_kill = true end

    local is_first_spawn = self._stage:get_is_first_spawn()

    -- restore coins
    for coin_i = 1, self._stage:get_n_coins() do
        self._stage:set_coin_is_collected(coin_i, self._coin_savestate[coin_i] == true)
    end

    local player = self._scene:get_player()
    player:reset()
    player:disable()

    local camera = self._scene:get_camera()
    local spawn_x, spawn_y

    local type = self._type
    if is_first_spawn then
        -- if first spawn, skip ray animation, spawn at position, spawn fireworks
        self:_set_state(_STATE_STAGE_ENTRY)
    else
        if also_kill then
            self:_set_state(_STATE_EXPLODING)
        else
            self:_set_state(_STATE_RAY)
        end
    end

    self._stage:set_active_checkpoint(self)
    self._stage:signal_emit("respawn")
    self._passed = true
end

--- @brief
function ow.Checkpoint:_set_state(state)
    self._state = state
    local player = self._scene:get_player()
    local camera = self._scene:get_camera()

    if self._state == _STATE_STAGE_ENTRY then
        -- on entry, instantly spawn player in position

        local before = camera:get_apply_bounds()
        camera:set_apply_bounds(false)
        local screen_h = camera:get_world_bounds().height
        local spawn_y = math.max(self._bottom_y - screen_h - 4 * player:get_radius(), self._top_y) -- always out of bounds, safe because ghost
        camera:get_apply_bounds()

        self._scene:set_camera_mode(ow.CameraMode.MANUAL)
        camera:set_position(self._bottom_x, self._bottom_y)

        player:reset()
        player:teleport_to(self._top_x, spawn_y)
        player:set_is_ghost(true)
        player:disable()

    elseif self._state == _STATE_EXPLODING then
        local explosion_x, explosion_y = player:get_position()
        self._explosion_player_position = { explosion_x, explosion_y }

        local player_radius = player:get_radius()
        local factor = rt.settings.overworld.checkpoint.explosion_radius_factor
        self._explosion_size = { 2 * factor * player_radius, 2 * factor * player_radius }

        self._scene:set_camera_mode(ow.CameraMode.MANUAL)
        camera:move_to(explosion_x, explosion_y)

        self._explosion_elapsed = 0
        self._explosion_fraction = 0

        player:reset()
        player:set_is_frozen(true)
        player:set_is_visible(false)
        player:disable()

    elseif self._state == _STATE_RAY then
        self._scene:set_camera_mode(ow.CameraMode.MANUAL)
        camera:set_position(self._bottom_x, self._bottom_y)

        self._ray_fraction = 0
        self._ray_fade_out_elapsed = 0
        self._ray_fade_out_fraction = 0
        local factor = rt.settings.overworld.checkpoint.ray_width_radius_factor
        self._ray_size = { 2 * factor * player:get_radius(), self._bottom_y - self._top_y }

        local _, screen_h = camera:world_xy_to_screen_xy(0, self._bottom_y)
        local spawn_y = math.max(self._top_y + 2 * player:get_radius(), self._bottom_y - screen_h - 2 * player:get_radius())
        player:teleport_to(self._top_x, spawn_y)

        player:reset()
        player:set_is_visible(true)
        player:disable()

    elseif self._state == _STATE_DEFAULT then
        self._scene:set_camera_mode(ow.CameraMode.AUTO)

        player:reset()
        player:enable()
    end
end

--- @brief
function ow.Checkpoint:update(delta)
    -- update fireworks indepedent from body location
    if self._fireworks_visible then
        self._fireworks:update(delta)
        self._fireworks_visible = not self._fireworks:get_is_done()
    end

    if self._state == _STATE_DEFAULT and not self._stage:get_is_body_visible(self._body) then return end
    local camera = self._scene:get_camera()
    local player = self._scene:get_player()

    self._color = { rt.lcha_to_rgba(0.8, 1, player:get_hue(), 1) }
    self._camera_offset = { camera:get_offset() }
    self._camera_scale = camera:get_scale()

    if self._type == ow.CheckpointType.PLAYER_SPAWN then
        self._platform:set_hue(self._scene:get_player():get_hue())
    elseif self._type == ow.CheckpointType.MIDWAY then
        self._rope:update(delta)
    end

    if self._state == _STATE_STAGE_ENTRY then
        -- wait for player to reach ghost spawn
        local player_x, player_y = player:get_position()
        if player_y >= self._bottom_y - 2 * player:get_radius() then
            self:_set_state(_STATE_DEFAULT)
            player:clear_forces()
        end
    elseif self._state == _STATE_EXPLODING then
        local duration = rt.settings.overworld.checkpoint.explosion_duration
        self._explosion_fraction = self._explosion_elapsed / duration
        self._explosion_elapsed = self._explosion_elapsed + delta

        if self._explosion_elapsed > duration then
            self:_set_state(_STATE_RAY)
        end
    elseif self._state == _STATE_RAY then
        local threshold = self._bottom_y - 2 * player:get_radius()
        local player_x, player_y = player:get_position()
        if self._ray_fade_out_elapsed <= 0 and self._ray_fraction < 1 then
            self._ray_fraction = (player_y - self._top_y) / (threshold - self._top_y)
        end

        if player_y >= threshold then
            self._ray_fade_out_elapsed = 0
            player:bounce(0, -0.25)
            self:_set_state(_STATE_DEFAULT)
        end
    elseif self._state == _STATE_DEFAULT then
        -- ray fades out after player has spawned
        local fade_out_duration = rt.settings.overworld.checkpoint.ray_fade_out_duration
        self._ray_fade_out_fraction = self._ray_fade_out_elapsed / fade_out_duration
        self._ray_fade_out_elapsed = self._ray_fade_out_elapsed + delta
    end
end

local _base_priority = 0
local _effect_priority = math.huge

--- @brief
function ow.Checkpoint:draw(priority)
    if priority == _base_priority then
        if self._type == ow.CheckpointType.MIDWAY then
            if self._fireworks_visible then self._fireworks:draw() end
        elseif self._type == ow.CheckpointType.PLAYER_SPAWN then
            self._platform:draw()
        end
    end

    if self._state == _STATE_DEFAULT and not self._stage:get_is_body_visible(self._body) then return end
    local hue = self._scene:get_player():get_hue()

    if priority == _base_priority then
        love.graphics.setColor(self._color)
        self._body:draw()

        -- ray drawn behind player
        if self._state == _STATE_RAY or self._state == _STATE_DEFAULT then
            _ray_shader:bind()
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
            _ray_shader:unbind()
        end

        if self._type == ow.CheckpointType.MIDWAY then
            self._rope:draw()
        end
    elseif priority == _effect_priority then
        -- explosion draw above everything
        if self._state == _STATE_EXPLODING then
            _explosion_shader:bind()
            _explosion_shader:send("fraction", self._explosion_fraction)
            _explosion_shader:send("size", self._explosion_size)
            _explosion_shader:send("hue", hue)

            local x, y = table.unpack(self._explosion_player_position)
            local w, h = table.unpack(self._explosion_size)
            love.graphics.rectangle("fill", x - 0.5 * w, y - 0.5 * h, w, h)
            _explosion_shader:unbind()
        end
    end
end

--- @brief
function ow.Checkpoint:draw_bloom()
    if not self._stage:get_is_body_visible(self._body) then return end
    if self._type == ow.CheckpointType.MIDWAY then
        self._rope:draw_bloom()
    elseif self._type == ow.CheckpointType.PLAYER_SPAWN then
        self._platform:draw_bloom()
    end
end

--- @brief
function ow.Checkpoint:get_render_priority()
    return _base_priority, _effect_priority
end

--- @brief
function ow.Checkpoint:_send_split()
    if self._split_send == true then return end
    self._stage:set_checkpoint_split(self)
    self._split_send = true
end

--- @brief
function ow.Checkpoint:get_type()
    return self._type
end

--- @brief
function ow.Checkpoint:reset()
    for to_reset in range( -- automatically skips nils
        self._shatter_surface,
        self._rope
    ) do
        to_reset:reset()
    end
end