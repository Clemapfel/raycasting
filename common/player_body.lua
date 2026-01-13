require "common.smoothed_motion_1d"

rt.settings.player_body = {
    relative_velocity_influence = 1 / 3, -- [0, 1] where 0 no influence

    -- user set params
    default_n_rings = 7,
    default_n_ropes_per_ring = 27,
    default_n_segments_per_rope = 8,
    default_rope_length_radius_factor = 7, -- * player radius

    -- static params
    node_mesh_alpha = 0.05,
    node_mesh_padding = 4,
    node_mesh_contour_radius = 1,
    contour_scale_offset = 10,
    non_contour_scale_offset = 6,
    node_mesh_radius_factor = 10 / 12.5,

    canvas_padding_radius_factor = 5,
    canvas_scale = 3,

    highlight_brightness = 0.4,
    highlight_radius = 8,
    outline_value_offset = 0.5,
    outline_width = 1.5,

    -- constraint solver params
    non_contour = {
        n_velocity_iterations = 4,
        n_distance_iterations = 8,
        n_axis_iterations = 0,
        axis_intensity = 0,
        n_bending_iterations = 0,
        velocity_damping = 1 - 0.15,
        inertia = 0.8,
        n_inverse_kinematics_iterations = 0,
        inverse_kinematics_intensity = 0
    },

    non_contour_performace = {
        n_velocity_iterations = 4,
        n_distance_iterations = 6,
        n_axis_iterations = 0,
        axis_intensity = 0,
        n_bending_iterations = 0,
        velocity_damping = 1 - 0.15,
        inertia = 0.8,
        n_inverse_kinematics_iterations = 0,
        inverse_kinematics_intensity = 0
    },

    contour = {
        n_velocity_iterations = 1,
        n_distance_iterations = 1,
        n_axis_iterations = 1,
        axis_intensity = 1,
        n_bending_iterations = 0,
        velocity_damping = 1 - 0.3,
        inertia = 0,
        n_inverse_kinematics_iterations = 3,
        inverse_kinematics_intensity = 0.1
    },

    contour_performance = {
        n_velocity_iterations = 1,
        n_distance_iterations = 1,
        n_axis_iterations = 1,
        axis_intensity = 1,
        n_bending_iterations = 0,
        velocity_damping = 1 - 0.3,
        inertia = 0,
        n_inverse_kinematics_iterations = 2,
        inverse_kinematics_intensity = 0.1
    },

    gravity = 2.5,

    squish_speed = 4, -- fraction
    squish_magnitude = 0.16, -- fraction

    max_stretch = 2,
}

--- @class rt.PlayerBody
rt.PlayerBody = meta.class("PlayerBody")

rt.PlayerBodyContourType = meta.enum("PlayerBodyContourType", {
    CIRCLE = "circle",
    SQUARE = "square",
    TRIANGLE = "triangle",
    TEAR_DROP = "tear_drop"
})

local _settings = rt.settings.player_body

local _threshold_shader = rt.Shader("common/player_body_outline.glsl", { MODE = 0})
local _outline_shader = rt.Shader("common/player_body_outline.glsl", { MODE = 1 })
local _core_shader = rt.Shader("common/player_body_core.glsl")

