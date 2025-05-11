--- @class ow.PlayerBody
ow.PlayerBody = meta.class("PlayerBody")

--- @brief
function ow.PlayerBody:instantiate(player)
    meta.assert(player, ow.Player)

    self._player = player
    self._ropes = {}
    self._elapsed = 0
end

--- @brief
function ow.PlayerBody:initialize(positions, floor_ax, floor_ay, floor_bx, floor_by)
    local success, new_tris = false, self._tris
    success, new_tris = pcall(love.math.triangulate, positions)
    if not success then
        success, new_tris = pcall(slick.triangulate, { positions })
    end

    self._tris = new_tris
    self._center_x, self._center_y = positions[1], positions[2]
    self._is_bubble = self._player:get_is_bubble()

    self._use_ground = floor_ax ~= nil
    self._floor_ax, self._floor_ay, self._floor_bx, self._floor_by = floor_ax, floor_ay, floor_bx, floor_by

    for tri in values(self._tris) do
        local center_x = (tri[1] + tri[3] + tri[5]) / 3
        local center_y = (tri[2] + tri[4] + tri[6]) / 3
        table.insert(positions, center_x)
        table.insert(positions, center_y)
    end

    local radius = self._player:get_radius()
    local n_rings = 10
    local n_ropes_per_ring = #positions / 2
    local max_rope_length = radius * 5

    if table.sizeof(self._ropes) < table.sizeof(self._tris) then
        self._n_segments = 16
        self._n_ropes = table.sizeof(self._tris)
        self._ropes = {}

        for ring = 1, n_rings do
            local ring_radius = ((ring - 1) / n_rings) * radius
            for i = 1, n_ropes_per_ring do
                local angle = (i - 1) / n_ropes_per_ring * 2 * math.pi
                local center_x = math.cos(angle) * ring_radius
                local center_y = math.sin(angle) * ring_radius

                local rope = {
                    current_positions = {},
                    last_positions = {},
                    distances = {},
                    anchor_x = center_x,
                    anchor_y = center_y,
                    hue = 1 - (ring - 1) / n_rings
                }

                rope.axis_x, rope.axis_y = math.normalize(center_x, center_y)

                center_x = center_x + self._center_x
                center_y = center_y + self._center_y

                local rope_length = (1 - math.distance(center_x, center_y, self._center_x, self._center_y) / radius) * max_rope_length
                rope.length = rope_length
                local dx, dy = math.normalize(rope.anchor_x - self._center_x, rope.anchor_y - self._center_y)
                for j = 1, self._n_segments do
                    local delta = (j - 1) / self._n_segments * rope_length
                    local px = center_x + dx * delta
                    local py = center_y + dy * delta
                    table.insert(rope.current_positions, px)
                    table.insert(rope.current_positions, py)
                    table.insert(rope.last_positions, px)
                    table.insert(rope.last_positions, py)
                    table.insert(rope.distances, rope_length / self._n_segments)
                end

                table.insert(self._ropes, rope)
            end
        end
    else
        local rope_i = 1
        for ring = 1, n_rings do
            local ring_radius = ((ring - 1) / n_rings) * radius
            for i = 1, n_ropes_per_ring do
                if self._ropes[rope_i] ~= nil then -- catch corrupted mesh
                    local contour_index = (i - 1) * 2 + 1
                    local contour_x = positions[contour_index]
                    local contour_y = positions[contour_index + 1]
                    local dx = contour_x - self._center_x
                    local dy = contour_y - self._center_y

                    dx = dx / radius
                    dy = dy / radius

                    local rope = self._ropes[rope_i]
                    rope.anchor_x = dx * ring_radius
                    rope.anchor_y = dy * ring_radius
                    rope_i = rope_i + 1
                end
            end
        end
    end
end

local _step = 1 / 120
local _gravity = 100
local _axis_stiffness = 1
local _bending_stiffness = 1
local _velocity_damping = 0.9
local _n_velocity_iterations = 1
local _n_distance_iterations = 8
local _n_axis_iterations = 2
local _n_bending_iterations = 0

local function _solve_distance_constraint(a_x, a_y, b_x, b_y, rest_length)
    local current_distance = math.distance(a_x, a_y, b_x, b_y)
    if current_distance < 10e-5 then return a_x, a_y, b_x, b_y end

    local delta_x = b_x - a_x
    local delta_y = b_y - a_y
    local distance_correction = (current_distance - rest_length) / current_distance
    local correction_x = delta_x * distance_correction
    local correction_y = delta_y * distance_correction

    local blend = 0.5
    a_x = a_x + correction_x * blend
    a_y = a_y + correction_y * blend
    b_x = b_x - correction_x * blend
    b_y = b_y - correction_y * blend

    return a_x, a_y, b_x, b_y
