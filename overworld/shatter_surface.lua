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
    velocity_magnitude = 120,
    player_velocity_influence = 0.08,

    -- visuals
    hue_range = 0.25,
    rim_thickness = 2, -- px
    fade_duration = 0.5, -- seconds, for shape fraction
}

--- @class ow.ShatterSurface
ow.ShatterSurface = meta.class("ShatterSurface")

local mesh_format = {
    { location = 0, name = rt.VertexAttribute.POSITION, format = "floatvec2" },
    { location = 1, name = rt.VertexAttribute.TEXTURE_COORDINATES, format = "floatvec2" },
    { location = 2, name = rt.VertexAttribute.COLOR, format = "floatvec4" }
}

local _shader = rt.Shader("overworld/shatter_surface.glsl")

--- @brief
function ow.ShatterSurface:instantiate(world, x, y, width, height)
    meta.assert(world, "PhysicsWorld")

    self._world = world
    self._bounds = rt.AABB(x, y, width, height)
    self._parts = {}
    self._pre_shatter_mesh = self._generate_mesh({
        x, y,
        x + width, y,
        x + width, y + height,
        x, y + height
    }, x, y, x + width, y + height)

    self._is_shattered = false
    self._time_since_shatter = 0 -- time since shatter
    self._is_done = false
    self._callback = nil -- coroutine
    self._time_dilation = 1 -- fraction
    self._flash = 0 -- white, fraction

    self._impulse = rt.ImpulseSubscriber()

    DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then _shader:recompile() end
    end)
end

