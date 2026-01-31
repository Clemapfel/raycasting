require "common.sound_manager"
require "overworld.shatter_surface"
require "overworld.checkpoint_particles"
require "common.label"


rt.settings.overworld.goal = {
    result_screen_delay = 0.5,
    outline_width = 6,

    flash_animation_duration = 20 / 60, -- seconds
    time_dilation_animation_duration = 2,
    fade_to_black_duration = 2.5,

    n_particles = 40
}

rt.settings.overworld.goal.time_dilation_duration = rt.settings.overworld.shatter_surface.fade_duration

--- @class ow.Goal
--- @types Point
ow.Goal = meta.class("Goal", ow.MovableObject)

local _indicator_shader = rt.Shader("overworld/objects/goal_indicator.glsl")
local _outline_shader = rt.Shader("overworld/objects/checkpoint_platform.glsl")

local _format_time = function(time)
    return string.format_time(time), {
        style = rt.FontStyle.BOLD,
        is_outlined = true,
        font_size = rt.FontSize.REGULAR,
        color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, rt.GameState:get_player():get_hue(), 1))
    }
end

--- @brief
function ow.Goal:instantiate(object, stage, scene)
    meta.install(self, {
        _scene = scene,
        _stage = stage,
        _world = stage:get_physics_world(),

        _object = object,
        _color = rt.RGBA(1, 1, 1, 1),

        _elapsed = 0,

        _is_shattered = false,
        _body = nil,    -- b2.Body
        _shatter_surface = nil, -- ow.ShatterSurface
        _time_dilation_elapsed = 0,
        _time_dilation_active = false,
        _shatter_velocity_x = 0,
        _shatter_velocity_y = 0,

        _indicator_outline = { 0, 0, 1, 1 }, -- love.Line
        _indicator_line = { 0, 0, 1, 1 }, -- love.Line
        _indicator = nil, -- rt.Mesh
        _indicator_motion = rt.SmoothedMotion1D(0, 2),
        _indicator_x = 0,
        _indicator_y = 0,

        _final_player_position_x = 0,
        _final_player_position_y = 0,

        _flash_animation = nil, -- rt.TimedAnimationSequence
        _player_time_dilation_animation = nil,
        _world_time_dilation_animation = nil,
        _fade_to_black_animation = nil,

        _result_screen_revealed = false,

        _particles = ow.CheckpointParticles(),
        _impulse = rt.ImpulseSubscriber()
    })

    rt.assert(object:get_type() == ow.ObjectType.RECTANGLE and object:get_rotation() == 0, "In ow.Goal: object `", object:get_id(), "` in stage `", self._stage:get_id(), "` is not an axis-aligned rectangle")


    self._bounds = rt.AABB(object.x, object.y, object.width, object.height)

    -- animations
    do
        local duration = rt.settings.overworld.goal.flash_animation_duration
        self._flash_animation = rt.AnimationChain(
            duration * 1 / 2, 0, 1,
            rt.InterpolationFunctions.SIGMOID,

            duration * 1 / 2, 1, 0,
            rt.InterpolationFunctions.SINUSOID_EASE_IN_OUT
        )
    end

    do
        local duration = rt.settings.overworld.goal.time_dilation_animation_duration
        local min_dilation = 0.2
        self._player_time_dilation_animation = rt.AnimationChain(
            rt.settings.overworld.goal.flash_animation_duration / 2,
            1, min_dilation,
            rt.InterpolationFunctions.GAUSSIAN_HIGHPASS,

            duration * 5 / 8,
            min_dilation, min_dilation,
            rt.InterpolationFunctions.LINEAR,

            duration * 3 / 8,
            min_dilation, min_dilation,
            rt.InterpolationFunctions.LINEAR
        )

        self._world_time_dilation_animation = rt.AnimationChain(
            rt.settings.overworld.goal.flash_animation_duration / 2,
            1, min_dilation,
            rt.InterpolationFunctions.GAUSSIAN_HIGHPASS,

            duration * 5 / 8,
            min_dilation, min_dilation,
            rt.InterpolationFunctions.LINEAR,

            duration * 3 / 8,
            min_dilation, 1,
            rt.InterpolationFunctions.GAUSSIAN_HIGHPASS
        )
    end

    do
        self._fade_to_black_animation = rt.TimedAnimation(
            rt.settings.overworld.goal.fade_to_black_duration,
            0, 1,
            rt.InterpolationFunctions.GAUSSIAN_HIGHPASS
        )
    end

    stage:signal_connect("initialized", function()
        local _, _, w, h = self._bounds:unpack()
        local player = self._scene:get_player()
        self._body = b2.Body(self._stage:get_physics_world(), object:get_physics_body_type(),
            self._bounds.x + 0.5 * self._bounds.width, self._bounds.y + 0.5 * self._bounds.height,
            b2.Rectangle(-0.5 * w, -0.5 * h, w, h)
        )

        local offset = rt.settings.overworld.goal.outline_width / 2 -- for pixel perfect hitbox accuracy

        local function create_mesh(min_x, min_y, max_x, max_y, radius)
            meta.assert(min_x, "Number", min_y, "Number", max_x, "Number", max_y, "Number")
            if min_x > max_x then min_x, max_x = max_x, min_x end
            if min_y > max_y then min_y, max_y = max_y, min_y end

            local inner_thickness = 0.25 * radius
            local outer_thickness = radius

            local ix1 = min_x + inner_thickness
            local iy1 = min_y + inner_thickness
            local ix2 = max_x - inner_thickness
            local iy2 = max_y - inner_thickness

            local ox1 = min_x - outer_thickness
            local oy1 = min_y - outer_thickness
            local ox2 = max_x + outer_thickness
            local oy2 = max_y + outer_thickness

            local mesh_data = {}
            local function add_vertex(x, y, u, v, alpha)
                table.insert(mesh_data, { x, y, u, v, 1, 1, 1, alpha })
            end

            add_vertex(ix1, iy1, 0/4, 1, 1) -- top-left
            add_vertex(ix2, iy1, 1/4, 1, 1) -- top-right
            add_vertex(ix2, iy2, 2/4, 1, 1) -- bottom-right
            add_vertex(ix1, iy2, 3/4, 1, 1) -- bottom-left
            add_vertex(ix1, iy1, 4/4, 1, 1) -- wrap duplicate

            add_vertex(ox1, oy1, 0/4, 0, 0) -- top-left
            add_vertex(ox2, oy1, 1/4, 0, 0) -- top-right
            add_vertex(ox2, oy2, 2/4, 0, 0) -- bottom-right
            add_vertex(ox1, oy2, 3/4, 0, 0) -- bottom-left
            add_vertex(ox1, oy1, 4/4, 0, 0) -- wrap duplicate

            local mesh = rt.Mesh(mesh_data, rt.MeshDrawMode.TRIANGLES)

            mesh:set_vertex_map({
                1, 6, 2,   2, 6, 7,
                2, 7, 3,   3, 7, 8,
                3, 8, 4,   4, 8, 9,
                4, 9, 5,   5, 9, 10
            })

            return mesh
        end

        do
            local x, y, width, height = self._bounds:unpack()
            x, y = -0.5 * width, -0.5 * height

            self._outline_mesh = create_mesh(
                x, y,
                x + width, y + height ,
                rt.settings.overworld.checkpoint_rope.radius
            )

            self._path = rt.Path(
                x, y,
                x + width, y,
                x + width, y + height,
                x, y + height,
                x, y
            )

            self._shatter_surface = ow.ShatterSurface(
                self._scene, self._world,
                x, y, width, height
            )
        end

        local collision_mask, collision_group = rt.settings.player.bounce_collision_group, rt.settings.player.bounce_collision_group
        self._body:set_collides_with(collision_mask)
        self._body:set_collision_group(collision_group)
        self._body:set_is_sensor(true)
        self._body:signal_connect("collision_start", function(_, other, nx, ny, x, y, x2, y2)
            if self._is_shattered == false then
                self._is_shattered = true
                self._scene:stop_timer()
                self._shatter_velocity_x, self._shatter_velocity_y = self._scene:get_player():get_velocity()
                local min_x, max_x = self._bounds.x, self._bounds.x + self._bounds.width
                local min_y, max_y = self._bounds.y, self._bounds.y + self._bounds.height

                local px, py = self._scene:get_player():get_position()
                px, py = math.subtract(px, py, self._body:get_position())
                self._final_player_position_x, self._final_player_position_y = px, py
                self._shatter_surface:shatter(px, py, self._shatter_velocity_x, self._shatter_velocity_y)

                self._flash_animation:reset()
                self._player_time_dilation_animation:reset()
                self._world_time_dilation_animation:reset()
                self._particles:spawn(
                    rt.settings.overworld.goal.n_particles,
                    -0.5 * (max_x - min_x), -0.5 * (max_y - min_y),
                    player:get_hue(),
                    self._shatter_velocity_x, self._shatter_velocity_y
                )
                player:pulse()
                self._scene:set_control_indicator_type(ow.ControlIndicatorType.NONE)
            end
        end)

        do
            self._body:add_tag("segment_light_source")
            self._body:set_user_data(self)

            local offset = 0
            self._outline = {
                self._bounds.x + offset, self._bounds.y + offset,
                self._bounds.x + self._bounds.width - offset, self._bounds.y + offset,
                self._bounds.x + self._bounds.width - offset, self._bounds.y + self._bounds.height - offset,
                self._bounds.x + offset, self._bounds.y + self._bounds.height - offset,
                self._bounds.x + offset, self._bounds.y + offset
            }

            local segment_lights = {}
            for i = 1, #self._outline - 4, 4 do
                table.insert(segment_lights, {
                    self._outline[i+0],
                    self._outline[i+1],
                    self._outline[i+2],
                    self._outline[i+3]
                })
            end

            self.get_segment_light_sources = function(self)
                local colors = {}
                for i = 1, #segment_lights do table.insert(colors, self._color) end
                return segment_lights, colors
            end
        end

        local center_x, center_y, radius = 0, 0, 2 * player:get_radius()

        self._indicator_outline = {}
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

            table.insert(self._indicator_outline, center_x + u * radius)
            table.insert(self._indicator_outline, center_y + v * radius)
        end

        self._indicator = rt.Mesh(mesh_data)

        self._indicator_x, self._indicator_y = self._path:at(0)
        self._indicator_motion:set_value(0)
        self._indicator_motion:set_target_value(0)
        self._indicator_motion:set_is_periodic(true, 0, 1)

        self._time_label = rt.Glyph(_format_time(self._scene:get_timer()))
        self._time_label:realize()
        self._time_label:reformat(-math.huge, -math.huge, math.huge, math.huge)
        self._time_label_offset_x, self._time_label_offset_y = 0, 0

        self._shatter_surface:set_offset(self._body:get_position())

        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function ow.Goal:update(delta)
    if not self._is_shattered and not self._stage:get_is_body_visible(self._body) then return end

    local player = self._scene:get_player()
    self._shatter_surface:set_offset(self._body:get_position())

    if self._is_shattered then
        self._shatter_surface:update(delta)

        self._flash_animation:update(delta)
        self._shatter_surface:set_flash(self._flash_animation:get_value())

        self._player_time_dilation_animation:update(delta)
        local dilation = self._player_time_dilation_animation:get_value()
        player:set_velocity(
            0.5 * dilation * self._shatter_velocity_x,
            0.5 * dilation * self._shatter_velocity_y
        )

        self._world_time_dilation_animation:update(delta)
        self._world:set_time_dilation(self._world_time_dilation_animation:get_value())

        local is_done = self._fade_to_black_animation:update(delta)
        self._scene:set_fade_to_black(self._fade_to_black_animation:get_value())

        if is_done and not self._result_screen_revealed then
            self._result_screen_revealed = true
            self._world:set_time_dilation(0)
            self._scene:set_fade_to_black(1)
            self._scene:show_result_screen()
        end

        self._particles:set_screen_bounds(self._scene:get_camera():get_world_bounds())
        self._particles:update(delta)
    end

    self._indicator_motion:update(delta)
    self._time_label:set_text(_format_time(self._scene:get_timer()))
    self._time_label:set_color(self._color:unpack())
    local w, h = self._time_label:measure()

    if not self._is_shattered then
        self._indicator_x, self._indicator_y = self._path:at(self._indicator_motion:get_value())
    else
        self._indicator_x, self._indicator_y = self._final_player_position_x, self._final_player_position_y
    end

    self._time_label_offset_x = self._indicator_x - w - 20 -- 20px hmargin
    self._time_label_offset_y = self._indicator_y - 0.5 * h

    self._color = player:get_color()

    local px, py = player:get_position()
    local offset_x, offset_y = self._body:get_position()
    px = px - offset_x
    py = py - offset_y
    local closest_x, closest_y, t = self._path:get_closest_point(px, py)
    self._indicator_motion:set_target_value(t)
end

local _base_priority = 0
local _label_priority = 1

--- @brief
function ow.Goal:draw(priority)
    if not self._is_shatterd and not self._stage:get_is_body_visible(self._body) then return end
    local brightness_scale = math.mix(1, rt.settings.impulse_manager.max_brightness_factor, self._impulse:get_pulse())

    if priority == _base_priority then
        self._color:bind()
        self._shatter_surface:draw()


        local offset_x, offset_y = self._body:get_position()
        love.graphics.push()
        love.graphics.translate(offset_x, offset_y)

        if self._is_shattered == false then
            _outline_shader:bind()
            _outline_shader:send("elapsed", rt.SceneManager:get_elapsed())
            _outline_shader:send("color", { self._color:unpack() })
            _outline_shader:send("brightness_scale", brightness_scale)
            _outline_shader:send("bloom_active", false)
            self._outline_mesh:draw()
            _outline_shader:unbind()

            -- dont draw time until result screen for suspense
            love.graphics.push()
            love.graphics.translate(self._indicator_x, self._indicator_y)

            _indicator_shader:bind()
            _indicator_shader:send("elapsed", rt.SceneManager:get_elapsed())
            _indicator_shader:send("brightness_scale", brightness_scale)
            self._indicator:draw()
            _indicator_shader:unbind()

            love.graphics.pop()
        end

        self._particles:draw()
        love.graphics.pop()
    elseif priority == _label_priority then
        if not self._is_shattered then
            local offset_x, offset_y = self._body:get_position()
            love.graphics.push()
            love.graphics.translate(offset_x, offset_y)

            self._time_label:draw()

            love.graphics.pop()
        end
    end
end

--- @brief
function ow.Goal:draw_bloom()
    if not self._stage:get_is_body_visible(self._body) then return end

    if self._is_shattered == false then
        self._shatter_surface:draw_bloom()

        _outline_shader:bind()
        _outline_shader:send("elapsed", rt.SceneManager:get_elapsed())
        _outline_shader:send("color", { self._color:unpack() })
        _outline_shader:send("bloom_active", false)
        self._outline_mesh:draw()
        _outline_shader:unbind()
    end
end

--- @brief
function ow.Goal:get_type()
    return self._type
end

--- @brief
function ow.Goal:reset()
    self._shatter_surface:reset()
    self._world_time_dilation_animation:reset()
    self._player_time_dilation_animation:reset()
    self:update(0)
    self._particles:clear()
    self._is_shattered = false
end

--- @brief
function ow.Goal:get_render_priority()
    return _base_priority, _label_priority
end

--- @brief
function ow.Goal:get_position()
    if self._body == nil then
        return self._x, self._y
    else
        return self._body:get_position()
    end
end

--- @brief
function ow.Goal:set_position(x, y)
    self._body:set_position(x, y)
    self._shatter_surface:set_offset(x, y)
end

--- @brief
function ow.Goal:set_velocity(vx, vy)
    if self._is_shattered then return end
    self._body:set_velocity(vx, vy)
end
