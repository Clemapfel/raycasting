require "common.sound_manager"
require "overworld.fireworks"

rt.settings.overworld.checkpoint = {
    explosion_duration = 1,
    explosion_radius_factor = 9, -- times player radius

    ray_duration = 0.1,
    ray_width_radius_factor = 4,
    ray_fade_out_duration = 0.5
}

--- @class ow.Checkpoint
ow.Checkpoint = meta.class("Checkpoint")

ow.CheckpointType = meta.enum("CheckpointType", {
    PLAYER_SPAWN = 0,
    CHECKPOINT = 1,
    PLAYER_GOAL = 2
})

--- @class ow.PlayerSpawn
ow.PlayerSpawn = function(object, stage, scene) -- alias for first checkpoint
    return ow.Checkpoint(object, stage, scene, ow.CheckpointType.PLAYER_SPAWN)
end

--- @class ow.PlayerGoal
ow.PlayerGoal = function(object, stage, scene) -- alias for end of stage
    return ow.Checkpoint(object, stage, scene, ow.CheckpointType.PLAYER_GOAL)
end

local _ray_shader, _explosion_shader

local _STATE_DEFAULT = "DEFAULT"
local _STATE_RAY = "RAY"
local _STATE_EXPLODING = "EXPLODING"
local _STATE_STAGE_ENTRY = "STAGE_ENTRY"
local _STATE_STAGE_EXIT = "STAGE_EXIT"

--- @brief
function ow.Checkpoint:instantiate(object, stage, scene, type)
    if _ray_shader == nil then
        _ray_shader = rt.Shader("overworld/objects/checkpoint_ray.glsl")
    end

    if _explosion_shader == nil then
        _explosion_shader = rt.Shader("overworld/objects/checkpoint_explosion.glsl")
    end

    if type == nil then type = ow.CheckpointType.CHECKPOINT end
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.Checkpoint: object is not a point")

    meta.install(self, {
        _scene = scene,
        _stage = stage,
        _world = stage:get_physics_world(),
        _type = type,

        _state = _STATE_DEFAULT,
        _passed = false,

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

        -- shader uniform
        _camera_offset = { 0, 0 },
        _camera_scale = 1,

        _is_broken = false,
        _should_despawn = false,
    })

    stage:add_checkpoint(self, object.id, self._type)
    stage:signal_connect("initialized", function()
        -- cast ray up an down to get local bounds
        local inf = love.graphics.getHeight() * 2

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
                self._passed = true
                return meta.DISCONNECT_SIGNAL
            end
        end)

        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function ow.Checkpoint:spawn(also_kill)
    if also_kill == nil then also_kill = true end

    local is_first_spawn = self._stage:get_is_first_spawn()

    self._stage:signal_emit("respawn")

    local player = self._scene:get_player()
    player:reset()
    player:disable()

    local camera = self._scene:get_camera()
    local spawn_x, spawn_y

    local type = self._type
    if is_first_spawn then
        -- if first spawn, skip ray animation, spawn at position
        self:_set_state(_STATE_STAGE_ENTRY)
    else
        if also_kill then
            self:_set_state(_STATE_EXPLODING)
        else
            self:_set_state(_STATE_RAY)
        end
    end

    self._stage:set_active_checkpoint(self)
    self._passed = true
end

--- @brief
function ow.Checkpoint:_set_state(state)
    self._state = state
    local player = self._scene:get_player()
    local camera = self._scene:get_camera()

    if self._state == _STATE_STAGE_ENTRY then
        -- on entry, instantly spawn player in position

        local spawn_y = self._bottom_y - 4 * player:get_radius()

        self._scene:set_camera_mode(ow.CameraMode.MANUAL)
        camera:set_position(self._bottom_x, self._bottom_y)

        player:reset()
        player:teleport_to(self._top_x, spawn_y)
        player:disable()

    elseif self._state == _STATE_STAGE_EXIT then


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
        player:set_velocity(0, 1000)
        player:disable()

    elseif self._state == _STATE_DEFAULT then
        self._scene:set_camera_mode(ow.CameraMode.AUTO)

        -- no reset
        player:enable()
    end
end

--- @brief
function ow.Checkpoint:update(delta)
    if not self._scene:get_is_body_visible(self._body) then return end
    local camera = self._scene:get_camera()
    local player = self._scene:get_player()

    self._color = { rt.lcha_to_rgba(0.8, 1, player:get_hue(), 1) }
    self._camera_offset = { camera:get_offset() }
    self._camera_scale = camera:get_scale()

    if self._state == _STATE_STAGE_ENTRY then
        self:_set_state(_STATE_DEFAULT)
        player:clear_forces()
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
    if self._state == _STATE_DEFAULT and not self._scene:get_is_body_visible(self._body) then return end
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
function ow.Checkpoint:get_render_priority()
    return _base_priority, _effect_priority
end