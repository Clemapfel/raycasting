require "common.delaunay_triangulation"
require "common.path"

rt.settings.overworld.shatter_surface = {
    line_density = 1 / 30,
    seed_density = 1 / 20, -- seed every n px

    max_offset = 5, -- px
    angle_offset = 0.005,
    merge_probability = 0
}


--- @class ow.ShatterSurface
ow.ShatterSurface = meta.class("ShatterSurface")

--- @brief
function ow.ShatterSurface:instantiate(x, y, width, height)
    self._bounds = rt.AABB(x, y, width, height)
end

local clip_polygon_to_rect -- sutherland–hodgman polygon clipping against rect
do
    -- edge functions: return true if inside, or intersection if last arg is true
    local left = function(x, y, nx, ny, rx, ry, rw, rh, want_intersect)
        if not want_intersect then return x >= rx end
        local dx, dy = nx - x, ny - y
        local t = (rx - x) / (dx ~= 0 and dx or math.eps)
        return rx, y + t * dy
    end

    local right = function(x, y, nx, ny, rx, ry, rw, rh, want_intersect)
        if not want_intersect then return x <= rx + rw end
        local dx, dy = nx - x, ny - y
        local t = ((rx + rw) - x) / (dx ~= 0 and dx or math.eps)
        return rx + rw, y + t * dy
    end

    local top = function(x, y, nx, ny, rx, ry, rw, rh, want_intersect)
        if not want_intersect then return y >= ry end
        local dx, dy = nx - x, ny - y
        local t = (ry - y) / (dy ~= 0 and dy or math.eps)
        return x + t * dx, ry
    end

    local bottom = function(x, y, nx, ny, rx, ry, rw, rh, want_intersect)
        if not want_intersect then return y <= ry + rh end
        local dx, dy = nx - x, ny - y
        local t = ((ry + rh) - y) / (dy ~= 0 and dy or math.eps)
        return x + t * dx, ry + rh
    end

    local function clip_edge(input, rx, ry, rw, rh, edge_fn)
        local output = {}
        local n = #input
        if n == 0 then return output end

        local sx, sy = input[n-1], input[n]
        for i = 1, n, 2 do
            local ex, ey = input[i], input[i+1]
            local s_in = edge_fn(sx, sy, nil, nil, rx, ry, rw, rh, false)
            local e_in = edge_fn(ex, ey, nil, nil, rx, ry, rw, rh, false)
            if e_in then
                if not s_in then
                    -- entering: add intersection
                    local ix, iy = edge_fn(sx, sy, ex, ey, rx, ry, rw, rh, true)
                    output[#output+1] = ix
                    output[#output+1] = iy
                end
                -- always add end point if inside
                output[#output+1] = ex
                output[#output+1] = ey
            elseif s_in then
                -- exiting: add intersection
                local ix, iy = edge_fn(sx, sy, ex, ey, rx, ry, rw, rh, true)
                output[#output+1] = ix
                output[#output+1] = iy
            end
            sx, sy = ex, ey
        end
        return output
    end

    local polygon_fully_outside_aabb = function(vertices, x, y, w, h)
        local minx, miny, maxx, maxy = x, y, x+w, y+h
        local n = #vertices
        if n < 6 then return true end

        local all_left, all_right = true, true
        local all_top,  all_bottom = true, true

        for i = 1, n, 2 do
            local vx, vy = vertices[i], vertices[i+1]
            if vx >= minx then all_left = false end
            if vx <= maxx then all_right = false end
            if vy >= miny then all_top = false end
            if vy <= maxy then all_bottom = false end
            if not (all_left or all_right or all_top or all_bottom) then
                break
            end
        end
        if all_left or all_right or all_top or all_bottom then
            return true
        end

        return false
    end

    clip_polygon_to_rect = function(vertices, rx, ry, rw, rh)
        if not vertices or #vertices < 6 or #vertices % 2 ~= 0 then
            return nil
        end

        if polygon_fully_outside_aabb(vertices, rx, ry, rw, rh) then return nil end

        local out = vertices
        for fn in range(left, right, top, bottom) do
            out = clip_edge(out, rx, ry, rw, rh, fn)
            if #out == 0 then return nil end
        end

        return out
    end
end

local compute_voronoi
do
    local function circumcenter(x1, y1, x2, y2, x3, y3)
        local d = 2 * (x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2))
        if math.abs(d) < math.eps then return nil, nil end

        local ux = ((x1 * x1 + y1 * y1) * (y2 - y3) + (x2 * x2 + y2 * y2) * (y3 - y1) + (x3 * x3 + y3 * y3) * (y1 - y2)) / d
        local uy = ((x1 * x1 + y1 * y1) * (x3 - x2) + (x2 * x2 + y2 * y2) * (x1 - x3) + (x3 * x3 + y3 * y3) * (x2 - x1)) / d

        return ux, uy
    end

    function compute_voronoi(sites, bounds_x, bounds_y, bounds_w, bounds_h)
        local n = math.floor(#sites / 2)

        local cells = {}
        for i = 1, n do
            cells[i] = {}
        end

        local map = rt.DelaunayTriangulation(sites):get_triangle_vertex_map()

        for i = 1, #map, 3 do
            local i1, i2, i3 = map[i+0], map[i+1], map[i+2]
            local x1, y1 = sites[(i1-1)*2+1], sites[(i1-1)*2+2]
            local x2, y2 = sites[(i2-1)*2+1], sites[(i2-1)*2+2]
            local x3, y3 = sites[(i3-1)*2+1], sites[(i3-1)*2+2]

            local cx, cy = circumcenter(x1, y1, x2, y2, x3, y3)
            if cx and cy then
                for cell_i in range(i1, i2, i3) do
                    local verts = cells[cell_i]
                    verts[#verts+1] = cx
                    verts[#verts+1] = cy
                end
            end
        end

        for i = 1, n do
            local verts = cells[i]
            if #verts >= 6 then
                local site_x, site_y = sites[(i-1)*2+1], sites[(i-1)*2+2]

                -- sort vertices by angle
                local indices = {}
                local index_to_angle = {}
                for j = 1, #verts, 2 do
                    local vx, vy = verts[j], verts[j+1]
                    indices[#indices+1] = j
                    index_to_angle[j] = math.angle(vx - site_x, vy - site_y)
                end
                table.sort(indices, function(a, b) return index_to_angle[a] < index_to_angle[b] end)

                local vertices = {}
                for idx in values(indices) do
                    vertices[#vertices +1] = verts[idx]
                    vertices[#vertices +1] = verts[idx+1]
                end
                cells[i] = vertices
            else
                cells[i] = {}
            end
        end

        return cells
    end
end

function intersection(origin_x, origin_y, dx, dy, x1, y1, x2, y2)
    local sx, sy = x2 - x1, y2 - y1
    local det = dx * (-sy) + dy * sx
    if math.abs(det) < math.eps then
        return nil
    end

    -- solve for t and u using Cramer's Rule
    local tx = x1 - origin_x
    local ty = y1 - origin_y
    local t = (tx * (-sy) + ty * sx) / det
    local u = (dx * ty - dy * tx) / det

    if t < 0 or u < 0 or u > 1 then
        return nil
    end

    local ix = origin_x + dx * t
    local iy = origin_y + dy * t
    return ix, iy
end

local function convex_hull(vertices)
    local n = #vertices
    if n < 6 then return vertices end -- Need at least 3 points (6 numbers)

    -- Convert flat list to point array for easier manipulation
    local points = {}
    for i = 1, n, 2 do
        points[#points + 1] = {vertices[i], vertices[i + 1]}
    end

    local num_points = #points
    if num_points < 3 then return vertices end

    -- Sort points lexicographically (first by x, then by y)
    table.sort(points, function(a, b)
        return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
    end)

    -- Cross product of vectors OA and OB where O is origin
    -- Returns > 0 for counter-clockwise, < 0 for clockwise, 0 for collinear
    local function cross(o, a, b)
        return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1])
    end

    -- Build lower hull
    local lower = {}
    for i = 1, num_points do
        -- Remove points that make clockwise turn
        while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], points[i]) <= 0 do
            lower[#lower] = nil
        end
        lower[#lower + 1] = points[i]
    end

    -- Build upper hull
    local upper = {}
    for i = num_points, 1, -1 do
        -- Remove points that make clockwise turn
        while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], points[i]) <= 0 do
            upper[#upper] = nil
        end
        upper[#upper + 1] = points[i]
    end

    -- Remove last point of each half because it's repeated
    lower[#lower] = nil
    upper[#upper] = nil

    -- Concatenate lower and upper hull
    local hull = {}
    for i = 1, #lower do
        hull[#hull + 1] = lower[i]
    end
    for i = 1, #upper do
        hull[#hull + 1] = upper[i]
    end

    -- Convert back to flat list
    local result = {}
    for i = 1, #hull do
        result[#result + 1] = hull[i][1]
        result[#result + 1] = hull[i][2]
    end

    return result
end

--- @brief
function ow.ShatterSurface:shatter(origin_x, origin_y)
    meta.assert(origin_x, "Number", origin_y, "Number")
    self._parts = {}

    local settings = rt.settings.overworld.shatter_surface

    local min_x, min_y = self._bounds.x, self._bounds.y
    local max_x, max_y = self._bounds.x + self._bounds.width, self._bounds.y + self._bounds.height
    local path = rt.Path(
        min_x, min_y,
        max_x, min_y,
        max_x, max_y,
        min_x, max_y,
        min_x, min_y
    )

    local seeds = {}
    local point_easing = rt.InterpolationFunctions.LINEAR

    local get_intersection = function(angle)
        local dx, dy = math.cos(angle), math.sin(angle)

        local ix, iy
        ix, iy = intersection(origin_x, origin_y, dx, dy, min_x, min_y, max_x, min_y)
        if ix ~= nil and iy ~= nil then return ix, iy end

        ix, iy = intersection(origin_x, origin_y, dx, dy, max_x, min_y, max_x, max_y)
        if ix ~= nil and iy ~= nil then return ix, iy end

        ix, iy = intersection(origin_x, origin_y, dx, dy, max_x, max_y, min_x, max_y)
        if ix ~= nil and iy ~= nil then return ix, iy end

        ix, iy = intersection(origin_x, origin_y, dx, dy, min_x, max_y, min_x, min_y)
        if ix ~= nil and iy ~= nil then return ix, iy end

        return nil
    end

    -- sample circumference, draw line from origin to that point, then sample line
    local n_lines = path:get_length() * settings.line_density
    for line_i = 0, n_lines - 1 do
        local line_t = line_i / n_lines
        line_t = line_t + rt.random.number(-1, 1) * settings.angle_offset
        local to_x, to_y = get_intersection(line_t * 2 * math.pi)

        local length = math.distance(origin_x, origin_y, to_x, to_y)
        local n_points = length * settings.seed_density
        for point_i = 0, n_points do -- sic, skip center, overshoot
            local point_t = point_easing(point_i / n_points)
            local point_x, point_y = math.mix2(origin_x, origin_y, to_x, to_y, point_t)

            point_x = point_x + rt.random.number(-1, 1) * settings.max_offset
            point_y = point_y + rt.random.number(-1, 1) * settings.max_offset

            table.insert(seeds, point_x)
            table.insert(seeds, point_y)
        end
    end

    -- seeds on corners
    for x in range(
        min_x, min_y,
        max_x, min_y,
        max_x, max_y,
        min_x, max_y
    ) do
        table.insert(seeds, x)
    end

    -- compute voronoi diagram
    local cells = compute_voronoi(seeds, self._bounds.x, self._bounds.y, self._bounds.width, self._bounds.height)

    -- clip to rectangle bounds
    for i, cell in ipairs(cells) do
        if cell and #cell >= 6 then
            local needs_clipping = false
            for vertex_i = 1, #cell, 2 do
                local x, y = cell[vertex_i+0], cell[vertex_i+1]
                if not self._bounds:contains(x, y) then
                    needs_clipping = true
                    break
                end
            end

            local vertices = cell
            if needs_clipping then
                local clipped = clip_polygon_to_rect(cell, self._bounds.x, self._bounds.y, self._bounds.width, self._bounds.height)
                if clipped ~= nil and #clipped >= 6 then
                    vertices = clipped
                end
            end

            table.insert(self._parts, {
                vertices = vertices
            })
        end
    end

    -- classify cells by angle, then merge ones only on subsequent lines
    local angle_to_parts = {}
    for part in values(self._parts) do
        local vertices = part.vertices
        local mean_x, mean_y, n = 0, 0, 0
        for i = 1, #vertices, 2 do
            mean_x = mean_x + vertices[i+0]
            mean_y = mean_y + vertices[i+1]
            n = n + 1
        end

        mean_x = mean_x / n
        mean_y = mean_y / n

        part.x = mean_x
        part.y = mean_y
        local angle = math.normalize_angle(math.angle(mean_x - origin_x, mean_y - origin_y))
        angle = math.floor(angle * n_lines)
        part.angle = angle
        part.color = {0, 0, 0, 0}

        local entry = angle_to_parts[angle]
        if entry == nil then
            entry = {}
            angle_to_parts[angle] = entry
        end
        table.insert(entry, part)
    end

    for entry in values(angle_to_parts) do
        table.sort(entry, function(a, b)
            return math.distance(a.x, a.y, origin_x, origin_y) < math.distance(b.x, b.y, origin_x, origin_y)
        end)
    end

st    local entry_i = 1
    for entry in values(angle_to_parts) do
        for part in values(entry) do
            part.color = { rt.lcha_to_rgba(0.8, 1, (entry_i - 1) / #angle_to_parts, 1) }
        end
        entry_i = entry_i + 1
    end
end

--- @brief
function ow.ShatterSurface:draw()
    love.graphics.setLineWidth(1)
    for part in values(self._parts) do
        if part.vertices ~= nil then
            love.graphics.setColor(part.color)
            love.graphics.polygon("fill", part.vertices)

            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.polygon("line", part.vertices)
        end
    end

    if self._seeds ~= nil then
        for i = 1, #self._seeds, 2 do
            local seed_x, seed_y = self._seeds[i], self._seeds[i + 1]
            love.graphics.circle("fill", seed_x, seed_y, 2)
        end
    end

    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.rectangle("line", self._bounds:unpack())
end