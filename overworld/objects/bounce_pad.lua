rt.settings.overworld.bounce_pad = {
    -- bounce animation
    bounce_max_offset = rt.settings.overworld.player.radius * 0.7, -- in px
    color_decay_duration = 1,

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
        _angle = object.rotation
    })
    self._color = self._default_color
    self._draw_color = self._color

    self._body:add_tag("slippery", "no_blood", "unjumpable")
    local bounce_group = rt.settings.overworld.player.bounce_collision_group
    self._body:set_collides_with(bounce_group)
    self._body:set_collision_group(bounce_group)

    self._body:signal_connect("collision_start", function(_, other_body, nx, ny, cx, cy)
        if cx == nil then return end -- player is sensor

        local player = self._scene:get_player()
        local restitution = player:bounce(nx, ny)

        -- animation
        self._color = { rt.lcha_to_rgba(0.9, 1, player:get_hue(), 1) }
        self._color_elapsed = 0

        self._bounce_velocity = restitution
        self._bounce_position = restitution
        self._bounce_contact_x, self._bounce_contact_y = cx, cy
        self._bounce_magnitude = rt.settings.overworld.bounce_pad.bounce_max_offset * restitution
        self._is_bouncing = true
    end)

    -- mesh
    self._mesh, self._tris = object:create_mesh()
    self:_create_contour()
end

local _round = function(x)
    return math.floor(x)
end

local _hash_to_points = {}

local _hash = function(points)
    local x1, y1, x2, y2 = _round(points[1]), _round(points[2]), _round(points[3]), _round(points[4])
    if x1 < x2 or (x1 == x2 and y1 < y2) then -- swap so point order does not matter
        x1, y1, x2, y2 = x2, y2, x1, y1
    end
    local hash = tostring(x1) .. "," .. tostring(y1) .. "," .. tostring(x2) .. "," .. tostring(y2)
    _hash_to_points[hash] = points
    return hash
end

local _unhash = function(hash)
    return _hash_to_points[hash]
end

function ow.BouncePad:_create_contour()
    local segments = {}
    for tri in values(self._tris) do
        for segment in range(
            {tri[1], tri[2], tri[3], tri[4]},
            {tri[3], tri[4], tri[5], tri[6]},
            {tri[1], tri[2], tri[5], tri[6]}
        ) do
            table.insert(segments, segment)
        end
    end

    local tuples = {}
    local n_total = 0
    for segment in values(segments) do
        local hash = _hash(segment)
        local current = tuples[hash]
        if current == nil then
            tuples[hash] = 1
        else
            tuples[hash] = current + 1
        end
        n_total = n_total + 1
    end

    local contour = {}
    for hash, count in pairs(tuples) do
        if count == 1 then
            table.insert(contour, _unhash(hash))
        end
    end

    self._segments = contour
end

function _point_to_segment_distance(px, py, x1, y1, x2, y2)
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

-- Example usage in bounce pad mesh update:
-- local rounded_polyline = round_polyline_corners(segments, 8, 8)
-- Now use rounded_polyline to build new segments and tris as needed.

function ow.BouncePad:_update_vertices()
    local px, py = self._bounce_contact_x, self._bounce_contact_y

    -- rotation precomputed
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

    -- deep copy transformed vertices
    self._draw_segments = {}
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

        table.insert(self._draw_segments, {
            x1, y1, x2, y2
        })
    end

    self._draw_tris = {}
    for tri in values(tris) do
        local to_push = {}
        for i = 1, #tri, 2 do
            local x, y = tri[i], tri[i+1]

            if math.cross(dx, dy, x - center_x, y - center_y) < 0 then
                x = x + axis_x
                y = y + axis_y
            end

            table.insert(to_push, x)
            table.insert(to_push, y)
        end
        table.insert(self._draw_tris, to_push)
    end
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

    if self._is_bouncing then
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
function ow.BouncePad:draw()
    if not self._scene:get_is_body_visible(self._body) then return end

    local r, g, b = table.unpack(self._draw_color)

    love.graphics.setColor(r, g, b, 0.7)
    for tri in values(self._draw_tris) do
        love.graphics.polygon("fill", tri)
    end

    love.graphics.setColor(r, g, b, 1.0)
    love.graphics.setLineWidth(1)
    for line in values(self._draw_segments) do
        love.graphics.line(line)
    end
end