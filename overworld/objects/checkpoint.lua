require "common.sound_manager"
require "overworld.checkpoint_particles"
require "overworld.shatter_surface"
require "overworld.objects.checkpoint_rope"
require "overworld.objects.checkpoint_platform"
require "common.label"

rt.settings.overworld.checkpoint = {
    explosion_duration = 0.75,
    explosion_radius_factor = 9, -- times player radius

    ray_duration = 0.05,
    ray_width_radius_factor = 8,
    ray_fade_out_duration = 0.5,

    platform_width = 6 * rt.settings.player.radius,
    platform_height = rt.settings.overworld.checkpoint_rope.radius,

    max_rope_length = 400,
    n_particles = 40,

    max_spawn_duration = 3, -- safety timer
    hue_offset = 0.075
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
local _ray_lch_texture = rt.LCHTexture(1, 1, 256)

local _explosion_shader = rt.Shader("overworld/objects/checkpoint_explosion.glsl")
local _explosion_lch_texture = rt.LCHTexture(64, 1, 256)

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

        _x = object.x,
        _y = object.y,

        _top_x = math.huge,
        _top_y = math.huge,

        _color = { 1, 1, 1, 1 },
        _camera_offset = { 0, 0 },
        _camera_scale = 1,

        _ray_fraction = math.huge,
        _ray_area = rt.AABB(),
        _ray_fade_out_start_timestamp = math.huge,
        _ray_fade_out_elapsed = math.huge,
        _ray_fade_out_fraction = 0,
        _ray_particles = {},

        _explosion_visible = true,
        _explosion_elapsed = math.huge,
        _explosion_fraction = math.huge,
        _explosion_x = 0,
        _explosion_y = 0,
        _explosion_size = { 0, 0 },

        _elapsed = 0,
        _split_send = false,
        _should_emit_respawn = false,

        _spawn_elapsed = math.huge,

        _time_label = rt.Glyph("0", {
            is_outlined = true,
            style = rt.FontStyle.BOLD,
            is_mono = true
        }),

        _time_label_visible = true,
        _time_label_motion = rt.SmoothedMotion1D(0, 2),

        -- only for player spawn
        _spawn_barrier = nil, -- b2.Body
        _use_spawn_barrier = false,

        -- only for midway
        _particles = ow.CheckpointParticles(),
        _rope = nil -- ow.CheckpointRope, only if midpoint
    })

    self._is_invisible = object:get_boolean("is_invisible", false)
    if self._is_invisible == nil then self._is_invisible = false end

    stage:signal_connect("initialized", function()
        local create_platform = function(x, y)
            local platform_w = rt.settings.overworld.checkpoint.platform_width
            local platform_h = rt.settings.overworld.checkpoint.platform_height

            local left_x, left_y = x - 0.5 * platform_w, y
            local right_x, right_y = x + 0.5 * platform_w, y

            -- check if solid ground alreaddy present
            local bodies = self._world:query_aabb(
                left_x, left_y, right_x - left_x, platform_h, rt.settings.overworld.hitbox.collision_group
            )

            self._use_spawn_barrier = #bodies == 0

            if self._use_spawn_barrier then
                self._platform = ow.CheckpointPlatform(
                    left_x, left_y, right_x, right_y, platform_h
                )
            end

            local min_x, max_x = left_x, right_x
            local min_y, max_y = y, y + platform_h
            self._spawn_barrier = b2.Body(self._stage:get_physics_world(), b2.BodyType.STATIC, 0, 0,
                b2.Polygon(
                    min_x, min_y,
                    max_x, min_y,
                    max_x, max_y,
                    min_x, max_y
                )
            )

            self._spawn_barrier:set_collision_group(
                bit.bor(
                    rt.settings.player.ghost_collision_group,
                    rt.settings.overworld.hitbox.collision_group
                )
            )

            self._spawn_barrier:add_tag("stencil", "hitbox")
            self._spawn_barrier:set_is_enabled(false)

            self._spawn_barrier_segment = {
                left_x, left_y + 0.5 * platform_h, right_x, right_y + 0.5 * platform_h,
            }
        end

        local max_rope_length = rt.settings.overworld.checkpoint.max_rope_length
        local top_x, top_y, _ = self._world:query_ray(
            self._x, self._y,
            0, -0.5 * max_rope_length
        )

        if top_x == nil or top_y == nil then
            top_x = self._x
            top_y = self._y - 0.5 * max_rope_length
        end

        self._top_x, self._top_y = top_x, top_y

        -- cast down to find true ground
        local bottom_x, bottom_y, body = self._world:query_ray(
            self._top_x, self._top_y,
            0, max_rope_length
        )

        if bottom_x == nil or bottom_y == nil then
            bottom_x = self._x
            bottom_y = self._y + 0.5 * max_rope_length
        end

        self._bottom_x, self._bottom_y = bottom_x, bottom_y

        if self._type == ow.CheckpointType.PLAYER_SPAWN then
            self._bottom_y = math.min(self._bottom_y, self._y)

            create_platform(self._x, self._y)
            self._spawn_barrier:set_is_enabled(self._use_spawn_barrier)
            self._body = self._spawn_barrier
        else
            -- cast up and down to find attachment points
            create_platform(self._bottom_x, self._bottom_y)
            self._spawn_barrier:set_is_enabled(false)

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

            if not self._is_invisible then
                self._rope = ow.CheckpointRope(
                    self._scene, self._stage, self._world,
                    self._top_x, self._top_y,
                    self._bottom_x, self._bottom_y
                )
            end

            self._body:signal_connect("collision_start", function(_, other)
                if not self._is_invisible and self._rope:get_is_cut() == false then
                    if self._rope:cut() then -- checks player position automatically
                        local player = self._scene:get_player()
                        local px, py = player:get_position()
                        local hue = player:get_hue()

                        local settings = {
                            n_particles = rt.settings.overworld.checkpoint.n_particles,
                            min_hue = hue - 0.2,
                            max_hue = hue + 0.2
                        }

                        self:_spawn_rope_particles(px, py)
                    end
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

                    self._pass_time = self._scene:get_timer()
                    self._time_label:set_text(string.format_time(self._pass_time))
                    self._time_label_motion:set_value(math.mix(self._bottom_y, self._top_y, 0.5))
                    self._passed = true
                end
            end)
        end

        if not self._is_invisible then
            self._body:add_tag("point_light_source", "segment_light_source")
            self._body:set_user_data(self)
        end

        return meta.DISCONNECT_SIGNAL
    end)

    DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then
            self:_spawn_ray_particles()
        end
    end)
