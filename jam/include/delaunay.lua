
Delaunay_t = "Delaunay"

delaunay_new = function(points, contour)
    local self = object_new(Delaunay_t, {
        _triangles = {},
        _hull = {},
        _half_edges = {},
        _current_n_points = -1
    })

    if points ~= nil then
        delaunay_triangulate(self, points, contour)
    end

    return self
end

local EPSILON = 1 / 1000
local EDGE_BUFFER_SIZE = 512

local function _swap(arr, i, j)
    local tmp = arr[i]
    arr[i] = arr[j]
    arr[j] = tmp
end

local function _quicksort(ids, _distances, left, right)
    if right - left <= 20 then
        for i = left + 1, right do
            local temp = ids[i]
            local temp_distance = _distances[temp]
            local j = i - 1
            while j >= left and _distances[ids[j]] > temp_distance do
                ids[j + 1] = ids[j]
                j = j - 1
            end
            ids[j + 1] = temp
        end
    else
        local median = math_floor((left + right) / 2)
        local i = left + 1
        local j = right
        _swap(ids, median, i)
        if _distances[ids[left]] > _distances[ids[right]] then _swap(ids, left, right) end
        if _distances[ids[i]] > _distances[ids[right]] then _swap(ids, i, right) end
        if _distances[ids[left]] > _distances[ids[i]] then _swap(ids, left, i) end

        local temp = ids[i]
        local temp_distance = _distances[temp]
        while true do
            repeat i = i + 1 until not (_distances[ids[i]] < temp_distance)
            repeat j = j - 1 until not (_distances[ids[j]] > temp_distance)
            if j < i then break end
            _swap(ids, i, j)
        end
        ids[left + 1] = ids[j]
        ids[j] = temp

        if right - i + 1 >= j - left then
            _quicksort(ids, _distances, i, right)
            _quicksort(ids, _distances, left, j - 1)
        else
            _quicksort(ids, _distances, left, j - 1)
            _quicksort(ids, _distances, i, right)
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
    local p = dx / (math_abs(dx) + math_abs(dy))
    if dy < 0 then
        return (3 - p) / 4
    else
        return (1 + p) / 4
    end
end

local function _get_signed_area(ax, ay, bx, by, cx, cy)
    return -1 * ((bx - ax) * (cy - ay) - (by - ay) * (cx - ax))
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

local function _trim(array, end_index)
    local n = _sizeof(array)
    if n <= end_index then return array end
    for i = end_index + 1, n do
        array[i] = nil
    end
    return array
end

local function _is_point_in_contour(x, y, contour, n)
    local inside = false
    local j = n
    for i = 1, n do
        local xi, yi = contour[2 * i - 1], contour[2 * i]
        local xj, yj = contour[2 * j - 1], contour[2 * j]
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / ((yj - yi) + EPSILON) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

local function _is_triangle_in_aabb(ax, ay, bx, by, cx, cy, min_x, min_y, max_x, max_y)
    return ax >= min_x and ax <= max_x and ay >= min_y and ay <= max_y and
        bx >= min_x and bx <= max_x and by >= min_y and by <= max_y and
        cx >= min_x and cx <= max_x and cy >= min_y and cy <= max_y
end

local _link = function(self, a, b)
    self._half_edges[a] = b
    if b ~= -1 then self._half_edges[b] = a end
end

local _add_triangle = function(self, i0, i1, i2, a, b, c)
    local t = self._n_triangles + 1

    self._triangles[t] = i0
    self._triangles[t + 1] = i1
    self._triangles[t + 2] = i2

    _link(self, t, a)
    _link(self, t + 1, b)
    _link(self, t + 2, c)

    self._n_triangles = self._n_triangles + 3

    return t
end

local function _hash(self, x, y)
    return math_floor(_angle(x - self._center_x, y - self._center_y) * self._hash_size) % self._hash_size + 1
end