--- @brief
function rt.PlayerBody:instantiate(config)
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then _core_shader:recompile() end
    end)

    meta.assert(config, "Table")

    local necessary_keys = {
        radius = false,
        max_radius = false
    }

    for key, default in pairs({
        n_rings = _settings.default_n_rings,
        n_ropes_per_ring = _settings.default_n_ropes_per_ring,
        n_segments_per_rope = _settings.default_n_segments_per_rope,
        rope_length_radius_factor = _settings.default_rope_length_radius_factor,
        use_performance_mode = false
    }) do
        if config[key] == nil then config[key] = default end
    end

    for key, value in pairs(config) do
        if necessary_keys[key] ~= nil then necessary_keys[key] = true end

        if key == "radius" then
            self._radius = value
        elseif key == "max_radius" then
            self._max_radius = value
        elseif key == "n_rings" then
            self._n_rings = value
        elseif key == "n_ropes_per_ring" then
            self._n_ropes_per_ring = value
        elseif key == "n_segments_per_rope" then
            self._n_segments_per_rope = value
        elseif key == "rope_length_radius_factor" then
            self._rope_length_radius_factor = value
        elseif key == "use_performance_mode" then
            self._use_performance_mode = value
        else
            rt.error("In rt.PlayerBody: unrecognized key `", key, "`")
        end
    end

    for key, is_present in pairs(necessary_keys) do
        if is_present == false then
            rt.error("In rt.PlayerBody: key `", key, "` is not present in config")
        end
    end

    self._node_mesh_radius = _settings.node_mesh_radius_factor * self._radius
    self._core_vertices = {}
    self._ropes = {}
    self._n_ropes = 0
    self._is_contour = false
    self._position_x, self._position_y = 0, 0
    self._stencil_bodies = {}
    self._core_stencil_bodies = {}
    self._shader_elapsed = 0
    self._is_initialized = false
    self._queue_relax = false
    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, 0, 1))
    self._body_color = rt.Palette.BLACK
    self._core_color = rt.Palette.TRUE_WHITE
    self._saturation = 1
    self._opacity = 1
    self._hue = 0
    self._use_stencils = true
    self._stretch_factor = 1
    self._stretch_axis_x = 0
    self._stretch_axis_y = 0
    self._relative_velocity_x = 0
    self._relative_velocity_y = 0
    self._attraction_x = 0
    self._attraction_y = 0
    self._attraction_magnitude = 0

    self._core_canvas_needs_update = true
    self._body_canvas_needs_update = true

    self._down_squish = false
    self._down_squish_normal_x = nil
    self._down_squish_normal_y = nil
    self._down_squish_origin_x = nil
    self._down_squish_normal_y = nil
    self._down_squish_motion = rt.SmoothedMotion1D(1, _settings.squish_speed)

    self._left_squish = false
    self._left_squish_normal_x = nil
    self._left_squish_normal_y = nil
    self._left_squish_origin_x = nil
    self._left_squish_normal_y = nil
    self._left_squish_motion = rt.SmoothedMotion1D(1, _settings.squish_speed)

    self._right_squish = false
    self._right_squish_normal_x = nil
    self._right_squish_normal_y = nil
    self._right_squish_origin_x = nil
    self._right_squish_normal_y = nil
    self._right_squish_motion = rt.SmoothedMotion1D(1, _settings.squish_speed)

    self._up_squish = false
    self._up_squish_normal_x = nil
    self._up_squish_normal_y = nil
    self._up_squish_origin_x = nil
    self._up_squish_normal_y = nil
    self._up_squish_motion = rt.SmoothedMotion1D(1, _settings.squish_speed)

    -- init metaball ball mesh

    self._node_mesh = rt.MeshCircle(0, 0, self._node_mesh_radius)
    self._node_mesh:set_vertex_color(1, 1, 1, 1, 1)
    for i = 2, self._node_mesh:get_n_vertices() do
        self._node_mesh:set_vertex_color(i, 1, 1, 1, 0.0)
    end

    local canvas_w = 2 * self._node_mesh_radius + 2 * _settings.node_mesh_padding
    self._node_mesh_texture = rt.RenderTexture(canvas_w, canvas_w, 4)
    self._node_mesh_texture:bind()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._node_mesh:get_native(), 0.5 * canvas_w, 0.5 * canvas_w)
    self._node_mesh_texture:unbind()

    -- init canvases
    self._canvas_scale = _settings.canvas_scale

    do
        local padding = 60
        local r = self._radius * _settings.max_stretch
        local texture_size = self._canvas_scale * (r + 2 * padding)
        self._body_canvas_a = rt.RenderTexture(texture_size, texture_size, 4)
        self._body_canvas_b = rt.RenderTexture(texture_size, texture_size, 4)

        for canvas in range(self._body_canvas_a, self._body_canvas_b) do
            canvas:set_scale_mode(rt.TextureScaleMode.LINEAR)
        end
    end

    do
        local padding = self._radius
        local r = self._radius * _settings.max_stretch
        self._core_canvas = rt.RenderTexture( self._canvas_scale * (r + 2 * padding) , self._canvas_scale * (r + 2 * padding), 8)
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

    self:initialize()
end

--- @brief
function rt.PlayerBody:set_position(x, y)
    self._position_x, self._position_y = x, y
end

--- @brief
function rt.PlayerBody:set_use_performance_mode(b)
    self._use_performance_mode = b
end

--- @brief
function rt.PlayerBody:set_shape(positions)
    self._core_vertices = positions
    table.insert(self._core_vertices, self._core_vertices[1])
    table.insert(self._core_vertices, self._core_vertices[2])
end

--- @brief
function rt.PlayerBody:initialize()
    if self._is_initialized == true then return end

    local n_rings = self._n_rings
    local n_ropes_per_ring = self._n_ropes_per_ring

    local ring_to_ring_radius = function(ring_i)
        return ((ring_i - 1) / n_rings) * self._radius
    end

    local ring_to_n_ropes = function(ring_i)
        local t = ring_i / (n_rings + 1)
        local out = math.ceil(t * n_ropes_per_ring)
        if self._use_performance_mode then
            out = math.max(1, out - (ring_i - 1))
        end
        return out
    end

    local ring_to_n_segments_per_rope = function(ring_i)
        local base = self._n_segments_per_rope
        return base
    end

    local mass_easing = function(t)
        -- only last node affected by gravity
        return ternary(t == 1, 1, 0.25)
    end

    -- init ropes
    local max_rope_length = self._rope_length_radius_factor * self._radius
    local contour_rope_length = max_rope_length / self._n_segments_per_rope + self._node_mesh_radius
    self._contour_rope_length = max_rope_length - self._node_mesh_radius
    self._t_to_ropes = {}

    for ring_i = 1, n_rings do
        local ring_radius = ring_to_ring_radius(ring_i)
        local current_n_ropes = ring_to_n_ropes(ring_i)
        local angle_step = (2 * math.pi) / current_n_ropes
        for i = 1, current_n_ropes do
            local angle = (i - 1) * angle_step
            if ring_i % 2 == 1 then angle = angle + angle_step * 0.5 end
            local axis_x, axis_y = math.cos(angle), math.sin(angle)
            local center_x = axis_x * ring_radius
            local center_y = axis_y * ring_radius
            local scale = ring_i / (n_rings)

            local rope_length = (1 - scale) * max_rope_length
            local n_segments = ring_to_n_segments_per_rope(ring_i)

            local rope = {
                current_positions = {},
                last_positions = {},
                last_velocities = {},
                masses = {},
                anchor_x = center_x, -- anchor of first node
                anchor_y = center_y,
                target_x = 0, -- inverse kinematics target
                target_y = 0,
                axis_x = axis_x, -- axis constraint
                axis_y = axis_y,
                scale = scale, -- metaball scale
                length = rope_length, -- total rope length
                n_segments = n_segments,
                segment_length = rope_length / n_segments,
                contour_segment_length = contour_rope_length / n_segments,
                contour_length = contour_rope_length
            }

            center_x = center_x + self._position_x
            center_y = center_y + self._position_y
            local dx, dy = math.normalize(rope.anchor_x - self._position_x, rope.anchor_y - self._position_y)

            rope.target_x = rope.anchor_x + (rope.contour_length) * rope.axis_x
            rope.target_y = rope.anchor_y + (rope.contour_length) * rope.axis_y

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

            local entry = self._t_to_ropes[angle]
            if entry == nil then
                entry = meta.make_weak({})
                self._t_to_ropes[angle] = entry
            end
            table.insert(entry, rope)

            self._n_ropes = self._n_ropes + 1
        end
    end

    self._use_contour = false
    self:_update_contour()

    self._is_initialized = true
    if self._queue_relax == true then
        self:relax()
    end
