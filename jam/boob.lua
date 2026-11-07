local _settings_timestep = 1 / 120
local _settings_max_n_steps = 4

local _settings_n_sub_steps = 4
local _settings_n_constraint_iterations = 4

local _settings_distance_compliance = 2e-6
local _settings_volume_compliance = 1e-7
local _settings_line_compliance = 0
local _settings_bending_compliance = 1e-5
local _settings_angular_compliance = 1e-5
local _settings_particle_collision_compliance = 0

local _settings_damping = 0.9998
local _settings_gravity = 500

local _settings_texture_zoom = 1 / 0.9
local _settings_texture_path = "jam/assets/barboach.png"
local _settings_draw_line_width = 3

local _x_offset = 0
local _y_offset = 1
local _previous_x_offset = 2
local _previous_y_offset = 3
local _snapshot_x_offset = 4
local _snapshot_y_offset = 5
local _draw_x_offset = 6
local _draw_y_offset = 7
local _velocity_x_offset = 8
local _velocity_y_offset = 9
local _radius_offset = 10
local _mass_offset = 11
local _inverse_mass_offset = 12
local _distance_lambda_offset = 13
local _bending_lambda_offset = 14
local _polygon_lambda_offset = 15

local _stride = _polygon_lambda_offset + 1

local _edge_x1_offset = 0
local _edge_y1_offset = 1
local _edge_dx_offset = 2
local _edge_dy_offset = 3
local _edge_inverse_length_squared_offset = 4
local _edge_normal_x_offset = 5
local _edge_normal_y_offset = 6
local _edge_inverse_dy_offset = 7

local _edge_stride = _edge_inverse_dy_offset + 1
local _edge_i_to_data_offset = function(edge_i)
    return (edge_i - 1) * _edge_stride + 1
end

local _particle_i_to_data_offset = function(particle_i, n_particles)
    if n_particles ~= nil then
        particle_i = (particle_i - 1) % n_particles + 1
    end

    return (particle_i - 1) * _stride + 1
end

Boob_t = "Boob"

boob_new = function()
    return object_new(Boob_t, {
        is_initialized = false
    })
end