local function _legalize(self, a)
    local triangles = self._triangles
    local half_edges = self._half_edges
    local coords = self._coords

    local i = 0
    local ar = 0

    while true do
        local b = half_edges[a]
        local a0 = a - ((a - 1) % 3)
        ar = a0 + (a + 1) % 3

        local should_continue = false
        if b == -1 then
            if i == 0 then break end
            i = i - 1
            a = self._edge_buffer[i + 1]
            should_continue = true
        end

        if not should_continue then
            local b0 = b - ((b - 1) % 3)
            local al = a0 + (a % 3)
            local bl = b0 + (b + 1) % 3

            local p0 = triangles[ar]
            local pr = triangles[a]
            local pl = triangles[al]
            local p1 = triangles[bl]

            local illegal = _is_point_in_circumcircle(
                coords[2 * p0 - 1], coords[2 * p0],
                coords[2 * pr - 1], coords[2 * pr],
                coords[2 * pl - 1], coords[2 * pl],
                coords[2 * p1 - 1], coords[2 * p1]
            )

            if illegal then
                triangles[a] = p1
                triangles[b] = p0

                local hbl = half_edges[bl]

                if hbl == -1 then
                    local e = self._hull_start
                    repeat
                        if self._hull_tri[e] == bl then
                            self._hull_tri[e] = a
                            break
                        end
                        e = self._hull_previous[e]
                    until e == self._hull_start
                end

                _link(self, a, hbl)
                _link(self, b, half_edges[ar])
                _link(self, ar, bl)

                local br = b0 + (b % 3)

                if (i < _sizeof(self._edge_buffer)) then
                    self._edge_buffer[i + 1] = br
                    i = i + 1
                else
                    break
                end
            else
                if i == 0 then break end
                i = i - 1
                a = self._edge_buffer[i + 1]
            end
        end
    end

    return ar
end