--- @brief
function ow.ShatterSurface:shatter(origin_x, origin_y, velocity_x, velocity_y)
    meta.assert(origin_x, "Number", origin_y, "Number")

    do
        local cell_size = 2 * rt.settings.overworld.shatter_surface.cell_size
        origin_x = math.clamp(origin_x, self._bounds.x + cell_size, self._bounds.x + self._bounds.width - cell_size)
        origin_y = math.clamp(origin_y, self._bounds.y + cell_size, self._bounds.y + self._bounds.height - cell_size)
    end

    local outer_bounds = self._bounds

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

        local function add_to_spatial_hash(x, y)
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
        local cells = self._compute_voronoi(seeds, self._bounds.x, self._bounds.y, self._bounds.width, self._bounds.height)

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
                    local clipped = self._clip_polygon_to_rect(cell, self._bounds.x, self._bounds.y, self._bounds.width, self._bounds.height)
                    if clipped ~= nil and #clipped >= 6 then
                        vertices = clipped
                    end
                end

                table.insert(self._parts, {
                    vertices = vertices
                })
            end
        end

        local function polygon_area(vertices)
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
        local hue = rt.GameState:get_player():get_hue()
        local hue_range = 0.5 * rt.settings.overworld.shatter_surface.hue_range
        for part in values(self._parts) do
            part.color = rt.RGBA(rt.lcha_to_rgba(
                rt.random.number(0.6, 0.85),
                1,
                math.fract(math.mix(hue - hue_range, hue + hue_range, part.distance / max_distance)),
                1
            ))

            part.mass = (part.mass - min_mass) / (max_mass - min_mass) -- normalize mass
            part.velocity_magnitude = math.mix(1, 2, (1 - part.distance / max_distance)) * settings.velocity_magnitude

            local n_vertices = math.floor(#part.vertices / 2)
            part.n_vertices = n_vertices

            part.body = b2.Body(self._world, b2.BodyType.DYNAMIC, part.x, part.y, b2.Polygon(part.vertices))
            part.body:add_tag("stencil", "unjumpable", "slippery")

            part.body:add_tag("light_source")
            part.get_color = function(self) return self.color end
            part.body:set_user_data(part)

            local ball_mass = 1
            local shard_mass = part.body:get_mass()
            local t = math.magnitude(
                math.abs(part.x - origin_x) / self._bounds.width,
                math.abs(part.y - origin_y) / self._bounds.height
            )

            local vx, vy = math.normalize(part.x - origin_x, part.y - origin_y)
            vx, vy = math.multiply(vx, vy, settings.velocity_magnitude, settings.velocity_magnitude)

            local influence = rt.settings.overworld.shatter_surface.player_velocity_influence
            vx = vx + velocity_x / (shard_mass * (1 + t)) * influence
            vy = vy + velocity_y / (shard_mass * (1 + t)) * influence

            part.velocity_x = vx
            part.velocity_y = vy
            part.body:set_velocity(vx, vy)
            --part.body:set_collides_with(b2.CollisionGroup.GROUP_07)
            --part.body:set_collision_group(b2.CollisionGroup.GROUP_07)
            part.body:set_restitution(1)
            part.mesh = self._generate_mesh(
                part.vertices,
                outer_bounds.x - part.x - origin_x,
                outer_bounds.y - part.y - origin_y,
                outer_bounds.x + outer_bounds.width - part.x - origin_x,
                outer_bounds.y + outer_bounds.height - part.y - origin_y
            )

            entry_i = entry_i + 1
        end

        self._is_done = true
        self._time_since_shatter = 0

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
    
    self._time_since_shatter = self._time_since_shatter + delta
end

--- @brief
function ow.ShatterSurface:draw()
     love.graphics.setColor(rt.lcha_to_rgba(0.8, 1, rt.GameState:get_player():get_hue() , 1))
    _shader:bind()
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    _shader:send("flash", self._flash)
    _shader:send("fraction", math.clamp(self._time_since_shatter / rt.settings.overworld.shatter_surface.fade_duration, 0, 1))
    _shader:send("draw_bloom", false)
    _shader:send("brightness_scale", math.mix(1, rt.settings.impulse_manager.max_brightness_factor, self._impulse:get_pulse()))
    _shader:send("pulse", self._impulse:get_pulse())

    if not self._is_done then
        self._pre_shatter_mesh:draw()
    else
        for part in values(self._parts) do
            part.color:bind()
            love.graphics.push()
            love.graphics.translate(part.x, part.y)
            love.graphics.rotate(part.angle) -- part centered at origin
            love.graphics.draw(part.mesh:get_native())
            love.graphics.pop()
        end
    end
    _shader:unbind()
end

--- @brief
function ow.ShatterSurface:draw_bloom()
    if not self._is_done then
        love.graphics.setColor(rt.lcha_to_rgba(0.8, 1, rt.GameState:get_player():get_hue() , 1))
        _shader:bind()
        _shader:send("elapsed", rt.SceneManager:get_elapsed())
        _shader:send("fraction", math.clamp(self._time_since_shatter / rt.settings.overworld.shatter_surface.fade_duration, 0, 1))
        _shader:send("draw_bloom", true)
        self._pre_shatter_mesh:draw()
        _shader:unbind()
    end
end

--- @brief
function ow.ShatterSurface:set_time_dilation(t)
    self._time_dilation = math.clamp(t, math.eps, 1)
    for part in values(self._parts) do
        part.body:set_damping(t)
    end
end

--- @brief
function ow.ShatterSurface:set_flash(t)
    self._flash = t
end

--- @brief
function ow.ShatterSurface:reset()
    for part in values(self._parts) do
        part.body:destroy()
    end

    self:instantiate(self._world, self._bounds:unpack())
end

--- @brief
function ow.ShatterSurface._generate_mesh(contour, min_x, min_y, max_x, max_y)
    local rim_thickness = rt.settings.overworld.shatter_surface.rim_thickness
    contour = table.deepcopy(contour)

    local n_vertices = #contour / 2

    -- Build inward offset lines per edge (clockwise polygon assumed).
    -- For edge k: v_k -> v_next, inward normal = -turn_left(tangent)
    local edges = {}
    for k = 1, n_vertices do
        local next_k = math.wrap(k + 1, n_vertices)

        local i1 = 2 * k - 1
        local i2 = 2 * next_k - 1

        local x1, y1 = contour[i1], contour[i1 + 1]
        local x2, y2 = contour[i2], contour[i2 + 1]

        local tx, ty = math.normalize(x2 - x1, y2 - y1)
        local nx, ny = math.turn_left(tx, ty)       -- outward for CW
        nx, ny = -nx, -ny                           -- inward for CW

        local ox, oy = nx * rim_thickness, ny * rim_thickness
        local px, py = x1 + ox, y1 + oy
        local qx, qy = x2 + ox, y2 + oy

        edges[k] = { px = px, py = py, dx = qx - px, dy = qy - py }
    end

    local function cross(ax, ay, bx, by) return ax * by - ay * bx end

    -- Compute inset polygon as intersections of adjacent inward-offset edges
    local inset = {}
    for k = 1, n_vertices do
        local prev_k = math.wrap(k - 1, n_vertices)
        local e_prev = edges[prev_k]
        local e_curr = edges[k]

        local ppx, ppy, prx, pry = e_prev.px, e_prev.py, e_prev.dx, e_prev.dy
        local qpx, qpy, qrx, qry = e_curr.px, e_curr.py, e_curr.dx, e_curr.dy

        local rxs = cross(prx, pry, qrx, qry)
        local ix, iy
        if math.abs(rxs) < 1e-6 then
            -- Fallback: parallel edges (degenerate). Offset current vertex along current inward normal.
            local i1 = 2 * k - 1
            local vx, vy = contour[i1], contour[i1 + 1]
            local next_k = math.wrap(k + 1, n_vertices)
            local j1 = 2 * next_k - 1
            local tx, ty = math.normalize(contour[j1] - vx, contour[j1 + 1] - vy)
            local nx, ny = math.turn_left(tx, ty); nx, ny = -nx, -ny
            ix, iy = vx + nx * rim_thickness, vy + ny * rim_thickness
        else
            local qmpx, qmpy = qpx - ppx, qpy - ppy
            local t = cross(qmpx, qmpy, qrx, qry) / rxs
            ix, iy = ppx + prx * t, ppy + pry * t
        end

        table.insert(inset, ix)
        table.insert(inset, iy)
    end

    local xy_to_uv = function(x, y, u, v)
        return (x - min_x) / (max_x - min_x),
        (y - min_y) / (max_y - min_y)
    end

    -- Mesh data: first, the fill region is the inset polygon (no overlap with rim)
    local mesh_data = {}
    for i = 1, #inset, 2 do
        local x, y = inset[i], inset[i + 1]
        -- position (x,y), tex (0,0), color (white)
        local u, v = xy_to_uv(x, y)
        table.insert(mesh_data, { x, y, u, v, 1, 1, 1, 1 })
    end

    -- Triangulate the inset polygon (convex) for the fill
    local vertex_map = rt.DelaunayTriangulation(inset):get_triangle_vertex_map()

    -- Attribute shorthands for rim vertices (keep as in original)
    local rim_inner = function(x, y) -- on original boundary
        local u, v = xy_to_uv(x, y)
        return u, v, 1, 1, 1, 0
    end

    local rim_outer = function(x, y)  -- on inset boundary
        local u, v = xy_to_uv(x, y)
        return u, v, 1, 1, 1, 1
    end

    -- Build rim quads per edge using ORIGINAL boundary and INSET boundary
    -- For edge k: v_k -> v_next, inset: w_k -> w_next
    -- Append 4 vertices per edge:
    --   base+1: original v_k           (rim_inner)
    --   base+2: inset w_k              (rim_outer)
    --   base+3: original v_next        (rim_inner)
    --   base+4: inset w_next           (rim_outer)
    -- Triangles: (base+1, base+2, base+3) and (base+3, base+2, base+4)
    -- This tiles the annulus without gaps/overlaps; no extra corner fill needed.
    local base_start = #mesh_data
    for k = 1, n_vertices do
        local next_k = math.wrap(k + 1, n_vertices)

        local i1 = 2 * k - 1
        local j1 = 2 * next_k - 1

        local x1, y1 = contour[i1], contour[i1 + 1]
        local x2, y2 = contour[j1], contour[j1 + 1]

        local ix1, iy1 = inset[i1], inset[i1 + 1]
        local ix2, iy2 = inset[j1], inset[j1 + 1]

        table.insert(mesh_data, { x1,  y1,  rim_inner(x1, y1) })
        table.insert(mesh_data, { ix1, iy1, rim_outer(ix1, iy1) })
        table.insert(mesh_data, { x2,  y2,  rim_inner(x2, y2) })
        table.insert(mesh_data, { ix2, iy2, rim_outer(ix2, iy2) })

        local base = base_start + (k - 1) * 4
        for j in range(
            base + 1, base + 2, base + 3, -- tri 1
            base + 3, base + 2, base + 4  -- tri 2
        ) do
            table.insert(vertex_map, j)
        end
    end

    -- Build mesh
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
function ow.ShatterSurface._compute_voronoi(sites, bounds_x, bounds_y, bounds_w, bounds_h)
    local function circumcenter(x1, y1, x2, y2, x3, y3)
        local d = 2 * (x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2))
        if math.abs(d) < math.eps then return nil, nil end

        local ux = ((x1 * x1 + y1 * y1) * (y2 - y3) + (x2 * x2 + y2 * y2) * (y3 - y1) + (x3 * x3 + y3 * y3) * (y1 - y2)) / d
        local uy = ((x1 * x1 + y1 * y1) * (x3 - x2) + (x2 * x2 + y2 * y2) * (x1 - x3) + (x3 * x3 + y3 * y3) * (x2 - x1)) / d

        return ux, uy
    end

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

