require "include"
require "common.common"

local EPSILON = math.pow(2, -32)

local function swap(arr, i, j)
    local tmp = arr[i]
    arr[i] = arr[j]
    arr[j] = tmp
end

local function quicksort(ids, dists, left, right)
    if right - left <= 20 then
        for i = left + 1, right do
            local temp = ids[i]
            local tempDist = dists[temp]
            local j = i - 1
            while j >= left and dists[ids[j]] > tempDist do
                ids[j + 1] = ids[j]
                j = j - 1
            end

            ids[j + 1] = temp;
        end
    else
        local median = bit.rshift(left + right, 1);
        local i = left + 1;
        local j = right;
        swap(ids, median, i);

        if dists[ids[left]] > dists[ids[right]] then swap(ids, left, right) end
        if dists[ids[i]] > dists[ids[right]] then swap(ids, i, right) end
        if dists[ids[left]] > dists[ids[i]] then swap(ids, left, i) end

        local temp = ids[i];
        local tempDist = dists[temp];

        while true do
            repeat i = i + 1 until not (dists[ids[i]] < tempDist)
            repeat j = j - 1 until not (dists[ids[j]] > tempDist)
            if (j < i) then break end
            swap(ids, i, j)
        end

        ids[left + 1] = ids[j]
        ids[j] = temp

        if (right - i + 1 >= j - left) then
            quicksort(ids, dists, i, right);
            quicksort(ids, dists, left, j - 1);
        else
            quicksort(ids, dists, left, j - 1);
            quicksort(ids, dists, i, right);
        end
    end
end

local function circumcenter(ax, ay, bx, by, cx, cy)
    local dx = bx - ax
    local dy = by - ay
    local ex = cx - ax
    local ey = cy - ay
    
    local bl = dx * dx + dy * dy
    local cl = ex * ex + ey * ey
    local d = 0.5 / (dx * ey - dy * ex)
    
    local x = ax + (ey * bl - dy * cl) * d
    local y = ay + (dx * cl - ex * bl) * d
    
    return { x = x, y = y }
end

local function circumradius(ax, ay, bx, by, cx, cy)
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

local function inCircle(ax, ay, bx, by, cx, cy, px, py)
    local dx = ax - px
    local dy = ay - py
    local ex = bx - px
    local ey = by - py
    local fx = cx - px
    local fy = cy - py

    local ap = dx * dx + dy * dy
    local bp = ex * ex + ey * ey
    local cp = fx * fx + fy * fy

    return dx * (ey * cp - bp * fy)
        - dy * (ex * cp - bp * fx)
        + ap * (ex * fy - ey * fx) < 0
end

