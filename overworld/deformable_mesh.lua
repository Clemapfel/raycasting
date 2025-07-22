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

    local outer_r = 50
    local deformable_max_depth = 4 * outer_r
    self._thickness = deformable_max_depth
    local shape_r = 200

    do
        require "physics.physics"
        local dbg_radius = shape_r
        local dbg_x, dbg_y = 0.5 * love.graphics.getWidth(), 0.5 * love.graphics.getHeight()
        contour = {}
        local n_points = 64
        for i = 1, n_points do
            local angle = (i - 1) * 2 * math.pi / n_points
            table.insert(contour, dbg_x + math.cos(angle) * shape_r)
            table.insert(contour, dbg_y + math.sin(angle) * shape_r)
        end

        local x, y = love.mouse.getPosition()
        self._outer_body_radius = outer_r
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

    -- construct solid center body

    do
        local inner_body_contour = {
            0, 0 -- local coords
        }
        for i = 1, #contour + 2, 2 do
            -- get vector from center to point
            local x1 = contour[math.wrap(i+0, #contour)]
            local y1 = contour[math.wrap(i+1, #contour)]

            local dx, dy = x1 - center_x, y1 - center_y
            local length = math.magnitude(dx, dy)
            dx, dy = math.normalize(dx, dy)

            table.insert(inner_body_contour, dx * math.max(length - deformable_max_depth, 5))
            table.insert(inner_body_contour, dy * math.max(length - deformable_max_depth, 5))
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

    for i = 1, #contour + 2, 2 do
        -- get vector from center to point
        local x1 = contour[math.wrap(i+0, #contour)]
        local y1 = contour[math.wrap(i+1, #contour)]

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

function _collide_push(origin_x, origin_y, dx, dy, circle_x, circle_y, circle_r)
    local tip_x, tip_y = origin_x + dx, origin_y + dy

    -- Vector from origin to tip
    local seg_dx = tip_x - origin_x
    local seg_dy = tip_y - origin_y
    local seg_length_sq = seg_dx * seg_dx + seg_dy * seg_dy

    -- If segment has zero length, no collision possible
    if seg_length_sq < 1e-12 then
        return dx, dy
    end

    -- Vector from origin to circle center
    local to_circle_x = circle_x - origin_x
    local to_circle_y = circle_y - origin_y

    -- Project circle center onto line segment (clamped to [0,1])
    local t = (to_circle_x * seg_dx + to_circle_y * seg_dy) / seg_length_sq
    t = math.max(0, math.min(1, t))

    -- Closest point on segment to circle center
    local closest_x = origin_x + t * seg_dx
    local closest_y = origin_y + t * seg_dy

    -- Distance from circle center to closest point
    local dist_to_closest = math.magnitude(closest_x - circle_x, closest_y - circle_y)

    -- No collision if distance > radius
    if dist_to_closest >= circle_r then
        return dx, dy -- no collision
    end

    -- Collision detected - adjust direction vector to clear circle
    local penetration = circle_r - dist_to_closest + 1 -- +1 for small buffer

    -- Direction to push the tip away from circle
    local push_dir_x, push_dir_y

    if dist_to_closest > 1e-6 then
        -- Push in direction from circle center to closest point
        push_dir_x = (closest_x - circle_x) / dist_to_closest
        push_dir_y = (closest_y - circle_y) / dist_to_closest
    else
        -- Closest point is at circle center, push perpendicular to segment
        local seg_length = math.sqrt(seg_length_sq)
        if seg_length > 1e-6 then
            push_dir_x = -seg_dy / seg_length  -- perpendicular to segment
            push_dir_y = seg_dx / seg_length
        else
            push_dir_x, push_dir_y = 1, 0 -- arbitrary fallback
        end
    end

    -- Calculate how much to extend the direction vector
    -- We need to move the tip far enough so the entire segment clears the circle
    local extension_needed = penetration / math.abs(t) -- scale by position along segment
    if t < 1e-6 then
        -- If collision is near origin, extend significantly
        extension_needed = penetration * 2
    end

    -- Extend the direction vector
    local new_dx = dx + push_dir_x * extension_needed
    local new_dy = dy + push_dir_y * extension_needed

    return new_dx, new_dy
end

--- @brief Check if line segment collides with circle and compress along axis to avoid overlap
--- @param origin_x number Base x coordinate of the vector (fixed)
--- @param origin_y number Base y coordinate of the vector (fixed)
--- @param dx number Direction vector x component
--- @param dy number Direction vector y component
--- @param circle_x number Circle center x coordinate
--- @param circle_y number Circle center y coordinate
--- @param circle_r number Circle radius
--- @return number, number New dx, dy (compressed along original axis)
function _collide_axis(origin_x, origin_y, dx, dy, circle_x, circle_y, circle_r)
    local tip_x, tip_y = origin_x + dx, origin_y + dy

    -- Vector from origin to tip
    local seg_length = math.magnitude(dx, dy)

    -- If segment has zero length, no collision possible
    if seg_length < 1e-12 then
        return dx, dy
    end

    -- Normalized direction of the vector
    local dir_x, dir_y = dx / seg_length, dy / seg_length

    -- Vector from origin to circle center
    local to_circle_x = circle_x - origin_x
    local to_circle_y = circle_y - origin_y

    -- Project circle center onto the infinite line through the vector
    local proj_length = to_circle_x * dir_x + to_circle_y * dir_y
    local proj_x = origin_x + proj_length * dir_x
    local proj_y = origin_y + proj_length * dir_y

    -- Distance from circle center to the line
    local dist_to_line = math.magnitude(proj_x - circle_x, proj_y - circle_y)

    -- No collision if line doesn't intersect circle
    if dist_to_line >= circle_r then
        return dx, dy
    end

    -- Calculate intersection points with circle
    local chord_half_length = math.sqrt(circle_r * circle_r - dist_to_line * dist_to_line)
    local intersection1_length = proj_length - chord_half_length
    local intersection2_length = proj_length + chord_half_length

    -- Find the intersection point that's closest to origin but still ahead of it
    local max_safe_length = seg_length

    if intersection1_length > 0 then
        -- First intersection is ahead of origin
        max_safe_length = math.min(max_safe_length, intersection1_length - 1) -- -1 for buffer
    elseif intersection2_length > 0 then
        -- Only second intersection is ahead, but we're inside the circle
        -- Compress significantly
        max_safe_length = math.max(0, intersection1_length - 1)
    end

    -- Ensure we don't extend beyond original length
    max_safe_length = math.max(0, math.min(max_safe_length, seg_length))

    -- Return compressed vector along original axis
    local new_dx = dir_x * max_safe_length
    local new_dy = dir_y * max_safe_length

    return new_dx, new_dy
end

--- @brief
function ow.DeformableMesh:update(delta)
    local outer_x, outer_y = self._outer_body:get_position()
    local outer_r = self._outer_body_radius

    -- Physics parameters
    local spring_k_tip = 0.8      -- Spring constant for tip (increased for more responsive compression)
    local damping = 2.0           -- Damping factor (memory foam effect)
    local max_displacement = self._thickness

    for i = 2, #self._mesh_data do -- skip first data, which is always constant
        local data = self._mesh_data[i]
        local rest = self._rest_mesh_data[i]
        local origin_x, origin_y = data[1], data[2]
        local dx, dy = data[3], data[4]
        local tip_x, tip_y = origin_x + dx, origin_y + dy

        -- --- AXIAL COMPRESSION COLLISION ---
        -- First apply compression-based collision response
        local axis_dx, axis_dy = _collide_axis(origin_x, origin_y, dx, dy, outer_x, outer_y, outer_r)
        local push_dx, push_dy = _collide_push(origin_x, origin_y, dx, dy, outer_x, outer_y, outer_r)
        dx, dy = math.mix2(axis_dx, axis_dy, push_dx, push_dy, 0.3)

        -- --- TIP COLLISION (for additional spring force) ---
        tip_x, tip_y = origin_x + dx, origin_y + dy
        local to_tip_x = tip_x - outer_x
        local to_tip_y = tip_y - outer_y
        local dist_tip = math.magnitude(to_tip_x, to_tip_y)

        if dist_tip < outer_r then
            local penetration = outer_r - dist_tip

            -- Apply compression force along the vector's own axis
            local vector_length = math.magnitude(dx, dy)
            if vector_length > 1e-6 then
                local compression_factor = spring_k_tip * penetration / vector_length
                -- Compress the vector (reduce its length)
                dx = dx * (1 - compression_factor)
                dy = dy * (1 - compression_factor)
            end
        end

        -- --- MEMORY FOAM (return to rest) ---
        local rest_dx, rest_dy = rest[3], rest[4]
        local rest_ox, rest_oy = rest[1], rest[2]
        dx = dx + (rest_dx - dx) * damping * delta
        dy = dy + (rest_dy - dy) * damping * delta
        origin_x = origin_x + (rest_ox - origin_x) * damping * delta
        origin_y = origin_y + (rest_oy - origin_y) * damping * delta

        -- --- CLAMP TIP DISPLACEMENT ---
        local disp = math.sqrt(dx * dx + dy * dy)
        if disp > max_displacement then
            dx = dx * (max_displacement / disp)
            dy = dy * (max_displacement / disp)
        end

        data[1], data[2] = origin_x, origin_y
        data[3], data[4] = dx, dy
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
    self._mesh:draw()
    _shader:unbind()

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
            --love.graphics.line(ox, oy, ox + dx, oy + dy)
            --love.graphics.polygon("fill", x1, y1, x2, y2, x3, y3)

            hue = hue + 1 / (#self._mesh_data - 1)
        end

        skip = false
    end

    love.graphics.setColor(1, 1, 1, 1)
    self._outer_body:draw()
    self._inner_body:draw()
end