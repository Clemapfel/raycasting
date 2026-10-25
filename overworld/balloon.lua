local settings = {
    n_sub_steps = 2,
    n_constraint_iterations = 4,

    vertex_density = 1 / 4,
    damping = 0.998,
    gravity = 5000,

    distance_compliance = 2e-6,
    volume_compliance = 1e-7,
    line_compliance = 0,
    bending_compliance = 1e-6,
    angular_compliance = 0,

    n_particles = 64,
    radius = 80,
    texture_zoom = 1 / 1.25
}

--- @class rt.Balloon
rt.Balloon = meta.class("Balloon", rt.Widget)

local _x_offset = 0
local _y_offset = 1
local _previous_x_offset = 2
local _previous_y_offset = 3
local _draw_x_offset = 4
local _draw_y_offset = 5
local _velocity_x_offset = 6
local _velocity_y_offset = 7
local _radius_offset = 8
local _mass_offset = 9
local _inverse_mass_offset = 10
local _distance_lambda_offset = 11
local _bending_lambda_offset = 12
local _polygon_lambda_offset = 13

local _stride = _polygon_lambda_offset + 1
local _particle_i_to_data_offset = function(particle_i)
    return (particle_i - 1) * _stride + 1
end

local _edge_x1_offset = 0
local _edge_y1_offset = 1
local _edge_x2_offset = 2
local _edge_y2_offset = 3
local _edge_normal_x_offset = 4
local _edge_normal_y_offset = 5

local _edge_stride = _edge_normal_y_offset + 1
local _edge_i_to_data_offset = function(edge_i)
    return (edge_i - 1) * _edge_stride + 1
end

