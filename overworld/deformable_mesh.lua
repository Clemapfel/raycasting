require "common.contour"
require "common.delaunay_triangulation"

--- @class ow.DeformableMesh
ow.DeformableMesh = meta.class("DeformableMesh")

local _shader

local _mesh_format = {
    { location = rt.VertexAttributeLocation.POSITION, name = rt.VertexAttribute.POSITION, format = "floatvec2" },
    { location = rt.VertexAttributeLocation.TEXTURE_COORDINATES, name = rt.VertexAttribute.TEXTURE_COORDINATES, format = "floatvec2" },
    { location = rt.VertexAttributeLocation.COLOR, name = rt.VertexAttribute.COLOR, format = "floatvec4" },
}
-- xy stores origin of vector, uv stores vector

function ow.DeformableMesh:instantiate(world, contour)
    if _shader == nil then _shader = rt.Shader("overworld/deformable_mesh.glsl") end

    meta.assert(world, b2.World)
    self._world = world

    local outer_r = 35
    local deformable_max_depth = 4 * outer_r
    self._thickness = deformable_max_depth
    local shape_r = 200

    do
        require "physics.physics"
        local dbg_radius = shape_r * 0.5
        local dbg_x, dbg_y = 0.5 * love.graphics.getWidth(), 0.5 * love.graphics.getHeight()
        contour = {}

        if false then
            local n_points = 64
            for i = 1, n_points do
                local angle = (i - 1) * 2 * math.pi / n_points
                table.insert(contour, dbg_x + math.cos(angle) * dbg_radius * 1.25)
                table.insert(contour, dbg_y + math.sin(angle) * dbg_radius)
            end
        else
            contour = {}
            local n_points = 128  -- More points for smoother spiral

            -- Snail parameters
            local spiral_turns = 2.5        -- Number of spiral turns
            local shell_growth = 2        -- How much the spiral grows outward
            local body_length = dbg_radius * 1.2  -- Length of the snail body
            local shell_offset_x = dbg_radius * 0.3  -- Shell position relative to body
            local shell_offset_y = 0

            -- Generate the snail body (elongated teardrop shape)
            local body_points = math.floor(n_points * 0.4)
            for i = 1, body_points do
                local t = (i - 1) / (body_points - 1)  -- 0 to 1
                local angle = t * math.pi  -- Half circle for body outline

                -- Teardrop shape: wider at back, pointed at front
                local width_factor = math.sin(angle) * (1 - t * 0.3)
                local length_factor = 1 - math.cos(angle)

                local x = dbg_x - body_length * 0.5 + body_length * length_factor
                local y = dbg_y + width_factor * dbg_radius * 0.6

                table.insert(contour, x)
                table.insert(contour, y)
            end

            -- Generate the spiral shell
            local shell_points = n_points - body_points
            for i = 1, shell_points do
                local t = (i - 1) / (shell_points - 1)  -- 0 to 1
                local spiral_angle = t * spiral_turns * 2 * math.pi

                -- Spiral radius grows from center outward
                local spiral_radius = shell_growth * dbg_radius * (1 - t)

                -- Shell center position
                local shell_center_x = dbg_x + shell_offset_x
                local shell_center_y = dbg_y + shell_offset_y

                local x = shell_center_x + spiral_radius * math.cos(spiral_angle)
                local y = shell_center_y + spiral_radius * math.sin(spiral_angle)

                table.insert(contour, x)
                table.insert(contour, y)
            end

            -- Connect back to body (bottom half)
            for i = body_points, 1, -1 do
                local t = (i - 1) / (body_points - 1)  -- 1 to 0
                local angle = t * math.pi + math.pi  -- Bottom half of circle

                local width_factor = math.sin(angle - math.pi) * (1 - (1-t) * 0.3)
                local length_factor = 1 - math.cos(angle - math.pi)

                local x = dbg_x - body_length * 0.5 + body_length * length_factor
                local y = dbg_y + width_factor * dbg_radius * 0.6

                table.insert(contour, x)
                table.insert(contour, y)
            end
        end

        local x, y = love.mouse.getPosition()
        self._outer_body_radius = outer_r
        self._outer_body = b2.Body(world, b2.BodyType.DYNAMIC, x, y, b2.Circle(0, 0, self._outer_body_radius))
        self._outer_body:set_mass(1)
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
            dx, dy,     -- texture_coords = vector
            rt.lcha_to_rgba(0.8, 1, i / #contour, 1)
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

function _spring_force(ox, oy, tip_x, tip_y, rest_x, rest_y, circle_x, circle_y, radius)
    -- Calculate current spring vector and length
    local current_dx = tip_x - ox
    local current_dy = tip_y - oy
    local current_length = math.sqrt(current_dx * current_dx + current_dy * current_dy)

    -- Calculate rest spring vector and length
    local rest_dx = rest_x - ox
    local rest_dy = rest_y - oy
    local rest_length = math.sqrt(rest_dx * rest_dx + rest_dy * rest_dy)

    -- Handle edge case where spring has zero current length
    if current_length == 0 then
        return 0, 0
    end

    -- Spring unit vector (direction from origin to tip)
    local spring_unit_x = current_dx / current_length
    local spring_unit_y = current_dy / current_length

    -- Find closest point on spring line segment to circle center
    local to_circle_x = circle_x - ox
    local to_circle_y = circle_y - oy

    -- Project circle center onto spring line
    local projection = to_circle_x * spring_unit_x + to_circle_y * spring_unit_y

    -- Clamp to spring segment [0, current_length]
    projection = math.max(0, math.min(projection, current_length))

    -- Closest point on spring to circle center
    local closest_x = ox + projection * spring_unit_x
    local closest_y = oy + projection * spring_unit_y

    -- Vector from closest point to circle center
    local contact_dx = circle_x - closest_x
    local contact_dy = circle_y - closest_y
    local contact_distance = math.sqrt(contact_dx * contact_dx + contact_dy * contact_dy)

    -- Check for collision
    if contact_distance >= radius then
        return 0, 0  -- No contact
    end

    -- Calculate penetration depth
    local penetration = radius - contact_distance

    -- Contact normal (points away from spring toward circle center)
    local normal_x, normal_y
    if contact_distance > 1e-10 then
        normal_x = contact_dx / contact_distance
        normal_y = contact_dy / contact_distance
    else
        -- Circle center is on spring line, use perpendicular to spring
        normal_x = -spring_unit_y
        normal_y = spring_unit_x
    end

    -- PHYSICS: Two force components

    -- 1. Spring restoring force (Hooke's Law: F = -k * displacement)
    -- This acts along the spring direction, proportional to compression/extension
    local spring_displacement = current_length - rest_length
    local spring_force_magnitude = spring_displacement  -- k = 1

    -- Spring force acts along spring axis toward equilibrium
    local spring_force_x = -spring_force_magnitude * spring_unit_x
    local spring_force_y = -spring_force_magnitude * spring_unit_y

    -- 2. Contact force (normal force due to collision)
    -- This prevents interpenetration, acts along contact normal
    local contact_force_magnitude = penetration  -- Treating as spring constant = 1
    local contact_force_x = contact_force_magnitude * normal_x
    local contact_force_y = contact_force_magnitude * normal_y

    -- The spring force should only affect the circle if the contact point
    -- is near the tip (where the spring force is applied)
    -- Weight by distance along spring (closer to tip = more influence)
    local tip_proximity = projection / current_length
    local spring_influence = tip_proximity * tip_proximity  -- Quadratic falloff

    -- Total force on circle
    local total_force_x = spring_influence * spring_force_x + contact_force_x
    local total_force_y = spring_influence * spring_force_y + contact_force_y

    return total_force_x, total_force_y
end

--- @brief
--- @brief
--- @brief
function ow.DeformableMesh:update(delta)
    local outer_x, outer_y = self._outer_body:get_position()
    local outer_r = self._outer_body_radius

    -- Physics parameters
    local spring_k_tip = 1      -- Spring constant for tip (increased for more responsive compression)
    local damping = 1 - 0.1          -- Damping factor (memory foam effect)
    local max_displacement = self._thickness
    local smoothing_strength = 0.1
    local smoothing_range = 3   -- How many neighbors on each side to consider

    -- Initialize force accumulator
    local total_force_x = 0
    local total_force_y = 0

    -- Store compression data for neighbor influence
    local updated_mesh_data = {}
    local compression_ratios = {}

    -- First pass: collision detection and store compression data
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

                -- Calculate force applied to circle from this spring
                -- Force = spring constant * compression distance
                local spring_force_magnitude = spring_k_tip * penetration

                -- Force direction is from tip toward circle center (Newton's 3rd law)
                if dist_tip > 1e-6 then
                    local force_dir_x = to_tip_x / dist_tip
                    local force_dir_y = to_tip_y / dist_tip

                    total_force_x = total_force_x + spring_force_magnitude * force_dir_x
                    total_force_y = total_force_y + spring_force_magnitude * force_dir_y
                end
            end
        end

        -- Store compression information for neighbor influence
        local rest_length = math.magnitude(rest[3], rest[4])
        local current_length = math.magnitude(dx, dy)
        local compression_ratio = math.max(0, (rest_length - current_length) / rest_length)
        compression_ratios[i] = compression_ratio

        -- Store the updated data temporarily
        updated_mesh_data[i] = { origin_x, origin_y, dx, dy }
    end

    -- Second pass: Apply compression smoothing
    local smoothed_mesh_data = {}
    for i = 2, #self._mesh_data do
        local data = updated_mesh_data[i]
        local rest = self._rest_mesh_data[i]
        local origin_x, origin_y = data[1], data[2]
        local dx, dy = data[3], data[4]

        -- Calculate weighted average compression from neighbors
        local total_compression_influence = 0
        local total_weight = 0
        local n_springs = #self._mesh_data - 1 -- Exclude center point

        for offset = -smoothing_range, smoothing_range do
            if offset ~= 0 then
                -- Convert current spring index to 0-based, apply offset, wrap, then convert back
                local current_spring_0based = i - 2  -- Convert to 0-based (springs are indexed 2 to N)
                local neighbor_spring_0based = math.wrap(current_spring_0based + offset, n_springs)
                local neighbor_idx = neighbor_spring_0based + 2  -- Convert back to 1-based spring index

                local neighbor_compression = compression_ratios[neighbor_idx]
                if neighbor_compression then  -- Safety check
                    -- Weight decreases with distance
                    local weight = 1.0 / (math.abs(offset) + 1)
                    total_compression_influence = total_compression_influence + neighbor_compression * weight
                    total_weight = total_weight + weight
                end
            end
        end

        if total_weight > 0 then
            local avg_neighbor_compression = total_compression_influence / total_weight
            local self_compression = compression_ratios[i]

            -- If neighbors are more compressed, pull this spring inward
            if avg_neighbor_compression > self_compression then
                local compression_diff = avg_neighbor_compression - self_compression
                local pull_strength = compression_diff * smoothing_strength

                -- Reduce the spring length to match neighbor compression
                local current_length = math.magnitude(dx, dy)
                local rest_length = math.magnitude(rest[3], rest[4])
                local target_compression = self_compression + pull_strength
                local target_length = rest_length * (1 - target_compression)

                if current_length > 1e-6 and target_length < current_length then
                    local scale = target_length / current_length
                    dx = dx * scale
                    dy = dy * scale
                end
            end
        end

        smoothed_mesh_data[i] = { origin_x, origin_y, dx, dy }
    end

    local force_x, force_y = 0, 0

    -- Third pass: Apply memory foam and finalize
    for i = 2, #self._mesh_data do
        local data = self._mesh_data[i]
        local smoothed_data = smoothed_mesh_data[i]
        local rest = self._rest_mesh_data[i]

        local origin_x, origin_y = smoothed_data[1], smoothed_data[2]
        local dx, dy = smoothed_data[3], smoothed_data[4]

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

        local rest_data = self._rest_mesh_data[i]
        local rest_origin_x, rest_origin_y, rest_dx, rest_dy = table.unpack(rest_data)
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

    local force_scale = 3
    self._outer_body:apply_force(force_x * force_scale, force_y * force_scale)

    -- outer movement for debugging
    local current_x, current_y = self._outer_body:get_position()
    if not love.keyboard.isDown("space") then
        self._outer_body:set_velocity(self._outer_target_x - current_x, self._outer_target_y - current_y)
    end
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