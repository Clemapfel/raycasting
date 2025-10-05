require "common.smoothed_motion_1d"

rt.settings.player_body = {
    relative_velocity_influence = 1 / 3, -- [0, 1] where 0 no influence

    -- rope params
    n_ropes = 27,
    n_rings = 7,
    n_segments_per_rope = 8,
    max_rope_length_factor = 5.2, -- * player radius

    -- graphics
    node_mesh_alpha = 0.05,
    node_mesh_padding = 4,
    node_mesh_radius = 10,
    node_mesh_bubble_radius = 1,
    bubble_scale_offset = 10,
    non_bubble_scale_offset = 6,

    canvas_padding = 50,
    canvas_scale = 3,

    highlight_brightness = 0.4,
    highlight_radius = 8,
    outline_value_offset = 0.5,
    outline_width = 1.5,

    -- constraint solver params
    non_bubble = {
        n_velocity_iterations = 4,
        n_distance_iterations = 8,
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

    gravity = 2,

    squish_speed = 4, -- fraction
    squish_magnitude = 0.11, -- fraction
}

--- @class rt.PlayerBody
rt.PlayerBody = meta.class("PlayerBody")

local _settings = rt.settings.player_body
local _canvas = nil

local _threshold_shader = rt.Shader("common/player_body_outline.glsl", { MODE = 0})
local _outline_shader = rt.Shader("common/player_body_outline.glsl", { MODE = 1 })

local _core_shader = rt.Shader("common/player_body_core.glsl")

--- @brief
function rt.PlayerBody:instantiate(player)
    meta.assert(player, rt.Player)

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then _outline_shader:recompile() end
    end)

    self._player = player
    self._player_radius = rt.settings.player.radius
    self._is_bubble = self._player:get_is_bubble()
    self._player_x, self._player_y = self._player:get_position()
    self._ropes = {}
    self._n_ropes = 0
    self._positions = {}
    self._stencil_bodies = {}
    self._shader_elapsed = 0
    self._is_initialized = false
    self._queue_relax = false

    self._relative_velocity_x = 0
    self._relative_velocity_y = 0

    self._core_canvas_needs_update = true
    self._body_canvas_needs_update = true

    self._is_squished = false
    self._squish_normal_x = nil -- set by set_is_squished
    self._squish_normal_y = nil
    self._squish_origin_x = nil
    self._squish_normal_y = nil

    self._squish_motion = rt.SmoothedMotion1D(1, _settings.squish_speed)

    self._r, self._g, self._b, self._a = 1, 1, 1, 1

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
        self._body_canvas_a = rt.RenderTexture(self._canvas_scale * (radius + 2 * padding), self._canvas_scale * (radius + 2 * padding), 4)
        self._body_canvas_b = rt.RenderTexture(self._canvas_scale * (radius + 2 * padding), self._canvas_scale * (radius + 2 * padding), 4)

        for canvas in range(self._body_canvas_a, self._body_canvas_b) do
            canvas:set_scale_mode(rt.TextureScaleMode.LINEAR)
        end
    end

    do
        local padding = self._player_radius
        local radius = self._player_radius
        self._core_canvas = rt.RenderTexture(self._canvas_scale * (radius + 2 * padding), self._canvas_scale * (radius + 2 * padding), 8)
        self._core_canvas:set_scale_mode(rt.TextureScaleMode.LINEAR)
    end

    -- highlight mesh
    local highlight_r = rt.settings.player_body.highlight_radius

    self._highlight_mesh = rt.MeshCircle(0, 0, highlight_r, highlight_r)
    for i = 1, self._highlight_mesh:get_n_vertices() do
        if i == 1 then
            self._highlight_mesh:set_vertex_color(i, 1, 1, 1, 1)
            self._highlight_mesh:set_vertex_position(i, -0.25 * highlight_r, -0.25 * highlight_r)
        else
            self._highlight_mesh:set_vertex_color(i, 1, 1, 1, 0)
        end
    end
end

--- @brief
function rt.PlayerBody:update_anchors(positions)
    self._positions = positions
    self._player_x, self._player_y = positions[1], positions[2]
    table.insert(self._positions, self._positions[3])
    table.insert(self._positions, self._positions[4])

    self._is_bubble = self._player:get_is_bubble()

    self:initialize(positions)
end

