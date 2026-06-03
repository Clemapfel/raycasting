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
        local contour = {
            mesh_x, mesh_y,
            mesh_x + width, mesh_y,
            mesh_x + width, mesh_y + height,
            mesh_x, mesh_y + height
        }

        self._pre_shatter_mesh = self._generate_mesh(contour, mesh_x, mesh_y, mesh_x + width, mesh_y + height)
        self._contour = rt.contour.close(contour)
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
            part.contour = rt.contour.close(table.deepcopy(part.vertices))
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
    local color = { rt.lcha_to_rgba(0.8, 1, rt.GameState:get_player():get_hue() , 1) }

    love.graphics.setLineStyle("smooth")
    love.graphics.setLineWidth(1.5)

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
        love.graphics.setColor(color)
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

    if not self._is_done then
        love.graphics.setColor(color)
        love.graphics.push()
        love.graphics.translate(self._offset_x, self._offset_y)
        love.graphics.rotate(self._rotation)
        love.graphics.line(self._contour)
        love.graphics.pop()
    else
        for part in values(self._parts) do
            part.color:bind()
            love.graphics.push()
            love.graphics.translate(part.x, part.y)
            love.graphics.rotate(part.body:get_rotation())
            love.graphics.line(part.contour)
            love.graphics.pop()
        end
    end

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

local _triangulator = nil

--- @brief
function ow.ShatterSurface._generate_mesh(contour, min_x, min_y, max_x, max_y)
    if _triangulator == nil then
        _triangulator = rt.DelaunayTriangulation(contour)
    end

    _triangulator:triangulate(contour)

    local data, indices = {}, {}
    for i = 1, #contour, 2 do
        local x, y = contour[i], contour[i+1]
        table.insert(data, { x, y, 0, 0, 1, 1, 1, 1 })
    end

    local mesh = rt.Mesh(
        data,
        rt.MeshDrawMode.TRIANGLES,
        mesh_format,
        rt.GraphicsBufferUsage.STATIC
    )
    mesh:set_vertex_map(_triangulator:get_triangle_vertex_map())

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