end

--- @brief
function ow.Checkpoint:_restore_coins()
    for coin_i = 1, self._stage:get_n_coins() do
        self._stage:set_coin_is_collected(coin_i, self._coin_savestate[coin_i] == true)
    end
end


--- @brief
function ow.Checkpoint:spawn(also_kill, play_animation)
    if also_kill == nil then also_kill = true end
    if play_animation == nil then play_animation = true end

    local is_first_spawn = self._stage:get_is_first_spawn()
    local player = self._scene:get_player()

    if also_kill then
        self._explosion_x, self._explosion_y = player:get_position()
    end

    player:reset()
    player:request_is_disabled(self, true)

    self._world:set_time_dilation(1)
    self._should_emit_respawn = true

    local type = self._type
    if is_first_spawn then
        self:_set_state(_STATE_STAGE_ENTRY)
    else
        if also_kill then
            self._explosion_visible = play_animation
            self:_set_state(_STATE_EXPLODING)
            self._scene:get_player():signal_emit("died")
        else
            self:_set_state(_STATE_RAY)
        end
    end

    self:_restore_coins()
    self._stage:set_active_checkpoint(self)
    self._spawn_barrier:set_is_enabled(self._use_spawn_barrier)
    self._passed = true
end

--- @brief
function ow.Checkpoint:_set_state(state)
    self._state = state
    local player = self._scene:get_player()
    local camera = self._scene:get_camera()

    if self._state ~= _STATE_DEFAULT then
        self._scene:clear_camera_mode()
        self._scene:push_camera_mode(ow.CameraMode.CUTSCENE)
    else
        self._scene:pop_camera_mode(ow.CameraMode.CUTSCENE)
    end

    if self._state == _STATE_STAGE_ENTRY then
        self._spawn_elapsed = 0

        -- find top most point to spawn player
        local screen_h = camera:get_world_bounds().height
        local _, max_y = self._world:query_ray(self._x, self._y, 0, -10e8)
        local spawn_y
        if max_y == nil then
            spawn_y = self._y - screen_h
        else
            spawn_y = math.max(self._y - screen_h, max_y)
        end

        self._top_y = spawn_y

        camera:set_apply_bounds(true)
        camera:set_position(self._bottom_x, self._bottom_y)
        self._stage:apply_camera_bounds(
            self._bottom_x, self._bottom_y,
            true -- snap instantly
        )

        player:reset()
        player:request_is_ghost(self, true)
        player:teleport_to(self._top_x, spawn_y)
        player:relax()
        player:request_is_disabled(self, true)

    elseif self._state == _STATE_EXPLODING then
        local player_radius = player:get_radius()
        local factor = rt.settings.overworld.checkpoint.explosion_radius_factor
        self._explosion_size = { 2 * factor * player_radius, 2 * factor * player_radius }

        camera:set_apply_bounds(true)
        camera:move_to(self._explosion_x, self._explosion_y)
        self._stage:apply_camera_bounds(
            self._explosion_x, self._explosion_y,
            false -- snap instantly
        )
        if self._explosion_visible then
            self:_spawn_explosion_particles(self._explosion_x, self._explosion_y)
        end

        self._explosion_elapsed = 0
        self._explosion_fraction = 0

        player:reset()
        player:request_is_frozen(self, true)
        player:request_is_visible(self, false)
        player:request_is_disabled(self, true)

    elseif self._state == _STATE_RAY then
        self._spawn_elapsed = 0

        camera:set_apply_bounds(true)
        camera:set_position(self._bottom_x, self._bottom_y)
        self._stage:apply_camera_bounds(
            self._bottom_x, self._bottom_y,
            true -- snap instantly
        )

        self._ray_fraction = 0
        self._ray_fade_out_elapsed = 0
        self._ray_fade_out_fraction = 0

        local ray_w = player:get_radius() * rt.settings.overworld.checkpoint.ray_width_radius_factor
        local screen_h = camera:get_world_bounds().height

        self._top_y = self._y - (screen_h / 2 + 4 * rt.settings.player.radius)

        local ray_top_y = self._ray_area:reformat(
            self._top_x - 0.5 * ray_w,
            self._top_y,
            ray_w,
            self._bottom_y - self._top_y
        )

        player:reset()
        player:request_is_ghost(self, true)
        player:teleport_to(self._top_x, self._top_y)
        player:request_opacity(self, 0)
        player:request_is_disabled(self, true)
        player:relax()
        self._stage:apply_camera_bounds(self._bottom_x, self._bottom_y)

    elseif self._state == _STATE_DEFAULT then
        player:reset()
        player:relax()
        player:request_is_disabled(self, nil) -- remove request
        self._stage:signal_emit("respawn")
        self._stage:apply_camera_bounds(self._bottom_x, self._bottom_y)
    end
