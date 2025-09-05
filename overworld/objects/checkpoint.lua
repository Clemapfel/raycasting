require "common.sound_manager"
require "overworld.fireworks"
require "overworld.shatter_surface"
require "overworld.objects.checkpoint_rope"
require "common.label"

rt.settings.overworld.checkpoint = {
    explosion_duration = 1,
    explosion_radius_factor = 9, -- times player radius

    ray_duration = 0.1,
    ray_width_radius_factor = 4,
    ray_fade_out_duration = 0.5,

    goal_time_dilation = 0,
    goal_time_dilation_duration = 1,
    goal_line_width = 50, -- px
    result_screen_delay = 0.0,
}

--- @class ow.Checkpoint
ow.Checkpoint = meta.class("Checkpoint")

ow.CheckpointType = meta.enum("CheckpointType", {
    PLAYER_SPAWN = 0,
    MIDWAY = 1,
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

local _ray_shader = rt.Shader("overworld/objects/checkpoint_ray.glsl")
local _explosion_shader = rt.Shader("overworld/objects/checkpoint_explosion.glsl")
local _indicator_shader = rt.Shader("overworld/objects/checkpoint_indicator.glsl")

local _STATE_DEFAULT = "DEFAULT"
local _STATE_RAY = "RAY"
local _STATE_EXPLODING = "EXPLODING"
local _STATE_STAGE_ENTRY = "STAGE_ENTRY"
local _STATE_STAGE_EXIT = "STAGE_EXIT"

local _format_time = function(time)
    return string.format_time(time), {
        style = rt.FontStyle.BOLD,
        is_outlined = true,
        font_size = rt.FontSize.REGULAR,
        color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, rt.GameState:get_player():get_hue(), 1))
    }
