require "common.smoothed_motion_1d"

rt.settings.player_body = {
    canvas_scale = 3,
    outline_darkening = 0.5,

    particle_radius = 2
}

--- @class rt.PlayerBody
rt.PlayerBody = meta.class("PlayerBody")

--- @brief
function rt.PlayerBody:instantiate(position_x, position_y)
    meta.assert(position_x, "Number", position_y, "Number")
    self._position_x = position_x
    self._position_y = position_y

    self._core_vertices = nil
    self._core_color = rt.Palette.WHITE
    self._body_color = rt.Palette.BLACK

    self._use_contour = true

    self:_initialize()
end

local _x_offset = 0
local _y_offset = 1
local _velocity_x_offset = 2
local _velocity_y_offset = 3
local _previous_x_offset = 4 -- last sub step
local _previous_y_offset = 5
local _radius_offset = 6 -- radius, px
local _mass_offset = 7
local _inverse_mass_offset = 8
local _segment_length_offset = 9
local _contour_segment_length_offset = 10
local _last_step_x_offset = 11 -- last sim step
local _last_step_y_offset = 12

local _stride = _last_step_y_offset + 1
local _particle_i_to_data_offset = function(particle_i)
    return (particle_i - 1) * _stride + 1 -- 1-based
end

local _particle_texture_shader = rt.Shader("common/player_body_particle_texture.glsl")
local _instance_draw_shader = rt.Shader("common/player_body_instanced_draw.glsl")

