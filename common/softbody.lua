local _settings_timestep = 1 / 60
local _settings_max_n_steps = 4

local _settings_n_sub_steps = 4
local _settings_n_constraint_iterations = 4

local _settings_default_static_friction = 0.7
local _settings_default_kinetic_friction = 0.5

local _settings_default_distance_compliance = 1e-7
local _settings_default_volume_compliance = 0
local _settings_default_collision_contour_compliance = 0
local _settings_default_bending_compliance = 4e-6
local _settings_default_angular_velocity_compliance = 0
local _settings_default_linear_velocity_compliance = 1e-5
local _settings_default_particle_collision_compliance = 0
local _settings_default_anchor_compliance = 0

local _settings_damping = 0.9998
local _settings_texture_zoom = 1 / 0.9

local _math_cross = math.cross
local _math_dot = math.dot
local _math_normalize = math.normalize
local _math_sign = math.sign
local _math_wrap = math.wrap
local _math_eps = math.eps
local _math_inf = math.huge

local _table_new = function(n) return table.new(n, 0) end
local _table_push = table.insert
local _table_clear = table.clear
local _table_rep = table.rep

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
local _segment_length_offset = 13
local _distance_lambda_offset = 14
local _bending_lambda_offset = 15
local _polygon_lambda_offset = 16

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

--- @class rt.Softbody
rt.Softbody = meta.class("Softbody")

local config_schema = meta.Schema({
    volume_compliance = mt.Optional(mt.Number),
    contour_compliance = mt.Optional(mt.Number),
    distance_compliance = mt.Optional(mt.Number),
    bending_compliance = mt.Optional(mt.Number),
    angular_velocity_compliance = mt.Optional(mt.Number),
    linear_velocity_compliance = mt.Optional(mt.Number),
    anchor_compliance = mt.Optional(mt.Number),
    static_friction = mt.Optional(mt.Number),
    kinetic_friction = mt.Optional(mt.Number)
})

function rt.Softbody:instantiate(...)
    self.is_initialized = false
    self._settings_override = {}

    if select("#", ...) > 0 then
        self:initialize(...)
    end
end

