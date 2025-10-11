require "common.smoothed_motion_1d"
require "common.matrix"

rt.settings.overworld.player_recorder_body = {
    edge_length = 5,
    n_nodes = 200,
    n_distance_iterations = 10,
    n_velocity_iterations = 3,
    n_bending_iterations = 3,
    n_axis_iterations = 0,
    axis_intensity = 0.2,
    inertia = 0.3,
    velocity_damping = 0.8,
    gravity = 4,
}

--- @class ow.PlayerRecorderBody
ow.PlayerRecorderBody = meta.class("PlayerRecorderBody")

local _NOT_PRESSED = 0
local _PRESSED = 1

local _settings = rt.settings.overworld.player_recorder_body

local _outline_shader = rt.Shader("common/player_body_outline.glsl", { MODE = 1 })

--- @brief
function ow.PlayerRecorderBody:instantiate(stage, scene)
    meta.assert(
        stage, ow.Stage,
        scene, ow.OverworldScene
    )

    self._stage = stage
    self._scene = scene

    self._radius = rt.settings.player.radius
    self._body = nil
    self._ropes = {}
    self._n_ropes = 0
    self._is_bubble = false

    -- canvases
    self._canvas_scale = rt.settings.player_body.canvas_scale
    self._canvas_needs_update = true

    local padding = rt.settings.player_body.canvas_padding
    local radius = _settings.edge_length + self._radius
    self._canvas = rt.RenderTexture(
        self._canvas_scale * (radius + 2 * padding),
        self._canvas_scale * (radius + 2 * padding),
    4) -- msaa

    -- TODO
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then self:relax() end
    end)
end

local _current_position_x = 1
local _current_position_y = 2
local _last_position_x = 3
local _last_position_y = 4
local _last_velocity_x = 5
local _last_velocity_y = 6
local _id = 7
local _mass = 8
local _offset_x = 9
local _offset_y = 10
local _is_anchor = 11
local _anchor_x = 12
local _anchor_y = 13

