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

function _collide(origin_x, origin_y, dx, dy, circle_x, circle_y, circle_r, push_blend)
    push_blend = push_blend or 0.3  -- Default blend used in original code

    -- Early exit for zero-length vectors
    local seg_length_sq = dx * dx + dy * dy
    if seg_length_sq < 1e-12 then
        return dx, dy
    end

    local seg_length = math.sqrt(seg_length_sq)
    local seg_inv_length = 1.0 / seg_length

    -- Normalized direction (reused for both methods)
    local dir_x, dir_y = dx * seg_inv_length, dy * seg_inv_length

    -- Vector from origin to circle center (reused)
    local to_circle_x = circle_x - origin_x
    local to_circle_y = circle_y - origin_y

    -- Project circle center onto line through vector
    local proj_length = to_circle_x * dir_x + to_circle_y * dir_y
    local proj_x = origin_x + proj_length * dir_x
    local proj_y = origin_y + proj_length * dir_y

    -- Distance from circle center to line
    local dist_to_line_sq = (proj_x - circle_x) * (proj_x - circle_x) + (proj_y - circle_y) * (proj_y - circle_y)
    local circle_r_sq = circle_r * circle_r

    -- No collision if line doesn't intersect circle
    if dist_to_line_sq >= circle_r_sq then
        return dx, dy
    end

    local dist_to_line = math.sqrt(dist_to_line_sq)

    -- === AXIS COMPRESSION METHOD ===
    -- Calculate intersection points with circle
    local chord_half_length = math.sqrt(circle_r_sq - dist_to_line_sq)
    local intersection1_length = proj_length - chord_half_length
    local intersection2_length = proj_length + chord_half_length

    -- Find safe compression length
    local max_safe_length = seg_length
    if intersection1_length > 0 then
        max_safe_length = math.min(max_safe_length, intersection1_length - 1)
    elseif intersection2_length > 0 then
        max_safe_length = math.max(0, intersection1_length - 1)
    end

    max_safe_length = math.max(0, math.min(max_safe_length, seg_length))
    local axis_dx = dir_x * max_safe_length
    local axis_dy = dir_y * max_safe_length

    -- === PUSH DISPLACEMENT METHOD ===
    -- Find closest point on segment to circle center (clamped to segment)
    local t = math.max(0, math.min(1, proj_length / seg_length))
    local closest_x = origin_x + t * dx
    local closest_y = origin_y + t * dy

    -- Distance from circle center to closest point on segment
    local closest_dist_sq = (closest_x - circle_x) * (closest_x - circle_x) + (closest_y - circle_y) * (closest_y - circle_y)

    local push_dx, push_dy = dx, dy
    if closest_dist_sq < circle_r_sq then
        local closest_dist = math.sqrt(closest_dist_sq)
        local penetration = circle_r - closest_dist + 1 -- +1 for buffer

        -- Direction to push tip away from circle
        local push_dir_x, push_dir_y
        if closest_dist > 1e-6 then
            local inv_closest_dist = 1.0 / closest_dist
            push_dir_x = (closest_x - circle_x) * inv_closest_dist
            push_dir_y = (closest_y - circle_y) * inv_closest_dist
        else
            -- Fallback: perpendicular to segment
            push_dir_x = -dir_y
            push_dir_y = dir_x
        end

        -- Calculate extension needed
        local extension_needed = (t < 1e-6) and (penetration * 2) or (penetration / t)

        push_dx = dx + push_dir_x * extension_needed
        push_dy = dy + push_dir_y * extension_needed
    end

    -- === BLEND RESULTS ===
    local inv_blend = 1.0 - push_blend
    return axis_dx * inv_blend + push_dx * push_blend,
    axis_dy * inv_blend + push_dy * push_blend
end

function _spring_force(ox, oy, tip_x, tip_y, rest_x, rest_y, circle_x, circle_y, radius)
    -- Calculate current spring vector and squared length
    local current_dx = tip_x - ox
    local current_dy = tip_y - oy
    local current_length_sq = current_dx * current_dx + current_dy * current_dy

    -- Early exit for zero-length springs
    if current_length_sq < 1e-12 then
        return 0, 0
    end

    local current_length = math.sqrt(current_length_sq)
    local current_inv_length = 1.0 / current_length

    -- Spring unit vector (direction from origin to tip)
    local spring_unit_x = current_dx * current_inv_length
    local spring_unit_y = current_dy * current_inv_length

    -- Vector from origin to circle center
    local to_circle_x = circle_x - ox
    local to_circle_y = circle_y - oy

    -- Project circle center onto spring line
    local projection = to_circle_x * spring_unit_x + to_circle_y * spring_unit_y

    -- Clamp projection to spring segment [0, current_length]
    projection = math.max(0, math.min(projection, current_length))

    -- Closest point on spring to circle center
    local closest_x = ox + projection * spring_unit_x
    local closest_y = oy + projection * spring_unit_y

    -- Vector from closest point to circle center
    local contact_dx = circle_x - closest_x
    local contact_dy = circle_y - closest_y
    local contact_distance_sq = contact_dx * contact_dx + contact_dy * contact_dy
    local radius_sq = radius * radius

    -- Early exit if no collision
    if contact_distance_sq >= radius_sq then
        return 0, 0
    end

    local contact_distance = math.sqrt(contact_distance_sq)
    local penetration = radius - contact_distance

    -- Contact normal (points away from spring toward circle center)
    local normal_x, normal_y
    if contact_distance > 1e-10 then
        local contact_inv_distance = 1.0 / contact_distance
        normal_x = contact_dx * contact_inv_distance
        normal_y = contact_dy * contact_inv_distance
    else
        -- Circle center is on spring line, use perpendicular to spring
        normal_x = -spring_unit_y
        normal_y = spring_unit_x
    end

    -- Calculate rest length only when needed (after collision confirmed)
    local rest_dx = rest_x - ox
    local rest_dy = rest_y - oy
    local rest_length_sq = rest_dx * rest_dx + rest_dy * rest_dy
    local rest_length = math.sqrt(rest_length_sq)

    -- PHYSICS: Two force components

    -- 1. Spring restoring force (Hooke's Law: F = -k * displacement)
    -- Spring displacement from equilibrium (k = 1)
    local spring_displacement = current_length - rest_length

    -- Spring force acts along spring axis toward equilibrium
    local spring_force_x = -spring_displacement * spring_unit_x
    local spring_force_y = -spring_displacement * spring_unit_y

    -- 2. Contact force (normal force due to collision)
    -- Prevents interpenetration, acts along contact normal
    local contact_force_x = penetration * normal_x
    local contact_force_y = penetration * normal_y

    -- Weight spring force by proximity to tip (quadratic falloff)
    -- Only tip interactions should influence the circle significantly
    local tip_proximity = projection * current_inv_length  -- projection / current_length
    local spring_influence = tip_proximity * tip_proximity

    -- Total force on circle (Newton's 3rd law - forces applied to circle)
    local total_force_x = spring_influence * spring_force_x + contact_force_x
    local total_force_y = spring_influence * spring_force_y + contact_force_y

    return total_force_x, total_force_y
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