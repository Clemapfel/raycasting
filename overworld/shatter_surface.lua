require "common.voronoi_tesselation"
require "common.path"
require "common.graphics_buffer"
require "common.coroutine"

rt.settings.overworld.shatter_surface = {
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
function ow.ShatterSurface:instantiate(scene, world, x, y, width, height, angle)
    meta.assert(world, "PhysicsWorld")

    self._scene = scene
    self._world = world
    self._bounds = rt.AABB(x, y, width, height)
    self._rotation = angle or 0

    self._parts = {}

    do
        local mesh_x, mesh_y = -0.5 * width, -0.5 * height
        self._pre_shatter_mesh = self._generate_mesh({
            mesh_x, mesh_y,
            mesh_x + width, mesh_y,
            mesh_x + width, mesh_y + height,
            mesh_x, mesh_y + height
        }, mesh_x, mesh_y, mesh_x + width, mesh_y + height)
    end

    self._offset_x, self._offset_y = 0, 0

    self._is_shattered = false
    self._time_since_shatter = 0 -- time since shatter
    self._is_done = false
    self._callback = nil -- coroutine
    self._time_dilation = 1 -- fraction
    self._flash = 0 -- white, fraction

    self._impulse = rt.ImpulseSubscriber()
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

--- @brief
function ow.ShatterSurface:shatter(origin_x, origin_y, velocity_x, velocity_y)
    local settings = rt.settings.overworld.shatter_surface
    local w, h = self._bounds.width, self._bounds.height

    self._parts = {}
    self._is_done = false
    self._is_shattered = true

    local start = love.timer.getTime()
    self._callback = rt.Coroutine(function()
        local tesselation = rt.VoronoiTesselation()
        -- Generate seeds in axis-aligned local space
        tesselation:generate_seeds(origin_x, origin_y,
            -0.5 * w, -0.5 * h,
            0.5 * w, -0.5 * h,
            0.5 * w,  0.5 * h,
            -0.5 * w,  0.5 * h
        )

        coroutine.yield()

        for polygon in values(tesselation:tesselate()) do
            table.insert(self._parts, { vertices = polygon })
        end

        coroutine.yield()

        local min_mass, max_mass, max_distance = math.huge, -math.huge, -math.huge
        for part in values(self._parts) do
            local mx, my, n = 0, 0, 0
            for i = 1, #part.vertices, 2 do
                mx, my, n = mx + part.vertices[i], my + part.vertices[i+1], n + 1
            end
            mx, my = mx / n, my / n

            for i = 1, #part.vertices, 2 do
                part.vertices[i], part.vertices[i+1] = part.vertices[i] - mx, part.vertices[i+1] - my
            end

            part.x, part.y = mx, my -- local AA centroid
            part.distance = math.distance(mx, my, origin_x, origin_y)
            part.mass = polygon_area(part.vertices)
            min_mass, max_mass = math.min(min_mass, part.mass), math.max(max_mass, part.mass)
            max_distance = math.max(max_distance, part.distance)
        end

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

            local wx, wy = math.rotate(part.x, part.y, self._rotation)
            part.body = b2.Body(self._world, b2.BodyType.DYNAMIC, wx + self._offset_x, wy + self._offset_y, b2.Polygon(part.vertices))
            part.body:set_rotation(self._rotation)
            part.body:add_tag("stencil", "unjumpable", "unwalkable", "slippery", "point_light_source")
            part.body:set_user_data(part)
            part.collect_point_lights = function(_, callback)
                local bx, by = part.body:get_position()
                callback(bx, by, 1, part.color:unpack())
            end

            local evx, evy = math.normalize(part.x - origin_x, part.y - origin_y)
            evx, evy = math.rotate(evx * settings.velocity_magnitude, evy * settings.velocity_magnitude, self._rotation)

            local shard_mass = part.body:get_mass()
            local t = math.magnitude(math.abs(part.x - origin_x) / w, math.abs(part.y - origin_y) / h)

            part.body:set_velocity(evx + (velocity_x / (shard_mass * (1 + t)) * settings.player_velocity_influence), evy + (velocity_y / (shard_mass * (1 + t)) * settings.player_velocity_influence))
            part.body:set_restitution(1)

            part.mesh = self._generate_mesh(part.vertices, -0.5 * w - part.x, -0.5 * h - part.y, 0.5 * w - part.x, 0.5 * h - part.y)
        end

        self._is_done = true
    end):start()
end

--- @brief
function ow.ShatterSurface:update(delta)
    if not self._is_shattered then return end

    -- distribute load over multiple frames
    if self._callback ~= nil and not self._callback:get_is_done() then
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

    local camera = self._scene:get_camera()
    local transform = camera:get_transform()
    transform = transform:inverse()
    _shader:send("screen_to_world_transform", transform)
    _shader:send("bounds", { self._bounds:unpack() })

    if not self._is_done then
        love.graphics.push()
        love.graphics.translate(self._offset_x, self._offset_y)
        love.graphics.rotate(self._rotation)
        self._pre_shatter_mesh:draw()
        love.graphics.pop()
    else
        for part in values(self._parts) do
            part.color:bind()
            love.graphics.push()
            love.graphics.translate(part.x, part.y)
            love.graphics.rotate(part.body:get_rotation()) -- part centered at origin
            love.graphics.draw(part.mesh:get_native())
            love.graphics.pop()
        end
    end
    _shader:unbind()

    if self._tesselation ~= nil then
        love.graphics.circle("fill", self._tesselation_origin_x, self._tesselation_origin_y, 10)
    end
end

--- @brief
function ow.ShatterSurface:draw_bloom()
    if not self._is_done then
        love.graphics.setColor(rt.lcha_to_rgba(0.8, 1, rt.GameState:get_player():get_hue() , 1))
        _shader:bind()
        _shader:send("elapsed", rt.SceneManager:get_elapsed())
        _shader:send("fraction", math.clamp(self._time_since_shatter / rt.settings.overworld.shatter_surface.fade_duration, 0, 1))
        _shader:send("draw_bloom", true)

        love.graphics.push()
        love.graphics.translate(self._offset_x, self._offset_y)
        love.graphics.rotate(self._rotation)
        self._pre_shatter_mesh:draw()
        love.graphics.pop()

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

    self:instantiate(self._scene, self._world, self._bounds:unpack())
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

        table.insert(mesh_data, { x1, y1, rim_inner(x1, y1) })
        table.insert(mesh_data, { ix1, iy1, rim_outer(ix1, iy1) })
        table.insert(mesh_data, { x2, y2, rim_inner(x2, y2) })
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
function ow.ShatterSurface:get_bounds()
    return self._bounds:clone()
end

--- @brief
function ow.ShatterSurface:set_offset(x, y)
    self._offset_x, self._offset_y = x, y
end