--- @brief
function ow.PlayerRecorderBody:initialize(x, y)
    if self._body ~= nil then -- already initialized
        self:set_position(x, y)
        return
    end

    -- physics shape
    self._body = b2.Body(
        self._stage:get_physics_world(),
        b2.BodyType.DYNAMIC,
        x, y,
        b2.Circle(0, 0, self._radius)
    )

    local player_settings = rt.settings.player
    self._body:set_collides_with(bit.bnot(bit.bor(
        player_settings.player_collision_group,
        player_settings.player_outer_body_collision_group,
        player_settings.bounce_collision_group,
        player_settings.ghost_collision_group
    )))
    self._body:set_collision_group(player_settings.exempt_collision_group)
    self._body:signal_connect("collision_start", function(_, other_body, normal_x, normal_y, x1, y1, x2, y2)
        if x1 ~= nil then
            self._stage:get_blood_splatter():add(x1, y1, self._radius, 0, 0)
        end
    end)

    -- simulation
    
    self._cloths = {}

    local n_cloths = 1
    for cloth_i = 1, n_cloths do
        local cloth = {}
        table.insert(self._cloths, cloth)
        
        local n_rows = 30
        local n_columns = 4 * 8
        local edge_length = _settings.edge_length

        cloth.nodes = {} -- Table<Node>, n
        cloth.pairs = {} -- Table<Node>, 2 * n
        cloth.edge_lengths = {} -- Table<Number>, pair_i to length
        cloth.triplets = {} -- Table<Node>, 3 * n

        cloth.axis_x = math.random(-0.25, 0.25)
        cloth.axis_y = 1

        local dy = 1
        local dx = -(1 / (n_cloths / 2)) + (cloth_i - 1) * (1 / n_cloths)
        local matrix = rt.Matrix()

        local x_offset = -0.5 * (n_columns * edge_length)
        local y_offset = 0

        local px, py = x, y

        local node_i = 1
        for row_i = 1, n_rows do
            for col_i = 1, n_columns do
                local offset_x = (row_i - 1) * edge_length + dx * x_offset
                local offset_y = (col_i - 1) * edge_length + dy * y_offset
                local node_x = px + offset_x + x_offset
                local node_y = py + offset_y + y_offset
                local node = {
                    [_current_position_x] = node_x,
                    [_current_position_y] = node_y,
                    [_last_position_x] = node_x,
                    [_last_position_y] = node_y,
                    [_last_velocity_x] = 0,
                    [_last_velocity_y] = 0,
                    [_id] = node_i,
                    [_mass] = 1, -- set after
                    [_offset_x] = offset_x,
                    [_offset_y] = offset_y,
                    [_is_anchor] = false,
                    [_anchor_x] = 0,
                    [_anchor_y] = 0
                }

                matrix:set(row_i, col_i, node)
                cloth.nodes[node_i] = node
                node_i = node_i + 1
            end
        end

        -- mass is inversely proportionate to anchors
        for row_i = 1, n_rows do
            local mass = row_i / (n_rows + 1)
            for col_i = 1, n_columns do
                if col_i % 2 == 0 then mass = mass * -1 end
                matrix:get(row_i, col_i)[_mass] = mass
            end
        end

        local reject = function(col_i)
            return col_i % 4 == 0
        end

        -- all neighbor pairs, for distance constraint solver
        for row_i = 1, n_rows do
            for col_i = 1, n_columns do
                if col_i < n_columns then
                    table.insert(cloth.pairs, matrix:get(row_i, col_i + 0))
                    table.insert(cloth.pairs, matrix:get(row_i, col_i + 1))
                    table.insert(cloth.edge_lengths, edge_length)
                end

                if row_i < n_rows then
                    table.insert(cloth.pairs, matrix:get(row_i + 0, col_i))
                    table.insert(cloth.pairs, matrix:get(row_i + 1, col_i))
                    table.insert(cloth.edge_lengths, edge_length)
                end
            end
        end

        -- all neighbor triplets, for bending constraint solver
        for row_i = 1, n_rows do
            for col_i = 1, n_columns do
                if col_i < n_columns - 1 then
                    table.insert(cloth.triplets, matrix:get(row_i, col_i + 0))
                    table.insert(cloth.triplets, matrix:get(row_i, col_i + 1))
                    table.insert(cloth.triplets, matrix:get(row_i, col_i + 2))
                end

                if row_i < n_rows - 1 then
                    table.insert(cloth.triplets, matrix:get(row_i + 0, col_i))
                    table.insert(cloth.triplets, matrix:get(row_i + 1, col_i))
                    table.insert(cloth.triplets, matrix:get(row_i + 2, col_i))
                end
            end
        end

        -- anchors
        do
            local anchor_distance = 0.25 * edge_length
            local cx, cy = 0, 0
            for col_i = 1, n_columns do
                local node = matrix:get(1, col_i)
                node[_is_anchor] = true
                node[_anchor_x] = (-0.5 * n_columns * anchor_distance) + ((col_i - 1) / n_columns) * (n_columns * anchor_distance)
                node[_anchor_y] = 0
            end
        end
    end
end

ow.PlayerRecorderBody._solve_distance_constraint = function(a_x, a_y, b_x, b_y, rest_length)
    local current_distance = math.max(1, math.distance(a_x, a_y, b_x, b_y))

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

ow.PlayerRecorderBody._solve_bending_constraint = function(
    a_x, a_y,
    b_x, b_y,
    c_x, c_y,
    stiffness,
    w_a, w_b, w_c -- inverse masses, 0 for anchored
)
    local qx = 0.5 * (a_x + c_x) - b_x
    local qy = 0.5 * (a_y + c_y) - b_y

    local denom = 0.25 * w_a + 1.0 * w_b + 0.25 * w_c
    if denom <= 0 then
        return a_x, a_y, b_x, b_y, c_x, c_y
    end

    local s = stiffness / denom

    local da_x = -0.5 * w_a * s * qx
    local da_y = -0.5 * w_a * s * qy

    local db_x =  1.0 * w_b * s * qx
    local db_y =  1.0 * w_b * s * qy

    local dc_x = -0.5 * w_c * s * qx
    local dc_y = -0.5 * w_c * s * qy

    return a_x + da_x, a_y + da_y,
        b_x + db_x, b_y + db_y,
        c_x + dc_x, c_y + dc_y
