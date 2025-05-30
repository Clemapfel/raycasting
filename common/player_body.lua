rt.settings.player_body = {
    -- rope params
    n_rings = 7,
    n_segments_per_rope = 8,
    max_rope_length_factor = 5, -- * player radius

    -- graphics
    node_mesh_alpha = 0.05,
    node_mesh_padding = 4,
    node_mesh_radius = 10,
    node_mesh_bubble_radius = 1,
    bubble_scale_offset = 10,
    non_bubble_scale_offset = 6,

    canvas_padding = 100,
    canvas_scale = 3,

    highlight_brightness = 0.2,
    outline_value_offset = 0.5,
    outline_width = 1.5,

    -- constraint solver params
    non_bubble = {
        n_velocity_iterations = 4,
        n_distance_iterations = 4,
        n_axis_iterations = 0,
        n_bending_iterations = 0,
        velocity_damping = 0.15,
        inertia = 0.8
    },

    bubble = {
        n_velocity_iterations = 2,
        n_distance_iterations = 0, -- copies n_bending
        n_axis_iterations = 1,
        n_bending_iterations = 13,
        velocity_damping = 0.1,
        inertia = 0
    },

    gravity = 0
}

--- @class rt.PlayerBody
rt.PlayerBody = meta.class("PlayerBody")

local _outline_shader, _core_shader, _canvas = nil, nil, nil
local _settings = rt.settings.player_body

--- @brief
function rt.PlayerBody:instantiate(player)
    meta.assert(player, rt.Player)

    self._player = player
    self._player_radius = rt.settings.player.radius
    self._is_bubble = self._player:get_is_bubble()
    self._player_x, self._player_y = self._player:get_position()
    self._center_x, self._center_x = self._player_x, self._player_y
    self._ropes = {}
    self._n_ropes = 0
    self._positions = {}
    self._stencil_bodies = {}
    self._shader_elapsed = 0
    self._is_initialized = false

    if _outline_shader == nil then _outline_shader = rt.Shader("common/player_body_outline.glsl") end
    if _core_shader == nil then _core_shader = rt.Shader("common/player_body_core.glsl") end

    -- init metaball ball mesh

    self._node_mesh = rt.MeshCircle(0, 0, _settings.node_mesh_radius)
    self._node_mesh:set_vertex_color(1, 1, 1, 1, 1)
    for i = 2, self._node_mesh:get_n_vertices() do
        self._node_mesh:set_vertex_color(i, 1, 1, 1, 0.0)
    end

    local canvas_w = 2 * _settings.node_mesh_radius + 2 * _settings.node_mesh_padding
    self._node_mesh_texture = rt.RenderTexture(canvas_w, canvas_w, 4)
    self._node_mesh_texture:bind()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._node_mesh:get_native(), 0.5 * canvas_w, 0.5 * canvas_w)
    self._node_mesh_texture:unbind()

    -- init canvases

    self._canvas_scale = _settings.canvas_scale

    do
        local padding = _settings.canvas_padding
        local radius = self._player_radius * rt.settings.player.bubble_radius_factor
        self._outline_canvas = rt.RenderTexture(self._canvas_scale * (radius + 2 * padding), self._canvas_scale * (radius + 2 * padding), 4)
        self._outline_canvas:set_scale_mode(rt.TextureScaleMode.LINEAR)
    end

    do
        local padding = self._player_radius
        local radius = self._player_radius
        self._core_canvas = rt.RenderTexture(self._canvas_scale * (radius + 2 * padding), self._canvas_scale * (radius + 2 * padding), 8)
        self._core_canvas:set_scale_mode(rt.TextureScaleMode.LINEAR)
    end

    -- expressions
    self._bottom_eye_lid_position = 0
    self._bottom_eye_lid = {}
    self._top_eye_lid_position = 0
    self._top_eye_lid = {}
end