--- @brief
function rt.PlayerBody:_initialize()
    local settings = rt.settings.player_body

    self._particle_data = {}
    self._ropes = {}

    local body_radius = rt.settings.player.radius
    local max_rope_length = 4 * body_radius

    local particle_texture_radius = rt.settings.player.radius * settings.particle_radius
    self._particle_texture_radius = particle_texture_radius

    local texture_scale = 1
    self._texture_scale = texture_scale

    do -- particle texture
        local w = (particle_texture_radius + 2) * 2
        local h = w
        self._particle_texture = rt.RenderTexture(w, h)

        -- fill particle with density data using shader
        love.graphics.push("all")
        love.graphics.reset()
        self._particle_texture:bind()
        _particle_texture_shader:bind()

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill",
            0, 0, w, h
        )

        _particle_texture_shader:unbind()
        self._particle_texture:unbind()
        love.graphics.pop()
    end

    do -- particles
        local particle_n = 1
        local add_rope = function(
            n_particles,
            length, contour_length,
            anchor_x, anchor_y,
            dx, dy
        )
            local rope = {
                anchor_x = anchor_x,
                anchor_y = anchor_y,

                axis_x = dx,
                axis_y = dy,

                length = length,
                contour_length = contour_length,

                start_i = particle_n,
                end_i = nil
            }

            local segment_length = length / n_particles
            local contour_segment_length = contour_length / n_particles

            local radius_easing = function(i, n)
                return ((i - 1) / n) * particle_texture_radius
            end

            local mass_easing = function(i, n)
                return 1
            end

            local x, y = self._position_x + anchor_x, self._position_y + anchor_y
            local data = self._particle_data
            for rope_node_i = 1, n_particles do
                -- add particle
                local i = #data + 1
                data[i + _x_offset] = x
                data[i + _y_offset] = y
                data[i + _velocity_x_offset] = 0
                data[i + _velocity_y_offset] = 0
                data[i + _previous_x_offset] = x
                data[i + _previous_y_offset] = y
                data[i + _radius_offset] = radius_easing(rope_node_i, n_particles)

                local mass = mass_easing(rope_node_i, n_particles)
                data[i + _mass_offset] = mass
                data[i + _inverse_mass_offset] = 1 / mass
                data[i + _segment_length_offset] = segment_length
                data[i + _contour_segment_length_offset] = contour_segment_length
                data[i + _last_step_x_offset] = x
                data[i + _last_step_y_offset] = y

                particle_n = particle_n + 1
            end

            rope.end_i = particle_n - 1
            table.insert(self._ropes, rope)
        end

        local ring_i_to_ring_radius = function(i, n)
            return ((i - 1) / n) * body_radius
        end

        local ring_radius_to_n_ropes = function(radius)
            local circumference = 2 * math.pi * radius
            local n = math.floor(math.max(1, circumference / 3))
            if n % 2 == 0 then n = n + 1 end
            return n
        end

        local ring_i_to_rope_length = function(i, n)
            return (1 - (i - 1) / (n + 1)) * max_rope_length
        end

        local rope_length_to_n_particles = function(length)
            return math.ceil(length / 3)
        end

        local n_rings = 7
        local contour_length_factor = rt.settings.player.bubble_radius_factor
        local center_x, center_y = self._position_x, self._position_y

        local total_n_ropes = 0
        for ring_i = 1, n_rings do
            local ring_radius = ring_i_to_ring_radius(ring_i, n_rings)
            local n_ropes = ring_radius_to_n_ropes(ring_radius)
            total_n_ropes = total_n_ropes + n_ropes
        end

        local total_rope_i = 1
        for ring_i = 1, n_rings do
            local rope_length = ring_i_to_rope_length(ring_i, n_rings)
            local n_particles = rope_length_to_n_particles(rope_length)
            local ring_radius = ring_i_to_ring_radius(ring_i, n_rings)
            local n_ropes = ring_radius_to_n_ropes(ring_radius)

            local angle_step = (2 * math.pi) / n_ropes
            for rope_i = 1, n_ropes do
                local angle = ((rope_i - 1) / n_ropes + (total_rope_i - 1) / total_n_ropes) * 2 * math.pi
                local dx, dy = math.cos(angle), math.sin(angle)
                local anchor_x = dx * ring_radius
                local anchor_y = dy * ring_radius

                add_rope(
                    n_particles,
                    rope_length, contour_length_factor * rope_length,
                    anchor_x, anchor_y,
                    dx, dy
                )

                total_rope_i = total_rope_i + 1
            end
        end

        self._n_particles = particle_n - 1
    end

    do -- instance mesh
        local x, y, r = 0, 0, 1
        local mesh = rt.Mesh({
            { x    , y    , 0.5, 0.5,  1, 1, 1, 1 },
            { x - r, y - r, 0.0, 0.0,  1, 1, 1, 1 },
            { x + r, y - r, 1.0, 0.0,  1, 1, 1, 1 },
            { x + r, y + r, 1.0, 1.0,  1, 1, 1, 1 },
            { x - r, y + r, 0.0, 1.0,  1, 1, 1, 1 }
        },
            rt.MeshDrawMode.TRIANGLES,
            rt.VertexFormat,
            rt.GraphicsBufferUsage.STATIC
        )

        mesh:set_vertex_map(
            1, 2, 3,
            1, 3, 4,
            1, 4, 5,
            1, 5, 2
        )
        mesh:set_texture(self._particle_texture)
        self._instance_mesh = mesh
    end

    do -- data mesh
        self._data_mesh_format = {
            { location = 3, name = "position", format = "floatvec4" }, -- xy: position, zw: previous position
            { location = 4, name = "velocity", format = "floatvec2" },
            { location = 5, name = "radius", format = "float" },
        }

        self._particle_i_to_data_mesh_position = {}
        for i = 1, self._n_particles do
            self._particle_i_to_data_mesh_position[i] = i
        end

        -- sort so highest radius particles are drawn first
        table.sort(self._particle_i_to_data_mesh_position, function(a_i, b_i)
            local i1 = _particle_i_to_data_offset(a_i)
            local i2 = _particle_i_to_data_offset(b_i)
            return self._particle_data[i1 + _radius_offset] < self._particle_data[i2 + _radius_offset]
        end)

        self._data_mesh_data = {}
        local data = self._particle_data
        for particle_i = 1, self._n_particles do
            local mapped_i = self._particle_i_to_data_mesh_position[particle_i]
            local i = _particle_i_to_data_offset(mapped_i)
            table.insert(self._data_mesh_data, {
                data[i + _x_offset],
                data[i + _y_offset],
                data[i + _previous_x_offset],
                data[i + _previous_y_offset],
                data[i + _velocity_x_offset],
                data[i + _velocity_y_offset],
                data[i + _radius_offset]
            })
        end

        self._data_mesh = rt.Mesh(
            self._data_mesh_data,
            rt.MeshDrawMode.POINTS,
            self._data_mesh_format,
            rt.GraphicsBufferUsage.STREAM
        )

        for entry in values(self._data_mesh_format) do
            self._instance_mesh:attach_attribute(
                self._data_mesh,
                entry.name,
                rt.MeshAttributeAttachmentMode.PER_INSTANCE
            )
        end
    end
end

--- @brief
function rt.PlayerBody:_update_data_mesh()
    local from = self._particle_data
    for particle_i = 1, self._n_particles do
        local mapped_i = self._particle_i_to_data_mesh_position[particle_i]
        local to = self._data_mesh_data[mapped_i]
        local i = _particle_i_to_data_offset(mapped_i)
        to[1] = from[i + _x_offset]
        to[2] = from[i + _y_offset]
        to[3] = from[i + _previous_x_offset]
        to[4] = from[i + _previous_y_offset]
        to[5] = from[i + _velocity_x_offset]
        to[6] = from[i + _velocity_y_offset]
        to[7] = from[i + _radius_offset]
    end

    self._data_mesh:replace_data(self._data_mesh_data)
