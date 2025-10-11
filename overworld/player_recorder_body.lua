require "common.smoothed_motion_1d"
require "common.matrix"

rt.settings.overworld.player_recorder_body = {
    edge_length = 12,
    n_rows = 7,

    n_distance_iterations = 10,
    n_velocity_iterations = 1,
    n_bending_iterations = 1,
    n_axis_iterations = 1,
    axis_intensity = 0.05,
    inertia = 0.0,
    velocity_damping = 0.6,
    gravity = 10,

    n_tentacles = 12,
    radius = 10,
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
    local radius = _settings.edge_length * _settings.n_rows * 2
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
local _mass = 7
local _offset_x = 8
local _offset_y = 9
local _is_anchor = 10
local _anchor_x = 11
local _anchor_y = 12
local _value = 13

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

    local n_rings = 4
    local n_cloths_per_ring = 4
    local n_cloths = 12  -- total number of cloths in the spiral
    for cloth_i = 1, n_cloths do
        local ring_t = 1 --cloth_i / n_cloths
        local ring_angle = ring_t * 2 * math.pi
        local ring_r = _settings.radius

        local px = x + math.cos(ring_angle) * ring_r
        local py = y + math.sin(ring_angle) * ring_r

        local edge_length = _settings.edge_length * math.mix(0.5, 1, ring_t)
        if edge_length < 2 then goto continue end

        local cloth = {}
        table.insert(self._cloths, 1, cloth)

        local angle = (cloth_i - 1) / n_cloths * 2 * math.pi
        local axis_x = math.cos(angle)
        local axis_y = math.sin(angle)

        local n_rows = _settings.n_rows
        local n_columns = 5

        cloth.nodes = {}       -- Table<Node>, n
        cloth.pairs = {}       -- Table<Node>, 2 * n
        cloth.edge_lengths = {}-- Table<Number>, pair_i to length
        cloth.axes = {}        -- Table<Number>, pair_i to axis x, axis y
        cloth.triplets = {}    -- Table<Node>, 3 * n

        cloth.mesh_data = {}
        cloth.mesh = nil

        local matrix = rt.Matrix()

        local x_offset = -0.5 * (n_columns * edge_length)
        local y_offset = 0

        local new_node = function(node_x, node_y, offset_x, offset_y)
            return {
                [_current_position_x] = node_x,
                [_current_position_y] = node_y,
                [_last_position_x] = node_x,
                [_last_position_y] = node_y,
                [_last_velocity_x] = 0,
                [_last_velocity_y] = 0,
                [_mass] = 1, -- set after
                [_offset_x] = offset_x,
                [_offset_y] = offset_y,
                [_is_anchor] = false,
                [_anchor_x] = 0,
                [_anchor_y] = 0,
                [_value] = 0 -- set by solver
            }
        end

        -- grid
        for row_i = 1, n_rows do
            for col_i = 1, n_columns do
                local offset_x = (col_i - 1) * edge_length
                local offset_y = (row_i - 1) * edge_length
                local node_x = px + x_offset + offset_x
                local node_y = py + y_offset + offset_y

                local node = new_node(node_x, node_y, offset_x, offset_y)
                matrix:set(row_i, col_i, node)
                table.insert(cloth.nodes, node)
            end
        end

        if false then -- tapering end
            local n = n_columns - 2
            local row_i = n_rows + 1
            local repeat_n = 0
            while n > 0 do
                for i = 1, n do
                    local col_i = (n_columns - n) / 2 + i
                    local offset_x = (col_i - 1) * edge_length
                    local offset_y = (row_i - 1) * edge_length
                    local node_x = px + x_offset + offset_x
                    local node_y = py + y_offset + offset_y

                    local node = new_node(node_x, node_y, offset_x, offset_y)
                    matrix:set(row_i, col_i, node)
                    table.insert(cloth.nodes, node)
                end
                row_i = row_i + 1
                n = n - 2
            end
        end

        local min_row, min_col, max_row, max_col = matrix:get_index_range()

        -- mass inverse proportional to distance to anchor
        for row_i = min_row, max_row do
            local mass = row_i / (n_rows + 1)
            for col_i = min_col, max_col do
                local node = matrix:get(row_i, col_i)
                if node ~= nil then
                    node[_mass] = mass
                end
            end
        end

        local hdistance_easing = function(t)
            return math.sqrt(1 - t^15)
        end

        -- pairs for distance constraint
        for row_i = min_row, max_row do
            for col_i = min_col, max_col do
                local node = matrix:get(row_i, col_i)
                if node then
                    local right = matrix:get(row_i, col_i + 1)
                    if right ~= nil then
                        table.insert(cloth.pairs, node)
                        table.insert(cloth.pairs, right)
                        table.insert(cloth.edge_lengths, math.max(hdistance_easing(row_i / n_rows) * edge_length, 0.05))

                        local haxis_x, haxis_y = math.turn_left(axis_x, axis_y)
                        table.insert(cloth.axes, haxis_x)
                        table.insert(cloth.axes, haxis_y)
                    end

                    local bottom = matrix:get(row_i + 1, col_i)
                    if bottom ~= nil then
                        table.insert(cloth.pairs, node)
                        table.insert(cloth.pairs, bottom)
                        table.insert(cloth.edge_lengths, edge_length)
                        table.insert(cloth.axes, axis_x)
                        table.insert(cloth.axes, axis_y)
                    end
                end
            end
        end

        -- triplets for bending constraint
        for row_i = min_row, max_row do
            for col_i = min_col, max_col do
                local col_a = matrix:get(row_i, col_i)
                local col_b = matrix:get(row_i, col_i + 1)
                local col_c = matrix:get(row_i, col_i + 2)
                if col_a and col_b and col_c then
                    table.insert(cloth.triplets, col_a)
                    table.insert(cloth.triplets, col_b)
                    table.insert(cloth.triplets, col_c)
                end

                local row_a = matrix:get(row_i, col_i)
                local row_b = matrix:get(row_i + 1, col_i)
                local row_c = matrix:get(row_i + 2, col_i)
                if row_a and row_b and row_c then
                    table.insert(cloth.triplets, row_a)
                    table.insert(cloth.triplets, row_b)
                    table.insert(cloth.triplets, row_c)
                end
            end
        end

        do -- anchors
            for col_i = min_col, max_col do
                local node = matrix:get(min_row, col_i)
                if node then
                    local anchor_angle = (col_i - 1) / n_columns * 2 * math.pi
                    node[_is_anchor] = true
                    node[_anchor_x] = 0 --math.cos(ring_t * 2 * math.pi) * ring_r
                    node[_anchor_y] = 0 --math.sin(ring_t * 2 * math.pi) * ring_r
                end
            end
        end

        -- mesh
        local mesh_data = {}
        local triangulation = {}

        local add_vertex = function(x, y)
            table.insert(mesh_data, {
                x, y,
                1, 1,
                1, 1, 1, 1
            })
        end

        local node_to_vertex_index = {}
        for i, node in ipairs(cloth.nodes) do
            add_vertex(node[_current_position_x], node[_current_position_y])
            node_to_vertex_index[node] = i
        end

        -- triangulation
        for row_i = min_row, max_row - 1 do
            for col_i = min_col, max_col - 1 do
                local top_left = matrix:get(row_i, col_i)
                local top_right = matrix:get(row_i, col_i + 1)
                local bottom_left = matrix:get(row_i + 1, col_i)
                local bottom_right = matrix:get(row_i + 1, col_i + 1)

                -- create two triangles for each quad if all four corners exist
                if top_left and top_right and bottom_left and bottom_right then
                    table.insert(triangulation, node_to_vertex_index[top_left])
                    table.insert(triangulation, node_to_vertex_index[bottom_left])
                    table.insert(triangulation, node_to_vertex_index[top_right])

                    table.insert(triangulation, node_to_vertex_index[top_right])
                    table.insert(triangulation, node_to_vertex_index[bottom_left])
                    table.insert(triangulation, node_to_vertex_index[bottom_right])
                elseif top_left and top_right and bottom_left then
                    table.insert(triangulation, node_to_vertex_index[top_left])
                    table.insert(triangulation, node_to_vertex_index[bottom_left])
                    table.insert(triangulation, node_to_vertex_index[top_right])

                elseif top_left and top_right and bottom_right then
                    table.insert(triangulation, node_to_vertex_index[top_left])
                    table.insert(triangulation, node_to_vertex_index[top_right])
                    table.insert(triangulation, node_to_vertex_index[bottom_right])

                elseif top_left and bottom_left and bottom_right then
                    table.insert(triangulation, node_to_vertex_index[top_left])
                    table.insert(triangulation, node_to_vertex_index[bottom_left])
                    table.insert(triangulation, node_to_vertex_index[bottom_right])

                elseif top_right and bottom_left and bottom_right then
                    table.insert(triangulation, node_to_vertex_index[top_right])
                    table.insert(triangulation, node_to_vertex_index[bottom_left])
                    table.insert(triangulation, node_to_vertex_index[bottom_right])
                end
            end
        end

        cloth.mesh = rt.Mesh(
            mesh_data,
            rt.MeshDrawMode.TRIANGLES,
            rt.VertexFormat,
            rt.GraphicsBufferUsage.STREAM
        )
        cloth.mesh:set_vertex_map(triangulation)
        cloth.mesh_data = mesh_data

        ::continue::
    end -- ring_i
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

                local axis_x = data.axes[pair_i + 0]
                local axis_y = data.axes[pair_i + 1]

                if axis_x ~= 0 or axis_y ~= 0 then
                    local new_x1, new_y1, new_x2, new_y2 = ow.PlayerRecorderBody._solve_axis_constraint(
                        node_1[_current_position_x], node_1[_current_position_y],
                        node_2[_current_position_x], node_2[_current_position_y],
                        axis_x, axis_y, data.axis_intensity
                    )

                    if node_1[_is_anchor] ~= true then
                        node_1[_current_position_x], node_1[_current_position_y] = new_x1, new_y1
                    end

                    if node_2[_is_anchor] ~= true then
                        node_2[_current_position_x], node_2[_current_position_y] = new_x2, new_y2
                    end
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
            axes = cloth.axes,
            n_distance_iterations = _settings.n_distance_iterations,
            n_velocity_iterations = _settings.n_velocity_iterations,
            n_bending_iterations = _settings.n_bending_iterations,
            n_axis_iterations = _settings.n_axis_iterations,
            axis_intensity = _settings.axis_intensity,
            velocity_damping = _settings.velocity_damping,
            inertia = _settings.inertia,
            gravity_x = 0,
            gravity_y = _settings.gravity,
            delta = delta,
            position_x = px,
            position_y = py,
        })
    end

    -- update mesh
    for cloth in values(self._cloths) do
        for node_i, node in ipairs(cloth.nodes) do
            local data = cloth.mesh_data[node_i]
            data[1] = node[_current_position_x]
            data[2] = node[_current_position_y]

            local value = 1 - node[_value]
            data[5] = value
            data[6] = value
            data[7] = value
        end

        cloth.mesh:replace_data(cloth.mesh_data)
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
    local w, h = self._canvas:get_size()
    local position_x, position_y = self:get_position()

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

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", position_x, position_y, 1.5 * _settings.radius)
        for cloth in values(self._cloths) do cloth.mesh:draw() end

        self._canvas:unbind()
        love.graphics.pop()
        self._canvas_needs_update = false
    end

    love.graphics.setLineWidth(2)
    love.graphics.setColor(1, 1, 1, 1)
    local r = 2 * self._radius
    local x, y = self._body:get_position()

    self._body:draw()

    --[[
    rt.Palette.BLACK:bind()
    love.graphics.draw(self._canvas:get_native(),
        position_x, position_y,
        0,
        1 / self._canvas_scale, 1 / self._canvas_scale,
        0.5 * w, 0.5 * h
    )
    ]]--

    for i, cloth in ipairs(self._cloths) do
        love.graphics.setColor(rt.lcha_to_rgba(0.8, 1, (i - 1) / (#self._cloths), 1))
        cloth.mesh:draw()
    end


    _outline_shader:bind()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._canvas:get_native(),
        position_x, position_y,
        0,
        1 / self._canvas_scale, 1 / self._canvas_scale,
        0.5 * w, 0.5 * h
    )
    _outline_shader:unbind()
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