end

local function _solve_axis_constraint(a_x, a_y, b_x, b_y, axis_x, axis_y, stiffness)
    local delta_x = b_x - a_x
    local delta_y = b_y - a_y

    -- Project the delta vector onto the axis
    local dot_product = math.abs(delta_x * axis_x + delta_y * axis_y)
    local projection_x = dot_product * axis_x
    local projection_y = dot_product * axis_y

    -- Calculate the correction to align with the axis
    local correction_x = (projection_x - delta_x) * stiffness
    local correction_y = (projection_y - delta_y) * stiffness

    -- Apply corrections symmetrically to avoid zig-zag patterns
    local blend = 0.5
    a_x = a_x - correction_x * blend
    a_y = a_y - correction_y * blend
    b_x = b_x + correction_x * blend
    b_y = b_y + correction_y * blend

    return a_x, a_y, b_x, b_y
end

local function _solve_bending_constraint(a_x, a_y, b_x, b_y, c_x, c_y, rest_length, stiffness)
    local ab_x = b_x - a_x
    local ab_y = b_y - a_y
    local bc_x = c_x - b_x
    local bc_y = c_y - b_y

    -- Normalize the vectors
    ab_x, ab_y = math.normalize(ab_x, ab_y)
    bc_x, bc_y = math.normalize(bc_x, bc_y)

    -- Calculate the target direction to smooth the bend
    local target_x = ab_x + bc_x
    local target_y = ab_y + bc_y
    local target_length = math.sqrt(target_x * target_x + target_y * target_y)
    if target_length > 0 then
        target_x, target_y = target_x / target_length, target_y / target_length
    end

    -- Calculate the correction to maintain smoothness
    local correction_x = target_x * stiffness
    local correction_y = target_y * stiffness

    -- Adjust positions while preserving distances
    local blend = 0.5
    a_x = a_x - correction_x * blend
    a_y = a_y - correction_y * blend
    c_x = c_x + correction_x * blend
    c_y = c_y + correction_y * blend

    return a_x, a_y, c_x, c_y
end