end

ow.PlayerRecorderBody._solve_axis_constraint = function(a_x, a_y, b_x, b_y, axis_x, axis_y, intensity)
    if intensity == nil then intensity = 1 end

    local delta_x = b_x - a_x
    local delta_y = b_y - a_y

    local dot_product = math.abs(delta_x * axis_x + delta_y * axis_y)
    local projection_x = dot_product * axis_x
    local projection_y = dot_product * axis_y

    local correction_x = (projection_x - delta_x)
    local correction_y = (projection_y - delta_y)

    local blend = math.mix(0, 0.5, intensity)
    a_x = a_x - correction_x * blend
    a_y = a_y - correction_y * blend
    b_x = b_x + correction_x * blend
    b_y = b_y + correction_y * blend

    return a_x, a_y, b_x, b_y
end

ow.PlayerRecorderBody._cloth_handler = function(data)
    if data.gravity_x == nil then data.gravity_x = 0 end
    if data.gravity_y == nil then data.gravity_y = 1 end
    if data.velocity_damping == nil then data.velocity_damping = 1 end

    local n_distance_iterations_done = 0
    local n_velocity_iterations_done = 0
    local n_bending_iterations_done = 0
    local n_axis_iterations_done = 0

    while (n_velocity_iterations_done < data.n_velocity_iterations)
        or (n_distance_iterations_done < data.n_distance_iterations)
        or (n_bending_iterations_done < data.n_bending_iterations)
    do
        -- verlet integration
        if n_velocity_iterations_done < data.n_velocity_iterations then
            for i = 1, #data.nodes do
                local node = data.nodes[i]
                local current_x, current_y = node[_current_position_x], node[_current_position_y]
                local old_x, old_y = node[_last_position_x], node[_last_position_y]
                local mass = node[_mass]

                if node[_is_anchor] == true then
                    current_x = data.position_x + node[_anchor_x]
                    current_y = data.position_y + node[_anchor_y]
                end

                local before_x, before_y = current_x, current_y

                local velocity_x = (current_x - old_x) * data.velocity_damping
                local velocity_y = (current_y - old_y) * data.velocity_damping

                velocity_x = math.mix(velocity_x, node[_last_velocity_x], data.inertia)
                velocity_y = math.mix(velocity_y, node[_last_velocity_y], data.inertia)

                node[_current_position_x]  = current_x + velocity_x + mass * data.gravity_x * data.delta
                node[_current_position_y]  = current_y + velocity_y + mass * data.gravity_y * data.delta

                node[_last_position_x]  = before_x
                node[_last_position_y]  = before_y
                node[_last_velocity_x]  = velocity_x
                node[_last_velocity_y]  = velocity_y
            end

            n_velocity_iterations_done = n_velocity_iterations_done + 1
        end

        -- distance
        if n_distance_iterations_done < data.n_distance_iterations then
            local length_i = 1
            for pair_i = 1, #data.pairs, 2 do
                local node_1 = data.pairs[pair_i + 0]
                local node_2 = data.pairs[pair_i + 1]

                local new_x1, new_y1, new_x2, new_y2 = ow.PlayerRecorderBody._solve_distance_constraint(
                    node_1[_current_position_x], node_1[_current_position_y],
                    node_2[_current_position_x], node_2[_current_position_y],
                    data.edge_lengths[length_i]
                )

                if node_1[_is_anchor] ~= true then
                    node_1[_current_position_x], node_1[_current_position_y] = new_x1, new_y1
                end

                if node_2[_is_anchor] ~= true then
                    node_2[_current_position_x], node_2[_current_position_y] = new_x2, new_y2
                end

                length_i = length_i + 1
            end

            n_distance_iterations_done = n_distance_iterations_done + 1
        end

        -- axis
        if n_axis_iterations_done < data.n_axis_iterations then
            for pair_i = 1, #data.pairs, 2 do
                local node_1 = data.pairs[pair_i + 0]
                local node_2 = data.pairs[pair_i + 1]

                local new_x1, new_y1, new_x2, new_y2 = ow.PlayerRecorderBody._solve_axis_constraint(
                    node_1[_current_position_x], node_1[_current_position_y],
                    node_2[_current_position_x], node_2[_current_position_y],
                    data.axis_x, data.axis_y, data.axis_intensity
                )

                if node_1[_is_anchor] ~= true then
                    node_1[_current_position_x], node_1[_current_position_y] = new_x1, new_y1
                end

                if node_2[_is_anchor] ~= true then
                    node_2[_current_position_x], node_2[_current_position_y] = new_x2, new_y2
                end
            end

            n_axis_iterations_done = n_axis_iterations_done + 1
        end

        -- bending constraints
        if n_bending_iterations_done < data.n_bending_iterations then
            local stiffness = data.bending_stiffness
            for triplet_i = 1, #data.triplets, 3 do
                local node_a = data.triplets[triplet_i + 0]
                local node_b = data.triplets[triplet_i + 1]
                local node_c = data.triplets[triplet_i + 2]

                local a_x, a_y = node_a[_current_position_x], node_a[_current_position_y]
                local b_x, b_y = node_b[_current_position_x], node_b[_current_position_y]
                local c_x, c_y = node_c[_current_position_x], node_c[_current_position_y]
                
                local mass_a, mass_b, mass_c = math.abs(node_a[_mass]), math.abs(node_b[_mass]), math.abs(node_c[_mass])

                -- inverse masses, anchored nodes behave as 1 / mass = 0
                local w_a, w_b, w_c = 1 / mass_a, 1 / mass_b, 1 / mass_c

                if node_a[_is_anchor] == true or mass_a == 0 then w_a = 0 end
                if node_b[_is_anchor] == true or mass_b == 0 then w_b = 0 end
                if node_c[_is_anchor] == true or mass_c == 0 then w_c = 0 end
                
                local nx1, ny1, nx2, ny2, nx3, ny3 = ow.PlayerRecorderBody._solve_bending_constraint(
                    a_x, a_y,
                    b_x, b_y,
                    c_x, c_y,
                    stiffness or math.min(1, (mass_a + mass_b + mass_c) / 3),
                    w_a, w_b, w_c
                )

                node_a[_current_position_x], node_a[_current_position_y] = nx1, ny1
                node_b[_current_position_x], node_b[_current_position_y] = nx2, ny2
                node_c[_current_position_x], node_c[_current_position_y] = nx3, ny3
            end

            n_bending_iterations_done = n_bending_iterations_done + 1
        end
    end
