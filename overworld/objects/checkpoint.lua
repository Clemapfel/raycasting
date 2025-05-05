require "overworld.fireworks"
require "common.smoothed_motion_1d"
require "common.sound_manager"

rt.settings.overworld.checkpoint = {
    max_spawn_duration = 5,
    celebration_particles_n = 500,
    passed_sound_id = "checkpoint_passed",
}

--- @class ow.Checkpoint 
ow.Checkpoint = meta.class("Checkpoint")

--- @class ow.CheckpointBody
ow.CheckpointBody = meta.class("CheckpointBody") -- dummy for `body` property

--- @class ow.PlayerSpawn
ow.PlayerSpawn = function(object, stage, scene) -- alias for first checkpoint
    return ow.Checkpoint(object, stage, scene, true)
end

local _mesh, _mesh_fill, _mesh_h = nil, nil, nil

local _outline_shader = love.graphics.newShader("overworld/objects/checkpoint_text.glsl", { defines = { MODE = 0 }})
_outline_shader:send("outline_color", { rt.Palette.BLACK:unpack() })

local _text_shader = love.graphics.newShader("overworld/objects/checkpoint_text.glsl", { defines = { MODE = 1 }})

--- @brief
function ow.Checkpoint:instantiate(object, stage, scene, is_player_spawn)
    meta.install(self, {
        _scene = scene,
        _stage = stage,
        _is_player_spawn = is_player_spawn or false,

        _x = object.x,
        _y = object.y,

        _top_x = math.huge,
        _top_y = math.huge,
        _bottom_x = math.huge,
        _bottom_y = math.huge,

        _mesh_position_y = math.huge,
        _mesh_motion = rt.SmoothedMotion1D(0, rt.settings.overworld.player.target_velocity_y),
        _mesh_visible = false,
        _passed = false,

        _color = { rt.Palette.CHECKPOINT:unpack() },
        _fireworks = ow.Fireworks(scene),

        _elapsed_text = "",
        _elapsed_text_height = 0,
        _elapsed_font_non_sdf = rt.settings.font.default_small:get_native(rt.FontStyle.REGULAR, false),
        _elapsed_font_sdf = rt.settings.font.default_small:get_native(rt.FontStyle.REGULAR, true)
    })

    local player_x, player_y = self._scene:get_player():get_position()
    self._mesh_motion:set_value(player_y)

    if _mesh == nil then
        _mesh_h = rt.settings.overworld.player.radius - 2
        _mesh = {}
        for angle = 0, 2 * math.pi, 2 * math.pi / 32 do
            table.insert(_mesh, 0 + math.cos(angle) * _mesh_h)
            table.insert(_mesh, 0 + math.sin(angle) * _mesh_h)
        end

        _mesh_fill = rt.MeshCircle(0, 0, _mesh_h)
        _mesh_fill:set_vertex_color(1, 0, 0, 0, 1)
        local outer = 0.65
        for i = 2, _mesh_fill:get_n_vertices() do
            _mesh_fill:set_vertex_color(i, outer, outer, outer, 1)
        end
        _mesh_fill = _mesh_fill:get_native()
    end

    stage:add_checkpoint(self, object.id, is_player_spawn)

    stage:signal_connect("initialized", function()
        local world = stage:get_physics_world()

        local inf = 10e9
        local bottom_x, bottom_y, nx, ny, body = world:query_ray(self._x, self._y, 0, inf)
        if bottom_x == nil then -- no ground
            rt.warning("In ow.Checkpoint: checkpoint `" .. object.id .. "` is not above solid ground")

            bottom_x = self._x
            bottom_y = self._y
        end

        local top_x, top_y, nx, ny, body = world:query_ray(self._x, self._y, 0, -inf)
        if top_x == nil then
            top_x = self._x
            top_y = self._y - inf
        end

        self._bottom_x, self._bottom_y = bottom_x, bottom_y
        self._top_x, self._top_y = top_x, top_y

        local player = self._scene:get_player()
        if math.distance(self._bottom_x, self._bottom_y, self._x, self._y) < player:get_radius() * 2 then
            rt.warning("In CheckPoint.initialize: checkpoint `" .. object.id .. "` does not have sufficient space below it")
        end

        if math.distance(self._top_x, self._top_y, self._x, self._y) < player:get_radius() * 2 then
            rt.warning("In CheckPoint.initialize: checkpoint `" .. object.id .. "` does not have sufficient space above it")
        end

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
        self._body:signal_connect("collision_start", function()
            if self._passed == false then
                self:pass()
            end
        end)

        return meta.DISCONNECT_SIGNAL
    end)
end

local _MODE_ASCEND = 0
local _MODE_EXPLODE = 1

--- @brief
function ow.Checkpoint:pass()
    if self._is_player_spawn or self._passed == true then return end

    local player = self._scene:get_player()
    local player_x, player_y = player:get_position()

    local hue = player:get_hue()
    self._color = { rt.lcha_to_rgba(0.8, 1, hue, 1) }

    self._mesh_motion:set_value(player_y)

    local hue_offset = 0.2
    local hue_min, hue_max = hue - hue_offset, hue + hue_offset
    local n_particles = 200 --0.5 * rt.settings.overworld.checkpoint.celebration_particles_n-- * (1 + player:get_flow())
    local x, y = player_x, player_y
    local vx, vy = player:get_velocity()
    local velocity = 0.5 * player:get_radius()
    self._fireworks:spawn(n_particles, velocity, x, y, 0, -1.5, hue_min, hue_max) -- spew upwards

    player:set_flow(1)
    self._passed = true

    rt.SoundManager:play(rt.settings.overworld.checkpoint.passed_sound_id)