function rt.Softbody:initialize(nodes)
    meta.typecheck(nodes, rt.Polyline)
    rt.assert(#nodes % 2 == 0, "In rt.Softbody.initialize: expected flat list of 2d points")

    local cos, sin, tau, pi = math.cos, math.sin, math.tau, math.pi

    local n_particles = nodes:get_n_vertices()
    local data = _table_new(n_particles * _stride)

    local arc_length = function(cx, cy, x1, y1, x2, y2)
        -- approximate path length using circular arc
        local dx1, dy1 = x1 - cx, y1 - cy
        local dx2, dy2 = x2 - cx, y2 - cy

        local r = math.magnitude(dx1, dy1)
        local a1 = math.angle(dx1, dy1)
        local a2 = math.angle(dx2, dy2)
        local dtheta = math.normalize_angle(a2 - a1)
        return r * dtheta
    end

    local cx, cy = nodes:get_centroid()

    for particle_i = 1, n_particles do
        local px, py = nodes:get_vertex(particle_i)
        local mass = 1

        local base = _particle_i_to_data_offset(particle_i)

        data[base + _x_offset] = px
        data[base + _y_offset] = py
        data[base + _previous_x_offset] = px
        data[base + _previous_y_offset] = py
        data[base + _snapshot_x_offset] = px
        data[base + _snapshot_y_offset] = py
        data[base + _draw_x_offset] = px
        data[base + _draw_y_offset] = py
        data[base + _velocity_x_offset] = 0
        data[base + _velocity_y_offset] = 0
        data[base + _radius_offset] = 1
        data[base + _mass_offset] = mass
        data[base + _inverse_mass_offset] = 1 / mass
        data[base + _segment_length_offset] = arc_length(
            cx, cy,
            px, py,
            nodes:get_vertex(math.wrap(particle_i, n_particles))
        )
        data[base + _distance_lambda_offset] = 0
        data[base + _bending_lambda_offset] = 0
        data[base + _polygon_lambda_offset] = 0

        assert(#data == particle_i * _stride)
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

    local rest_area = area

    -- drawing
    local draw_contour = _table_new(2 * n_particles + 2)
    for particle_i = 1, n_particles do
        local angle = (particle_i - 1) / n_particles * tau
        local i = _particle_i_to_data_offset(particle_i, n_particles)

        _table_push(draw_contour, data[i + _x_offset])
        _table_push(draw_contour, data[i + _y_offset])
    end

    _table_push(draw_contour, draw_contour[1])
    _table_push(draw_contour, draw_contour[2])

    self.particles = data
    self.n_particles = n_particles
    self.centroid_x = 0
    self.centroid_y = 0

    self.volume = rest_area
    self.volume_multiplier = 1.0

    self.volume_lambda = 0
    self.angular_velocity_lambda = 0
    self.linear_velocity_lambda_x = 0
    self.linear_velocity_lambda_y = 0

    self.rest_angular_velocity = 0

    self.anchor_x = 0
    self.anchor_y = 0
    self.anchor_active = false
    self.anchor_lambda_x = 0
    self.anchor_lambda_y = 0

    self.volume_gradient = _table_new(2 * n_particles)
    for particle_i = 1, n_particles do
        self.volume_gradient[2 * particle_i - 1] = 0
        self.volume_gradient[2 * particle_i] = 0
    end

    self.collision_contours = _table_new(0)

    self.linear_impulses = {}
    self.angular_impulses = {}
    self.linear_forces = {}
    self.angular_forces = {}

    self.gravity_x = 0
    self.gravity_y = 0

    self.draw_contour = rt.Polyline(draw_contour):close()

    -- control
    self.linear_velocity_x = 0
    self.linear_velocity_y = 0
    self.angular_velocity = 0

    self.is_initialized = true
    self.elapsed = 0

    return self
end

function rt.Softbody:is_initialized()
    return self ~= nil and type(self) == "table" and self.is_initialized == true
end

function rt.Softbody:set_collision_contours(contours)
    meta.typecheck(contours, mt.Table)

    local eps_squared = _math_eps * _math_eps
    local abs = math.abs
    _table_clear(self.collision_contours)

    for i = 1, #contours do
        local contour = contours[i]
        meta.typecheck_arg_i(contour, rt.Polyline, i)

        local closed_contour = contour:close()
        local n_corners = closed_contour:get_n_vertices()

        rt.assert(n_corners >= 3, "In rt.Softbody.set_collision_contours: need at least 3 vertices")

        local signed_area = closed_contour:get_signed_area()
        rt.assert(abs(signed_area) > _math_eps, "In rt.Softbody.set_collision_contours: contour must enclose an area")

        local orientation = _math_sign(signed_area)
        local vertices = closed_contour:get_vertices()
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

        rt.assert(n_edges >= 3, "In rt.Softbody.set_collision_contours: need at least 3 non-degenerate edges")

        local collision_contour = {
            contour = closed_contour,
            edges = edges,
            n_edges = n_edges,
            lambdas = _table_rep(0, self.n_particles),
            normals_x = _table_rep(0, self.n_particles),
            normals_y = _table_rep(0, self.n_particles)
        }

        for particle_i = 1, self.n_particles do
            collision_contour.lambdas[particle_i] = 0
        end

        _table_push(self.collision_contours, collision_contour)
    end

    return self
end

function rt.Softbody:get_collision_contours()
    local out = {}
    for entry in values(self.collision_contours) do
        table.insert(out, entry.contour)
    end
    return out
end

function rt.Softbody:get_contour()
    meta.typecheck(self, rt.Softbody)

    local contour = _table_new(2 * self.n_particles)
    local data = self.particles
    for particle_i = 1, self.n_particles, 1 do -- clockwise winding
        local i = _particle_i_to_data_offset(particle_i)
        _table_push(contour, data[i + _x_offset])
        _table_push(contour, data[i + _y_offset])
    end

    return rt.Polyline(contour)
end

function rt.Softbody:get_draw_contour()
    return self.draw_contour
end

do -- rt.Softbody:update
    local sqrt = math.sqrt
    local max = math.max
    local huge = _math_inf
    local eps = _math_eps
    local dot = math.dot
    local cross = math.cross
    local magnitude = math.magnitude
    local distance = math.distance
    local normalize = math.normalize
    local clamp = math.clamp
    local mix = math.mix

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
            return 0, 0, lambda_before, 0, 0
        end

        local denominator = inverse_mass + alpha
        if denominator < eps then
            return 0, 0, lambda_before, 0, 0
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = max(lambda_before + delta_lambda, 0)
        delta_lambda = lambda_new - lambda_before

        local correction_x = inverse_mass * delta_lambda * normal_x
        local correction_y = inverse_mass * delta_lambda * normal_y

        return correction_x, correction_y, lambda_new, normal_x, normal_y
    end

    local function _pre_solve(
        position_x, position_y,
        velocity_x, velocity_y,
        inverse_mass,
        acceleration_x, acceleration_y,
        rest_velocity_x, rest_velocity_y,
        rest_angular_velocity,
        center_x, center_y,
        damping, delta
    )
        local previous_x = position_x
        local previous_y = position_y

        if inverse_mass <= 0 then
            return position_x, position_y, 0, 0, previous_x, previous_y
        end

        local world_velocity_new_x = velocity_x * damping + acceleration_x * delta
        local world_velocity_new_y = velocity_y * damping + acceleration_y * delta

        local rx = position_x - center_x
        local ry = position_y - center_y
        local base_velocity_x = rest_velocity_x - rest_angular_velocity * ry
        local base_velocity_y = rest_velocity_y + rest_angular_velocity * rx

        local position_new_x = position_x + (world_velocity_new_x + base_velocity_x) * delta
        local position_new_y = position_y + (world_velocity_new_y + base_velocity_y) * delta

        return position_new_x, position_new_y,
        world_velocity_new_x, world_velocity_new_y,
        previous_x, previous_y
    end

    local function _get_mass_properties(particles, n_particles)
        local total_mass = 0
        local center_x, center_y = 0, 0

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local inverse_mass = particles[i + _inverse_mass_offset]
            local mass = particles[i + _mass_offset]

            if inverse_mass > 0 and mass > 0 then
                total_mass = total_mass + mass
                center_x = center_x + mass * particles[i + _x_offset]
                center_y = center_y + mass * particles[i + _y_offset]
            end
        end

        if total_mass <= eps then
            return 0, 0, 0, 0
        end

        center_x = center_x / total_mass
        center_y = center_y / total_mass

        local moment_of_inertia = 0
        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local inverse_mass = particles[i + _inverse_mass_offset]
            local mass = particles[i + _mass_offset]

            if inverse_mass > 0 and mass > 0 then
                local rx = particles[i + _x_offset] - center_x
                local ry = particles[i + _y_offset] - center_y
                moment_of_inertia = moment_of_inertia + mass * dot(rx, ry, rx, ry)
            end
        end

        return center_x, center_y, total_mass, moment_of_inertia
    end

    local function _sum_linear_sources(sources)
        local force_x, force_y = 0, 0
        for _, entry in pairs(sources) do
            force_x = force_x + entry.magnitude * entry.dx
            force_y = force_y + entry.magnitude * entry.dy
        end
        return force_x, force_y
    end

    local function _sum_angular_sources(sources, value_key)
        local total = 0
        for _, entry in pairs(sources) do
            total = total + entry[value_key]
        end
        return total
    end

    local function _apply_pending_impulses(self, particles, n_particles)
        local impulse_x, impulse_y = _sum_linear_sources(self.linear_impulses)
        local angular_impulse = _sum_angular_sources(self.angular_impulses, "angular_impulse")

        for id in pairs(self.linear_impulses) do
            self.linear_impulses[id] = nil
        end

        for id in pairs(self.angular_impulses) do
            self.angular_impulses[id] = nil
        end

        if impulse_x == 0 and impulse_y == 0 and angular_impulse == 0 then
            return
        end

        local center_x, center_y, total_mass, moment_of_inertia =
        _get_mass_properties(particles, n_particles)

        local delta_velocity_x, delta_velocity_y = 0, 0
        if total_mass > eps then
            delta_velocity_x = impulse_x / total_mass
            delta_velocity_y = impulse_y / total_mass
        end

        local delta_angular_velocity = 0
        if moment_of_inertia > eps then
            delta_angular_velocity = angular_impulse / moment_of_inertia
        end

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            if particles[i + _inverse_mass_offset] > 0 then
                local rx = particles[i + _x_offset] - center_x
                local ry = particles[i + _y_offset] - center_y

                particles[i + _velocity_x_offset] = particles[i + _velocity_x_offset]
                    + delta_velocity_x - delta_angular_velocity * ry

                particles[i + _velocity_y_offset] = particles[i + _velocity_y_offset]
                    + delta_velocity_y + delta_angular_velocity * rx
            end
        end
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
        rest_velocity_x, rest_velocity_y,
        rest_angular_velocity,
        center_x, center_y,
        delta
    )
        local x = position_x
        local y = position_y

        local velocity_x = (x - previous_x) / delta
            - rest_velocity_x
            + rest_angular_velocity * (previous_y - center_y)

        local velocity_y = (y - previous_y) / delta
            - rest_velocity_y
            - rest_angular_velocity * (previous_x - center_x)

        return x, y, velocity_x, velocity_y
    end

    local function _enforce_angular_momentum(
        particles, n_particles,
        target_velocity, -- radians / s, positive clockwise in screen coordinates
        sub_delta,
        alpha,
        lambda_before
    )
        local mass_sum = 0
        local com_x, com_y = 0, 0

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local inverse_mass = particles[i + _inverse_mass_offset]
            local m = particles[i + _mass_offset]

            if inverse_mass > 0 and m > 0 then
                mass_sum = mass_sum + m
                com_x = com_x + m * particles[i + _previous_x_offset]
                com_y = com_y + m * particles[i + _previous_y_offset]
            end
        end

        if mass_sum <= 0 then
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

            if inverse_mass > 0 and m > 0 then
                local rx = particles[i + _previous_x_offset] - com_x
                local ry = particles[i + _previous_y_offset] - com_y

                local dx = particles[i + _x_offset] - particles[i + _previous_x_offset]
                local dy = particles[i + _y_offset] - particles[i + _previous_y_offset]

                angular_momentum = angular_momentum + m * cross(rx, ry, dx, dy)
                inertia = inertia + m * dot(rx, ry, rx, ry)

                local gx, gy = -m * ry, m * rx
                weight_sum = weight_sum + inverse_mass * dot(gx, gy, gx, gy)
            end
        end

        local denominator = weight_sum + alpha
        if denominator <= 0 then
            return lambda_before
        end

        local constraint = angular_momentum - inertia * target_velocity * sub_delta

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = lambda_before + delta_lambda

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local m = particles[i + _mass_offset]
            local inverse_mass = particles[i + _inverse_mass_offset]

            if inverse_mass > 0 and m > 0 then
                local rx = particles[i + _previous_x_offset] - com_x
                local ry = particles[i + _previous_y_offset] - com_y

                particles[i + _x_offset] = particles[i + _x_offset]
                    + inverse_mass * delta_lambda * (-m * ry)

                particles[i + _y_offset] = particles[i + _y_offset]
                    + inverse_mass * delta_lambda * (m * rx)
            end
        end

        return lambda_new
    end

    local function _enforce_friction(
        position_x, position_y,
        previous_x, previous_y,
        normal_x, normal_y,
        inverse_mass,
        normal_lambda,
        static_friction, kinetic_friction
    )
        if inverse_mass <= 0 or normal_lambda <= 0 then
            return 0, 0
        end

        local depth = inverse_mass * normal_lambda
        local delta_x = position_x - previous_x
        local delta_y = position_y - previous_y

        local normal_component = dot(delta_x, delta_y, normal_x, normal_y)
        local tangent_x = delta_x - normal_component * normal_x
        local tangent_y = delta_y - normal_component * normal_y

        local tangent_length = magnitude(tangent_x, tangent_y)
        if tangent_length < eps then
            return 0, 0
        end

        local scale
        if tangent_length < static_friction * depth then
            scale = 1
        else
            scale = math.min(kinetic_friction * depth / tangent_length, 1)
        end

        return -tangent_x * scale, -tangent_y * scale
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
            local inverse_mass = particles[i + _inverse_mass_offset]

            if inverse_mass > 0 and m > 0 then
                mass_sum = mass_sum + m
                weight_sum = weight_sum + inverse_mass * m * m

                momentum_x = momentum_x + m * (particles[i + _x_offset] - particles[i + _previous_x_offset])
                momentum_y = momentum_y + m * (particles[i + _y_offset] - particles[i + _previous_y_offset])
            end
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

            if inverse_mass > 0 and m > 0 then
                particles[i + _x_offset] = particles[i + _x_offset]
                    + inverse_mass * delta_lambda_x * m

                particles[i + _y_offset] = particles[i + _y_offset]
                    + inverse_mass * delta_lambda_y * m
            end
        end

        return lambda_x_new, lambda_y_new
    end

    -- Pins the mass-weighted center of the body to (anchor_x, anchor_y).
    -- Constraint: C = center - anchor = 0, with dC/dx_i = m_i / M for every particle.
    -- Corrections are therefore a shared translation, so the contour keeps all
    -- of its internal degrees of freedom (shape, rotation, deformation).
    local function _enforce_anchor(
        particles, n_particles,
        anchor_x, anchor_y,
        alpha,
        lambda_x_before, lambda_y_before
    )
        local mass_sum = 0
        local weight_sum = 0
        local center_x, center_y = 0, 0

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local m = particles[i + _mass_offset]
            local inverse_mass = particles[i + _inverse_mass_offset]

            if inverse_mass > 0 and m > 0 then
                mass_sum = mass_sum + m
                center_x = center_x + m * particles[i + _x_offset]
                center_y = center_y + m * particles[i + _y_offset]
                weight_sum = weight_sum + inverse_mass * m * m
            end
        end

        if mass_sum < eps then
            return lambda_x_before, lambda_y_before
        end

        center_x = center_x / mass_sum
        center_y = center_y / mass_sum

        -- gradient is m_i / M, so sum of w_i * (m_i / M)^2 = weight_sum / M^2
        local denominator = weight_sum / (mass_sum * mass_sum) + alpha
        if denominator < eps then
            return lambda_x_before, lambda_y_before
        end

        local constraint_x = center_x - anchor_x
        local constraint_y = center_y - anchor_y

        local delta_lambda_x = -(constraint_x + alpha * lambda_x_before) / denominator
        local delta_lambda_y = -(constraint_y + alpha * lambda_y_before) / denominator

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local m = particles[i + _mass_offset]
            local inverse_mass = particles[i + _inverse_mass_offset]

            if inverse_mass > 0 and m > 0 then
                local gradient = m / mass_sum
                particles[i + _x_offset] = particles[i + _x_offset] + inverse_mass * delta_lambda_x * gradient
                particles[i + _y_offset] = particles[i + _y_offset] + inverse_mass * delta_lambda_y * gradient
            end
        end

        return lambda_x_before + delta_lambda_x, lambda_y_before + delta_lambda_y
    end

    function rt.Softbody:update(delta_in)
        meta.typecheck(delta_in, mt.Number)

        local timestep = _settings_timestep
        local sub_delta = timestep / _settings_n_sub_steps

        local damping = _settings_damping
        local n_sub_steps = _settings_n_sub_steps
        local n_constraint_iterations = _settings_n_constraint_iterations

        local override = self._settings_override
        local sub_delta_sq = (sub_delta * sub_delta)
        local volume_alpha  = (override.volume_compliance  or _settings_default_volume_compliance) / sub_delta_sq
        local contour_alpha = (override.contour_compliance or _settings_default_collision_contour_compliance) / sub_delta_sq
        local distance_alpha = (override.distance_compliance or _settings_default_distance_compliance) / sub_delta_sq
        local bending_alpha = (override.bending_compliance or _settings_default_bending_compliance) / sub_delta_sq
        local angular_alpha = (override.angular_velocity_compliance or _settings_default_angular_velocity_compliance) / sub_delta_sq
        local linear_alpha = (override.linear_velocity_compliance or _settings_default_linear_velocity_compliance) / sub_delta_sq
        local anchor_alpha = (override.anchor_compliance or _settings_default_anchor_compliance) / sub_delta_sq

        local static_friction = override.static_friction or _settings_default_static_friction
        local kinetic_friction = override.kinetic_friction or _settings_default_kinetic_friction

        local data = self.particles
        local n_particles = self.n_particles
        local collision_contours = self.collision_contours
        local n_collision_contours = #collision_contours

        local anchor_active = self.anchor_active
        local anchor_x, anchor_y = self.anchor_x, self.anchor_y

        local gravity_x = self.gravity_x
        local gravity_y = self.gravity_y
        local linear_force_x, linear_force_y = _sum_linear_sources(self.linear_forces)
        local angular_torque = _sum_angular_sources(self.angular_forces, "torque")

        self.elapsed = self.elapsed + delta_in
        local n_steps = 0
        while self.elapsed >= timestep and n_steps < _settings_max_n_steps do
            self.elapsed = self.elapsed - timestep
            n_steps = n_steps + 1

            -- substep or constraint iteration.
            _apply_pending_impulses(self, data, n_particles)

            -- snapshot for frame interpolation
            for particle_i = 1, n_particles do
                local i = _particle_i_to_data_offset(particle_i)
                data[i + _snapshot_x_offset] = data[i + _x_offset]
                data[i + _snapshot_y_offset] = data[i + _y_offset]
            end

            for _ = 1, n_sub_steps do
                -- reset polygon collision lambdas
                for contour_i = 1, n_collision_contours do
                    local lambdas = collision_contours[contour_i].lambdas
                    for particle_i = 1, n_particles do
                        lambdas[particle_i] = 0
                    end
                end

                local center_x, center_y, total_mass, moment_of_inertia = _get_mass_properties(data, n_particles)

                local force_acceleration_x, force_acceleration_y = 0, 0
                if total_mass > eps then
                    force_acceleration_x = linear_force_x / total_mass
                    force_acceleration_y = linear_force_y / total_mass
                end

                local angular_acceleration = 0
                if moment_of_inertia > eps then
                    angular_acceleration = angular_torque / moment_of_inertia
                end

                for particle_i = 1, n_particles do
                    local i = _particle_i_to_data_offset(particle_i)
                    local acceleration_x = gravity_x + force_acceleration_x
                    local acceleration_y = gravity_y + force_acceleration_y

                    if data[i + _inverse_mass_offset] > 0 and angular_acceleration ~= 0 then
                        local rx = data[i + _x_offset] - center_x
                        local ry = data[i + _y_offset] - center_y
                        acceleration_x = acceleration_x - angular_acceleration * ry
                        acceleration_y = acceleration_y + angular_acceleration * rx
                    end

                    local new_position_x, new_position_y,
                    new_velocity_x, new_velocity_y,
                    previous_x, previous_y = _pre_solve(
                        data[i + _x_offset],
                        data[i + _y_offset],
                        data[i + _velocity_x_offset],
                        data[i + _velocity_y_offset],
                        data[i + _inverse_mass_offset],
                        acceleration_x,
                        acceleration_y,
                        0, 0, -- linear velocity
                        0, -- angular velocity
                        center_x, center_y,
                        damping,
                        sub_delta
                    )

                    data[i + _x_offset] = new_position_x
                    data[i + _y_offset] = new_position_y
                    data[i + _velocity_x_offset] = new_velocity_x
                    data[i + _velocity_y_offset] = new_velocity_y
                    data[i + _previous_x_offset] = previous_x
                    data[i + _previous_y_offset] = previous_y

                    data[i + _distance_lambda_offset] = 0
                    data[i + _bending_lambda_offset] = 0
                    data[i + _polygon_lambda_offset] = 0
                end

                self.volume_lambda = 0
                self.angular_velocity_lambda = 0
                self.linear_velocity_lambda_x = 0
                self.linear_velocity_lambda_y = 0
                self.anchor_lambda_x = 0
                self.anchor_lambda_y = 0

                for _ = 1, n_constraint_iterations do
                    -- distance: pair wise
                    for particle_i = 1, n_particles do
                        local ai = _particle_i_to_data_offset(particle_i)
                        local bi = _particle_i_to_data_offset(particle_i + 1, n_particles)

                        local correction_ax, correction_ay,
                        correction_bx, correction_by,
                        lambda_new = _enforce_exact_distance(
                            data[ai + _x_offset], data[ai + _y_offset],
                            data[bi + _x_offset], data[bi + _y_offset],
                            data[ai + _inverse_mass_offset],
                            data[bi + _inverse_mass_offset],
                            data[ai + _segment_length_offset],
                            distance_alpha,
                            data[ai + _distance_lambda_offset]
                        )

                        data[ai + _x_offset] = data[ai + _x_offset] + correction_ax
                        data[ai + _y_offset] = data[ai + _y_offset] + correction_ay

                        data[bi + _x_offset] = data[bi + _x_offset] + correction_bx
                        data[bi + _y_offset] = data[bi + _y_offset] + correction_by

                        data[ai + _distance_lambda_offset] = lambda_new
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
                            data[ai + _x_offset], data[ai + _y_offset],
                            data[bi + _x_offset], data[bi + _y_offset],
                            data[ci + _x_offset], data[ci + _y_offset],
                            data[ai + _inverse_mass_offset],
                            data[bi + _inverse_mass_offset],
                            data[ci + _inverse_mass_offset],
                            bending_alpha,
                            data[ai + _bending_lambda_offset]
                        )

                        data[ai + _x_offset] = data[ai + _x_offset] + correction_ax
                        data[ai + _y_offset] = data[ai + _y_offset] + correction_ay

                        data[bi + _x_offset] = data[bi + _x_offset] + correction_bx
                        data[bi + _y_offset] = data[bi + _y_offset] + correction_by

                        data[ci + _x_offset] = data[ci + _x_offset] + correction_cx
                        data[ci + _y_offset] = data[ci + _y_offset] + correction_cy

                        data[ai + _bending_lambda_offset] = lambda_new
                    end

                    -- volume
                    self.volume_lambda = _enforce_volume(
                        data, n_particles,
                        self.volume_gradient,
                        self.volume,
                        volume_alpha,
                        self.volume_lambda
                    )

                    self.angular_velocity_lambda = _enforce_angular_momentum(
                        data, n_particles,
                        0,
                        sub_delta,
                        angular_alpha,
                        self.angular_velocity_lambda
                    )

                    if anchor_active then
                        self.anchor_lambda_x, self.anchor_lambda_y = _enforce_anchor(
                            data, n_particles,
                            anchor_x, anchor_y,
                            anchor_alpha,
                            self.anchor_lambda_x,
                            self.anchor_lambda_y
                        )
                    end
                end

                -- polygon collision
                for _ = 1, n_constraint_iterations do
                    for contour_i = 1, n_collision_contours do
                        local entry = collision_contours[contour_i]
                        local edges = entry.edges
                        local n_edges = entry.n_edges
                        local lambdas = entry.lambdas
                        local normals_x, normals_y = entry.normals_x, entry.normals_y
                        local keep_outside = entry.contour:get_winding()

                        for particle_i = 1, n_particles do
                            local i = _particle_i_to_data_offset(particle_i)
                            local correction_x, correction_y, lambda_new, normal_x, normal_y = _enforce_polygon_collision(
                                data[i + _x_offset], data[i + _y_offset],
                                data[i + _inverse_mass_offset],
                                data[i + _radius_offset],
                                edges, n_edges,
                                contour_alpha,
                                lambdas[particle_i],
                                keep_outside
                            )

                            data[i + _x_offset] = data[i + _x_offset] + correction_x
                            data[i + _y_offset] = data[i + _y_offset] + correction_y
                            lambdas[particle_i] = lambda_new

                            if normal_x ~= 0 or normal_y ~= 0 then
                                normals_x[particle_i], normals_y[particle_i] = normal_x, normal_y
                            end
                        end
                    end
                end

                -- friction, after the final normal lambdas are known and before the velocity update
                if static_friction > 0 or kinetic_friction > 0 then
                    for contour_i = 1, n_collision_contours do
                        local entry = collision_contours[contour_i]
                        local lambdas = entry.lambdas
                        local normals_x, normals_y = entry.normals_x, entry.normals_y

                        for particle_i = 1, n_particles do
                            local i = _particle_i_to_data_offset(particle_i)
                            local correction_x, correction_y = _enforce_friction(
                                data[i + _x_offset], data[i + _y_offset],
                                data[i + _previous_x_offset], data[i + _previous_y_offset],
                                normals_x[particle_i], normals_y[particle_i],
                                data[i + _inverse_mass_offset],
                                lambdas[particle_i],
                                static_friction, kinetic_friction
                            )

                            data[i + _x_offset] = data[i + _x_offset] + correction_x
                            data[i + _y_offset] = data[i + _y_offset] + correction_y
                        end
                    end
                end

                -- post solve
                for particle_i = 1, n_particles do
                    local i = _particle_i_to_data_offset(particle_i)
                    local x, y = data[i + _x_offset], data[i + _y_offset]

                    local new_position_x, new_position_y,
                    new_velocity_x, new_velocity_y = _post_solve(
                        x, y,
                        data[i + _previous_x_offset],
                        data[i + _previous_y_offset],
                        0, 0,
                        0,
                        center_x, center_y,
                        sub_delta
                    )

                    data[i + _x_offset] = new_position_x
                    data[i + _y_offset] = new_position_y
                    data[i + _velocity_x_offset] = new_velocity_x
                    data[i + _velocity_y_offset] = new_velocity_y
                end
            end
        end

        self.elapsed = math.min(self.elapsed, timestep) -- prevent accumulating death spiral

        -- update draw contour
        local draw_contour_vertices = self.draw_contour:get_vertices()
        local frame_interpolation_alpha = self.elapsed / timestep

        local centroid_x, centroid_y = 0, 0
        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local contour_i = (particle_i - 1) * 2 + 1

            local prev_x, prev_y = data[i + _snapshot_x_offset], data[i + _snapshot_y_offset]
            local curr_x, curr_y = data[i + _x_offset], data[i + _y_offset]

            local x = prev_x + (curr_x - prev_x) * frame_interpolation_alpha
            local y = prev_y + (curr_y - prev_y) * frame_interpolation_alpha

            data[i + _draw_x_offset] = x
            data[i + _draw_y_offset] = y

            draw_contour_vertices[contour_i + 0] = x
            draw_contour_vertices[contour_i + 1] = y

            centroid_x = centroid_x + x
            centroid_y = centroid_y + y
        end

        draw_contour_vertices[n_particles * 2 + 1] = draw_contour_vertices[1]
        draw_contour_vertices[n_particles * 2 + 2] = draw_contour_vertices[2]

        self.centroid_x = centroid_x / self.n_particles
        self.centroid_y = centroid_y / self.n_particles

        return self
    end
