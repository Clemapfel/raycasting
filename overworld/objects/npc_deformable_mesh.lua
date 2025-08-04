rt.settings.overworld.deformable_mesh = {
    spring_constant = 1,
    elasticity = 6,
    smoothing_strength = 0.1,
    smoothing_range = 3,
    subdivide_step = 5,
    gravity = 0, -- px / s
    downwards_scale_factor = 0, -- scales part of mesh pointing downwards
    outline_width = 5
}

require "common.contour"
require "common.delaunay_triangulation"

--- @class ow.DeformableMesh
ow.DeformableMesh = meta.class("DeformableMesh")

local _shader, _outline_shader

local _mesh_format = {
    { location = rt.VertexAttributeLocation.POSITION, name = rt.VertexAttribute.POSITION, format = "floatvec2" },
    { location = rt.VertexAttributeLocation.TEXTURE_COORDINATES, name = rt.VertexAttribute.TEXTURE_COORDINATES, format = "floatvec2" },
    { location = rt.VertexAttributeLocation.COLOR, name = rt.VertexAttribute.COLOR, format = "floatvec4" },
} -- xy stores origin, uv stores dxy, rg stores rest origin, ba stores rest dxy


function ow.DeformableMesh:instantiate(scene, world, contour)
    if _shader == nil then _shader = rt.Shader("overworld/objects/npc_deformable_mesh.glsl", { OUTLINE = false }) end
    if _outline_shader == nil then _outline_shader = rt.Shader("overworld/objects/npc_deformable_mesh.glsl", { OUTLINE = true }) end

    -- TODO
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "l" then _shader:recompile(); _outline_shader:recompile() end
    end)

    meta.assert(scene, ow.OverworldScene, world, b2.World)
    self._scene = scene
    self._world = world

    -- player data
    self._outer_x, self._outer_y, self._outer_radius = 0, 0, 0

    local deformable_max_depth = rt.settings.player.radius * rt.settings.player.bubble_radius_factor
    self._thickness = deformable_max_depth
    self._contour = contour
    self._draw_contour = table.deepcopy(contour)

    local max_y = -math.huge
    local min_y = math.huge

    -- construct center vectors
    local center_x, center_y = 0, 0
    local n = 0
    for i = 1, #contour, 2 do
        local y =  contour[i+1]
        center_x = center_x + contour[i+0]
        center_y = center_y + y

        if y >= max_y then max_y = y end
        if y <= min_y then min_y = y end
        n = n + 1
    end

    center_x = center_x / n
    center_y = center_y / n
    self._center_x, self._center_y = center_x, center_y
    self._base_x, self._base_y = center_x, max_y
    self._height = max_y - min_y

    do -- hard inner shell
        local inner_body_contour = {
            0, 0 -- local coords
        }

        local downwards_scale_factor = rt.settings.overworld.deformable_mesh.downwards_scale_factor
        local downwards_angle = 3 * math.pi / 2 -- straight downwards
        local outline_width = rt.settings.overworld.deformable_mesh.outline_width

        for i = 1, #contour + 2, 2 do
            local x1 = contour[math.wrap(i+0, #contour)]
            local y1 = contour[math.wrap(i+1, #contour)]

            local dx, dy = x1 - center_x, y1 - center_y
            local length = math.magnitude(dx, dy)
            dx, dy = math.normalize(dx, dy)

            -- scale vectors the closer they are to pointing downwards, for bottom-heavy inner shell
            local angle = math.angle(dx, dy)
            local diff = math.abs(math.normalize_angle(angle - downwards_angle))
            if diff > math.pi then diff = 2 * math.pi - diff end
            local penalty = 1 + (diff / math.pi) * downwards_scale_factor

            -- rescale so there is at least 0.5 * player spaced
            local final_length = math.clamp(penalty * length - deformable_max_depth, length - deformable_max_depth, length)

            table.insert(inner_body_contour, dx * final_length)
            table.insert(inner_body_contour, dy * final_length)
        end

        local shapes = {}
        for tri in values(rt.DelaunayTriangulation(inner_body_contour):get_triangles()) do
            table.insert(shapes, b2.Polygon(tri))
        end

        self._inner_body = b2.Body(world, b2.BodyType.KINEMATIC, center_x, center_y, shapes)
    end

    self._highlight = rt.generate_contour_highlight(self._contour, 1, 1, 250, 0.5 * deformable_max_depth)

    -- subdivide, then get outer shape
    contour = rt.subdivide_contour(contour, rt.settings.overworld.deformable_mesh.subdivide_step)
    contour = rt.smooth_contour(contour, 2)

    local mesh_data = {
        { center_x, center_y, 0, 0, 1, 1, 1, 1 }
    }

    local max_length = -math.huge
    for i = 1, #contour + 2, 2 do
        -- get vector from center to point
        local x1 = contour[math.wrap(i+0, #contour)]
        local y1 = contour[math.wrap(i+1, #contour)]

        local dx, dy = x1 - center_x, y1 - center_y
        local length = math.magnitude(dx, dy)
        dx, dy = math.normalize(dx, dy)
        dx = dx * math.min(deformable_max_depth, length)
        dy = dy * math.min(deformable_max_depth, length)

        if length > max_length then max_length = length end

        -- get new vector origin
        local ox, oy = x1 - dx, y1 - dy

        table.insert(mesh_data, {
            ox, oy,     -- vertex position = origin of vector
            dx, dy,      -- texture_coords = vector
            ox, oy, -- copy of rest data
            dx, dy
        })
    end

    self._max_length = max_length
    self._mesh_data = mesh_data
    self._mesh_data_at_rest = table.deepcopy(self._mesh_data)

    self._mesh = rt.Mesh(
        mesh_data,
        rt.MeshDrawMode.TRIANGLE_FAN,
        _mesh_format,
        rt.GraphicsBufferUsage.STREAM
    )

    -- wave
    self._n_points = math.floor(#self._contour / 2)
    self._wave = {
        previous = table.rep(0, self._n_points),
        current = table.rep(0, self._n_points),
        next = {}
    }
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

    local push_dx, push_dy = dx, dy
    if push_blend > 0 then
        local t = math.max(0, math.min(1, projection_length / segment_length))
        local closest_x = origin_x + t * dx
        local closest_y = origin_y + t * dy

        local closest_distance_x = closest_x - circle_x
        local closest_distance_y = closest_y - circle_y
        local closest_distance_squared = closest_distance_x * closest_distance_x + closest_distance_y * closest_distance_y

        if closest_distance_squared < circle_radius * circle_radius then
            local closest_distance = math.sqrt(closest_distance_squared)
            local penetration = circle_radius - closest_distance + 1

            local push_direction_x, push_direction_y
            if closest_distance > 1e-6 then
                push_direction_x = closest_distance_x / closest_distance
                push_direction_y = closest_distance_y / closest_distance
            else
                -- If the closest point is at the center, pick a perpendicular direction to dx,dy
                local norm = math.sqrt(dx * dx + dy * dy)
                if norm > 1e-6 then
                    push_direction_x = -dy / norm
                    push_direction_y = dx / norm
                else
                    push_direction_x = 1
                    push_direction_y = 0
                end
            end

            local extension_needed = (t < 1e-6) and (penetration) or (penetration / t)

            push_dx = dx + push_direction_x * extension_needed
            push_dy = dy + push_direction_y * extension_needed
        end
    end

    return math.mix2(
        push_dx, push_dy,
        direction_x * maximum_safe_length, direction_y * maximum_safe_length,
        push_blend
    )
end

-- Returns contact_x, contact_y, normal_x, normal_y or nil if no collision
local function _line_circle_collision(origin_x, origin_y, dx, dy, circle_x, circle_y, circle_radius)
    -- Vector from segment origin to circle center
    local ox, oy = origin_x - circle_x, origin_y - circle_y

    -- Quadratic coefficients for intersection
    local a = dx * dx + dy * dy
    local b = 2 * (ox * dx + oy * dy)
    local c = ox * ox + oy * oy - circle_radius * circle_radius

    local discriminant = b * b - 4 * a * c
    if discriminant < 0 then
        return nil -- No intersection
    end

    local sqrt_disc = math.sqrt(discriminant)
    local t1 = (-b - sqrt_disc) / (2 * a)
    local t2 = (-b + sqrt_disc) / (2 * a)

    -- We want the smallest t in [0,1]
    local t = nil
    if t1 >= 0 and t1 <= 1 then
        t = t1
    elseif t2 >= 0 and t2 <= 1 then
        t = t2
    else
        return nil -- Intersection is outside the segment
    end

    -- Contact point
    local contact_x = origin_x + dx * t
    local contact_y = origin_y + dy * t

    -- Collision normal (from circle center to contact point, normalized)
    local nx = contact_x - circle_x
    local ny = contact_y - circle_y
    local len = math.sqrt(nx * nx + ny * ny)
    if len == 0 then
        return nil -- Degenerate case: contact at center
    end
    local normal_x = nx / len
    local normal_y = ny / len

    return contact_x, contact_y, normal_x, normal_y
end

function ow.DeformableMesh:step(delta, outer_x, outer_y, outer_r)
    meta.assert(delta, "Number", outer_x, "Number", outer_y, "Number", outer_r, "Number")

    require "common.debugger"
    local settings = rt.settings.overworld.deformable_mesh
    local elasticity = settings.elasticity
    local smoothing_strength = settings.smoothing_strength
    local smoothing_range = settings.smoothing_range
    local max_displacement = self._thickness
    local gravity = settings.gravity

    -- compression data for neighbor smoothing
    local compression_ratios = {}

    -- first pass: collision detection and store compression data
    for i = 2, #self._mesh_data do -- skip first, which is center
        local data = self._mesh_data[i]
        local rest = self._mesh_data_at_rest[i]
        local origin_x, origin_y = data[1], data[2]
        local dx, dy = data[3], data[4]

        dx, dy = _collide(origin_x, origin_y, dx, dy, outer_x, outer_y, outer_r, 1)

        local length = math.magnitude(dx, dy)
        local rest_length = math.magnitude(rest[3], rest[4])

        if length < 1 or math.dot(dx, dy, rest[3], rest[4]) < 1 then -- vectors point in opposit directions
            -- rescale to 1 to avoid numerical instability
            dx, dy = math.normalize(rest[3], rest[4])
            dx = dx * 1
            dy = dy * 1
        elseif length > rest_length then
            dx, dy = math.normalize(rest[3], rest[4])
            dx = dx * rest_length
            dy = dy * rest_length
        end

        local tip_x, tip_y = origin_x + dx, origin_y + dy
        local distance = math.distance(tip_x, tip_y, outer_x, outer_y)

        if distance < outer_r then
            local penetration = outer_r - distance

            local compression_factor
            if length > math.eps then
                compression_factor = penetration / length
            else
                compression_factor = 0
            end

            dx = dx * (1 - compression_factor)
            dy = dy * (1 - compression_factor)
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

    -- move towards rest position (memory foam)
    local contour_i = 1
    for i = 2, #self._mesh_data do
        local data = self._mesh_data[i]
        local rest = self._mesh_data_at_rest[i]

        local origin_x, origin_y, dx, dy = table.unpack(data)
        local rest_origin_x, rest_origin_y, rest_dx, rest_dy = table.unpack(rest)
        dx = dx + (rest_dx - dx) * elasticity * delta
        dy = dy + (rest_dy - dy) * elasticity * delta
        origin_x = origin_x + (rest_origin_x - origin_x) * elasticity * delta
        origin_y = origin_y + (rest_origin_y - origin_y) * elasticity * delta

        dx = dx + delta * 0
        dy = dy + delta * gravity

        local length = math.magnitude(dx, dy)
        local max_length = math.magnitude(rest_dx, rest_dy)
        if length > max_length then
            dx = dx * (max_length / length)
            dy = dy * (max_length / length)
        end

        local ax, ay = origin_x + dx, origin_y + dy
        local bx, by = rest_origin_x + rest_dx, rest_origin_y + rest_dy

        data[1], data[2] = origin_x, origin_y
        data[3], data[4] = dx, dy

        self._draw_contour[contour_i+0] = origin_x + dx
        self._draw_contour[contour_i+1] = origin_y + dy
        contour_i = contour_i + 2
    end

    self._mesh:replace_data(self._mesh_data)
end

--- @brief
function ow.DeformableMesh:_apply_translation()
    local inner_x, inner_y = self._inner_body:get_position()
    love.graphics.translate(inner_x - self._center_x, inner_y - self._center_y)
end

--- @brief
function ow.DeformableMesh:draw_body()
    love.graphics.push()
    self:_apply_translation()

    _shader:bind()
    _shader:send("camera_offset", { self._scene:get_camera():get_offset() })
    _shader:send("camera_scale", self._scene:get_camera():get_final_scale())
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    self._mesh:draw()
    _shader:unbind()

    love.graphics.pop()
end

function ow.DeformableMesh:draw_highlight()
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.polygon("fill", self._highlight)
end

--- @brief
function ow.DeformableMesh:get_contour()
    return self._draw_contour
end

--- @brief
function ow.DeformableMesh:draw_outline()
    --[[
    _outline_shader:bind()
    _outline_shader:send("camera_offset", { self._scene:get_camera():get_offset() })
    _outline_shader:send("camera_scale", self._scene:get_camera():get_final_scale())
    _outline_shader:send("elapsed", rt.SceneManager:get_elapsed())
    ]]--
    love.graphics.line(self._draw_contour)
    --_outline_shader:unbind()
end

--- @brief
function ow.DeformableMesh:draw_base()
    love.graphics.push()

    love.graphics.polygon("fill", self._contour)

    love.graphics.pop()

    self._inner_body:draw()
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

--- @brief
function ow.DeformableMesh:get_base()
    return self._base_x, self._base_y
end

--- @brief
function ow.DeformableMesh:get_height()
    return self._height
end

--- @brief
function ow.DeformableMesh:get_radius()
    return self._max_length
end