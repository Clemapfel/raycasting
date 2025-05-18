--- @class rt.PlayerBody
rt.PlayerBody = meta.class("PlayerBody")

--- @brief
function rt.PlayerBody:instantiate(player)
    meta.assert(player, rt.Player)

    self._player = player
    self._elapsed = 0
    self._hull_tris = {}
    self._hull_color = rt.Palette.BLACK:clone()
    self._hull_color.a = 0.2

    self._center_tris = {}
    self._outline = {}

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "c" then
            self._shader:recompile()
            dbg("recompile")
        end
    end)
end

--- @brief
function rt.PlayerBody:initialize(x, y)
    local _settings = rt.settings.player
    local radius = rt.settings.player.radius
    local max_rope_length = radius * 10

    self._n_segments = radius
    self._n_ropes = 256

    self._ropes = {}

    local _golden_ratio = (1 + math.sqrt(5)) / 2

    for rope_i = 1, self._n_ropes do
        local idx = rope_i - 0.5
        local z = 1 - 2 * idx / self._n_ropes
        local theta = 2 * math.pi * idx / _golden_ratio

        local r = math.sqrt(1 - z * z)
        local offset_x = r * math.cos(theta)
        local offset_y = r * math.sin(theta)

        local centered = (1 - math.gaussian(math.magnitude(offset_x, offset_y), 1))
        offset_x = offset_x * centered
        offset_y = offset_y * centered

        local dx = offset_x
        local dy = offset_y
        local rope = {
            current_positions = {},
            last_positions = {},
            distances = {},
            anchor_offset_x = offset_x * radius,
            anchor_offset_y = offset_y * radius
        }
        rope.axis_x, rope.axis_y = math.normalize(-dx, -dy)

        local rope_length = (1 - math.magnitude(offset_x, offset_y)) * radius * 5

        local last_x, last_y = x, y
        for i = 1, self._n_segments do
            local delta = (i - 1) / self._n_segments * radius
            local px = x + dx * delta * radius
            local py = y + dy * delta * radius
            table.insert(rope.current_positions, px)
            table.insert(rope.current_positions, py)
            table.insert(rope.last_positions, px)
            table.insert(rope.last_positions, py)
            table.insert(rope.distances, rope_length / self._n_segments)
            last_x = px
            last_y = py
        end

        table.insert(self._ropes, rope)
    end
end

local _step = 1 / 120
local _gravity = 100
local _axis_stiffness = 0.5
local _bending_stiffness = 1
local _velocity_damping = 0.9
local _n_velocity_iterations = 3
local _n_distance_iterations = 8
local _n_axis_iterations = 1
local _n_bending_iterations = 1

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
function rt.PlayerBody:update(delta)
    self._elapsed = self._elapsed + delta

    local axis_x, axis_y = self._player:get_velocity()
    axis_x = -1 * axis_x
    axis_y = -1 * axis_y
    local is_stationary = false --math.magnitude(axis_x, axis_y) < 100
    axis_x, axis_y = math.normalize(axis_x, axis_y)

    while self._elapsed > _step do
        self._elapsed = self._elapsed - _step

        local delta_squared = _step * _step
        local player_x, player_y = self._player:get_physics_body():get_predicted_position()

        local mass = 1
        for rope in values(self._ropes) do
            local positions = rope.current_positions
            local old_positions = rope.last_positions
            local distances = rope.distances
            local gravity_x, gravity_y = 0 * _gravity, 1 * _gravity

            local n_axis_iterations = 0
            local n_distance_iterations = 0
            local n_velocity_iterations = 0
            local n_bending_iterations = 0

            local rope_axis_x = axis_x
            local rope_axis_y = axis_y

            if is_stationary then
                rope_axis_x = rope.axis_x
                rope_axis_y = rope.axis_y
            end

            while n_axis_iterations < _n_axis_iterations or n_distance_iterations <_n_distance_iterations or n_velocity_iterations < _n_velocity_iterations do

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
                if n_axis_iterations < _n_axis_iterations and not is_stationary then
                    for i = 1, #positions - 2, 2 do
                        local node_1_xi, node_1_yi, node_2_xi, node_2_yi = i, i+1, i+2, i+3
                        local node_1_x, node_1_y = positions[node_1_xi], positions[node_1_yi]
                        local node_2_x, node_2_y = positions[node_2_xi], positions[node_2_yi]

                        local new_x1, new_y1, new_x2, new_y2 = _solve_axis_constraint(
                            node_1_x, node_1_y, node_2_x, node_2_y, rope_axis_x, rope_axis_y,
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
                            node_1_x = player_x + rope.anchor_offset_x
                            node_1_y = player_y + rope.anchor_offset_y
                        end

                        local rest_length = distances[distance_i]
                        if is_stationary then rest_length = 0 end

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
end

--- @brief
function rt.PlayerBody:draw(is_bubble)
    love.graphics.setColor(1, 1, 1, 1)

    local hue = 0
    local rope_i = 0
    love.graphics.setLineWidth(2)
    for rope in values(self._ropes) do
        love.graphics.setColor(hue, hue, hue, 1)
        for i = 1, self._n_segments, 2 do
            local node_1_x, node_1_y = rope.current_positions[i + 0], rope.current_positions[i + 1]
            local node_2_x, node_2_y = rope.current_positions[i + 2], rope.current_positions[i + 3]

            love.graphics.line(node_1_x, node_1_y, node_2_x, node_2_y)
        end

        hue = rope_i / self._n_ropes
        rope_i = rope_i + 1
    end
end