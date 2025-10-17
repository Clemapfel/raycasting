require "common.sound_manager"
require "overworld.fireworks"
require "overworld.shatter_surface"
require "common.label"

rt.settings.overworld.goal = {
    time_dilation = 0,
    result_screen_delay = 0.5,
    outline_width = 6,
    size = 200, -- px, square
}

rt.settings.overworld.goal.time_dilation_duration = rt.settings.overworld.shatter_surface.fade_duration

--- @class ow.Goal
--- @types Point
ow.Goal = meta.class("Goal")

local _indicator_shader = rt.Shader("overworld/objects/goal_indicator.glsl")

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
        _x = object.x,
        _y = object.y,

        _color = { 1, 1, 1, 1 },

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

        _result_screen_revealed = false
    })
    stage:signal_connect("initialized", function()
        local player = self._scene:get_player()
        local size = rt.settings.overworld.goal.size

        -- try to push out of level geometry, this may fail but catches common cases
        local cast_ray = function(dx, dy)
            local x, y = self._x, self._y
            local rx, ry = self._world:query_ray(x, y, dx * size / 2, dy * size / 2)
            if rx == nil then return size / 2 else return math.distance(x, y, rx, ry) end
        end

        local top_dist = cast_ray(0, -1)
        self._y = self._y + (size / 2 - top_dist)

        local bottom_dist = cast_ray(0, 1)
        self._y = self._y - (size / 2 - bottom_dist)

        local left_dist = cast_ray(-1, 0)
        self._x = self._x - (size / 2 - left_dist)

        local right_dist = cast_ray(1, 0)
        self._x = self._x + (size / 2 - right_dist)
        
        local bx, by, bw, bh = -0.5 * size, -0.5 * size, size, size
        self._body = b2.Body(self._stage:get_physics_world(), b2.BodyType.STATIC,
            self._x, self._y,
            b2.Polygon(
                bx, by,
                bx + bw, by,
                bx + bw, by + bh,
                bx, by + bh
            )
        )

        self._bounds = rt.AABB(self._x + bx, self._y + by, bw, bh)

        local offset = rt.settings.overworld.goal.outline_width / 2 -- for pixel perfect hitbox accuracy
        self._outline = {
            self._bounds.x + offset, self._bounds.y + offset,
            self._bounds.x + self._bounds.width - offset, self._bounds.y + offset,
            self._bounds.x + self._bounds.width - offset, self._bounds.y + self._bounds.height - offset,
            self._bounds.x + offset, self._bounds.y + self._bounds.height - offset,
            self._bounds.x + offset, self._bounds.y + offset
        }

        self._path = rt.Path(
            self._bounds.x, self._bounds.y,
            self._bounds.x + self._bounds.width, self._bounds.y,
            self._bounds.x + self._bounds.width, self._bounds.y + self._bounds.height,
            self._bounds.x, self._bounds.y + self._bounds.height,
            self._bounds.x, self._bounds.y
        )

        self._segment_lights = {}
        for i = 1, #self._outline - 4, 4 do
            table.insert(self._segment_lights, {
                self._outline[i+0],
                self._outline[i+1],
                self._outline[i+2],
                self._outline[i+3]
            })
        end

        self._shatter_surface = ow.ShatterSurface(self._world, self._bounds:unpack())

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
                self._final_player_position_x, self._final_player_position_y = px, py
                self._shatter_surface:shatter(px, py)
                self._time_dilation_active = true
                self._time_dilation_elapsed = 0
            end
        end)

        self._body:add_tag("segment_light_source")
        self._body:set_user_data(self)

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
        self._time_label:reformat(0, 0, math.huge, math.huge)
        self._time_label_offset_x, self._time_label_offset_y = 0, 0

        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function ow.Goal:update(delta)
    if not self._is_shattered and not self._stage:get_is_body_visible(self._body) then return end
    if self._is_shattered then
        self._shatter_surface:update(delta)
    end

    self._indicator_motion:update(delta)
    self._time_label:set_text(_format_time(self._scene:get_timer()))
    self._time_label:set_color(table.unpack(self._color))
    local w, h = self._time_label:measure()


    if not self._is_shattered then
        self._indicator_x, self._indicator_y = self._path:at(self._indicator_motion:get_value())
    else
        self._indicator_x, self._indicator_y = self._final_player_position_x, self._final_player_position_y
    end

    self._time_label_offset_x = self._indicator_x - w - 20 -- 20px hmargin
    self._time_label_offset_y = self._indicator_y - 0.5 * h

    local player = self._scene:get_player()
    self._color = { rt.lcha_to_rgba(0.8, 1, player:get_hue(), 1) }

    local closest_x, closest_y, t = self._path:get_closest_point(player:get_position())
    self._indicator_motion:set_target_value(t)

    if self._time_dilation_active == true then
        self._time_dilation_elapsed = self._time_dilation_elapsed + delta
        local fraction = self._time_dilation_elapsed / rt.settings.overworld.goal.time_dilation_duration

        fraction = rt.InterpolationFunctions.SINUSOID_EASE_OUT(fraction)
        local dilation = math.mix(1, rt.settings.overworld.goal.time_dilation, fraction)
        self._shatter_surface:set_time_dilation(dilation)
        self._scene:get_player():set_velocity(0.5 * dilation * self._shatter_velocity_x, 0.5 * dilation * self._shatter_velocity_y)

        if self._time_dilation_elapsed >= rt.settings.overworld.goal.result_screen_delay
            and self._result_screen_revealed == false
        then
            --TODO: self._scene:show_result_screen()
            self._result_screen_revealed = true
        end
    end
end

local _base_priority = 0
local _label_priority = math.huge

--- @brief
function ow.Goal:draw(priority)
    if priority == _base_priority then
        love.graphics.setColor(self._color)
        self._shatter_surface:draw()

        if not self._is_shattered then
            local line_width = rt.settings.overworld.goal.outline_width

            rt.Palette.BLACK:bind()
            love.graphics.setLineWidth(line_width)
            love.graphics.line(self._outline)

            love.graphics.setColor(self._color)
            love.graphics.setLineWidth(line_width - 3)
            love.graphics.line(self._outline)
        end

        love.graphics.push()
        love.graphics.translate(self._indicator_x, self._indicator_y)

        _indicator_shader:bind()
        _indicator_shader:send("elapsed", rt.SceneManager:get_elapsed())
        self._indicator:draw()
        _indicator_shader:unbind()

        love.graphics.pop()
    elseif priority == _label_priority then
        love.graphics.push()
        love.graphics.translate(
            self._time_label_offset_x,
            self._time_label_offset_y
        )
        self._time_label:draw()
        love.graphics.pop()
    end
end

--- @brief
function ow.Goal:draw_bloom()
    if not self._stage:get_is_body_visible(self._body) then return end
end

--- @brief
function ow.Goal:get_type()
    return self._type
end

--- @brief
function ow.Goal:reset()
    self._shatter_surface:reset()
end

--- @brief
function ow.Goal:get_render_priority()
    return _base_priority, _label_priority
end

--- @brief
function ow.Goal:get_segment_light_sources()
    return self._segment_lights, table.rep(self._color, #self._segment_lights)
end
