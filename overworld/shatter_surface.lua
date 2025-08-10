rt.settings.overworld.shatter_surface = {
    shapes_per_px = 1 / 1000,
    angle_variance = 0, -- in 0, 1
    radius_variance = 0, -- in 0, 1
    merge_probability = 0.5, -- probability of merging neighboring shapes
    radial_angle_tolerance = math.pi / 12 -- tolerance for radial alignment (15 degrees)
}

--- @class ow.ShatterSurface
ow.ShatterSurface = meta.class("ShatterSurface")

--- @brief
function ow.ShatterSurface:instantiate(x, y, width, height)
    self._bounds = rt.AABB(x, y, width, height)
    self:reset()
end

--- @brief
function ow.ShatterSurface:reset()
    self._is_broken = false
    self._parts = {}
end

--- @brief Helper to check if point is inside polygon
local function point_in_polygon(x, y, vertices)
    local inside = false
    local p1x, p1y = vertices[#vertices - 1], vertices[#vertices]
    for i = 1, #vertices, 2 do
        local p2x, p2y = vertices[i], vertices[i + 1]
        if ((p2y > y) ~= (p1y > y)) and (x < (p1x - p2x) * (y - p2y) / (p1y - p2y) + p2x) then
            inside = not inside
        end
        p1x, p1y = p2x, p2y
    end
    return inside
end

--- @brief Helper to clip polygon to rectangle bounds
local function clip_polygon_to_rect(vertices, x, y, w, h)
    local function clip_edge(verts, edge_x, edge_y, edge_w, edge_h, axis, positive)
        local output = {}
        if #verts < 6 then return verts end

        local prev_x, prev_y = verts[#verts - 1], verts[#verts]
        local prev_inside

        if axis == "x" then
            prev_inside = positive and (prev_x <= edge_x + edge_w) or (prev_x >= edge_x)
        else
            prev_inside = positive and (prev_y <= edge_y + edge_h) or (prev_y >= edge_y)
        end

        for i = 1, #verts, 2 do
            local curr_x, curr_y = verts[i], verts[i + 1]
            local curr_inside

            if axis == "x" then
                curr_inside = positive and (curr_x <= edge_x + edge_w) or (curr_x >= edge_x)
            else
                curr_inside = positive and (curr_y <= edge_y + edge_h) or (curr_y >= edge_y)
            end

            if curr_inside ~= prev_inside then
                -- Calculate intersection
                local t
                if axis == "x" then
                    local edge = positive and (edge_x + edge_w) or edge_x
                    t = (edge - prev_x) / (curr_x - prev_x)
                else
                    local edge = positive and (edge_y + edge_h) or edge_y
                    t = (edge - prev_y) / (curr_y - prev_y)
                end

                local int_x = prev_x + t * (curr_x - prev_x)
                local int_y = prev_y + t * (curr_y - prev_y)
                table.insert(output, int_x)
                table.insert(output, int_y)
            end

            if curr_inside then
                table.insert(output, curr_x)
                table.insert(output, curr_y)
            end

            prev_x, prev_y = curr_x, curr_y
            prev_inside = curr_inside
        end

        return output
    end

    -- Clip against all four edges
    vertices = clip_edge(vertices, x, y, w, h, "x", false)  -- left
    vertices = clip_edge(vertices, x, y, w, h, "x", true)   -- right
    vertices = clip_edge(vertices, x, y, w, h, "y", false)  -- top
    vertices = clip_edge(vertices, x, y, w, h, "y", true)   -- bottom

    return vertices
end

--- @brief Generate seeds using Fibonacci spiral pattern
local function generate_seeds(origin_x, origin_y, num_seeds, max_radius, variance)
    local seeds = {}
    local golden_angle = math.pi * (3 - math.sqrt(5))

    -- Add impact point as the center seed
    table.insert(seeds, origin_x)
    table.insert(seeds, origin_y)

    local easing = rt.InterpolationFunctions.LINEAR
    local max_angle_variance = rt.settings.overworld.shatter_surface.angle_variance * 2 * math.pi
    local max_radius_variance = rt.settings.overworld.shatter_surface.radius_variance

    local max_offset = debugger.get("max_offset")

    local n_lines = 32
    local spiral_density_at_edge = math.sqrt(num_seeds) / max_radius
    local average_spiral_spacing = max_radius / math.sqrt(num_seeds)
    local n_steps = math.floor(max_radius / average_spiral_spacing)

    local step = max_radius / n_steps

    for i = 1, n_lines do
        local angle = (i - 1) / n_lines * 2 * math.pi
        angle = angle + rt.random.number(-1, 1) * debugger.get("angle_offset") * 2 * math.pi
        local dx, dy = math.cos(angle), math.sin(angle)
        for j = 1, n_steps do
            local length = easing(j / n_steps) * max_radius

            local offset_x = rt.random.number(-1, 1) * debugger.get("step_x_offset") * step
            local offset_y = rt.random.number(-1, 1) * debugger.get("step_y_offset") * step

            local x = origin_x + dx * (length + offset_x)
            local y = origin_y + dy * (length + offset_y)
            x = x + rt.random.noise(x, y) * rt.random.number(-1, 1) * max_offset * length
            y = y + rt.random.noise(-y, x) * rt.random.number(-1, 1) * max_offset * length

            table.insert(seeds, x)
            table.insert(seeds, y)
        end
    end

    return seeds
end

--- @brief Fast Voronoi diagram computation using Fortune's algorithm
local VoronoiComputer = {}

function VoronoiComputer:new()
    local obj = {
        sites = {},
        edges = {},
        cells = {},
        events = {},
        beachline = {},
        sweep_y = 0
    }
    setmetatable(obj, { __index = self })
    return obj
end

-- Distance squared between two points (using flat arrays)
local function dist_sq(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return dx * dx + dy * dy
end

-- Calculate parabola intersection
local function get_parabola_intersection(site1_x, site1_y, site2_x, site2_y, sweep_y)
    local dp = 2 * (site1_y - sweep_y)
    if math.abs(dp) < 1e-10 then
        return (site1_x + site2_x) / 2
    end

    local a1 = 1 / dp
    local b1 = -2 * site1_x / dp
    local c1 = (site1_x * site1_x + site1_y * site1_y - sweep_y * sweep_y) / dp

    dp = 2 * (site2_y - sweep_y)
    if math.abs(dp) < 1e-10 then
        return (site1_x + site2_x) / 2
    end

    local a2 = 1 / dp
    local b2 = -2 * site2_x / dp
    local c2 = (site2_x * site2_x + site2_y * site2_y - sweep_y * sweep_y) / dp

    local a = a1 - a2
    local b = b1 - b2
    local c = c1 - c2

    if math.abs(a) < 1e-10 then
        return -c / b
    end

    local disc = b * b - 4 * a * c
    if disc < 0 then return nil end

    local x1 = (-b + math.sqrt(disc)) / (2 * a)
    local x2 = (-b - math.sqrt(disc)) / (2 * a)

    -- Return the intersection closer to the sites
    if math.abs(x1 - (site1_x + site2_x) / 2) < math.abs(x2 - (site1_x + site2_x) / 2) then
        return x1
    else
        return x2
    end
end

-- Calculate circumcenter of three points
local function circumcenter(x1, y1, x2, y2, x3, y3)
    local d = 2 * (x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2))
    if math.abs(d) < 1e-10 then return nil, nil end

    local ux = ((x1 * x1 + y1 * y1) * (y2 - y3) + (x2 * x2 + y2 * y2) * (y3 - y1) + (x3 * x3 + y3 * y3) * (y1 - y2)) / d
    local uy = ((x1 * x1 + y1 * y1) * (x3 - x2) + (x2 * x2 + y2 * y2) * (x1 - x3) + (x3 * x3 + y3 * y3) * (x2 - x1)) / d

    return ux, uy
end

function VoronoiComputer:add_site(x, y)
    table.insert(self.sites, {x, y, #self.sites + 1})
end

function VoronoiComputer:compute_voronoi(bounds_x, bounds_y, bounds_w, bounds_h)
    -- Sort sites by y-coordinate
    table.sort(self.sites, function(a, b)
        return a[2] < b[2] or (a[2] == b[2] and a[1] < b[1])
    end)

    -- Initialize cells for each site
    for i = 1, #self.sites do
        self.cells[i] = {}
    end

    -- Simple Delaunay triangulation approach for better performance
    -- This is a simplified version that works well for shatter patterns
    local triangles = self:delaunay_triangulation()

    -- Convert triangulation to Voronoi cells
    for _, tri in ipairs(triangles) do
        local i1, i2, i3 = tri[1], tri[2], tri[3]
        local site1 = self.sites[i1]
        local site2 = self.sites[i2]
        local site3 = self.sites[i3]

        local cx, cy = circumcenter(site1[1], site1[2], site2[1], site2[2], site3[1], site3[2])
        if cx and cy then
            -- Add circumcenter to each site's cell
            if not self.cells[i1].vertices then self.cells[i1].vertices = {} end
            if not self.cells[i2].vertices then self.cells[i2].vertices = {} end
            if not self.cells[i3].vertices then self.cells[i3].vertices = {} end

            table.insert(self.cells[i1].vertices, {cx, cy})
            table.insert(self.cells[i2].vertices, {cx, cy})
            table.insert(self.cells[i3].vertices, {cx, cy})
        end
    end

    -- Sort vertices for each cell and create polygons
    for i = 1, #self.sites do
        if self.cells[i].vertices then
            local site_x, site_y = self.sites[i][1], self.sites[i][2]

            -- Sort vertices by angle around the site
            table.sort(self.cells[i].vertices, function(a, b)
                local angle_a = math.atan2(a[2] - site_y, a[1] - site_x)
                local angle_b = math.atan2(b[2] - site_y, b[1] - site_x)
                return angle_a < angle_b
            end)

            -- Convert to flat array format
            local flat_vertices = {}
            for _, vertex in ipairs(self.cells[i].vertices) do
                table.insert(flat_vertices, vertex[1])
                table.insert(flat_vertices, vertex[2])
            end

            self.cells[i].flat_vertices = flat_vertices
        end
    end
end

-- Simplified Delaunay triangulation using incremental insertion
function VoronoiComputer:delaunay_triangulation()
    local triangles = {}
    local n = #self.sites

    if n < 3 then return triangles end

    -- Create super triangle that encompasses all points
    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge

    for _, site in ipairs(self.sites) do
        min_x = math.min(min_x, site[1])
        min_y = math.min(min_y, site[2])
        max_x = math.max(max_x, site[1])
        max_y = math.max(max_y, site[2])
    end

    local dx, dy = max_x - min_x, max_y - min_y
    local delta_max = math.max(dx, dy)
    local mid_x, mid_y = (min_x + max_x) / 2, (min_y + max_y) / 2

    -- Super triangle vertices
    local super1 = {mid_x - 20 * delta_max, mid_y - delta_max, n + 1}
    local super2 = {mid_x, mid_y + 20 * delta_max, n + 2}
    local super3 = {mid_x + 20 * delta_max, mid_y - delta_max, n + 3}

    table.insert(triangles, {n + 1, n + 2, n + 3})

    -- Add super triangle to sites temporarily
    table.insert(self.sites, super1)
    table.insert(self.sites, super2)
    table.insert(self.sites, super3)

    -- Insert each point
    for i = 1, n do
        local bad_triangles = {}
        local polygon = {}

        -- Find triangles whose circumcircle contains the point
        for j, tri in ipairs(triangles) do
            local site1 = self.sites[tri[1]]
            local site2 = self.sites[tri[2]]
            local site3 = self.sites[tri[3]]

            local cx, cy = circumcenter(site1[1], site1[2], site2[1], site2[2], site3[1], site3[2])
            if cx and cy then
                local radius_sq = dist_sq(cx, cy, site1[1], site1[2])
                local point_dist_sq = dist_sq(cx, cy, self.sites[i][1], self.sites[i][2])

                if point_dist_sq < radius_sq then
                    table.insert(bad_triangles, j)
                    -- Add edges to polygon
                    table.insert(polygon, {tri[1], tri[2]})
                    table.insert(polygon, {tri[2], tri[3]})
                    table.insert(polygon, {tri[3], tri[1]})
                end
            end
        end

        -- Remove bad triangles
        for j = #bad_triangles, 1, -1 do
            table.remove(triangles, bad_triangles[j])
        end

        -- Remove duplicate edges from polygon
        local unique_edges = {}
        for _, edge in ipairs(polygon) do
            local found = false
            for k = #unique_edges, 1, -1 do
                local other = unique_edges[k]
                if (edge[1] == other[1] and edge[2] == other[2]) or
                    (edge[1] == other[2] and edge[2] == other[1]) then
                    table.remove(unique_edges, k)
                    found = true
                    break
                end
            end
            if not found then
                table.insert(unique_edges, edge)
            end
        end

        -- Create new triangles
        for _, edge in ipairs(unique_edges) do
            table.insert(triangles, {edge[1], edge[2], i})
        end
    end

    -- Remove triangles that contain super triangle vertices
    local final_triangles = {}
    for _, tri in ipairs(triangles) do
        if tri[1] <= n and tri[2] <= n and tri[3] <= n then
            table.insert(final_triangles, tri)
        end
    end

    -- Remove super triangle vertices
    for i = 1, 3 do
        table.remove(self.sites)
    end

    return final_triangles
end

--- @brief Helper to clip polygon to rectangle bounds
local function clip_polygon_to_rect(vertices, x, y, w, h)
    local function clip_edge(verts, edge_x, edge_y, edge_w, edge_h, axis, positive)
        local output = {}
        if #verts < 6 then return verts end

        local prev_x, prev_y = verts[#verts - 1], verts[#verts]
        local prev_inside

        if axis == "x" then
            prev_inside = positive and (prev_x <= edge_x + edge_w) or (prev_x >= edge_x)
        else
            prev_inside = positive and (prev_y <= edge_y + edge_h) or (prev_y >= edge_y)
        end

        for i = 1, #verts, 2 do
            local curr_x, curr_y = verts[i], verts[i + 1]
            local curr_inside

            if axis == "x" then
                curr_inside = positive and (curr_x <= edge_x + edge_w) or (curr_x >= edge_x)
            else
                curr_inside = positive and (curr_y <= edge_y + edge_h) or (curr_y >= edge_y)
            end

            if curr_inside ~= prev_inside then
                -- Calculate intersection
                local t
                if axis == "x" then
                    local edge = positive and (edge_x + edge_w) or edge_x
                    t = (edge - prev_x) / (curr_x - prev_x)
                else
                    local edge = positive and (edge_y + edge_h) or edge_y
                    t = (edge - prev_y) / (curr_y - prev_y)
                end

                local int_x = prev_x + t * (curr_x - prev_x)
                local int_y = prev_y + t * (curr_y - prev_y)
                table.insert(output, int_x)
                table.insert(output, int_y)
            end

            if curr_inside then
                table.insert(output, curr_x)
                table.insert(output, curr_y)
            end

            prev_x, prev_y = curr_x, curr_y
            prev_inside = curr_inside
        end

        return output
    end

    -- Clip against all four edges
    vertices = clip_edge(vertices, x, y, w, h, "x", false)  -- left
    vertices = clip_edge(vertices, x, y, w, h, "x", true)   -- right
    vertices = clip_edge(vertices, x, y, w, h, "y", false)  -- top
    vertices = clip_edge(vertices, x, y, w, h, "y", true)   -- bottom

    return vertices
end

--- @brief Optimized shatter function using Voronoi diagram
function ow.ShatterSurface:shatter(origin_x, origin_y)
    self._is_broken = true
    self._parts = {}
    self._origin_x = origin_x
    self._origin_y = origin_y

    local settings = rt.settings.overworld.shatter_surface
    local min_x, min_y = self._bounds.x, self._bounds.y
    local max_x, max_y = self._bounds.x + self._bounds.width, self._bounds.y + self._bounds.height

    local num_shards = math.floor((self._bounds.width * self._bounds.height) * settings.shapes_per_px)
    local max_radius = math.max(self._bounds.width, self._bounds.height) / 2

    -- Generate seeds using existing function
    local seeds = generate_seeds(origin_x, origin_y, num_shards, math.sqrt(2) * max_radius, settings.shatter_variance)
    for x in range(
        min_x, min_y,
        max_x, min_y,
        max_x, max_y,
        min_x, max_y
    ) do
        table.insert(seeds, x)
    end

    self._seeds = seeds

    -- Create Voronoi computer and add sites
    local voronoi = VoronoiComputer:new()
    for i = 1, #seeds, 2 do
        voronoi:add_site(seeds[i], seeds[i + 1])
    end

    -- Compute Voronoi diagram
    voronoi:compute_voronoi(min_x, min_y, self._bounds.width, self._bounds.height)

    -- Convert Voronoi cells to parts
    for i, cell in ipairs(voronoi.cells) do
        if cell.flat_vertices and #cell.flat_vertices >= 6 then
            -- Clip to bounds
            local clipped = clip_polygon_to_rect(cell.flat_vertices, min_x, min_y, self._bounds.width, self._bounds.height)

            if #clipped >= 6 then
                table.insert(self._parts, {
                    vertices = clipped,
                    color = {}
                })
            end
        end
    end

    -- Assign colors
    for i, entry in ipairs(self._parts) do
        entry.color = { rt.lcha_to_rgba(0.8, 0, 2 * i / #self._parts, 1) }
    end
end

--- @brief
function ow.ShatterSurface:draw()
    love.graphics.setLineWidth(1)
    for part in values(self._parts) do
        love.graphics.setColor(part.color)
        love.graphics.polygon("fill", part.vertices)

        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.polygon("line", part.vertices)
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