end

--- @brief
function rt.PlayerBody:relax()
    local data = self._particle_data
    local center_x, center_y = self._position_x, self._position_y
    for rope in values(self._ropes) do
        local dx, dy = rope.axis_x, rope.axis_y
        local x, y = center_x + rope.anchor_x, center_y + rope.anchor_y
        for particle_i = rope.start_i, rope.end_i do
            local i = _particle_i_to_data_offset(particle_i)
            data[i + _x_offset] = x
            data[i + _y_offset] = y

            local segment_length = data[i + _segment_length_offset]
            x = x + dx * segment_length
            y = y + dy * segment_length
        end
    end

    self:_update_data_mesh()
end

function rt.PlayerBody:update(delta)
    self:_step(delta)
end

do -- update helpers
    local _pre_solve = function(
        particles, n_particles,
        gravity_x, gravity_y,
        damping, delta
    )
        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local x_i = i + _x_offset
            local y_i = i + _y_offset
            local velocity_x_i = i + _velocity_x_offset
            local velocity_y_i = i + _velocity_y_offset

            local x, y = particles[x_i], particles[y_i]

            particles[i + _previous_x_offset] = x
            particles[i + _previous_y_offset] = y

            local velocity_x = particles[velocity_x_i] * damping
            local velocity_y = particles[velocity_y_i] * damping

            local mass = particles[i + _mass_offset]
            velocity_x = velocity_x + mass * gravity_x * delta
            velocity_y = velocity_y + mass * gravity_y * delta

            particles[velocity_x_i] = velocity_x
            particles[velocity_y_i] = velocity_y

            particles[x_i] = x + delta * velocity_x
            particles[y_i] = y + delta * velocity_y
        end
    end

    -- XPBD: enforce distance between two particles to be a specific value
    local function _enforce_distance(
        ax, ay, bx, by,
        inverse_mass_a, inverse_mass_b,
        target_distance,
        compliance
    )
        local dx = bx - ax
        local dy = by - ay

        local current_distance = math.magnitude(dx, dy)
        dx, dy = math.normalize(dx, dy)

        local constraint_violation = current_distance - target_distance

        local mass_sum = inverse_mass_a + inverse_mass_b

        local divisor = (mass_sum + compliance)
        if divisor < math.eps then return 0, 0, 0, 0 end

        local correction = -constraint_violation / divisor

        local max_correction = math.abs(constraint_violation)
        correction = math.clamp(correction, -max_correction, max_correction)

        local a_correction_x = -dx * correction * inverse_mass_a
        local a_correction_y = -dy * correction * inverse_mass_a

        local b_correction_x =  dx * correction * inverse_mass_b
        local b_correction_y =  dy * correction * inverse_mass_b

        return a_correction_x, a_correction_y, b_correction_x, b_correction_y
    end

    -- XPBD-style bending: straightening by making end-to-end distance equal sum of adjacent segment lengths
    -- Returns corrections for A, B, C respectively (B gets zero for this constraint; it is indirectly updated by distance constraints)
    local function _enforce_bending(
        ax, ay, bx, by, cx, cy,
        inverse_mass_a, inverse_mass_b, inverse_mass_c,
        target_ac_distance,
        compliance
    )
        local dx = cx - ax
        local dy = cy - ay
        local current_distance = math.magnitude(dx, dy)
        dx, dy = math.normalize(dx, dy)

        -- If degenerate, skip
        if current_distance < math.eps then
            return 0, 0, 0, 0, 0, 0
        end

        -- Distance violation for AC
        local constraint_violation = current_distance - target_ac_distance

        local mass_sum = inverse_mass_a + inverse_mass_c
        local divisor = (mass_sum + compliance)
        if divisor < math.eps then
            return 0, 0, 0, 0, 0, 0
        end

        local correction = -constraint_violation / divisor

        -- Clamp to avoid overshoot
        local max_correction = math.abs(constraint_violation)
        correction = math.clamp(correction, -max_correction, max_correction)

        local a_correction_x = -dx * correction * inverse_mass_a
        local a_correction_y = -dy * correction * inverse_mass_a

        local c_correction_x =  dx * correction * inverse_mass_c
        local c_correction_y =  dy * correction * inverse_mass_c

        -- middle node gets no direct correction here (keeps perf high and stable)
        return a_correction_x, a_correction_y, 0.0, 0.0, c_correction_x, c_correction_y
    end

    -- XPBD-style IK for segment orientation: rotate a single segment towards target direction
    -- Returns corrections for both particles of the segment
    local function _enforce_axis_alignment(
        ax, ay,
        bx, by,
        inv_mass_a, inv_mass_b,
        segment_length,
        target_dx, target_dy,
        compliance
    )
        local vx = bx - ax
        local vy = by - ay
        local len_sq = vx*vx + vy*vy

        if len_sq < 1e-12 then
            return 0, 0, 0, 0
        end

        local len = math.sqrt(len_sq)
        vx = vx / len
        vy = vy / len

        -- perpendicular to current segment
        local px = -vy
        local py =  vx

        -- desired endpoint of B
        local tbx = ax + target_dx * segment_length
        local tby = ay + target_dy * segment_length

        -- positional error
        local ex = tbx - bx
        local ey = tby - by

        -- project error onto perpendicular → pure rotation
        local err = ex * px + ey * py
        ex = px * err
        ey = py * err

        local wsum = inv_mass_a + inv_mass_b
        if wsum == 0 then
            return 0, 0, 0, 0
        end

        -- XPBD compliance
        local alpha = compliance
        local s = 1.0 / (wsum + alpha)

        local axc = -ex * inv_mass_a * s
        local ayc = -ey * inv_mass_a * s
        local bxc =  ex * inv_mass_b * s
        local byc =  ey * inv_mass_b * s

        return axc, ayc, bxc, byc
    end


    local function _post_solve(particles, n_particles, delta)
        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)

            local x = particles[i + _x_offset]
            local y = particles[i + _y_offset]

            local velocity_x = (x - particles[i + _previous_x_offset]) / delta
            local velocity_y = (y - particles[i + _previous_y_offset]) / delta
            particles[i + _velocity_x_offset] = velocity_x
            particles[i + _velocity_y_offset] = velocity_y
        end
    end

    --- @brief
    function rt.PlayerBody:_step(delta)
        local damping = 1 - 0.1
        local n_sub_steps = 1
        local n_constraint_iterations = 5

        local sub_delta = delta / n_sub_steps

        -- compliance alphas, pre-calculated
        local distance_compliance = 0.000 / (sub_delta^2)
        local bending_compliance  = 0.001 / (sub_delta^2)
        local inverse_kinematics_compliance = 0.00001 / (sub_delta^2)

        local data = self._particle_data
        local n_particles = self._n_particles

        local gravity_dx, gravity_dy = 0, 1
        local gravity = 1

        for _ = 1, n_sub_steps do
            _pre_solve(
                data, n_particles,
                gravity_dx * gravity, gravity_dy * gravity,
                damping,
                sub_delta
            )

            for _ = 1, n_constraint_iterations do
                for rope in values(self._ropes) do
                    local anchor_x = self._position_x + rope.anchor_x
                    local anchor_y = self._position_y + rope.anchor_y

                    -- keep first node pinned to anchor each iteration
                    local anchor_i = _particle_i_to_data_offset(rope.start_i)
                    data[anchor_i + _x_offset] = anchor_x
                    data[anchor_i + _y_offset] = anchor_y

                    for node_i = rope.start_i, rope.end_i - 1, 1 do
                        local i1 = _particle_i_to_data_offset(node_i + 0)
                        local i2 = _particle_i_to_data_offset(node_i + 1)

                        local ax, ay = data[i1 + _x_offset], data[i1 + _y_offset]
                        local bx, by = data[i2 + _x_offset], data[i2 + _y_offset]

                        local inverse_mass_a = data[i1 + _inverse_mass_offset]
                        local inverse_mass_b = data[i2 + _inverse_mass_offset]

                        local segment_length = data[i1 + _segment_length_offset]

                        local a_cx, a_cy, b_cx, b_cy = _enforce_distance(
                            ax, ay, bx, by,
                            inverse_mass_a, inverse_mass_b,
                            segment_length,
                            distance_compliance
                        )

                        data[i1 + _x_offset] = ax + a_cx
                        data[i1 + _y_offset] = ay + a_cy
                        data[i2 + _x_offset] = bx + b_cx
                        data[i2 + _y_offset] = by + b_cy
                    end

                    if not self._use_contour then goto next_rope end

                    -- enforce bending
                    for node_i = rope.start_i, rope.end_i - 2, 1 do
                        local i1 = _particle_i_to_data_offset(node_i + 0)
                        local i2 = _particle_i_to_data_offset(node_i + 1)
                        local i3 = _particle_i_to_data_offset(node_i + 2)

                        local ax, ay = data[i1 + _x_offset], data[i1 + _y_offset]
                        local bx, by = data[i2 + _x_offset], data[i2 + _y_offset]
                        local cx, cy = data[i3 + _x_offset], data[i3 + _y_offset]

                        local wa = data[i1 + _inverse_mass_offset]
                        local wb = data[i2 + _inverse_mass_offset]
                        local wc = data[i3 + _inverse_mass_offset]

                        local segment_length_ab = data[i1 + _segment_length_offset]
                        local segment_length_bc = data[i2 + _segment_length_offset]
                        local target_length = segment_length_ab + segment_length_bc

                        local a_cx, a_cy, _, _, c_cx, c_cy = _enforce_bending(
                            ax, ay, bx, by, cx, cy,
                            wa, wb, wc,
                            target_length,
                            bending_compliance
                        )

                        data[i1 + _x_offset] = ax + a_cx
                        data[i1 + _y_offset] = ay + a_cy

                        data[i3 + _x_offset] = cx + c_cx
                        data[i3 + _y_offset] = cy + c_cy
                    end

                    -- enforce axis
                    for node_i = rope.start_i, rope.end_i - 1 do
                        local i1 = _particle_i_to_data_offset(node_i)
                        local i2 = _particle_i_to_data_offset(node_i + 1)

                        local ax = data[i1 + _x_offset]
                        local ay = data[i1 + _y_offset]
                        local bx = data[i2 + _x_offset]
                        local by = data[i2 + _y_offset]

                        local wa = data[i1 + _inverse_mass_offset]
                        local wb = data[i2 + _inverse_mass_offset]

                        local segment_length = data[i1 + _segment_length_offset]

                        local a_cx, a_cy, b_cx, b_cy = _enforce_axis_alignment(
                            ax, ay, bx, by,
                            wa, wb,
                            segment_length,
                            rope.axis_x, rope.axis_y,
                            inverse_kinematics_compliance
                        )

                        data[i1 + _x_offset] = ax + a_cx
                        data[i1 + _y_offset] = ay + a_cy
                        data[i2 + _x_offset] = bx + b_cx
                        data[i2 + _y_offset] = by + b_cy
                    end

                    ::next_rope::
                end

                _post_solve(
                    data, n_particles,
                    sub_delta
                )
            end -- ropes
        end -- n sub steps

        self:_update_data_mesh()
    end
