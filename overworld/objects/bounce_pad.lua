require "common.contour"

rt.settings.overworld.bounce_pad = {
    line_width = 5,
    respawn_duration = 6, -- seconds
    dashed_contour_segment_length = 12, -- px

    -- bounce animation
    bounce_max_offset = rt.settings.player.radius * 0.7, -- in px
    bounce_min_magnitude = 10,

    outer_color_decay_duration = 1,
    inner_color_decay_duration = 2.5,
    corner_radius = 20,
    bounce_penetration_fraction = 1, -- times radius, the larger, the more of the shape will wiggle

    -- bounce animation simulation parameters
    stiffness = 10,
    damping = 0.95,
    origin = 0,
    magnitude = 100,
}

--- @class ow.BouncePad
--- @types Polygon, Rectangle, Ellipse
--- @field is_single_use Boolean? whether pad pops after being hit
--- @field respawn_duration Number? if single use, how long to respawn
ow.BouncePad = meta.class("BouncePad", rt.Drawable)

local _x_index = 1
local _y_index = 2
local _axis_x_index = 1
local _axis_y_index = 2
local _offset_index = 3

local _shape_shader = rt.Shader("overworld/objects/bounce_pad.glsl")

--- @brief
function ow.BouncePad:instantiate(object, stage, scene)
    meta.install(self, {
        _scene = scene,
        _stage = stage,
        _body = object:create_physics_body(stage:get_physics_world()),

        -- spring simulation
        _bounce_position = rt.settings.overworld.bounce_pad.origin, -- in [0, 1]
        _bounce_velocity = 0,
        _bounce_contact_x = 0,
        _bounce_contact_y = 0,
        _bounce_normal_x = 0,
        _bounce_normal_y = 0,
        _is_bouncing = true,
        _color_elapsed = math.huge,
        _default_color = { rt.Palette.BOUNCE_PAD:unpack() },
        _bounce_magnitude = 0,

        _signal_elapsed = 0,
        _signal = 0
    })

    self._draw_inner_color = { rt.Palette.BOUNCE_PAD:unpack() }
    self._draw_outer_color = { rt.Palette.BOUNCE_PAD:unpack() }
    self._hue = self._scene:get_player():get_hue()

    -- collision
    self._body:add_tag("slippery", "no_blood", "unjumpable", "stencil")

    local bounce_group = rt.settings.player.bounce_collision_group
    self._body:set_collides_with(bounce_group)
    self._body:set_collision_group(bounce_group)

    self._body:signal_connect("collision_start", function(_, other_body, nx, ny, cx, cy)
        local player = self._scene:get_player()
        local restitution = player:bounce(nx, ny)

        -- color animation
        self._hue = player:get_hue()

        self._color_elapsed = 0
        self._is_bouncing = true
        self._bounce_velocity = restitution
        self._bounce_position = restitution
        self._bounce_contact_x, self._bounce_contact_y = cx, cy
        self._bounce_normal_x, self._bounce_normal_y = nx, ny
        self._bounce_magnitude = math.max(rt.settings.overworld.bounce_pad.bounce_max_offset * restitution, rt.settings.overworld.bounce_pad.bounce_min_magnitude)
    end)

    -- contour
    self._contour = rt.round_contour(
        object:create_contour(),
        rt.settings.overworld.bounce_pad.corner_radius,
        16
    )

    local shape_mesh_format = {
        {location = rt.VertexAttributeLocation.POSITION, name = rt.VertexAttribute.POSITION, format = "floatvec2"},
    }

    local offset_mesh_format = {
        {location = 3, name = "axis_offset", format = "floatvec3"}, -- xy axis, z offset (absolute)
    }

    local shape_mesh_data = {}
    local offset_mesh_data = {}
    for i = 1, #self._contour, 2 do
        local x, y = self._contour[i+0], self._contour[i+1]
        table.insert(shape_mesh_data, {
            [_x_index] = x,
            [_y_index] = y
        })

        table.insert(offset_mesh_data, {
            [_axis_x_index] = 0,
            [_axis_y_index] = 1,
            [_offset_index] = 0
        })
    end

    self._shape_mesh_data = shape_mesh_data
    self._shape_mesh = rt.Mesh(
        shape_mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        shape_mesh_format,
        rt.GraphicsBufferUsage.STATIC
    )

    local triangulation = rt.DelaunayTriangulation(self._contour, self._contour):get_triangle_vertex_map()
    self._shape_mesh:set_vertex_map(triangulation)

    self._offset_mesh_data = offset_mesh_data
    self._offset_mesh = rt.Mesh(
        offset_mesh_data,
        rt.MeshDrawMode.POINTS,
        offset_mesh_format,
        rt.GraphicsBufferUsage.STREAM
    )

    self._shape_mesh:attach_attribute(self._offset_mesh, "axis_offset", "pervertex")

    self._draw_contour = {}
    for i = 1, #self._contour, 2 do
        local x, y = self._contour[i+0], self._contour[i+1]
        table.insert(self._draw_contour, x)
        table.insert(self._draw_contour, y)
    end

    self._rotation_origin_x = object.rotation_origin_x
    self._rotation_origin_y = object.rotation_origin_y
end