--- @brief
function rt.PlayerBody:initialize(positions)
    self._positions = positions
    self._center_x, self._center_y = positions[1], positions[2]

    local n_rings = _settings.n_rings
    local n_ropes_per_ring = #positions / 2
    local n_segments = _settings.n_segments_per_rope
    local bubble_rope_length = (self._player_radius * rt.settings.player.bubble_radius_factor) - 2.5 * _settings.node_mesh_radius

    local ring_to_ring_radius = function(ring_i)
        return ((ring_i - 1) / n_rings) * self._player_radius
    end

    local ring_to_n_ropes = function(ring_i)
        if ring_i == 1 then
            return 3
        else
            return #positions / 2
        end
    end

    if self._is_initialized == false then
        -- init ropes
        local max_rope_length = _settings.max_rope_length_factor * self._player_radius
        for ring = 1, n_rings do
            local ring_radius = ring_to_ring_radius(ring)
            local current_n_ropes = ring_to_n_ropes(ring)
            local angle_step = (2 * math.pi) / current_n_ropes
            for i = 1, current_n_ropes do
                local angle = (i - 1) * angle_step
                if ring % 2 == 1 then angle = angle + angle_step * 0.5 end
                local axis_x, axis_y = math.cos(angle), math.sin(angle)
                local center_x = axis_x * ring_radius
                local center_y = axis_y * ring_radius
                local scale = (ring - 1) / n_rings
                local rope_length = (1 - scale) * max_rope_length

                local rope = {
                    current_positions = {},
                    last_positions = {},
                    last_velocities = {},
                    distances = {}, -- segment distances
                    masses = {},
                    bubble_distances = {},
                    anchor_x = center_x, -- anchor of first node
                    anchor_y = center_y,
                    axis_x = axis_x, -- axis constraint
                    axis_y = axis_y,
                    scale = scale, -- metaball scale
                    length = rope_length, -- total rope length
                }

                center_x = center_x + self._center_x
                center_y = center_y + self._center_y
                local dx, dy = math.normalize(rope.anchor_x - self._center_x, rope.anchor_y - self._center_y)

                for segment_i = 1, n_segments do
                    table.insert(rope.current_positions, center_x)
                    table.insert(rope.current_positions, center_x)
                    table.insert(rope.last_positions, center_x)
                    table.insert(rope.last_positions, center_x)
                    table.insert(rope.last_velocities, 0)
                    table.insert(rope.last_velocities, 0)
                    table.insert(rope.masses,  (segment_i - 1) / n_segments)
                    table.insert(rope.distances, rope_length / n_segments)
                    table.insert(rope.bubble_distances, bubble_rope_length / n_segments)
                end

                table.insert(self._ropes, rope)
                self._n_ropes = self._n_ropes + 1
            end
        end

        self._is_initialized = true
    else
        --[[
        -- update rope anchors
        local rope_i = 1
        for ring = 1, n_rings do
            local ring_radius = ring_to_ring_radius(ring)
            local current_n_ropes = ring_to_n_ropes(ring)
            for i = 1, current_n_ropes do
                local contour_index = (i - 1) * 2 + 1
                local contour_x = positions[contour_index]
                local contour_y = positions[contour_index + 1]
                local dx = contour_x - self._center_x
                local dy = contour_y - self._center_y
                dx, dy = math.normalize(dx, dy)

                local rope = self._ropes[rope_i]
                --rope.anchor_x = dx * ring_radius
                --rope.anchor_y = dy * ring_radius
                rope_i = rope_i + 1
            end
        end
        ]]--
    end

    table.insert(self._positions, self._positions[3])
    table.insert(self._positions, self._positions[4])

    self._is_bubble = self._player:get_is_bubble()
    self:_update_eyelids()
end

