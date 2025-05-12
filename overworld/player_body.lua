--- @class ow.PlayerBody
ow.PlayerBody = meta.class("PlayerBody")

local _outline_shader, _core_shader, _canvas = nil, nil, nil

--- @brief
function ow.PlayerBody:instantiate(player)
    meta.assert(player, ow.Player)

    self._player = player
    self._ropes = {}
    self._elapsed = 0
    self._shader_elapsed = 0

    local alpha = 0.05
    local padding = 4

    local node_mesh_radius = 10
    local node_mesh = rt.MeshCircle(0, 0, node_mesh_radius)
    node_mesh:set_vertex_color(1, 1, 1, 1, alpha)
    for i = 2, node_mesh:get_n_vertices() do
        node_mesh:set_vertex_color(i, 1, 1, 1, 0.0)
    end
    self._node_mesh = node_mesh

    self._node_mesh_texture = rt.RenderTexture(2 * node_mesh_radius + 2 * padding, 2 * node_mesh_radius + 2 * padding, 8)
    self._node_mesh_texture:bind()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(node_mesh:get_native(), 0.5 * self._node_mesh_texture:get_width(), 0.5 * self._node_mesh_texture:get_height())
    self._node_mesh_texture:unbind()

    local bubble_node_mesh_radius = 1
    local bubble_node_mesh = rt.MeshCircle(0, 0, bubble_node_mesh_radius)
    bubble_node_mesh:set_vertex_color(1, 1, 1, alpha)
    for i = 2, bubble_node_mesh:get_n_vertices() do
        bubble_node_mesh:set_vertex_color(i, 1, 1, 1, 0)
    end
    self._bubble_node_mesh = bubble_node_mesh

    self._bubble_node_mesh_texture = rt.RenderTexture(2 * bubble_node_mesh_radius + 2 * padding, 2 * bubble_node_mesh_radius + 2 * padding, 8)
    self._bubble_node_mesh_texture:bind()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bubble_node_mesh:get_native(), 0.5 * self._bubble_node_mesh_texture:get_width(), 0.5 * self._bubble_node_mesh_texture:get_height())
    self._bubble_node_mesh_texture:unbind()

    for texture in range(self._node_mesh_texture, self._bubble_node_mesh_texture) do
        texture:set_scale_mode(rt.TextureScaleMode.LINEAR)
    end

    if _outline_shader == nil then _outline_shader = rt.Shader("overworld/player_body_outline.glsl") end
    if _core_shader == nil then _core_shader = rt.Shader("overworld/player_body_core.glsl") end

    self._canvas_scale = 3

    if self._outline_canvas == nil then
        local padding = 50
        local radius = rt.settings.overworld.player.radius * rt.settings.overworld.player.bubble_radius_factor
        self._outline_canvas = rt.RenderTexture(self._canvas_scale * (radius + 2 * padding), self._canvas_scale * (radius + 2 * padding), 4)
        self._outline_canvas:set_scale_mode(rt.TextureScaleMode.LINEAR)
    end

    if self._core_canvas == nil then
        local padding = 10
        local radius = rt.settings.overworld.player.radius
        self._core_canvas = rt.RenderTexture(self._canvas_scale * (radius + 2 * padding), self._canvas_scale * (radius + 2 * padding), 8)
        self._core_canvas:set_scale_mode(rt.TextureScaleMode.LINEAR)
    end

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "z" then
            _core_shader:recompile()
        end
    end)
end

