require "common.contour"
require "common.delaunay_triangulation"

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

        _rotation_origin_x = object.origin_x,
        _rotation_origin_y = object.origin_y,
        _angle = object.rotation,

        _is_single_use = object:get_string("single_use") or false,
        _is_destroyed = false
    })
    self._color = self._default_color
    self._draw_color = self._color

    self._body:add_tag("slippery", "no_blood", "unjumpable")
    local bounce_group = rt.settings.player.bounce_collision_group
    self._body:set_collides_with(bounce_group)
    self._body:set_collision_group(bounce_group)

    self._body:signal_connect("collision_start", function(_, other_body, nx, ny, cx, cy)
        if self._is_destroyed then return end

        if cx == nil then return end -- player is sensor

        local player = self._scene:get_player()
        local restitution = player:bounce(nx, ny)

        -- animation
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

    -- mesh
    self._mesh, self._tris = object:create_mesh()
    self:_create_contour()
    self:_update_vertices(false)
end

-- simulate ball-on-a-spring for bouncing animation
local stiffness = rt.settings.overworld.bounce_pad.stiffness
local origin = rt.settings.overworld.bounce_pad.origin
local damping = rt.settings.overworld.bounce_pad.damping
local magnitude = rt.settings.overworld.bounce_pad.magnitude
local color_duration = rt.settings.overworld.bounce_pad.color_decay_duration
local offset = rt.settings.overworld.bounce_pad.bounce_max_offset

--- @brief
function ow.BouncePad:update(delta)
    if self._is_destroyed then return end

    if not self._scene:get_is_body_visible(self._body) then return end

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
        self:_update_vertices(true)
    end
end

--- @brief
function ow.BouncePad:draw()
    if self._is_destroyed then return end

    if not self._scene:get_is_body_visible(self._body) then return end

    local r, g, b = table.unpack(self._draw_color)

    if self._draw_contour ~= nil then
        love.graphics.setColor(r, g, b, 0.7)
        for tri in values(self._draw_tris) do
            love.graphics.polygon("fill", tri)
        end

        love.graphics.setColor(r, g, b, 1.0)
        love.graphics.setLineWidth(1)
        love.graphics.setLineStyle("smooth")
        love.graphics.setLineJoin("bevel")
        love.graphics.line(self._draw_contour)
    end
end

local _round = function(x)
    return math.floor(x)
end

--- @param points Table<Number>
local function _round_contour(points, radius, samples_per_corner)
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

function ow.BouncePad:_create_contour()
    local contour = rt.contour_from_tris(self._tris)

    contour = _round_contour(contour, rt.settings.overworld.bounce_pad.corner_radius, 16)

    self._segments = {}
    for i = 1, #contour - 2, 2 do
        local x1, y1 = contour[i], contour[i+1]
        local x2, y2 = contour[i+2], contour[i+3]
        table.insert(self._segments, { x1, y1, x2, y2 })
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
    return math.sqrt(dist_x * dist_x + dist_y * dist_y) --, nearest_x, nearest_y
end

function ow.BouncePad:_update_vertices(first)
    local px, py = self._bounce_contact_x, self._bounce_contact_y

    -- apply rotation
    local offset_x, offset_y = self._body:get_position()
    local origin_x, origin_y, angle = self._rotation_origin_x + offset_x, self._rotation_origin_y + offset_y, self._angle + self._body:get_rotation()

    local center_x, center_y, n = 0, 0, 0
    local segments = {}
    for segment in values(self._segments) do
        local x1, y1, x2, y2 = table.unpack(segment)
        x1, y1 = math.rotate(x1, y1, angle, origin_x, origin_y)
        x2, y2 = math.rotate(x2, y2, angle, origin_x, origin_y)
        table.insert(segments, {x1, y1, x2, y2})

        center_x = center_x + (x1 + x2) / 2
        center_y = center_y + (y1 + y2) / 2
        n = n + 1
    end

    center_x, center_y = center_x / n, center_y / n

    local tris = {}
    for tri in values(self._tris) do
        local to_push = {}
        for i = 1, #tri, 2 do
            local x, y = tri[i], tri[i+1]
            for p in range(math.rotate(x, y, angle, origin_x, origin_y)) do
                table.insert(to_push, p)
            end
        end
        table.insert(tris, to_push)
    end

    -- find closest segment to bounce contact
    local segment_is_to_distance = {}
    local sorted_is = {}
    for i, segment in ipairs(segments) do
        segment_is_to_distance[i] = _point_to_segment_distance(px, py, table.unpack(segment))
        sorted_is[i] = i
    end

    table.sort(sorted_is, function(a, b)
        return segment_is_to_distance[a] < segment_is_to_distance[b]
    end)

    local cx1, cy1, cx2, cy2 = table.unpack(segments[sorted_is[1]])

    -- direction vector of the closest segment
    local dx, dy = cx2 - cx1, cy2 - cy1
    dx, dy = math.normalize(dx, dy)

    -- ensure direction is consistent: (dx, dy) should point such that the centroid is always on the same side
    local to_centroid_x, to_centroid_y = center_x - cx1, center_y - cy1
    if math.cross(dx, dy, to_centroid_x, to_centroid_y) < 0 then
        cx1, cy1, cx2, cy2 = cx2, cy2, cx1, cy1
        dx, dy = -dx, -dy
    end

    -- axis perpendicular to the segment direction
    local axis_x, axis_y = math.turn_right(dx, dy)

    -- get axis of scaling
    local magnitude = self._bounce_magnitude
    local scale = self._bounce_position
    axis_x = axis_x * scale * magnitude
    axis_y = axis_y * scale * magnitude

    local contour = {}
    for segment in values(segments) do
        local x1, y1, x2, y2 = table.unpack(segment)

        -- check if point is on side of player or opposite side of center line
        if math.cross(dx, dy, x1 - center_x, y1 - center_y) < 0 then
            x1 = x1 + axis_x
            y1 = y1 + axis_y
        end

        if math.cross(dx, dy, x2 - center_x, y2 - center_y) < 0 then
            x2 = x2 + axis_x
            y2 = y2 + axis_y
        end

        for p in range(x1, y1) do
            table.insert(contour, p)
        end
    end

    for p in range(contour[1], contour[2]) do
        table.insert(contour, p)
    end

    self._draw_contour = contour

    if self._triangulator == nil then self._triangulator = rt.DelaunayTriangulation() end
    self._triangulator:triangulate(contour, contour)
    self._draw_tris = self._triangulator:get_triangles()
end