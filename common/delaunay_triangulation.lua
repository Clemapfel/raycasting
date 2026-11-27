require "common.meta"

rt.DelaunayTriangulation = meta.class("DelaunayTriangulation")

local EPSILON = 1e-10
local EDGE_BUFFER_SIZE = 512
local EMPTY_TABLE = {}
local DEGENERATE_COORDS = { 0, 0, 0, 0, 0, 0 }

local _set_degenerate_state
local _update

function rt.DelaunayTriangulation:instantiate(points, contour)
    if contour == nil then contour = points end

    if points ~= nil then
        self:triangulate(points, contour)
    else
        self._coords = DEGENERATE_COORDS
        self._constraints = EMPTY_TABLE
        _set_degenerate_state(self)
    end
end

local function _swap(buffer, offset, i, j)
    local i_index = offset + i
    local j_index = offset + j
    local tmp = buffer[i_index]
    buffer[i_index] = buffer[j_index]
    buffer[j_index] = tmp
end

local function _quicksort(buffer, ids_offset, distances_offset, left, right)
    if right - left <= 20 then
        for i = left + 1, right do
            local id_index = ids_offset + i
            local temp = buffer[id_index]
            local temp_distance = buffer[distances_offset + temp]
            local j = i - 1
            while j >= left and buffer[distances_offset + buffer[ids_offset + j]] > temp_distance do
                buffer[ids_offset + j + 1] = buffer[ids_offset + j]
                j = j - 1
            end
            buffer[ids_offset + j + 1] = temp
        end
    else
        local median = math.floor((left + right) / 2)
        local i = left + 1
        local j = right
        _swap(buffer, ids_offset, median, i)
        if buffer[distances_offset + buffer[ids_offset + left]] > buffer[distances_offset + buffer[ids_offset + right]] then
            _swap(buffer, ids_offset, left, right)
        end
        if buffer[distances_offset + buffer[ids_offset + i]] > buffer[distances_offset + buffer[ids_offset + right]] then
            _swap(buffer, ids_offset, i, right)
        end
        if buffer[distances_offset + buffer[ids_offset + left]] > buffer[distances_offset + buffer[ids_offset + i]] then
            _swap(buffer, ids_offset, left, i)
        end

        local temp = buffer[ids_offset + i]
        local temp_distance = buffer[distances_offset + temp]
        while true do
            repeat i = i + 1 until not (buffer[distances_offset + buffer[ids_offset + i]] < temp_distance)
            repeat j = j - 1 until not (buffer[distances_offset + buffer[ids_offset + j]] > temp_distance)
            if j < i then break end
            _swap(buffer, ids_offset, i, j)
        end
        buffer[ids_offset + left + 1] = buffer[ids_offset + j]
        buffer[ids_offset + j] = temp

        if right - i + 1 >= j - left then
            _quicksort(buffer, ids_offset, distances_offset, i, right)
            _quicksort(buffer, ids_offset, distances_offset, left, j - 1)
        else
            _quicksort(buffer, ids_offset, distances_offset, left, j - 1)
            _quicksort(buffer, ids_offset, distances_offset, i, right)
        end
    end
end

local function _get_circumcenter(ax, ay, bx, by, cx, cy)
    local dx = bx - ax
    local dy = by - ay
    local ex = cx - ax
    local ey = cy - ay

    local bl = dx * dx + dy * dy
    local cl = ex * ex + ey * ey
    local d = 0.5 / (dx * ey - dy * ex)

    local x = ax + (ey * bl - dy * cl) * d
    local y = ay + (dx * cl - ex * bl) * d

    return x, y
end

local function _get_circumradius(ax, ay, bx, by, cx, cy)
    local dx = bx - ax
    local dy = by - ay
    local ex = cx - ax
    local ey = cy - ay

    local bl = dx * dx + dy * dy
    local cl = ex * ex + ey * ey
    local d = 0.5 / (dx * ey - dy * ex)

    local x = (ey * bl - dy * cl) * d
    local y = (dx * cl - ex * bl) * d

    return x * x + y * y
end

local function _is_point_in_circumcircle(ax, ay, bx, by, cx, cy, px, py)
    local dx = ax - px
    local dy = ay - py
    local ex = bx - px
    local ey = by - py
    local fx = cx - px
    local fy = cy - py

    local ap = dx * dx + dy * dy
    local bp = ex * ex + ey * ey
    local cp = fx * fx + fy * fy

    return dx * (ey * cp - bp * fy) -
        dy * (ex * cp - bp * fx) +
        ap * (ex * fy - ey * fx) < 0