function rt.Balloon:reformat(x, y, width, height)
    local n_particles = settings.n_particles
    self._n_particles = n_particles

    local cx, cy = x + 0.5 * width, y + 0.5 * height
    local radius = settings.radius

    -- particles
    local particles = {}
    self._particles = particles

    for particle_i = 1, n_particles do
        local angle = (particle_i - 1) / n_particles * 2 * math.pi
        local px = cx + radius * math.cos(angle)
        local py = cy + radius * math.sin(angle)
        local mass = 1

        local base = _particle_i_to_data_offset(particle_i)

        particles[base + _x_offset] = px
        particles[base + _y_offset] = py
        particles[base + _previous_x_offset] = px
        particles[base + _previous_y_offset] = py
        particles[base + _draw_x_offset] = px
        particles[base + _draw_y_offset] = py
        particles[base + _velocity_x_offset] = 0
        particles[base + _velocity_y_offset] = 0
        particles[base + _radius_offset] = 4
        particles[base + _mass_offset] = mass
        particles[base + _inverse_mass_offset] = 1 / mass
        particles[base + _distance_lambda_offset] = 0
        particles[base + _bending_lambda_offset] = 0
        particles[base + _polygon_lambda_offset] = 0
    end

    -- collision area
    local tlx, tly = x, y
    local trx, try = x + width, y
    local brx, bry = x + width, y + height
    local blx, bly = x, y + height
    local polygon = {
        tlx, tly,
        trx, try,
        brx, bry,
        blx, bly,
        tlx, tly
    }
    self._polygon = polygon

    -- precompute polygon edge data
    local edges = {}
    local n_edges = 0
    local n_vertices = #polygon / 2
    for vertex_i = 1, n_vertices do
        local next_vertex_i = vertex_i % n_vertices + 1

        local ai = (vertex_i - 1) * 2 + 1
        local bi = (next_vertex_i - 1) * 2 + 1
        local x1, y1 = polygon[ai + 0], polygon[ai + 1]
        local x2, y2 = polygon[bi + 0], polygon[bi + 1]

        local e_dx = x2 - x1
        local e_dy = y2 - y1
        local e_magnitude = math.sqrt(e_dx * e_dx + e_dy * e_dy)

        if e_magnitude > math.eps then
            n_edges = n_edges + 1
            local base = _edge_i_to_data_offset(n_edges)

            edges[base + _edge_x1_offset] = x1
            edges[base + _edge_y1_offset] = y1
            edges[base + _edge_x2_offset] = x2
            edges[base + _edge_y2_offset] = y2
            edges[base + _edge_normal_x_offset] = -e_dy / e_magnitude
            edges[base + _edge_normal_y_offset] = e_dx / e_magnitude
        end
    end
    self._polygon_edges = edges
    self._n_polygon_edges = n_edges

    -- volume
    local area = 0
    for particle_i = 1, n_particles do
        local ai = _particle_i_to_data_offset(particle_i)
        local bi = _particle_i_to_data_offset(particle_i % n_particles + 1)
        local ax, ay = particles[ai + _x_offset], particles[ai + _y_offset]
        local bx, by = particles[bi + _x_offset], particles[bi + _y_offset]
        area = area + 0.5 * (ax * by - bx * ay)
    end
    self._rest_volume = area

    self._volume_lambda = 0
    self._angular_lambda = 0

    -- preallocated gradient buffers for volume constraint
    self._volume_gradient_x = {}
    self._volume_gradient_y = {}
    for particle_i = 1, n_particles do
        self._volume_gradient_x[particle_i] = 0
        self._volume_gradient_y[particle_i] = 0
    end

    -- chain
    self._chain = {}
    for particle_i = 1, n_particles  do
        table.insert(self._chain, particle_i)
    end

    -- precompute wrapped data offsets for pairs (a, b) and triplets (a, b, c)
    local chain = self._chain
    local n_chain = #chain
    self._chain_a = {}
    self._chain_b = {}
    self._chain_c = {}
    for chain_i = 1, n_chain do
        self._chain_a[chain_i] = _particle_i_to_data_offset(chain[chain_i])
        self._chain_b[chain_i] = _particle_i_to_data_offset(chain[chain_i % n_chain + 1])
        self._chain_c[chain_i] = _particle_i_to_data_offset(chain[(chain_i + 1) % n_chain + 1])
    end

    -- sim params
    self._segment_length = (2 * math.pi * radius) / n_particles
    self._elapsed = 0

    -- mesh
    self._draw_positions = {}
    for particle_i = 1, n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        table.insert(self._draw_positions, particles[i + _x_offset])
        table.insert(self._draw_positions, particles[i + _y_offset])
    end

    self._mesh_data = {}

    local zoom = settings.texture_zoom
    for particle_i = 1, n_particles do
        local a_particle_i = particle_i
        local b_particle_i = particle_i % n_particles + 1

        local angle_a = (a_particle_i - 1) / n_particles * 2 * math.pi
        local angle_b = (b_particle_i - 1) / n_particles * 2 * math.pi
        local u_a = 0.5 + 0.5 * zoom * math.cos(angle_a)
        local v_a = 0.5 + 0.5 * zoom * math.sin(angle_a)
        local u_b = 0.5 + 0.5 * zoom * math.cos(angle_b)
        local v_b = 0.5 + 0.5 * zoom * math.sin(angle_b)

        local ai = _particle_i_to_data_offset(a_particle_i)
        local bi = _particle_i_to_data_offset(b_particle_i)
        local ax, ay = particles[ai + _x_offset], particles[ai + _y_offset]
        local bx, by = particles[bi + _x_offset], particles[bi + _y_offset]

        table.insert(self._mesh_data, { cx, cy, 0.5, 0.5, 1, 1, 1, 1 })
        table.insert(self._mesh_data, { ax, ay, u_a, v_a, 1, 1, 1, 1 })
        table.insert(self._mesh_data, { bx, by, u_b, v_b, 1, 1, 1, 1 })
    end

    self._mesh = rt.Mesh(self._mesh_data, rt.MeshDrawMode.TRIANGLES)
    self._mesh:set_texture(rt.Texture("assets/sprites/why.png"))
    self._mesh_data_needs_update = false
end