local function dist(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

local function pseudoAngle(dx, dy)
    local p = dx / (math.abs(dx) + math.abs(dy))
    if dy > 0 then
        return (3 - p) / 4
    else
        return (1 + p) / 4
    end
end

local function orient2d(ax, ay, bx, by, cx, cy)
    return (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
end

local function new_array(n) -- 0-based array
    local out = {}
    for i = 0, n - 1 do
        out[i] = 0
    end
    
    return out
end

local EDGE_STACK = new_array(512)

local function subarray(array, start_index, end_index)
    local result = {}
    for i = start_index, end_index - 1 do
        result[i - start_index] = array[i]
    end
    return result
end

local function sizeof(t)
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

local function fill(array, value)
    for i = 0, sizeof(array) - 1 do
        array[i] = value
    end
end

rt.Delaunator = meta.class("Delaunator")

function rt.Delaunator:instantiate(data)
    local coords = new_array(sizeof(data))

    for i = 1, sizeof(data) do
        coords[i - 1] = data[i]
    end

    self.coords = coords
    local n = sizeof(coords)

    -- arrays that will store the triangulation graph
    local maxTriangles = math.max(2 * n - 5, 0)
    self._triangles = new_array(maxTriangles * 3)
    self._halfedges = new_array(maxTriangles * 3)

    -- temporary arrays for tracking the edges of the advancing convex hull
    self._hashSize = math.ceil(math.sqrt(n))
    self._hullPrev = new_array(n) -- edge to prev edge
    self._hullNext = new_array(n) -- edge to next edge
    self._hullTri = new_array(n) -- edge to adjacent triangle
    self._hullHash = new_array(self._hashSize) -- angular edge hash

    -- temporary arrays for sorting points
    self._ids = new_array(n)
    self._dists = new_array(n)

    self:update()
end

function rt.Delaunator:get_triangles()
    local out = {}
    local n_triangles = math.floor(sizeof(self._triangles) / 3)

    for i = 0, n_triangles - 1 do
        local i1 = self._triangles[3 * i + 0]
        local i2 = self._triangles[3 * i + 1]
        local i3 = self._triangles[3 * i + 2]

        local x1 = self.coords[2 * i1 + 0]
        local y1 = self.coords[2 * i1 + 1]
        local x2 = self.coords[2 * i2 + 0]
        local y2 = self.coords[2 * i2 + 1]
        local x3 = self.coords[2 * i3 + 0]
        local y3 = self.coords[2 * i3 + 1]

        local tri = {
            x1, y1, x2, y2, x3, y3
        }

        table.insert(out, tri)
    end

    return out
end

function rt.Delaunator:_link(a, b)
    self._halfedges[a] = b
    if b ~= -1 then self._halfedges[b] = a end
end

function rt.Delaunator:_addTriangle(i0, i1, i2, a, b, c)
    local t = self.trianglesLen

    self._triangles[t] = i0
    self._triangles[t + 1] = i1
    self._triangles[t + 2] = i2

    self:_link(t, a)
    self:_link(t + 1, b)
    self:_link(t + 2, c)

    self.trianglesLen = self.trianglesLen + 3

    return t
end

function rt.Delaunator:_hashKey(x, y) 
    return math.floor(pseudoAngle(x - self._cx, y - self._cy) * self._hashSize) % self._hashSize;
end

function rt.Delaunator:_legalize(a)
    local self = self
    local triangles = self._triangles
    local halfedges = self._halfedges
    local coords = self.coords

    local i = 0;
    local ar = 0;

    while (true) do
        local b = halfedges[a];

        local a0 = a - a % 3;
        ar = a0 + (a + 2) % 3;

        if b == -1 then -- convex hull edge
            if (i == 0) then break end;
            a = EDGE_STACK[i];
            i = i - 1
            goto continue
        end

        local b0 = b - b % 3;
        local al = a0 + (a + 1) % 3;
        local bl = b0 + (b + 2) % 3;

        local p0 = triangles[ar];
        local pr = triangles[a];
        local pl = triangles[al];
        local p1 = triangles[bl];

        local illegal = inCircle(
            coords[2 * p0], coords[2 * p0 + 1],
            coords[2 * pr], coords[2 * pr + 1],
            coords[2 * pl], coords[2 * pl + 1],
            coords[2 * p1], coords[2 * p1 + 1]
        );

        if illegal then
            triangles[a] = p1;
            triangles[b] = p0;

            local hbl = halfedges[bl];

            if hbl == -1 then
                local e = self._hullStart
                repeat
                    if self._hullTri[e] == bl then
                        self._hullTri[e] = a
                        break
                    end

                    e = self._hullPrev[e]
                until e == self._hullStart
            end

            self:_link(a, hbl)
            self:_link(b, halfedges[ar])
            self:_link(ar, bl)

            local br = b0 + (b + 1) % 3;

            if i < sizeof(EDGE_STACK) then
                EDGE_STACK[i] = br;
                i = i + 1
            end
        else
            if i == 0 then break end
            a = EDGE_STACK[i]
            i = i - 1
        end
        
        ::continue::
    end

    return ar
end

function rt.Delaunator:update()
    local coords = self.coords
    local hullPrev = self._hullPrev
    local hullNext = self._hullNext
    local hullTri = self._hullTri
    local hullHash = self._hullHash

    local n = bit.rshift(sizeof(coords), 1)

    local minX = math.huge;
    local minY = math.huge;
    local maxX = -math.huge;
    local maxY = -math.huge;

    for i = 0, n - 1 do
        local x = coords[2 * i];
        local y = coords[2 * i + 1];
        if x < minX then minX = x end
        if y < minY then minY = y end
        if x > maxX then maxX = x end
        if y > maxY then maxY = y end
        self._ids[i] = i;
    end

    local cx = (minX + maxX) / 2;
    local cy = (minY + maxY) / 2;

    local i0, i1, i2;

    do -- pick a seed point close to the center
        local minDist = math.huge
        for i = 0, n - 1 do
            local d = dist(cx, cy, coords[2 * i], coords[2 * i + 1]);
            if d < minDist then
                i0 = i;
                minDist = d;
            end
        end
    end

    local i0x = coords[2 * i0];
    local i0y = coords[2 * i0 + 1];

    do -- find the point closest to the seed
        local minDist = math.huge
        for i = 0, n - 1 do
            if i ~= i0 then
                local d = dist(i0x, i0y, coords[2 * i], coords[2 * i + 1]);
                if d < minDist and d > 0 then
                    i1 = i
                    minDist = d
                end
            end
        end
    end

    local i1x = coords[2 * i1];
    local i1y = coords[2 * i1 + 1];

    local minRadius = math.huge;

    -- find the third point which forms the smallest circumcircle with the first two
    for i = 0, n - 1 do
        if not (i == i0 or i == i1) then
            local r = circumradius(i0x, i0y, i1x, i1y, coords[2 * i], coords[2 * i + 1]);
            if r < minRadius then
                i2 = i;
                minRadius = r;
            end
        end
    end

    local i2x = coords[2 * i2];
    local i2y = coords[2 * i2 + 1];

    if minRadius == math.huge then
        -- order collinear points by dx (or dy if all x are identical)
        -- and return the list as a hull

        for i = 0, n - 1 do
            self._dists[i] = coords[2 * i] - coords[0]
            if self._dists[i] == 0 then
                self._dists[i] = coords[2 * i + 1] - coords[1]
            end
        end

        quicksort(self._ids, self._dists, 0, n - 1)
        local hull = new_array(n)
        local j = 0
        do
            local d0 = -math.huge
            for i = 0, n - 1 do
                local id = self._ids
                local d = self._dists[id]
                if d > d0 then
                    hull[j] = id
                    j = j + 1
                    d0 = d
                end
            end
        end

        self.hull = subarray(hull, 0, j)
        self.triangles = new_array(0)
        self.halfedges = new_array(0)
        return
    end

    if orient2d(i0x, i0y, i1x, i1y, i2x, i2y) < 0 then
        local i = i1;
        local x = i1x;
        local y = i1y;
        i1 = i2;
        i1x = i2x;
        i1y = i2y;
        i2 = i;
        i2x = x;
        i2y = y;
    end

    local center = circumcenter(i0x, i0y, i1x, i1y, i2x, i2y);
    self._cx = center.x;
    self._cy = center.y;

    for i = 0, n - 1 do
        self._dists[i] = dist(coords[2 * i], coords[2 * i + 1], center.x, center.y);
    end

    -- sort the points by distance from the seed triangle circumcenter
    quicksort(self._ids, self._dists, 0, n - 1);

    -- set up the seed triangle as the starting hull
    self._hullStart = i0;
    local hullSize = 3;

    hullNext[i0] = i1
    hullPrev[i2] = i1
    hullNext[i1] = i2
    hullPrev[i0] = i2
    hullNext[i2] = i0
    hullPrev[i1] = i0

    hullTri[i0] = 0;
    hullTri[i1] = 1;
    hullTri[i2] = 2;

    fill(hullHash, -1)
    hullHash[self:_hashKey(i0x, i0y)] = i0;
    hullHash[self:_hashKey(i1x, i1y)] = i1;
    hullHash[self:_hashKey(i2x, i2y)] = i2;

    self.trianglesLen = 0;
    self:_addTriangle(i0, i1, i2, -1, -1, -1);

    do
        local xp, yp
        for k = 0, sizeof(self._ids) - 1 do
            local i = self._ids[k];
            local x = coords[2 * i];
            local y = coords[2 * i + 1];

            -- skip near-duplicate points
            if k > 0 and math.abs(x - xp) <= EPSILON and math.abs(y - yp) <= EPSILON then goto continue end

            xp = x;
            yp = y;

            -- skip seed triangle points
            if (i == i0 or i == i1 or i == i2) then goto continue end

            -- find a visible edge on the convex hull using edge hash
            local start = 0
            do
                local key = self:_hashKey(x, y)
                for j = 0, self._hashSize - 1 do
                    start = hullHash[(key + j) % self._hashSize];
                    if (start ~= -1 and start ~= hullNext[start]) then break end
                end
            end

            start = hullPrev[start]
            local e = start
            local q
            while true do
                q = hullNext[e]
                if orient2d(
                    x, y,
                    coords[2 * e], coords[2 * e + 1],
                    coords[2 * q], coords[2 * q + 1]
                ) >= 0 then
                    e = q
                    if e == start then
                        e = -1
                        break
                    end
                else
                    break
                end
            end

            if e == -1 then goto continue end -- likely a near-duplicate point; skip it

            -- add the first triangle from the point
            local t = self:_addTriangle(e, i, hullNext[e], -1, -1, hullTri[e]);

            -- recursively flip triangles from the point until they satisfy the Delaunay condition
            hullTri[i] = self:_legalize(t + 2);
            hullTri[e] = t; -- keep track of boundary triangles on the hull
            hullSize = hullSize + 1;

            -- walk forward through the hull, adding more triangles and flipping recursively
            local n = hullNext[e]
            while true do
                q = hullNext[n]
                if orient2d(x, y, coords[2 * n], coords[2 * n + 1], coords[2 * q], coords[2 * q + 1]) < 0 then
                    t = self:_addTriangle(n, i, q, hullTri[i], -1, hullTri[n])
                    hullTri[i] = self:_legalize(t + 2)
                    hullNext[n] = n
                    hullSize = hullSize - 1
                    n = q
                else
                    break
                end
            end

            -- walk backward from the other side, adding more triangles and flipping
            if e == start then
                repeat
                    q = hullPrev[e]
                    if orient2d(x, y, coords[2 * q], coords[2 * q + 1], coords[2 * e], coords[2 * e + 1]) < 0 then
                        t = self:_addTriangle(q, i, e, -1, hullTri[e], hullTri[q])
                        self:_legalize(t + 2)
                        hullTri[q] = t
                        hullNext[e] = e
                        hullSize = hullSize - 1
                        e = q
                    else
                        break
                    end
                until false
            end

            -- update the hull indices
            hullPrev[i] = e
            self._hullStart = hullPrev[i]
            hullPrev[n] = i
            hullNext[e] = hullPrev[n]
            hullNext[i] = n

            -- save the two new edges in the hash table
            hullHash[self:_hashKey(x, y)] = i;
            hullHash[self:_hashKey(coords[2 * e], coords[2 * e + 1])] = e;

            ::continue::
        end

        self.hull = new_array(hullSize)
        do
            local e = self._hullStart
            for i = 0, hullSize - 1 do
                self.hull[i] = e
                e = hullNext[e]
            end
        end

        -- trim typed triangle mesh arrays
        self.triangles = subarray(self._triangles, 0, self.trianglesLen);
        self.halfedges = subarray(self._halfedges, 0, self.trianglesLen);
    end
end

require "common.random"

local tris = {}
local points = {}
local n_points = 200
local instance
do
    local border = 50
    local data = {}
    for i = 1, n_points do
        local point ={
            rt.random.number(border, love.graphics.getWidth() - border),
            rt.random.number(border, love.graphics.getHeight() - border)
        }

        table.insert(data, point[1])
        table.insert(data, point[2])
        table.insert(points, point)
    end

    instance = rt.Delaunator(data)
    tris = instance:get_triangles()
end

function love.draw()
    love.graphics.setLineWidth(1)
    for tri in values(tris) do
        --love.graphics.polygon("line", tri)
    end

    love.graphics.setColor(0, 1, 1, 1)
    for i = 1, sizeof(instance.triangles), 3 do
        local i1, i2, i3 = instance.triangles[i + 0 - 1], instance.triangles[i + 1 - 1], instance.triangles[i + 2 - 1]
        local p1, p2, p3 = points[i1+1], points[i2+1], points[i3+1]
        love.graphics.line(p1[1], p1[2], p2[1], p2[2], p3[1], p3[2], p1[1], p1[2])
    end

    love.graphics.setPointSize(2)
    love.graphics.setColor(1, 0, 1, 1)
    for i = 0, sizeof(instance.coords) - 1, 2 do
        love.graphics.points(instance.coords[i], instance.coords[i+1])
    end

    love.graphics.setColor(0, 1, 0, 1)
    for i = 1, n_points, 1 do
        local point = points[i]
        love.graphics.points(point[1], point[2])
    end

    local hull = {}
    for i = 0, sizeof(instance.hull) - 1 do
        local point = points[instance.hull[i]]
        table.insert(hull, point[1])
        table.insert(hull, point[2])
    end

    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.line(hull)

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
