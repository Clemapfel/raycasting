require "common.delaunay_triangulation"
require "common.path"
require "common.graphics_buffer"
require "common.coroutine"

rt.settings.overworld.shatter_surface = {
    line_density = 1 / 30, -- lines per arclength pixel of perimeter
    seed_density = 1 / 40, -- seed every n px

    max_offset = 0.05, -- fraction of line length
    angle_offset = 0.005, -- fraction of 2pi

    cell_size = 5, -- grid size of spatial hash to merge smaller tiles

    -- physics sim
    gravity = 1,
    velocity_magnitude = 100
}

--- @class ow.ShatterSurface
ow.ShatterSurface = meta.class("ShatterSurface")

--- @brief
function ow.ShatterSurface:instantiate(world, x, y, width, height)
    meta.assert(world, "PhysicsWorld")
    self._world = world
    self._bounds = rt.AABB(x, y, width, height)
    self._parts = {}
    self._pre_shatter_mesh = rt.MeshRectangle(x, y, width, height)

    self._is_shattered = false
    self._is_done = false
    self._callback = nil -- coroutine
    self._time_dilation = 1
end

function polygon_area(vertices)
    local area = 0
    local n = #vertices / 2

    -- shoelace formula
    for i = 1, n do
        local j = (i % n) + 1
        local xi = vertices[(i-1) * 2 + 1]
        local yi = vertices[(i-1) * 2 + 2]
        local xj = vertices[(j-1) * 2 + 1]
        local yj = vertices[(j-1) * 2 + 2]

        area = area + (xi * yj) - (xj * yi)
    end

    return math.abs(area / 2)
end