end

--- @brief
function ow.Checkpoint:_spawn_ray_particles(x, y)
    local settings = {
        min_radius = 2,
        max_radius = 4,
        gravity = 0,
        min_damping = 0.92,
        max_damping = 0.95,
        min_angle = -math.pi,
        max_angle = 0,
        min_lifetime = 0.5,
        max_lifetime = 0.7,
        n_particles = rt.random.integer(3, 7),
        origin_offset = rt.settings.player.radius,
        is_point_light = true
    }

    local hue = self._scene:get_player():get_hue()
    local hue_offset = rt.settings.overworld.checkpoint.hue_offset
    settings.min_hue = hue - hue_offset
    settings.max_hue = hue + hue_offset

    self._particles:spawn(x, y, settings)
end

--- @brief
function ow.Checkpoint:_spawn_explosion_particles(x, y)
    local settings = {
        min_radius = 2,
        max_radius = 5,
        gravity = 0,
        min_damping = 0.95,
        max_damping = 0.98,
        min_angle = 0,
        max_angle = 2 * math.pi,
        min_lifetime = 0.5,
        max_lifetime = 0.7,
        n_particles = rt.random.integer(9, 14),
        origin_offset = rt.settings.player.radius,
        is_point_light = true
    }

    local hue = self._scene:get_player():get_hue()
    local hue_offset = rt.settings.overworld.checkpoint.hue_offset
    settings.min_hue = hue - 2 * hue_offset
    settings.max_hue = hue + 2 * hue_offset

    self._particles:spawn(x, y, settings)
end

--- @brief
function ow.Checkpoint:_spawn_rope_particles(x, y)
    local velocity = 3
    local settings = {
        min_radius = 5,
        max_radius = 6,
        min_velocity = 0,
        max_velocity = 200 * velocity,
        gravity = 200,
        min_damping = 1,
        max_damping = 1,
        min_angle = 0,
        max_angle = 2 * math.pi,
        min_lifetime = 10,
        max_lifetime = 10,
        n_particles = rt.random.integer(128, 128),
        origin_offset = rt.settings.player.radius,
        draw_as_outline = true,
        is_point_light = false
    }

    local hue = self._scene:get_player():get_hue()
    local hue_offset = rt.settings.overworld.checkpoint.hue_offset
    settings.min_hue = hue - 2 * hue_offset
    settings.max_hue = hue + 2 * hue_offset

    self._particles:spawn(x, y, settings)
end