end

local function _distance(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

local function _angle(dx, dy)
    local magnitude = math.abs(dx) + math.abs(dy)
    if magnitude == 0 then return 0 end

    local p = dx / magnitude
    if dy < 0 then
        return (3 - p) / 4
    else
        return (1 + p) / 4
    end
end

local function _get_signed_area(ax, ay, bx, by, cx, cy)
    return -1 * ((bx - ax) * (cy - ay) - (by - ay) * (cx - ax))
end

local function _is_finite_number(value)
    return value == value and value ~= math.huge and value ~= -math.huge
end

local function _has_nonzero_area(coords)
    if coords == nil or #coords < 6 or #coords % 2 ~= 0 then return false end

    local n = math.floor(#coords / 2)
    for i = 1, #coords do
        if not _is_finite_number(coords[i]) then return false end
    end

    local ax, ay = coords[1], coords[2]
    local bx, by
    for i = 2, n do
        local x, y = coords[2 * i - 1], coords[2 * i]
        if x ~= ax or y ~= ay then
            bx, by = x, y
            break
        end
    end
    if bx == nil then return false end

    for i = 2, n do
        local cx, cy = coords[2 * i - 1], coords[2 * i]
        local cross = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
        if cross ~= 0 then return true end
    end

    return false
end

local function _has_nonzero_contour_area(contour)
    if contour == nil or #contour < 6 or #contour % 2 ~= 0 then return false end

    local n = math.floor(#contour / 2)
    local twice_area = 0
    for i = 1, n do
        local j = (i % n) + 1
        local x1, y1 = contour[2 * i - 1], contour[2 * i]
        local x2, y2 = contour[2 * j - 1], contour[2 * j]
        if not _is_finite_number(x1) or not _is_finite_number(y1) then return false end
        twice_area = twice_area + x1 * y2 - x2 * y1
    end

    return _is_finite_number(twice_area) and twice_area ~= 0
end

if table.new == nil then require("table.new") end

local function _new_array(n)
    local out = table.new(n, 1)
    for i = 1, n do
        out[i] = 0
    end
    return out
end

local function _sizeof(t)
    return #t
end

local function _ensure_workspace(self, n)
    if n < 3 then n = 3 end

    local capacity = self._capacity_points or 0
    if capacity < n or self._buffer == nil then
        capacity = n
        self._capacity_points = capacity

        local triangle_capacity = math.max(2 * capacity - 5, 1) * 3
        local hash_capacity = math.ceil(math.sqrt(capacity))
        local offset = 0

        self._triangles_offset = offset
        offset = offset + triangle_capacity
        self._half_edges_offset = offset
        offset = offset + triangle_capacity
        self._hull_offset = offset
        offset = offset + capacity
        self._hull_previous_offset = offset
        offset = offset + capacity
        self._hull_next_offset = offset
        offset = offset + capacity
        self._hull_tri_offset = offset
        offset = offset + capacity
        self._hull_hash_offset = offset
        offset = offset + hash_capacity
        self._ids_offset = offset
        offset = offset + capacity
        self._distances_offset = offset
        offset = offset + capacity
        self._triangle_capacity = triangle_capacity
        self._hash_capacity = hash_capacity
        self._buffer = _new_array(offset)
    end

    -- Keep legalization scratch storage separate so it can grow safely if a
    -- pathological point set creates a deeper flip stack than expected.
    if self._edge_stack == nil then
        self._edge_buffer_capacity = EDGE_BUFFER_SIZE
        self._edge_stack = table.new(self._edge_buffer_capacity, 1)
    end

    self._hashSize = math.ceil(math.sqrt(n))
    self._current_n_points = n
end

_set_degenerate_state = function(self)
    -- A degenerate triangulation is genuinely empty.  The old fallback wrote
    -- a synthetic (1, 2, 3) triangle at the origin, which became visible as a
    -- disconnected triangle and also made empty results look non-empty.
    _ensure_workspace(self, 3)

    if self._coords == nil then
        self._coords = DEGENERATE_COORDS
    end

    self._n_triangles = 0
    self._hull_size = 0
    self._hull_start = 0
    self._center_x = 0
    self._center_y = 0
end

local function _is_point_on_segment(px, py, ax, ay, bx, by)
    local dx = bx - ax
    local dy = by - ay
    local cross = (px - ax) * dy - (py - ay) * dx
    local cross_scale = math.abs((px - ax) * dy) + math.abs((py - ay) * dx)
    if math.abs(cross) > EPSILON * math.max(1, cross_scale) then return false end

    -- Midpoints on decimal-valued edges can miss exact collinearity by a
    -- few ULPs. Use a coordinate-scaled bound for the segment extents too.
    local coordinate_epsilon = EPSILON * math.max(1, math.abs(ax), math.abs(ay), math.abs(bx), math.abs(by))
    return px >= math.min(ax, bx) - coordinate_epsilon and px <= math.max(ax, bx) + coordinate_epsilon and
        py >= math.min(ay, by) - coordinate_epsilon and py <= math.max(ay, by) + coordinate_epsilon
end

local function _is_point_in_contour(x, y, contour, n)
    local inside = false
    local j = n

    for i = 1, n do
        local xi, yi = contour[2 * i - 1], contour[2 * i]
        local xj, yj = contour[2 * j - 1], contour[2 * j]

        -- Treat points on the contour as inside.  Do not bias the ray
        -- denominator: adding EPSILON changes intersections on shallow and
        -- small-scale edges and can flip the result from frame to frame.
        if _is_point_on_segment(x, y, xi, yi, xj, yj) then
            return true
        end

        if (yi > y) ~= (yj > y) then
            local intersection_x = xi + (xj - xi) * (y - yi) / (yj - yi)
            if x < intersection_x then inside = not inside end
        end
        j = i
    end

    return inside
end

local function _segments_properly_intersect(ax, ay, bx, by, cx, cy, dx, dy)
    -- Only proper crossings are rejected. Shared endpoints and collinear
    -- boundary edges are valid contacts with the contour.
    local ab_c = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
    local ab_d = (bx - ax) * (dy - ay) - (by - ay) * (dx - ax)
    if not ((ab_c > 0 and ab_d < 0) or (ab_c < 0 and ab_d > 0)) then
        return false
    end

    local cd_a = (dx - cx) * (ay - cy) - (dy - cy) * (ax - cx)
    local cd_b = (dx - cx) * (by - cy) - (dy - cy) * (bx - cx)
    return (cd_a > 0 and cd_b < 0) or (cd_a < 0 and cd_b > 0)
end

local function _is_triangle_inside_contour(x1, y1, x2, y2, x3, y3, contour, contour_n)
    if not _is_point_in_contour(x1, y1, contour, contour_n) or
        not _is_point_in_contour(x2, y2, contour, contour_n) or
        not _is_point_in_contour(x3, y3, contour, contour_n) then
        return false
    end

    -- A triangle can have all vertices inside a concave contour while one
    -- of its sides crosses outside it. Reject any proper edge/boundary
    -- crossing; checking the centroid as well catches numerical/touch cases.
    local cx = (x1 + x2 + x3) / 3
    local cy = (y1 + y2 + y3) / 3
    if not _is_point_in_contour(cx, cy, contour, contour_n) then
        return false
    end
    if not _is_point_in_contour((x1 + x2) / 2, (y1 + y2) / 2, contour, contour_n) or
        not _is_point_in_contour((x2 + x3) / 2, (y2 + y3) / 2, contour, contour_n) or
        not _is_point_in_contour((x3 + x1) / 2, (y3 + y1) / 2, contour, contour_n) then
        return false
    end

    for edge_i = 1, 3 do
        local ax, ay, bx, by
        if edge_i == 1 then
            ax, ay, bx, by = x1, y1, x2, y2
        elseif edge_i == 2 then
            ax, ay, bx, by = x2, y2, x3, y3
        else
            ax, ay, bx, by = x3, y3, x1, y1
        end
        local edge_min_x, edge_max_x = math.min(ax, bx), math.max(ax, bx)
        local edge_min_y, edge_max_y = math.min(ay, by), math.max(ay, by)

        for contour_i = 1, contour_n do
            local contour_j = contour_i % contour_n + 1
            local cx1, cy1 = contour[2 * contour_i - 1], contour[2 * contour_i]
            local cx2, cy2 = contour[2 * contour_j - 1], contour[2 * contour_j]

            -- Cheap bounding-box rejection before the orientation tests.
            if edge_max_x >= math.min(cx1, cx2) and edge_min_x <= math.max(cx1, cx2) and
                edge_max_y >= math.min(cy1, cy2) and edge_min_y <= math.max(cy1, cy2) and
                _segments_properly_intersect(ax, ay, bx, by, cx1, cy1, cx2, cy2) then
                return false
            end
        end
    end

    return true
end

local function _clip_to_contour(self, contour)
    if contour == nil or contour == EMPTY_TABLE or #contour < 6 then
        return
    end

    local contour_n = math.floor(#contour / 2)
    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge
    for i = 1, contour_n do
        local x, y = contour[2 * i - 1], contour[2 * i]
        if x < min_x then min_x = x end
        if y < min_y then min_y = y end
        if x > max_x then max_x = x end
        if y > max_y then max_y = y end
    end

    local buffer = self._buffer
    local triangles = self._triangles_offset
    local coords = self._coords
    local n_triangles = self._n_triangles
    local write_i = 1

    for triangle_i = 1, n_triangles, 3 do
        local i1 = buffer[triangles + triangle_i]
        local i2 = buffer[triangles + triangle_i + 1]
        local i3 = buffer[triangles + triangle_i + 2]
        local x1, y1 = coords[2 * i1 - 1], coords[2 * i1]
        local x2, y2 = coords[2 * i2 - 1], coords[2 * i2]
        local x3, y3 = coords[2 * i3 - 1], coords[2 * i3]

        -- A triangle wholly inside a contour must also have all vertices in
        -- its AABB.  This is a cheap rejection before point-in-polygon tests.
        if x1 >= min_x and x1 <= max_x and y1 >= min_y and y1 <= max_y and
            x2 >= min_x and x2 <= max_x and y2 >= min_y and y2 <= max_y and
            x3 >= min_x and x3 <= max_x and y3 >= min_y and y3 <= max_y and
            _is_triangle_inside_contour(x1, y1, x2, y2, x3, y3, contour, contour_n) then
            buffer[triangles + write_i] = i1
            buffer[triangles + write_i + 1] = i2
            buffer[triangles + write_i + 2] = i3
            write_i = write_i + 3
        end
    end

    self._n_triangles = write_i - 1
end
function rt.DelaunayTriangulation:triangulate(points, contour)
    if meta.isa(contour, rt.Polyline) then contour = contour:get_vertices() end
    -- A Polyline is a valid point source as well as a contour. Preserve its
    -- vertices instead of replacing the point set with an empty table.
    if meta.isa(points, rt.Polyline) then points = points:get_vertices() end
    if points == nil then points = EMPTY_TABLE end

    meta.typecheck(points, mt.Table(mt.Number), contour, mt.Optional(mt.Table(mt.Number)))

    -- Keep the caller's coordinate array even for degenerate inputs.  The
    -- previous fallback replaced it with a static zero triangle, so a later
    -- update could no longer observe repaired/mutated input coordinates.
    self._coords = points
    self._constraints = contour or EMPTY_TABLE

    if not _has_nonzero_area(points) or
        (contour ~= nil and not _has_nonzero_contour_area(contour)) then
        _set_degenerate_state(self)
        return self
    end

    _update(self, true)
    if self._n_triangles == 0 then
        return self
    end

    _clip_to_contour(self, contour)
    return self
end
-- Optional output tables let frame-by-frame callers reuse allocations.  With
-- no argument these retain the original fresh-table return semantics.
function rt.DelaunayTriangulation:get_triangle_vertex_map(out)
    if out == nil then
        out = table.new(self._n_triangles or 0, 0)
    end

    local n_triangles = self._n_triangles or 0
    for i = #out, n_triangles + 1, -1 do
        out[i] = nil
    end

    if self._buffer == nil or n_triangles == 0 then
        return out
    end

    local buffer = self._buffer
    local triangles_offset = self._triangles_offset
    for i = 1, n_triangles do
        out[i] = buffer[triangles_offset + i]
    end

    return out
end

function rt.DelaunayTriangulation:get_triangles(out)
    local n_triangles = self._n_triangles or 0
    local n_output = math.floor(n_triangles / 3)
    if out == nil then
        out = table.new(n_output, 0)
    end

    for i = #out, n_output + 1, -1 do
        out[i] = nil
    end

    if self._buffer == nil or n_triangles == 0 or self._coords == nil then
        return out
    end

    local coords = self._coords
    local buffer = self._buffer
    local triangles_offset = self._triangles_offset
    local out_i = 1
    for i = 1, n_triangles, 3 do
        local i1 = buffer[triangles_offset + i]
        local i2 = buffer[triangles_offset + i + 1]
        local i3 = buffer[triangles_offset + i + 2]
        local x1, y1 = coords[2 * i1 - 1], coords[2 * i1]
        local x2, y2 = coords[2 * i2 - 1], coords[2 * i2]
        local x3, y3 = coords[2 * i3 - 1], coords[2 * i3]

        local triangle = out[out_i]
        if triangle == nil then
            triangle = table.new(6, 0)
            out[out_i] = triangle
        end
        triangle[1], triangle[2] = x1, y1
        triangle[3], triangle[4] = x2, y2
        triangle[5], triangle[6] = x3, y3
        out_i = out_i + 1
    end

    return out
end

function rt.DelaunayTriangulation:get_hull()
    if self._buffer == nil or self._hull_size == nil or self._hull_size == 0 or self._coords == nil then
        return rt.Polyline({})
    end

    local hull_size = self._hull_size
    local hull = table.new(hull_size * 2, 0)
    local coords = self._coords
    local buffer = self._buffer
    local hull_offset = self._hull_offset
    local out_i = 1
    for i = 1, hull_size do
        local j = buffer[hull_offset + i]
        hull[out_i] = coords[2 * j - 1]
        hull[out_i + 1] = coords[2 * j]
        out_i = out_i + 2
    end
    return rt.Polyline(hull)
end

function rt.DelaunayTriangulation:_link(a, b)
    local buffer = self._buffer
    local half_edges = self._half_edges_offset
    buffer[half_edges + a] = b
    if b ~= -1 then buffer[half_edges + b] = a end
end

function rt.DelaunayTriangulation:_add_triangle(i0, i1, i2, a, b, c)
    local t = self._n_triangles + 1
    local buffer = self._buffer
    local triangles = self._triangles_offset

    buffer[triangles + t] = i0
    buffer[triangles + t + 1] = i1
    buffer[triangles + t + 2] = i2

    self:_link(t, a)
    self:_link(t + 1, b)
    self:_link(t + 2, c)

    self._n_triangles = self._n_triangles + 3

    return t
end

function rt.DelaunayTriangulation:_hash(x, y)
    return math.floor(_angle(x - self._center_x, y - self._center_y) * self._hashSize) % self._hashSize + 1
end

function rt.DelaunayTriangulation:_legalize(a)
    local buffer = self._buffer
    local triangles = self._triangles_offset
    local half_edges = self._half_edges_offset
    local hull_triangles = self._hull_tri_offset
    local hull_previous = self._hull_previous_offset
    local edge_stack = self._edge_stack
    local coords = self._coords

    local i = 0
    local ar = 0

    while true do
        local b = buffer[half_edges + a]
        local a0 = a - ((a - 1) % 3)
        ar = a0 + (a + 1) % 3

        local should_continue = false
        if b == -1 then
            if i == 0 then break end
            i = i - 1
            a = edge_stack[i + 1]
            should_continue = true
        end

        if not should_continue then
            local b0 = b - ((b - 1) % 3)
            local al = a0 + (a % 3)
            local bl = b0 + (b + 1) % 3

            local p0 = buffer[triangles + ar]
            local pr = buffer[triangles + a]
            local pl = buffer[triangles + al]
            local p1 = buffer[triangles + bl]

            local illegal = _is_point_in_circumcircle(
                coords[2 * p0 - 1], coords[2 * p0],
                coords[2 * pr - 1], coords[2 * pr],
                coords[2 * pl - 1], coords[2 * pl],
                coords[2 * p1 - 1], coords[2 * p1]
            )

            if illegal then
                buffer[triangles + a] = p1
                buffer[triangles + b] = p0

                local hbl = buffer[half_edges + bl]

                if hbl == -1 then
                    local e = self._hull_start
                    repeat
                        if buffer[hull_triangles + e] == bl then
                            buffer[hull_triangles + e] = a
                            break
                        end
                        e = buffer[hull_previous + e]
                    until e == self._hull_start
                end

                self:_link(a, hbl)
                self:_link(b, buffer[half_edges + ar])
                self:_link(ar, bl)

                local br = b0 + (b % 3)
                if i >= self._edge_buffer_capacity then
                    local new_capacity = self._edge_buffer_capacity * 2
                    local new_stack = table.new(new_capacity, 1)
                    for stack_i = 1, i do
                        new_stack[stack_i] = edge_stack[stack_i]
                    end
                    self._edge_stack = new_stack
                    self._edge_buffer_capacity = new_capacity
                    edge_stack = new_stack
                end
                edge_stack[i + 1] = br
                i = i + 1
            else
                if i == 0 then break end
                i = i - 1
                a = edge_stack[i + 1]
            end
        end
    end

    return ar
end

_update = function(self, coords_are_valid)
    if not coords_are_valid and not _has_nonzero_area(self._coords) then
        _set_degenerate_state(self)
        return
    end

    local coords = self._coords
    local n = bit.rshift(_sizeof(coords), 1)
    _ensure_workspace(self, n)

    local buffer = self._buffer
    local hull_previous = self._hull_previous_offset
    local hull_next = self._hull_next_offset
    local hull_triangles = self._hull_tri_offset
    local hull_hash = self._hull_hash_offset
    local ids = self._ids_offset
    local distances = self._distances_offset

    local min_x = math.huge
    local min_y = math.huge
    local max_x = -math.huge
    local max_y = -math.huge

    for i = 1, n do
        local x = coords[2 * i - 1]
        local y = coords[2 * i]
        if x < min_x then min_x = x end
        if y < min_y then min_y = y end
        if x > max_x then max_x = x end
        if y > max_y then max_y = y end
        buffer[ids + i] = i
    end

    local cx = (min_x + max_x) / 2
    local cy = (min_y + max_y) / 2

    local i0, i1, i2

    do         local min_distance = math.huge
        for i = 1, n do
            local d = _distance(cx, cy, coords[2 * i - 1], coords[2 * i])
            if d < min_distance then
                i0 = i
                min_distance = d
            end
        end
    end

    local i0x = coords[2 * i0 - 1]
    local i0y = coords[2 * i0]

    do         local min_distance = math.huge
        for i = 1, n do
            if i ~= i0 then
                local d = _distance(i0x, i0y, coords[2 * i - 1], coords[2 * i])
                if d < min_distance and d > 0 then
                    i1 = i
                    min_distance = d
                end
            end
        end
    end

    local i1x = coords[2 * i1 - 1]
    local i1y = coords[2 * i1]

    local min_radius = math.huge

    for i = 1, n do
        if not (i == i0 or i == i1) then
            local r = _get_circumradius(i0x, i0y, i1x, i1y, coords[2 * i - 1], coords[2 * i])
            if r < min_radius then
                i2 = i
                min_radius = r
            end
        end
    end

    if min_radius == math.huge then

        for i = 1, n do
            local x_diff = coords[2 * i - 1] - coords[1]
            if x_diff == 0 then
                buffer[distances + i] = coords[2 * i] - coords[2]
            else
                buffer[distances + i] = x_diff
            end
        end

        _quicksort(buffer, ids, distances, 1, n)
        local hull = self._hull_offset
        local j = 0
        do
            local d0 = -math.huge
            for i = 1, n do
                local id = buffer[ids + i]
                local d = buffer[distances + id]
                if d > d0 then
                    buffer[hull + j + 1] = id
                    j = j + 1
                    d0 = d
                end
            end
        end

        self._hull_size = j
        _set_degenerate_state(self)
        return
    end

    local i2x = coords[2 * i2 - 1]
    local i2y = coords[2 * i2]

    if _get_signed_area(i0x, i0y, i1x, i1y, i2x, i2y) < 0 then
        local i = i1
        local x = i1x
        local y = i1y
        i1 = i2
        i1x = i2x
        i1y = i2y
        i2 = i
        i2x = x
        i2y = y
    end

    self._center_x, self._center_y = _get_circumcenter(i0x, i0y, i1x, i1y, i2x, i2y)

    for i = 1, n do
        buffer[distances + i] = _distance(coords[2 * i - 1], coords[2 * i], self._center_x, self._center_y)
    end

    _quicksort(buffer, ids, distances, 1, n)

    self._hull_start = i0
    local hull_size = 3

    buffer[hull_next + i0] = i1
    buffer[hull_next + i1] = i2
    buffer[hull_next + i2] = i0
    buffer[hull_previous + i0] = i2
    buffer[hull_previous + i1] = i0
    buffer[hull_previous + i2] = i1

    buffer[hull_triangles + i0] = 1
    buffer[hull_triangles + i1] = 2
    buffer[hull_triangles + i2] = 3

    for i = 1, self._hashSize do
        buffer[hull_hash + i] = -1
    end

    buffer[hull_hash + self:_hash(i0x, i0y)] = i0
    buffer[hull_hash + self:_hash(i1x, i1y)] = i1
    buffer[hull_hash + self:_hash(i2x, i2y)] = i2

    self._n_triangles = 0
    self:_add_triangle(i0, i1, i2, -1, -1, -1)

    do
        local xp, yp
        for k = 1, n do
            local i = buffer[ids + k]
            local x = coords[2 * i - 1]
            local y = coords[2 * i]

            local is_duplicate = false
            -- Only collapse points that are effectively coincident.  The
            -- former 1e-3 absolute threshold discarded legitimate nearby
            -- vertices and could leave narrow regions untriangulated.
            is_duplicate = k > 1
                and math.abs(x - xp) <= EPSILON
                and math.abs(y - yp) <= EPSILON

            if not is_duplicate then
                xp = x
                yp = y

                local is_seed = false
                is_seed = i == i0
                    or i == i1
                    or i == i2

                if not is_seed then
                    local start = -1
                    local key = self:_hash(x, y)
                    for j = 0, self._hashSize - 1 do
                        start = buffer[hull_hash + (key + j - 1) % self._hashSize + 1]
                        if start ~= -1 and start ~= buffer[hull_next + start] then break end
                    end

                    start = buffer[hull_previous + start]
                    local e, q = start, nil
                    while true do
                        q = buffer[hull_next + e]
                        if not (_get_signed_area(x, y, coords[2 * e - 1], coords[2 * e], coords[2 * q - 1], coords[2 * q]) >= 0) then
                            break
                        end
                        e = q
                        if e == start then
                            e = -1
                            break
                        end
                    end

                    local is_near_duplicate = e == -1

                    if not is_near_duplicate then

                        local t = self:_add_triangle(e, i, buffer[hull_next + e], -1, -1, buffer[hull_triangles + e])

                        buffer[hull_triangles + i] = self:_legalize(t + 2)
                        buffer[hull_triangles + e] = t                         hull_size = hull_size + 1

                        local vertex_i = buffer[hull_next + e]
                        while true do
                            q = buffer[hull_next + vertex_i]
                            if not (_get_signed_area(x, y, coords[2 * vertex_i - 1], coords[2 * vertex_i], coords[2 * q - 1], coords[2 * q]) < 0) then
                                break
                            end
                            t = self:_add_triangle(vertex_i, i, q, buffer[hull_triangles + i], -1, buffer[hull_triangles + vertex_i])
                            buffer[hull_triangles + i] = self:_legalize(t + 2)
                            buffer[hull_next + vertex_i] = vertex_i                             hull_size = hull_size - 1
                            vertex_i = q
                        end

                        if e == start then
                            while true do
                                q = buffer[hull_previous + e]
                                if not (_get_signed_area(x, y, coords[2 * q - 1], coords[2 * q], coords[2 * e - 1], coords[2 * e]) < 0) then
                                    break
                                end
                                t = self:_add_triangle(q, i, e, -1, buffer[hull_triangles + e], buffer[hull_triangles + q])
                                self:_legalize(t + 2)
                                buffer[hull_triangles + q] = t
                                buffer[hull_next + e] = e                                 hull_size = hull_size - 1
                                e = q
                            end
                        end

                        buffer[hull_previous + i] = e
                        self._hull_start = e
                        buffer[hull_previous + vertex_i] = i
                        buffer[hull_next + e] = i
                        buffer[hull_next + i] = vertex_i

                        buffer[hull_hash + self:_hash(x, y)] = i
                        buffer[hull_hash + self:_hash(coords[2 * e - 1], coords[2 * e])] = e
                    end
                end
            end
        end

        local hull = self._hull_offset
        local e = self._hull_start
        for i = 1, hull_size do
            buffer[hull + i] = e
            e = buffer[hull_next + e]
        end
        self._hull_size = hull_size
    end
end

function rt.DelaunayTriangulation:update()
    local contour = self._constraints
    if contour ~= nil and contour ~= EMPTY_TABLE and not _has_nonzero_contour_area(contour) then
        _set_degenerate_state(self)
        return
    end

    _update(self, false)
    if self._n_triangles > 0 then
        _clip_to_contour(self, contour)
    end
end