end

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

        -- shader uniform
        _camera_offset = { 0, 0 },
        _camera_scale = 1,

        -- start checkpoint: player spawn
        _spawn_barrier = nil, -- b2.Body

        -- midway checkpoint:
        _fireworks = nil, -- ow.Fireworks
        _fireworks_locations = {},
        _fireworks_visible = false,

        _rope = nil, -- ow.CheckpointRope

        -- last checkpoint: player goal
        _is_shattered = false,
        _shatter_body = nil,    -- b2.Body
        _shatter_surface = nil, -- ow.ShatterSurface
        _time_dilation_elapsed = 0,
        _time_dilation_active = false,
        _shatter_velocity_x = 0,
        _shatter_velocity_y = 0,

        _goal_indicator_outline = { 0, 0, 1, 1 }, -- love.Line
        _goal_indicator_line = { 0, 0, 1, 1 }, -- love.Line
        _goal_indicator = nil, -- rt.Mesh
        _goal_indicator_motion = rt.SmoothedMotion2D(),

        _goal_player_position_x = 0,
        _goal_player_position_y = 0,

        _result_screen_revealed = false,
        _split_send = false
    })

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

        local collision_mask, collision_group = rt.settings.player.bounce_collision_group, rt.settings.player.bounce_collision_group
        self._body:set_collides_with(collision_mask)
        self._body:set_collision_group(collision_group)

        self._body:set_use_continuous_collision(true)
        self._body:set_is_sensor(true)

        if self._type == ow.CheckpointType.PLAYER_SPAWN then
            self._body:signal_connect("collision_start", function(_, other)
                if self._passed == false then
                    -- spawn does not split
                    self._passed = true
                    self._coin_savestate = {} -- no coins
                    self._stage:set_active_checkpoint(self)
                end
            end)

            local r = rt.settings.player.radius
            self._spawn_barrier = b2.Body(self._stage:get_physics_world(), b2.BodyType.STATIC,
                bottom_x, bottom_y,
                b2.Polygon(
                    0 - 4 * r, 0,
                    0 + 4 * r, 0,
                    0 + 4 * r, r,
                    0 - 4 * r, r
                )
            )

            self._spawn_barrier:set_collision_group(
                rt.settings.player.ghost_collision_group
            )
        elseif self._type == ow.CheckpointType.MIDWAY then
            self._fireworks = ow.Fireworks(self._scene:get_player())
            self._rope = ow.CheckpointRope(self._scene, self._world, self._top_x, self._top_y, self._bottom_x, self._bottom_y)

            self._body:signal_connect("collision_start", function(_, other)
                if self._rope:get_is_cut() == false then
                    self._rope:cut() -- checks player position automatically

                    -- fireworks
                    local player = self._scene:get_player()
                    local n_particles = 300
                    local start_x, start_y = self._bottom_x, self._bottom_y
                    local max_distance = math.distance(self._bottom_x, self._bottom_y, self._top_x, self._top_y)

                    self._fireworks_locations = {}
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

                        table.insert(self._fireworks_locations, start_x)
                        table.insert(self._fireworks_locations, start_y)
                        table.insert(self._fireworks_locations, end_x)
                        table.insert(self._fireworks_locations, end_y)
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

        elseif self._type == ow.CheckpointType.PLAYER_GOAL then
            local surface_w = 100
            local surface_h = self._bottom_y - self._top_y

            local body_x, body_y = self._top_x, self._top_y
            self._shatter_bounds = rt.AABB(body_x, body_y, surface_w, surface_h)
            self._shatter_body = b2.Body(self._world, b2.BodyType.STATIC,
                0, 0,
                b2.Rectangle(self._shatter_bounds:unpack())
            )

            self._shatter_surface = ow.ShatterSurface(self._world, self._shatter_bounds:unpack())

            self._shatter_body:set_collides_with(collision_mask)
            self._shatter_body:set_collision_group(collision_group)
            self._shatter_body:set_is_sensor(true)
            self._shatter_body:signal_connect("collision_start", function(_, other, nx, ny, x, y, x2, y2)
                if self._is_shattered == false then
                    self._is_shattered = true
                    self._scene:stop_timer()
                    self._shatter_velocity_x, self._shatter_velocity_y = self._scene:get_player():get_velocity()
                    local min_x, max_x = self._shatter_bounds.x, self._shatter_bounds.x + self._shatter_bounds.width
                    local min_y, max_y = self._shatter_bounds.y, self._shatter_bounds.y + self._shatter_bounds.height

                    local px, py = self._scene:get_player():get_position()
                    self._goal_player_position_x, self._goal_player_position_y = self._goal_indicator_line[1], py
                    self._shatter_surface:shatter(px, py)
                    self._time_dilation_active = true
                    self._time_dilation_elapsed = 0
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

            self._goal_line = {
                body_x, body_y,
                body_x, body_y + surface_h
            }

            do
                local r, h = rt.settings.overworld.checkpoint.goal_line_width, surface_h
                local x, y = body_x - r, body_y
                local inner = function() return 1, 1, 1, 1 end
                local outer = function() return 1, 1, 1, 0  end
                self._goal_line_mesh = rt.Mesh({
                    [1] = { x + 0 * r, y + 0, 0, 0, outer() },
                    [2] = { x + 1 * r, y + 0, 1, 0, inner() },
                    [3] = { x + 2 * r, y + 0, 0, 0, outer() },
                    [4] = { x + 0 * r, y + h, 0, 1, outer() } ,
                    [5] = { x + 1 * r, y + h, 1, 1, inner() },
                    [6] = { x + 2 * r, y + h, 0, 1, outer() }
                }, rt.MeshDrawMode.TRIANGLES)

                self._goal_line_mesh:set_vertex_map({
                    1, 2, 5,
                    1, 4, 5,
                    2, 3, 6,
                    2, 5, 6
                })
            end

            local center_x, center_y, radius = 0, 0, 2 * player:get_radius()

            self._goal_indicator_outline = {}
            local mesh_data = {
                { center_x, center_y, 0, 0, 1, 1, 1, }
            }

            local n_vertices = 16
            for i = 1, n_vertices + 1 do
                local angle = (i - 1) / n_vertices * (2 * math.pi)
                local u, v = math.cos(angle), math.sin(angle)
                table.insert(mesh_data, {
                    center_x + u * radius, center_y + v * radius,
                    u, v,
                    1, 1, 1, 1
                })

                table.insert(self._goal_indicator_outline, center_x + u * radius)
                table.insert(self._goal_indicator_outline, center_y + v * radius)
            end

            self._goal_indicator = rt.Mesh(mesh_data)
            self._goal_indicator_line = {
                body_x, body_y, body_x, body_y + surface_h
            }

            local offset_x, offset_y = body_x, body_y + 0.5 * surface_h
            self._goal_indicator_motion:set_position(offset_x, offset_y)
            self._goal_indicator_motion:set_target_position(offset_x, offset_y)

            self._goal_time_label = rt.Glyph(_format_time(self._scene:get_timer()))
            self._goal_time_label:realize()
            self._goal_time_label:reformat(0, 0, math.huge, math.huge)
            self._goal_time_label_offset_x, self._goal_time_label_offset_y = 0, 0
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

        local _, screen_h = camera:world_xy_to_screen_xy(0, self._bottom_y)
        local spawn_y = self._bottom_y - screen_h - 2 * player:get_radius() -- always out of bounds, safe because ghost

        self._scene:set_camera_mode(ow.CameraMode.MANUAL)
        camera:set_position(self._bottom_x, self._bottom_y)

        player:reset()
        player:teleport_to(self._top_x, spawn_y)
        player:set_is_ghost(true)
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

        player:reset()
        player:enable()
    end
end

--- @brief
function ow.Checkpoint:update(delta)
    -- update fireworks indepedent from body location
    if self._type == ow.CheckpointType.MIDWAY then
        if self._fireworks_visible then
            self._fireworks:update(delta)
            self._fireworks_visible = not self._fireworks:get_is_done()
        end
    elseif self._type == ow.CheckpointType.PLAYER_GOAL then
        if self._is_shattered then
            self._shatter_surface:update(delta)
        end

        self._goal_indicator_motion:update(delta)
        self._goal_time_label:set_text(_format_time(self._scene:get_timer()))
        self._goal_time_label:set_color(table.unpack(self._color))
        local w, h = self._goal_time_label:measure()
        local gx, gy
        if not self._is_shattered then
            gx, gy = self._goal_indicator_motion:get_position()
            gy = select(2, self._scene:get_player():get_position())
        else
            gx, gy = self._goal_player_position_x, self._goal_player_position_y
        end

        self._goal_time_label_offset_x, self._goal_time_label_offset_y = gx - w - 20, gy - 0.5 * h

        if self._time_dilation_active == true then
            self._time_dilation_elapsed = self._time_dilation_elapsed + delta
            local fraction = self._time_dilation_elapsed / rt.settings.overworld.checkpoint.goal_time_dilation_duration

            fraction = rt.InterpolationFunctions.SINUSOID_EASE_OUT(fraction)
            local dilation = math.mix(1, rt.settings.overworld.checkpoint.goal_time_dilation, fraction)
            self._shatter_surface:set_time_dilation(dilation)
            self._scene:get_player():set_velocity(0.5 * dilation * self._shatter_velocity_x, 0.5 * dilation * self._shatter_velocity_y)

            if self._time_dilation_elapsed >= rt.settings.overworld.checkpoint.result_screen_delay
                and self._result_screen_revealed == false
            then
                self._scene:show_result_screen()
                self._result_screen_revealed = true
            end
        end
    end

    if not self._scene:get_is_body_visible(self._body) then return end
    local camera = self._scene:get_camera()
    local player = self._scene:get_player()

    self._color = { rt.lcha_to_rgba(0.8, 1, player:get_hue(), 1) }
    self._camera_offset = { camera:get_offset() }
    self._camera_scale = camera:get_scale()

    if self._type == ow.CheckpointType.PLAYER_SPAWN then
        -- noop
    elseif self._type == ow.CheckpointType.MIDWAY then
        self._rope:update(delta)
    elseif self._type == ow.CheckpointType.PLAYER_GOAL then
        if self._is_shattered == false then
            local x1, y1, x2, y2 = table.unpack(self._goal_indicator_line)
            local y = math.clamp(select(2, player:get_position()), y1, y2)
            self._goal_indicator_motion:set_target_position(x1, y)
        else
            self._goal_indicator_motion:set_target_position(self._goal_player_position_x, self._goal_player_position_y)
        end

        self._shatter_surface:update(delta)
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
        elseif self._type == ow.CheckpointType.PLAYER_GOAL then
            if self._is_shattered then self._shatter_surface:draw() end

            love.graphics.push()
            love.graphics.translate(
                self._goal_time_label_offset_x,
                self._goal_time_label_offset_y
            )
            self._goal_time_label:draw()
            love.graphics.pop()
        end
    end

    if self._state == _STATE_DEFAULT and not self._scene:get_is_body_visible(self._body) then return end
    local hue = self._scene:get_player():get_hue()

    if priority == _base_priority then
        love.graphics.setColor(self._color)
        self._body:draw()

        if self._spawn_barrier ~= nil then self._spawn_barrier:draw() end

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
        elseif self._type == ow.CheckpointType.PLAYER_GOAL then
            if not self._is_shattered then
                self._shatter_surface:draw()
                -- otherwise, drawn before body visiblity check
            end

            love.graphics.setLineWidth(2)
            love.graphics.setColor(self._color)
            love.graphics.line(self._goal_line)

            love.graphics.push()
            love.graphics.translate(self._goal_indicator_motion:get_target_position())

            _indicator_shader:bind()
            _indicator_shader:send("elapsed", rt.SceneManager:get_elapsed())
            self._goal_indicator:draw()
            _indicator_shader:unbind()

            --rt.Palette.BLACK:bind()
            --love.graphics.line(self._goal_indicator_outline)
            love.graphics.pop()
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
    if not self._scene:get_is_body_visible(self._body) then return end
    if self._type == ow.CheckpointType.MIDWAY then
        self._rope:draw_bloom()
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