end

--- @brief
function ow.Checkpoint:update(delta)
    if self._waiting_for_player then
        self._spawn_duration_elapsed = self._spawn_duration_elapsed + delta

        local player = self._scene:get_player()
        local player_x, player_y = player:get_position()

        -- spawn animation: once player reached location, unfreeze, with timer as failsafe
        if player_y >= (self._bottom_y - player:get_radius()) or self._spawn_duration_elapsed > rt.settings.overworld.checkpoint.max_spawn_duration then
            player:enable()
            player:set_trail_visible(true)
            self._waiting_for_player = false
            self._scene:set_camera_mode(ow.CameraMode.AUTO)
        end
    end

    if self._is_player_spawn then return end

    -- update graphics
    if not self._passed then
        local player = self._scene:get_player()
        local player_x, player_y = player:get_position()

        self._mesh_motion:set_target_value(player_y)
        self._mesh_motion:update(delta)
        self._mesh_out_of_bounds = player_y < self._top_y + _mesh_h or player_y > self._bottom_y - _mesh_h
    end

    self._mesh_position_y = self._mesh_motion:get_value()
    self._fireworks:update(delta)
    if self._fireworks:get_is_done() then self._passed = false end -- TODO

    if self._scene:get_is_body_visible(self._body) and self._passed == false then
        local duration = self._scene:get_run_duration()
        local hours = math.floor(duration / 3600)
        local minutes = math.floor((duration % 3600) / 60)
        local seconds = math.floor(duration % 60)
        local milliseconds = math.floor((duration * 1000) % 1000)

        if hours >= 1 then
            self._elapsed_text = string.format("%2d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
        elseif minutes >= 1 then
            self._elapsed_text = string.format("%2d:%02d.%03d", minutes, seconds, milliseconds)
        else
            self._elapsed_text = string.format("%2d.%03d", seconds, milliseconds)
        end

        self._elapsed_text_height = self._elapsed_font_non_sdf:getHeight(self._elapsed_text)
        self._color = { rt.lcha_to_rgba(0.8, 1, self._scene:get_player():get_hue(), 1) }
    end
end

--- @brief
function ow.Checkpoint:spawn()
    local player = self._scene:get_player()
    player:disable()
    local vx, vy = player:get_velocity()
    player:set_velocity(0, rt.settings.overworld.player.air_target_velocity_x)
    player:set_trail_visible(false)

    local camera = self._scene:get_camera()

    -- place player just above screen, or as high as possible
    local _, screen_h = camera:world_xy_to_screen_xy(self._bottom_x, self._bottom_y)
    local player_y = math.max(self._top_y + player:get_radius(), self._bottom_y - screen_h - 2 * player:get_radius())

    player:teleport_to(self._top_x, player_y)
    player:set_gravity(1)
    player:set_flow_velocity(0)
    self._waiting_for_player = true
    self._spawn_duration_elapsed = 0


    self._scene:set_camera_mode(ow.CameraMode.MANUAL)
    camera:set_position(self._bottom_x, self._bottom_y)
    self._stage:set_active_checkpoint(self)
    player:signal_emit("respawn")
end

--- @brief
function ow.Checkpoint:draw()
    self._fireworks:draw()

    if not self._scene:get_is_body_visible(self._body) then return end
    local mesh_x = self._top_x
    local mesh_y = self._mesh_position_y
    local stencil = rt.graphics.get_stencil_value()

    if self._mesh_out_of_bounds then
        rt.graphics.stencil(stencil, function()
            local inf = love.graphics.getWidth()

            love.graphics.rectangle("fill", self._bottom_x - inf, self._bottom_y, 2 * inf, inf)
            love.graphics.rectangle("fill", self._top_x - inf, self._top_y - inf, 2 * inf, inf)
        end)
        rt.graphics.set_stencil_test(rt.StencilCompareMode.NOT_EQUAL, stencil)
    end

    love.graphics.setColor(table.unpack(self._color))
    love.graphics.setLineWidth(2)
    love.graphics.line(self._top_x, self._top_y, self._bottom_x, self._bottom_y)

    love.graphics.push()
    love.graphics.translate(mesh_x, mesh_y)

    love.graphics.draw(_mesh_fill)
    love.graphics.polygon("line", _mesh)

    love.graphics.setShader(_outline_shader)
    love.graphics.setFont(self._elapsed_font_sdf)
    local text_x, text_y = math.round(_mesh_h + rt.settings.margin_unit * 0.5), math.round(-0.5 * self._elapsed_text_height)
    love.graphics.printf(self._elapsed_text, text_x, text_y, math.huge)
    love.graphics.setShader(_text_shader)
    love.graphics.setFont(self._elapsed_font_non_sdf)
    love.graphics.printf(self._elapsed_text, text_x, text_y, math.huge)
    love.graphics.setShader(nil)

    rt.graphics.set_stencil_test(nil)
    love.graphics.pop()
end

--- @brief
function ow.Checkpoint:get_render_priority()
    return math.huge
end