local function _generate_eyelid_mesh(t, eye_x, eye_y, eye_r, points)
    local out = {}

    local direction = t >= 0
    t = math.abs(t)

    local y
    if direction == true then
        y = eye_y + t * eye_r
    else
        y = eye_y - t * eye_r
    end

    local dx = math.sqrt(eye_r^2 - (t * eye_r)^2)
    local left_x = eye_x - dx
    local right_x = eye_x + dx

    --[[
    if direction == true then
        table.insert(out, right_x)
        table.insert(out, y)
    else
        table.insert(out, left_x)
        table.insert(out, y)
    end
    ]]--

    local x_width = right_x - left_x

    local left_angle = (math.angle(left_x - eye_x, y - eye_y))
    local right_angle = (math.angle(right_x - eye_x, y - eye_y))

    local min_angle = math.min(left_angle, right_angle)
    local max_angle = math.max(left_angle, right_angle)


    for i = 1, #points, 2 do
        local px = points[i+0]
        local py = points[i+1]
        local angle = math.angle(px - eye_x, py - eye_y)

        if angle >= min_angle and angle <= max_angle then
            table.insert(out, px)
            table.insert(out, py)
        end
    end

    --[[
    local n_steps = 32
    local step = math.abs(left_angle - right_angle) / n_steps
    for angle = math.min(left_angle, right_angle), math.max(left_angle, right_angle), step do
        table.insert(out, eye_x + math.cos(angle) * eye_r)
        table.insert(out, eye_y + math.sin(angle) * eye_r)
    end
    ]]

    --[[
    if direction == true then
        table.insert(out, left_x)
        table.insert(out, y)
    else
        table.insert(out, right_x)
        table.insert(out, y)
    end
    ]]--

    local offset
    if direction == true then
        offset = -0.5 * math.pi
    else
        offset =  0.5 * math.pi
    end

    local n_steps = 32
    local y_radius = math.sqrt(eye_r * t)
    local step = math.pi / n_steps
    for angle = -0.5 * math.pi + offset, 0.5 * math.pi + offset + step, step do
        table.insert(out, eye_x + math.cos(angle) * x_width / 2)
        table.insert(out, y + math.sin(angle) * y_radius)
    end

    return out
end

--- @brief
function rt.PlayerBody:_update_eyelids()
    if self._bottom_eye_lid == 0 then
        self._bottom_eye_lid = {}
    else
        self._bottom_eye_lid = _generate_eyelid_mesh(
            1 - self._bottom_eye_lid_position,
            self._center_x,
            self._center_y,
            self._player:get_radius(),
            self._positions
        )
    end

    if self._top_eye_lid == 0 then
        self._top_eye_lid = {}
    else
        self._top_eye_lid = _generate_eyelid_mesh(
            -1 * (1 - self._top_eye_lid_position),
            self._center_x,
            self._center_y,
            self._player:get_radius(),
            self._positions
        )
    end
end


-- keep nodes at fixed distance
local function _solve_distance_constraint(a_x, a_y, b_x, b_y, rest_length)
    local current_distance = math.distance(a_x, a_y, b_x, b_y)

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

-- align nodes with axis
local function _solve_axis_constraint(a_x, a_y, b_x, b_y, axis_x, axis_y)
    local delta_x = b_x - a_x
    local delta_y = b_y - a_y

    local dot_product = math.abs(delta_x * axis_x + delta_y * axis_y)
    local projection_x = dot_product * axis_x
    local projection_y = dot_product * axis_y

    local correction_x = (projection_x - delta_x)
    local correction_y = (projection_y - delta_y)

    local blend = 0.5
    a_x = a_x - correction_x * blend
    a_y = a_y - correction_y * blend
    b_x = b_x + correction_x * blend
    b_y = b_y + correction_y * blend

    return a_x, a_y, b_x, b_y
end

-- align sequence of 3 nodes towards straight line
local function _solve_bending_constraint(a_x, a_y, b_x, b_y, c_x, c_y, stiffness)
    local ab_x = b_x - a_x
    local ab_y = b_y - a_y
    local bc_x = c_x - b_x
    local bc_y = c_y - b_y

    ab_x, ab_y = math.normalize(ab_x, ab_y)
    bc_x, bc_y = math.normalize(bc_x, bc_y)

    local target_x = ab_x + bc_x
    local target_y = ab_y + bc_y

    local correction_x = target_x
    local correction_y = target_y

    local blend = 0.5 * stiffness
    a_x = a_x - correction_x * blend
    a_y = a_y - correction_y * blend
    c_x = c_x + correction_x * blend
    c_y = c_y + correction_y * blend

    return a_x, a_y, c_x, c_y
end

