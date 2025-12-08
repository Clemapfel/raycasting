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

    self._cached_path = nil -- rt.Path
    self._path_needs_update = true
end

--- @brief
function ow.Tether:tether(attachment_x, attachment_y, target_x, target_y)
    local settings = rt.settings.overworld.tether
    if self._is_tethered == true then
        local rope = self._rope
        rope.position_x, rope.position_y = attachment_x, attachment_y
        rope.target_x, rope.target_y = target_x, target_y

        local end_x = rope.current_positions[#rope.current_positions - 1]
        local end_y = rope.current_positions[#rope.current_positions - 0]
        rope.current_positions[#rope.current_positions - 1] = target_x
        rope.current_positions[#rope.current_positions - 0] = target_y

        local n_nodes = math.ceil(math.clamp(
            math.distance(attachment_x, attachment_y, target_x, target_y) * settings.node_density,
            settings.min_n_nodes,
            settings.max_n_nodes
        ))

        -- Use actual current node count derived from the buffer length to avoid drift
        local current_n = math.floor(#rope.current_positions / 2)
        rope.n_nodes = current_n

        -- extend / shorten if necessary
        if current_n ~= n_nodes then
            if current_n < n_nodes then
                -- extend
                for node_i = current_n + 1, n_nodes do
                    local t = (node_i - current_n) / (n_nodes - current_n)
                    local x, y = math.mix2(end_x, end_y, target_x, target_y, t)
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

                current_n = n_nodes
            else
                -- shorten
                while current_n > n_nodes do
                    table.remove(rope.current_positions) -- y
                    table.remove(rope.current_positions) -- x
                    table.remove(rope.last_positions)
                    table.remove(rope.last_positions)
                    table.remove(rope.last_velocities)
                    table.remove(rope.last_velocities)
                    table.remove(rope.masses)
                    current_n = current_n - 1
                end
            end

            rope.n_nodes = n_nodes
        end
    else
        local ax, ay = attachment_x, attachment_y
        local bx, by = target_x, target_y
        local dx, dy = math.normalize(bx - ax, by - ay)
        local distance = math.distance(attachment_x, attachment_y, target_x, target_y)

        local n_nodes = math.ceil(math.clamp(
            distance * settings.node_density,
            settings.min_n_nodes,
            settings.max_n_nodes
        ))

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
    self._rope = {}
    self._is_tethered = false
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

    local rope = self._rope
    if not rope.current_positions or #rope.current_positions < 2 then return end

    -- Keep end at the target
    rope.current_positions[#rope.current_positions - 1] = rope.target_x
    rope.current_positions[#rope.current_positions - 0] = rope.target_y

    local rope_changed = rt.PlayerBody.update_rope({
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

    if rope_changed == true then self._path_needs_update = true end
end

--- @brief
function ow.Tether:draw()
    local r, g, b, a = love.graphics.getColor()
    local rope = self._rope
    if not rope.current_positions or #rope.current_positions < 2 then return end

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

    -- Example of future bulge/path usage (kept as-is)
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
function ow.Tether:as_path()
    if self._cached_path == nil or self._path_needs_update then
        self._cached_path = rt.Path(self._rope.current_positions)
    end

    return self._cached_path
end