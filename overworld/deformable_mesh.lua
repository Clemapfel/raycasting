require "common.contour"
require "common.delaunay_triangulation"

--- @class ow.DeformableMesh
ow.DeformableMesh = meta.class("DeformableMesh")

local _shader

local _mesh_format = {
    { location = rt.VertexAttributeLocation.POSITION, name = rt.VertexAttribute.POSITION, format = "floatvec2" },
    { location = rt.VertexAttributeLocation.TEXTURE_COORDINATES, name = rt.VertexAttribute.TEXTURE_COORDINATES, format = "floatvec2" },
}
-- xy stores origin of vector, uv stores vector

function ow.DeformableMesh:instantiate(world, contour)
    if _shader == nil then _shader = rt.Shader("overworld/deformable_mesh.glsl") end

    meta.assert(world, b2.World)
    self._world = world

    local deformable_max_depth = 200
    self._thickness = deformable_max_depth
    local shape_r = 300

    do
        require "physics.physics"
        local dbg_radius = shape_r
        local dbg_x, dbg_y = 0.5 * love.graphics.getWidth(), 0.5 * love.graphics.getHeight()
        contour = {}
        local n_points = 16
        for i = 1, n_points do
            local angle = (i - 1) * 2 * math.pi / n_points
            table.insert(contour, dbg_x + math.cos(angle) * shape_r)
            table.insert(contour, dbg_y + math.sin(angle) * shape_r)
        end

        local x, y = love.mouse.getPosition()
        self._outer_body_radius = 30
        self._outer_body = b2.Body(world, b2.BodyType.DYNAMIC, x, y, b2.Circle(0, 0, self._outer_body_radius))
        self._input = rt.InputSubscriber()
        self._outer_target_x, self._outer_target_y = x, y
        self._input:signal_connect("mouse_moved", function(_, x, y)
            self._outer_target_x, self._outer_target_y = x, y
        end)
    end

    self._contour = contour

    -- construct center vectors
    local center_x, center_y = 0, 0
    local n = 0
    for i = 1, #contour, 2 do
        center_x = center_x + contour[i+0]
        center_y = center_y + contour[i+1]
        n = n + 1
    end

    center_x = center_x / n
    center_y = center_y / n
    self._center_x, self._center_y = center_x, center_y

    table.insert(contour, contour[1])
    table.insert(contour, contour[2])

    -- construct solid center body

    do
        local inner_body_contour = {
            0, 0 -- local coords
        }
        for i = 1, #contour, 2 do
            -- get vector from center to point
            local x1 = contour[i+0]
            local y1 = contour[i+1]

            local dx, dy = x1 - center_x, y1 - center_y
            local length = math.magnitude(dx, dy)
            dx, dy = math.normalize(dx, dy)

            table.insert(inner_body_contour, dx * math.max(length - deformable_max_depth, 0))
            table.insert(inner_body_contour, dy * math.max(length - deformable_max_depth, 0))
        end

        local shapes = {}
        for tri in values(rt.DelaunayTriangulation(inner_body_contour):get_triangles()) do
            table.insert(shapes, b2.Polygon(tri))
        end

        self._inner_body = b2.Body(world, b2.BodyType.STATIC, center_x, center_y, shapes)
    end

    -- subdivide, then get outer shape
    contour = rt.subdivide_contour(contour, 5)
    local mesh_data = {
        { center_x, center_y, 0, 0 }
    }

    for i = 1, #contour, 2 do
        -- get vector from center to point
        local x1 = contour[i+0]
        local y1 = contour[i+1]

        local dx, dy = x1 - center_x, y1 - center_y
        local length = math.magnitude(dx, dy)
        dx, dy = math.normalize(dx, dy)
        dx = dx * math.min(deformable_max_depth, length)
        dy = dy * math.min(deformable_max_depth, length)

        -- get new vector origin
        local ox, oy = x1 - dx, y1 - dy

        table.insert(mesh_data, {
            ox, oy,     -- vertex position = origin of vector
            dx, dy,     -- texture_coords = vector
        })
    end

    self._mesh_data = mesh_data
    self._mesh = rt.Mesh(
        mesh_data,
        rt.MeshDrawMode.TRIANGLE_FAN,
        _mesh_format,
        rt.GraphicsBufferUsage.DYNAMIC
    )

    self._rest_mesh_data = {}
    for i, data in ipairs(self._mesh_data) do
        -- Deep copy
        self._rest_mesh_data[i] = { data[1], data[2], data[3], data[4] }
    end