--- @brief
function ow.ShatterSurface._clip_polygon_to_rect(vertices, rx, ry, rw, rh)
    -- Robust Sutherland–Hodgman polygon clip to AABB (Lua)
    local eps = 1e-9

    local function left(x, y, nx, ny, rx, ry, rw, rh, want_intersect)
        if not want_intersect then return x >= rx end
        local dx, dy = nx - x, ny - y
        if math.abs(dx) < eps then
            -- parallel: if segment lies exactly on the vertical line x=rx, return endpoints that lie on it
            if math.abs(x - rx) < eps then
                -- return the endpoint that lies within [ry, ry+rh] if any (caller expects single intersection)
                -- choose the point of the segment that is inside vertical half-space (best-effort)
                local t = 0
                return rx, y
            end
            return nil, nil
        end
        local t = (rx - x) / dx
        if t < -eps or t > 1 + eps then return nil, nil end
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
        return rx, y + t * dy
    end

    local function right(x, y, nx, ny, rx, ry, rw, rh, want_intersect)
        if not want_intersect then return x <= rx + rw end
        local dx, dy = nx - x, ny - y
        local rxr = rx + rw
        if math.abs(dx) < eps then
            if math.abs(x - rxr) < eps then
                return rxr, y
            end
            return nil, nil
        end
        local t = (rxr - x) / dx
        if t < -eps or t > 1 + eps then return nil, nil end
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
        return rxr, y + t * dy
    end

    local function top(x, y, nx, ny, rx, ry, rw, rh, want_intersect)
        if not want_intersect then return y >= ry end
        local dx, dy = nx - x, ny - y
        if math.abs(dy) < eps then
            if math.abs(y - ry) < eps then
                return x, ry
            end
            return nil, nil
        end
        local t = (ry - y) / dy
        if t < -eps or t > 1 + eps then return nil, nil end
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
        return x + t * dx, ry
    end

    local function bottom(x, y, nx, ny, rx, ry, rw, rh, want_intersect)
        if not want_intersect then return y <= ry + rh end
        local dx, dy = nx - x, ny - y
        local ryb = ry + rh
        if math.abs(dy) < eps then
            if math.abs(y - ryb) < eps then
                return x, ryb
            end
            return nil, nil
        end
        local t = (ryb - y) / dy
        if t < -eps or t > 1 + eps then return nil, nil end
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
        return x + t * dx, ryb
    end

    local function clip_edge(input, rx, ry, rw, rh, edge_fn)
        local output = {}
        local n = #input
        if n < 2 then return output end

        local sx, sy = input[n-1], input[n]

        for i = 1, n, 2 do
            local ex, ey = input[i], input[i+1]
            local s_in = edge_fn(sx, sy, nil, nil, rx, ry, rw, rh, false)
            local e_in = edge_fn(ex, ey, nil, nil, rx, ry, rw, rh, false)

            if e_in then
                if not s_in then
                    local ix, iy = edge_fn(sx, sy, ex, ey, rx, ry, rw, rh, true)
                    if ix and iy then
                        output[#output+1] = ix
                        output[#output+1] = iy
                    end
                end
                output[#output+1] = ex
                output[#output+1] = ey
            elseif s_in then
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

    -- Robust early reject: returns true if polygon is *definitely fully outside* AABB
    local function polygon_fully_outside_aabb(vertices, rx, ry, rw, rh)
        local right = rx + rw
        local bottom = ry + rh

        for i = 1, #vertices, 2 do
            local x, y = vertices[i], vertices[i + 1]
            if x >= rx and x <= right and y >= ry and y <= bottom then
                return false -- vertex inside or on edge
            end
        end

        -- Liang–Barsky line vs AABB intersection test
        local function segment_intersects_aabb(x1, y1, x2, y2)
            local dx, dy = x2 - x1, y2 - y1
            local t0, t1 = 0.0, 1.0
            local function clip(p, q)
                if math.abs(p) < 1e-12 then
                    return q >= 0 -- line parallel and inside boundary
                end
                local r = q / p
                if p < 0 then
                    if r > t1 then return false end
                    if r > t0 then t0 = r end
                else
                    if r < t0 then return false end
                    if r < t1 then t1 = r end
                end
                return true
            end

            -- left, right, top, bottom planes
            if not clip(-dx, x1 - rx) then return false end
            if not clip(dx, right - x1) then return false end
            if not clip(-dy, y1 - ry) then return false end
            if not clip(dy, bottom - y1) then return false end

            return t1 >= t0 -- intersection or touching exists
        end

        -- test each polygon edge
        local n = math.floor(#vertices / 2)
        for i = 1, n do
            local i1 = (i - 1) * 2 + 1
            local i2 = (i % n) * 2 + 1
            local x1, y1 = vertices[i1], vertices[i1 + 1]
            local x2, y2 = vertices[i2], vertices[i2 + 1]
            if segment_intersects_aabb(x1, y1, x2, y2) then
                return false -- touches or crosses
            end
        end

        local cx, cy = rx + rw * 0.5, ry + rh * 0.5
        local inside = false
        for i = 1, n do
            local i1 = (i - 1) * 2 + 1
            local i2 = (i % n) * 2 + 1
            local x1, y1 = vertices[i1], vertices[i1 + 1]
            local x2, y2 = vertices[i2], vertices[i2 + 1]

            -- Ray casting
            if ((y1 > cy) ~= (y2 > cy)) then
                local xint = x1 + (x2 - x1) * (cy - y1) / (y2 - y1)
                if xint >= cx then
                    inside = not inside
                end
            end
        end

        if inside then
            return false
        end

        return true -- fully outside, no touching
    end

    if not vertices or #vertices < 6 or (#vertices % 2) ~= 0 then
        return nil
    end

    if polygon_fully_outside_aabb(vertices, rx, ry, rw, rh) then
        return nil
    end

    local out = vertices
    local edges = { left, right, top, bottom }
    for _, fn in ipairs(edges) do
        out = clip_edge(out, rx, ry, rw, rh, fn)
        if #out == 0 then return nil end
    end
    return out
end

--- @brief
function ow.ShatterSurface:get_bounds()
    return self._bounds:clone()
end