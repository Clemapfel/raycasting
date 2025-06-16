local _round = function(x)
    return math.floor(x)
end

local _hash_to_points = nil

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

--- @brief construct contour from list of triangles
rt.contour_from_tris = function(tris, close_loop)
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
    _hash_to_points = {}
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

        if not found then
            rt.warning("In rt.contour_from_tris: contour has duplicate edges")
            break
        end -- degenerate contour with duplicate segments
    end

    local contour = {}
    for segment in values(ordered) do
        table.insert(contour, segment[1])
        table.insert(contour, segment[2])
    end
    table.insert(contour, contour[1])
    table.insert(contour, contour[2])

    return contour
end

-- medial_axis.lua
-- Computes the medial axis (skeleton) of a 2D non-convex polygon without holes.
-- Input: flat array of coordinates {x1, y1, x2, y2, ..., xn, yn}
-- Output: list of medial axis segments { {x1, y1, x2, y2}, ... }

local function parse_points(flat)
    local points = {}
    for i = 1, #flat, 2 do
        table.insert(points, {flat[i], flat[i+1]})
    end
    return points
end

-- Helper: Euclidean distance
local function dist(a, b)
    local dx, dy = a[1] - b[1], a[2] - b[2]
    return math.sqrt(dx*dx + dy*dy)
end

-- Helper: Point-in-polygon test (ray casting)
local function point_in_polygon(pt, poly)
    local x, y = pt[1], pt[2]
    local inside = false
    local n = #poly
    for i = 1, n do
        local j = (i % n) + 1
        local xi, yi = poly[i][1], poly[i][2]
        local xj, yj = poly[j][1], poly[j][2]
        if ((yi > y) ~= (yj > y)) and
            (x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi) then
            inside = not inside
        end
    end
    return inside
end

-- Helper: Compute Voronoi diagram (brute-force, for small N)
local function compute_voronoi(points, bbox, grid_step)
    -- Returns Voronoi edges as pairs of points
    -- bbox = {xmin, ymin, xmax, ymax}
    -- grid_step: sampling resolution
    local edges = {}
    local width = bbox[3] - bbox[1]
    local height = bbox[4] - bbox[2]
    local grid = {}
    for x = bbox[1], bbox[3], grid_step do
        for y = bbox[2], bbox[4], grid_step do
            -- Find two closest sites
            local dists = {}
            for i, p in ipairs(points) do
                table.insert(dists, {dist = dist({x, y}, p), idx = i})
            end
            table.sort(dists, function(a, b) return a.dist < b.dist end)
            -- If equidistant to two sites, this is a Voronoi edge point
            if math.abs(dists[1].dist - dists[2].dist) < grid_step * 0.7 then
                table.insert(grid, {x, y})
            end
        end
    end
    -- Connect nearby Voronoi edge points into segments
    for i = 1, #grid do
        local a = grid[i]
        for j = i+1, #grid do
            local b = grid[j]
            if dist(a, b) < grid_step * 1.5 then
                table.insert(edges, {a[1], a[2], b[1], b[2]})
            end
        end
    end
    return edges
end

function rt.medial_axis_from_contour(flat, grid_step)
    local points = parse_points(flat)
    -- Compute bounding box
    local xmin, ymin, xmax, ymax = points[1][1], points[1][2], points[1][1], points[1][2]
    for _, p in ipairs(points) do
        if p[1] < xmin then xmin = p[1] end
        if p[1] > xmax then xmax = p[1] end
        if p[2] < ymin then ymin = p[2] end
        if p[2] > ymax then ymax = p[2] end
    end
    -- Slightly expand bbox
    local pad = grid_step * 2
    local bbox = {xmin - pad, ymin - pad, xmax + pad, ymax + pad}
    -- Compute Voronoi edges
    local vor_edges = compute_voronoi(points, bbox, grid_step)
    -- Filter: keep only edges whose midpoints are inside the polygon
    local medial = {}
    for _, seg in ipairs(vor_edges) do
        local mx = (seg[1] + seg[3]) / 2
        local my = (seg[2] + seg[4]) / 2
        if point_in_polygon({mx, my}, points) then
            table.insert(medial, seg)
        end
    end

    return medial
end
