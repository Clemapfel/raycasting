require "include"
require "common.common"
require "common.palette"
require "common.smoothed_motion_1d"

rt.settings.delaunay_triangulation = {
    edge_buffer_size = 512
}

local EPSILON = 1 / 1000

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
            local temp__distanceance = _distances[temp]
            local j = i - 1
            while j >= left and _distances[ids[j]] > temp__distanceance do
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
        local temp__distanceance = _distances[temp]
        while true do
            repeat i = i + 1 until not (_distances[ids[i]] < temp__distanceance)
            repeat j = j - 1 until not (_distances[ids[j]] > temp__distanceance)
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
    local dx = bx - ax;
    local dy = by - ay;
    local ex = cx - ax;
    local ey = cy - ay;

    local bl = dx * dx + dy * dy;
    local cl = ex * ex + ey * ey;
    local d = 0.5 / (dx * ey - dy * ex);

    local x = ax + (ey * bl - dy * cl) * d;
    local y = ay + (dx * cl - ex * bl) * d;

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

-- approximates angle of vector, normalized into [0, 1]
local function _angle(dx, dy)
    -- return (math.atan(dy, dx) + math.pi) / (2 * math.pi)
    local p = dx / (math.abs(dx) + math.abs(dy))
    if dy < 0 then
        return(3 - p) / 4
    else
        return (1 + p) / 4
    end
end

local function _get_signed_area(ax, ay, bx, by, cx, cy)
    return -1 * ((bx - ax) * (cy - ay) - (by - ay) * (cx - ax))
end

local function _new_array(n) -- 0-based array
    local out = {}
    for i = 0, n - 1 do
        out[i] = 0
    end

    return out
end

local function _subarray(array, start_index, end_index)
    local result = {}
    for i = start_index, end_index - 1 do
        result[i - start_index] = array[i]
    end
    return result
end

local function _sizeof(t)
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

--- @class rt.DelaunayTriangulation
rt.DelaunayTriangulation = meta.class("DelaunayTriangulation")

--- @brief
function rt.DelaunayTriangulation:instantiate(points)
    self._triangles = {}
    self._hull = {}
    self._half_edges = {}

    if points ~= nil then
        self:triangulate(points)
    end
end

function rt.DelaunayTriangulation:triangulate(points)
    -- translation of `from`
    local point_size = _sizeof(points)
    local coords = _new_array(point_size)

    for i = 1, point_size, 2 do
        coords[i+0 - 1] = points[i+0]
        coords[i+1 - 1] = points[i+1]
    end

    -- translation of localructor
    self._coords = coords
    local coords_size = _sizeof(coords)

    -- arrays that will store the triangulation graph
    local max_n_triangles = math.max(2 * coords_size - 5, 0)
    self._triangles = _new_array(max_n_triangles * 3)
    self._half_edges = _new_array(max_n_triangles * 3)
    self._edge_buffer = _new_array(rt.settings.delaunay_triangulation.edge_buffer_size)

    -- temporary arrays for tracking the edges of the advancing convex hull
    self._hashSize = math.ceil(math.sqrt(coords_size))
    self._hull_previous = _new_array(coords_size) -- edge to prev edge
    self._hull_next = _new_array(coords_size) -- edge to next edge
    self._hull_tri = _new_array(coords_size) -- edge to adjacent triangle
    self._hullHash = _new_array(self._hashSize) -- angular edge hash

    -- temporary arrays for sorting points
    self._ids = _new_array(coords_size)
    self._distances = _new_array(coords_size)

    self:update()
end

--- @brief
function rt.DelaunayTriangulation:get_triangles()
    local triangles = {}
    for i = 0, _sizeof(self._triangles) - 1, 3 do
        local i1 = self._triangles[i + 0]
        local i2 = self._triangles[i + 1]
        local i3 = self._triangles[i + 2]
        local x1 = self._coords[i1 * 2]
        local y1 = self._coords[i1 * 2 + 1]
        local x2 = self._coords[i2 * 2]
        local y2 = self._coords[i2 * 2 + 1]
        local x3 = self._coords[i3 * 2]
        local y3 = self._coords[i3 * 2 + 1]
        table.insert(triangles, { x1, y1, x2, y2, x3, y3 })
    end
    return triangles
end

