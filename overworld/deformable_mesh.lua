rt.settings.overworld.deformable_mesh = {
    spring_constant = 1,
    damping = 0.9,
    smoothing_strength = 0.1,
    smoothing_range = 3,
    subdivide_step = 5,
}

require "common.contour"
require "common.delaunay_triangulation"

--- @class ow.DeformableMesh
ow.DeformableMesh = meta.class("DeformableMesh")

local _shader

local _mesh_format = {
    { location = rt.VertexAttributeLocation.POSITION, name = rt.VertexAttribute.POSITION, format = "floatvec2" },
    { location = rt.VertexAttributeLocation.TEXTURE_COORDINATES, name = rt.VertexAttribute.TEXTURE_COORDINATES, format = "floatvec2" }
} -- xy stores origin of vector, uv stores vector

function ow.DeformableMesh:instantiate(world, contour)
    if _shader == nil then _shader = rt.Shader("overworld/deformable_mesh.glsl") end

    meta.assert(world, b2.World)
    self._world = world

    -- player data
    self._outer_x, self._outer_y, self._outer_radius = 0, 0, 0

    local deformable_max_depth = 4 * rt.settings.player.radius
    self._thickness = deformable_max_depth
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

    do -- hard inner shell
        local inner_body_contour = {
            0, 0 -- local coords
        }

        for i = 1, #contour + 2, 2 do
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
    contour = rt.subdivide_contour(contour, rt.settings.overworld.deformable_mesh.subdivide_step)

    local mesh_data = {
        { center_x, center_y, 0, 0, 1, 1, 1, 1 }
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
            dx, dy     -- texture_coords = vector
        })
    end

    self._mesh_data = mesh_data
    self._mesh_data_at_rest = table.deepcopy(self._mesh_data)

    self._mesh = rt.Mesh(
        mesh_data,
        rt.MeshDrawMode.TRIANGLE_FAN,
        _mesh_format,
        rt.GraphicsBufferUsage.DYNAMIC
    )
end

function _collide(origin_x, origin_y, dx, dy, circle_x, circle_y, circle_radius, push_blend)
    push_blend = push_blend or 0.3

    local segment_length_squared = dx * dx + dy * dy
    if segment_length_squared < 1e-12 then
        return dx, dy
    end

    local segment_length = math.sqrt(segment_length_squared)
    local direction_x, direction_y = dx / segment_length, dy / segment_length

    local to_circle_x = circle_x - origin_x
    local to_circle_y = circle_y - origin_y

    local projection_length = to_circle_x * direction_x + to_circle_y * direction_y
    local projection_x = origin_x + projection_length * direction_x
    local projection_y = origin_y + projection_length * direction_y

    local distance_to_line_squared = (projection_x - circle_x) * (projection_x - circle_x) + (projection_y - circle_y) * (projection_y - circle_y)
    if distance_to_line_squared >= circle_radius * circle_radius then
        return dx, dy
    end

    local chord_half_length = math.sqrt(circle_radius * circle_radius - distance_to_line_squared)
    local intersection1_length = projection_length - chord_half_length
    local intersection2_length = projection_length + chord_half_length

    local maximum_safe_length = segment_length
    if intersection1_length > 0 then
        maximum_safe_length = math.min(maximum_safe_length, intersection1_length - 1)
    elseif intersection2_length > 0 then
        maximum_safe_length = math.max(0, intersection1_length - 1)
    end

    maximum_safe_length = math.max(0, math.min(maximum_safe_length, segment_length))

    local t = math.max(0, math.min(1, projection_length / segment_length))
    local closest_x = origin_x + t * dx
    local closest_y = origin_y + t * dy

    local closest_distance_squared = (closest_x - circle_x) * (closest_x - circle_x) + (closest_y - circle_y) * (closest_y - circle_y)

    local push_dx, push_dy = dx, dy
    if closest_distance_squared < circle_radius * circle_radius then
        local closest_distance = math.sqrt(closest_distance_squared)
        local penetration = circle_radius - closest_distance + 1

        local push_direction_x, push_direction_y
        if closest_distance > 1e-6 then
            push_direction_x = (closest_x - circle_x) / closest_distance
            push_direction_y = (closest_y - circle_y) / closest_distance
        else
            push_direction_x = -direction_y
            push_direction_y = direction_x
        end

        local extension_needed = (t < 1e-6) and (penetration * 2) or (penetration / t)

        push_dx = dx + push_direction_x * extension_needed
        push_dy = dy + push_direction_y * extension_needed
    end

    return direction_x * maximum_safe_length * (1.0 - push_blend) + push_dx * push_blend,
    direction_y * maximum_safe_length * (1.0 - push_blend) + push_dy * push_blend