--- @brief
function ow.Checkpoint:update(delta)
    local camera = self._scene:get_camera()
    local player = self._scene:get_player()

    -- update particles indepedent from body location
    if self._particles ~= nil then
        self._particles:set_bounds(self._scene:get_camera():get_world_bounds())
        self._particles:update(delta)
    end

    if self._state == _STATE_DEFAULT and not self._stage:get_is_body_visible(self._body) then return end

    self._color = { player:get_color():unpack() }
    self._camera_offset = { camera:get_offset() }
    self._camera_scale = camera:get_scale()

    if self._platform ~= nil and self._spawn_barrier:get_is_enabled() then
        self._platform:set_hue(self._scene:get_player():get_hue())
    end

    if self._type == ow.CheckpointType.MIDWAY then
        if self._rope ~= nil then
            self._rope:update(delta)
        end

        if rt.GameState:get_draw_speedrun_splits() and self._time_label_visible == true then
            self._time_label:set_color(self._color)

            if self._passed == false then
                self._time_label:set_text(string.format_time(self._scene:get_timer()))
                self._time_label_motion:set_target_value(math.clamp(
                    select(2, player:get_position()),
                    self._top_y,
                    self._bottom_y
                ))
                self._time_label_motion:update(delta)
            else
                local camera_bounds = self._scene:get_camera():get_world_bounds()
                local label_bounds = rt.AABB(
                    self._bottom_x,
                    self._time_label_motion:get_value(),
                    self._time_label:measure()
                )

                local padding = 10 * rt.get_pixel_scale()
                label_bounds.x = label_bounds.x - padding
                label_bounds.y = label_bounds.y - padding
                label_bounds.width = label_bounds.width + 2 * padding
                label_bounds.height = label_bounds.height + 2 * padding

                if not camera_bounds:overlaps(label_bounds) then
                    self._time_label_visible = false
                end
            end
        end
    end

    if self._state == _STATE_STAGE_ENTRY then
        -- wait for player to reach ghost spawn
        local player_x, player_y = player:get_position()
        if player_y >= self._bottom_y - 2 * player:get_radius() or self._spawn_elapsed > rt.settings.overworld.checkpoint.max_spawn_duration then
            self:_set_state(_STATE_DEFAULT)
            player:relax()
        end

        self._spawn_elapsed = self._spawn_elapsed + delta
    elseif self._state == _STATE_EXPLODING then
        local duration = rt.settings.overworld.checkpoint.explosion_duration
        self._explosion_fraction = self._explosion_elapsed / duration
        self._explosion_elapsed = self._explosion_elapsed + delta

        self._scene:set_blur(rt.InterpolationFunctions.GAUSSIAN_HIGHPASS(math.min(1, self._explosion_elapsed / duration)))

        if self._explosion_elapsed > duration then
            if self._rope:get_is_cut() then self._rope:_despawn() end
            self:_set_state(_STATE_RAY)
        end
    elseif self._state == _STATE_RAY then
        if self._ray_fraction < 1 and self._should_emit_respawn then
            self._stage:signal_emit("respawn", false) -- is first spawn
            self._should_emit_respawn = false
        end

        local threshold = self._bottom_y - 2 * player:get_radius()
        local player_x, player_y = player:get_position()
        if self._ray_fraction < 1 then
            self._ray_fraction = 1 - (player_y - threshold) / (self._top_y - threshold)
        end

        player:request_opacity(self, rt.InterpolationFunctions.GAUSSIAN_HIGHPASS(self._ray_fraction))
        self._scene:set_blur(rt.InterpolationFunctions.GAUSSIAN_HIGHPASS(1 - math.min(1, self._ray_fraction)))

        if player_y >= threshold or self._spawn_elapsed > rt.settings.overworld.checkpoint.max_spawn_duration then
            self._ray_fade_out_start_timestamp = love.timer.getTime()
            self:_spawn_ray_particles(self._bottom_x, self._bottom_y)
            self:_set_state(_STATE_DEFAULT)
        end
        self._spawn_elapsed = self._spawn_elapsed + delta
    elseif self._state == _STATE_DEFAULT then
        -- ray fades out after player has spawned
        self._scene:set_blur(0)


        player:request_opacity(self, nil)
    end
end

local _base_priority = 0
local _effect_priority = math.huge

