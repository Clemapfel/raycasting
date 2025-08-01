require "common.contour"

rt.settings.overworld.bounce_pad = {
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
ow.BouncePad = meta.class("BouncePad", rt.Drawable)

local _x_index = 1
local _y_index = 2
local _axis_x_index = 1
local _axis_y_index = 2
local _offset_index = 3

local _shape_shader

--- @brief
function ow.BouncePad:instantiate(object, stage, scene)
    if _shape_shader == nil then _shape_shader = rt.Shader("overworld/objects/bounce_pad.glsl") end

    meta.install(self, {
        _scene = scene,
        _stage = stage,
        _body = object:create_physics_body(stage:get_physics_world()),

        -- spring simulation
        _bounce_position = rt.settings.overworld.bounce_pad.origin, -- in [0, 1]
        _bounce_velocity = 0,
        _bounce_contact_x = 0,
        _bounce_contact_y = 0,
        _is_bouncing = true,
        _color_elapsed = math.huge,
        _default_color = { rt.Palette.BOUNCE_PAD:unpack() },
        _bounce_magnitude = 0,

        -- popping bubbles
        _is_single_use = object:get_string("single_use") or false,
        _is_destroyed = false,

        _elapsed = 0,
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
        if self._is_destroyed or cx == nil then return end -- popped, or player is sensor

        local player = self._scene:get_player()
        local restitution = player:bounce(nx, ny)

        -- color animation
        self._hue = player:get_hue()

        self._color_elapsed = 0

        self._bounce_velocity = restitution
        self._bounce_position = restitution
        self._bounce_contact_x, self._bounce_contact_y = cx, cy
        self._bounce_magnitude = math.max(rt.settings.overworld.bounce_pad.bounce_max_offset * restitution, rt.settings.overworld.bounce_pad.bounce_min_magnitude)
        self._is_bouncing = true

        if self._is_single_use then
            self._is_destroyed = true
            self._body:set_is_enabled(false)
        end
    end)

    self._stage:signal_connect("respawn", function()
        self._is_destroyed = false
        self._body:set_is_enabled(true)
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
        rt.GraphicsBufferUsage.DYNAMIC
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
    if self._is_destroyed or not self._scene:get_is_body_visible(self._body) then return end

    self._elapsed = self._elapsed + delta
    self._elapsed = self._elapsed + self._signal

    -- color animation
    self._color_elapsed = self._color_elapsed + delta
    self._signal = rt.InterpolationFunctions.EXPONENTIAL_DECELERATION(math.min(self._color_elapsed / rt.settings.overworld.bounce_pad.outer_color_decay_duration, 1))
    local player = self._scene:get_player()

    local base_r, base_g, base_b = rt.Palette.BOUNCE_PAD:unpack()
    local target_r, target_g, target_b = rt.lcha_to_rgba(0.8, 1, self._hue, 1)
    local fraction = self._signal
    self._draw_outer_color = { math.mix3(
        target_r, target_g, target_b,
        base_r, base_g, base_b,
        1 - math.clamp(fraction, 0, 1)
    )}

    local fraction = self._color_elapsed / rt.settings.overworld.bounce_pad.inner_color_decay_duration
    target_r, target_g, target_b = rt.lcha_to_rgba(0.9, 0.9, self._hue, 1)
    self._draw_inner_color = { math.mix3(
        target_r, target_g, target_b,
        base_r, base_g, base_b,
        math.clamp(fraction, 0, 1)
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

local function _point_to_segment_distance(px, py, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local length_sq = dx * dx + dy * dy

    local t = ((px - x1) * dx + (py - y1) * dy) / length_sq
    t = math.max(0, math.min(1, t))

    local nearest_x = x1 + t * dx
    local nearest_y = y1 + t * dy

    local dist_x = px - nearest_x
    local dist_y = py - nearest_y
    return math.sqrt(dist_x * dist_x + dist_y * dist_y), nearest_x, nearest_y
end

--- @brief
--- @brief
function ow.BouncePad:_update_vertices()
    local px, py = self._bounce_contact_x, self._bounce_contact_y

    local contour = self._contour
    if self._body:get_rotation() ~= 0 then
        contour = {}
        local angle = self._body:get_rotation()
        for i = 1, #self._contour, 2 do
            local x, y = self._contour[i+0], self._contour[i+1]
            x, y = math.rotate(x, y, angle, self._rotation_origin_x, self._rotation_origin_y)
            contour[i+0] = x
            contour[i+1] = y
        end
    end

    local offset_x, offset_y = self._body:get_position()
    px = px - offset_x -- TODO: is this correct?
    py = py - offset_y

    -- find closest segment to contact
    local min_distance, min_distance_i, min_contact_x, min_contact_y = math.huge, 1, 0, 0
    for i = 1, #contour - 2, 2 do
        local distance, mx, my = _point_to_segment_distance(
            px, py,
            contour[i+0], contour[i+1],
            contour[i+2], contour[i+3]
        )

        if distance < min_distance then
            min_distance = distance
            min_distance_i = i
            min_contact_x = mx
            min_contact_y = my
        end
    end

    local cx1, cy1, cx2, cy2 =
    contour[min_distance_i+0],
    contour[min_distance_i+1],
    contour[min_distance_i+2],
    contour[min_distance_i+3]

    -- vector from contact point on segment to player contact point
    local vx, vy = px - min_contact_x, py - min_contact_y
    vx, vy = math.normalize(vx, vy)

    -- segment direction and normal
    local dx, dy = math.normalize(cx2 - cx1, cy2 - cy1)
    -- normal to the segment (right-hand normal)
    local nx, ny = math.turn_right(dx, dy)

    -- Ensure (vx, vy) points into the segment (same direction as normal)
    local dot = vx * nx + vy * ny
    if dot < 0 then
        vx, vy = -vx, -vy
    end

    -- extend 1 radius further into the shape, use that as threshold
    local radius = self._scene:get_player():get_radius() * rt.settings.overworld.bounce_pad.bounce_penetration_fraction
    local center_x, center_y = min_contact_x + vx * (min_distance + radius), min_contact_y + vy * (min_distance + radius)

    -- what side of that line is the contact on?
    local player_sign = math.sign(math.cross(dx, dy, px - center_x, py - center_y))

    -- axis of scaling
    local scale_axis_x, scale_axis_y = math.turn_right(dx, dy)

    local scale_offset = self._bounce_position * self._bounce_magnitude
    local data_i = 1
    for i = 1, #contour, 2 do
        local x1, y1 = contour[i+0], contour[i+1]

        local data = self._offset_mesh_data[data_i]
        data[_axis_x_index] = scale_axis_x
        data[_axis_y_index] = scale_axis_y

        -- check if point is on side of player, if yes, should bounce, otherwise static
        if math.sign(math.cross(dx, dy, x1 - center_x, y1 - center_y)) == player_sign then
            data[_offset_index] = scale_offset

            self._draw_contour[i+0] = contour[i+0] + scale_axis_x * scale_offset
            self._draw_contour[i+1] = contour[i+1] + scale_axis_y * scale_offset
        else
            data[_offset_index] = 0
            self._draw_contour[i+0] = contour[i+0]
            self._draw_contour[i+1] = contour[i+1]
        end

        data_i = data_i + 1
    end

    self._offset_mesh:replace_data(self._offset_mesh_data)
end

--- @brief
function ow.BouncePad:draw()
    if self._is_destroyed or not self._scene:get_is_body_visible(self._body) then return end

    local r, g, b = table.unpack(self._draw_inner_color)
    love.graphics.setColor(r, g, b, 1)
    _shape_shader:bind()
    _shape_shader:send("elapsed", self._elapsed)
    _shape_shader:send("signal", self._signal)
    _shape_shader:send("camera_offset", { self._scene:get_camera():get_offset() })
    _shape_shader:send("camera_scale", self._scene:get_camera():get_scale())
    love.graphics.draw(self._shape_mesh:get_native())
    _shape_shader:unbind()

    love.graphics.setLineWidth(7)
    love.graphics.setLineStyle("smooth")
    love.graphics.setLineJoin("bevel")
    rt.Palette.BLACK:bind()
    love.graphics.line(self._draw_contour)
    local r, g, b = table.unpack(self._draw_outer_color)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(7-2)
    love.graphics.line(self._draw_contour)
end