--- @brief
function ow.PlayerBody:update(delta)
    self._elapsed = self._elapsed + delta

    local player_x, player_y = self._player:get_physics_body():get_predicted_position()
    local axis_x, axis_y = self._player:get_velocity()
    axis_x = 0
    axis_y = 1

    while self._elapsed > _step do
        self._elapsed = self._elapsed - _step

        local delta_squared = _step * _step

        local mass = 1
        for rope in values(self._ropes) do
            local positions = rope.current_positions
            local old_positions = rope.last_positions
            local distances = rope.distances
            local gravity_x, gravity_y = axis_x * _gravity, axis_y * _gravity

            if self._is_bubble then
                gravity_x, gravity_y = 0, 0
            end

            local n_axis_iterations = 0
            local n_distance_iterations = 0
            local n_velocity_iterations = 0
            local n_bending_iterations = 0

            while (self._is_bubble and n_axis_iterations < _n_axis_iterations) or n_distance_iterations <_n_distance_iterations or n_velocity_iterations < _n_velocity_iterations do
                -- velocity
                if n_velocity_iterations < _n_velocity_iterations then
                    for i = 1, #positions, 2 do
                        local current_x, current_y = positions[i], positions[i+1]
                        local old_x, old_y = old_positions[i], old_positions[i+1]

                        local before_x, before_y = current_x, current_y

                        positions[i] = current_x + (current_x - old_x) * _velocity_damping + gravity_x * mass * delta_squared
                        positions[i+1] = current_y + (current_y - old_y) * _velocity_damping + gravity_y * mass * delta_squared

                        old_positions[i] = before_x
                        old_positions[i+1] = before_y
                    end

                    n_velocity_iterations = n_velocity_iterations + 1
                end

                -- axis
                if self._is_bubble and n_axis_iterations < _n_axis_iterations then
                    for i = 1, #positions - 2, 2 do
                        local node_1_xi, node_1_yi, node_2_xi, node_2_yi = i, i+1, i+2, i+3
                        local node_1_x, node_1_y = positions[node_1_xi], positions[node_1_yi]
                        local node_2_x, node_2_y = positions[node_2_xi], positions[node_2_yi]

                        local new_x1, new_y1, new_x2, new_y2 = _solve_axis_constraint(
                            node_1_x, node_1_y, node_2_x, node_2_y, rope.axis_x, rope.axis_y,
                            _axis_stiffness
                        )

                        positions[node_1_xi] = new_x1
                        positions[node_1_yi] = new_y1
                        positions[node_2_xi] = new_x2
                        positions[node_2_yi] = new_y2
                    end

                    n_axis_iterations = n_axis_iterations + 1
                end

                -- bending
                if n_bending_iterations < _n_bending_iterations then
                    local distance_i = 1
                    for i = 1, #positions - 4, 2 do
                        local node_1_xi, node_1_yi, node_2_xi, node_2_yi, node_3_xi, node_3_yi = i, i+1, i+2, i+3, i+4, i+5
                        local node_1_x, node_1_y = positions[node_1_xi], positions[node_1_yi]
                        local node_2_x, node_2_y = positions[node_2_xi], positions[node_2_yi]
                        local node_3_x, node_3_y = positions[node_3_xi], positions[node_3_yi]

                        local new_x1, new_y1, new_x3, new_y3 = _solve_bending_constraint(
                            node_1_x, node_1_y, node_2_x, node_2_y, node_3_x, node_3_y,
                            distances[distance_i] + distances[distance_i+1],
                            _bending_stiffness * (1 - i / #positions)
                        )
                        distance_i = distance_i + 1

                        positions[node_1_xi] = new_x1
                        positions[node_1_yi] = new_y1
                        positions[node_3_xi] = new_x3
                        positions[node_3_yi] = new_y3
                    end

                    n_axis_iterations = n_axis_iterations + 1
                end

                -- distance
                if n_distance_iterations < _n_distance_iterations then
                    local distance_i = 1
                    for i = 1, #positions - 2, 2 do
                        local node_1_xi, node_1_yi, node_2_xi, node_2_yi = i, i+1, i+2, i+3
                        local node_1_x, node_1_y = positions[node_1_xi], positions[node_1_yi]
                        local node_2_x, node_2_y = positions[node_2_xi], positions[node_2_yi]

                        if i == 1 then
                            node_1_x = player_x + rope.anchor_x
                            node_1_y = player_y + rope.anchor_y
                        end

                        local rest_length = distances[distance_i]

                        local new_x1, new_y1, new_x2, new_y2 = _solve_distance_constraint(
                            node_1_x, node_1_y, node_2_x, node_2_y,
                            rest_length
                        )

                        positions[node_1_xi] = new_x1
                        positions[node_1_yi] = new_y1
                        positions[node_2_xi] = new_x2
                        positions[node_2_yi] = new_y2
                    end

                    n_distance_iterations = n_distance_iterations + 1
                end
            end
        end
    end

    if not self._is_bubble and self._use_ground then
        -- move all bodies above ground line
        local ax, ay = self._floor_ax, self._floor_ay
        local bx, by = self._floor_bx, self._floor_by

        for rope in values(self._ropes) do
            local positions = rope.current_positions

            for i = 1, #positions, 2 do
                local px, py = positions[i], positions[i + 1]

                -- Calculate the perpendicular projection of (px, py) onto the line (ax, ay) -> (bx, by)
                local ab_x, ab_y = bx - ax, by - ay
                local ap_x, ap_y = px - ax, py - ay
                local ab_length_squared = ab_x * ab_x + ab_y * ab_y
                local dot_product = (ap_x * ab_x + ap_y * ab_y) / ab_length_squared

                -- Find the closest point on the line
                local closest_x = ax + dot_product * ab_x
                local closest_y = ay + dot_product * ab_y

                -- Check if the point is below the line
                local normal_x, normal_y = -ab_y, ab_x -- Perpendicular vector
                local to_point_x, to_point_y = px - closest_x, py - closest_y
                local side = to_point_x * normal_x + to_point_y * normal_y

                if side > 0 then
                    -- Move the point to the closest point on the line
                    positions[i] = closest_x
                    positions[i + 1] = closest_y
                end
            end
        end
    end
end

--- @brief
function ow.PlayerBody:draw(is_bubble)
    love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
    for tri in values(self._tris) do
        love.graphics.polygon("fill", tri)
    end

    love.graphics.setLineWidth(1)
    local rope_i, n_ropes = 0, table.sizeof(self._ropes)
    for rope in values(self._ropes) do
        for i = 1, self._n_segments, 2 do
            love.graphics.setColor(rope.hue, rope.hue, rope.hue, 1)
            local node_1_x, node_1_y = rope.current_positions[i + 0], rope.current_positions[i + 1]
            local node_2_x, node_2_y = rope.current_positions[i + 2], rope.current_positions[i + 3]

            love.graphics.line(node_1_x, node_1_y, node_2_x, node_2_y)
            rope_i = rope_i + 1
        end
    end
end