--- @brief
function ow.Checkpoint:draw(priority)
    if self._platform ~= nil and self._stage:get_is_body_visible(self._spawn_barrier) then
        self._platform:draw()
    end

    local hue = self._scene:get_player():get_hue()

    if priority == _base_priority then
        local ray_fade_out_duration = rt.settings.overworld.checkpoint.ray_fade_out_duration

        local ray_fade_out_fraction = 1
        if self._state == _STATE_DEFAULT then
            local fade_out_duration = rt.settings.overworld.checkpoint.ray_fade_out_duration
            ray_fade_out_fraction = 1 - math.min(1, (love.timer.getTime() - self._ray_fade_out_start_timestamp) / fade_out_duration)
        end

        -- ray drawn behind player
        if self._state == _STATE_RAY
            or self._state == _STATE_DEFAULT
        then
            love.graphics.setColor(1, 1, 1, 1)
            _ray_shader:bind()
            _ray_shader:send("fraction", self._ray_fraction)
            _ray_shader:send("fade_out_fraction", ray_fade_out_fraction)
            _ray_shader:send("size", { self._ray_area.width, self._ray_area.height })
            _ray_shader:send("elapsed", self._elapsed)
            _ray_shader:send("hue", hue)
            _ray_shader:send("camera_offset", self._camera_offset)
            _ray_shader:send("camera_scale", self._camera_scale)
            _ray_shader:send("lch_texture", _ray_lch_texture)
            _ray_shader:send("screen_to_world_transform", self._scene:get_camera():get_transform():inverse())
            _ray_shader:send("bottom", { self._bottom_x, self._bottom_y })
            love.graphics.rectangle("fill", self._ray_area:unpack())
            _ray_shader:unbind()
        end

        if self._type == ow.CheckpointType.MIDWAY and self._rope ~= nil then
            love.graphics.setColor(self._color)
            self._rope:draw()
        end
    elseif priority == _effect_priority then
        -- explosion draw above everything
        if self._state == _STATE_EXPLODING then
            love.graphics.setColor(1, 1, 1, 1)
            _explosion_shader:bind()
            _explosion_shader:send("fraction", self._explosion_fraction)
            _explosion_shader:send("size", self._explosion_size)
            _explosion_shader:send("hue", hue)
            _explosion_shader:send("lch_texture", _explosion_lch_texture)

            local x, y = self._explosion_x, self._explosion_y
            local w, h = table.unpack(self._explosion_size)
            love.graphics.rectangle("fill", x - 0.5 * w, y - 0.5 * h, w, h)
            _explosion_shader:unbind()
        end

        if priority == _effect_priority then
            self._particles:draw()
        end

        if rt.GameState:get_draw_speedrun_splits()
            and self._type == ow.CheckpointType.MIDWAY
            and self._time_label_visible
        then
            local w, h = self._time_label:measure()
            local y = math.clamp(self._time_label_motion:get_value(), self._top_y + 0.5 * h, self._bottom_y - 0.5 * h)
            self._time_label:draw(
                 self._bottom_x + 0.5 * rt.settings.overworld.checkpoint_rope.radius,
                 y - 0.5 * h
             )
        end
    end
end

--- @brief
function ow.Checkpoint:draw_bloom()
    if not self._stage:get_is_body_visible(self._body) or self._is_invisible then return end
    if self._type == ow.CheckpointType.MIDWAY then
        self._rope:draw_bloom()
    elseif self._type == ow.CheckpointType.PLAYER_SPAWN then
        if self._platform ~= nil and self._spawn_barrier:get_is_enabled() then
            self._platform:draw_bloom()
        end
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
    self._coin_savestate = {}
    self._split_send = false
    self._time_label_visible = true

    if self._type == ow.CheckpointType.MIDWAY and not self._is_invisible then
        self._particles:clear()
        self._rope:reset()
    end

    self:_set_state(_STATE_DEFAULT)
end

--- @brief
function ow.Checkpoint:get_is_respawning()
    return self._state ~= _STATE_DEFAULT
end

--- @brief
function ow.Checkpoint:collect_point_lights(callback)
    if self._is_invisible then return end

    self._particles:collect_point_lights(callback)

    if self._state == _STATE_EXPLODING then
        callback(
            self._explosion_x,
            self._explosion_y,
            rt.settings.player.radius * rt.settings.player.bubble_radius_factor,
            table.unpack(self._color)
        )
    end
end

--- @brief
function ow.Checkpoint:collect_segment_lights(callback)
    if self._rope ~= nil then
        self._rope:collect_segment_lights(callback)
    end

    if self._spawn_barrier ~= nil then
        local x1, y1, x2, y2 = table.unpack(self._spawn_barrier_segment)
        callback(
            x1, y1, x2, y2,
            table.unpack(self._color)
        )
    end

    if self._state == _STATE_RAY then
        local r, g, b, _ = table.unpack(self._color)
        callback(
            self._top_x, self._top_y,
            self._bottom_x, self._bottom_y,
            r, g, b, self._ray_fade_out_fraction
        )
    end
end