end

--- @brief
function ow.PlayerRecorderBody:update(delta)
    local px, py = love.mouse.getPosition()
    px, py = self._scene:get_camera():screen_xy_to_world_xy(px, py)

    for cloth in values(self._cloths) do
        ow.PlayerRecorderBody._cloth_handler({
            nodes = cloth.nodes,
            pairs = cloth.pairs,
            triplets = cloth.triplets,
            edge_lengths = cloth.edge_lengths,
            n_distance_iterations = _settings.n_distance_iterations,
            n_velocity_iterations = _settings.n_velocity_iterations,
            n_bending_iterations = _settings.n_bending_iterations,
            n_axis_iterations = _settings.n_axis_iterations,
            axis_intensity = _settings.axis_intensity,
            axis_x = cloth.axis_x,
            axis_y = cloth.axis_y,
            velocity_damping = _settings.velocity_damping,
            inertia = _settings.inertia,
            gravity_x = 0,
            gravity_y = _settings.gravity,
            delta = delta,
            position_x = px,
            position_y = py,
        })
    end

    self._canvas_needs_update = true
end

--- @brief
function ow.PlayerRecorderBody:relax()
    for motion in range(
        self._up_pressed_motion,
        self._right_pressed_motion,
        self._down_pressed_motion,
        self._left_pressed_motion
    ) do
        motion:set_value(_NOT_PRESSED)
        motion:set_target_value(_NOT_PRESSED)
    end

    for i, node in ipairs(self._nodes) do
        local x, y = self:get_position()
        x = x + node[_offset_x]
        y = y + node[_offset_y]
        node[_current_position_x] = x
        node[_current_position_y] = y
        node[_last_position_x] = x
        node[_last_position_y] = y
        node[_last_velocity_x] = 0
        node[_last_velocity_y] = 0
    end