--- @brief
function rt.PlayerBody:initialize(positions)
    if self._is_initialized == false then
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
                return _settings.n_ropes
            end
        end

        local mass_easing = function(t)
            -- only last node affected by gravity
            return ternary(t == 1, 1, 0.25)
        end

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
                local scale = ring / n_rings

                local rope_length = (1 - scale) * max_rope_length

                local rope = {
                    current_positions = {},
                    last_positions = {},
                    last_velocities = {},
                    masses = {},
                    anchor_x = center_x, -- anchor of first node
                    anchor_y = center_y,
                    axis_x = axis_x, -- axis constraint
                    axis_y = axis_y,
                    scale = scale, -- metaball scale
                    length = rope_length, -- total rope length
                    n_segments = n_segments,
                    segment_length = rope_length / n_segments,
                    bubble_segment_length = bubble_rope_length / n_segments
                }

                center_x = center_x + self._player_x
                center_y = center_y + self._player_y
                local dx, dy = math.normalize(rope.anchor_x - self._player_x, rope.anchor_y - self._player_y)

                for segment_i = 1, n_segments do
                    table.insert(rope.current_positions, center_x)
                    table.insert(rope.current_positions, center_x)
                    table.insert(rope.last_positions, center_x)
                    table.insert(rope.last_positions, center_x)
                    table.insert(rope.last_velocities, 0)
                    table.insert(rope.last_velocities, 0)
                    table.insert(rope.masses,  mass_easing(segment_i - 1) / n_segments)
                end

                table.insert(self._ropes, rope)
                self._n_ropes = self._n_ropes + 1
            end
        end

        self._is_initialized = true
        if self._queue_relax == true then
            self:relax()
        end
    end
end

function rt.PlayerBody:relax()
    if not self._is_initialized then
        self._queue_relax = true
        return
    end

    -- release all rope forces
    local px, py = self._player:get_position()
    for rope in values(self._ropes) do
        local dx, dy = rope.axis_x, rope.axis_y
        local x, y = px + rope.anchor_x, py + rope.anchor_y

        for i = 0, rope.n_segments - 1 do
            local step = ternary(self._player:get_is_bubble(), rope.segment_length, rope.bubble_segment_length)
            rope.current_positions[i * 2 + 1] = x + dx * step * i
            rope.current_positions[i * 2 + 2] = y + dy * step * i
        end

        for i = 1, #rope.last_positions do
            rope.last_positions[i] = rope.current_positions[i]
        end

        for i = 1, #rope.last_velocities do
            rope.last_velocities[i] = 0
        end
    end
end

rt.PlayerBody._rope_handler = function(data)
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
    local function _solve_axis_constraint(a_x, a_y, b_x, b_y, axis_x, axis_y, intensity)
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

    local rope = data.rope
    local positions = rope.current_positions
    local last_positions = rope.last_positions
    local last_velocities = rope.last_velocities
    local segment_length = data.is_bubble and rope.bubble_segment_length or rope.segment_length
    local masses = rope.masses

    do -- translate whole physics system into relative velocity
        local t = 1 - math.clamp(rt.settings.player_body.relative_velocity_influence, 0, 1)
        for i = 1, #positions, 2 do
            positions[i] = positions[i] + data.platform_delta_x * t
            positions[i+1] = positions[i+1] + data.platform_delta_y * t
            last_positions[i] = last_positions[i] + data.platform_delta_x * t
            last_positions[i+1] = last_positions[i+1] + data.platform_delta_y * t
        end
    end

    local n_axis_iterations_done = 0
    local n_distance_iterations_done = 0
    local n_velocity_iterations_done = 0
    local n_bending_iterations_done = 0

    data.n_distance_iterations = data.n_distance_iterations + data.n_bending_iterations

    while
    (n_velocity_iterations_done < data.n_velocity_iterations)
        or (n_distance_iterations_done < data.n_distance_iterations)
        or (n_axis_iterations_done < data.n_axis_iterations)
        or (n_bending_iterations_done < data.n_bending_iterations)
    do
        -- verlet integration
        if n_velocity_iterations_done < data.n_velocity_iterations then
            local mass_i = 1
            for i = 1, #positions, 2 do
                local current_x, current_y = positions[i+0], positions[i+1]
                if i == 1 then
                    current_x = data.position_x + rope.anchor_x
                    current_y = data.position_y + rope.anchor_y
                end

                local old_x, old_y = last_positions[i+0], last_positions[i+1]
                local mass = masses[mass_i]
                local before_x, before_y = current_x, current_y

                local velocity_x = (current_x - old_x) * data.velocity_damping
                local velocity_y = (current_y - old_y) * data.velocity_damping

                velocity_x = math.mix(velocity_x, last_velocities[i+0], data.inertia)
                velocity_y = math.mix(velocity_y, last_velocities[i+1], data.inertia)

                positions[i+0] = current_x + velocity_x + mass * data.gravity_x * data.delta
                positions[i+1] = current_y + velocity_y + mass * data.gravity_y * data.delta

                last_positions[i+0] = before_x
                last_positions[i+1] = before_y

                last_velocities[i+0] = velocity_x
                last_velocities[i+1] = velocity_y

                mass_i = mass_i + 1
            end

            n_velocity_iterations_done = n_velocity_iterations_done + 1
        end

        -- axis
        if n_axis_iterations_done < data.n_axis_iterations then
            for i = 1, #positions - 2, 2 do
                local node_1_xi, node_1_yi, node_2_xi, node_2_yi = i+0, i+1, i+2, i+3
                local node_1_x, node_1_y = positions[node_1_xi], positions[node_1_yi]
                local node_2_x, node_2_y = positions[node_2_xi], positions[node_2_yi]

                local new_x1, new_y1, new_x2, new_y2 = _solve_axis_constraint(
                    node_1_x, node_1_y,
                    node_2_x, node_2_y,
                    rope.axis_x, rope.axis_y,
                    data.axis_intensity
                )

                positions[node_1_xi] = new_x1
                positions[node_1_yi] = new_y1
                positions[node_2_xi] = new_x2
                positions[node_2_yi] = new_y2
            end

            n_axis_iterations_done = n_axis_iterations_done + 1
        end

        -- bending
        if n_bending_iterations_done < data.n_bending_iterations then
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
        if n_distance_iterations_done < data.n_distance_iterations then
            local distance_i = 1
            for i = 1, #positions - 2, 2 do
                local node_1_xi, node_1_yi, node_2_xi, node_2_yi = i+0, i+1, i+2, i+3
                local node_1_x, node_1_y = positions[node_1_xi], positions[node_1_yi]
                local node_2_x, node_2_y = positions[node_2_xi], positions[node_2_yi]

                if i == 1 then
                    node_1_x = data.position_x + rope.anchor_x
                    node_1_y = data.position_y + rope.anchor_y
                end

                local rest_length = segment_length

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

