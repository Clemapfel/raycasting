local _settings_timestep = 1 / 60
local _settings_max_n_steps = 4

local _settings_n_sub_steps = 4
local _settings_n_constraint_iterations = 4

local _settings_distance_compliance = 2e-6
local _settings_volume_compliance = 1e-7
local _settings_collision_contour_compliance = 0
local _settings_bending_compliance = 1e-5
local _settings_angular_compliance = 1e-5
local _settings_linear_compliance = 1e-5
local _settings_particle_collision_compliance = 0

local _settings_damping = 0.9998
local _settings_gravity = 5000

local _settings_texture_zoom = 1 / 0.9

local _math_cross = math_cross
local _math_dot = math_dot
local _math_normalize = math_normalize
local _math_sign = math_sign
local _math_wrap = math_wrap
local _math_eps = math_eps
local _math_inf = math_inf

local _table_new = table_new
local _table_push = table_push
local _table_clear = table_clear

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

SoftBody_t = "SoftBody"

softbody_new = function(...)
    local self = object_new(SoftBody_t, {
        is_initialized = false
    })

    if select("#", ...) > 0 then
        return softbody_init(self, ...)
    else
        return self
    end
end

softbody_init = function(self, center_x, center_y, radius, n_contour_nodes)
    log_typecheck(
        self, SoftBody_t,
        center_x, Float_t,
        center_y, Float_t,
        radius, Float_t,
        n_contour_nodes, Integer_t
    )

    local cos, sin, tau, pi = math_cos, math_sin, math_tau, math_pi

    -- particles
    log_assert(n_contour_nodes >= 5, "In softbody_init: need at least 5 contour nodes")

    local n_particles = n_contour_nodes
    local data = _table_new(n_particles * _stride)

    for particle_i = 1, n_contour_nodes do
        local angle = (particle_i - 1) / n_contour_nodes * tau
        local px = center_x + radius * cos(angle)
        local py = center_y + radius * sin(angle)
        local mass = 1

        local base = _particle_i_to_data_offset(particle_i)

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
    end

    -- volume
    local area = 0

    for particle_i = 1, n_particles do
        local ai = _particle_i_to_data_offset(particle_i, n_particles)
        local bi = _particle_i_to_data_offset(particle_i + 1, n_particles)

        local ax, ay = data[ai + _x_offset], data[ai + _y_offset]
        local bx, by = data[bi + _x_offset], data[bi + _y_offset]

        area = area + 0.5 * _math_cross(ax, ay, bx, by)
    end

    local segment_length = 2 * radius * sin(pi / n_particles)
    local rest_area = area

    -- drawing
    local mesh_data = _table_new(3 * n_particles)
    local draw_contour = _table_new(2 * n_particles + 2)
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

        _table_push(mesh_data, { center_x, center_y, 0.5, 0.5, 1, 1, 1, 1 })
        _table_push(mesh_data, { ax, ay, u_a, v_a, 1, 1, 1, 1 })
        _table_push(mesh_data, { bx, by, u_b, v_b, 1, 1, 1, 1 })

        _table_push(draw_contour, ax)
        _table_push(draw_contour, ay)
    end

    _table_push(draw_contour, draw_contour[1])
    _table_push(draw_contour, draw_contour[2])

    local mesh = mesh_new(mesh_data, GraphicsBufferUsage.STREAM)

    self.particles = data
    self.n_particles = n_particles

    self.volume = rest_area
    self.volume_multiplier = 1.0

    self.volume_lambda = 0
    self.angular_lambda = 0
    self.linear_lambda_x = 0
    self.linear_lambda_y = 0
    self.segment_length = segment_length

    self.volume_gradient = _table_new(2 * n_particles)
    for particle_i = 1, n_particles do
        self.volume_gradient[2 * particle_i - 1] = 0
        self.volume_gradient[2 * particle_i] = 0
    end

    self.collision_contours = _table_new(0)

    self.mesh = mesh
    self.mesh_data = mesh_data
    self.draw_contour = polyline_close(polyline_new(draw_contour))

    -- control
    self.linear_velocity_x = 0
    self.linear_velocity_y = 0
    self.angular_velocity = 0

    self.is_initialized = true
    self.elapsed = 0

    return self
end

softbody_is_initialized = function(self)
    return object_isa(self, SoftBody_t) and self.is_initialized == true
end

