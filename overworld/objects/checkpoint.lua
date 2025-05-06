require "common.sound_manager"

rt.settings.overworld.checkpoint = {
    celebration_particles_n = 500,

    explosion_duration = 1.5,
    explosion_radius_factor = 15, -- times playe radius
}

--- @class ow.Checkpoint
ow.Checkpoint = meta.class("Checkpoint")

--- @class ow.PlayerSpawn
ow.PlayerSpawn = function(object, stage, scene) -- alias for first checkpoint
    return ow.Checkpoint(object, stage, scene, true)
end

local _text_outline_shader, _text_shader
local _ray_shader, _explosion_shader

local _STATE_DEFAULT = "DEFAULT"
local _STATE_RAY = "RAY"
local _STATE_EXPLODING = "EXPLODING"

--- @brief
function ow.Checkpoint:instantiate(object, stage, scene, is_player_spawn)
    if _text_outline_shader == nil then
        _text_outline_shader = love.graphics.newShader("overworld/objects/checkpoint_text.glsl", { defines = { MODE = 0 }})
        _text_outline_shader:send("outline_color", { rt.Palette.BLACK:unpack() })
    end

    if _text_shader == nil then
        _text_shader = love.graphics.newShader("overworld/objects/checkpoint_text.glsl", { defines = { MODE = 1 }})
    end

    if _ray_shader == nil then
        _ray_shader = love.graphics.newShader("overworld/objects/checkpoint_ray.glsl")
    end

    if _explosion_shader == nil then
        _explosion_shader = love.graphics.newShader("overworld/objects/checkpoint_explosion.glsl")
    end

    assert(object:get_type() == ow.ObjectType.POINT, "In ow.Checkpoint: object is not a point")

    if is_player_spawn == nil then is_player_spawn = false end
    meta.install(self, {
        _scene = scene,
        _stage = stage,
        _world = stage:get_physics_world(),
        _is_player_spawn = is_player_spawn,
        _is_first_spawn = is_player_spawn,

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

        _ray_fraction = math.huge,

        _explosion_elapsed = math.huge,
        _explosion_fraction = math.huge,
        _explosion_player_position = { 0, 0 },
        _explosion_player_radius = 0,
        _explosion_size = {0, 0},

        -- uniform
        _camera_offset = { 0, 0 },
        _camera_scale = 1,
    })

    stage:add_checkpoint(self, object.id, is_player_spawn)
    stage:signal_connect("initialized", function()
        -- cast ray up an down to get local bounds
        local inf = 10e9

        local bottom_x, bottom_y, _, _, _ = self._world:query_ray(self._x, self._y, 0, inf)
        if bottom_x == nil then
            bottom_x = self._x
            bottom_y = self._y
            rt.error("In ow.Checkpoint.initialize: checkpoint `" .. self._object.id .. "` is not above solid ground")
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
        self._body:set_collides_with(rt.settings.overworld.player.player_collision_group)
        self._body:set_use_continuous_collision(true)
        self._body:set_is_sensor(true)
        self._body:signal_connect("collision_start", function(_)
            if self._passed == false then
                self:pass()
                --TODO return meta.DISCONNECT_SIGNAL
            end
        end)

        return meta.DISCONNECT_SIGNAL
    end)

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "6" then
            local before = love.timer.getTime()
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

    local player = self._scene:get_player()
    player:reset_flow()

    if also_kill then
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

    local player_y = math.max(self._top_y + 2 * player:get_radius(), self._bottom_y - screen_h - 2 * player:get_radius())
    self._current_player_spawn_x, self._current_player_spawn_y = self._top_x, player_y
    player:teleport_to(self._current_player_spawn_x, self._current_player_spawn_y)

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

        self._explosion_player_position = { self._scene:get_player():get_position()ref }
        local player_radius = player:get_radius()
        self._explosion_player_radius = player_radius
        local factor = rt.settings.overworld.checkpoint.explosion_radius_factor
        self._explosion_size = { 2 * factor * player_radius, 2 * factor * player_radius }

    elseif state == _STATE_RAY then
        self._scene:set_camera_mode(ow.CameraMode.MANUAL)
        self._ray_elapsed = 0
        self._ray_fraction = 0

        player:disable()
        player:set_velocity(0, 0)
        player:set_gravity(1)
        player:set_opacity(0)

        local camera = self._scene:get_camera()
        if self._is_first_spawn then -- smash cut at start of level
            camera:set_position(self._bottom_x, self._bottom_y)
            self._is_first_spawn = false
        else
            camera:move_to(self._bottom_x, self._bottom_y)
        end

    elseif state == _STATE_DEFAULT then
        self._scene:set_camera_mode(ow.CameraMode.AUTO)

        player:enable()
        player:set_gravity(1)
        player:set_opacity(1)
    end
end

--- @brief
function ow.Checkpoint:update(delta)
    if self._state == _STATE_EXPLODING then
        local duration = rt.settings.overworld.checkpoint.explosion_duration
        self._explosion_fraction = self._explosion_elapsed / duration
        self._explosion_elapsed = self._explosion_elapsed + delta

        local camera = self._scene:get_camera()
        self._camera_offset = { camera:get_offset() }
        self._camera_scale = camera:get_scale()

        if self._explosion_elapsed > duration then
            self:_set_state(_STATE_RAY)
        end
    elseif self._state == _STATE_RAY then
        local player = self._scene:get_player()
        local player_x, player_y = player:get_position()

        local camera = self._scene:get_camera()
        self._camera_offset = { camera:get_offset() }
        self._camera_scale = camera:get_scale()

        local threshold = self._bottom_y - player:get_radius() * 2 * 2
        self._ray_fraction = (player_y - self._current_player_spawn_y) / (threshold - self._current_player_spawn_y)
        player:set_opacity(self._ray_fraction)

        -- once player reaches ground
        if player_y >= threshold then
            self:_set_state(_STATE_DEFAULT)
        end
    elseif self._state == _STATE_DEFAULT and self._scene:get_is_body_visible(self._body) then

    end

    self._color = { rt.lcha_to_rgba(0.8, 1, self._scene:get_player():get_hue(), 1) }
end

--- @brief
function ow.Checkpoint:draw()
    love.graphics.setColor(1, 1, 1, 1)
    self._body:draw()
    love.graphics.circle("fill", self._current_player_spawn_x, self._current_player_spawn_y, 5)

    if self._state == _STATE_EXPLODING then
        love.graphics.setShader(_explosion_shader)
        _explosion_shader:send("fraction", self._explosion_fraction)
        _explosion_shader:send("size", self._explosion_size)

        local x, y = table.unpack(self._explosion_player_position)
        local w, h = table.unpack(self._explosion_size)
        love.graphics.rectangle("fill", x - 0.5 * w, y - 0.5 * h, w, h)
        love.graphics.setShader(nil)
    elseif self._state == _STATE_RAY then

    end
end

--- @brief
function ow.Checkpoint:get_render_priority()
    return 0
end
