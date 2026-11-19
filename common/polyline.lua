--- @class rt.Polyline
rt.Polyline = meta.class("Polyline")

--- @enum rt.PolylineWinding
rt.PolylineWinding = {
    CLOCKWISE = true,
    COUNTERCLOCKWISE = false
}

-- distance below which first and last vertex count as the same point
local _closure_tolerance = 1

--- @brief
function rt.Polyline:instantiate(first, ...)
    local vertices
    if meta.is_table(first) then
        meta.typecheck(first, mt.Table, select(1, ...), mt.Nil)
        vertices = first
    else
        vertices = { first, ... }
        local n = select("#", ...)
        for i = 1, n do
            meta.typecheck_arg_i(select(i, ...), mt.Number, i + 1)
        end
    end

    rt.assert(#vertices % 2 == 0, "In rt.Polyline: number of vertices is not a multiple of 2")
    self.vertices = vertices
end

meta.get_instance_metatable(rt.Polyline, {
    __index = function(_, i)
        -- TODO
        rt.fatal("In rt.Polyline: trying to access index `", i, "`. Use get_vertex instead")
    end
})

--- @brief
function rt.Polyline:get_vertices()
    return self.vertices
end

--- @brief
function rt.Polyline:draw()
    love.graphics.line(self.vertices)
end

do
    local function collect(vertices, i, n, index, ...)
        local j = index * 2
        assert(
            type(index) == "number" and index >= 1 and j <= #vertices,
            "In rt.Polyline.at: index `" .. tostring(index) .. "` out of bounds for polyline with `" .. tostring(#vertices / 2) .. "` vertices"
        )

        if i == n then
            return vertices[j - 1], vertices[j]
        end
        return vertices[j - 1], vertices[j], collect(vertices, i + 1, n, ...)
    end

    --- @brief get node position component at index
    function rt.Polyline:get_vertex(...)
        local n = select("#", ...)
        if n == 0 then return end
        return collect(self.vertices, 1, n, ...)
    end
end

--- @brief
function rt.Polyline:set_vertices(first, ...)
    if meta.is_table(first) then
        meta.typecheck(first, mt.Table, select(1, ...), mt.Nil)
        self.vertices = first
    else
        meta.typecheck_arg_i(first, mt.Number, 1)
        for i = 1, select("#", ...) do
            meta.typecheck_arg_i(select(i, ...), mt.Number, i + 1)
        end
        self.vertices = { first, ... }
    end
    return self
end

--- @brief
function rt.Polyline:is_closed()
    local data = self.vertices
    local n = #data
    if n < 4 then return false end
    return math.distance(data[1], data[2], data[n - 1], data[n]) <= _closure_tolerance
end

--- @brief
function rt.Polyline:close()
    local data = self.vertices
    local n = #data
    if n < 4 then return self end

    local first_x, first_y = data[1], data[2]
    local last_x, last_y = data[n - 1], data[n]
    if math.distance(last_x, last_y, first_x, first_y) > _closure_tolerance then
        table.insert(data, first_x)
        table.insert(data, first_y)
    end
    return self
end

--- @brief
function rt.Polyline:get_n_vertices()
    local n = #self.vertices / 2
    if self:is_closed() then
        n = n - 1
    end
    return n
end

--- @brief
function rt.Polyline:get_vertex(index)
    meta.typecheck(index, mt.Number)

    local n = self:get_n_vertices()
    rt.assert(index >= 1 and index <= n, "In rt.Polyline.get_vertex: index out of range")

    local i = (index - 1) * 2 + 1
    local data = self.vertices
    return data[i + 0], data[i + 1]
end

--- @brief
function rt.Polyline:get_edge(index)
    meta.typecheck(index, mt.Number)

    local n = self:get_n_vertices()
    rt.assert(index >= 1 and index <= n, "In rt.Polyline.get_edge: index out of range")

    local next_index = index % n + 1 -- closed contour
    local ai = (index - 1) * 2 + 1
    local bi = (next_index - 1) * 2 + 1
    local data = self.vertices

    return data[ai + 0], data[ai + 1], data[bi + 0], data[bi + 1]
end

--- @brief
function rt.Polyline:translate(x, y)
    meta.typecheck(x, mt.Number, y, mt.Number)
    local data = self.vertices
    for i = 1, #data, 2 do
        data[i + 0] = data[i + 0] + x
        data[i + 1] = data[i + 1] + y
    end
    return self
end

--- @brief
function rt.Polyline:draw()
    local data = self.vertices
    local n = #data
    if n < 4 then return self end

    for i = 1, n - 2, 2 do
        love.graphics.line(data[i + 0], data[i + 1], data[i + 2], data[i + 3])
    end
    love.graphics.line(data[n - 1], data[n - 0], data[1], data[2])

    return self
end

local _hash = function(segment)
    local x1, y1, x2, y2 = math.floor(segment[1]), math.floor(segment[2]), math.floor(segment[3]), math.floor(segment[4])
    if x1 < x2 or (x1 == x2 and y1 < y2) then -- swap so point order does not matter
        x1, y1, x2, y2 = x2, y2, x1, y1
    end
    return tostring(x1) .. "," .. tostring(y1) .. "," .. tostring(x2) .. "," .. tostring(y2)
end

--- @brief
function rt.Polyline:create_from_tris(tris, close_loop)
    if close_loop == nil then close_loop = true end
    local segments = {}
    for tri in values(tris) do
        for segment in range(
            {tri[1], tri[2], tri[3], tri[4]},
            {tri[3], tri[4], tri[5], tri[6]},
            {tri[1], tri[2], tri[5], tri[6]}
        ) do
            table.insert(segments, segment)
        end
    end

    -- filter so only outer segments remain
    local hash_to_points = {}
    local tuples = {}
    for segment in values(segments) do
        local hash = _hash(segment)
        hash_to_points[hash] = segment
        tuples[hash] = (tuples[hash] or 0) + 1
    end

    local outline = {}
    for hash, count in pairs(tuples) do
        if count == 1 then
            table.insert(outline, hash_to_points[hash])
        end
    end

    if #outline == 0 then
        self.vertices = {}
        return self
    end

    -- link segments so they are ordered
    local function points_equal(x1, y1, x2, y2)
        return math.abs(x1 - x2) < 1e-6 and math.abs(y1 - y2) < 1e-6
    end

    local ordered = { outline[1] }
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
                -- reverse the segment
                table.insert(ordered, { sx2, sy2, sx1, sy1 })
                table.remove(outline, i)
                found = true
                break
            end
        end

        if not found then -- degenerate contour with duplicate segments
            rt.warning("In rt.Polyline.create_from_tris: contour has duplicate edges")
            break
        end
    end

    local vertices = {}
    for segment in values(ordered) do
        table.insert(vertices, segment[1])
        table.insert(vertices, segment[2])
    end

    self.vertices = vertices
    return self
end

--- @brief
--- @param segment_length Number
function rt.Polyline:subdivide(segment_length)
    meta.typecheck(segment_length, mt.Number)
    local contour = self.vertices
    local out = {}
    local remainder = 0

    for i = 1, #contour, 2 do
        local x1, y1 = contour[i], contour[i + 1]
        local next_i = (i + 2 > #contour) and 1 or i + 2
        local x2, y2 = contour[next_i], contour[next_i + 1]

        table.insert(out, x1)
        table.insert(out, y1)

        local dx, dy = x2 - x1, y2 - y1
        local edge_length = math.magnitude(dx, dy)
        local distance = segment_length - remainder

        while distance < edge_length do
            table.insert(out, x1 + (distance / edge_length) * dx)
            table.insert(out, y1 + (distance / edge_length) * dy)
            distance = distance + segment_length
        end

        remainder = edge_length - (distance - segment_length)
    end

    self.vertices = out
    return self
end

--- @brief
--- @param n_iterations Number
function rt.Polyline:smooth(n_iterations)
    n_iterations = n_iterations or 1
    local points = self.vertices
    for _ = 1, n_iterations do
        local smoothed = {}
        local count = #points
        for j = 1, count, 2 do
            local previous_j = ((j - 3) % count) + 1
            local next_j = ((j - 1 + 2) % count) + 1
            smoothed[#smoothed + 1] = (points[previous_j] + points[j] + points[next_j]) / 3
            smoothed[#smoothed + 1] = (points[previous_j + 1] + points[j + 1] + points[next_j + 1]) / 3
        end
        points = smoothed
    end

    self.vertices = points
    return self
end

--- @brief
function rt.Polyline:round(radius, samples_per_corner)
    local points = self.vertices
    local n = math.floor(#points / 2)
    if n < 2 then return self end

    radius = radius or 10

    -- interpret options
    local opts = {}
    if type(samples_per_corner) == "table" then
        opts = samples_per_corner
    elseif type(samples_per_corner) == "number" then
        -- larger samples_per_corner -> smaller error, clamped to avoid pathological values
        local q = math.max(1, samples_per_corner)
        opts.max_error = math.max(0.25, math.min(radius / (4 * q * q), radius * 0.25))
    end

    local max_error = opts.max_error or math.max(0.75, radius * 0.02)
    local min_segments = math.max(1, opts.min_segments or 1)
    local max_segments = math.max(min_segments, opts.max_segments or 64)
    local max_depth = opts.max_depth
    if not max_depth then
        -- 2^depth ~= max_segments
        max_depth = math.ceil(math.log(max_segments) / math.log(2))
    end
    local flatness2 = max_error * max_error

    local new_points = {}

    for i = 1, n do
        local previous_idx = ((i - 2 + n) % n) + 1
        local current_idx = i
        local next_idx = (i % n) + 1

        local previous_x, previous_y = points[2 * previous_idx - 1], points[2 * previous_idx]
        local current_x, current_y   = points[2 * current_idx - 1], points[2 * current_idx]
        local next_x, next_y         = points[2 * next_idx - 1], points[2 * next_idx]

        local v1x, v1y = current_x - previous_x, current_y - previous_y
        local v2x, v2y = next_x - current_x, next_y - current_y

        -- shorten current segments by corner radius
        local v1nx, v1ny = math.normalize(v1x, v1y)
        local v2nx, v2ny = math.normalize(v2x, v2y)
        local len1 = math.min(radius, math.magnitude(v1x, v1y) / 2)
        local len2 = math.min(radius, math.magnitude(v2x, v2y) / 2)

        local p1x = current_x - v1nx * len1
        local p1y = current_y - v1ny * len1
        local p2x = current_x + v2nx * len2
        local p2y = current_y + v2ny * len2

        -- adaptive sampling of the quadratic Bezier curve (p1 -> current as control -> p2)
        local before_len = #new_points

        -- stack-based iterative traversal to avoid recursion
        local stack = { { p1x, p1y, current_x, current_y, p2x, p2y, 0 } }

        while #stack > 0 do
            local entry = table.remove(stack)
            local ax, ay, cx, cy, bx, by, depth = entry[1], entry[2], entry[3], entry[4], entry[5], entry[6], entry[7]

            if depth >= max_depth then -- prevent runaway subdivision
                new_points[#new_points + 1] = bx
                new_points[#new_points + 1] = by
            else
                -- squared distance from control point C to infinite line AB
                local abx, aby = bx - ax, by - ay
                local acx, acy = cx - ax, cy - ay
                local ab2 = math.dot(abx, aby, abx, aby)

                local is_flat
                if ab2 < math.eps then
                    is_flat = true -- degenerate chord
                else
                    local cross = math.cross(acx, acy, abx, aby)
                    is_flat = (cross * cross) / ab2 <= flatness2
                end

                if is_flat then
                    new_points[#new_points + 1] = bx
                    new_points[#new_points + 1] = by
                else
                    -- De Casteljau split at t=0.5
                    local q0x, q0y = 0.5 * (ax + cx), 0.5 * (ay + cy)
                    local q1x, q1y = 0.5 * (cx + bx), 0.5 * (cy + by)
                    local rx, ry   = 0.5 * (q0x + q1x), 0.5 * (q0y + q1y)

                    -- push right curve first (processed last)
                    stack[#stack + 1] = { rx, ry, q1x, q1y, bx, by, depth + 1 }
                    -- push left curve (processed first)
                    stack[#stack + 1] = { ax, ay, q0x, q0y, rx, ry, depth + 1 }
                end
            end
        end

        local added_points = math.floor((#new_points - before_len) / 2)

        -- guarantee a minimum number of segments if requested
        if min_segments > 1 and added_points < min_segments then
            local to_add = min_segments - added_points
            for k = 1, to_add do
                local t = k / min_segments
                local it = 1 - t
                new_points[#new_points + 1] = it * it * p1x + 2 * it * t * current_x + t * t * p2x
                new_points[#new_points + 1] = it * it * p1y + 2 * it * t * current_y + t * t * p2y
            end
        end
    end

    -- close the contour
    if #new_points >= 2 then
        new_points[#new_points + 1] = new_points[1]
        new_points[#new_points + 1] = new_points[2]
    end

    self.vertices = new_points
    return self
end

--- @brief
--- @return Table<Number>
function rt.Polyline:get_normals()
    local contour = self.vertices
    local normals = {}

    local turn_func = (self:get_signed_area() < 0) and math.turn_right or math.turn_left
    for i = 1, #contour, 2 do
        local x1, y1 = contour[i], contour[i + 1]

        local prev_i = (i - 2 < 1) and (#contour - 1) or (i - 2)
        local x0, y0 = contour[prev_i], contour[prev_i + 1]

        local next_i = (i + 2 > #contour) and 1 or (i + 2)
        local x2, y2 = contour[next_i], contour[next_i + 1]

        -- tangent is the average of incoming and outgoing directions
        local tx, ty = math.normalize((x1 - x0) + (x2 - x1), (y1 - y0) + (y2 - y1))

        -- rotate tangent by 90 degrees
        local nx, ny = turn_func(tx, ty)

        table.insert(normals, nx)
        table.insert(normals, ny)
    end

    return normals
end

--- @brief
function rt.Polyline:get_centroid()
    local data = self.vertices
    local x, y, n = 0, 0, 0
    for i = 1, #data, 2 do
        x = x + data[i + 0]
        y = y + data[i + 1]
        n = n + 1
    end

    return x / n, y / n
end

--- @brief
function rt.Polyline:get_circumcircle()
    local vertices = self.vertices
    local cx, cy = self:get_centroid()

    local max_distance = -math.huge
    for i = 1, #vertices, 2 do
        max_distance = math.max(max_distance, math.distance(cx, cy, vertices[i + 0], vertices[i + 1]))
    end

    return cx, cy, max_distance
end

--- @brief
function rt.Polyline:get_center_of_mass()
    local vertices = self.vertices
    local n = self:get_n_vertices()

    local rx, ry = vertices[1], vertices[2]
    local cross_sum = 0
    local cx, cy = 0, 0
    local far_magnitude, far_x, far_y = 0, 0, 0

    for i = 1, n do
        local j = i % n + 1
        local ai = (i - 1) * 2 + 1
        local bi = (j - 1) * 2 + 1
        local ax, ay = vertices[ai + 0] - rx, vertices[ai + 1] - ry
        local bx, by = vertices[bi + 0] - rx, vertices[bi + 1] - ry

        local cross = math.cross(ax, ay, bx, by)
        cross_sum = cross_sum + cross
        cx = cx + (ax + bx) * cross
        cy = cy + (ay + by) * cross

        local dist = math.dot(ax, ay, ax, ay)
        if dist > far_magnitude then
            far_magnitude, far_x, far_y = dist, ax, ay
        end
    end

    if far_magnitude < math.eps * math.eps then
        return rx, ry
    end

    if math.abs(cross_sum) <= math.eps * far_magnitude then
        -- degenerate (collinear) polygon, use midpoint of extent along its axis
        local dir_x, dir_y = math.normalize(far_x, far_y)

        local min_t, max_t = math.huge, -math.huge
        for i = 1, n do
            local vi = (i - 1) * 2 + 1
            local t = math.dot(vertices[vi + 0] - rx, vertices[vi + 1] - ry, dir_x, dir_y)
            if t < min_t then min_t = t end
            if t > max_t then max_t = t end
        end

        local mid = (min_t + max_t) * 0.5
        return rx + dir_x * mid, ry + dir_y * mid
    end

    local factor = 1 / (3 * cross_sum)
    return rx + cx * factor, ry + cy * factor
end

--- @brief
function rt.Polyline:get_signed_area()
    local vertices = self.vertices
    local n = self:get_n_vertices()

    local area = 0
    for i = 1, n do
        local next_i = i % n + 1
        local ai = (i - 1) * 2 + 1
        local bi = (next_i - 1) * 2 + 1
        area = area + 0.5 * math.cross(vertices[ai + 0], vertices[ai + 1], vertices[bi + 0], vertices[bi + 1])
    end

    return area
end

--- @brief
function rt.Polyline:get_winding()
    if self:get_signed_area() >= 0 then
        return rt.PolylineWinding.CLOCKWISE
    else
        return rt.PolylineWinding.COUNTERCLOCKWISE
    end
end

--- @brief make sure the polyline has the given winding, reversing if needed
--- @param winding rt.PolylineWinding
function rt.Polyline:set_winding(winding)
    local area = self:get_signed_area()
    if area == 0 then return self end -- degenerate, no meaningful winding

    if self:get_winding() ~= winding then
        self:reverse()
    end
    return self
end

--- @brief reverse vertex order in place, flips the winding
function rt.Polyline:reverse()
    local data = self.vertices
    local n = #data / 2
    for i = 1, math.floor(n / 2) do
        local a = (i - 1) * 2 + 1
        local b = (n - i) * 2 + 1
        data[a + 0], data[b + 0] = data[b + 0], data[a + 0]
        data[a + 1], data[b + 1] = data[b + 1], data[a + 1]
    end
    return self
end

--- @brief
function rt.Polyline:get_aabb()
    local vertices = self.vertices
    local n = #vertices
    if n < 4 then return rt.AABB(0, 0, 0, 0) end

    local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge

    for i = 1, n, 2 do
        local x, y = vertices[i], vertices[i + 1]
        if x < min_x then min_x = x end
        if y < min_y then min_y = y end
        if x > max_x then max_x = x end
        if y > max_y then max_y = y end
    end

    return rt.AABB(min_x, min_y, max_x - min_x, max_y - min_y)
end

--- @brief
function rt.Polyline:is_convex()
    local vertices = self.vertices
    local n = #vertices / 2
    if n < 3 then
        return false
    end

    local sign = nil

    for i = 0, n - 1 do
        local curr_idx = i * 2 + 1
        local next_idx = ((i + 1) % n) * 2 + 1
        local prev_idx = ((i - 1 + n) % n) * 2 + 1

        local curr_x, curr_y = vertices[curr_idx], vertices[curr_idx + 1]
        local next_x, next_y = vertices[next_idx], vertices[next_idx + 1]
        local prev_x, prev_y = vertices[prev_idx], vertices[prev_idx + 1]

        local cross_product = math.cross(
            curr_x - prev_x, curr_y - prev_y,
            next_x - curr_x, next_y - curr_y
        )

        if math.abs(cross_product) > math.eps then
            local current_sign = cross_product > 0 and 1 or -1

            if sign == nil then
                sign = current_sign
            elseif sign ~= current_sign then
                return false
            end
        end
    end

    return true
end

--- @brief
function rt.Polyline:contains(point_x, point_y)
    meta.typecheck(point_x, mt.Number, point_y, mt.Number)
    local contour = self.vertices
    local crossings = 0
    local count = #contour

    for i = 1, count, 2 do
        local ax, ay = contour[i], contour[i + 1]
        local bx, by = contour[(i + 1) % count + 1], contour[(i + 2) % count + 1]

        if (ay <= point_y and by > point_y) or (by <= point_y and ay > point_y) then
            if point_x < ax + (point_y - ay) / (by - ay) * (bx - ax) then
                crossings = crossings + 1
            end
        end
    end

    return math.is_odd(crossings)
end

--- @brief
function rt.Polyline:test_point(px, py)
    meta.typecheck(px, mt.Number, py, mt.Number)

    local data = self.vertices
    local n = self:get_n_vertices()

    local last = (n - 1) * 2 + 1
    local ax, ay = data[last + 0], data[last + 1]
    local winding = 0

    for i = 1, n * 2, 2 do
        local bx, by = data[i + 0], data[i + 1]
        local side = math.cross(bx - ax, by - ay, px - ax, py - ay)

        if ay <= py then
            if by > py and side > 0 then -- upward crossing
                winding = winding + 1
            end
        elseif by <= py and side < 0 then -- downward crossing
            winding = winding - 1
        end

        ax, ay = bx, by
    end

    return winding ~= 0
end

--- @brief
function rt.Polyline:test_circle(px, py, pr)
    meta.typecheck(px, mt.Number, py, mt.Number, pr, mt.Number)

    local vertices = self.vertices
    local n = self:get_n_vertices()
    local radius_sq = pr * pr
    local indices = {}
    local distances = {}

    for i = 1, n do
        local j = i % n + 1
        local ai = (i - 1) * 2 + 1
        local bi = (j - 1) * 2 + 1
        local ax, ay = vertices[ai + 0], vertices[ai + 1]
        local bx, by = vertices[bi + 0], vertices[bi + 1]
        local dx, dy = bx - ax, by - ay
        local length_sq = math.dot(dx, dy, dx, dy)

        local t = 0
        if length_sq > 0 then
            t = math.clamp(math.dot(px - ax, py - ay, dx, dy) / length_sq, 0, 1)
        end

        local ox, oy = px - (ax + dx * t), py - (ay + dy * t)
        local distance_sq = math.dot(ox, oy, ox, oy)
        if distance_sq <= radius_sq then
            table.insert(indices, i)
            distances[i] = distance_sq
        end
    end

    table.sort(indices, function(a, b)
        return distances[a] < distances[b]
    end)

    return indices
end

--- @brief
function rt.Polyline:test_segment(origin_x, origin_y, direction_x, direction_y)
    meta.typecheck(
        origin_x, mt.Number, origin_y, mt.Number,
        direction_x, mt.Number, direction_y, mt.Number
    )

    local vertices = self.vertices
    local n = self:get_n_vertices()
    local indices = {}
    local distances = {}

    local eps = math.eps
    local direction_length_sq = math.dot(direction_x, direction_y, direction_x, direction_y)
    local direction_length = math.magnitude(direction_x, direction_y)

    rt.assert(direction_length > eps, "In rt.Polyline.test_segment: segment has length 0")
    local parameter_eps = eps / direction_length

    for i = 1, n do
        local j = i % n + 1
        local ai = (i - 1) * 2 + 1
        local bi = (j - 1) * 2 + 1
        local ax, ay = vertices[ai], vertices[ai + 1]
        local bx, by = vertices[bi], vertices[bi + 1]
        local edge_x, edge_y = bx - ax, by - ay
        local edge_length_sq = math.dot(edge_x, edge_y, edge_x, edge_y)
        local offset_x, offset_y = ax - origin_x, ay - origin_y
        local t
        local overlaps = false

        if edge_length_sq >= eps * eps then -- disregard degenerate segments
            local edge_length = math.magnitude(edge_x, edge_y)
            local denominator = math.cross(direction_x, direction_y, edge_x, edge_y)

            if math.abs(denominator) > eps * direction_length * edge_length then
                -- non-parallel
                t = math.cross(offset_x, offset_y, edge_x, edge_y) / denominator
                local u = math.cross(offset_x, offset_y, direction_x, direction_y) / denominator
                local edge_parameter_eps = eps / edge_length
                overlaps = t >= -parameter_eps and t <= 1 + parameter_eps
                    and u >= -edge_parameter_eps and u <= 1 + edge_parameter_eps
            else
                -- parallel, only hits if collinear
                local collinear_cross = math.cross(offset_x, offset_y, direction_x, direction_y)
                if math.abs(collinear_cross) <= eps * direction_length then
                    local t0 = math.dot(offset_x, offset_y, direction_x, direction_y) / direction_length_sq
                    local t1 = math.dot(bx - origin_x, by - origin_y, direction_x, direction_y) / direction_length_sq
                    local overlap_start = math.max(0, math.min(t0, t1))
                    local overlap_end = math.min(1, math.max(t0, t1))

                    if overlap_start <= overlap_end + parameter_eps then
                        t = math.clamp(overlap_start, 0, 1)
                        overlaps = true
                    end
                end
            end
        end

        if overlaps then
            table.insert(indices, i)
            distances[i] = math.clamp(t, 0, 1)
        end
    end

    table.sort(indices, function(a, b)
        if distances[a] == distances[b] then
            return a < b
        end
        return distances[a] < distances[b]
    end)

    return indices
end

--- @brief
function rt.Polyline:cast_ray(x, y, dx, dy)
    meta.typecheck(x, mt.Number, y, mt.Number, dx, mt.Number, dy, mt.Number)

    local vertices = self.vertices
    local n = self:get_n_vertices()

    local eps = math.eps
    local direction_length_sq = math.dot(dx, dy, dx, dy)
    local direction_length = math.magnitude(dx, dy)

    rt.assert(direction_length > eps, "In rt.Polyline.cast_ray: ray has length 0")
    local parameter_eps = eps / direction_length

    local min_t = math.huge

    for i = 1, n do
        local j = i % n + 1
        local ai = (i - 1) * 2 + 1
        local bi = (j - 1) * 2 + 1
        local ax, ay = vertices[ai], vertices[ai + 1]
        local bx, by = vertices[bi], vertices[bi + 1]
        local edge_x, edge_y = bx - ax, by - ay
        local edge_length_sq = math.dot(edge_x, edge_y, edge_x, edge_y)
        local offset_x, offset_y = ax - x, ay - y

        if edge_length_sq >= eps * eps then
            local edge_length = math.magnitude(edge_x, edge_y)
            local denominator = math.cross(dx, dy, edge_x, edge_y)

            if math.abs(denominator) > eps * direction_length * edge_length then
                -- non-parallel
                local t = math.cross(offset_x, offset_y, edge_x, edge_y) / denominator
                local u = math.cross(offset_x, offset_y, dx, dy) / denominator
                local edge_parameter_eps = eps / edge_length

                if t >= -parameter_eps and t <= 1 + parameter_eps
                    and u >= -edge_parameter_eps and u <= 1 + edge_parameter_eps then
                    t = math.clamp(t, 0, 1)
                    if t < min_t then min_t = t end
                end
            else
                -- parallel, only hits if collinear
                local collinear_cross = math.cross(offset_x, offset_y, dx, dy)
                if math.abs(collinear_cross) <= eps * direction_length then
                    local t0 = math.dot(offset_x, offset_y, dx, dy) / direction_length_sq
                    local t1 = math.dot(bx - x, by - y, dx, dy) / direction_length_sq
                    local overlap_start = math.max(0, math.min(t0, t1))
                    local overlap_end = math.min(1, math.max(t0, t1))

                    if overlap_start <= overlap_end + parameter_eps then
                        local t = math.clamp(overlap_start, 0, 1)
                        if t < min_t then min_t = t end
                    end
                end
            end
        end
    end

    if min_t == math.huge then
        return nil, nil
    end

    return x + dx * min_t, y + dy * min_t
end

--[[
function rt.Polyline:distribute_circles(polygon_tris, circle_i_to_radius)
    local N = #circle_i_to_radius
    if N == 0 then return {} end
    if polygon_tris == nil or #polygon_tris == 0 then return {} end

    local sqrt, abs, max, min, floor = math.sqrt, math.abs, math.max, math.min, math.floor
    local random = (love and love.math and love.math.random) or math.random
    local distance, cross, mix = math.distance, math.cross, math.mix
    local EPS = math.eps or 1e-9
    local SQRT3 = sqrt(3.0)

    local tri_count = #polygon_tris
    local tri_areas = {}
    local total_area = 0.0
    local minx, miny = 1/0, 1/0
    local maxx, maxy = -1/0, -1/0

    local tri_basis = {}
    tri_basis[6 * tri_count] = nil

    for i = 1, tri_count do
        local t = polygon_tris[i]
        local ax, ay, bx, by, cx, cy = t[1], t[2], t[3], t[4], t[5], t[6]
        local abx, aby = bx - ax, by - ay
        local acx, acy = cx - ax, cy - ay
        local area = 0.5 * abs(cross(abx, aby, acx, acy))
        tri_areas[i] = area
        total_area = total_area + area

        local base = (i - 1) * 6
        tri_basis[base + 1] = ax
        tri_basis[base + 2] = ay
        tri_basis[base + 3] = abx
        tri_basis[base + 4] = aby
        tri_basis[base + 5] = acx
        tri_basis[base + 6] = acy

        -- bbox accumulation
        local tminx = min(ax, min(bx, cx))
        local tmaxx = max(ax, max(bx, cx))
        local tminy = min(ay, min(by, cy))
        local tmaxy = max(ay, max(by, cy))
        if tminx < minx then minx = tminx end
        if tmaxx > maxx then maxx = tmaxx end
        if tminy < miny then miny = tminy end
        if tmaxy > maxy then maxy = tmaxy end
    end
    if total_area <= EPS then
        return {}
    end

    local prob = {}
    local alias = {}
    prob[tri_count] = nil
    alias[tri_count] = nil

    do
        local scaled = {}
        scaled[tri_count] = nil
        local inv_total = 1.0 / total_area
        for i = 1, tri_count do
            scaled[i] = tri_areas[i] * inv_total * tri_count
        end

        local small, large = {}, {}
        for i = 1, tri_count do
            if scaled[i] < 1.0 then
                small[#small+1] = i
            else
                large[#large+1] = i
            end
        end
        while #small > 0 and #large > 0 do
            local l = small[#small]; small[#small] = nil
            local g = large[#large]; large[#large] = nil
            prob[l] = scaled[l]
            alias[l] = g
            scaled[g] = (scaled[g] + scaled[l]) - 1.0
            if scaled[g] < 1.0 then
                small[#small+1] = g
            else
                large[#large+1] = g
            end
        end
        while #large > 0 do
            local g = large[#large]; large[#large] = nil
            prob[g] = 1.0
            alias[g] = g
        end
        while #small > 0 do
            local l = small[#small]; small[#small] = nil
            prob[l] = 1.0
            alias[l] = l
        end
    end

    local function sample_triangle_index()
        local r = random() * tri_count
        local k = floor(r) + 1
        local frac = r - floor(r)
        if frac < prob[k] then
            return k
        else
            return alias[k]
        end
    end

    local function sample_point_in_polygon()
        local tri_index = sample_triangle_index()
        local u = random()
        local v = random()
        if (u + v) > 1.0 then
            u = 1.0 - u
            v = 1.0 - v
        end
        local base = (tri_index - 1) * 6
        local ax = tri_basis[base + 1]
        local ay = tri_basis[base + 2]
        local abx = tri_basis[base + 3]
        local aby = tri_basis[base + 4]
        local acx = tri_basis[base + 5]
        local acy = tri_basis[base + 6]
        local px = ax + u * abx + v * acx
        local py = ay + u * aby + v * acy
        return px, py
    end

    -- Initial centers: triangular lattice inside polygon.
    -- Lattice spacing 'a' estimated from polygon area and number of circles.
    local a = sqrt((2.0 * total_area) / (SQRT3 * N))
    a = a * 0.95
    local h = a * (SQRT3 * 0.5)

    -- Point-in-triangle for lattice filtering (triangles tessellate the polygon)
    local function point_in_triangle(px, py, ax, ay, bx, by, cx, cy)
        local c1 = cross(bx - ax, by - ay, px - ax, py - ay)
        local c2 = cross(cx - bx, cy - by, px - bx, py - by)
        local c3 = cross(ax - cx, ay - cy, px - cx, py - cy)
        local has_neg = (c1 < -EPS) or (c2 < -EPS) or (c3 < -EPS)
        local has_pos = (c1 > EPS) or (c2 > EPS) or (c3 > EPS)
        return not (has_neg and has_pos)
    end

    local tri_bbox = {}
    tri_bbox[4 * tri_count] = nil
    do
        for i = 1, tri_count do
            local t = polygon_tris[i]
            local ax, ay, bx, by, cx, cy = t[1], t[2], t[3], t[4], t[5], t[6]
            local tminx = min(ax, min(bx, cx))
            local tmaxx = max(ax, max(bx, cx))
            local tminy = min(ay, min(by, cy))
            local tmaxy = max(ay, max(by, cy))
            local base = (i - 1) * 4
            tri_bbox[base + 1] = tminx
            tri_bbox[base + 2] = tmaxx
            tri_bbox[base + 3] = tminy
            tri_bbox[base + 4] = tmaxy
        end
    end

    local function point_in_polygon(px, py)
        for i = 1, tri_count do
            local bb = (i - 1) * 4
            local tminx = tri_bbox[bb + 1]
            local tmaxx = tri_bbox[bb + 2]
            local tminy = tri_bbox[bb + 3]
            local tmaxy = tri_bbox[bb + 4]
            if px >= tminx and px <= tmaxx and py >= tminy and py <= tmaxy then
                local t = polygon_tris[i]
                if point_in_triangle(px, py, t[1], t[2], t[3], t[4], t[5], t[6]) then
                    return true
                end
            end
        end
        return false
    end

    local candidates = {}
    local row = 0
    local y = miny - h
    local y_end = maxy + h
    while y <= y_end do
        local x_offset = ((row % 2) ~= 0) and (a * 0.5) or 0.0
        local x = (minx - a) + x_offset
        local x_end = maxx + a
        while x <= x_end do
            if point_in_polygon(x, y) then
                candidates[#candidates+1] = x
                candidates[#candidates+1] = y
            end
            x = x + a
        end
        row = row + 1
        y = y + h
    end

    local need = N - floor(#candidates / 2)
    if need > 0 then
        for _ = 1, need do
            local sx, sy = sample_point_in_polygon()
            candidates[#candidates+1] = sx
            candidates[#candidates+1] = sy
        end
    end

    local cand_pairs = floor(#candidates / 2)
    for i = cand_pairs, 2, -1 do
        local j = 1 + floor(random() * i)
        local ia = (i - 1) * 2 + 1
        local ja = (j - 1) * 2 + 1
        candidates[ia], candidates[ja] = candidates[ja], candidates[ia]
        candidates[ia+1], candidates[ja+1] = candidates[ja+1], candidates[ia+1]
    end

    local centers = {}
    centers[2 * N] = nil
    for i = 1, N do
        local ci = (i - 1) * 2 + 1
        local si = (i - 1) * 2 + 1
        centers[ci] = candidates[si]
        centers[ci+1] = candidates[si+1]
    end

    local n_lloyd_iterations = 4
    local alpha = 0.5
    local radii = circle_i_to_radius
    local tiny = EPS

    local sums = {}
    local counts = {}
    sums[2 * N] = nil
    counts[N] = nil

    local cell = a
    if cell < EPS then cell = 1.0 end
    local inv_cell = 1.0 / cell
    local grid_w = max(1, floor((maxx - minx) * inv_cell) + 1)
    local grid_h = max(1, floor((maxy - miny) * inv_cell) + 1)
    local grid_size = grid_w * grid_h
    local grid = {}
    local center_cell_ix = {}

    local function cell_index(ix, iy)
        return iy * grid_w + ix + 1
    end

    local function clampi(v, lo, hi)
        if v < lo then return lo end
        if v > hi then return hi end
        return v
    end

    local function rebuild_grid()
        for i = 1, grid_size do grid[i] = nil end
        for i = 1, N do
            local ci = (i - 1) * 2 + 1
            local x = centers[ci]
            local y = centers[ci+1]
            local ix = clampi(floor((x - minx) * inv_cell), 0, grid_w - 1)
            local iy = clampi(floor((y - miny) * inv_cell), 0, grid_h - 1)
            local gi = cell_index(ix, iy)
            local bucket = grid[gi]
            if bucket == nil then
                bucket = {}
                grid[gi] = bucket
            end
            bucket[#bucket+1] = i
            center_cell_ix[i] = gi
        end
    end

    local function nearest_center_scaled(sx, sy)
        local ix = clampi(floor((sx - minx) * inv_cell), 0, grid_w - 1)
        local iy = clampi(floor((sy - miny) * inv_cell), 0, grid_h - 1)

        local best_i = nil
        local best_d = 1/0

        local r = 0
        local maxR = max(grid_w, grid_h)
        while r <= maxR do
            local found_any = false
            local xmin = clampi(ix - r, 0, grid_w - 1)
            local xmax = clampi(ix + r, 0, grid_w - 1)
            local ymin = clampi(iy - r, 0, grid_h - 1)
            local ymax = clampi(iy + r, 0, grid_h - 1)

            for yy = ymin, ymax do
                for xx = xmin, xmax do
                    local gi = cell_index(xx, yy)
                    local bucket = grid[gi]
                    if bucket ~= nil then
                        found_any = true
                        for k = 1, #bucket do
                            local idx = bucket[k]
                            local ci = (idx - 1) * 2 + 1
                            local cx = centers[ci]
                            local cy = centers[ci+1]
                            local denom = max(radii[idx], tiny)
                            local d = distance(sx, sy, cx, cy) / denom
                            if d < best_d then
                                best_d = d
                                best_i = idx
                            end
                        end
                    end
                end
            end

            if found_any and best_i ~= nil then
                break
            end
            r = r + 1
        end

        if best_i == nil then
            best_i = 1
            local ci = 1
            local denom = max(radii[1], tiny)
            best_d = distance(sx, sy, centers[ci], centers[ci+1]) / denom
            for i = 2, N do
                ci = (i - 1) * 2 + 1
                local d = distance(sx, sy, centers[ci], centers[ci+1]) / max(radii[i], tiny)
                if d < best_d then
                    best_d = d
                    best_i = i
                end
            end
        end

        return best_i
    end

    local function lloyd_iteration()
        for i = 1, 2 * N do sums[i] = 0.0 end
        for i = 1, N do counts[i] = 0 end

        rebuild_grid()

        local M = min(max(12 * N, 400), 12000)

        for _ = 1, M do
            local sx, sy = sample_point_in_polygon()
            local best_i = nearest_center_scaled(sx, sy)

            local bi = (best_i - 1) * 2 + 1
            sums[bi] = sums[bi] + sx
            sums[bi + 1] = sums[bi + 1] + sy
            counts[best_i] = counts[best_i] + 1
        end

        for i = 1, N do
            local c = counts[i]
            local ci = (i - 1) * 2 + 1
            if c > 0 then
                local meanx = sums[ci] / c
                local meany = sums[ci + 1] / c
                local ox = centers[ci]
                local oy = centers[ci + 1]
                centers[ci] = mix(ox, meanx, alpha)
                centers[ci + 1] = mix(oy, meany, alpha)
            else
                local rx, ry = sample_point_in_polygon()
                centers[ci] = rx
                centers[ci + 1] = ry
            end
        end
    end

    for _ = 1, n_lloyd_iterations do
        lloyd_iteration()
    end

    return centers
end

require "common.common"

--- Remove collinear points from a flat array of coordinates {x1, y1, x2, y2, ...}
--- Multiple contours are separated by `nil` values.
--- @param flat_points table (flat array)
--- @param closed boolean (true if the contours are closed, false if open)
--- @return table (flat array with collinear points removed)
local function dissolve_colinear_points(flat_points, closed)
    local function is_colinear(ax, ay, bx, by, cx, cy)
        local cross_product = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
        return math.abs(cross_product) < 1e-6
    end

    local result = {}
    local contour = {}

    for i = 1, #flat_points, 2 do
        local x, y = flat_points[i], flat_points[i + 1]
        if x == nil or y == nil then
            -- Process the current contour
            if #contour > 0 then
                local n = math.floor(#contour / 2)
                local processed_contour = {}

                for j = 1, n do
                    local ax, ay = contour[(j - 1) * 2 + 1], contour[(j - 1) * 2 + 2]
                    local bx, by = contour[(j % n) * 2 + 1], contour[(j % n) * 2 + 2]
                    local cx, cy = contour[(j + 1) % n * 2 + 1], contour[(j + 1) % n * 2 + 2]

                    if not is_colinear(ax, ay, bx, by, cx, cy) then
                        table.insert(processed_contour, bx)
                        table.insert(processed_contour, by)
                    end
                end

                for _, v in ipairs(processed_contour) do
                    table.insert(result, v)
                end
                table.insert(result, nil) -- Add delimiter for the next contour
            end

            -- Reset contour for the next segment
            contour = {}
        else
            table.insert(contour, x)
            table.insert(contour, y)
        end
    end

    -- Process the last contour if it exists
    if #contour > 0 then
        local n = math.floor(#contour / 2)
        local processed_contour = {}

        for j = 1, n do
            local ax, ay = contour[(j - 1) * 2 + 1], contour[(j - 1) * 2 + 2]
            local bx, by = contour[(j % n) * 2 + 1], contour[(j % n) * 2 + 2]
            local cx, cy = contour[(j + 1) % n * 2 + 1], contour[(j + 1) % n * 2 + 2]

            if not is_colinear(ax, ay, bx, by, cx, cy) then
                table.insert(processed_contour, bx)
                table.insert(processed_contour, by)
            end
        end

        for _, v in ipairs(processed_contour) do
            table.insert(result, v)
        end
    end

    return result
end

--- @brief
-- Extracts all contours from a binary image using the marching squares algorithm.
-- Returns a flat list of 2D points (all contours concatenated).
-- @param canvas love.graphics.Canvas
-- @return table of {x, y} points (flat list)
function rt.contour.from_canvas(canvas)
    local data = love.graphics.readbackTexture(canvas:get_native())
    local width, height = data:getWidth(), data:getHeight()

    local function get_pixel(x, y)
        -- Out of bounds is always off (false)
        if x < 0 or y < 0 or x >= width or y >= height then
            return false
        end
        return data:getPixel(x, y) > 1 / 32
    end

    -- Visited edges: visited[x+1][y+1][dir+1] = true
    -- dir: 0=left, 1=top, 2=right, 3=bottom (edge leaving (x, y))
    local visited = {}
    for x = 0, width do
        visited[x+1] = {}
        for y = 0, height do
            visited[x+1][y+1] = {false, false, false, false}
        end
    end

    local edge_moves = {
        [0] = {dx=0, dy=0, nx=0, ny=-1, nd=3}, -- left
        [1] = {dx=1, dy=0, nx=1, ny=0, nd=2},  -- top
        [2] = {dx=1, dy=1, nx=0, ny=1, nd=0},  -- right
        [3] = {dx=0, dy=1, nx=0, ny=0, nd=1},  -- bottom
    }

    local next_edge = {
        [1]  = {[3]=0, [0]=3},
        [2]  = {[0]=1, [1]=0},
        [3]  = {[3]=1, [1]=3},
        [4]  = {[1]=2, [2]=1},
        [5]  = {[3]=2, [2]=3, [1]=0, [0]=1},
        [6]  = {[0]=2, [2]=0},
        [7]  = {[3]=2, [2]=3, [1]=2},
        [8]  = {[2]=3, [3]=2},
        [9]  = {[1]=3, [3]=1},
        [10] = {[0]=2, [2]=0, [1]=3, [3]=1},
        [11] = {[1]=2, [2]=1, [3]=1},
        [12] = {[0]=1, [1]=0, [2]=1},
        [13] = {[0]=3, [3]=0, [1]=3},
        [14] = {[0]=1, [1]=0, [2]=0},
    }

    local function get_case(x, y)
        local c0 = get_pixel(x, y) and 1 or 0
        local c1 = get_pixel(x+1, y) and 1 or 0
        local c2 = get_pixel(x+1, y+1) and 1 or 0
        local c3 = get_pixel(x, y+1) and 1 or 0
        return c0 + 2*c1 + 4*c2 + 8*c3
    end

    local flat_points = {}
    local function trace_contour(sx, sy, sdir)
        local x, y, dir = sx, sy, sdir
        local first = true
        while true do
            visited[x+1][y+1][dir+1] = true

            local px, py
            if dir == 0 then
                px, py = x, y + 0.5
            elseif dir == 1 then
                px, py = x + 0.5, y
            elseif dir == 2 then
                px, py = x + 1, y + 0.5
            elseif dir == 3 then
                px, py = x + 0.5, y + 1
            end
            table.insert(flat_points, px)
            table.insert(flat_points, py)

            local case = get_case(x, y)
            if case == 0 or case == 15 then
                break
            end

            local outgoing = next_edge[case] and next_edge[case][dir]
            if outgoing == nil then
                break
            end

            local move = edge_moves[outgoing]
            local nx = x + move.nx
            local ny = y + move.ny
            local ndir = move.nd

            if not first and nx == sx and ny == sy and ndir == sdir then
                break
            end

            if visited[nx+1] and visited[nx+1][ny+1] and visited[nx+1][ny+1][ndir+1] then
                break
            end

            x, y, dir = nx, ny, ndir
            first = false
        end
    end

    for y = 0, height-1 do
        for x = 0, width-1 do
            local case = get_case(x, y)
            if case ~= 0 and case ~= 15 then
                for dir = 0, 3 do
                    if not visited[x+1][y+1][dir+1] then
                        trace_contour(x, y, dir)
                    end
                end
            end
        end
    end

    flat_points = dissolve_colinear_points(flat_points, true)

    require "common.delaunay_triangulation"
    return rt.DelaunayTriangulation(flat_points, flat_points):get_triangles()
end
]]