end

function _spring_force(origin_x, origin_y, tip_x, tip_y, rest_x, rest_y, circle_x, circle_y, radius)
    local current_dx = tip_x - origin_x
    local current_dy = tip_y - origin_y
    local current_length_squared = current_dx * current_dx + current_dy * current_dy

    if current_length_squared < 1e-12 then
        return 0, 0
    end

    local current_length = math.sqrt(current_length_squared)
    local spring_unit_x = current_dx / current_length
    local spring_unit_y = current_dy / current_length

    local to_circle_x = circle_x - origin_x
    local to_circle_y = circle_y - origin_y

    local projection = math.max(0, math.min(to_circle_x * spring_unit_x + to_circle_y * spring_unit_y, current_length))

    local closest_x = origin_x + projection * spring_unit_x
    local closest_y = origin_y + projection * spring_unit_y

    local contact_dx = circle_x - closest_x
    local contact_dy = circle_y - closest_y
    local contact_distance_squared = contact_dx * contact_dx + contact_dy * contact_dy

    if contact_distance_squared >= radius * radius then
        return 0, 0
    end

    local contact_distance = math.sqrt(contact_distance_squared)
    local penetration = radius - contact_distance

    local normal_x, normal_y
    if contact_distance > 1e-10 then
        normal_x = contact_dx / contact_distance
        normal_y = contact_dy / contact_distance
    else
        normal_x = -spring_unit_y
        normal_y = spring_unit_x
    end

    local rest_dx = rest_x - origin_x
    local rest_dy = rest_y - origin_y
    local rest_length = math.sqrt(rest_dx * rest_dx + rest_dy * rest_dy)

    local spring_displacement = current_length - rest_length

    local spring_force_x = -spring_displacement * spring_unit_x
    local spring_force_y = -spring_displacement * spring_unit_y

    local contact_force_x = penetration * normal_x
    local contact_force_y = penetration * normal_y

    local spring_influence = (projection / current_length)
    spring_influence = spring_influence * spring_influence

    return spring_influence * spring_force_x + contact_force_x,
        spring_influence * spring_force_y + contact_force_y
end