end

-- volume

function rt.Softbody:set_target_volume(fraction) -- fraction
    meta.typecheck(fraction, mt.Number)
    self.volume_multiplier = fraction
    self.volume_lambda = 0
end

function rt.Softbody:get_target_volume()
    meta.typecheck(self, rt.Softbody)
    return self.volume_multiplier
end

function rt.Softbody:set_gravity(dx, dy)
    meta.typecheck(dx, mt.Number, dy, mt.Number)
    self.gravity_x, self.gravity_y = dx, dy
end

local _entry_hash = 0
local _get_hash = function()
    local hash = _entry_hash
    _entry_hash = _entry_hash + 1
    return hash
end

-- linear

function rt.Softbody:add_linear_force(dx, dy)
    meta.typecheck(dx, mt.Number, dy, mt.Number)
    local magnitude = math.magnitude(dx, dy)
    if magnitude <= _math_eps then
        return
    end

    dx, dy = math.normalize(dx, dy)
    local id = _get_hash()
    self.linear_forces[id] = {
        magnitude = magnitude,
        dx = dx,
        dy = dy
    }
    return id
end

function rt.Softbody:remove_linear_force(hash)
    if hash == nil then return end
    meta.typecheck(hash, mt.Number)
    self.linear_forces[hash] = nil
