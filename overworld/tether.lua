require "common.player_body"
require "common.path"

rt.settings.overworld.tether = {
    node_density = 0.1,
    gravity = 4,

    min_n_nodes = 3,
    max_n_nodes = 1024,

    buldge_radius = 20
}

--- @class ow.Tether
ow.Tether = meta.class("Tether")

local _bulge = nil

--- @brief
function ow.Tether:instantiate()
    self._is_tethered = false
    self._rope = {}

    self._draw_buldge = false
    self._buldge_x, self._buldge_y = nil, nil -- Number
end

--- @brief
function ow.Tether:tether(attachment_x, attachment_y, target_x, target_y)
    if self._is_tethered == true then
        local rope = self._rope
        rope.position_x, rope.position_y = attachment_x, attachment_y
        rope.target_x, rope.target_y = target_x, target_y

        local end_x = rope.current_positions[#rope.current_positions - 1]
        local end_y = rope.current_positions[#rope.current_positions - 0]
        rope.current_positions[#rope.current_positions - 1] = target_x
        rope.current_positions[#rope.current_positions - 0] = target_y

        local n_nodes = math.ceil(math.clamp(math.distance(
            attachment_x, attachment_y,
            target_x, target_y
        ) * rt.settings.overworld.tether.node_density,
            rt.settings.overworld.tether.min_n_nodes,
            rt.settings.overworld.tether.max_n_nodes
        ))

        -- extend / shorten if necessary

        if rope.n_nodes ~= n_nodes then
            if rope.n_nodes < n_nodes then
                for node_i = rope.n_nodes, n_nodes do
                    local t = (node_i - rope.n_nodes) / (n_nodes - rope.n_nodes)                        local x, y = math.mix2(end_x, end_y, target_x, target_y, t)
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
    else
        local ax, ay = attachment_x, attachment_y
        local bx, by = target_x, target_y
        local dx, dy = math.normalize(bx - ax, by - ay)
        local distance = math.distance(attachment_x, attachment_y, target_x, target_y)
        local n_nodes = math.max(3, distance * rt.settings.overworld.tether.node_density)

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

        self._rope = rope
        self._is_tethered = true
    end

    return self
end

--- @brief
function ow.Tether:untether()
    if self._is_tethered == false then return end
    self._ropes = {}
end

--- @brief
function ow.Tether:set_draw_bulge(t)
    self._draw_buldge = t ~= nil
    self._buldge_x, self._buldge_y = t
end

local _buldge = nil -- 2d vertives

--- @brief
function ow.Tether:update(delta)
    require "common.player_body"

    local todo = rt.settings.player_body.non_contour
    local rope = self._rope
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
        inertia = 0,
        velocity_damping = 1 - 0.5,
        gravity_x = 0,
        gravity_y = rt.settings.overworld.tether.gravity
    })

    rope.current_positions[#rope.current_positions - 1] = rope.target_x
    rope.current_positions[#rope.current_positions - 0] = rope.target_y

    if self._draw_buldge then
        if self._path == nil then
            self._path = rt.Path(rope.current_positions)
        else
            self._path:create_from(rope.current_positions)
        end
    end
end

--- @brief
function ow.Tether:draw()
    local r, g, b, a = love.graphics.getColor()
    local rope = self._rope

    love.graphics.setLineJoin("none")
    love.graphics.setLineStyle("rough")

    local line_width = love.graphics.getLineWidth()
    love.graphics.setLineWidth(line_width + 1.5)
    rt.Palette.BLACK:bind()
    love.graphics.line(rope.current_positions)

    love.graphics.setLineWidth(line_width)
    love.graphics.setColor(r, g, b, a)
    love.graphics.line(rope.current_positions)

    love.graphics.circle("fill",
        rope.current_positions[#rope.current_positions - 1],
        rope.current_positions[#rope.current_positions - 0],
        0.5 * line_width
    )

    local eps = 0.4
    local path = rt.Path(rope.current_positions)
    local length = path:get_length()
    local radius = 20
    local t = 0.5
    local x, y = path:at(t)
    local ax, ay = path:at(t - (radius / length))
    local bx, by = path:at(t + (radius / length))

end

--- @brief
function ow.Tether:get_is_tethered()
    return self._is_tethered
end

--- @brief
function ow.Tether:get_points()
    return self._rope.current_positions
end

--- @brief
function ow.Tether:as_path()
    return rt.Path(self._rope.current_positions)
end