function rt.Balloon:draw()
    local n_particles = self._n_particles
    local frame_interpolation_alpha = 1.0

    if self._mesh_data_needs_update then
        self._mesh_data_needs_update = false

        local particles = self._particles
        local draw_positions = self._draw_positions

        -- precompute draw positions and centroid
        local x_sum, y_sum = 0, 0
        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)

            local base_x, base_y = particles[i + _x_offset], particles[i + _y_offset]
            local draw_x, draw_y = particles[i + _draw_x_offset], particles[i + _draw_y_offset]

            local x = draw_x + (base_x - draw_x) * frame_interpolation_alpha
            local y = draw_y + (base_y - draw_y) * frame_interpolation_alpha

            x_sum = x_sum + x
            y_sum = y_sum + y

            local j = particle_i * 2
            draw_positions[j - 1] = x
            draw_positions[j - 0] = y
        end

        local cx, cy = x_sum / n_particles, y_sum / n_particles

        -- update mesh data
        local mesh_data = self._mesh_data
        for particle_i = 1, n_particles do
            local a_particle_i = particle_i
            local b_particle_i = particle_i % n_particles + 1

            local ai = (a_particle_i - 1) * 2 + 1
            local bi = (b_particle_i - 1) * 2 + 1

            local ax, ay = draw_positions[ai + 0], draw_positions[ai + 1]
            local bx, by = draw_positions[bi + 0], draw_positions[bi + 1]

            local mesh_i = (particle_i - 1) * 3 + 1
            mesh_data[mesh_i + 0][1] = cx
            mesh_data[mesh_i + 0][2] = cy

            mesh_data[mesh_i + 1][1] = ax
            mesh_data[mesh_i + 1][2] = ay

            mesh_data[mesh_i + 2][1] = bx
            mesh_data[mesh_i + 2][2] = by
        end

        self._mesh:replace_data(mesh_data)
    end

    love.graphics.setColor(1, 1, 1, 1)
    self._mesh:draw()

    love.graphics.setLineWidth(4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.line(self._polygon)
end

do
    local function _pre_solve(
        position_x, position_y,
        velocity_x, velocity_y,
        mass,
        gravity_x, gravity_y,
        damping, delta
    )
        local previous_x = position_x
        local previous_y = position_y

        local world_velocity_new_x = velocity_x * damping + mass * gravity_x * delta
        local world_velocity_new_y = velocity_y * damping + mass * gravity_y * delta

        local position_new_x = position_x + world_velocity_new_x * delta
        local position_new_y = position_y + world_velocity_new_y * delta

        return position_new_x, position_new_y, world_velocity_new_x, world_velocity_new_y, previous_x, previous_y
    end

    local function _enforce_distance(
        ax, ay, bx, by,
        inverse_mass_a, inverse_mass_b,
        target_distance,
        alpha,
        lambda_before
    )
        local delta_x = bx - ax
        local delta_y = by - ay
        local length = math.magnitude(delta_x, delta_y)
        if length < math.eps then
            return 0, 0, 0, 0, lambda_before
        end

        local normal_x, normal_y = delta_x / length, delta_y / length

        local constraint = length - target_distance
        local weight_sum = inverse_mass_a + inverse_mass_b
        local denominator = weight_sum + alpha
        if denominator < math.eps then
            return 0, 0, 0, 0, lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = lambda_before + delta_lambda

        local correction_ax = inverse_mass_a * delta_lambda * (-normal_x)
        local correction_ay = inverse_mass_a * delta_lambda * (-normal_y)
        local correction_bx = inverse_mass_b * delta_lambda * ( normal_x)
        local correction_by = inverse_mass_b * delta_lambda * ( normal_y)

        return correction_ax, correction_ay, correction_bx, correction_by, lambda_new
    end

    local function _closest_point_on_segment(xy_x, xy_y, sx1, sy1, sx2, sy2)
        local a_x, a_y = sx1, sy1
        local b_x, b_y = sx2, sy2
        local ab_x, ab_y = b_x - a_x, b_y - a_y
        local ab_magnitude_sq = ab_x * ab_x + ab_y * ab_y

        if ab_magnitude_sq <= 0.0 then
            return a_x, a_y
        end

        local ap_x, ap_y = xy_x - a_x, xy_y - a_y
        local t = (ap_x * ab_x + ap_y * ab_y) / ab_magnitude_sq
        if t < 0.0 then t = 0.0 elseif t > 1.0 then t = 1.0 end

        return a_x + t * ab_x, a_y + t * ab_y
    end

    local function _enforce_polygon_collision(
        position_x, position_y, inverse_mass,
        radius,
        edges, n_edges,
        alpha,
        lambda_before
    )
        if inverse_mass <= 0.0 then
            return 0.0, 0.0, lambda_before
        end

        local min_dist_sq = math.huge
        local best_cx, best_cy = position_x, position_y
        local best_nx, best_ny = 0, 0
        local inside = false

        for edge_i = 1, n_edges do
            local i = _edge_i_to_data_offset(edge_i)
            local x1, y1 = edges[i + _edge_x1_offset], edges[i + _edge_y1_offset]
            local x2, y2 = edges[i + _edge_x2_offset], edges[i + _edge_y2_offset]

            -- closest point
            local cx, cy = _closest_point_on_segment(position_x, position_y, x1, y1, x2, y2)
            local dx = position_x - cx
            local dy = position_y - cy
            local dist_sq = dx * dx + dy * dy

            if dist_sq < min_dist_sq then
                min_dist_sq = dist_sq
                best_cx, best_cy = cx, cy
                best_nx = edges[i + _edge_normal_x_offset]
                best_ny = edges[i + _edge_normal_y_offset]
            end

            -- even-odd rule
            if ((y2 > position_y) ~= (y1 > position_y))
                and (position_x < (x1 - x2) * (position_y - y2) / (y1 - y2) + x2)
            then
                inside = not inside
            end
        end

        local d = math.sqrt(min_dist_sq)

        local signed_dist
        local normal_x, normal_y

        if inside then
            signed_dist = d
            local vx, vy = position_x - best_cx, position_y - best_cy
            if d < math.eps then
                normal_x, normal_y = best_nx, best_ny
            else
                normal_x, normal_y = vx / d, vy / d
            end
        else
            signed_dist = -d
            normal_x, normal_y = best_nx, best_ny
        end

        local constraint = signed_dist - radius
        if constraint >= 0.0 then
            return 0.0, 0.0, lambda_before
        end

        local denominator = inverse_mass + alpha
        if denominator < math.eps then
            return 0.0, 0.0, lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = math.max(lambda_before + delta_lambda, 0.0)
        delta_lambda = lambda_new - lambda_before

        local correction_x = inverse_mass * delta_lambda * normal_x
        local correction_y = inverse_mass * delta_lambda * normal_y

        return correction_x, correction_y, lambda_new
    end

    local function _enforce_bending(
        ax, ay, bx, by, cx, cy,
        inverse_mass_a, inverse_mass_b, inverse_mass_c,
        alpha,
        lambda_before
    )
        local chord_x = cx - ax
        local chord_y = cy - ay
        local length = math.sqrt(chord_x * chord_x + chord_y * chord_y)
        if length < math.eps then
            return 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, lambda_before
        end

        local inv_length = 1.0 / length
        local tx = chord_x * inv_length
        local ty = chord_y * inv_length
        local nx = -ty
        local ny = tx

        local ex = 0.5 * (ax + cx) - bx
        local ey = 0.5 * (ay + cy) - by

        local constraint = ex * nx + ey * ny

        local k = (ex * tx + ey * ty) * inv_length

        local wa =  0.5 + k
        local wb = -1.0
        local wc =  0.5 - k

        local weight_sum = inverse_mass_a * wa * wa
            + inverse_mass_b * wb * wb
            + inverse_mass_c * wc * wc

        local denominator = weight_sum + alpha
        if denominator < math.eps then
            return 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = lambda_before + delta_lambda

        local sa = inverse_mass_a * delta_lambda * wa
        local sb = inverse_mass_b * delta_lambda * wb
        local sc = inverse_mass_c * delta_lambda * wc

        return sa * nx, sa * ny,
        sb * nx, sb * ny,
        sc * nx, sc * ny,
        lambda_new
    end

    local function _enforce_angular_momentum(
        particles, n_particles,
        alpha,
        lambda_before
    )
        local mass_sum = 0
        local com_x, com_y = 0, 0
        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local m = particles[i + _mass_offset]
            mass_sum = mass_sum + m
            com_x = com_x + m * particles[i + _previous_x_offset]
            com_y = com_y + m * particles[i + _previous_y_offset]
        end

        if mass_sum < math.eps then return lambda_before end
        com_x = com_x / mass_sum
        com_y = com_y / mass_sum

        local constraint = 0
        local weight_sum = 0
        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local m = particles[i + _mass_offset]
            local inverse_mass = particles[i + _inverse_mass_offset]

            local rx = particles[i + _previous_x_offset] - com_x
            local ry = particles[i + _previous_y_offset] - com_y
            local dx = particles[i + _x_offset] - particles[i + _previous_x_offset]
            local dy = particles[i + _y_offset] - particles[i + _previous_y_offset]

            constraint = constraint + m * (rx * dy - ry * dx)

            local gx, gy = -m * ry, m * rx
            weight_sum = weight_sum + inverse_mass * (gx * gx + gy * gy)
        end

        local denominator = weight_sum + alpha
        if denominator < math.eps then return lambda_before end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = lambda_before + delta_lambda

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local m = particles[i + _mass_offset]
            local inverse_mass = particles[i + _inverse_mass_offset]

            local rx = particles[i + _previous_x_offset] - com_x
            local ry = particles[i + _previous_y_offset] - com_y

            particles[i + _x_offset] = particles[i + _x_offset] + inverse_mass * delta_lambda * (-m * ry)
            particles[i + _y_offset] = particles[i + _y_offset] + inverse_mass * delta_lambda * ( m * rx)
        end

        return lambda_new
    end

    local function _enforce_volume(
        particles, n_particles,
        gradient_x, gradient_y,
        rest_area,
        alpha,
        lambda_before
    )
        local current_area = 0
        local weight_sum = 0.0

        local previous_ai = _particle_i_to_data_offset(n_particles)
        local current_ai = _particle_i_to_data_offset(1)

        for i = 1, n_particles do
            local next_ai = _particle_i_to_data_offset(i % n_particles + 1)

            local previous_x = particles[previous_ai + _x_offset]
            local previous_y = particles[previous_ai + _y_offset]
            local current_x = particles[current_ai + _x_offset]
            local current_y = particles[current_ai + _y_offset]
            local next_x = particles[next_ai + _x_offset]
            local next_y = particles[next_ai + _y_offset]

            current_area = current_area + 0.5 * (current_x * next_y - next_x * current_y)

            local grad_x = 0.5 * (next_y - previous_y)
            local grad_y = 0.5 * (previous_x - next_x)
            gradient_x[i] = grad_x
            gradient_y[i] = grad_y

            local inverse_mass = particles[current_ai + _inverse_mass_offset]
            weight_sum = weight_sum + inverse_mass * (grad_x * grad_x + grad_y * grad_y)

            previous_ai = current_ai
            current_ai = next_ai
        end

        local constraint = current_area - rest_area

        local denominator = weight_sum + alpha
        if denominator < math.eps then
            return lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = lambda_before + delta_lambda

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local inverse_mass = particles[i + _inverse_mass_offset]

            particles[i + _x_offset] = particles[i + _x_offset] + inverse_mass * delta_lambda * gradient_x[particle_i]
            particles[i + _y_offset] = particles[i + _y_offset] + inverse_mass * delta_lambda * gradient_y[particle_i]
        end

        return lambda_new
    end

    local function _post_solve(
        position_x, position_y,
        previous_x, previous_y,
        delta
    )
        local velocity_x = (position_x - previous_x) / delta
        local velocity_y = (position_y - previous_y) / delta

        return velocity_x, velocity_y
    end

    function rt.Balloon:update(delta)
        local sub_delta = delta / settings.n_sub_steps

        local damping = settings.damping
        local n_sub_steps = settings.n_sub_steps
        local n_constraint_iterations = settings.n_constraint_iterations

        local volume_alpha = settings.volume_compliance / (sub_delta^2)
        local line_alpha = settings.line_compliance / (sub_delta^2)
        local distance_alpha = settings.distance_compliance / (sub_delta^2)
        local bending_alpha = settings.bending_compliance / (sub_delta^2)
        local angular_alpha = settings.angular_compliance / (sub_delta^2)

        local ps = self._particles
        local n_particles = self._n_particles
        local chain_a, chain_b, chain_c = self._chain_a, self._chain_b, self._chain_c
        local n_chain = #chain_a
        local segment_length = self._segment_length

        local volume_gradient_x = self._volume_gradient_x
        local volume_gradient_y = self._volume_gradient_y

        local edges = self._polygon_edges
        local n_edges = self._n_polygon_edges

        local gravity_direction_x, gravity_direction_y = 0, 1
        local gravity = settings.gravity

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            ps[i + _draw_x_offset] = ps[i + _x_offset]
            ps[i + _draw_y_offset] = ps[i + _y_offset]
        end

        for _ = 1, n_sub_steps do
            -- pre solve
            for particle_i = 1, n_particles do
                local i = _particle_i_to_data_offset(particle_i)
                local new_position_x, new_position_y, new_velocity_x, new_velocity_y, previous_x, previous_y = _pre_solve(
                    ps[i + _x_offset],
                    ps[i + _y_offset],
                    ps[i + _velocity_x_offset],
                    ps[i + _velocity_y_offset],
                    ps[i + _mass_offset],
                    gravity_direction_x * gravity, gravity_direction_y * gravity,
                    damping, sub_delta
                )

                ps[i + _x_offset] = new_position_x
                ps[i + _y_offset] = new_position_y
                ps[i + _velocity_x_offset] = new_velocity_x
                ps[i + _velocity_y_offset] = new_velocity_y
                ps[i + _previous_x_offset] = previous_x
                ps[i + _previous_y_offset] = previous_y

                ps[i + _distance_lambda_offset] = 0
                ps[i + _bending_lambda_offset] = 0
                ps[i + _polygon_lambda_offset] = 0
            end

            self._volume_lambda = 0
            self._angular_lambda = 0

            for _ = 1, n_constraint_iterations do
                -- distance: pair wise
                for chain_i = 1, n_chain, 1 do
                    local ai, bi = chain_a[chain_i], chain_b[chain_i]

                    local correction_ax, correction_ay, correction_bx, correction_by, lambda_new = _enforce_distance(
                        ps[ai + _x_offset], ps[ai + _y_offset],
                        ps[bi + _x_offset], ps[bi + _y_offset],
                        ps[ai + _inverse_mass_offset], ps[bi + _inverse_mass_offset],
                        segment_length,
                        distance_alpha,
                        ps[ai + _distance_lambda_offset]
                    )

                    ps[ai + _x_offset] = ps[ai + _x_offset] + correction_ax
                    ps[ai + _y_offset] = ps[ai + _y_offset] + correction_ay
                    ps[bi + _x_offset] = ps[bi + _x_offset] + correction_bx
                    ps[bi + _y_offset] = ps[bi + _y_offset] + correction_by
                    ps[ai + _distance_lambda_offset] = lambda_new
                end

                -- bending: triplets
                for chain_i = 1, n_chain, 1 do
                    local ai, bi, ci = chain_a[chain_i], chain_b[chain_i], chain_c[chain_i]

                    local correction_ax, correction_ay, correction_bx, correction_by, correction_cx, correction_cy, lambda_new = _enforce_bending(
                        ps[ai + _x_offset], ps[ai + _y_offset],
                        ps[bi + _x_offset], ps[bi + _y_offset],
                        ps[ci + _x_offset], ps[ci + _y_offset],
                        ps[ai + _inverse_mass_offset],
                        ps[bi + _inverse_mass_offset],
                        ps[ci + _inverse_mass_offset],
                        bending_alpha,
                        ps[ai + _bending_lambda_offset]
                    )

                    ps[ai + _x_offset] = ps[ai + _x_offset] + correction_ax
                    ps[ai + _y_offset] = ps[ai + _y_offset] + correction_ay
                    ps[bi + _x_offset] = ps[bi + _x_offset] + correction_bx
                    ps[bi + _y_offset] = ps[bi + _y_offset] + correction_by
                    ps[ci + _x_offset] = ps[ci + _x_offset] + correction_cx
                    ps[ci + _y_offset] = ps[ci + _y_offset] + correction_cy

                    ps[ai + _bending_lambda_offset] = lambda_new
                end

                -- volume
                self._volume_lambda = _enforce_volume(
                    ps, n_particles,
                    volume_gradient_x, volume_gradient_y,
                    self._rest_volume,
                    volume_alpha,
                    self._volume_lambda
                )

                -- rotation
                self._angular_lambda = _enforce_angular_momentum(
                    ps, n_particles,
                    angular_alpha,
                    self._angular_lambda
                )
            end

            for particle_i = 1, n_particles do
                local i = _particle_i_to_data_offset(particle_i)

                local x, y = ps[i + _x_offset], ps[i + _y_offset]
                local inverse_mass = ps[i + _inverse_mass_offset]
                local radius = ps[i + _radius_offset]
                local lambda = ps[i + _polygon_lambda_offset]

                -- polygon collision
                for _ = 1, n_constraint_iterations do
                    local correction_x, correction_y, lambda_new = _enforce_polygon_collision(
                        x, y,
                        inverse_mass,
                        radius,
                        edges, n_edges,
                        line_alpha,
                        lambda
                    )

                    x = x + correction_x
                    y = y + correction_y
                    lambda = lambda_new
                end

                ps[i + _x_offset] = x
                ps[i + _y_offset] = y
                ps[i + _polygon_lambda_offset] = lambda

                -- post-solve
                local new_velocity_x, new_velocity_y = _post_solve(
                    x, y,
                    ps[i + _previous_x_offset],
                    ps[i + _previous_y_offset],
                    sub_delta
                )

                ps[i + _velocity_x_offset] = new_velocity_x
                ps[i + _velocity_y_offset] = new_velocity_y
            end
        end

        self._mesh_data_needs_update = true
    end
end