delaunay_update = function(self)
    log_typecheck(self, Delaunay_t)

    local coords = self._coords
    local hull_previous = self._hull_previous
    local hull_next = self._hull_next
    local hull_triangles = self._hull_tri
    local hull_hash = self._hull_hash

    local n = math_floor(_sizeof(coords) / 2)

    local min_x = math_positive_inf
    local min_y = math_positive_inf
    local max_x = math_negative_inf
    local max_y = math_negative_inf

    for i = 1, n do
        local x = coords[2 * i - 1]
        local y = coords[2 * i]
        if x < min_x then min_x = x end
        if y < min_y then min_y = y end
        if x > max_x then max_x = x end
        if y > max_y then max_y = y end
        self._ids[i] = i
    end

    local cx = (min_x + max_x) / 2
    local cy = (min_y + max_y) / 2

    local i0, i1, i2

    do -- pick a seed point close to the center
        local min_distance = math_positive_inf
        for i = 1, n do
            local d = _distance(cx, cy, coords[2 * i - 1], coords[2 * i])
            if d < min_distance then
                i0 = i
                min_distance = d
            end
        end
    end

    local i0x = coords[2 * i0 - 1]
    local i0y = coords[2 * i0 - 0]

    do -- find the point closest to the seed
        local min_distance = math_positive_inf
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

    local min_radius = math_positive_inf

    -- find the third point which forms the smallest circumcircle with the first two
    for i = 1, n do
        if not (i == i0 or i == i1) then
            local r = _get_circumradius(i0x, i0y, i1x, i1y, coords[2 * i - 1], coords[2 * i])
            if r < min_radius then
                i2 = i
                min_radius = r
            end
        end
    end

    if min_radius == math_positive_inf then
        -- order collinear points by dx (or dy if all x are identical)
        -- and return the list as a hull

        for i = 1, n do
            local x_diff = coords[2 * i - 1] - coords[1]
            if x_diff == 0 then
                self._distances[i] = coords[2 * i] - coords[2]
            else
                self._distances[i] = x_diff
            end
        end

        _quicksort(self._ids, self._distances, 1, n)
        local hull = _new_array(n)
        local j = 0
        do
            local d0 = math_negative_inf
            for i = 1, n do
                local id = self._ids[i]
                local d = self._distances[id]
                if d > d0 then
                    hull[j + 1] = id
                    j = j + 1
                    d0 = d
                end
            end
        end

        self._hull = _trim(hull, j)
        self._triangles = _new_array(0)
        self._half_edges = _new_array(0)
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
        self._distances[i] = _distance(coords[2 * i - 1], coords[2 * i], self._center_x, self._center_y)
    end

    -- sort the points by _distanceance from the seed triangle circumcenter
    _quicksort(self._ids, self._distances, 1, n)

    -- set up the seed triangle as the starting hull
    self._hull_start = i0
    local hull_size = 3

    hull_next[i0] = i1
    hull_next[i1] = i2
    hull_next[i2] = i0
    hull_previous[i0] = i2
    hull_previous[i1] = i0
    hull_previous[i2] = i1

    hull_triangles[i0] = 1
    hull_triangles[i1] = 2
    hull_triangles[i2] = 3

    for i = 1, _sizeof(hull_hash) do
        hull_hash[i] = -1
    end

    hull_hash[_hash(self, i0x, i0y)] = i0
    hull_hash[_hash(self, i1x, i1y)] = i1
    hull_hash[_hash(self, i2x, i2y)] = i2

    self._n_triangles = 0
    _add_triangle(self, i0, i1, i2, -1, -1, -1)

    do
        local xp, yp
        for k = 1, _sizeof(self._ids) do
            local i = self._ids[k]
            local x = coords[2 * i - 1]
            local y = coords[2 * i]

            -- skip near-duplicate points
            local is_duplicate = false
            is_duplicate = k > 1
                and math_abs(x - xp) <= EPSILON
                and math_abs(y - yp) <= EPSILON

            if not is_duplicate then
                xp = x
                yp = y

                -- skip seed triangle points
                local is_seed = false
                is_seed = i == i0
                    or i == i1
                    or i == i2

                if not is_seed then
                    -- find a visible edge on the convex hull using edge hash
                    local start = -1
                    local key = _hash(self, x, y)
                    for j = 0, self._hash_size - 1 do
                        start = hull_hash[(key + j - 1) % self._hash_size + 1]
                        if start ~= -1 and start ~= hull_next[start] then break end
                    end

                    start = hull_previous[start]
                    local e, q = start, nil
                    while true do
                        q = hull_next[e]
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

                        -- add the first triangle from the point
                        local t = _add_triangle(self, e, i, hull_next[e], -1, -1, hull_triangles[e])

                        -- recursively flip triangles from the point until they satisfy the Delaunay condition
                        hull_triangles[i] = _legalize(self, t + 2)
                        hull_triangles[e] = t -- keep track of boundary triangles on the hull
                        hull_size = hull_size + 1

                        -- walk forward through the hull, adding more triangles and flipping recursively
                        local vertex_i = hull_next[e]
                        while true do
                            q = hull_next[vertex_i]
                            if not (_get_signed_area(x, y, coords[2 * vertex_i - 1], coords[2 * vertex_i], coords[2 * q - 1], coords[2 * q]) < 0) then
                                break
                            end
                            t = _add_triangle(self, vertex_i, i, q, hull_triangles[i], -1, hull_triangles[vertex_i])
                            hull_triangles[i] = _legalize(self, t + 2)
                            hull_next[vertex_i] = vertex_i -- mark as removed
                            hull_size = hull_size - 1
                            vertex_i = q
                        end

                        -- walk backward from the other side
                        if e == start then
                            while true do
                                q = hull_previous[e]
                                if not (_get_signed_area(x, y, coords[2 * q - 1], coords[2 * q], coords[2 * e - 1], coords[2 * e]) < 0) then
                                    break
                                end
                                t = _add_triangle(self, q, i, e, -1, hull_triangles[e], hull_triangles[q])
                                _legalize(self, t + 2)
                                hull_triangles[q] = t
                                hull_next[e] = e -- mark as removed
                                hull_size = hull_size - 1
                                e = q
                            end
                        end

                        -- update the hull indices
                        hull_previous[i] = e
                        self._hull_start = e
                        hull_previous[vertex_i] = i
                        hull_next[e] = i
                        hull_next[i] = vertex_i

                        hull_hash[_hash(self, x, y)] = i
                        hull_hash[_hash(self, coords[2 * e - 1], coords[2 * e])] = e
                    end
                end
            end
        end

        self._hull = _new_array(hull_size)
        do
            local e = self._hull_start
            for i = 1, hull_size do
                self._hull[i] = e
                e = hull_next[e]
            end
        end

        -- trim typed triangle mesh arrays
        self._hull = _trim(self._hull, hull_size)
        self._triangles = _trim(self._triangles, self._n_triangles)
        self._half_edges = _trim(self._half_edges, self._n_triangles)
    end