--- @brief
function rt.PlayerBody:update(delta)
    -- non rope sim updates
    self._shader_elapsed = self._shader_elapsed + delta
    self._r, self._g, self._b, self._a = rt.lcha_to_rgba(0.8, 1, self._player:get_hue(), self._player:get_opacity())
    self._player_x, self._player_y = self._player:get_predicted_position()

    local w, h = self._outline_canvas:get_size()
    local bodies = self._player:get_physics_world():query_aabb(
        self._player_x - 0.5 * w, self._player_y - 0.5 * h, w, h
    )

    self._stencil_bodies = {}
    for body in values(bodies) do
        if body:has_tag("hitbox") then
            table.insert(self._stencil_bodies, body)
        end
    end

    -- ground collision
    local player_grounded = self._player:get_is_grounded()

    -- rope sim
    local gravity_x, gravity_y, velocity_damping
    if self._is_bubble then
        gravity_x, gravity_y = 0, 0
        velocity_damping = 1 - _settings.bubble.velocity_damping
    else
        gravity_x, gravity_y = 0, 1 * _settings.gravity
        velocity_damping = 1 - _settings.non_bubble.velocity_damping
    end

    local todo = self._is_bubble and _settings.bubble or _settings.non_bubble
    for rope in values(self._ropes) do
        local positions = rope.current_positions
        local old_positions = rope.last_positions
        local old_velocities = rope.last_velocities
        local distances = self._is_bubble and rope.bubble_distances or rope.distances
        local masses = rope.masses

        local n_axis_iterations_done = 0
        local n_distance_iterations_done = 0
        local n_velocity_iterations_done = 0
        local n_bending_iterations_done = 0

        while
        (n_velocity_iterations_done < todo.n_velocity_iterations) or
            (n_distance_iterations_done < todo.n_distance_iterations + todo.n_bending_iterations) or
            (n_axis_iterations_done < todo.n_axis_iterations) or
            (n_bending_iterations_done < todo.n_bending_iterations)
        do
            -- verlet integration
            if n_velocity_iterations_done < todo.n_velocity_iterations then
                local mass_i = 1
                for i = 1, #positions, 2 do
                    local current_x, current_y = positions[i+0], positions[i+1]
                    local old_x, old_y = old_positions[i+0], old_positions[i+1]
                    local mass = masses[mass_i]
                    local before_x, before_y = current_x, current_y

                    local velocity_x = (current_x - old_x) * velocity_damping
                    local velocity_y = (current_y - old_y) * velocity_damping

                    -- inertia
                    velocity_x = math.mix(velocity_x, old_velocities[i+0], todo.inertia)
                    velocity_y = math.mix(velocity_y, old_velocities[i+1], todo.inertia)

                    positions[i+0] = current_x + velocity_x + mass * gravity_x * delta * delta
                    positions[i+1] = current_y + velocity_y + mass * gravity_y * delta * delta

                    old_positions[i+0] = before_x
                    old_positions[i+1] = before_y

                    old_velocities[i+0] = velocity_x
                    old_velocities[i+1] = velocity_y

                    mass_i = mass_i + 1
                end

                n_velocity_iterations_done = n_velocity_iterations_done + 1
            end

            -- axis
            if n_axis_iterations_done < todo.n_axis_iterations then
                for i = 1, #positions - 2, 2 do
                    local node_1_xi, node_1_yi, node_2_xi, node_2_yi = i+0, i+1, i+2, i+3
                    local node_1_x, node_1_y = positions[node_1_xi], positions[node_1_yi]
                    local node_2_x, node_2_y = positions[node_2_xi], positions[node_2_yi]

                    local new_x1, new_y1, new_x2, new_y2 = _solve_axis_constraint(
                        node_1_x, node_1_y,
                        node_2_x, node_2_y,
                        rope.axis_x, rope.axis_y
                    )

                    positions[node_1_xi] = new_x1
                    positions[node_1_yi] = new_y1
                    positions[node_2_xi] = new_x2
                    positions[node_2_yi] = new_y2
                end

                n_axis_iterations_done = n_axis_iterations_done + 1
            end

            -- bending
            if n_bending_iterations_done < todo.n_bending_iterations then
                local distance_i = 1
                for i = 1, #positions - 4, 2 do
                    local node_1_xi, node_1_yi, node_2_xi, node_2_yi, node_3_xi, node_3_yi = i+0, i+1, i+2, i+3, i+4, i+5
                    local node_1_x, node_1_y = positions[node_1_xi], positions[node_1_yi]
                    local node_2_x, node_2_y = positions[node_2_xi], positions[node_2_yi]
                    local node_3_x, node_3_y = positions[node_3_xi], positions[node_3_yi]

                    local new_x1, new_y1, new_x3, new_y3 = _solve_bending_constraint(
                        node_1_x, node_1_y,
                        node_2_x, node_2_y,
                        node_3_x, node_3_y,
                        (1 - i / #positions) -- more bendy the farther away from base
                    )

                    positions[node_1_xi] = new_x1
                    positions[node_1_yi] = new_y1
                    positions[node_3_xi] = new_x3
                    positions[node_3_yi] = new_y3

                    distance_i = distance_i + 1
                end

                n_bending_iterations_done = n_bending_iterations_done + 1
            end

            -- distance
            if n_distance_iterations_done < todo.n_distance_iterations + todo.n_bending_iterations then
                local distance_i = 1
                for i = 1, #positions - 2, 2 do
                    local node_1_xi, node_1_yi, node_2_xi, node_2_yi = i+0, i+1, i+2, i+3
                    local node_1_x, node_1_y = positions[node_1_xi], positions[node_1_yi]
                    local node_2_x, node_2_y = positions[node_2_xi], positions[node_2_yi]

                    if i == 1 then
                        node_1_x = self._player_x + rope.anchor_x
                        node_1_y = self._player_y + rope.anchor_y
                    end

                    local rest_length = distances[distance_i]

                    local new_x1, new_y1, new_x2, new_y2 = _solve_distance_constraint(
                        node_1_x, node_1_y,
                        node_2_x, node_2_y,
                        rest_length
                    )

                    positions[node_1_xi] = new_x1
                    positions[node_1_yi] = new_y1
                    positions[node_2_xi] = new_x2
                    positions[node_2_yi] = new_y2

                    distance_i = distance_i + 1
                end

                n_distance_iterations_done = n_distance_iterations_done + 1
            end
        end
    end
end


local _black_r, _black_g, _black_b = rt.Palette.BLACK:unpack()

--- @brief
function rt.PlayerBody:draw_body()
    if self._is_initialized ~= true then return end

    love.graphics.push()
    love.graphics.origin()

    local w, h = self._outline_canvas:get_size()
    love.graphics.translate(0.5 * w, 0.5 * h)
    love.graphics.scale(self._canvas_scale, self._canvas_scale)
    love.graphics.translate(-0.5 * w, -0.5 * h)
    love.graphics.translate(-self._center_x + 0.5 * w, -self._center_y + 0.5 * h)

    self._outline_canvas:bind()
    love.graphics.clear()

    -- stencil bordering geometry
    local stencil_value = rt.graphics.get_stencil_value()
    rt.graphics.stencil(stencil_value, function()
        for body in values(self._stencil_bodies) do
            body:draw()
        end
    end)
    rt.graphics.set_stencil_compare_mode(rt.StencilCompareMode.NOT_EQUAL, stencil_value)

    -- draw rope nodes
    rt.graphics.set_blend_mode(rt.BlendMode.ADD, rt.BlendMode.ADD)

    if self._is_bubble then
        love.graphics.setColor(1, 1, 1, 1)
    else
        love.graphics.setColor(1, 1, 1, _settings.node_mesh_alpha)
    end

    local rope_i, n_ropes = 0, self._n_ropes
    local texture = self._node_mesh_texture:get_native()
    local tw, th = self._node_mesh_texture:get_size()
    for rope in values(self._ropes) do
        for i = 1, #rope.current_positions, 2 do
            local scale = math.min(rope.scale + _settings.non_bubble_scale_offset / self._player:get_radius(), 1)
            local x, y = rope.last_positions[i+0], rope.last_positions[i+1]
            love.graphics.draw(texture, x, y, 0, scale, scale, 0.5 * tw, 0.5 * th)
        end
    end

    rt.graphics.set_blend_mode(nil)

    if not self._is_bubble then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.polygon("fill", self._positions)
    end

    self._outline_canvas:unbind()
    rt.graphics.set_stencil_compare_mode(nil)
    love.graphics.pop()

    -- black fill
    love.graphics.setColor(_black_r, _black_g, _black_b, self._a)
    love.graphics.draw(self._outline_canvas:get_native(), self._center_x, self._center_y, 0, 1 / self._canvas_scale, 1 / self._canvas_scale, 0.5 * w, 0.5 * h)

    -- outlines
    _outline_shader:bind()
    love.graphics.setColor(self._r, self._g,self._b, self._a)
    love.graphics.draw(self._outline_canvas:get_native(), self._center_x, self._center_y, 0, 1 / self._canvas_scale, 1 / self._canvas_scale, 0.5 * w, 0.5 * h)
    _outline_shader:unbind()
end

--- @brief
function rt.PlayerBody:draw_core()
    if self._is_initialized ~= true then return end

    local outline_width = _settings.outline_width
    local outside_scale = 1 + outline_width / self._player:get_radius()
    local inside_scale = 1

    -- core canvas for shader inlay
    self._core_canvas:bind()
    love.graphics.clear()

    love.graphics.push()
    love.graphics.origin()

    local w, h = self._core_canvas:get_size()
    love.graphics.translate(0.5 * w, 0.5 * h)
    love.graphics.scale(inside_scale * self._canvas_scale)
    love.graphics.translate(-0.5 * w, -0.5 * h)
    love.graphics.translate(-self._center_x + 0.5 * w, -self._center_y + 0.5 * h)

    love.graphics.setColor(1, 1, 1, self._a)
    _core_shader:bind()
    _core_shader:send("hue", self._player:get_hue())
    _core_shader:send("elapsed", self._shader_elapsed)
    if self._is_bubble then
        love.graphics.circle("fill", self._center_x, self._center_y, rt.settings.player.radius)
    else
        love.graphics.polygon("fill", self._positions)
    end
    _core_shader:unbind()

    love.graphics.pop()
    self._core_canvas:unbind()

    -- draw outline
    local darken = _settings.outline_value_offset
    love.graphics.setColor(1 - darken, 1 - darken, 1 - darken, self._a)
    love.graphics.draw(
        self._core_canvas:get_native(),
        self._player_x, self._player_y,
        0,
        1 / self._canvas_scale * outside_scale,
        1 / self._canvas_scale * outside_scale,
        0.5 * w, 0.5 * h
    )

    -- eyelid
    local stencil_value = rt.graphics.get_stencil_value()
    rt.graphics.stencil(stencil_value, function()
        if self._top_eye_lid_position > 0 then
            love.graphics.polygon("fill", self._top_eye_lid)
        end

        if self._bottom_eye_lid_position > 0 then
            love.graphics.polygon("fill", self._bottom_eye_lid)
        end
    end)
    rt.graphics.set_stencil_compare_mode(rt.StencilCompareMode.NOT_EQUAL, stencil_value)

    -- draw inside
    love.graphics.setColor(1, 1, 1, self._a)
    love.graphics.draw(
        self._core_canvas:get_native(),
        self._player_x, self._player_y,
        0,
        1 / self._canvas_scale * inside_scale,
        1 / self._canvas_scale * inside_scale,
        0.5 * w, 0.5 * h
    )

    rt.graphics.set_stencil_compare_mode(nil)

    love.graphics.push()
    love.graphics.translate(self._center_x, self._center_y)
    rt.Palette.WHITE:bind()
    for tri in values(self._tris) do
        love.graphics.polygon("fill", tri)
    end
    love.graphics.pop()

    -- highlight
    local boost = _settings.highlight_brightness
    love.graphics.push()
    love.graphics.setColor(boost, boost, boost, 1)
    rt.graphics.set_blend_mode(rt.BlendMode.ADD)
    local highlight_r = 4
    local offset = self._player_radius * 1 / 4
    love.graphics.translate(-offset, -offset)
    love.graphics.ellipse("fill", self._player_x, self._player_y, highlight_r, highlight_r)

    love.graphics.setColor(boost / 2, boost / 2, boost / 2, 1)
    love.graphics.translate(-highlight_r / 4, -highlight_r / 4)
    love.graphics.ellipse("fill", self._player_x, self._player_y, highlight_r / 2, highlight_r / 2)

    rt.graphics.set_blend_mode(nil)
    love.graphics.pop()

    --[[
    --love.graphics.circle("fill", self._center_x, self._center_y, 100)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setPointSize(1)
    for rope in values(self._ropes) do
        love.graphics.points(rope.current_positions[1], rope.current_positions[2])

        for i = 1, #rope.current_positions - 2, 2 do
            local hue = 1 - (i - 1) / (#rope.current_positions / 2) * 0.5
            love.graphics.setColor(hue, hue, hue, 1)
            love.graphics.line(rope.current_positions[i], rope.current_positions[i+1], rope.current_positions[i+2], rope.current_positions[i+3])
        end
    end
    ]]--

end
