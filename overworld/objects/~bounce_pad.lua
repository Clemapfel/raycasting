rt.settings.overworld.bounce_pad = {
    -- bounce animation
    bounce_max_offset = rt.settings.overworld.player.radius * 0.7, -- in px
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

local _link_segments = function(segments)
    local function points_equal(x1, y1, x2, y2)
        return math.abs(x1 - x2) < 1e-6 and math.abs(y1 - y2) < 1e-6
    end

    local ordered = {segments[1]}
    table.remove(segments, 1)

    while #segments > 0 do
        local last = ordered[#ordered]
        local x2, y2 = last[3], last[4]
        local found = false

        for i, segment in ipairs(segments) do
            local sx1, sy1, sx2, sy2 = segment[1], segment[2], segment[3], segment[4]
            if points_equal(x2, y2, sx1, sy1) then
                table.insert(ordered, segment)
                table.remove(segments, i)
                found = true
                break
            elseif points_equal(x2, y2, sx2, sy2) then
                -- Reverse the segment
                table.insert(ordered, {sx2, sy2, sx1, sy1})
                table.remove(segments, i)
                found = true
                break
            end
        end

        if not found then
            break -- no match found
        end
    end

    return ordered
end

--- @param points Table<Number>
local function round_contour(points, radius, samples_per_corner)
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

    -- filter so only outer segments remain
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

    local outline = {}
    for hash, count in pairs(tuples) do
        if count == 1 then
            table.insert(outline, _unhash(hash))
        end
    end

    -- link segments so they are ordered
    local function points_equal(x1, y1, x2, y2)
        return math.abs(x1 - x2) < 1e-6 and math.abs(y1 - y2) < 1e-6
    end

    -- link segments
    local ordered = {outline[1]}
    table.remove(outline, 1)

    while #outline > 0 do
        local last = ordered[#ordered]
        local x2, y2 = last[3], last[4]
        local found = false

        for i, segment in ipairs(outline) do
            local sx1, sy1, sx2, sy2 = segment[1], segment[2], segment[3], segment[4]
            if points_equal(x2, y2, sx1, sy1) then
                table.insert(ordered, segment)
                table.remove(outline, i)
                found = true
                break
            elseif points_equal(x2, y2, sx2, sy2) then
                -- Reverse the segment
                table.insert(ordered, {sx2, sy2, sx1, sy1})
                table.remove(outline, i)
                found = true
                break
            end
        end
    end

    outline = ordered

    -- construct contour
    local contour = {}
    for segment in values(outline) do
        table.insert(contour, segment[1])
        table.insert(contour, segment[2])
    end

    contour = round_contour(contour, rt.settings.overworld.bounce_pad.corner_radius, 16)

    -- Convert flat contour array to table of segments
    self._segments = {}

    do
        local n = #contour
        for i = 1, n - 2, 2 do
            local x1, y1 = contour[i], contour[i+1]
            local x2, y2 = contour[i+2], contour[i+3]
            table.insert(self._segments, {x1, y1, x2, y2})
        end

        -- Optionally close the loop if the contour is closed and not already closed
        if n >= 4 then
            local x_last, y_last = contour[n-1], contour[n]
            local x_first, y_first = contour[1], contour[2]
            -- Only add if not already closed
            if x_last ~= x_first or y_last ~= y_first then
                table.insert(self._segments, {x_last, y_last, x_first, y_first})
            end
        end
    end
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

    local success
    success, self._draw_tris = pcall(love.graphics.triangulate, contour)
    if not success then
        success, self._draw_tris = pcall(slick.triangulate, { contour })
    end
end



