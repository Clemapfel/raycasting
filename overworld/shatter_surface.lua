require "common.delaunay_triangulation"
require "common.path"

rt.settings.overworld.shatter_surface = {
    line_density = 1 / 30,
    seed_density = 1 / 40, -- seed every n px

    max_offset = 0.05, -- fraction of line length
    angle_offset = 0.005,
    merge_probability = 0.1,
    gravity = 4,
    velocity_magnitude = 40,

    cell_size = 20
}


--- @class ow.ShatterSurface
ow.ShatterSurface = meta.class("ShatterSurface")

local _shader

--- @brief
function ow.ShatterSurface:instantiate(x, y, width, height)
    if _shader == nil then _shader = rt.Shader("overworld/shatter_surface.glsl") end
    self._texture = rt.Texture("assets/sprites/barboach.png")
    self._bounds = rt.AABB(x, y, width, height)
    self._parts = {}
    self._n_vertices_to_static_data = {}
    self._n_vertices_to_instance_mesh = {}
    self._n_vertices_to_data_mesh = {}
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

local _position = rt.VertexAttribute.POSITION
local _texture_coords = rt.VertexAttribute.TEXTURE_COORDINATES
local _offset = "offset"

local _instance_mesh_format = {
    { location = 0, name = _position, format = "floatvec2" },
    { location = 1, name = _texture_coords, format = "floatvec2" }
}

local _static_data_mesh_format = {
    { location = 0, name = _position, format = "floatvec2" },
    { location = 1, name = _texture_coords, format = "floatvec2" }
}

local _offset_mesh_format = {
    { location = 0, name = _offset, format = "floatvec2" }
}

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
        local n_points = length * settings.seed_density
        for point_i = 0, n_points do -- sic, skip center, overshoot
            local point_t = point_easing(point_i / n_points) + rt.random.number(-1, 0) * settings.max_offset
            add_to_spatial_hash(math.mix2(origin_x, origin_y, to_x, to_y, point_t))
        end
    end

    local seeds = {}
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
        part.velocity_x, part.velocity_y = math.normalize(part.x - origin_x, part.y - origin_y)
        part.distance = math.distance(part.x, part.y, origin_x, origin_y)
        part.mass = polygon_area(part.vertices)

        min_mass = math.min(min_mass, part.mass)
        max_mass = math.max(max_mass, part.mass)
        max_distance = math.max(max_distance, part.distance)
    end

    -- generate meshes for instancing

    self._n_vertices_to_static_data = {}
    self._n_vertices_to_instance_mesh = {}
    self._n_vertices_to_instance_count = {}
    self._n_vertices_to_offset_data = {}

    local entry_i = 1
    for part in values(self._parts) do
        part.color = { rt.lcha_to_rgba(0.8, 1, (entry_i - 1) / #self._parts, 1) }
        part.mass = (part.mass - min_mass) / (max_mass - min_mass) -- normalize mass
        part.velocity_magnitude = (1 + 1 - part.distance / max_distance) * settings.velocity_magnitude

        local n_vertices = math.floor(#part.vertices / 2)

        local static_data_entry = {}
        local offset_data_entry = {}

        for i = 1, #part.vertices, 2 do
            local x = part.vertices[i+0]
            local y = part.vertices[i+1]
            local u = ((x + part.x) - min_x) / (max_x - min_x)
            local v = ((y + part.y) - min_y) / (max_y - min_y)
            table.insert(static_data_entry, {
                x, y, u, v
            })

            table.insert(offset_data_entry, {
                part.x, part.y
            })
        end

        part.static_data = static_data_entry
        part.offset = offset_data_entry
        part.n_vertices = n_vertices

        local count = self._n_vertices_to_instance_count[n_vertices] or 0
        self._n_vertices_to_instance_count[n_vertices] = count + 1

        local static_data = self._n_vertices_to_static_data[n_vertices]
        local offset_data = self._n_vertices_to_offset_data[n_vertices] 
        if static_data == nil then
            -- static data mesh
            static_data = {}
            self._n_vertices_to_static_data[n_vertices] = static_data
            
            -- static instance mesh
            self._n_vertices_to_instance_mesh[n_vertices] = rt.Mesh(
                static_data_entry, -- is overriden anyway
                rt.MeshDrawMode.TRIANGLE_FAN,
                _instance_mesh_format,
                rt.GraphicsBufferUsage.STATIC
            )
            
            -- dynamic offset mesh
            offset_data = {}
            self._n_vertices_to_offset_data[n_vertices] = offset_data
        end

        table.insert(static_data, static_data_entry)
        table.insert(offset_data, offset_data_entry)
        entry_i = entry_i + 1
    end

    for n, instance in pairs(self._n_vertices_to_instance_mesh) do
        local static_data = self._n_vertices_to_static_data[n]
        local static_data_mesh = rt.Mesh(
            static_data,
            rt.MeshDrawMode.POINTS,
            _static_data_mesh_format,
            rt.GraphicsBufferUsage.STATIC
        )
        self._n_vertices_to_data_mesh[n] = static_data_mesh

        local offset_data = self._n_vertices_to_offset_data[n]
        local offset_data_mesh = rt.Mesh(
            offset_data,
            rt.MeshDrawMode.POINTS,
            _offset_mesh_format,
            rt.GraphicsBufferUsage.STREAM
        )
        self._n_vertices_to_static_data[n] = offset_data_mesh

        for entry in values(_static_data_mesh_format) do
            instance:attach_attribute(static_data_mesh, entry.name, rt.MeshAttributeAttachmentMode.PER_INSTANCE)
        end

        for entry in values(_offset_mesh_format) do
            instance:attach_attribute(offset_data_mesh, entry.name, rt.MeshAttributeAttachmentMode.PER_INSTANCE)
        end
    end
end

--- @brief
function ow.ShatterSurface:update(delta)
    if self._parts == nil or #self._parts == 0 then return end

    local gravity = rt.settings.overworld.shatter_surface.gravity

    delta = delta
    for part in values(self._parts) do
        part.velocity_y = part.velocity_y + math.mix(1, 2, part.mass) * gravity * delta

        local vx, vy = part.velocity_x * part.velocity_magnitude, part.velocity_y * part.velocity_magnitude
        part.x = part.x + vx * delta
        part.y = part.y + vy * delta
    end
end

--- @brief
function ow.ShatterSurface:draw()
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)

    _shader:bind()
    for n, instance in pairs(self._n_vertices_to_instance_mesh) do
        instance:draw_instanced(self._n_vertices_to_instance_count[n])
    end
    _shader:unbind()

    if self._seeds ~= nil then
        for i = 1, #self._seeds, 2 do
            local seed_x, seed_y = self._seeds[i], self._seeds[i + 1]
            love.graphics.circle("fill", seed_x, seed_y, 2)
        end
    end

end