boob_init = function(self, center_x, center_y, radius, n_contour_nodes)
    log_typecheck(
        self, Boob_t,
        center_x, Float_t,
        center_y, Float_t,
        radius, Float_t,
        n_contour_nodes, Integer_t
    )

    local cos, sin, tau = math_cos, math_sin, math_tau

    -- particles
    log_assert(n_contour_nodes >= 5, "In boob_init: need at least 5 contour nodes")

    local n_particles = 0
    local data = {}

    for particle_i = 1, n_contour_nodes do
        local angle = (particle_i - 1) / n_contour_nodes * tau
        local px = center_x + radius * cos(angle)
        local py = center_y + radius * sin(angle)
        local mass = 1

        local base = _particle_i_to_data_offset(particle_i)
        n_particles = n_particles + 1

        data[base + _x_offset] = px
        data[base + _y_offset] = py
        data[base + _previous_x_offset] = px
        data[base + _previous_y_offset] = py
        data[base + _snapshot_x_offset] = px
        data[base + _snapshot_y_offset] = py
        data[base + _velocity_x_offset] = 0
        data[base + _velocity_y_offset] = 0
        data[base + _radius_offset] = 1
        data[base + _mass_offset] = mass
        data[base + _inverse_mass_offset] = 1 / mass
        data[base + _distance_lambda_offset] = 0
        data[base + _bending_lambda_offset] = 0
        data[base + _polygon_lambda_offset] = 0

        log_assert(#data == n_particles * _stride)
    end

    -- volume
    local area = 0

    for particle_i = 1, n_particles do
        local ai = _particle_i_to_data_offset(particle_i, n_particles)
        local bi = _particle_i_to_data_offset(particle_i + 1, n_particles)

        local ax, ay = data[ai + _x_offset], data[ai + _y_offset]
        local bx, by = data[bi + _x_offset], data[bi + _y_offset]

        area = area + 0.5 * math_cross(ax, ay, bx, by)
    end

    local segment_length = 2 * radius * sin(math.pi / n_particles)
    local rest_area = area

    -- drawing
    local mesh_data = {}
    local draw_contour = {}
    local zoom = _settings_texture_zoom

    for particle_i = 1, n_particles do
        local a_particle_i = particle_i
        local b_particle_i = particle_i + 1

        local angle_a = (a_particle_i - 1) / n_particles * tau
        local angle_b = (b_particle_i - 1) / n_particles * tau

        local u_a = 0.5 + 0.5 * zoom * cos(angle_a)
        local v_a = 0.5 + 0.5 * zoom * sin(angle_a)
        local u_b = 0.5 + 0.5 * zoom * cos(angle_b)
        local v_b = 0.5 + 0.5 * zoom * sin(angle_b)

        local ai = _particle_i_to_data_offset(a_particle_i, n_particles)
        local bi = _particle_i_to_data_offset(b_particle_i, n_particles)

        local ax, ay = data[ai + _x_offset], data[ai + _y_offset]
        local bx, by = data[bi + _x_offset], data[bi + _y_offset]

        table_push(mesh_data, { center_x, center_y, 0.5, 0.5, 1, 1, 1, 1 })
        table_push(mesh_data, { ax, ay, u_a, v_a, 1, 1, 1, 1 })
        table_push(mesh_data, { bx, by, u_b, v_b, 1, 1, 1, 1 })

        table_push(draw_contour, ax)
        table_push(draw_contour, ay)
    end

    table_push(draw_contour, draw_contour[1])
    table_push(draw_contour, draw_contour[2])

    local mesh = love.graphics.newMesh(mesh_data, "triangles", "stream")
    local mesh_texture = love.graphics.newImage(_settings_texture_path)

    mesh_texture:setFilter("nearest", "nearest")
    mesh:setTexture(mesh_texture)

    self.particles = data
    self.n_particles = n_particles

    self.volume = rest_area
    self.volume_lambda = 0
    self.angular_lambda = 0
    self.segment_length = segment_length

    self.volume_gradient = {}
    for particle_i = 1, n_particles do
        self.volume_gradient[2 * particle_i - 1] = 0
        self.volume_gradient[2 * particle_i] = 0
    end

    self.collision_contours = {}

    self.mesh = mesh
    self.mesh_data = mesh_data
    self.mesh_texture = mesh_texture
    self.draw_contour = polyline_close(polyline_new(draw_contour))

    -- control
    self.angular_velocity = 0

    self.is_initialized = true
    self.elapsed = 0

    return self
end

boob_is_initialized = function(self)
    return object_isa(self, Boob_t) and self.is_initialized == true
end

boob_set_collision_contours = function(self, ...)
    log_typecheck(self, Boob_t)

    local eps_squared = math_eps * math_eps

    for i = 1, select("#", ...) do
        local contour = select(i, ...)
        log_typecheck_arg_i(contour, Polyline_t, i)

        local closed_contour = polyline_close(contour)
        local n_corners = polyline_get_n_corners(closed_contour)

        log_assert(n_corners >= 3, "In boob_set_collision_contours: need at least 3 vertices")

        -- positive winding keeps the body inside; negative winding keeps it outside
        local signed_area = polyline_get_signed_area(closed_contour)
        log_assert(math.abs(signed_area) > math_eps,
            "In boob_set_collision_contours: contour must enclose an area")

        local orientation = polyline_get_orientation(closed_contour)
        local vertices = polyline_get_vertices(closed_contour)
        local edges = {}
        local n_edges = 0

        for vertex_i = 1, n_corners do
            local next_vertex_i = vertex_i % n_corners + 1
            local ai = (vertex_i - 1) * 2 + 1
            local bi = (next_vertex_i - 1) * 2 + 1
            local x1, y1 = vertices[ai + 0], vertices[ai + 1]
            local x2, y2 = vertices[bi + 0], vertices[bi + 1]

            local dx = x2 - x1
            local dy = y2 - y1
            local length_squared = dx * dx + dy * dy

            if length_squared > eps_squared then
                local length = math.sqrt(length_squared)
                n_edges = n_edges + 1
                local base = _edge_i_to_data_offset(n_edges)

                edges[base + _edge_x1_offset] = x1
                edges[base + _edge_y1_offset] = y1
                edges[base + _edge_dx_offset] = dx
                edges[base + _edge_dy_offset] = dy
                edges[base + _edge_inverse_length_squared_offset] = 1 / length_squared
                edges[base + _edge_normal_x_offset] = orientation * dy / length
                edges[base + _edge_normal_y_offset] = -orientation * dx / length
                edges[base + _edge_inverse_dy_offset] = dy ~= 0 and 1 / dy or 0
            end
        end

        log_assert(n_edges >= 3, "In boob_set_collision_contours: need at least 3 non-degenerate edges")

        local collision_contour = {
            polyline = closed_contour,
            edges = edges,
            n_edges = n_edges,
            keep_outside = orientation < 0,
            lambdas = {}
        }

        for particle_i = 1, self.n_particles do
            collision_contour.lambdas[particle_i] = 0
        end

        table_push(self.collision_contours, collision_contour)
    end

    return self
end

boob_draw = function(self)
    log_typecheck(self, Boob_t)

    if boob_is_initialized(self) ~= true then
        log_warning("In boob_draw: trying to draw instance before `boob_init` was called")
        return
    end

    graphics_push_state()

    graphics_set_color(1, 1, 1, 1)
    graphics_set_line_state(_settings_draw_line_width)

    graphics_draw_mesh(self.mesh)
    love.graphics.line(polyline_get_vertices(self.draw_contour))

    graphics_pop_state()

    return self
end

do -- boob_update
    local function _enforce_polygon_collision(
        position_x, position_y, inverse_mass,
        radius,
        edges, n_edges,
        alpha,
        lambda_before,
        keep_outside
    )
        if inverse_mass <= 0 or n_edges == 0 then
            return 0, 0, lambda_before
        end

        local min_dist_squared = math.huge
        local best_cx, best_cy = position_x, position_y
        local best_nx, best_ny = 0, 0
        local inside = false

        for edge_i = 1, n_edges do
            local i = _edge_i_to_data_offset(edge_i)
            local x1 = edges[i + _edge_x1_offset]
            local y1 = edges[i + _edge_y1_offset]
            local dx = edges[i + _edge_dx_offset]
            local dy = edges[i + _edge_dy_offset]
            local inverse_length_squared = edges[i + _edge_inverse_length_squared_offset]

            -- closest point on the edge segment
            local px = position_x - x1
            local py = position_y - y1
            local t = (px * dx + py * dy) * inverse_length_squared
            if t < 0 then t = 0 elseif t > 1 then t = 1 end

            local cx = x1 + t * dx
            local cy = y1 + t * dy
            local distance_x = position_x - cx
            local distance_y = position_y - cy
            local distance_squared = distance_x * distance_x + distance_y * distance_y

            if distance_squared < min_dist_squared then
                min_dist_squared = distance_squared
                best_cx, best_cy = cx, cy
                best_nx = edges[i + _edge_normal_x_offset]
                best_ny = edges[i + _edge_normal_y_offset]
            end

            -- even-odd point-in-polygon test
            local y2 = y1 + dy
            if ((y1 > position_y) ~= (y2 > position_y))
                and (position_x < x1 + (position_y - y1) * dx * edges[i + _edge_inverse_dy_offset])
            then
                inside = not inside
            end
        end

        local distance = math.sqrt(min_dist_squared)
        local signed_distance
        local normal_x, normal_y

        if keep_outside then
            signed_distance = inside and -distance or distance
            normal_x, normal_y = best_nx, best_ny
        else
            signed_distance = inside and distance or -distance

            if inside and distance > math_eps then
                normal_x = (position_x - best_cx) / distance
                normal_y = (position_y - best_cy) / distance
            else
                normal_x, normal_y = -best_nx, -best_ny
            end
        end

        local constraint = signed_distance - radius
        if constraint >= 0 then
            return 0, 0, lambda_before
        end

        local denominator = inverse_mass + alpha
        if denominator < math_eps then
            return 0, 0, lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = math.max(lambda_before + delta_lambda, 0)
        delta_lambda = lambda_new - lambda_before

        local correction_x = inverse_mass * delta_lambda * normal_x
        local correction_y = inverse_mass * delta_lambda * normal_y

        return correction_x, correction_y, lambda_new
    end

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

        return position_new_x, position_new_y,
        world_velocity_new_x, world_velocity_new_y,
        previous_x, previous_y
    end

    local function _enforce_exact_distance(
        ax, ay, bx, by,
        inverse_mass_a, inverse_mass_b,
        target_distance,
        alpha,
        lambda_before
    )
        local delta_x = bx - ax
        local delta_y = by - ay

        local length = math.sqrt(delta_x^2 + delta_y^2)

        if length < math_eps then
            return 0, 0, 0, 0, lambda_before
        end

        local normal_x, normal_y = delta_x / length, delta_y / length

        local constraint = length - target_distance
        local weight_sum = inverse_mass_a + inverse_mass_b
        local denominator = weight_sum + alpha

        if denominator < math_eps then
            return 0, 0, 0, 0, lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = lambda_before + delta_lambda

        local correction_ax = inverse_mass_a * delta_lambda * (-normal_x)
        local correction_ay = inverse_mass_a * delta_lambda * (-normal_y)
        local correction_bx = inverse_mass_b * delta_lambda * normal_x
        local correction_by = inverse_mass_b * delta_lambda * normal_y

        return correction_ax, correction_ay,
        correction_bx, correction_by,
        lambda_new
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

        if length < math_eps then
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

        local wa = 0.5 + k
        local wb = -1.0
        local wc = 0.5 - k

        local weight_sum =
        inverse_mass_a * wa * wa
            + inverse_mass_b * wb * wb
            + inverse_mass_c * wc * wc

        local denominator = weight_sum + alpha

        if denominator < math_eps then
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
        target_velocity, -- radians / s, positive for clockwise, negative for counter clockwise
        sub_delta,
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

        if mass_sum < math_eps then
            return lambda_before
        end

        com_x = com_x / mass_sum
        com_y = com_y / mass_sum

        local angular_momentum = 0 -- sum m * (r x dx), achieved this step
        local inertia = 0          -- sum m * |r|^2
        local weight_sum = 0

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)

            local m = particles[i + _mass_offset]
            local inverse_mass = particles[i + _inverse_mass_offset]

            local rx = particles[i + _previous_x_offset] - com_x
            local ry = particles[i + _previous_y_offset] - com_y

            local dx = particles[i + _x_offset] - particles[i + _previous_x_offset]
            local dy = particles[i + _y_offset] - particles[i + _previous_y_offset]

            angular_momentum = angular_momentum + m * (rx * dy - ry * dx)
            inertia = inertia + m * (rx * rx + ry * ry)

            local gx, gy = -m * ry, m * rx
            weight_sum = weight_sum + inverse_mass * (gx * gx + gy * gy)
        end

        local denominator = weight_sum + alpha

        if denominator < math_eps then
            return lambda_before
        end

        local constraint = angular_momentum - inertia * target_velocity * sub_delta

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = lambda_before + delta_lambda

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)

            local m = particles[i + _mass_offset]
            local inverse_mass = particles[i + _inverse_mass_offset]

            local rx = particles[i + _previous_x_offset] - com_x
            local ry = particles[i + _previous_y_offset] - com_y

            particles[i + _x_offset] = particles[i + _x_offset]
                + inverse_mass * delta_lambda * (-m * ry)

            particles[i + _y_offset] = particles[i + _y_offset]
                + inverse_mass * delta_lambda * (m * rx)
        end

        return lambda_new
    end

    local function _enforce_volume(
        particles, n_particles,
        gradient,
        rest_area,
        alpha,
        lambda_before
    )
        local current_area = 0
        local weight_sum = 0.0

        local previous_ai = _particle_i_to_data_offset(n_particles)
        local current_ai = _particle_i_to_data_offset(1)

        for particle_i = 1, n_particles do
            local next_ai = _particle_i_to_data_offset(particle_i + 1, n_particles)

            local previous_x = particles[previous_ai + _x_offset]
            local previous_y = particles[previous_ai + _y_offset]

            local current_x = particles[current_ai + _x_offset]
            local current_y = particles[current_ai + _y_offset]

            local next_x = particles[next_ai + _x_offset]
            local next_y = particles[next_ai + _y_offset]

            current_area = current_area
                + 0.5 * (current_x * next_y - next_x * current_y)

            local grad_x = 0.5 * (next_y - previous_y)
            local grad_y = 0.5 * (previous_x - next_x)

            local gi = 2 * particle_i - 1
            gradient[gi + 0] = grad_x
            gradient[gi + 1] = grad_y

            local inverse_mass = particles[current_ai + _inverse_mass_offset]

            weight_sum = weight_sum
                + inverse_mass * (grad_x * grad_x + grad_y * grad_y)

            previous_ai = current_ai
            current_ai = next_ai
        end

        local constraint = current_area - rest_area

        local denominator = weight_sum + alpha

        if denominator < math_eps then
            return lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = lambda_before + delta_lambda

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local inverse_mass = particles[i + _inverse_mass_offset]

            local gi = 2 * particle_i - 1

            particles[i + _x_offset] = particles[i + _x_offset]
                + inverse_mass * delta_lambda * gradient[gi + 0]

            particles[i + _y_offset] = particles[i + _y_offset]
                + inverse_mass * delta_lambda * gradient[gi + 1]
        end

        return lambda_new
    end

    local function _post_solve(
        position_x, position_y,
        previous_x, previous_y,
        delta
    )
        local x = position_x
        local y = position_y

        local velocity_x = (x - previous_x) / delta
        local velocity_y = (y - previous_y) / delta

        return x, y, velocity_x, velocity_y
    end

    boob_update = function(self, delta_in)
        log_typecheck(self, Boob_t, delta_in, Number_t)

        local timestep = _settings_timestep
        local sub_delta = timestep / _settings_n_sub_steps

        local damping = _settings_damping
        local n_sub_steps = _settings_n_sub_steps
        local n_constraint_iterations = _settings_n_constraint_iterations

        local volume_alpha = _settings_volume_compliance / (sub_delta^2)
        local line_alpha = _settings_line_compliance / (sub_delta^2)
        local distance_alpha = _settings_distance_compliance / (sub_delta^2)
        local bending_alpha = _settings_bending_compliance / (sub_delta^2)
        local angular_alpha = _settings_angular_compliance / (sub_delta^2)

        local ps = self.particles
        local n_particles = self.n_particles
        local segment_length = self.segment_length
        local collision_contours = self.collision_contours
        local n_collision_contours = #collision_contours

        local gravity_direction_x, gravity_direction_y = 0, 1
        local gravity = _settings_gravity

        self.elapsed = self.elapsed + delta_in
        local n_steps = 0
        while self.elapsed >= timestep and n_steps < _settings_max_n_steps do
            self.elapsed = self.elapsed - timestep
            n_steps = n_steps + 1

            -- snapshot for frame interpolation
            for particle_i = 1, n_particles do
                local i = _particle_i_to_data_offset(particle_i)
                ps[i + _snapshot_x_offset] = ps[i + _x_offset]
                ps[i + _snapshot_y_offset] = ps[i + _y_offset]
            end

            for _ = 1, n_sub_steps do
                -- reset polygon collision lambdas
                for contour_i = 1, n_collision_contours do
                    local lambdas = collision_contours[contour_i].lambdas
                    for particle_i = 1, n_particles do
                        lambdas[particle_i] = 0
                    end
                end

                -- pre solve
                for particle_i = 1, n_particles do
                    local i = _particle_i_to_data_offset(particle_i)

                    local new_position_x, new_position_y,
                    new_velocity_x, new_velocity_y,
                    previous_x, previous_y = _pre_solve(
                        ps[i + _x_offset],
                        ps[i + _y_offset],
                        ps[i + _velocity_x_offset],
                        ps[i + _velocity_y_offset],
                        ps[i + _mass_offset],
                        gravity_direction_x * gravity,
                        gravity_direction_y * gravity,
                        damping,
                        sub_delta
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

                self.volume_lambda = 0
                self.angular_lambda = 0

                for _ = 1, n_constraint_iterations do
                    -- distance: pair wise
                    for particle_i = 1, n_particles do
                        local ai = _particle_i_to_data_offset(particle_i)
                        local bi = _particle_i_to_data_offset(particle_i + 1, n_particles)

                        local correction_ax, correction_ay,
                        correction_bx, correction_by,
                        lambda_new = _enforce_exact_distance(
                            ps[ai + _x_offset], ps[ai + _y_offset],
                            ps[bi + _x_offset], ps[bi + _y_offset],
                            ps[ai + _inverse_mass_offset],
                            ps[bi + _inverse_mass_offset],
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
                    for particle_i = 1, n_particles do
                        local ai = _particle_i_to_data_offset(particle_i)
                        local bi = _particle_i_to_data_offset(particle_i + 1, n_particles)
                        local ci = _particle_i_to_data_offset(particle_i + 2, n_particles)

                        local correction_ax, correction_ay,
                        correction_bx, correction_by,
                        correction_cx, correction_cy,
                        lambda_new = _enforce_bending(
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
                    self.volume_lambda = _enforce_volume(
                        ps, n_particles,
                        self.volume_gradient,
                        self.volume,
                        volume_alpha,
                        self.volume_lambda
                    )

                    -- rotation
                    self.angular_lambda = _enforce_angular_momentum(
                        ps, n_particles,
                        self.angular_velocity, sub_delta,
                        angular_alpha,
                        self.angular_lambda
                    )
                end

                -- polygon collision
                for _ = 1, n_constraint_iterations do
                    for contour_i = 1, n_collision_contours do
                        local collision_contour = collision_contours[contour_i]
                        local edges = collision_contour.edges
                        local n_edges = collision_contour.n_edges
                        local keep_outside = collision_contour.keep_outside
                        local lambdas = collision_contour.lambdas

                        for particle_i = 1, n_particles do
                            local i = _particle_i_to_data_offset(particle_i)
                            local correction_x, correction_y, lambda_new = _enforce_polygon_collision(
                                ps[i + _x_offset], ps[i + _y_offset],
                                ps[i + _inverse_mass_offset],
                                ps[i + _radius_offset],
                                edges, n_edges,
                                line_alpha,
                                lambdas[particle_i],
                                keep_outside
                            )

                            ps[i + _x_offset] = ps[i + _x_offset] + correction_x
                            ps[i + _y_offset] = ps[i + _y_offset] + correction_y
                            lambdas[particle_i] = lambda_new
                        end
                    end
                end

                -- post solve
                for particle_i = 1, n_particles do
                    local i = _particle_i_to_data_offset(particle_i)
                    local x, y = ps[i + _x_offset], ps[i + _y_offset]

                    local new_position_x, new_position_y,
                    new_velocity_x, new_velocity_y = _post_solve(
                        x, y,
                        ps[i + _previous_x_offset],
                        ps[i + _previous_y_offset],
                        sub_delta
                    )

                    ps[i + _x_offset] = new_position_x
                    ps[i + _y_offset] = new_position_y
                    ps[i + _velocity_x_offset] = new_velocity_x
                    ps[i + _velocity_y_offset] = new_velocity_y
                end
            end
        end

        -- calculate mesh centroid
        local alpha = self.elapsed / timestep
        local mesh_centroid_x, mesh_centroid_y = 0, 0

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)

            local prev_x, prev_y = ps[i + _snapshot_x_offset], ps[i + _snapshot_y_offset]
            local curr_x, curr_y = ps[i + _x_offset], ps[i + _y_offset]

            local x = prev_x + (curr_x - prev_x) * alpha
            local y = prev_y + (curr_y - prev_y) * alpha

            ps[i + _draw_x_offset] = x
            ps[i + _draw_y_offset] = y

            mesh_centroid_x = mesh_centroid_x + x
            mesh_centroid_y = mesh_centroid_y + y
        end

        mesh_centroid_x = mesh_centroid_x / n_particles
        mesh_centroid_y = mesh_centroid_y / n_particles

        -- update mesh
        local mesh_data = self.mesh_data

        for particle_i = 1, n_particles do
            local ai = _particle_i_to_data_offset(particle_i)
            local bi = _particle_i_to_data_offset(particle_i + 1, n_particles)

            local ax, ay = ps[ai + _draw_x_offset], ps[ai + _draw_y_offset]
            local bx, by = ps[bi + _draw_x_offset], ps[bi + _draw_y_offset]

            local mesh_i = (particle_i - 1) * 3 + 1

            mesh_data[mesh_i + 0][1] = mesh_centroid_x
            mesh_data[mesh_i + 0][2] = mesh_centroid_y

            mesh_data[mesh_i + 1][1] = ax
            mesh_data[mesh_i + 1][2] = ay

            mesh_data[mesh_i + 2][1] = bx
            mesh_data[mesh_i + 2][2] = by
        end

        self.mesh:setVertices(mesh_data)

        -- update draw contour
        local contour_vertices = polyline_get_vertices(self.draw_contour)

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local contour_i = (particle_i - 1) * 2 + 1

            contour_vertices[contour_i + 0] = ps[i + _x_offset]
            contour_vertices[contour_i + 1] = ps[i + _y_offset]
        end

        contour_vertices[n_particles * 2 + 1] = contour_vertices[1]
        contour_vertices[n_particles * 2 + 2] = contour_vertices[2]

        return self
    end
end