local stiffness = rt.settings.overworld.bounce_pad.stiffness
local origin = rt.settings.overworld.bounce_pad.origin
local damping = rt.settings.overworld.bounce_pad.damping
local magnitude = rt.settings.overworld.bounce_pad.magnitude
local color_duration = rt.settings.overworld.bounce_pad.color_decay_duration
local offset = rt.settings.overworld.bounce_pad.bounce_max_offset

--- @brief
function ow.BouncePad:update(delta)
    if not self._stage:get_is_body_visible(self._body) then return end

    if self._is_single_use and math.equals(self._pop_motion:get_value(), 0) then return end

    self._signal_elapsed = self._signal_elapsed + delta
    self._signal_elapsed = self._signal_elapsed + self._signal

    -- color animation
    self._color_elapsed = self._color_elapsed + delta
    self._signal = rt.InterpolationFunctions.EXPONENTIAL_DECELERATION(math.min(self._color_elapsed / rt.settings.overworld.bounce_pad.outer_color_decay_duration, 1))
    local player = self._scene:get_player()

    local base_r, base_g, base_b = rt.Palette.BOUNCE_PAD:unpack()
    local target_r, target_g, target_b = rt.lcha_to_rgba(0.8, 1, self._hue, 1)
    local outer_fraction = self._signal
    self._draw_outer_color = { math.mix3(
        target_r, target_g, target_b,
        base_r, base_g, base_b,
        1 - math.clamp(outer_fraction, 0, 1)
    )}

    local inner_fraction = self._color_elapsed / rt.settings.overworld.bounce_pad.inner_color_decay_duration
    target_r, target_g, target_b = rt.lcha_to_rgba(0.9, 0.9, self._hue, 1)
    self._draw_inner_color = { math.mix3(
        target_r, target_g, target_b,
        base_r, base_g, base_b,
        math.clamp(inner_fraction, 0, 1)
    )}

    -- bounce
    if self._is_bouncing and not rt.GameState:get_is_performance_mode_enabled() then
        local before = self._bounce_position
        self._bounce_velocity = self._bounce_velocity + -1 * (self._bounce_position - origin) * stiffness
        self._bounce_velocity = self._bounce_velocity * damping
        self._bounce_position = self._bounce_position + self._bounce_velocity * delta

        if math.abs(self._bounce_position - before) * offset < 1 / love.graphics.getWidth() then -- more than 1 px change
            self._bounce_position = 0
            self._bounce_velocity = 0
            self._is_bouncing = false
        end
        self:_update_vertices()
    end
end

--- @brief
function ow.BouncePad:_update_vertices()
    -- get compression axis
    local axis_x, axis_y = self._bounce_normal_x, self._bounce_normal_y

    -- define line through center of the shape
    local line_dx, line_dy = math.turn_left(axis_x, axis_y)
    local line_origin_x, line_origin_y = self._body:get_position()

    local function get_sign(test_x, test_y)
        return math.sign(math.cross(line_dx, line_dy, test_x - line_origin_x, test_y - line_origin_y))
    end

    -- find all vertices on the same side of the line as player, compress only them
    local player_x, player_y = self._scene:get_player():get_position()
    local player_sign = get_sign(player_x, player_y)

    local scale_offset = self._bounce_position * self._bounce_magnitude
    local data_i = 1
    for i = 1, #self._contour, 2 do
        local contour_x, contour_y = self._contour[i+0], self._contour[i+1]

        local data = self._offset_mesh_data[data_i]
        data[_axis_x_index] = axis_x
        data[_axis_y_index] = axis_y

        if get_sign(contour_x, contour_y) == player_sign then
            self._draw_contour[i+0] = contour_x + axis_x * scale_offset
            self._draw_contour[i+1] = contour_y + axis_y * scale_offset
            data[_offset_index] = scale_offset;
        else
            self._draw_contour[i+0] = contour_x
            self._draw_contour[i+1] = contour_y
            data[_offset_index] = 0;
        end

        data_i = data_i + 1
    end

    self._offset_mesh:replace_data(self._offset_mesh_data)
end

--- @brief
function ow.BouncePad:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    local opacity = 1

    local r, g, b = table.unpack(self._draw_inner_color)
    love.graphics.setColor(r, g, b, opacity)
    _shape_shader:bind()
    _shape_shader:send("elapsed", self._signal_elapsed)
    _shape_shader:send("axis", { math.flip(self._bounce_normal_x, self._bounce_normal_y) })
    _shape_shader:send("signal", self._signal)
    _shape_shader:send("camera_offset", { self._scene:get_camera():get_offset() })
    _shape_shader:send("camera_scale", self._scene:get_camera():get_final_scale())
    love.graphics.draw(self._shape_mesh:get_native())
    _shape_shader:unbind()

    local line_width = rt.settings.overworld.bounce_pad.line_width
    love.graphics.setLineWidth(line_width)
    love.graphics.setLineJoin("bevel")

    local r, g, b = rt.Palette.BLACK:unpack()
    love.graphics.setColor(r, g, b, opacity)
    love.graphics.line(self._draw_contour)

    local r, g, b = table.unpack(self._draw_outer_color)
    love.graphics.setColor(r, g, b, opacity)
    love.graphics.setLineWidth(line_width - 2)
    love.graphics.line(self._draw_contour)
end

--- @brief
function ow.BouncePad:reset()
    self._bounce_velocity = 0
    self._bounce_position = 0
    self._is_bouncing = false
end