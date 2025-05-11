--- @class ow.PlayerBody
ow.PlayerBody = meta.class("PlayerBody")

--- @brief
function ow.PlayerBody:instantiate(player)
    meta.assert(player, ow.Player)

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
function ow.PlayerBody:initialize(x, y)
    local _settings = rt.settings.overworld.player
    local radius = rt.settings.overworld.player.radius * 10
    self._n_segments = 16
    self._n_ropes = 32
    self._gravity_x = 0
    self._gravity_y = 0

    self._ropes = {}
    for angle = 0, 2 * math.pi, (2 * math.pi) / self._n_ropes do
        local dx, dy = math.cos(angle), math.sin(angle)
        local offset_x, offset_y = dx, dy
        local rope = {
            current_positions = {},
            last_positions = {},
            distances = {},
            axis_x = dx,
            axis_y = dy,
            anchor_offset_x = offset_x * 10,
            anchor_offset_y = offset_y * 10
        }

        local last_x, last_y = x, y
        for i = 1, self._n_segments do
            local delta = (i - 1) / self._n_segments * radius
            local px = x + offset_x + dx * delta
            local py = y + offset_y + dy * delta
            table.insert(rope.current_positions, px)
            table.insert(rope.current_positions, py)
            table.insert(rope.last_positions, px)
            table.insert(rope.last_positions, py)
            table.insert(rope.distances, 1) --radius / self._n_segments)
            last_x = px
            last_y = py
        end

        table.insert(self._ropes, rope)
    end
end

local _step = 1 / 120
local _axis_stiffness = 1
local _bending_stiffness = 1
local _n_velocity_iterations = 0
local _n_distance_iterations = 5
local _n_axis_iterations = 5
local _n_bending_iterations = 5

local function _solve_distance_constraint(a_x, a_y, b_x, b_y, rest_length)
    local current_distance = math.distance(a_x, a_y, b_x, b_y)
    if current_distance < rest_length then return a_x, a_y, b_x, b_y end

    local delta_x = b_x - a_x
    local delta_y = b_y - a_y
    local distance_correction = (current_distance - rest_length) / current_distance
    local correction_x = delta_x * 0.5 * distance_correction
    local correction_y = delta_y * 0.5 * distance_correction

    a_x = a_x + correction_x
    a_y = a_y + correction_y
    b_x = b_x - correction_x
    b_y = b_y - correction_y

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

    -- Calculate the lengths of the segments
    local ab_length = math.sqrt(ab_x * ab_x + ab_y * ab_y)
    local bc_length = math.sqrt(bc_x * bc_x + bc_y * bc_y)

    -- Normalize the vectors
    ab_x, ab_y = ab_x / ab_length, ab_y / ab_length
    bc_x, bc_y = bc_x / bc_length, bc_y / bc_length

    -- Calculate the target direction to smooth the bend
    local target_x = ab_x + bc_x
    local target_y = ab_y + bc_y
    target_x, target_y = target_x / rest_length, target_y / rest_length

    -- Apply corrections to maintain smoothness
    local correction_x = target_x * stiffness
    local correction_y = target_y * stiffness

    -- Adjust positions
    a_x = a_x - correction_x * 0.5
    a_y = a_y - correction_y * 0.5
    c_x = c_x + correction_x * 0.5
    c_y = c_y + correction_y * 0.5

    return a_x, a_y, c_x, c_y
end

--- @brief
function ow.PlayerBody:update(delta)
    self._elapsed = self._elapsed + delta

    while self._elapsed > _step do
        self._elapsed = self._elapsed - _step

        local delta_squared = _step * _step
        local player_x, player_y = self._player:get_physics_body():get_predicted_position()

        local mass = 1
        for rope in values(self._ropes) do
            local positions = rope.current_positions
            local old_positions = rope.last_positions
            local distances = rope.distances
            local gravity_x, gravity_y = self._gravity_x, self._gravity_y
            local axis_x, axis_y = rope.axis_x, rope.axis_y

            local n_axis_iterations = 0
            local n_distance_iterations = 0
            local n_velocity_iterations = 0
            local n_bending_iterations = 0

            while n_axis_iterations < _n_axis_iterations or n_distance_iterations <_n_distance_iterations or n_velocity_iterations < _n_velocity_iterations do

                -- velocity
                if n_velocity_iterations < _n_velocity_iterations then
                    for i = 1, #positions, 2 do
                        local current_x, current_y = positions[i], positions[i+1]
                        local old_x, old_y = old_positions[i], old_positions[i+1]

                        local before_x, before_y = current_x, current_y

                        positions[i] = current_x + (current_x - old_x) + gravity_x * mass * delta_squared
                        positions[i+1] = current_y + (current_y - old_y) + gravity_y * mass * delta_squared

                        old_positions[i] = before_x
                        old_positions[i+1] = before_y
                    end

                    n_velocity_iterations = n_velocity_iterations + 1
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

                -- axis
                if n_axis_iterations < _n_axis_iterations then
                    for i = 1, #positions - 2, 2 do
                        local node_1_xi, node_1_yi, node_2_xi, node_2_yi = i, i+1, i+2, i+3
                        local node_1_x, node_1_y = positions[node_1_xi], positions[node_1_yi]
                        local node_2_x, node_2_y = positions[node_2_xi], positions[node_2_yi]

                        local new_x1, new_y1, new_x2, new_y2 = _solve_axis_constraint(
                            node_1_x, node_1_y, node_2_x, node_2_y, axis_x, axis_y,
                            i / (#positions) * _bending_stiffness
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
                            distances[distance_i],
                            1 - i / (#positions) * _bending_stiffness
                        )
                        distance_i = distance_i + 1

                        positions[node_1_xi] = new_x1
                        positions[node_1_yi] = new_y1
                        positions[node_3_xi] = new_x3
                        positions[node_3_yi] = new_y3
                    end

                    n_axis_iterations = n_axis_iterations + 1
                end
            end
        end
    end
end

--- @brief
function ow.PlayerBody:draw(is_bubble)
    love.graphics.setColor(1, 1, 1, 1)

    local hue = 0
    local rope_i = 0
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