end

delaunay_triangulate = function(self, points, contour)
    log_typecheck(self, Delaunay_t, points, Table_t, contour, Table_t)

    log_assert(#points >= 6, "In delaunay_triangulate: table has less than 3 points")

    self._constraints = contour
    self._coords = points
    local coords = self._coords
    local coords_size = math_floor(#coords / 2)

    if self._current_n_points ~= coords_size then
        self._current_n_points = coords_size

        local max_n_triangles = math_max(2 * coords_size - 5, 0)
        self._triangles = _new_array(max_n_triangles * 3)
        self._half_edges = _new_array(max_n_triangles * 3)
        self._edge_buffer = _new_array(EDGE_BUFFER_SIZE)

        self._hash_size = math_ceil(math_sqrt(coords_size))
        self._hull_previous = _new_array(coords_size)
        self._hull_next = _new_array(coords_size)
        self._hull_tri = _new_array(coords_size)
        self._hull_hash = _new_array(self._hash_size)

        self._ids = _new_array(coords_size)
        self._distances = _new_array(coords_size)
    end

    delaunay_update(self)

    if not contour then return self end

    local min_x, min_y, max_x, max_y = math_positive_inf, math_positive_inf, math_negative_inf, math_negative_inf
    local hull = self._hull
    for i = 1, _sizeof(hull) do
        local j = hull[i]
        local x = coords[2 * j - 1]
        local y = coords[2 * j]
        if x < min_x then min_x = x end
        if y < min_y then min_y = y end
        if x > max_x then max_x = x end
        if y > max_y then max_y = y end
    end

    -- filter
    local triangles = self._triangles
    local n_triangles = _sizeof(triangles)
    local contour_n = math_floor(#contour / 2)
    local constrained = _new_array(n_triangles)
    local constrained_i = 0

    for triangle_i = 1, n_triangles, 3 do
        local i1 = triangles[triangle_i]
        local i2 = triangles[triangle_i + 1]
        local i3 = triangles[triangle_i + 2]
        local x1 = coords[2 * i1 - 1]
        local y1 = coords[2 * i1]
        local x2 = coords[2 * i2 - 1]
        local y2 = coords[2 * i2]
        local x3 = coords[2 * i3 - 1]
        local y3 = coords[2 * i3]

        if _is_triangle_in_aabb(x1, y1, x2, y2, x3, y3, min_x, min_y, max_x, max_y) then
            local cx = (x1 + x2 + x3) / 3
            local cy = (y1 + y2 + y3) / 3
            if _is_point_in_contour(cx, cy, contour, contour_n) then
                constrained[constrained_i+1] = i1
                constrained[constrained_i+2] = i2
                constrained[constrained_i+3] = i3
                constrained_i = constrained_i + 3
            end
        end
    end

    self._triangles = _trim(constrained, constrained_i)
    return self._triangles
end

delaunay_get_triangle_vertex_map = function(self)
    log_typecheck(self, Delaunay_t)

    local indices = {}
    local tris = self._triangles
    for i = 1, _sizeof(tris), 3 do
        table.insert(indices, tris[i])
        table.insert(indices, tris[i + 1])
        table.insert(indices, tris[i + 2])
    end

    return indices
end

delaunay_get_triangles = function(self)
    log_typecheck(self, Delaunay_t)

    local triangles = {}
    local coords = self._coords
    local tris = self._triangles
    for i = 1, _sizeof(tris), 3 do
        local i1 = tris[i]
        local i2 = tris[i + 1]
        local i3 = tris[i + 2]
        local x1 = coords[2 * i1 - 1]
        local y1 = coords[2 * i1]
        local x2 = coords[2 * i2 - 1]
        local y2 = coords[2 * i2]
        local x3 = coords[2 * i3 - 1]
        local y3 = coords[2 * i3]
        table.insert(triangles, { x1, y1, x2, y2, x3, y3 })
    end

    return triangles
end

delaunay_get_hull = function(self)
    log_typecheck(self, Delaunay_t)

    local hull = {}
    local coords = self._coords
    for i = 1, _sizeof(self._hull) do
        local j = self._hull[i]
        table.insert(hull, coords[2 * j - 1])
        table.insert(hull, coords[2 * j])
    end

    return hull
end