require "common.player_body"

rt.settings.overworld.player_tether = {
    node_density = 0.1,
    gravity = 4
}

--- @class ow.PlayerTether
ow.PlayerTether = meta.class("PlayerTether")

--- @brief
function ow.PlayerTether:instantiate()
    self._is_tethered = false
end

--- @brief
function ow.PlayerTether:tether(attachment_x, attachment_y, target_x, target_y)
    if self._is_tethered == true then
        for rope in values(self._ropes) do
            rope.position_x, rope.position_y = attachment_x, attachment_y
            rope.target_x, rope.target_y = target_x, target_y

            rope.current_positions[#rope.current_positions - 1] = target_x
            rope.current_positions[#rope.current_positions - 0] = target_y

            local n_nodes = math.ceil(math.max(3, math.distance(
                attachment_x, attachment_y,
                target_x, target_y
            ) * rt.settings.overworld.player_tether.node_density))
            if rope.n_nodes ~= n_nodes then
                if rope.n_nodes < n_nodes then
                    local path = rt.Path(rope.current_positions)
                    for node_i = rope.n_nodes, n_nodes do
                        local t = (node_i - 1) / n_nodes
                        local x, y = path:at(t)
                        local x_index = (node_i - 1) * 2 + 1
                        local y_index = (node_i - 1) * 2 + 2

                        rope.current_positions[x_index] = x
                        rope.current_positions[y_index] = y
                        rope.last_positions[x_index] = x
                        rope.last_positions[y_index] = y
                        rope.last_velocities[x_index] = 0
                        rope.last_velocities[y_index] = 0
                        rope.masses[node_i] = 1
                    end

                    rope.n_nodes = n_nodes
                else
                    while rope.n_nodes > n_nodes do
                        table.remove(rope.current_positions)
                        table.remove(rope.current_positions)
                        table.remove(rope.last_positions)
                        table.remove(rope.last_positions)
                        table.remove(rope.last_velocities)
                        table.remove(rope.last_velocities)
                        table.remove(rope.masses)
                        rope.n_nodes = rope.n_nodes - 1
                    end
                end

                assert(rope.n_nodes == n_nodes)
            end
        end
    else
        local ax, ay = attachment_x, attachment_y
        local bx, by = target_x, target_y
        local dx, dy = math.normalize(bx - ax, by - ay)
        local distance = math.distance(attachment_x, attachment_y, target_x, target_y)
        local n_nodes = math.max(3, distance * rt.settings.overworld.player_tether.node_density)

        self._ropes = {}
        for rope_i = 1, 1 do
            local rope = {
                current_positions = {},
                last_positions = {},
                last_velocities = {},
                masses = {},
                position_x = ax,
                position_y = ay,
                target_x = bx,
                target_y = by,
                segment_length = 4,
                n_nodes = n_nodes
            }

            for node_i = 1, n_nodes do
                local t = (node_i - 1) / n_nodes
                local x, y = ax + t * dx * distance, ay + t * dy * distance
                table.insert(rope.current_positions, x)
                table.insert(rope.current_positions, y)
                table.insert(rope.last_positions, x)
                table.insert(rope.last_positions, y)
                table.insert(rope.last_velocities, 0)
                table.insert(rope.last_velocities, 0)
                table.insert(rope.masses, 1)
            end

            table.insert(self._ropes, rope)
        end

        self._is_tethered = true
    end
end

--- @brief
function ow.PlayerTether:untether()
    if self._is_tethered == false then return end
    self._ropes = {}
end

--- @brief
function ow.PlayerTether:update(delta)
    require "common.player_body"

    local todo = rt.settings.player_body.non_contour
    for rope in values(self._ropes) do
        rope.current_positions[#rope.current_positions - 1] = rope.target_x
        rope.current_positions[#rope.current_positions - 0] = rope.target_y

        rt.PlayerBody.update_rope({
            current_positions = rope.current_positions,
            last_positions = rope.last_positions,
            last_velocities = rope.last_velocities,
            masses = rope.masses,
            delta = delta,
            position_x = rope.position_x,
            position_y = rope.position_y,
            target_x = rope.target_x,
            target_y = rope.target_y,
            segment_length = rope.segment_length,

            n_velocity_iterations = 4,
            n_distance_iterations = 0,
            n_bending_iterations = 2,
            n_inverse_kinematics_iterations = 0,
            inverse_kinematics_intensity = 0.1,
            inertia = todo.inertia,
            velocity_damping = 1 - 0.75,
            gravity_x = 0,
            gravity_y = rt.settings.overworld.player_tether.gravity
        })

        rope.current_positions[#rope.current_positions - 1] = rope.target_x
        rope.current_positions[#rope.current_positions - 0] = rope.target_y
    end
end

--- @brief
function ow.PlayerTether:draw()
    local r, g, b, a = love.graphics.getColor()

    love.graphics.setLineJoin("none")

    local line_width = 2
    love.graphics.setLineWidth(line_width + 1.5)
    rt.Palette.BLACK:bind()
    for rope in values(self._ropes) do
        love.graphics.line(rope.current_positions)
    end

    love.graphics.setLineWidth(line_width)
    love.graphics.setColor(r, g, b, a)
    for rope in values(self._ropes) do
        love.graphics.line(rope.current_positions)
    end
end

--- @brief
function ow.PlayerTether:get_is_tethered()
    return self._is_tethered
end