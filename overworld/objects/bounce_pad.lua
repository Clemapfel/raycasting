rt.settings.overworld.bounce_pad = {
    -- bounce animation
    bounce_max_offset = rt.settings.player.radius * 0.7, -- in px
    bounce_min_magnitude = 10,
    color_decay_duration = 1,
    corner_radius = 10,

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
        _is_bouncing = true,
        _color_elapsed = math.huge,
        _default_color = { rt.Palette.BOUNCE_PAD:unpack() },
        _bounce_magnitude = 0,

        -- popping bubbles
        _is_single_use = object:get_string("single_use") or false,
        _is_destroyed = false
    })

    self._color = self._default_color
    self._draw_color = self._color

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
        self._color = { rt.lcha_to_rgba(0.9, 1, player:get_hue(), 1) }
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
    self._contour = self:_round_contour(
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
            [_axis_y_index] = 0,
            [_offset_index] = 0
        })
    end

    self._shape_mesh = rt.Mesh(
        shape_mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        shape_mesh_format,
        rt.GraphicsBufferUsage.STATIC
    )

    local triangulation = rt.DelaunayTriangulation(self._contour, self._contour):get_triangle_vertex_map()
    self._shape_mesh:set_vertex_map(triangulation)

    self._offset_mesh = rt.Mesh(
        offset_mesh_data,
        rt.MeshDrawMode.POINTS,
        offset_mesh_format,
        rt.GraphicsBufferUsage.DYNAMIC
    )
    self._shape_mesh:attach_attribute(self._offset_mesh, "axis_offset", "pervertex")

    self._draw_contour = table.deepcopy(self._contour)
end

function ow.BouncePad:_round_contour(points, radius, samples_per_corner)
    local n = math.floor(#points / 2)
    radius = radius or 10
    samples_per_corner = samples_per_corner or 5

    local new_points = {}

    for i = 1, n do
        local previous_idx = ((i - 2 + n) % n) + 1
        local current_idx = i
        local next_idx = (i % n) + 1

        local previous_x, previous_y = points[ 2 * previous_idx - 1], points[2 *previous_idx]
        local current_x, current_y = points[2 * current_idx - 1], points[2 * current_idx]
        local next_x, next_y = points[2 * next_idx-1], points[2 * next_idx]

        local v1x = current_x - previous_x
        local v1y = current_y - previous_y
        local v2x = next_x - current_x
        local v2y = next_y - current_y

        -- shorten current segment by corner radius
        local v1nx, v1ny = math.normalize(v1x, v1y)
        local v2nx, v2ny = math.normalize(v2x, v2y)
        local len1 = math.min(radius, math.magnitude(v1x, v1y) / 2)
        local len2 = math.min(radius, math.magnitude(v2x, v2y) / 2)

        local p1x = current_x + v1nx * -len1
        local p1y = current_y + v1ny * -len1
        local p2x = current_x + v2nx * len2
        local p2y = current_y + v2ny * len2

        -- resample bezier curve to replace missing vertices
        local curve = love.math.newBezierCurve({
            p1x, p1y,
            current_x, current_y,
            p2x, p2y
        })

        for s = 1, samples_per_corner do
            local t = s / samples_per_corner
            local x, y = curve:evaluate(t)
            table.insert(new_points, x)
            table.insert(new_points, y)
        end
    end

    -- close loop
    table.insert(new_points, new_points[1])
    table.insert(new_points, new_points[2])

    return new_points
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

    -- color animation
    if self._color_elapsed <= color_duration then
        self._color_elapsed = self._color_elapsed + delta

        local default_r, default_g, default_b = table.unpack(self._default_color)
        local target_r, target_g, target_b = table.unpack(self._color)
        local weight = rt.InterpolationFunctions.EXPONENTIAL_DECELERATION(math.min(self._color_elapsed / color_duration, 1))

        self._draw_color = {
            math.mix(default_r, target_r, weight),
            math.mix(default_g, target_g, weight),
            math.mix(default_b, target_b, weight),
            1
        }
    end
end

--- @brief
function ow.BouncePad:draw()
    if self._is_destroyed or not self._scene:get_is_body_visible(self._body) then return end
    local r, g, b = table.unpack(self._draw_color)

    love.graphics.setColor(r, g, b, 0.7)
    love.graphics.draw(self._shape_mesh:get_native())

    love.graphics.setColor(r, g, b, 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.setLineStyle("smooth")
    love.graphics.setLineJoin("bevel")
    love.graphics.line(self._draw_contour)
end