--- @return force_x, force_y
function ow.DeformableMesh:step(delta, outer_x, outer_y, outer_r)
    meta.assert(delta, "Number", outer_x, "Number", outer_y, "Number", outer_r, "Number")

    local settings = rt.settings.overworld.deformable_mesh
    local spring_constant = settings.spring_constant
    local damping = settings.damping
    local smoothing_strength = settings.smoothing_strength
    local smoothing_range = settings.smoothing_range
    local max_displacement = self._thickness

    -- compression data for neighbor smoothing
    local compression_ratios = {}

    -- first pass: collision detection and store compression data
    for i = 2, #self._mesh_data do -- skip first, which is center
        local data = self._mesh_data[i]
        local rest = self._mesh_data_at_rest[i]
        local origin_x, origin_y = data[1], data[2]
        local dx, dy = data[3], data[4]

        dx, dy = _collide(origin_x, origin_y, dx, dy, outer_x, outer_y, outer_r, 0.3)

        local tip_x, tip_y = origin_x + dx, origin_y + dy
        local distance = math.distance(tip_x, tip_y, outer_x, outer_y)

        local length = math.magnitude(dx, dy)
        if distance < outer_r then
            local penetration = outer_r - distance

            if length > math.eps then
                local compression_factor = spring_constant * penetration / length
                dx = dx * (1 - compression_factor)
                dy = dy * (1 - compression_factor)
            end
        end

        local rest_length = math.magnitude(rest[3], rest[4])
        length = math.magnitude(dx, dy)
        compression_ratios[i] = math.max(0, (rest_length - length) / rest_length)
        data[1], data[2], data[3], data[4] = origin_x, origin_y, dx, dy
    end

    -- apply smoothing
    local smoothed_mesh_data = {}
    for i = 2, #self._mesh_data do
        local data = self._mesh_data[i]
        local rest = self._mesh_data_at_rest[i]
        local origin_x, origin_y = data[1], data[2]
        local dx, dy = data[3], data[4]

        -- weighted compression of neighbors
        local total_compression_influence = 0
        local total_weight = 0
        local n_springs = #self._mesh_data - 1 -- exclude center point

        for offset = -smoothing_range, smoothing_range do
            if offset ~= 0 then
                local neighbor_idx = math.wrap(i - 2 + offset, n_springs) + 2
                local neighbor_compression = compression_ratios[neighbor_idx]
                if neighbor_compression ~= nil then
                    local weight = 1.0 / (math.abs(offset) + 1)
                    total_compression_influence = total_compression_influence + neighbor_compression * weight
                    total_weight = total_weight + weight
                end
            end
        end

        if total_weight > 0 then
            local mean_neighbor_compression = total_compression_influence / total_weight
            local self_compression = compression_ratios[i]

            -- if neighbors are more compressed, pull this spring inward
            if mean_neighbor_compression > self_compression then
                local pull_strength = (mean_neighbor_compression - self_compression) * smoothing_strength

                local current_length = math.magnitude(dx, dy)
                local rest_length = math.magnitude(rest[3], rest[4])
                local target_length = rest_length * (1 - (self_compression + pull_strength))

                if current_length > math.eps and target_length < current_length then
                    local scale = target_length / current_length
                    dx = dx * scale
                    dy = dy * scale
                end
            end
        end

        data[1], data[2], data[3], data[4] = origin_x, origin_y, dx, dy
    end

    local force_x, force_y = 0, 0

    -- move towards rest position (memory foam)
    for i = 2, #self._mesh_data do
        local data = self._mesh_data[i]
        local rest = self._mesh_data_at_rest[i]

        local origin_x, origin_y, dx, dy = table.unpack(data)
        local rest_origin_x, rest_origin_y, rest_dx, rest_dy = table.unpack(rest)
        dx = dx + (rest_dx - dx) * damping * delta
        dy = dy + (rest_dy - dy) * damping * delta
        origin_x = origin_x + (rest_origin_x - origin_x) * damping * delta
        origin_y = origin_y + (rest_origin_y - origin_y) * damping * delta

        local length =  math.magnitude(dx, dy)
        if length > max_displacement then
            dx = dx * (max_displacement / length)
            dy = dy * (max_displacement / length)
        end

        data[1], data[2] = origin_x, origin_y
        data[3], data[4] = dx, dy

        -- calculate spring force
        local fx, fy = _spring_force(
            origin_x, origin_y,
            origin_x + dx, origin_y + dy,
            rest_origin_x + rest_dx,
            rest_origin_y + rest_dy,
            outer_x, outer_y, outer_r
        )

        force_x = force_x + fx
        force_y = force_y + fy
    end

    self._mesh:replace_data(self._mesh_data)
    return force_x, force_y
end

--- @brief
function ow.DeformableMesh:draw()
    _shader:bind()
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    self._mesh:draw()
    _shader:unbind()
end

--- @brief
function ow.DeformableMesh:get_body()
    return self._inner_body
end

--- @brief
function ow.DeformableMesh:reset()
    for i, data in ipairs(self._mesh_data) do
        data[1], data[2], data[3], data[4] = table.unpack(self._mesh_data_at_rest[i])
    end
end

--- @brief
function ow.DeformableMesh:get_center()
    return self._center_x, self._center_y
end