end

function rt.Softbody:add_linear_impulse(dx, dy)
    meta.typecheck(dx, mt.Number, dy, mt.Number)
    local magnitude = math.magnitude(dx, dy)
    if magnitude > _math_eps then
        dx, dy = math.normalize(dx, dy)
        local id = _get_hash()
        self.linear_impulses[id] = {
            magnitude = magnitude,
            dx = dx,
            dy = dy
        }
        return id
    end
end

function rt.Softbody:remove_linear_impulse(hash)
    if hash == nil then return end
    meta.typecheck(hash, mt.Number)
    self.linear_impulses[hash] = nil
end

-- rotation

function rt.Softbody:add_angular_force(torque)
    meta.typecheck(torque, mt.Number)
    if torque ~= 0 then
        local id = _get_hash()
        self.angular_forces[id] = {
            torque = torque
        }
        return id
    end
end

function rt.Softbody:remove_angular_force(hash)
    if hash == nil then return end
    meta.typecheck(hash, mt.Number)
    self.angular_forces[hash] = nil
end

function rt.Softbody:add_angular_impulse(angular_impulse)
    meta.typecheck(angular_impulse, mt.Number)
    if angular_impulse ~= 0 then
        local id = _get_hash()
        self.angular_impulses[id] = {
            angular_impulse = angular_impulse
        }
        return id
    end