end

--- @brief
function rt.PlayerBody:draw_body()
    love.graphics.push("all")
    rt.Palette.WHITE:bind()
    _instance_draw_shader:bind()
    _instance_draw_shader:send("interpolation_alpha", 1)
    self._instance_mesh:draw_instanced(self._n_particles)
    _instance_draw_shader:unbind()
    love.graphics.pop()
end

--- @brief
function rt.PlayerBody:draw_core()
    if self._core_vertices == nil then return end
    love.graphics.push("all")
    self._core_color:bind()
    love.graphics.translate(self._position_x, self._position_y)
    --love.graphics.polygon("fill", self._core_vertices)
    love.graphics.pop()
end

--- @brief
function rt.PlayerBody:set_position(x, y)
    self._position_x = x
    self._position_y = y
end

--- @brief
function rt.PlayerBody:set_shape(positions)
    self._core_vertices = positions
end

rt.PlayerBody.update_rope = function(data)

end

--- @brief
function rt.PlayerBody:set_color(color)
    meta.assert(color, rt.RGBA)
    self._core_color = color
end

--- @brief
function rt.PlayerBody:set_body_color(color)
    meta.assert(color, rt.RGBA)
    self._body_color = color
end

--- @brief
function rt.PlayerBody:set_core_color(color)

end

--- @brief
function rt.PlayerBody:set_opacity(opacity)

end

--- @brief
function rt.PlayerBody:set_use_contour(b)
    self._use_contour = b
end

--- @brief
function rt.PlayerBody:draw_bloom()

end

--- @brief
function rt.PlayerBody:set_relative_velocity(vx, vy)

end

--- @brief
function rt.PlayerBody:set_down_squish(b, nx, ny, contact_x, contact_y)

end

--- @brief
function rt.PlayerBody:set_left_squish(b, nx, ny, contact_x, contact_y)

end

--- @brief
function rt.PlayerBody:set_right_squish(b, nx, ny, contact_x, contact_y)

end

--- @brief
function rt.PlayerBody:set_up_squish(b, nx, ny, contact_x, contact_y)

end

--- @brief
function rt.PlayerBody:set_gravity(gravity_x, gravity_y)
    self._gravity_x, self._gravity_y = gravity_x, gravity_y -- can be nil
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
function rt.PlayerBody:set_world(physics_world)
end

--- @brief
function rt.PlayerBody:set_use_stencils(b)
end