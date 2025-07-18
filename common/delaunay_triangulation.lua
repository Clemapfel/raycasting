require "common.meta"

--- @class rt.DelaunayTriangulation
rt.DelaunayTriangulation = meta.class("DelaunayTriangulation")

--- @brief
function rt.DelaunayTriangulation:instantiate(points, contour)
    self._triangles = {}
    self._hull = {}
    self._half_edges = {}
    self._current_n_points = -1

    if points ~= nil then
        self:triangulate(points, contour)
    end
end

local EPSILON = math.eps
local EDGE_BUFFER_SIZE = 512

local function _swap(arr, i, j)
    local tmp = arr[i]
    arr[i] = arr[j]
    arr[j] = tmp
end

-- quicksort for ids based on _distances, 0-based arrays
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
        local median = math.floor((left + right) / 2)
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
    local p = dx / (math.abs(dx) + math.abs(dy))
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
    for i = 0, n - 1 do
        out[i] = 0
    end
    return out
end

local function _sizeof(t)
    return #t + 1
end

local function _trim(array, end_index)
    local n = _sizeof(array)
    if n > end_index then return array end
    for i = end_index, n do
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

function rt.DelaunayTriangulation:triangulate(points, contour)
    self._constraints = contour or {}

    local coords = points
    local coords_size = #coords
    self._coords = coords

    if self._current_n_points ~= coords_size then
        self._current_n_points = coords_size

        local max_n_triangles = math.max(2 * coords_size - 5, 0)
        self._triangles = _new_array(max_n_triangles * 3)
        self._half_edges = _new_array(max_n_triangles * 3)
        self._edge_buffer = _new_array(EDGE_BUFFER_SIZE)

        self._hashSize = math.ceil(math.sqrt(coords_size))
        self._hull_previous = _new_array(coords_size)
        self._hull_next = _new_array(coords_size)
        self._hull_tri = _new_array(coords_size)
        self._hullHash = _new_array(self._hashSize)

        self._ids = _new_array(coords_size)
        self._distances = _new_array(coords_size)
    end

    self:update()

    if not contour then return self end

    -- Compute AABB for the contour
    local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
    local hull = self._hull
    local coords = self._coords
    for i = 0, _sizeof(hull) - 1 do
        local j = hull[i]
        local x = coords[j * 2 + 1]
        local y = coords[j * 2 + 2]
        if x < min_x then min_x = x end
        if y < min_y then min_y = y end
        if x > max_x then max_x = x end
        if y > max_y then max_y = y end
    end

    -- Efficient triangle filtering
    local triangles = self._triangles
    local n_triangles = _sizeof(triangles)
    local contour_n = math.floor(#contour / 2)
    local constrained = _new_array(n_triangles)
    local constrained_i = 0

    for triangle_i = 0, n_triangles - 1, 3 do
        local i1 = triangles[triangle_i + 0]
        local i2 = triangles[triangle_i + 1]
        local i3 = triangles[triangle_i + 2]
        local x1 = coords[i1 * 2 + 1]
        local y1 = coords[i1 * 2 + 2]
        local x2 = coords[i2 * 2 + 1]
        local y2 = coords[i2 * 2 + 2]
        local x3 = coords[i3 * 2 + 1]
        local y3 = coords[i3 * 2 + 2]

        if _is_triangle_in_aabb(x1, y1, x2, y2, x3, y3, min_x, min_y, max_x, max_y) then
            local cx = (x1 + x2 + x3) / 3
            local cy = (y1 + y2 + y3) / 3
            if _is_point_in_contour(cx, cy, contour, contour_n) then
                constrained[constrained_i+0] = i1
                constrained[constrained_i+1] = i2
                constrained[constrained_i+2] = i3
                constrained_i = constrained_i + 3
            end
        end
    end

    self._triangles = _trim(constrained, constrained_i)
    return self
end

--- @brief
function rt.DelaunayTriangulation:get_triangle_vertex_map()
    local indices = {}
    local tris = self._triangles
    for i = 0, _sizeof(tris) - 1, 3 do
        table.insert(indices, tris[i + 0] + 1)
        table.insert(indices, tris[i + 1] + 1)
        table.insert(indices, tris[i + 2] + 1)
    end

    return indices
end

--- @brief
function rt.DelaunayTriangulation:get_triangles()
    local triangles = {}
    local coords = self._coords
    local tris = self._triangles
    for i = 0, _sizeof(tris) - 1, 3 do
        local i1 = tris[i + 0]
        local i2 = tris[i + 1]
        local i3 = tris[i + 2]
        local x1 = coords[i1 * 2 + 1]
        local y1 = coords[i1 * 2 + 2]
        local x2 = coords[i2 * 2 + 1]
        local y2 = coords[i2 * 2 + 2]
        local x3 = coords[i3 * 2 + 1]
        local y3 = coords[i3 * 2 + 2]
        table.insert(triangles, { x1, y1, x2, y2, x3, y3 })
    end
    return triangles
end

--- @brief
function rt.DelaunayTriangulation:get_hull()
    local hull = {}
    local coords = self._coords
    for i = 0, _sizeof(self._hull) - 1 do
        local j = self._hull[i]
        table.insert(hull, coords[j * 2 + 1])
        table.insert(hull, coords[j * 2 + 2])
    end
    return hull
end

function rt.DelaunayTriangulation:_link(a, b)
    self._half_edges[a] = b
    if b ~= -1 then self._half_edges[b] = a end
end

function rt.DelaunayTriangulation:_add_triangle(i0, i1, i2, a, b, c)
    local t = self._n_triangles

    self._triangles[t] = i0
    self._triangles[t + 1] = i1
    self._triangles[t + 2] = i2

    self:_link(t, a)
    self:_link(t + 1, b)
    self:_link(t + 2, c)

    self._n_triangles = self._n_triangles + 3

    return t
end

function rt.DelaunayTriangulation:_hash(x, y)
    return math.floor(_angle(x - self._center_x, y - self._center_y) * self._hashSize) % self._hashSize
end

function rt.DelaunayTriangulation:_legalize(a)
    local triangles = self._triangles
    local half_edges = self._half_edges
    local coords = self._coords

    local i = 0
    local ar = 0

    while true do
        local b = half_edges[a]
        local a0 = a - (a % 3)
        ar = a0 + (a + 2) % 3

        if b == -1 then
            if i == 0 then break end
            i = i - 1
            a = self._edge_buffer[i]
            goto continue
        end

        local b0 = b - (b % 3)
        local al = a0 + ((a + 1) % 3)
        local bl = b0 + ((b + 2) % 3)

        local p0 = triangles[ar]
        local pr = triangles[a]
        local pl = triangles[al]
        local p1 = triangles[bl]

        local illegal = _is_point_in_circumcircle(
            coords[2 * p0 + 1], coords[2 * p0 + 2],
            coords[2 * pr + 1], coords[2 * pr + 2],
            coords[2 * pl + 1], coords[2 * pl + 2],
            coords[2 * p1 + 1], coords[2 * p1 + 2]
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

            self:_link(a, hbl)
            self:_link(b, half_edges[ar])
            self:_link(ar, bl)

            local br = b0 + ((b + 1) % 3)

            if (i < _sizeof(self._edge_buffer)) then
                self._edge_buffer[i] = br
                i = i + 1
            else
                break
            end
        else
            if i == 0 then break end
            i = i - 1
            a = self._edge_buffer[i]
        end

        ::continue::
    end

    return ar
end

function rt.DelaunayTriangulation:update()
    local coords = self._coords
    local hull_previous = self._hull_previous
    local hull_next = self._hull_next
    local hull_triangles = self._hull_tri
    local hull_hash = self._hullHash

    local n = bit.rshift(_sizeof(coords), 1)

    local min_x = math.huge
    local min_y = math.huge
    local max_x = -math.huge
    local max_y = -math.huge

    for i = 0, n - 1 do
        local x = coords[2 * i + 1]
        local y = coords[2 * i + 2]
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
        local min_distance = math.huge
        for i = 0, n - 1 do
            local d = _distance(cx, cy, coords[2 * i + 1], coords[2 * i + 2])
            if d < min_distance then
                i0 = i
                min_distance = d
            end
        end
    end

    local i0x = coords[2 * i0 + 1]
    local i0y = coords[2 * i0 + 2]

    do -- find the point closest to the seed
        local min_distance = math.huge
        for i = 0, n - 1 do
            if i ~= i0 then
                local d = _distance(i0x, i0y, coords[2 * i + 1], coords[2 * i + 2])
                if d < min_distance and d > 0 then
                    i1 = i
                    min_distance = d
                end
            end
        end
    end

    local i1x = coords[2 * i1 + 1]
    local i1y = coords[2 * i1 + 2]

    local min_radius = math.huge

    -- find the third point which forms the smallest circumcircle with the first two
    for i = 0, n - 1 do
        if not (i == i0 or i == i1) then
            local r = _get_circumradius(i0x, i0y, i1x, i1y, coords[2 * i + 1], coords[2 * i + 2])
            if r < min_radius then
                i2 = i
                min_radius = r
            end
        end
    end

    local i2x = coords[2 * i2 + 1]
    local i2y = coords[2 * i2 + 2]

    if min_radius == math.huge then
        -- order collinear points by dx (or dy if all x are identical)
        -- and return the list as a hull

        for i = 0, n - 1 do
            local x_diff = coords[2 * i + 1] - coords[1]
            if x_diff == 0 then
                self._distances[i] = coords[2 * i + 2] - coords[2]
            else
                self._distances[i] = x_diff
            end
        end

        _quicksort(self._ids, self._distances, 0, n - 1)
        local hull = _new_array(n)
        local j = 0
        do
            local d0 = -math.huge
            for i = 0, n - 1 do
                local id = self._ids[i]
                local d = self._distances[id]
                if d > d0 then
                    hull[j] = id
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

    for i = 0, n - 1 do
        self._distances[i] = _distance(coords[2 * i + 1], coords[2 * i + 2], self._center_x, self._center_y)
    end

    -- sort the points by _distanceance from the seed triangle circumcenter
    _quicksort(self._ids, self._distances, 0, n - 1)

    -- set up the seed triangle as the starting hull
    self._hull_start = i0
    local hull_size = 3

    hull_next[i0] = i1
    hull_next[i1] = i2
    hull_next[i2] = i0
    hull_previous[i0] = i2
    hull_previous[i1] = i0
    hull_previous[i2] = i1

    hull_triangles[i0] = 0
    hull_triangles[i1] = 1
    hull_triangles[i2] = 2

    for i = 0, _sizeof(hull_hash) - 1 do
        hull_hash[i] = -1
    end

    hull_hash[self:_hash(i0x, i0y)] = i0
    hull_hash[self:_hash(i1x, i1y)] = i1
    hull_hash[self:_hash(i2x, i2y)] = i2

    self._n_triangles = 0
    self:_add_triangle(i0, i1, i2, -1, -1, -1)

    do
        local xp, yp
        for k = 0, _sizeof(self._ids) - 1 do
            local i = self._ids[k]
            local x = coords[2 * i + 1]
            local y = coords[2 * i + 2]

            -- skip near-duplicate points
            if k > 0 and math.abs(x - xp) <= EPSILON and math.abs(y - yp) <= EPSILON then goto continue end

            xp = x
            yp = y

            -- skip seed triangle points
            if (i == i0 or i == i1 or i == i2) then goto continue end

            -- find a visible edge on the convex hull using edge hash
            local start = 0
            local key = self:_hash(x, y)
            for j = 0, self._hashSize - 1 do
                start = hull_hash[(key + j) % self._hashSize]
                if start ~= -1 and start ~= hull_next[start] then break end
            end

            start = hull_previous[start]
            local e, q = start, nil
            while true do
                q = hull_next[e]
                if not (_get_signed_area(x, y, coords[2 * e + 1], coords[2 * e + 2], coords[2 * q + 1], coords[2 * q + 2]) >= 0) then
                    break
                end
                e = q
                if e == start then
                    e = -1
                    break
                end
            end

            if e == -1 then goto continue end -- likely a near-duplicate point, skip it

            -- add the first triangle from the point
            local t = self:_add_triangle(e, i, hull_next[e], -1, -1, hull_triangles[e])

            -- recursively flip triangles from the point until they satisfy the Delaunay condition
            hull_triangles[i] = self:_legalize(t + 2)
            hull_triangles[e] = t -- keep track of boundary triangles on the hull
            hull_size = hull_size + 1

            -- walk forward through the hull, adding more triangles and flipping recursively
            local vertex_i = hull_next[e]
            while true do
                q = hull_next[vertex_i]
                if not (_get_signed_area(x, y, coords[2 * vertex_i + 1], coords[2 * vertex_i + 2], coords[2 * q + 1], coords[2 * q + 2]) < 0) then
                    break
                end
                t = self:_add_triangle(vertex_i, i, q, hull_triangles[i], -1, hull_triangles[vertex_i])
                hull_triangles[i] = self:_legalize(t + 2)
                hull_next[vertex_i] = vertex_i -- mark as removed
                hull_size = hull_size - 1
                vertex_i = q
            end

            -- walk backward from the other side, adding more triangles and flipping
            if e == start then
                while true do
                    q = hull_previous[e]
                    if not (_get_signed_area(x, y, coords[2 * q + 1], coords[2 * q + 2], coords[2 * e + 1], coords[2 * e + 2]) < 0) then
                        break
                    end
                    t = self:_add_triangle(q, i, e, -1, hull_triangles[e], hull_triangles[q])
                    self:_legalize(t + 2)
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

            -- save the two new edges in the hash table
            hull_hash[self:_hash(x, y)] = i
            hull_hash[self:_hash(coords[2 * e +1], coords[2 * e + 2])] = e

            ::continue::
        end

        self._hull = _new_array(hull_size)
        do
            local e = self._hull_start
            for i = 0, hull_size - 1 do
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