end

function rt.PlayerBody:relax()
    if not self._is_initialized then
        self._queue_relax = true
        return
    end

    -- release all rope forces
    local px, py = self._position_x, self._position_y
    for rope in values(self._ropes) do
        local dx, dy = rope.axis_x, rope.axis_y
        local x, y = px + rope.anchor_x, py + rope.anchor_y

        for i = 0, rope.n_segments - 1 do
            local step = ternary(self._is_contour, rope.segment_length, rope.contour_segment_length)
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

--- @brief
function rt.PlayerBody:_update_contour()
    local n_samples = #self._t_to_ropes
    local center_x, center_y = 0, 0
    local callback = function(angle, radius)
        return math.cos(angle) * radius, math.sin(angle) * radius
    end

    local max_r = -math.huge
    for t, ropes in pairs(self._t_to_ropes) do
        for rope in values(ropes) do
            local x, y = callback(t, rope.contour_length)
            rope.target_x = rope.anchor_x + x
            rope.target_y = rope.anchor_y + y
            max_r = math.max(max_r, math.magnitude(rope.target_x, rope.target_y))
        end
    end

    self._contour_vertices = {}
    local max_length = max_r + self._node_mesh_radius * 0.5

    local n = #self._ropes
    for i = 1, n do
        local angle = (i - 1) / n * 2 * math.pi
        local x, y = callback(angle, max_length)
        table.insert(self._contour_vertices, x)
        table.insert(self._contour_vertices, y)
    end
end

rt.PlayerBody._solve_distance_constraint = function(a_x, a_y, b_x, b_y, mass_a, mass_b, rest_length)
    local current_distance = math.max(1, math.distance(a_x, a_y, b_x, b_y))

    local delta_x = b_x - a_x
    local delta_y = b_y - a_y

    local distance_correction = (current_distance - rest_length) / current_distance
    local correction_x = delta_x * distance_correction
    local correction_y = delta_y * distance_correction

    local total_mass = mass_a + mass_b
    local blend_a = mass_b / total_mass
    local blend_b = mass_a / total_mass

    a_x = a_x + correction_x * blend_a
    a_y = a_y + correction_y * blend_a
    b_x = b_x - correction_x * blend_b
    b_y = b_y - correction_y * blend_b

    return a_x, a_y, b_x, b_y
end

rt.PlayerBody._solve_axis_constraint = function(
    a_x, a_y, b_x, b_y,
    axis_x, axis_y,
    mass_a, mass_b,
    intensity
)
    if intensity == nil then intensity = 1 end

    local delta_x = b_x - a_x
    local delta_y = b_y - a_y

    local dot_product = math.abs(delta_x * axis_x + delta_y * axis_y)
    local projection_x = dot_product * axis_x
    local projection_y = dot_product * axis_y

    local correction_x = (projection_x - delta_x)
    local correction_y = (projection_y - delta_y)

    local total_mass = mass_a + mass_b
    local blend_a = math.mix(0, mass_b / total_mass, intensity)
    local blend_b = math.mix(0, mass_a / total_mass, intensity)

    a_x = a_x - correction_x * blend_a
    a_y = a_y - correction_y * blend_a
    b_x = b_x + correction_x * blend_b
    b_y = b_y + correction_y * blend_b

    return a_x, a_y, b_x, b_y
end

rt.PlayerBody._solve_bending_constraint = function(
    a_x, a_y, b_x, b_y, c_x, c_y,
    mass_a, mass_b, mass_c,
    stiffness
)
    local ab_x = b_x - a_x
    local ab_y = b_y - a_y
    local bc_x = c_x - b_x
    local bc_y = c_y - b_y

    ab_x, ab_y = math.normalize(ab_x, ab_y)
    bc_x, bc_y = math.normalize(bc_x, bc_y)

    local target_x = ab_x + bc_x
    local target_y = ab_y + bc_y

    local correction_x = target_x * stiffness
    local correction_y = target_y * stiffness

    local inv_mass_a = 1 / mass_a
    local inv_mass_c = 1 / mass_c
    local inv_mass_sum = inv_mass_a + inv_mass_c

    local blend_a = (inv_mass_a / inv_mass_sum) * 0.5
    local blend_c = (inv_mass_c / inv_mass_sum) * 0.5

    a_x = a_x - correction_x * blend_a
    a_y = a_y - correction_y * blend_a
    c_x = c_x + correction_x * blend_c
    c_y = c_y + correction_y * blend_c

    return a_x, a_y, c_x, c_y
end