--- @brief
function rt.PlayerBody:update(delta)
    -- non rope sim updates
    self._shader_elapsed = self._shader_elapsed + delta
    self._r, self._g, self._b, self._a = rt.lcha_to_rgba(0.8, 1, self._player:get_hue(), self._player:get_opacity())

    self._squish_motion:update(delta)

    local w, h = self._body_canvas_a:get_size()
    local bodies = self._player:get_physics_world():query_aabb(
        self._player_x - 0.5 * w, self._player_y - 0.5 * h, w, h
    )

    self._stencil_bodies = {}
    for body in values(bodies) do
        if body:has_tag("stencil") then
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

    local to_send = {}

    for i, rope in ipairs(self._ropes) do
        self._rope_handler({
            rope = rope,
            rope_i = i,
            is_bubble = self._is_bubble,
            n_velocity_iterations = todo.n_velocity_iterations,
            n_distance_iterations = todo.n_distance_iterations,
            n_axis_iterations = todo.n_axis_iterations,
            axis_intensity = 1,
            n_bending_iterations = todo.n_bending_iterations,
            inertia = todo.inertia,
            gravity_x = gravity_x,
            gravity_y = gravity_y,
            delta = delta,
            velocity_damping = velocity_damping,
            position_x = self._player_x,
            position_y = self._player_y,
            platform_delta_x = self._relative_velocity_x * delta,
            platform_delta_y = self._relative_velocity_y * delta
        })
    end

    self._core_canvas_needs_update = true
    self._body_canvas_needs_update = true
end

--- @brief
function rt.PlayerBody:_apply_squish(factor)
    local squish_amount = self._squish_motion:get_value()
    if squish_amount < 0.01 then return end -- skip

    local magnitude = _settings.squish_magnitude * (factor or 1)
    local squish_nx, squish_ny = self._squish_normal_x or 0, self._squish_normal_y or -1
    local squish_origin_x = self._squish_origin_x or self._player_x
    local squish_origin_y = self._squish_origin_y or self._player_y + 0.5 * self._player_radius

    local angle = math.angle(squish_nx, squish_ny)

    love.graphics.translate(squish_origin_x, squish_origin_y)
    love.graphics.rotate(angle)
    love.graphics.scale(
        1 - squish_amount * magnitude,
        1
    )
    love.graphics.rotate(-angle)
    love.graphics.translate(-squish_origin_x, -squish_origin_y)