--- @brief
function rt.DelaunayTriangulation:get_hull()
    local hull = {}
    for i = 0, _sizeof(self._hull) - 1 do
        local j = self._hull[i]
        table.insert(hull, self._coords[j * 2])
        table.insert(hull, self._coords[j * 2 + 1])
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
        local a0 = a - (a % 3);
        ar = a0 + (a + 2) % 3;

        if b == -1 then
            if i == 0 then break end
            i = i - 1
            a = self._edge_buffer[i]
            goto continue
        end

        local b0 = b - (b % 3);
        local al = a0 + ((a + 1) % 3);
        local bl = b0 + ((b + 2) % 3);

        local p0 = triangles[ar];
        local pr = triangles[a];
        local pl = triangles[al];
        local p1 = triangles[bl];

        local illegal = _is_point_in_circumcircle(
            coords[2 * p0], coords[2 * p0 + 1],
            coords[2 * pr], coords[2 * pr + 1],
            coords[2 * pl], coords[2 * pl + 1],
            coords[2 * p1], coords[2 * p1 + 1]
        );

        if illegal then
            triangles[a] = p1;
            triangles[b] = p0;

            local hbl = half_edges[bl];

            -- edge _swapped on the other side of the hull (rare); fix the halfedge reference
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

            self:_link(a, hbl);
            self:_link(b, half_edges[ar]);
            self:_link(ar, bl);

            local br = b0 + ((b + 1) % 3);

            if (i < _sizeof(self._edge_buffer)) then
                self._edge_buffer[i] = br;
                i = i + 1
            else
                -- edge cap hit
                break
            end
        else
            if i == 0 then break end
            i = i - 1
            a = self._edge_buffer[i];
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
        local x = coords[2 * i]
        local y = coords[2 * i + 1]
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
            local d = _distance(cx, cy, coords[2 * i], coords[2 * i + 1])
            if d < min_distance then
                i0 = i
                min_distance = d
            end
        end
    end

    local i0x = coords[2 * i0]
    local i0y = coords[2 * i0 + 1]

    do -- find the point closest to the seed
        local min_distance = math.huge
        for i = 0, n - 1 do
            if i ~= i0 then
                local d = _distance(i0x, i0y, coords[2 * i], coords[2 * i + 1])
                if d < min_distance and d > 0 then
                    i1 = i
                    min_distance = d
                end
            end
        end
    end

    local i1x = coords[2 * i1]
    local i1y = coords[2 * i1 + 1]

    local min_radius = math.huge

    -- find the third point which forms the smallest circumcircle with the first two
    for i = 0, n - 1 do
        if not (i == i0 or i == i1) then
            local r = _get_circumradius(i0x, i0y, i1x, i1y, coords[2 * i], coords[2 * i + 1])
            if r < min_radius then
                i2 = i
                min_radius = r
            end
        end
    end

    local i2x = coords[2 * i2]
    local i2y = coords[2 * i2 + 1]

    if min_radius == math.huge then
        -- order collinear points by dx (or dy if all x are identical)
        -- and return the list as a hull

        for i = 0, n - 1 do
            local x_diff = coords[2 * i] - coords[0]
            if x_diff == 0 then
                self._distances[i] = coords[2 * i + 1] - coords[1]
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

        self._hull = _subarray(hull, 0, j)
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
        self._distances[i] = _distance(coords[2 * i], coords[2 * i + 1], self._center_x, self._center_y)
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
            local x = coords[2 * i]
            local y = coords[2 * i + 1]

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
                if not (_get_signed_area(x, y, coords[2 * e], coords[2 * e + 1], coords[2 * q], coords[2 * q + 1]) >= 0) then
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
                if not (_get_signed_area(x, y, coords[2 * vertex_i], coords[2 * vertex_i + 1], coords[2 * q], coords[2 * q + 1]) < 0) then
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
                    if not (_get_signed_area(x, y, coords[2 * q], coords[2 * q + 1], coords[2 * e], coords[2 * e + 1]) < 0) then
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
            hull_hash[self:_hash(coords[2 * e], coords[2 * e + 1])] = e

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
        self._hull = _subarray(self._hull, 0, hull_size)
        self._triangles = _subarray(self._triangles, 0, self._n_triangles)
        self._half_edges = _subarray(self._half_edges, 0, self._n_triangles)
    end
end

require "common.random"

local points = {}
local directions = {}
local n_points = 200
local border = 50

local instance = rt.DelaunayTriangulation()

do

    points = {}
    table.insert(points, 0.5 * love.graphics.getWidth())
    table.insert(points, 0.5 * love.graphics.getHeight())

    for angle = 0, 2 * math.pi, (2 * math.pi) / n_points do
        for radius in range(50, 100, 150, 200, 250) do
            table.insert(points, 0.5 * love.graphics.getWidth() + math.cos(angle) * radius)
            table.insert(points, 0.5 * love.graphics.getHeight() + math.sin(angle) * radius)
        end

    end

    dbg(_sizeof(points))
    instance:triangulate(points)