rt.PlayerBody._solve_inverse_kinematics_constraint = function(positions, base_x, base_y, target_x, target_y, segment_length, intensity, max_iterations)
    if target_x == nil or target_y == nil then return end

    intensity = math.clamp(intensity or 1, 0, 1)
    max_iterations = max_iterations or 3

    local n_nodes = math.floor(#positions / 2)
    if n_nodes < 2 or intensity <= 0 then
        -- Ensure base is anchored
        if n_nodes >= 1 then
            positions[1], positions[2] = base_x, base_y
        end
        return
    end

    -- Copy current chain; enforce base at [1]
    local px, py = {}, {}
    px[1], py[1] = base_x, base_y
    for i = 2, n_nodes do
        local xi = (i - 1) * 2 + 1
        px[i], py[i] = positions[xi], positions[xi + 1]
    end

    local total_length = segment_length * (n_nodes - 1)
    local dist_to_target = math.distance(base_x, base_y, target_x, target_y)
    local tolerance = segment_length * 0.01  -- 1% of segment length
    local length_eps = 1e-10

    local converged

    if dist_to_target >= total_length - tolerance then
        -- Target unreachable: stretch directly towards target
        local dir_x, dir_y = target_x - base_x, target_y - base_y
        local len = math.sqrt(dir_x * dir_x + dir_y * dir_y)

        if len > 1e-10 then
            dir_x, dir_y = dir_x / len, dir_y / len
            for i = 1, n_nodes do
                px[i] = base_x + dir_x * segment_length * (i - 1)
                py[i] = base_y + dir_y * segment_length * (i - 1)
            end
        else
            -- Degenerate case: maintain current orientation
            local prev_dx = px[2] - px[1]
            local prev_dy = py[2] - py[1]
            local prev_len = math.magnitude(prev_dx, prev_dy)

            if prev_len > length_eps then
                dir_x, dir_y = prev_dx / prev_len, prev_dy / prev_len
                for i = 1, n_nodes do
                    px[i] = base_x + dir_x * segment_length * (i - 1)
                    py[i] = base_y + dir_y * segment_length * (i - 1)
                end
            end
        end
    else
        -- target reachable: iterative FABRIK step
        -- forward reaching: start from target
        px[n_nodes], py[n_nodes] = target_x, target_y
        for i = n_nodes - 1, 1, -1 do
            local dx = px[i] - px[i + 1]
            local dy = py[i] - py[i + 1]
            local len = math.magnitude(dx, dy)

            if len > length_eps then
                local scale = segment_length / len
                px[i] = px[i + 1] + dx * scale
                py[i] = py[i + 1] + dy * scale
            end
        end

        -- backward reaching: restore base position
        px[1], py[1] = base_x, base_y
        for i = 1, n_nodes - 1 do
            local dx = px[i + 1] - px[i]
            local dy = py[i + 1] - py[i]
            local len = math.magnitude(dx, dy)

            if len > length_eps then
                local scale = segment_length / len
                px[i + 1] = px[i] + dx * scale
                py[i + 1] = py[i] + dy * scale
            end
        end

        -- Check convergence
        local end_dist = math.distance(px[n_nodes], py[n_nodes], target_x, target_y)
        if end_dist < tolerance then
            converged = true
        end
    end

    -- Blend IK solution with intensity
    positions[1], positions[2] = base_x, base_y
    for i = 2, n_nodes do
        local xi = (i - 1) * 2 + 1
        positions[xi]     = math.mix(positions[xi],     px[i], intensity)
        positions[xi + 1] = math.mix(positions[xi + 1], py[i], intensity)
    end

    return converged
end

rt.PlayerBody.update_rope = function(data)
    if data.use_contour == nil then data.use_contour = false end
    local use_contour = data.use_contour

    local contour_segment_length = data.contour_segment_length or data.segment_length or 1
    local segment_length = ternary(data.use_contour, contour_segment_length, data.segment_length or 1)

    local n_velocity_iterations = data.n_velocity_iterations or 0
    local n_distance_iterations = data.n_distance_iterations or 0
    local n_axis_iterations = data.n_axis_iterations or 0
    local n_bending_iterations = data.n_bending_iterations or 0
    local n_inverse_kinematics_iterations = data.n_inverse_kinematics_iterations or 0
    local axis_intensity = data.axis_intensity or 1
    local inverse_kinematics_intensity = data.inverse_kinematics_intensity or 1

    local inertia = data.inertia or 1
    local gravity_x = data.gravity_x or 0
    local gravity_y = data.gravity_y or rt.settings.player_body.gravity
    local attraction_x = data.attraction_x or 0
    local attraction_y = data.attraction_y or 0
    local attraction_magnitude = data.attraction_magnitude or 0
    local velocity_damping = data.velocity_damping or rt.settings.player_body.non_contour.velocity_damping
    local platform_delta_x = data.platform_delta_x or 0
    local platform_delta_y = data.platform_delta_y or 0

    local anchor_x = data.anchor_x or 0
    local anchor_y = data.anchor_y or 0
    local axis_x = data.axis_x or 0
    local axis_y = data.axis_y or 0
    local target_x = data.target_x or data.position_x
    local target_y = data.target_y or data.position_y

    meta.assert(
        data.delta, "Number",
        data.current_positions, "Table",
        data.last_positions, "Table",
        data.last_velocities, "Table",
        data.masses, "Table",
        data.position_x, "Number",
        data.position_y, "Number"
    )

    local delta = data.delta
    local position_x = data.position_x
    local position_y = data.position_y
    local positions = data.current_positions
    local last_positions = data.last_positions
    local last_velocities = data.last_velocities
    local masses = data.masses

    do -- translate whole physics system into relative velocity
        local t = 1 - math.clamp(rt.settings.player_body.relative_velocity_influence, 0, 1)
        for i = 1, #positions, 2 do
            positions[i] = positions[i] + platform_delta_x * t
            positions[i+1] = positions[i+1] + platform_delta_y * t
            last_positions[i] = last_positions[i] + platform_delta_x * t
            last_positions[i+1] = last_positions[i+1] + platform_delta_y * t
        end
    end

    local n_axis_iterations_done = 0
    local n_distance_iterations_done = 0
    local n_velocity_iterations_done = 0
    local n_bending_iterations_done = 0
    local n_inverse_kinematics_iterations_done = 0

    n_distance_iterations = n_distance_iterations + n_bending_iterations

    local rope_changed = false

    while
        (n_velocity_iterations_done < n_velocity_iterations)
        or (n_distance_iterations_done < n_distance_iterations)
        or (n_axis_iterations_done < n_axis_iterations)
        or (n_bending_iterations_done < n_bending_iterations)
        or (n_inverse_kinematics_iterations_done < n_inverse_kinematics_iterations)
    do
        -- verlet integration
        if n_velocity_iterations_done < n_velocity_iterations then
            local mass_i = 1
            for i = 1, #positions, 2 do
                local current_x, current_y = positions[i+0], positions[i+1]
                if i == 1 then
                    current_x = position_x + anchor_x
                    current_y = position_y + anchor_y
                end

                local old_x, old_y = last_positions[i+0], last_positions[i+1]
                local mass = masses[mass_i]
                local before_x, before_y = current_x, current_y

                local velocity_x = (current_x - old_x) * velocity_damping
                local velocity_y = (current_y - old_y) * velocity_damping

                velocity_x = math.mix(velocity_x, last_velocities[i+0], inertia)
                velocity_y = math.mix(velocity_y, last_velocities[i+1], inertia)

                local attraction_dx, attraction_dy = 0, 0
                if attraction_magnitude > 0 then
                    local dx, dy = math.normalize(attraction_x - current_x, attraction_y - current_y)
                    attraction_dx, attraction_dy = dx * attraction_magnitude, dy * attraction_magnitude
                end

                -- sic: mass * gravity is intended
                local delta_x = velocity_x + mass * gravity_x * delta + attraction_dx * mass
                local delta_y = velocity_y + mass * gravity_y * delta + attraction_dy * mass

                positions[i+0] = current_x + delta_x
                positions[i+1] = current_y + delta_y

                if math.magnitude(delta_x, delta_y) > 1 then rope_changed = true end

                last_positions[i+0] = before_x
                last_positions[i+1] = before_y

                last_velocities[i+0] = velocity_x
                last_velocities[i+1] = velocity_y

                mass_i = mass_i + 1
            end

            n_velocity_iterations_done = n_velocity_iterations_done + 1
        end

        -- axis
        if n_axis_iterations_done < n_axis_iterations then
            local mass_i = 1
            for i = 1, #positions - 2, 2 do
                local node_1_xi, node_1_yi, node_2_xi, node_2_yi = i+0, i+1, i+2, i+3
                local node_1_x, node_1_y = positions[node_1_xi], positions[node_1_yi]
                local node_2_x, node_2_y = positions[node_2_xi], positions[node_2_yi]

                local new_x1, new_y1, new_x2, new_y2 = rt.PlayerBody._solve_axis_constraint(
                    node_1_x, node_1_y,
                    node_2_x, node_2_y,
                    axis_x, axis_y,
                    masses[mass_i + 0], masses[mass_i + 1],
                    axis_intensity
                )

                positions[node_1_xi] = new_x1
                positions[node_1_yi] = new_y1
                positions[node_2_xi] = new_x2
                positions[node_2_yi] = new_y2

                mass_i = mass_i + 1
            end

            n_axis_iterations_done = n_axis_iterations_done + 1
        end

        -- bending
        if n_bending_iterations_done < n_bending_iterations then
            local mass_i = 1
            for i = 1, #positions - 4, 2 do
                local node_1_xi, node_1_yi, node_2_xi, node_2_yi, node_3_xi, node_3_yi = i+0, i+1, i+2, i+3, i+4, i+5
                local node_1_x, node_1_y = positions[node_1_xi], positions[node_1_yi]
                local node_2_x, node_2_y = positions[node_2_xi], positions[node_2_yi]
                local node_3_x, node_3_y = positions[node_3_xi], positions[node_3_yi]

                local new_x1, new_y1, new_x3, new_y3 = rt.PlayerBody._solve_bending_constraint(
                    node_1_x, node_1_y,
                    node_2_x, node_2_y,
                    node_3_x, node_3_y,
                    masses[mass_i + 0], masses[mass_i + 1], masses[mass_i + 2],
                    (1 - (i - 1) / (#positions / 2)) -- more bendy the farther away from base
                )

                positions[node_1_xi] = new_x1
                positions[node_1_yi] = new_y1

                positions[node_3_xi] = new_x3
                positions[node_3_yi] = new_y3

                mass_i = mass_i + 1
            end

            n_bending_iterations_done = n_bending_iterations_done + 1
        end

        -- inverse kinematics
        if n_inverse_kinematics_iterations_done < n_inverse_kinematics_iterations then
            local base_x = position_x + anchor_x
            local base_y = position_y + anchor_y
            local final_target_x = position_x + target_x
            local final_target_y = position_y + target_y
            local converged = rt.PlayerBody._solve_inverse_kinematics_constraint(
                positions,
                base_x, base_y,
                final_target_x, final_target_y,
                contour_segment_length or segment_length,
                inverse_kinematics_intensity
            )
            n_inverse_kinematics_iterations_done = n_inverse_kinematics_iterations_done + 1
            if converged then n_inverse_kinematics_iterations_done = math.huge end
        end

        -- distance
        if n_distance_iterations_done < n_distance_iterations then
            local distance_i = 1
            local mass_i = 1
            for i = 1, #positions - 2, 2 do
                local node_1_xi, node_1_yi, node_2_xi, node_2_yi = i+0, i+1, i+2, i+3
                local node_1_x, node_1_y = positions[node_1_xi], positions[node_1_yi]
                local node_2_x, node_2_y = positions[node_2_xi], positions[node_2_yi]

                if i == 1 then
                    node_1_x = position_x + anchor_x
                    node_1_y = position_y + anchor_y
                end

                local rest_length = segment_length

                local new_x1, new_y1, new_x2, new_y2 = rt.PlayerBody._solve_distance_constraint(
                    node_1_x, node_1_y,
                    node_2_x, node_2_y,
                    masses[mass_i+0], masses[mass_i+1],
                    rest_length
                )

                positions[node_1_xi] = new_x1
                positions[node_1_yi] = new_y1
                positions[node_2_xi] = new_x2
                positions[node_2_yi] = new_y2

                distance_i = distance_i + 1
                mass_i = mass_i + 1
            end

            n_distance_iterations_done = n_distance_iterations_done + 1
        end
    end

    return rope_changed
end

--- @brief
function rt.PlayerBody:set_color(color)
    meta.assert(color, "RGBA")
    self._color = color
    self._hue = select(3, rt.rgba_to_lcha(self._color:unpack()))
end

--- @brief
function rt.PlayerBody:set_body_color(color)
    meta.assert(color, "RGBA")
    self._body_color = color
end

--- @brief
function rt.PlayerBody:set_core_color(color)
    meta.assert(color, "RGBA")
    self._core_color = color
end

--- @brief
function rt.PlayerBody:set_opacity(opacity)
    meta.assert(opacity, "Number")
    self._opacity = opacity
end

--- @brief
function rt.PlayerBody:set_world(physics_world)
    if physics_world ~= nil then
        meta.assert(physics_world, b2.World)
    end
    self._world = physics_world
end

--- @brief
function rt.PlayerBody:set_use_contour(b)
    meta.assert(b, "Boolean")
    if self._use_contour == b then return end

    self._use_contour = b
    self:_update_contour()
end

--- @brief
function rt.PlayerBody:update(delta)

    -- non rope sim updates
    self._shader_elapsed = self._shader_elapsed + delta
    if not self._use_performance_mode then
        for squish in range(
            self._down_squish_motion,
            self._left_squish_motion,
            self._right_squish_motion,
            self._up_squish_motion
        ) do
            squish:update(delta)
        end
    end

    if self._world ~= nil then
        self._stencil_bodies = {}
        self._core_stencil_bodies = {}

        if self._use_stencils then
            local w = self._contour_rope_length
            local h = w

            local settings = rt.settings.player
            local mask = bit.bnot(0x0)
            mask = bit.band(mask, bit.bnot(settings.player_outer_body_collision_group))
            mask = bit.band(mask, bit.bnot(settings.player_collision_group))
            mask = bit.band(mask, bit.bnot(settings.bounce_collision_group))

            local bodies = self._world:query_aabb(
                self._position_x - 0.5 * w, self._position_y - 0.5 * h, w, h,
                mask
            )

            for body in values(bodies) do
                if body:has_tag("stencil") and not body:get_is_sensor() then
                    table.insert(self._stencil_bodies, body)
                end

                if body:has_tag("core_stencil") and not body:get_is_sensor() then
                    table.insert(self._core_stencil_bodies, body)
                end
            end
        end
    end

    -- rope sim
    local gravity_x, gravity_y
    if self._use_contour then
        gravity_x, gravity_y = 0, 0
    else
        gravity_x, gravity_y = self._gravity_x or 0, self._gravity_y or 1 * _settings.gravity
    end

    local todo
    if self._use_performance_mode or rt.GameState:get_is_performance_mode_enabled() then
        todo = self._use_contour and _settings.contour_performance or _settings.non_contour_performace
    else
        todo = self._use_contour and _settings.contour or _settings.non_contour
    end

    if self._use_performance_mode
        and self._use_contour
    then
        -- noop, use polygon instead of rope nodes for ow.NPC
    else
        for i, rope in ipairs(self._ropes) do
            rt.PlayerBody.update_rope({
                current_positions = rope.current_positions,
                last_positions = rope.last_positions,
                last_velocities = rope.last_velocities,
                masses = rope.masses,
                position_x = self._position_x,
                position_y = self._position_y,
                target_x = rope.target_x,
                target_y = rope.target_y,
                anchor_x = rope.anchor_x,
                anchor_y = rope.anchor_y,
                axis_x = rope.axis_x,
                axis_y = rope.axis_y,
                delta = delta,
                segment_length = rope.segment_length,
                contour_segment_length = rope.contour_segment_length,
                use_contour = self._use_contour,
                n_velocity_iterations = todo.n_velocity_iterations,
                n_distance_iterations = todo.n_distance_iterations,
                n_axis_iterations = todo.n_axis_iterations,
                axis_intensity = todo.axis_intensity,
                n_bending_iterations = todo.n_bending_iterations,
                inertia = todo.inertia,
                velocity_damping = todo.velocity_damping,
                gravity_x = gravity_x,
                gravity_y = gravity_y * (1 + self._down_squish_motion:get_value()),
                attraction_x = self._attraction_x,
                attraction_y = self._attraction_y,
                attraction_magnitude = self._attraction_magnitude,
                platform_delta_x = self._relative_velocity_x * delta,
                platform_delta_y = self._relative_velocity_y * delta,
                n_inverse_kinematics_iterations = todo.n_inverse_kinematics_iterations,
                inverse_kinematics_intensity = todo.inverse_kinematics_intensity
            })
        end
    end

    self._core_canvas_needs_update = true
    self._body_canvas_needs_update = true
end

--- @brief
function rt.PlayerBody:_apply_squish(factor)
    if self._use_performance_mode then return end

    local magnitude = _settings.squish_magnitude * (factor or 1)
    local function apply(is_enabled, motion, nx, ny, ox, oy, default_nx, default_ny, default_ox, default_oy)
        if motion ~= nil and motion:get_value() < 0 then return end
        if motion == nil or motion.get_value == nil then return end

        local amount = motion:get_value()

        local squish_nx = (nx ~= nil) and nx or default_nx
        local squish_ny = (ny ~= nil) and ny or default_ny
        local origin_x = (ox ~= nil) and ox or default_ox
        local origin_y = (oy ~= nil) and oy or default_oy

        local angle = math.angle(squish_nx or 0, squish_ny or -1)

        love.graphics.translate(origin_x, origin_y)
        love.graphics.rotate(angle)
        love.graphics.scale(1 - amount * magnitude, 1)
        love.graphics.rotate(-angle)
        love.graphics.translate(-origin_x, -origin_y)
    end

    apply(
        self._down_squish,
        self._down_squish_motion,
        self._down_squish_normal_x, self._down_squish_normal_y,
        self._down_squish_origin_x, self._down_squish_origin_y,
        0, -1,
        self._position_x, self._position_y + 0.5 * self._radius
    )

    apply(
        self._left_squish,
        self._left_squish_motion,
        self._left_squish_normal_x, self._left_squish_normal_y,
        self._left_squish_origin_x, self._left_squish_origin_y,
        1, 0,
        self._position_x - 0.5 * self._radius, self._position_y
    )

    apply(
        self._right_squish,
        self._right_squish_motion,
        self._right_squish_normal_x, self._right_squish_normal_y,
        self._right_squish_origin_x, self._right_squish_origin_y,
        -1, 0,
        self._position_x + 0.5 * self._radius, self._position_y
    )

    apply(
        self._up_squish_squish,
        self._up_squish_squish_motion,
        self._up_squish_squish_normal_x, self._up_squish_squish_normal_y,
        self._up_squish_squish_origin_x, self._up_squish_squish_origin_y,
        0, 1,
        self._position_x, self._position_y - 0.5 * self._radius
    )
end

--- @brief
function rt.PlayerBody:draw_body()
    if self._is_initialized ~= true then return end

    local w, h = self._body_canvas_a:get_size()

    if self._body_canvas_needs_update then
        self._body_canvas_needs_update = false
        love.graphics.push("all")
        love.graphics.reset()

        love.graphics.translate(0.5 * w, 0.5 * h)
        love.graphics.scale(self._canvas_scale, self._canvas_scale)
        love.graphics.translate(-0.5 * w, -0.5 * h)
        love.graphics.translate(-self._position_x + 0.5 * w, -self._position_y + 0.5 * h)

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
        if self._use_contour then
            love.graphics.setColor(1, 1, 1, 1)
        else
            love.graphics.setColor(1, 1, 1, _settings.node_mesh_alpha)
        end

        if not (self._use_performance_mode and self._use_contour) then
            -- function to thin out only very last part of tail
            local easing = function(t)
                -- f\left(x\right)=\left(0.045\cdot e^{\ln\left(\frac{1}{0.045}+1\right)x}-0.045\right)^{b}
                local buldge = 4--2.5 -- the higher, the closer to f(x) = x easing
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
                    local scale = easing(segment_i / rope.n_segments) * math.min(1, rope.scale + _settings.non_contour_scale_offset / self._radius)
                    -- Use current_positions for drawing to reduce visual lag
                    local x, y = rope.current_positions[i+0], rope.current_positions[i+1]
                    love.graphics.draw(self._node_mesh_texture:get_native(), x, y, 0, scale, scale, 0.5 * tw, 0.5 * th)

                    love.graphics.pop()

                    segment_i = segment_i + 1
                end
            end
        end

        if self._use_contour then
            if self._use_performance_mode then
                love.graphics.push()
                love.graphics.translate(self._position_x, self._position_y)
                love.graphics.polygon("fill", self._contour_vertices)
                love.graphics.pop()
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

    love.graphics.push("all")
    love.graphics.setBlendMode("alpha", "premultiplied")

    do
        love.graphics.setShader(nil)
        local r, g, b, a = self._body_color:unpack()
        love.graphics.setColor(r * self._opacity, g * self._opacity, b * self._opacity, a * self._opacity)
        love.graphics.draw(
            self._body_canvas_b:get_native(),
            self._position_x,
            self._position_y,
            0,
            1 / self._canvas_scale,
            1 / self._canvas_scale,
            0.5 * w,
            0.5 * h
        )
    end

    do
        local r, g, b, a = self._color:unpack()
        love.graphics.setColor(r * self._opacity, g * self._opacity, b * self._opacity, a * self._opacity)
        love.graphics.draw(
            self._body_canvas_a:get_native(),
            self._position_x,
            self._position_y,
            0,
            1 / self._canvas_scale,
            1 / self._canvas_scale,
            0.5 * w,
            0.5 * h
        )
    end

    love.graphics.pop()
end

--- @brief
function rt.PlayerBody:draw_core()
    if self._is_initialized ~= true or #self._core_vertices < 6 then return end

    local opacity = self._color.a * self._opacity
    local w, h = self._core_canvas:get_size()

    if self._core_canvas_needs_update then
        self._core_canvas_needs_update = false
        -- core canvas for shader inlay
        self._core_canvas:bind()
        love.graphics.clear()

        love.graphics.push("all")
        love.graphics.setStencilMode(nil)
        rt.graphics.set_blend_mode(nil)
        love.graphics.origin()

        love.graphics.translate(0.5 * w, 0.5 * h)
        love.graphics.scale(self._canvas_scale)
        love.graphics.translate(-0.5 * w, -0.5 * h)
        love.graphics.translate(-self._position_x + 0.5 * w, -self._position_y + 0.5 * h)

        self._core_color:bind()
        _core_shader:bind()
        _core_shader:send("hue", self._hue)
        _core_shader:send("elapsed", self._shader_elapsed)
        _core_shader:send("saturation", self._saturation)
        if self._use_contour then
            love.graphics.circle("fill", self._position_x, self._position_y, self._radius)
        else
            love.graphics.push()
            love.graphics.translate(self._position_x, self._position_y)
            love.graphics.polygon("fill", self._core_vertices)
            love.graphics.pop()
        end
        _core_shader:unbind()

        love.graphics.pop()
        self._core_canvas:unbind()
    end

    local outline_width = _settings.outline_width
    local outside_scale = 1 + outline_width / self._radius

    rt.graphics.push_stencil()
    local stencil_value = rt.graphics.get_stencil_value()
    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW)
    for body in values(self._core_stencil_bodies) do
        body:draw(true)
    end
    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST, rt.StencilCompareMode.NOT_EQUAL)

    love.graphics.push()
    self:_apply_squish()

    -- draw outline
    local darken = _settings.outline_value_offset
    love.graphics.setColor(1 - darken, 1 - darken, 1 - darken, opacity)
    love.graphics.draw(
        self._core_canvas:get_native(),
        self._position_x, self._position_y,
        0,
        1 / self._canvas_scale * outside_scale,
        1 / self._canvas_scale * outside_scale,
        0.5 * w, 0.5 * h
    )

    -- draw inside
    love.graphics.setColor(1, 1, 1, opacity)
    love.graphics.draw(
        self._core_canvas:get_native(),
        self._position_x, self._position_y,
        0,
        1 / self._canvas_scale * 1,
        1 / self._canvas_scale * 1,
        0.5 * w, 0.5 * h
    )

    -- highlight
    love.graphics.push()
    love.graphics.setColor(1, 1, 1, _settings.highlight_brightness * opacity)
    local offset = self._radius * 1 / 4

    love.graphics.translate(self._position_x, self._position_y)
    love.graphics.translate(-offset, -offset)
    self._highlight_mesh:draw()

    rt.graphics.set_blend_mode(nil)
    love.graphics.pop()

    love.graphics.pop() -- squish
end

--- @brief
function rt.PlayerBody:draw_bloom()
    if self._is_initialized ~= true then return end

    local w, h = self._body_canvas_a:get_size()
    love.graphics.setColor(self._color:unpack())
    love.graphics.draw(
        self._body_canvas_a:get_native(),
        self._position_x,
        self._position_y,
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
function rt.PlayerBody:set_down_squish(b, nx, ny, contact_x, contact_y)
    self._down_squish = b
    self._down_squish_normal_x = nx or self._down_squish_normal_x
    self._down_squish_normal_y = ny or self._down_squish_normal_y
    self._down_squish_origin_x = contact_x or self._down_squish_origin_x
    self._down_squish_origin_y = contact_y or self._down_squish_origin_y

    if b == true then
        self._down_squish_motion:set_target_value(1)
    else
        self._down_squish_motion:set_target_value(0)
    end
end

--- @brief
function rt.PlayerBody:set_left_squish(b, nx, ny, contact_x, contact_y)
    self._left_squish = b
    self._left_squish_normal_x = nx or self._left_squish_normal_x
    self._left_squish_normal_y = ny or self._left_squish_normal_y
    self._left_squish_origin_x = contact_x or self._left_squish_origin_x
    self._left_squish_origin_y = contact_y or self._left_squish_origin_y

    if b == true then
        self._left_squish_motion:set_target_value(1)
    else
        self._left_squish_motion:set_target_value(0)
    end
end

--- @brief
function rt.PlayerBody:set_right_squish(b, nx, ny, contact_x, contact_y)
    self._right_squish = b
    self._right_squish_normal_x = nx or self._right_squish_normal_x
    self._right_squish_normal_y = ny or self._right_squish_normal_y
    self._right_squish_origin_x = contact_x or self._right_squish_origin_x
    self._right_squish_origin_y = contact_y or self._right_squish_origin_y

    if b == true then
        self._right_squish_motion:set_target_value(1)
    else
        self._right_squish_motion:set_target_value(0)
    end
end

--- @brief
function rt.PlayerBody:set_up_squish(b, nx, ny, contact_x, contact_y)
    self._up_squish = b
    self._up_squish_normal_x = nx or self._up_squish_normal_x
    self._up_squish_normal_y = ny or self._up_squish_normal_y
    self._up_squish_origin_x = contact_x or self._up_squish_origin_x
    self._up_squish_origin_y = contact_y or self._up_squish_origin_y

    if b == true then
        self._up_squish_motion:set_target_value(1)
    else
        self._up_squish_motion:set_target_value(0)
    end
end

--- @brief
function rt.PlayerBody:set_gravity(gravity_x, gravity_y)
    self._gravity_x, self._gravity_y = gravity_x, gravity_y -- can be nil
end

--- @brief
function rt.PlayerBody:set_stretch_factor(t, axis_x, axis_y)
    meta.assert(t, "Number", axis_x, "Number", axis_y, "Number")
    self._stretch_factor = math.clamp(t, 0, 1)
    self._stretch_axis_x = axis_x
    self._stretch_axis_y = axis_y
end

--- @brief
function rt.PlayerBody:set_saturation(t)
    self._saturation = t
end

--- @brief
function rt.PlayerBody:get_saturation()
    return self._saturation
end

--- @brief
function rt.PlayerBody:set_attraction(x, y, magnitude)
    self._attraction_x, self._attraction_y, self._attraction_magnitude = x, y, magnitude
end

--- @brief
function rt.PlayerBody:get_attraction()
    return self._attraction_x, self._attraction_y, self._attraction_magnitude
end

--- @brief
function rt.PlayerBody:set_use_stencils(b)
    self._use_stencils = b
end