end

-- Rest of the code remains unchanged (draw_body, draw_core, draw_bloom, set_relative_velocity methods)
local _black_r, _black_g, _black_b = rt.Palette.BLACK:unpack()

--- @brief
function rt.PlayerBody:draw_body()
    if self._is_initialized ~= true then return end

    local w, h = self._body_canvas_a:get_size()
    local opacity = self._player:get_opacity()

    if self._body_canvas_needs_update then
        self._body_canvas_needs_update = false
        love.graphics.push("all")
        love.graphics.reset()

        love.graphics.translate(0.5 * w, 0.5 * h)
        love.graphics.scale(self._canvas_scale, self._canvas_scale)
        love.graphics.translate(-0.5 * w, -0.5 * h)
        love.graphics.translate(-self._player_x + 0.5 * w, -self._player_y + 0.5 * h)

        -- draw body
        self._body_canvas_a:bind()
        love.graphics.clear(0, 0, 0, 0)

        -- stencil bordering geometry
        local stencil_value = rt.graphics.get_stencil_value()
        rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW)
        for body in values(self._stencil_bodies) do
            body:draw(true) -- mask only
        end
        rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST, rt.StencilCompareMode.NOT_EQUAL)

        -- draw rope nodes
        rt.graphics.set_blend_mode(rt.BlendMode.ADD, rt.BlendMode.ADD)
        if self._is_bubble then
            love.graphics.setColor(1, 1, 1, 1)
        else
            love.graphics.setColor(1, 1, 1, _settings.node_mesh_alpha)
        end

        -- function to thin out only very last part of tail
        local easing = function(t)
            -- f\left(x\right)=\left(0.045\cdot e^{\ln\left(\frac{1}{0.045}+1\right)x}-0.045\right)^{b}
            local buldge = 2.5 -- the higher, the closer to f(x) = x easing
            t = t * 0.8
            local v = (0.045 * math.exp(math.log(1 / 0.045 + 1) * t) - 0.045) ^ buldge
            return 1 - math.clamp(v, 0, 1)
        end

        local rope_i, n_ropes = 0, self._n_ropes
        local tw, th = self._node_mesh_texture:get_size()
        for rope in values(self._ropes) do
            local segment_i = 0
            for i = 1, #rope.current_positions, 2 do
                love.graphics.push()
                self:_apply_squish(1 + 1 - (i - 1) / (#rope.current_positions / 2))
                local scale = easing(segment_i / rope.n_segments) * math.min(1, rope.scale + _settings.non_bubble_scale_offset / self._player:get_radius())
                -- Use current_positions for drawing to reduce visual lag
                local x, y = rope.current_positions[i+0], rope.current_positions[i+1]
                love.graphics.draw(self._node_mesh_texture:get_native(), x, y, 0, scale, scale, 0.5 * tw, 0.5 * th)

                love.graphics.pop()

                segment_i = segment_i + 1
            end
        end

        rt.graphics.set_blend_mode(nil)

        self._body_canvas_a:unbind()
        rt.graphics.set_stencil_mode(nil)
        love.graphics.pop()

        love.graphics.push("all")
        love.graphics.reset()

        -- draw a to b: fill
        self._body_canvas_b:bind()
        love.graphics.clear(0, 0, 0, 0)
        _threshold_shader:bind()
        self._body_canvas_a:draw()
        _threshold_shader:unbind()
        self._body_canvas_b:unbind()

        -- draw b to a: outline
        self._body_canvas_a:bind()
        love.graphics.clear(0, 0, 0, 0)
        _outline_shader:bind()
        self._body_canvas_b:draw()
        _outline_shader:unbind()
        self._body_canvas_a:unbind()

        -- b contains fill, a contains outline
        love.graphics.pop("all")
    end

    love.graphics.setShader(nil)
    love.graphics.setColor(_black_r, _black_g, _black_b, self._a * opacity)
    love.graphics.draw(
        self._body_canvas_b:get_native(),
        self._player_x,
        self._player_y,
        0,
        1 / self._canvas_scale,
        1 / self._canvas_scale,
        0.5 * w,
        0.5 * h
    )

    love.graphics.setColor(self._r, self._g, self._b, self._a * opacity)
    love.graphics.draw(
        self._body_canvas_a:get_native(),
        self._player_x,
        self._player_y,
        0,
        1 / self._canvas_scale,
        1 / self._canvas_scale,
        0.5 * w,
        0.5 * h
    )
end

--- @brief
function rt.PlayerBody:draw_core()
    if self._is_initialized ~= true then return end

    local opacity = self._player:get_opacity()
    local w, h = self._core_canvas:get_size()

    if self._core_canvas_needs_update then
        self._core_canvas_needs_update = false
        -- core canvas for shader inlay
        self._core_canvas:bind()
        love.graphics.clear()

        love.graphics.push("all")
        love.graphics.setStencilMode(nil)
        love.graphics.origin()

        love.graphics.translate(0.5 * w, 0.5 * h)
        love.graphics.scale(self._canvas_scale)
        love.graphics.translate(-0.5 * w, -0.5 * h)
        love.graphics.translate(-self._player_x + 0.5 * w, -self._player_y + 0.5 * h)

        love.graphics.setColor(1, 1, 1, self._a)
        _core_shader:bind()
        _core_shader:send("hue", self._player:get_hue())
        _core_shader:send("elapsed", self._shader_elapsed)
        if self._is_bubble then
            love.graphics.circle("fill", self._player_x, self._player_y, rt.settings.player.radius)
        else
            love.graphics.polygon("fill", self._positions)
        end
        _core_shader:unbind()

        love.graphics.pop()
        self._core_canvas:unbind()
    end

    local outline_width = _settings.outline_width
    local outside_scale = 1 + outline_width / self._player:get_radius()

    if self._is_bubble then
        rt.graphics.push_stencil()
        local stencil_value = rt.graphics.get_stencil_value()
        rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW)
        for body in values(self._stencil_bodies) do
            body:draw(true)
        end
        rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST, rt.StencilCompareMode.NOT_EQUAL)
    else
        love.graphics.push()
        self:_apply_squish()
    end

    -- draw outline
    local darken = _settings.outline_value_offset
    love.graphics.setColor(1 - darken, 1 - darken, 1 - darken, self._a * opacity)
    love.graphics.draw(
        self._core_canvas:get_native(),
        self._player_x, self._player_y,
        0,
        1 / self._canvas_scale * outside_scale,
        1 / self._canvas_scale * outside_scale,
        0.5 * w, 0.5 * h
    )

    -- draw inside
    love.graphics.setColor(1, 1, 1, self._a * opacity)
    love.graphics.draw(
        self._core_canvas:get_native(),
        self._player_x, self._player_y,
        0,
        1 / self._canvas_scale * 1,
        1 / self._canvas_scale * 1,
        0.5 * w, 0.5 * h
    )

    -- highlight
    local boost = _settings.highlight_brightness
    love.graphics.push()
    love.graphics.setColor(1, 1, 1, boost)
    --love.graphics.setColor(boost, boost, boost, 1 * opacity)
    --rt.graphics.set_blend_mode(rt.BlendMode.ADD)
    local offset = self._player_radius * 1 / 4
    local highlight_radius = rt.settings.player_body.highlight_radius

    love.graphics.translate(self._player_x, self._player_y)
    love.graphics.translate(-offset, -offset)
    self._highlight_mesh:draw()

    --love.graphics.setColor(boost / 2, boost / 2, boost / 2, 1 * opacity)
    love.graphics.translate(-highlight_radius / 4, -highlight_radius / 4)
    love.graphics.scale(0.5, 0.5)
    --self._highlight_mesh:draw()

    rt.graphics.set_blend_mode(nil)
    love.graphics.pop()

    if self._is_bubble then
        rt.graphics.set_stencil_mode(nil)
        rt.graphics.pop_stencil()
    else
        love.graphics.pop() -- squish
    end
end

--- @brief
function rt.PlayerBody:draw_bloom()
    if self._is_initialized ~= true then return end

    local w, h = self._body_canvas_a:get_size()
    love.graphics.setColor(self._r, self._g, self._b, self._a * self._player:get_opacity())
    love.graphics.draw(
        self._body_canvas_a:get_native(),
        self._player_x,
        self._player_y,
        0,
        1 / self._canvas_scale,
        1 / self._canvas_scale,
        0.5 * w,
        0.5 * h
    )
end

--- @brief
function rt.PlayerBody:set_relative_velocity(vx, vy)
    self._relative_velocity_x = vx
    self._relative_velocity_y = vy
end

--- @brief
function rt.PlayerBody:set_is_squished(b, nx, ny, contact_x, contact_y)
    self._is_squished = b
    self._squish_normal_x = nx
    self._squish_normal_y = ny
    self._squish_origin_x = contact_x
    self._squish_origin_y = contact_y

    if b == true then
        self._squish_motion:set_target_value(1)
    else
        self._squish_motion:set_target_value(0)
    end
end