end

--- @brief
function ow.DeformableMesh:update(delta)
    local outer_x, outer_y = self._outer_body:get_position()
    local outer_r = self._outer_body_radius

    -- Physics parameters
    local spring_k = 0.5         -- Spring constant (tune for stiffness)
    local damping = 1        -- Damping factor (tune for memory foam effect)
    local max_displacement = self._thickness  -- Clamp for stability

    for i = 2, #self._mesh_data do -- skip first data, which is always constant
        local data = self._mesh_data[i]
        local rest = self._rest_mesh_data[i]
        local origin_x, origin_y = data[1], data[2]
        local dx, dy = data[3], data[4]
        local tip_x, tip_y = origin_x + dx, origin_y + dy

        -- Check collision with outer circle
        local to_tip_x = tip_x - outer_x
        local to_tip_y = tip_y - outer_y
        local dist = math.sqrt(to_tip_x * to_tip_x + to_tip_y * to_tip_y)

        local force_x, force_y = 0, 0

        if dist < outer_r then
            -- Penetration depth
            local penetration = outer_r - dist
            -- Direction: push tip outward from circle center
            local nx, ny = 0, 0
            if dist > 1e-6 then
                nx, ny = to_tip_x / dist, to_tip_y / dist
            else
                nx, ny = 1, 0 -- arbitrary direction if exactly at center
            end
            -- Spring force proportional to penetration
            force_x = nx * spring_k * penetration
            force_y = ny * spring_k * penetration
        end

        -- Apply force to tip (direction vector)
        -- Optionally, you could also move the origin for more dramatic effects

        -- Memory foam: interpolate direction back toward rest direction
        local rest_dx, rest_dy = rest[3], rest[4]
        -- Damping: how quickly it returns to rest
        dx = dx + force_x
        dy = dy + force_y

        -- Interpolate back to rest (memory foam)
        dx = dx + (rest_dx - dx) * damping * delta
        dy = dy + (rest_dy - dy) * damping * delta

        -- Clamp displacement for stability
        local disp = math.sqrt(dx * dx + dy * dy)
        local rest_disp = math.sqrt(rest_dx * rest_dx + rest_dy * rest_dy)
        if disp > max_displacement then
            dx = dx * (max_displacement / disp)
            dy = dy * (max_displacement / disp)
        end

        data[3], data[4] = dx, dy
        -- Optionally, also update origin if you want the base to move:
        -- data[1], data[2] = ... (similar logic)
    end

    self._mesh:replace_data(self._mesh_data)

    -- outer movement for debugging
    local current_x, current_y = self._outer_body:get_position()
    self._outer_body:set_velocity(self._outer_target_x - current_x, self._outer_target_y - current_y)
    self._world:update(delta)
end

local _tri_w, _tri_h  = 10, 10

--- @brief
function ow.DeformableMesh:draw()
    _shader:bind()
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    --self._mesh:draw()
    _shader:unbind()

    self._inner_body:draw()
    self._outer_body:draw()

    local hue = 0
    local skip = true
    for data in values(self._mesh_data) do
        if not skip then
            local ox, oy, dx, dy = table.unpack(data)

            -- Draw a triangle at the end of the line
            local tip_x, tip_y = ox + dx, oy + dy
            local angle = math.angle(dx, dy)
            local cos_a = math.cos(angle)
            local sin_a = math.sin(angle)

            local x1 = tip_x
            local y1 = tip_y
            local x2 = tip_x - _tri_h * cos_a + (_tri_w / 2) * sin_a
            local y2 = tip_y - _tri_h * sin_a - (_tri_w / 2) * cos_a
            local x3 = tip_x - _tri_h * cos_a - (_tri_w / 2) * sin_a
            local y3 = tip_y - _tri_h * sin_a + (_tri_w / 2) * cos_a

            rt.LCHA(0.8, 1, hue, 1):bind()
            love.graphics.line(ox, oy, ox + dx, oy + dy)
            --love.graphics.polygon("fill", x1, y1, x2, y2, x3, y3)

            hue = hue + 1 / (#self._mesh_data - 1)
        end

        skip = false
    end

    love.graphics.line(self._contour)
end