end

--- @brief
function ow.PlayerRecorderBody:set_position(x, y)
    self._body:set_position(x, y)
end

--- @brief
function ow.PlayerRecorderBody:get_position()
    local px, py = love.mouse.getPosition()
    px, py = self._scene:get_camera():screen_xy_to_world_xy(px, py)
    return px, py
    --return self._body:get_position()
end

--- @brief
function ow.PlayerRecorderBody:set_velocity(dx, dy)
    self._body:set_velocity(dx, dy)
end

--- @brief
function ow.PlayerRecorderBody:draw()
    --[[
    local w, h = self._canvas:get_size()
    local position_x, position_y = self._body:get_position()

    if self._canvas_needs_update then
        love.graphics.push("all")
        love.graphics.reset()

        self._canvas:bind()
        love.graphics.clear(0, 0, 0, 0)

        love.graphics.translate(0.5 * w, 0.5 * h)
        love.graphics.scale(self._canvas_scale, self._canvas_scale)
        love.graphics.translate(-0.5 * w, -0.5 * h)

        love.graphics.translate(-position_x, -position_y)
        love.graphics.translate(0.5 * w, 0.5 * h)

        love.graphics.setColor(0, 0, 0,1)
        love.graphics.circle("fill", position_x, position_y, 10)

        love.graphics.setLineWidth(_settings.rope_thickness)
        love.graphics.setLineJoin("none")

        for rope in values(self._ropes) do
            local rope_i = 0
            for i = 1, #rope.current_positions, 2 do
                local v = rope_i / self._n_ropes * 0.2
                love.graphics.setColor(v, v, v, 1)

                if i < #rope.current_positions - 2 then
                    local x1, y1, x2, y2 = rope.current_positions[i+0], rope.current_positions[i+1], rope.current_positions[i+2], rope.current_positions[i+3]
                    love.graphics.line(x1, y1, x2, y2)
                end

                love.graphics.circle("fill",
                    rope.current_positions[i+0],
                    rope.current_positions[i+1],
                    _settings.rope_thickness
                )

                rope_i = rope_i + 1
            end
        end

        self._body:draw()

        self._canvas:unbind()
        love.graphics.pop()
        self._canvas_needs_update = false
    end

    love.graphics.setLineWidth(2)
    love.graphics.setColor(1, 1, 1, 1)
    local r = 2 * self._radius
    local x, y = self._body:get_position()

    self._body:draw()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._canvas:get_native(),
        position_x, position_y,
        0,
        1 / self._canvas_scale, 1 / self._canvas_scale,
        0.5 * w, 0.5 * h
    )

    _outline_shader:bind()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._canvas:get_native(),
        position_x, position_y,
        0,
        1 / self._canvas_scale, 1 / self._canvas_scale,
        0.5 * w, 0.5 * h
    )
    _outline_shader:unbind()
    ]]--

    local px, py = self:get_position()

    for cloth in values(self._cloths) do
        for i = 1, #cloth.pairs, 2 do
            local node_1 = cloth.pairs[i+0]
            local node_2 = cloth.pairs[i+1]
            love.graphics.setColor(rt.lcha_to_rgba(0.8, 1, (i - 1) / (#cloth.pairs / 2), 1))
            love.graphics.line(
                node_1[_current_position_x],
                node_1[_current_position_y],
                node_2[_current_position_x],
                node_2[_current_position_y]
            )
        end
    end
end


--- @brief
function ow.PlayerRecorderBody:update_input(
    up_pressed,
    right_pressed,
    down_pressed,
    left_pressed,
    sprint_pressed,
    jump_pressed,
    is_bubble
)
    self._is_bubble = is_bubble
end