softbody_set_collision_contours = function(self, contours)
    log_typecheck(self, SoftBody_t, contours, Table_t)

    local eps_squared = _math_eps * _math_eps
    local abs = math.abs
    _table_clear(self.collision_contours)

    for i = 1, #contours do
        local contour = contours[i]
        log_typecheck_arg_i(contour, Polyline_t, i)

        local closed_contour = polyline_close(contour)
        local n_corners = polyline_get_n_nodes(closed_contour)

        log_assert(n_corners >= 3, "In softbody_set_collision_contours: need at least 3 vertices")

        local signed_area = polyline_get_signed_area(closed_contour)
        log_assert(abs(signed_area) > _math_eps, "In softbody_set_collision_contours: contour must enclose an area")

        local orientation = _math_sign(signed_area)
        local vertices = polyline_get_vertices(closed_contour)
        local edges = _table_new(n_corners * _edge_stride)
        local n_edges = 0

        for vertex_i = 1, n_corners do
            local next_vertex_i = _math_wrap(vertex_i + 1, n_corners)
            local ai = (vertex_i - 1) * 2 + 1
            local bi = (next_vertex_i - 1) * 2 + 1
            local x1, y1 = vertices[ai + 0], vertices[ai + 1]
            local x2, y2 = vertices[bi + 0], vertices[bi + 1]

            local dx = x2 - x1
            local dy = y2 - y1
            local length_squared = _math_dot(dx, dy, dx, dy)

            if length_squared > eps_squared then
                local normal_x, normal_y = _math_normalize(orientation * dy, -orientation * dx)
                n_edges = n_edges + 1
                local base = _edge_i_to_data_offset(n_edges)

                edges[base + _edge_x1_offset] = x1
                edges[base + _edge_y1_offset] = y1
                edges[base + _edge_dx_offset] = dx
                edges[base + _edge_dy_offset] = dy
                edges[base + _edge_inverse_length_squared_offset] = 1 / length_squared
                edges[base + _edge_normal_x_offset] = normal_x
                edges[base + _edge_normal_y_offset] = normal_y
                edges[base + _edge_inverse_dy_offset] = dy ~= 0 and 1 / dy or 0
            end
        end

        log_assert(n_edges >= 3, "In softbody_set_collision_contours: need at least 3 non-degenerate edges")

        local collision_contour = {
            contour = closed_contour,
            edges = edges,
            n_edges = n_edges,
            lambdas = table_rep(0, self.n_particles)
        }

        for particle_i = 1, self.n_particles do
            collision_contour.lambdas[particle_i] = 0
        end

        _table_push(self.collision_contours, collision_contour)
    end

    return self
end

softbody_set_texture = function(self, texture)
    log_typecheck_arg_i(self, SoftBody_t, texture, Texture_t)
    self.mesh_texture = texture
    mesh_set_texture(self.mesh, texture)
end

softbody_get_contour = function(self)
    log_typecheck(self, SoftBody_t)

    local contour = _table_new(2 * self.n_particles)
    local data = self.particles
    for particle_i = 1, self.n_particles, 1 do -- clockwise winding
        local i = _particle_i_to_data_offset(particle_i)
        _table_push(contour, data[i + _x_offset])
        _table_push(contour, data[i + _y_offset])
    end

    return polyline_new(contour)
end

softbody_get_draw_contour = function(self)
    return self.draw_contour
end

softbody_get_draw_mesh = function(self)
    return self.mesh
end