end

function rt.Softbody:remove_angular_impulse(hash)
    if hash == nil then return end
    meta.typecheck(hash, mt.Number)
    self.angular_impulses[hash] = nil
end

-- mode
function rt.Softbody:set_config(settings)
    config_schema:validate(settings)
    self.settings_override = settings
end

function rt.Softbody:get_config()
    return self.settings_override
end

function rt.Softbody:get_centroid()
    meta.typecheck(self, rt.Softbody)
    return self.centroid_x, self.centroid_y
end

function rt.Softbody:set_anchor(x, y)
    meta.typecheck(x, mt.Number, y, mt.Number)
    self.anchor_x, self.anchor_y = x, y
end

function rt.Softbody:set_is_anchored(b)
    meta.typecheck(b, mt.Boolean)
    self.anchor_active = b
end

function rt.Softbody:clear_forces()
    meta.typecheck(self, rt.Softbody)

    -- clear pending impulses and persistent forces
    for id in pairs(self.linear_impulses) do
        self.linear_impulses[id] = nil
    end

    for id in pairs(self.angular_impulses) do
        self.angular_impulses[id] = nil
    end

    for id in pairs(self.linear_forces) do
        self.linear_forces[id] = nil
    end

    for id in pairs(self.angular_forces) do
        self.angular_forces[id] = nil
    end

    local data = self.particles
    for particle_i = 1, self.n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        data[i + _velocity_x_offset] = 0
        data[i + _velocity_y_offset] = 0
    end

    return self
end

function rt.Softbody:set_friction(static_friction, kinetic_friction)
    meta.typecheck(static_friction, mt.Number, kinetic_friction, mt.Number)
    rt.assert(static_friction >= 0 and kinetic_friction >= 0, "In rt.Softbody.set_friction: coefficients must be non-negative")
    self.static_friction = static_friction
    self.kinetic_friction = math.min(kinetic_friction, static_friction)
    return self
end

function rt.Softbody:get_mass()
    local data = self.particles
    local total = 0
    for particle_i = 1, self.n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        if data[i + _inverse_mass_offset] > 0 then
            total = total + data[i + _mass_offset]
        end
    end
    return total
end

function rt.Softbody:relax()

end