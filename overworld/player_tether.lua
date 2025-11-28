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
    local ax, ay = attachment_x, attachment_y
    local bx, by = target_x, target_y
    local dx, dy = math.normalize(bx - ax, by - ay)
    local distance = math.distance(ax, ay, bx, by)
    -- Round to nearest integer and clamp to minimum
    local n_nodes = math.max(3, math.floor(distance * rt.settings.overworld.player_tether.node_density + 0.5))

    if self._is_tethered == true then
        for rope in values(self._ropes) do
            rope.position_x, rope.position_y = ax, ay
            rope.target_x, rope.target_y = bx, by

            -- Ensure endpoints of current polyline match new anchor/target before any resampling
            if rope.current_positions and #rope.current_positions >= 2 then
                rope.current_positions[1], rope.current_positions[2] = ax, ay
                rope.current_positions[#rope.current_positions - 1], rope.current_positions[#rope.current_positions] = bx, by
            end

            if rope.n_nodes ~= n_nodes then
                -- Resample the existing curve (polyline) to desired node count using arc-length parameterization
                local function cumulative_lengths(pts)
                    -- pts is a flat array {x1,y1,x2,y2,...}
                    local cum = {0}
                    local total = 0
                    for i = 3, #pts, 2 do
                        local x0, y0 = pts[i - 2], pts[i - 1]
                        local x1, y1 = pts[i],     pts[i + 1]
                        total = total + math.distance(x0, y0, x1, y1)
                        table.insert(cum, total)
                    end
                    return cum, total
                end

                local function sample_polyline(pts, cum, total, t)
                    -- t in [0,1]
                    if total <= 1e-6 then
                        -- Degenerate: linear interpolation between endpoints
                        local x0, y0 = pts[1], pts[2]
                        local x1, y1 = pts[#pts - 1], pts[#pts]
                        return x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
                    end

                    local target_len = t * total
                    local idx = 2
                    for i = 2, #cum do
                        if target_len <= cum[i] then
                            idx = i
                            break
                        end
                    end

                    local seg_start_len = cum[idx - 1]
                    local seg_end_len = cum[idx]
                    local s = 0
                    if seg_end_len > seg_start_len then
                        s = (target_len - seg_start_len) / (seg_end_len - seg_start_len)
                    end

                    -- Convert cum index to point indices in flat array
                    local i0 = (idx - 1) * 2 - 1
                    local i1 = i0 + 2
                    local x0, y0 = pts[i0], pts[i0 + 1]
                    local x1, y1 = pts[i1], pts[i1 + 1]
                    return x0 + (x1 - x0) * s, y0 + (y1 - y0) * s
                end

                local cur = rope.current_positions
                local cum_cur, total_cur = cumulative_lengths(cur)

                local new_current, new_last, new_vel, new_masses = {}, {}, {}, {}
                local count = n_nodes

                for node_i = 1, count do
                    local t = (count == 1) and 0 or (node_i - 1) / (count - 1)
                    local x, y = sample_polyline(cur, cum_cur, total_cur, t)

                    -- current positions
                    table.insert(new_current, x)
                    table.insert(new_current, y)

                    -- last positions: resample if available and compatible, otherwise copy current
                    local lx, ly = x, y
                    if rope.last_positions and #rope.last_positions == #cur then
                        local cum_last, total_last = cumulative_lengths(rope.last_positions)
                        lx, ly = sample_polyline(rope.last_positions, cum_last, total_last, t)
                    end
                    table.insert(new_last, lx)
                    table.insert(new_last, ly)

                    -- velocities: reset to zero to avoid spikes on topology change
                    table.insert(new_vel, 0)
                    table.insert(new_vel, 0)

                    -- masses: keep uniform
                    table.insert(new_masses, 1)
                end

                -- Ensure exact endpoints (avoid numeric drift)
                new_current[1], new_current[2] = ax, ay
                new_current[#new_current - 1], new_current[#new_current] = bx, by
                new_last[1], new_last[2] = ax, ay
                new_last[#new_last - 1], new_last[#new_last] = bx, by

                rope.current_positions = new_current
                rope.last_positions = new_last
                rope.last_velocities = new_vel
                rope.masses = new_masses
                rope.n_nodes = count
            else
                -- Node count unchanged; still ensure end node matches target exactly
                rope.current_positions[#rope.current_positions - 1] = bx
                rope.current_positions[#rope.current_positions - 0] = by
                -- Also ensure start matches anchor
                rope.current_positions[1], rope.current_positions[2] = ax, ay
            end
        end
    else
        -- First-time tether: initialize with evenly spaced nodes and exact endpoints
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
                local t = (n_nodes == 1) and 0 or (node_i - 1) / (n_nodes - 1)
                local x, y = ax + t * dx * distance, ay + t * dy * distance
                table.insert(rope.current_positions, x)
                table.insert(rope.current_positions, y)
                table.insert(rope.last_positions, x)
                table.insert(rope.last_positions, y)
                table.insert(rope.last_velocities, 0)
                table.insert(rope.last_velocities, 0)
                table.insert(rope.masses, 1)
            end

            -- Ensure exact endpoints
            rope.current_positions[1], rope.current_positions[2] = ax, ay
            rope.current_positions[#rope.current_positions - 1], rope.current_positions[#rope.current_positions] = bx, by
            rope.last_positions[1], rope.last_positions[2] = ax, ay
            rope.last_positions[#rope.last_positions - 1], rope.last_positions[#rope.last_positions] = bx, by

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

            n_velocity_iterations = todo.n_velocity_iterations,
            n_distance_iterations = todo.n_distance_iterations,
            n_bending_iterations = todo.n_bending_iterations,
            n_inverse_kinematics_iterations = 0,
            inverse_kinematics_intensity = 0.1,
            inertia = todo.inertia,
            velocity_damping = todo.velocity_damping,
            gravity_x = 0,
            gravity_y = rt.settings.overworld.player_tether.gravity
        })
    end
end

--- @brief
function ow.PlayerTether:draw()
    local r, g, b, a = love.graphics.getColor()

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