do -- softbody_update
    local sqrt = math.sqrt
    local max = math.max
    local huge = _math_inf
    local eps = _math_eps
    local dot = math_dot
    local cross = math_cross
    local magnitude = math_magnitude
    local distance = math_distance
    local normalize = math_normalize
    local clamp = math_clamp
    local mix = math_mix

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

        local min_dist_squared = huge
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

            local px = position_x - x1
            local py = position_y - y1
            local t = clamp(dot(px, py, dx, dy) * inverse_length_squared, 0, 1)

            local cx = x1 + t * dx
            local cy = y1 + t * dy
            local distance_x = position_x - cx
            local distance_y = position_y - cy
            local distance_squared = dot(distance_x, distance_y, distance_x, distance_y)

            if distance_squared < min_dist_squared then
                min_dist_squared = distance_squared
                best_cx, best_cy = cx, cy
                best_nx = edges[i + _edge_normal_x_offset]
                best_ny = edges[i + _edge_normal_y_offset]
            end

            local y2 = y1 + dy
            if ((y1 > position_y) ~= (y2 > position_y))
                and (position_x < x1 + (position_y - y1) * dx * edges[i + _edge_inverse_dy_offset])
            then
                inside = not inside
            end
        end

        local distance = sqrt(min_dist_squared)
        local signed_distance
        local normal_x, normal_y

        if keep_outside then
            signed_distance = inside and -distance or distance
            normal_x, normal_y = best_nx, best_ny
        else
            signed_distance = inside and distance or -distance

            if inside and distance > eps then
                normal_x, normal_y = normalize(position_x - best_cx, position_y - best_cy)
            else
                normal_x, normal_y = -best_nx, -best_ny
            end
        end

        local constraint = signed_distance - radius
        if constraint >= 0 then
            return 0, 0, lambda_before
        end

        local denominator = inverse_mass + alpha
        if denominator < eps then
            return 0, 0, lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = max(lambda_before + delta_lambda, 0)
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
        local length = distance(ax, ay, bx, by)

        if length < eps then
            return 0, 0, 0, 0, lambda_before
        end

        local normal_x, normal_y = (bx - ax) / length, (by - ay) / length

        local constraint = length - target_distance
        local weight_sum = inverse_mass_a + inverse_mass_b
        local denominator = weight_sum + alpha

        if denominator < eps then
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

        local length = magnitude(chord_x, chord_y)

        if length < eps then
            return 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, lambda_before
        end

        local inv_length = 1.0 / length
        local tx, ty = chord_x * inv_length, chord_y * inv_length
        local nx, ny = -ty, tx

        local ex = mix(ax, cx, 0.5) - bx
        local ey = mix(ay, cy, 0.5) - by

        local constraint = dot(ex, ey, nx, ny)

        local k = dot(ex, ey, tx, ty) * inv_length

        local wa = 0.5 + k
        local wb = -1.0
        local wc = 0.5 - k

        local weight_sum =
        inverse_mass_a * wa * wa
            + inverse_mass_b * wb * wb
            + inverse_mass_c * wc * wc

        local denominator = weight_sum + alpha

        if denominator < eps then
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

        if mass_sum < eps then
            return lambda_before
        end

        com_x = com_x / mass_sum
        com_y = com_y / mass_sum

        local angular_momentum = 0
        local inertia = 0
        local weight_sum = 0

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)

            local m = particles[i + _mass_offset]
            local inverse_mass = particles[i + _inverse_mass_offset]

            local rx = particles[i + _previous_x_offset] - com_x
            local ry = particles[i + _previous_y_offset] - com_y

            local dx = particles[i + _x_offset] - particles[i + _previous_x_offset]
            local dy = particles[i + _y_offset] - particles[i + _previous_y_offset]

            angular_momentum = angular_momentum + m * cross(rx, ry, dx, dy)
            inertia = inertia + m * dot(rx, ry, rx, ry)

            local gx, gy = -m * ry, m * rx
            weight_sum = weight_sum + inverse_mass * dot(gx, gy, gx, gy)
        end

        local denominator = weight_sum + alpha

        if denominator < eps then
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

    local function _enforce_linear_momentum(
        particles, n_particles,
        target_velocity_x, target_velocity_y,
        sub_delta,
        alpha,
        lambda_x_before, lambda_y_before
    )
        local mass_sum = 0
        local weight_sum = 0
        local momentum_x, momentum_y = 0, 0

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local m = particles[i + _mass_offset]

            mass_sum = mass_sum + m
            weight_sum = weight_sum + particles[i + _inverse_mass_offset] * m * m

            momentum_x = momentum_x + m * (particles[i + _x_offset] - particles[i + _previous_x_offset])
            momentum_y = momentum_y + m * (particles[i + _y_offset] - particles[i + _previous_y_offset])
        end

        local denominator = weight_sum + alpha
        if mass_sum < eps or denominator < eps then
            return lambda_x_before, lambda_y_before
        end

        local delta_lambda_x, delta_lambda_y = 0, 0
        local lambda_x_new, lambda_y_new = lambda_x_before, lambda_y_before

        if target_velocity_x ~= nil then
            local constraint = momentum_x - mass_sum * target_velocity_x * sub_delta
            delta_lambda_x = -(constraint + alpha * lambda_x_before) / denominator
            lambda_x_new = lambda_x_before + delta_lambda_x
        end

        if target_velocity_y ~= nil then
            local constraint = momentum_y - mass_sum * target_velocity_y * sub_delta
            delta_lambda_y = -(constraint + alpha * lambda_y_before) / denominator
            lambda_y_new = lambda_y_before + delta_lambda_y
        end

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local m = particles[i + _mass_offset]
            local inverse_mass = particles[i + _inverse_mass_offset]

            particles[i + _x_offset] = particles[i + _x_offset] + inverse_mass * delta_lambda_x * m
            particles[i + _y_offset] = particles[i + _y_offset] + inverse_mass * delta_lambda_y * m
        end

        return lambda_x_new, lambda_y_new
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

            -- shoelace formula
            current_area = current_area
                + 0.5 * cross(current_x, current_y, next_x, next_y)

            local grad_x = 0.5 * (next_y - previous_y)
            local grad_y = 0.5 * (previous_x - next_x)

            local gi = 2 * particle_i - 1
            gradient[gi + 0] = grad_x
            gradient[gi + 1] = grad_y

            local inverse_mass = particles[current_ai + _inverse_mass_offset]

            weight_sum = weight_sum
                + inverse_mass * dot(grad_x, grad_y, grad_x, grad_y)

            previous_ai = current_ai
            current_ai = next_ai
        end

        local constraint = current_area - rest_area

        local denominator = weight_sum + alpha

        if denominator < eps then
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

    softbody_update = function(self, delta_in)
        log_typecheck(self, SoftBody_t, delta_in, Number_t)

        local timestep = _settings_timestep
        local sub_delta = timestep / _settings_n_sub_steps

        local damping = _settings_damping
        local n_sub_steps = _settings_n_sub_steps
        local n_constraint_iterations = _settings_n_constraint_iterations

        local volume_alpha = _settings_volume_compliance / (sub_delta * sub_delta)
        local line_alpha = _settings_collision_contour_compliance / (sub_delta * sub_delta)
        local distance_alpha = _settings_distance_compliance / (sub_delta * sub_delta)
        local bending_alpha = _settings_bending_compliance / (sub_delta * sub_delta)
        local angular_alpha = _settings_angular_compliance / (sub_delta * sub_delta)
        local linear_alpha = _settings_linear_compliance / (sub_delta * sub_delta)

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
                self.linear_lambda_x = 0
                self.linear_lambda_y = 0

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

                    self.linear_lambda_x, self.linear_lambda_y = _enforce_linear_momentum(
                        ps, n_particles,
                        self.linear_velocity_x, self.linear_velocity_y,
                        sub_delta,
                        linear_alpha,
                        self.linear_lambda_x, self.linear_lambda_y
                    )
                end

                -- polygon collision
                for _ = 1, n_constraint_iterations do
                    for contour_i = 1, n_collision_contours do
                        local entry = collision_contours[contour_i]
                        local edges = entry.edges
                        local n_edges = entry.n_edges
                        local lambdas = entry.lambdas

                        for particle_i = 1, n_particles do
                            local i = _particle_i_to_data_offset(particle_i)
                            local correction_x, correction_y, lambda_new = _enforce_polygon_collision(
                                ps[i + _x_offset], ps[i + _y_offset],
                                ps[i + _inverse_mass_offset],
                                ps[i + _radius_offset],
                                edges, n_edges,
                                line_alpha,
                                lambdas[particle_i],
                                polyline_get_winding(entry.contour)
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

        mesh_update_vertices(self.mesh, mesh_data)

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

softbody_set_target_linear_velocity = function(self, dx, dy)
    log_typecheck(self, SoftBody_t, dx, Number_t, dy, Number_t)
    self.linear_velocity_x = dx
    self.linear_velocity_y = dy
    self.linear_lambda_x = 0
    self.linear_lambda_y = 0
end

softbody_get_target_linear_velocity = function(self)
    log_typecheck(self, SoftBody_t)
    return self.linear_velocity_x, self.linear_velocity_y
end

softbody_set_target_angular_velocity = function(self, dtheta) -- signed radians / s
    log_typecheck(self, SoftBody_t, dtheta, Number_t)
    self.angular_velocity = dtheta
    self.angular_lambda = 0
end

softbody_get_target_angular_velocity = function(self)
    log_typecheck(self, SoftBody_t)
    return self.angular_velocity
end

softbody_set_target_volume = function(self, fraction) -- fraction
    log_typecheck(self, SoftBody_t, fraction, Number_t)
    self.volume_multiplier = fraction
    self.volume_lambda = 0
end

softbody_get_target_volume = function(self)
    log_typecheck(self, SoftBody_t)
    return self.volume_multiplier
end