--- @brief
function ow.PlayerBody:initialize(positions, floor_ax, floor_ay, floor_bx, floor_by)
    local success, tris = pcall(love.math.triangulate, positions)
    if not success then
        --success, tris = pcall(slick.triangulate, { positions })
        return
    end

    self._positions = positions
    self._tris = tris or self._tris
    self._center_x, self._center_y = self._player:get_physics_body():get_predicted_position()
    self._is_bubble = self._player:get_is_bubble()

    self._use_ground = self._player._bottom_wall

    if floor_ax ~= nil then
        self._floor_ax, self._floor_ay, self._floor_bx, self._floor_by = floor_ax, floor_ay, floor_bx, floor_by
    end

    for tri in values(tris) do
        local center_x = (tri[1] + tri[3] + tri[5]) / 3
        local center_y = (tri[2] + tri[4] + tri[6]) / 3
        table.insert(positions, center_x)
        table.insert(positions, center_y)
    end

    local radius = self._player:get_radius()
    local n_rings = 7
    local n_ropes_per_ring = #positions / 2
    local max_rope_length = radius * 4

    if table.sizeof(self._ropes) < table.sizeof(tris) then
        self._n_segments = 8
        self._n_ropes = table.sizeof(tris)
        self._ropes = {}

        for ring = 1, n_rings do
            local ring_radius = ((ring - 1) / n_rings) * radius
            local n_ropes = ring_radius == 0 and 1 or n_ropes_per_ring
            for i = 1, n_ropes do
                local angle = (i - 1) / n_ropes_per_ring * 2 * math.pi
                local center_x = math.cos(angle) * ring_radius
                local center_y = math.sin(angle) * ring_radius

                local rope = {
                    current_positions = {},
                    last_positions = {},
                    distances = {},
                    bubble_distances = {},
                    anchor_x = center_x,
                    anchor_y = center_y,
                    scale = (ring - 1) / n_rings,
                    hue = 1 - (ring - 1) / n_rings,
                    timestamp = love.timer.getTime(),
                }

                rope.axis_x, rope.axis_y = math.normalize(center_x, center_y)

                center_x = center_x + self._center_x
                center_y = center_y + self._center_y

                local rope_length = (1 - rope.scale) * max_rope_length
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
                    table.insert(rope.bubble_distances, 0)
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
local _gravity = 0
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
    self._shader_elapsed = self._shader_elapsed + delta

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
            local distances = self._is_bubble and rope.bubble_distances or rope.distances
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

            rope.timestamp = love.timer.getTime()
        end
    end

    if false then --not self._is_bubble and self._use_ground then
        local ax, ay = self._floor_ax, self._floor_ay
        local bx, by = self._floor_bx, self._floor_by

        local cx, cy = self._player:get_physics_body():get_predicted_position()
        local radius = self._player:get_radius() * 1.5

        for rope in values(self._ropes) do
            local positions = rope.current_positions

            for i = 1, #positions, 2 do
                local px, py = positions[i], positions[i + 1]

                local ab_x, ab_y = bx - ax, by - ay
                local ap_x, ap_y = px - ax, py - ay
                local ab_length_squared = ab_x * ab_x + ab_y * ab_y
                local dot_product = (ap_x * ab_x + ap_y * ab_y) / ab_length_squared

                local closest_x = ax + dot_product * ab_x
                local closest_y = ay + dot_product * ab_y

                local normal_x, normal_y = -ab_y, ab_x -- Perpendicular vector
                local to_point_x, to_point_y = px - closest_x, py - closest_y
                local side = to_point_x * normal_x + to_point_y * normal_y

                if side > 0 then
                    positions[i] = closest_x
                    positions[i + 1] = closest_y
                end

                local dx, dy = px - cx, py - cy
                if math.magnitude(dx, dy) > radius then
                    dx, dy = math.normalize(dx, dy)
                    positions[i] = cx + dx * radius
                    positions[i+1] = cy + dy * radius
                end
            end
        end
    end

    local points = {}
    for rope in values(self._ropes) do
        table.insert(points, rope.current_positions[#rope.current_positions-1])
        table.insert(points, rope.current_positions[#rope.current_positions])
    end
    self._points = points

    self._interpolation_factor = self._elapsed / _step
end

--- @brief
function ow.PlayerBody:draw()
    local mesh = self._is_bubble and self._bubble_node_mesh:get_native() or self._node_mesh:get_native()

    love.graphics.push()
    love.graphics.origin()
    local w, h = self._outline_canvas:get_size()
    love.graphics.translate(0.5 * w, 0.5 * h)
    love.graphics.scale(self._canvas_scale, self._canvas_scale)
    love.graphics.translate(-0.5 * w, -0.5 * h)
    love.graphics.translate(-self._center_x + 0.5 * w, -self._center_y + 0.5 * h)

    love.graphics.push()
    love.graphics.origin()
    love.graphics.draw(self._node_mesh_texture:get_native())
    love.graphics.pop()

    self._outline_canvas:bind()
    love.graphics.clear()

    local stencil_value = rt.graphics.get_stencil_value()
    rt.graphics.stencil(stencil_value, function()
        for body in values(self._player:get_walls()) do
            body:draw()
        end
    end)
    rt.graphics.set_stencil_test(rt.StencilCompareMode.NOT_EQUAL, stencil_value)

    rt.graphics.set_blend_mode(rt.BlendMode.ADD, rt.BlendMode.ADD)
    love.graphics.setColor(1, 1, 1, 1)
    local rope_i, n_ropes = 0, table.sizeof(self._ropes)
    local texture = self._is_bubble and self._bubble_node_mesh_texture:get_native() or self._node_mesh_texture:get_native()
    for rope in values(self._ropes) do
        local tw, th = texture:getDimensions()
        for i = 1, #rope.current_positions, 2 do
            local scale = math.min(rope.scale + 0.5, 1)
            local last_x, last_y = rope.last_positions[i+0], rope.last_positions[i+1]
            local current_x, current_y = rope.current_positions[i+0], rope.current_positions[i+1]
            local x, y = last_x + (current_x - last_x) * self._interpolation_factor,
            last_y + (current_y - last_y) * self._interpolation_factor


            love.graphics.draw(texture, x - 0.5 * tw, y - 0.5 * th, 0, scale, scale)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    rt.graphics.set_blend_mode(nil)

    love.graphics.translate(self._center_x, self._center_y)
    love.graphics.scale(1.0)
    love.graphics.translate(-self._center_x, -self._center_y)
    love.graphics.polygon("fill", self._positions)

    self._outline_canvas:unbind()
    rt.graphics.set_blend_mode(nil)
    love.graphics.pop()

    local r, g, b, a = rt.Palette.BLACK:unpack()
    love.graphics.setColor(r, g, b, 1)
    love.graphics.draw(self._outline_canvas:get_native(), self._center_x, self._center_y, 0, 1 / self._canvas_scale, 1 / self._canvas_scale, 0.5 * w, 0.5 * h)

    _outline_shader:bind()
    local r, g, b, a = rt.lcha_to_rgba(0.8, 1, self._player:get_hue(), 1)
    love.graphics.setColor(r, g, b, a)
    love.graphics.draw(self._outline_canvas:get_native(), self._center_x, self._center_y, 0, 1 / self._canvas_scale, 1 / self._canvas_scale, 0.5 * w, 0.5 * h)
    _outline_shader:unbind()

    local outline_width = 1.5

    if self._is_bubble then
        local radius = rt.settings.overworld.player.radius
        local offset = 0.5
        love.graphics.setColor(r - offset, g - offset, b - offset, a)
        love.graphics.circle("fill", self._center_x, self._center_y, radius)

        _core_shader:bind()
        _core_shader:send("hue", self._player:get_hue())
        _core_shader:send("elapsed", self._shader_elapsed)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", self._center_x, self._center_y, radius - outline_width)
        _core_shader:unbind()
    else
        local outline_offset = outline_width / self._player:get_radius()
        local outline_scale = 1
        local inside_scale = outline_scale - outline_offset

        love.graphics.translate(self._center_x, self._center_y)
        love.graphics.scale(outline_scale) -- actual hitbox
        love.graphics.translate(-self._center_x, -self._center_y)
        local offset = 0.3
        love.graphics.setColor(r - offset, g - offset, b - offset, a)
        love.graphics.polygon("fill", self._positions)

        self._core_canvas:bind()
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setColor(1, 1, 1, 1)

        love.graphics.push()
        love.graphics.origin()

        w, h = self._core_canvas:get_size()
        love.graphics.translate(0.5 * w, 0.5 * h)
        love.graphics.scale(inside_scale * self._canvas_scale)
        love.graphics.translate(-0.5 * w, -0.5 * h)
        love.graphics.setColor(r, g, b, a)

        love.graphics.translate(-self._center_x + 0.5 * w, -self._center_y + 0.5 * h)
        _core_shader:bind()
        _core_shader:send("hue", self._player:get_hue())
        _core_shader:send("elapsed", self._shader_elapsed)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.polygon("fill", self._positions)
        _core_shader:unbind()

        love.graphics.pop()
        self._core_canvas:unbind()

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self._core_canvas:get_native(), self._center_x, self._center_y, 0, 1 / self._canvas_scale, 1 / self._canvas_scale, 0.5 * w, 0.5 * h)
    end
end