end

local speed, scale = 40, 4
local elapsed = 0
function love.update(delta)
    elapsed = elapsed + delta

    if not love.keyboard.isDown("space") then return end


    for i = 1, #points, 2 do
        local x, y = points[i+0], points[i+1]

        local dx, dy = directions[i+0], directions[i+1]
        if dx == nil then dx = 1; directions[i+0] = dx end
        if dy == nil then dy = 1; directions[i+1] = dy end

        local offset = rt.random.noise(
            (i / n_points) * scale,
            (i / n_points) * scale
        ) * 2 * math.pi

        local x_offset = math.cos(offset) * speed * delta * dx
        local y_offset = math.sin(offset) * speed * delta * dy

        if x + x_offset < border or x + x_offset > love.graphics.getWidth() - border then directions[i+0] = -dx end
        if y + y_offset < border or y + y_offset > love.graphics.getHeight() - border then directions[i+1] = -dy end

        points[i+0] = x + x_offset
        points[i+1] = y + y_offset
    end

    instance:triangulate(points)
end

function love.draw()
    love.graphics.setLineWidth(1)

    local gray = 0.7
    local scale = 0.1
    love.graphics.setColor(gray, gray, gray, 1)
    love.graphics.setLineWidth(1)
    love.graphics.setLineJoin("none")
    local triangles = instance:get_triangles()
    local n_triangles = _sizeof(triangles)
    for i, triangle in ipairs(triangles) do
        rt.Palette.BLACK:bind()
        --love.graphics.line(triangle[1], triangle[2], triangle[3], triangle[4], triangle[5], triangle[6], triangle[1], triangle[2])

        local x, y = _get_circumcenter(table.unpack(triangle))
        local hue = rt.random.noise(scale * x / love.graphics.getWidth(), scale * y / love.graphics.getHeight())
        --local hue = math.distance(x, y, 0.5 * love.graphics.getWidth(), 0.5 * love.graphics.getHeight()) / math.min(love.graphics.getDimensions())
        local cx, cy = (triangle[1] + triangle[3] + triangle[5]) / 3, (triangle[2] + triangle[4] + triangle[6]) / 3

        local real = math.normalize_angle(math.angle(cx - 0.5 * love.graphics.getWidth(), cy - 0.5 * love.graphics.getHeight())) / (2 * math.pi)
        local approx = math.fract(_angle(cx - 0.5 * love.graphics.getWidth(), cy - 0.5 * love.graphics.getHeight()), 1)

        real = math.fract(real + elapsed / 10)
        approx = math.fract(approx + elapsed / 10)

        if cx >= 0.5 * love.graphics.getWidth() then rt.HSVA(0, 0, hue, 1):bind() else rt.HSVA(approx, 1, 1, 1):bind() end
        love.graphics.polygon("fill", triangle[1], triangle[2], triangle[3], triangle[4], triangle[5], triangle[6], triangle[1], triangle[2])
    end

    local bounds = instance:get_hull()
    table.insert(bounds, bounds[1])
    table.insert(bounds, bounds[2])
    --[[
    local bounds = instance:get_hull()
    table.insert(bounds, bounds[1])
    table.insert(bounds, bounds[2])
    ]]--

    --[[
    if #bounds > 0 then
        love.graphics.line(bounds)
    end
    ]]--

    --[[
    for i = 1, #points, 2 do
        local x, y = points[i+0], points[i+1]

        rt.Palette.BLACK:bind()
        love.graphics.circle("fill", x, y, 2)

        rt.Palette.WHITE:bind()
        love.graphics.circle("fill", x, y, 1)
    end
    ]]--
end

--[[
require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"
require "common.profiler"

_input = rt.InputSubscriber()
_input:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "p" then
        debugger.reload()
    elseif which == "r" then
        background:recompile()
    elseif which == "1" then
        require "menu.settings_scene"
        rt.SceneManager:set_scene(mn.SettingsScene)
    elseif which == "2" then
        require "overworld.overworld_scene"
        rt.SceneManager:set_scene(ow.OverworldScene, "tutorial")
    elseif which == "3" then
        require "menu.keybinding_scene"
        rt.SceneManager:set_scene(mn.KeybindingScene)
    end
end)

love.load = function(args)
    -- intialize all scenes
    require "overworld.overworld_scene"
    rt.SceneManager:push(ow.OverworldScene, "tutorial")

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    --rt.SceneManager:push(mn.MenuScene)
end

love.update = function(delta)
    rt.SceneManager:update(delta)
end

love.draw = function()
    rt.SceneManager:draw()
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end
]]--