local clip_polygon_to_rect -- sutherland–hodgman polygon clipping against rect
do
    local eps = 10e-4
    -- edge functions: return true if inside, or intersection if last arg is true
    local left = function(x, y, nx, ny, rx, ry, rw, rh, want_intersect)
        if not want_intersect then return x >= rx end
        local dx, dy = nx - x, ny - y
        if math.abs(dx) < eps then return nil, nil end -- Parallel to edge
        local t = (rx - x) / dx
        if t < 0 or t > 1 then return nil, nil end -- Intersection outside segment
        return rx, y + t * dy
    end

    local right = function(x, y, nx, ny, rx, ry, rw, rh, want_intersect)
        if not want_intersect then return x <= rx + rw end
        local dx, dy = nx - x, ny - y
        if math.abs(dx) < eps then return nil, nil end
        local t = ((rx + rw) - x) / dx
        if t < 0 or t > 1 then return nil, nil end
        return rx + rw, y + t * dy
    end

    local top = function(x, y, nx, ny, rx, ry, rw, rh, want_intersect)
        if not want_intersect then return y >= ry end
        local dx, dy = nx - x, ny - y
        if math.abs(dy) < eps then return nil, nil end
        local t = (ry - y) / dy
        if t < 0 or t > 1 then return nil, nil end
        return x + t * dx, ry
    end

    local bottom = function(x, y, nx, ny, rx, ry, rw, rh, want_intersect)
        if not want_intersect then return y <= ry + rh end
        local dx, dy = nx - x, ny - y
        if math.abs(dy) < eps then return nil, nil end
        local t = ((ry + rh) - y) / dy
        if t < 0 or t > 1 then return nil, nil end
        return x + t * dx, ry + rh
    end

    local function clip_edge(input, rx, ry, rw, rh, edge_fn)
        local output = {}
        local n = #input
        if n < 2 then return output end -- Need at least one vertex (x,y pair)

        -- Get the last vertex (properly indexed)
        local sx, sy = input[n-1], input[n]

        for i = 1, n, 2 do
            local ex, ey = input[i], input[i+1]
            local s_in = edge_fn(sx, sy, nil, nil, rx, ry, rw, rh, false)
            local e_in = edge_fn(ex, ey, nil, nil, rx, ry, rw, rh, false)

            if e_in then
                if not s_in then
                    -- entering: add intersection
                    local ix, iy = edge_fn(sx, sy, ex, ey, rx, ry, rw, rh, true)
                    if ix and iy then
                        output[#output+1] = ix
                        output[#output+1] = iy
                    end
                end
                -- always add end point if inside
                output[#output+1] = ex
                output[#output+1] = ey
            elseif s_in then
                -- exiting: add intersection
                local ix, iy = edge_fn(sx, sy, ex, ey, rx, ry, rw, rh, true)
                if ix and iy then
                    output[#output+1] = ix
                    output[#output+1] = iy
                end
            end
            sx, sy = ex, ey
        end
        return output
    end

    function polygon_fully_outside_aabb(polygon, aabb_x, aabb_y, aabb_w, aabb_h)
        local aabb_right = aabb_x + aabb_w
        local aabb_bottom = aabb_y + aabb_h

        local function line_segment_intersects_aabb(x1, y1, x2, y2)
            -- use parametric line equation and check against AABB planes
            local dx = x2 - x1
            local dy = y2 - y1

            -- degenerate line (point)
            if dx == 0 and dy == 0 then
                return x1 >= aabb_x and x1 <= aabb_right and
                    y1 >= aabb_y and y1 <= aabb_bottom
            end

            local t_min = 0
            local t_max = 1

            -- check intersection with vertical planes (left and right)
            if dx ~= 0 then
                local t1 = (aabb_x - x1) / dx
                local t2 = (aabb_right - x1) / dx

                if t1 > t2 then
                    t1, t2 = t2, t1
                end

                t_min = math.max(t_min, t1)
                t_max = math.min(t_max, t2)

                if t_min > t_max then
                    return false
                end
            else
                -- line is vertical, check if it's within x bounds
                if x1 < aabb_x or x1 > aabb_right then
                    return false
                end
            end

            -- check intersection with horizontal planes (top and bottom)
            if dy ~= 0 then
                local t1 = (aabb_y - y1) / dy
                local t2 = (aabb_bottom - y1) / dy

                if t1 > t2 then
                    t1, t2 = t2, t1
                end

                t_min = math.max(t_min, t1)
                t_max = math.min(t_max, t2)

                if t_min > t_max then
                    return false
                end
            else
                -- line is horizontal, check if it's within y bounds
                if y1 < aabb_y or y1 > aabb_bottom then
                    return false
                end
            end

            return true
        end

        -- helper function for point-in-AABB test
        local function point_in_aabb(x, y)
            return x >= aabb_x and x <= aabb_right and
                y >= aabb_y and y <= aabb_bottom
        end

        -- check if any polygon vertex is inside the AABB
        for i = 1, #polygon, 2 do
            local x = polygon[i]
            local y = polygon[i + 1]

            if point_in_aabb(x, y) then
                return false  -- Polygon has vertex inside AABB
            end
        end

        -- check if any polygon edge intersects the AABB
        local num_vertices = math.floor(#polygon / 2)
        for i = 0, num_vertices - 1 do
            local curr_idx = i * 2 + 1
            local next_idx = ((i + 1) % num_vertices) * 2 + 1

            local x1 = polygon[curr_idx]
            local y1 = polygon[curr_idx + 1]
            local x2 = polygon[next_idx]
            local y2 = polygon[next_idx + 1]

            if line_segment_intersects_aabb(x1, y1, x2, y2) then
                return false  -- polygon edge intersects AABB
            end
        end

        -- check if AABB is completely inside the polygon using ray casting
        local test_x = aabb_x + aabb_w * 0.5
        local test_y = aabb_y + aabb_h * 0.5

        local inside_count = 0
        for i = 0, num_vertices - 1 do
            local curr_idx = i * 2 + 1
            local next_idx = ((i + 1) % num_vertices) * 2 + 1

            local x1 = polygon[curr_idx]
            local y1 = polygon[curr_idx + 1]
            local x2 = polygon[next_idx]
            local y2 = polygon[next_idx + 1]

            -- ray casting algorithm
            if ((y1 > test_y) ~= (y2 > test_y)) then
                local intersect_x = x1 + (x2 - x1) * (test_y - y1) / (y2 - y1)
                if test_x < intersect_x then
                    inside_count = inside_count + 1
                end
            end
        end

        local aabb_center_inside_polygon = (inside_count % 2) == 1

        if aabb_center_inside_polygon then
            return false
        end

        return true
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

        coroutine.yield()

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

local function intersection(origin_x, origin_y, dx, dy, x1, y1, x2, y2)
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

local mesh_format = {
    { location = 0, name = rt.VertexAttribute.POSITION, format = "floatvec2" },
    { location = 1, name = rt.VertexAttribute.TEXTURE_COORDINATES, format = "floatvec2" },
    { location = 2, name = rt.VertexAttribute.COLOR, format = "floatvec4" }
}

-- Generate a mesh with an inner region + an outer rim made of quads.
-- The input contour is convex and ordered clockwise.
-- This version fixes quad triangulation (including the closing edge) and adds
-- corner-filling triangles by only appending indices to the vertex map.
local mesh_format = {
    { location = 0, name = rt.VertexAttribute.POSITION, format = "floatvec2" },
    { location = 1, name = rt.VertexAttribute.TEXTURE_COORDINATES, format = "floatvec2" },
    { location = 2, name = rt.VertexAttribute.COLOR, format = "floatvec4" }
}

-- Generate a mesh with an inner region + an outer rim made of quads.
-- The input contour is convex and ordered clockwise.
-- This version fixes quad triangulation (including the closing edge) and adds
-- corner-filling triangles by only appending indices to the vertex map.
local function generate_mesh(contour, rim_thickness)
    if rim_thickness == nil then rim_thickness = 2 end
    contour = table.deepcopy(contour)

    -- compute inner region + UVs from AABB
    local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
    for i = 1, #contour, 2 do
        local x, y = contour[i + 0], contour[i + 1]
        min_x = math.min(min_x, x)
        min_y = math.min(min_y, y)
        max_x = math.max(max_x, x)
        max_y = math.max(max_y, y)
    end

    local mesh_data = {}
    for i = 1, #contour, 2 do
        local x, y = contour[i + 0], contour[i + 1]
        local u = (max_x ~= min_x) and (x - min_x) / (max_x - min_x) or 0
        local v = (max_y ~= min_y) and (y - min_y) / (max_y - min_y) or 0
        table.insert(mesh_data, {
            x, y,            -- position
            u, v,            -- tex coords
            1, 1, 1, 1       -- rgba
        })
    end

    -- triangulate inner polygon (convex) using existing class
    local vertex_map = rt.DelaunayTriangulation(contour):get_triangle_vertex_map()

    -- attribute shorthands for rim vertices
    local inner = function() return 1, 1, 1, 1, 1, 1 end -- uv=(1,1), color=white
    local rim_inner = function() return 1, 1, 0, 0, 0, 1  end
    local rim_outer = function() return 1, 1, 0, 0, 0, 1 end -- uv=(1,1), color=black

    local n_vertices_inner = #contour / 2
    local vertex_i = #mesh_data -- start index for newly appended rim vertices

    -- Build quads per edge, including the closing edge from last->first.
    -- For edge k: v_k -> v_next, we append 4 vertices:
    --   base+1: duplicate inner v_k
    --   base+2: outer of v_k
    --   base+3: duplicate inner v_next
    --   base+4: outer of v_next
    -- Then add two triangles: (base+1, base+2, base+3) and (base+3, base+2, base+4)
    for k = 1, n_vertices_inner do
        local next_k = math.wrap(k + 1, n_vertices_inner)

        local i1 = 2 * k - 1
        local i2 = 2 * k
        local i3 = 2 * next_k - 1
        local i4 = 2 * next_k

        local x1, y1 = contour[i1], contour[i2]
        local x2, y2 = contour[i3], contour[i4]

        -- outward normal (clockwise winding guaranteed)
        local dx, dy = math.turn_left(math.normalize(x2 - x1, y2 - y1))
        dx = dx * rim_thickness
        dy = dy * rim_thickness

        local outer_x1, outer_y1 = x1 + dx, y1 + dy
        local outer_x2, outer_y2 = x2 + dx, y2 + dy

        -- append rim quad vertices
        table.insert(mesh_data, { x1,        y1,        rim_inner() })
        table.insert(mesh_data, { outer_x1,  outer_y1,  rim_outer() })
        table.insert(mesh_data, { x2,        y2,        rim_inner() })
        table.insert(mesh_data, { outer_x2,  outer_y2,  rim_outer() })

        local base = vertex_i
        -- triangulate the quad for this edge
        for j in range(
            base + 1, base + 2, base + 3, -- tri 1
            base + 3, base + 2, base + 4  -- tri 2
        ) do
            table.insert(vertex_map, j)
        end

        vertex_i = vertex_i + 4
    end

    -- Fill corner gaps between adjacent quads using only rim vertices.
    -- For each corner k, we'll use:
    -- - The duplicate inner vertex for this corner (base_curr + 1)
    -- - The outer vertex from previous edge (base_prev + 4)
    -- - The outer vertex from current edge (base_curr + 2)
    for k = 1, n_vertices_inner do
        local prev_k = math.wrap(k - 1, n_vertices_inner)

        local base_curr = n_vertices_inner + (k - 1) * 4
        local base_prev = n_vertices_inner + (prev_k - 1) * 4

        -- Use the duplicate inner vertex (base_curr + 1) instead of original inner vertex
        local inner_dup = base_curr + 1
        local outer_prev = base_prev + 4  -- previous edge's outer at its end (vertex k)
        local outer_curr = base_curr + 2  -- current edge's outer at its start (vertex k)

        for j in range(inner_dup, outer_prev, outer_curr) do
            table.insert(vertex_map, j)
        end
    end

    -- build mesh
    local mesh = rt.Mesh(
        mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        mesh_format,
        rt.GraphicsBufferUsage.STATIC
    )
    mesh:set_vertex_map(vertex_map)
    return mesh
end

--- @brief
function ow.ShatterSurface:shatter(origin_x, origin_y)
    meta.assert(origin_x, "Number", origin_y, "Number")

    do
        local cell_size = 2 * rt.settings.overworld.shatter_surface.cell_size
        origin_x = math.clamp(origin_x, self._bounds.x + cell_size, self._bounds.x + self._bounds.width - cell_size)
        origin_y = math.clamp(origin_y, self._bounds.y + cell_size, self._bounds.y + self._bounds.height - cell_size)
    end

    self._parts = {}
    self._is_done = false
    self._is_shattered = true
    self._callback = rt.Coroutine(function()
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

        local point_easing = rt.InterpolationFunctions.LINEAR
        local line_easing = rt.InterpolationFunctions.LINEAR

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

        local cell_size = settings.cell_size
        local seed_hash = {}

        function add_to_spatial_hash(x, y)
            local cells_x = math.ceil((max_x - min_x) / cell_size)
            local cells_y = math.ceil((max_y - min_y) / cell_size)

            local i = math.floor((x - min_x) / cell_size)
            local j = math.floor((y - min_y) / cell_size)

            local linear_i = j * cells_x + i

            if seed_hash[linear_i] == nil then seed_hash[linear_i] = {} end
            table.insert(seed_hash[linear_i], x)
            table.insert(seed_hash[linear_i], y)
        end

        -- sample circumference, draw line from origin to that point, then sample line
        local n_lines = path:get_length() * settings.line_density
        for line_i = 0, n_lines - 1 do
            local line_t = line_easing(line_i / n_lines)
            line_t = line_t + rt.random.number(-1, 1) * settings.angle_offset
            local to_x, to_y = get_intersection(line_t * 2 * math.pi)

            local length = math.distance(origin_x, origin_y, to_x, to_y)
            local n_points = math.max(length * settings.seed_density, 4)
            for point_i = 0, n_points do -- sic, skip center, overshoot
                local point_t = point_easing(point_i / n_points) + rt.random.number(-1, 0) * settings.max_offset
                add_to_spatial_hash(math.mix2(origin_x, origin_y, to_x, to_y, point_t))
            end
        end

        local seeds = {}

        for i = 1, math.floor(self._bounds.width * self._bounds.height * settings.seed_density / 16) do
            add_to_spatial_hash(
                self._bounds.x + cell_size + rt.random.number(0, 1) * (self._bounds.width - cell_size),
                self._bounds.y + cell_size + rt.random.number(0, 1) * (self._bounds.height - cell_size)
            )
        end

        for entry in values(seed_hash) do
            local mean_x, mean_y, n = 0, 0, 0
            for i = 1, #entry, 2 do
                mean_x = mean_x + entry[i+0]
                mean_y = mean_y + entry[i+1]
                n = n + 1
            end
            table.insert(seeds, mean_x / n)
            table.insert(seeds, mean_y / n)
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

        coroutine.yield()

        -- compute voronoi diagram
        local cells = compute_voronoi(seeds, self._bounds.x, self._bounds.y, self._bounds.width, self._bounds.height)

        coroutine.yield()

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

        local max_distance = -math.huge
        local min_mass, max_mass = math.huge, -math.huge
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

            for i = 1, #vertices, 2 do
                vertices[i+0] = vertices[i+0] - mean_x
                vertices[i+1] = vertices[i+1] - mean_y
            end

            part.x = mean_x
            part.y = mean_y
            part.centroid_x = mean_x
            part.centroid_y = mean_y
            part.angle = 0
            part.distance = math.distance(part.x, part.y, origin_x, origin_y)
            part.mass = polygon_area(part.vertices)

            min_mass = math.min(min_mass, part.mass)
            max_mass = math.max(max_mass, part.mass)
            max_distance = math.max(max_distance, part.distance)
        end

        -- generate meshes

        self._n_vertices_to_data = {}
        local n_vertices_to_instance_part = {}

        local entry_i = 1
        for part in values(self._parts) do
            part.color = { rt.lcha_to_rgba(0.8, 1, (entry_i - 1) / #self._parts, 1) }
            part.mass = (part.mass - min_mass) / (max_mass - min_mass) -- normalize mass
            part.velocity_magnitude = math.mix(1, 2, (1 - part.distance / max_distance)) * settings.velocity_magnitude

            local n_vertices = math.floor(#part.vertices / 2)
            part.n_vertices = n_vertices

            part.body = b2.Body(self._world, b2.BodyType.DYNAMIC, part.x, part.y, b2.Polygon(part.vertices))
            part.body:add_tag("stencil", "unjumpable", "slippery")
            local vx, vy = math.normalize(part.x - origin_x, part.y - origin_y)
            part.body:set_velocity(vx * settings.velocity_magnitude, vy * settings.velocity_magnitude)
            part.mesh = generate_mesh(part.vertices)

            entry_i = entry_i + 1
        end

        self._is_done = true

    end):start()
end

--- @brief
function ow.ShatterSurface:update(delta)
    if not self._is_shattered then return end

    -- distribute load over multiple frames
    if not self._callback:get_is_done() then
        self._callback:resume()
        return
    end
    
    local gravity = rt.settings.overworld.shatter_surface.gravity
    for part in values(self._parts) do
        part.x, part.y = part.body:get_position()
        part.angle = part.body:get_rotation()
    end
end

--- @brief
function ow.ShatterSurface:draw()
    love.graphics.setColor(1, 1, 1, 1)
    if not self._is_done then
        self._pre_shatter_mesh:draw()
    else
        rt.Palette.BLACK:bind()
        for part in values(self._parts) do
            love.graphics.push()
            love.graphics.translate(part.x, part.y)
            love.graphics.rotate(part.angle) -- part centered at origin

            rt.Palette.WHITE:bind()
            love.graphics.draw(part.mesh:get_native())

            rt.Palette.BLACK:bind()
            --love.graphics.polygon("line", part.vertices)
            love.graphics.pop()
        end

        if self._seeds ~= nil then
            for i = 1, #self._seeds, 2 do
                local seed_x, seed_y = self._seeds[i], self._seeds[i + 1]
                love.graphics.circle("fill", seed_x, seed_y, 2)
            end
        end
    end
end

--- @brief
function ow.ShatterSurface:set_time_dilation(t)
    self._time_dilation = math.clamp(t, math.eps, 1)
    for part in values(self._parts) do
        part.body:set_damping(1 - t)
    end
end