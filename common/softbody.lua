rt.settings.softbody = {
    timestep = 1 / 60,
    max_n_steps = 8,

    n_sub_steps = 4,
    n_constraint_iterations = 4,

    default = {
        static_friction = 0.7,
        kinetic_friction = 0.5,

        distance_compliance = 1e-6,
        volume_compliance = 0,
        collision_contour_compliance = 0,
        bending_compliance = 1e-6,
        angular_velocity_compliance = 0,
        linear_velocity_compliance = 0,
        particle_collision_compliance = 0,
        anchor_compliance = 1e-8
    }
}

local Op = mt.Optional(mt.Number)
local config_schema = meta.Schema({
    static_friction = Op,
    kinetic_friction = Op,
    distance_compliance = Op,
    volume_compliance = Op,
    collision_contour_compliance = Op,
    bending_compliance = Op,
    angular_velocity_compliance = Op,
    linear_velocity_compliance = Op,
    particle_collision_compliance = Op,
    anchor_compliance = Op
})

local _settings_damping = 1 - 1e-4
local _settings_texture_zoom = 1 / 0.9

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
local _rest_length_offset = 16        -- rest length of the edge from this particle to the next
local _bending_rest_offset = 17       -- signed rest offset of this particle from the chord of its neighbours

local _stride = _bending_rest_offset + 1

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
rt.SoftBody = meta.class("SoftBody")

function rt.SoftBody:instantiate(contour)
    meta.typecheck(
        self, rt.SoftBody,
        contour, rt.Polyline
    )

    self._initial_contour = contour

    local eps_squared = math.eps * math.eps

    local source = contour:get_vertices()
    local n_source = math.floor(#source / 2)
    local xs, ys = {}, {}
    local n_particles = 0

    for source_i = 1, n_source do
        local x, y = source[2 * source_i - 1], source[2 * source_i]
        local is_new = true
        if n_particles > 0 then
            local dx, dy = x - xs[n_particles], y - ys[n_particles]
            is_new = dx * dx + dy * dy > eps_squared
        end

        if is_new then
            n_particles = n_particles + 1
            xs[n_particles], ys[n_particles] = x, y
        end
    end

    if n_particles > 1 then
        local dx, dy = xs[n_particles] - xs[1], ys[n_particles] - ys[1]
        if dx * dx + dy * dy <= eps_squared then
            n_particles = n_particles - 1
        end
    end

    rt.assert(n_particles >= 3, "In softbody_init: contour needs at least 3 distinct vertices")

    -- particles
    local data = table.new(n_particles * _stride)

    for particle_i = 1, n_particles do
        local px, py = xs[particle_i], ys[particle_i]
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
        data[base + _distance_lambda_offset] = 0
        data[base + _bending_lambda_offset] = 0
        data[base + _polygon_lambda_offset] = 0
        data[base + _rest_length_offset] = 0 -- filled below
        data[base + _bending_rest_offset] = 0

        assert(#data == particle_i * _stride)
    end

    -- rest state: edge lengths, bending offsets, and signed area
    local area = 0

    for particle_i = 1, n_particles do
        local ai = _particle_i_to_data_offset(particle_i - 1, n_particles)
        local bi = _particle_i_to_data_offset(particle_i, n_particles)
        local ci = _particle_i_to_data_offset(particle_i + 1, n_particles)

        local ax, ay = data[ai + _x_offset], data[ai + _y_offset]
        local bx, by = data[bi + _x_offset], data[bi + _y_offset]
        local cx, cy = data[ci + _x_offset], data[ci + _y_offset]

        -- distance: edge b -> c
        data[bi + _rest_length_offset] = math.distance(bx, by, cx, cy)

        -- bending: same signed quantity as in _enforce_bending, measured on the rest shape
        local chord_x, chord_y = cx - ax, cy - ay
        local chord_length = math.magnitude(chord_x, chord_y)
        if chord_length > math.eps then
            local nx, ny = -chord_y / chord_length, chord_x / chord_length
            local ex = 0.5 * (ax + cx) - bx
            local ey = 0.5 * (ay + cy) - by
            data[bi + _bending_rest_offset] = ex * nx + ey * ny
        end

        -- signed area (shoelace), the volume constraint works for either winding
        area = area + 0.5 * math.cross(bx, by, cx, cy)
    end

    rt.assert(math.abs(area) > math.eps, "In softbody_init: contour must enclose an area")
    local rest_area = area

    -- drawing
    local draw_contour = table.new(2 * n_particles + 2)
    local centroid_x, centroid_y = 0, 0
    for particle_i = 1, n_particles do
        local i = _particle_i_to_data_offset(particle_i, n_particles)

        table.insert(draw_contour, data[i + _x_offset])
        table.insert(draw_contour, data[i + _y_offset])

        centroid_x = centroid_x + data[i + _x_offset]
        centroid_y = centroid_y + data[i + _y_offset]
    end

    table.insert(draw_contour, draw_contour[1])
    table.insert(draw_contour, draw_contour[2])

    self._particles = data
    self._n_particles = n_particles

    -- rest positions, used to express the anchor pivot as a material point
    self._rest_xs, self._rest_ys = {}, {}
    for particle_i = 1, n_particles do
        self._rest_xs[particle_i], self._rest_ys[particle_i] = xs[particle_i], ys[particle_i]
    end
    self._centroid_x = centroid_x / n_particles
    self._centroid_y = centroid_y / n_particles

    self._volume = rest_area
    self._volume_multiplier = 1.0

    self._volume_lambda = 0
    self._angular_velocity_lambda = 0
    self._linear_velocity_lambda_x = 0
    self._linear_velocity_lambda_y = 0

    self._rest_angular_velocity = 0

    self._anchor_x = nil
    self._anchor_y = nil
    self._anchor_offset_x = 0
    self._anchor_offset_y = 0
    self._anchor_weights = nil -- per-particle weights of the pivot material point, sums to 1
    self._anchor_weights_offset_x = nil
    self._anchor_weights_offset_y = nil
    self._anchor_particle_i = nil -- particle initially selected by set_anchor; retained while dragging
    self._anchor_lambda_x = 0
    self._anchor_lambda_y = 0
    self._pinch_lambda_x = 0
    self._pinch_lambda_y = 0

    self._volume_gradient = table.new(2 * n_particles)
    for particle_i = 1, n_particles do
        self._volume_gradient[2 * particle_i - 1] = 0
        self._volume_gradient[2 * particle_i] = 0
    end

    self._collision_contours = table.new(0)

    self._linear_impulses = {}
    self._angular_impulses = {}
    self._linear_forces = {}
    self._angular_forces = {}

    self._gravity_x = 0
    self._gravity_y = 0

    self._draw_contour = rt.Polyline(draw_contour):close()
    self._collision_contours = {}

    -- control
    self._linear_velocity_x = 0
    self._linear_velocity_y = 0
    self._angular_velocity = 0

    self._is_initialized = true
    self._elapsed = 0
end

function rt.SoftBody:is_initialized()
    return object_isa(self, rt.SoftBody) and self._is_initialized == true
end

function rt.SoftBody:set_collision_contours(contours)

    local eps_squared = math.eps * math.eps
    local abs = math.abs
    table.clear(self._collision_contours)

    for i = 1, #contours do
        local contour = contours[i]

        local closed_contour = contour:close()
        local n_corners = closed_contour:get_n_vertices()

        rt.assert(n_corners >= 3, "In softbody_set_collision_contours: need at least 3 vertices")

        local signed_area = closed_contour:get_signed_area()
        rt.assert(abs(signed_area) > math.eps, "In softbody_set_collision_contours: contour must enclose an area")

        local orientation = math.sign(signed_area)
        local vertices = closed_contour:get_vertices()
        local edges = table.new(n_corners * _edge_stride)
        local n_edges = 0

        for vertex_i = 1, n_corners do
            local next_vertex_i = math.wrap(vertex_i + 1, n_corners)
            local ai = (vertex_i - 1) * 2 + 1
            local bi = (next_vertex_i - 1) * 2 + 1
            local x1, y1 = vertices[ai + 0], vertices[ai + 1]
            local x2, y2 = vertices[bi + 0], vertices[bi + 1]

            local dx = x2 - x1
            local dy = y2 - y1
            local length_squared = math.dot(dx, dy, dx, dy)

            if length_squared > eps_squared then
                local normal_x, normal_y = math.normalize(orientation * dy, -orientation * dx)
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

        local collision_contour = {
            contour = closed_contour,
            edges = edges,
            n_edges = n_edges,
            lambdas = table.rep(0, self._n_particles),
            normals_x = table.rep(0, self._n_particles),
            normals_y = table.rep(0, self._n_particles)
        }

        for particle_i = 1, self._n_particles do
            collision_contour.lambdas[particle_i] = 0
        end

        table.insert(self._collision_contours, collision_contour)
    end

    return self
end

function rt.SoftBody:get_collision_contours()
    local results = {}
    for entry in values(self._collision_contours) do
        table.insert(results, entry.contour)
    end
    return results
end

function rt.SoftBody:get_contour()
    meta.typecheck(self, rt.SoftBody)

    local contour = table.new(2 * self._n_particles)
    local data = self._particles
    for particle_i = 1, self._n_particles, 1 do -- clockwise winding
        local i = _particle_i_to_data_offset(particle_i)
        table.insert(contour, data[i + _x_offset])
        table.insert(contour, data[i + _y_offset])
    end

    return rt.Polyline(contour)
end

function rt.SoftBody:get_draw_contour()
    return self._draw_contour
end

do -- softbody_update
    local sqrt = math.sqrt
    local max = math.max
    local huge = math.huge
    local eps = math.eps
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
        local impulse_x, impulse_y = _sum_linear_sources(self._linear_impulses)
        local angular_impulse = _sum_angular_sources(self._angular_impulses, "angular_impulse")

        for id in pairs(self._linear_impulses) do
            self._linear_impulses[id] = nil
        end

        for id in pairs(self._angular_impulses) do
            self._angular_impulses[id] = nil
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
        rest_offset, -- signed distance chord midpoint -> b at rest (> 0 for a convex CCW contour)
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

        -- C = (midpoint - b) . n  -  rest_offset
        -- the gradient is unaffected by the constant rest term. For a regular polygon
        -- inscribed in a circle, b sits R * (1 - cos(2pi/n)) outside the chord midpoint
        local constraint = dot(ex, ey, nx, ny) - rest_offset

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

    -- Constrains one material point (a particle) to the world-space anchor.
    -- The attachment particle is selected once by set_anchor and remains fixed
    -- for the duration of the drag. Unlike a center-of-mass constraint, this
    -- lets the remaining particles respond through the shape constraints.
    local function _enforce_pinch(
        particles, particle_i,
        anchor_x, anchor_y,
        alpha,
        lambda_x_before, lambda_y_before
    )
        if particle_i == nil then
            return lambda_x_before, lambda_y_before
        end

        local i = _particle_i_to_data_offset(particle_i)
        local inverse_mass = particles[i + _inverse_mass_offset]
        if inverse_mass <= 0 then
            return lambda_x_before, lambda_y_before
        end

        local denominator = inverse_mass + alpha
        if denominator < eps then
            return lambda_x_before, lambda_y_before
        end

        local constraint_x = particles[i + _x_offset] - anchor_x
        local constraint_y = particles[i + _y_offset] - anchor_y

        local delta_lambda_x = -(constraint_x + alpha * lambda_x_before) / denominator
        local delta_lambda_y = -(constraint_y + alpha * lambda_y_before) / denominator

        particles[i + _x_offset] = particles[i + _x_offset] + inverse_mass * delta_lambda_x
        particles[i + _y_offset] = particles[i + _y_offset] + inverse_mass * delta_lambda_y

        return lambda_x_before + delta_lambda_x, lambda_y_before + delta_lambda_y
    end

    -- Pins a material point of the body to (anchor_x, anchor_y). The point is a
    -- fixed affine combination P = sum(w_i * p_i), sum(w_i) = 1, chosen so that P
    -- sits at (rest center - offset) and follows the body's rotation exactly for
    -- rigid motion (see _compute_pivot_weights). Constraint: C = P - anchor = 0,
    -- dC/dp_i = w_i. Since the correction is not a pure translation, the body
    -- rotates around the anchor instead of around its center.
    local function _enforce_anchor(
        particles, n_particles,
        weights,
        anchor_x, anchor_y,
        alpha,
        lambda_x_before, lambda_y_before
    )
        local point_x, point_y = 0, 0
        local denominator = alpha

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local w = weights[particle_i]
            local inverse_mass = particles[i + _inverse_mass_offset]

            point_x = point_x + w * particles[i + _x_offset]
            point_y = point_y + w * particles[i + _y_offset]

            if inverse_mass > 0 then
                denominator = denominator + inverse_mass * w * w
            end
        end

        if denominator < eps then
            return lambda_x_before, lambda_y_before
        end

        local constraint_x = point_x - anchor_x
        local constraint_y = point_y - anchor_y

        local delta_lambda_x = -(constraint_x + alpha * lambda_x_before) / denominator
        local delta_lambda_y = -(constraint_y + alpha * lambda_y_before) / denominator

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local inverse_mass = particles[i + _inverse_mass_offset]

            if inverse_mass > 0 then
                local gradient = weights[particle_i]
                particles[i + _x_offset] = particles[i + _x_offset] + inverse_mass * delta_lambda_x * gradient
                particles[i + _y_offset] = particles[i + _y_offset] + inverse_mass * delta_lambda_y * gradient
            end
        end

        return lambda_x_before + delta_lambda_x, lambda_y_before + delta_lambda_y
    end

    function rt.SoftBody:update(delta)
        meta.typecheck(self, rt.SoftBody, delta, mt.Number)

        -- A zero-sized timestep makes compliance and interpolation divisions
        -- undefined (0/0 or value/0), which can permanently poison particle state.
        -- Treat a zero-delta update as a no-op and preserve the current draw contour.
        if delta <= 0 then
            return self
        end

        local timestep = delta
        local sub_delta = timestep / rt.settings.softbody.n_sub_steps

        local damping = _settings_damping
        local n_sub_steps = rt.settings.softbody.n_sub_steps
        local n_constraint_iterations = rt.settings.softbody.n_constraint_iterations

        local override = self._override or {}

        local sub_delta_sq = (sub_delta * sub_delta)
        local volume_alpha  = (override.volume_compliance  or rt.settings.softbody.default.volume_compliance) / sub_delta_sq
        local contour_alpha = (override.contour_compliance or rt.settings.softbody.default.collision_contour_compliance) / sub_delta_sq
        local distance_alpha = (override.distance_compliance or rt.settings.softbody.default.distance_compliance) / sub_delta_sq
        local bending_alpha = (override.bending_compliance or rt.settings.softbody.default.bending_compliance) / sub_delta_sq
        local angular_alpha = (override.angular_velocity_compliance or rt.settings.softbody.default.angular_velocity_compliance) / sub_delta_sq
        local linear_alpha = (override.linear_velocity_compliance or rt.settings.softbody.default.linear_velocity_compliance) / sub_delta_sq
        local anchor_alpha = (override.anchor_compliance or rt.settings.softbody.default.anchor_compliance) / sub_delta_sq

        local static_friction = override.static_friction or rt.settings.softbody.default.static_friction
        local kinetic_friction = override.kinetic_friction or rt.settings.softbody.default.kinetic_friction

        local data = self._particles
        local n_particles = self._n_particles
        local collision_contours = self._collision_contours
        local n_collision_contours = #collision_contours

        local anchor_x, anchor_y = self._anchor_x, self._anchor_y
        local anchor_weights = self._anchor_weights
        local anchor_particle_i = self._anchor_particle_i
        local anchor_active = anchor_particle_i ~= nil
            and anchor_x ~= nil and anchor_y ~= nil
            and anchor_weights ~= nil

        local gravity_x = self._gravity_x
        local gravity_y = self._gravity_y
        local linear_force_x, linear_force_y = _sum_linear_sources(self._linear_forces)
        local angular_torque = _sum_angular_sources(self._angular_forces, "torque")

        do

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

                self._volume_lambda = 0
                self._angular_velocity_lambda = 0
                self._linear_velocity_lambda_x = 0
                self._linear_velocity_lambda_y = 0
                self._anchor_lambda_x = 0
                self._anchor_lambda_y = 0

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
                            data[ai + _rest_length_offset],
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
                            data[bi + _bending_rest_offset],
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
                    self._volume_lambda = _enforce_volume(
                        data, n_particles,
                        self._volume_gradient,
                        self._volume,
                        volume_alpha,
                        self._volume_lambda
                    )

                    -- An active point anchor supplies an external torque. Do not
                    -- project that angular motion away: doing so makes an off-center
                    -- drag behave like a translation-only kinematic move.
                    if not anchor_active then
                        self._angular_velocity_lambda = _enforce_angular_momentum(
                            data, n_particles,
                            0,
                            sub_delta,
                            angular_alpha,
                            self._angular_velocity_lambda
                        )
                    end

                    if self._pinch_x ~= nil and self._pinch_y ~= nil then
                        self._pinch_lambda_x, self._pinch_lambda_y = _enforce_pinch(
                            data, 1,
                            self._pinch_x, self._pinch_y,
                            anchor_alpha,
                            self._pinch_lambda_x,
                            self._pinch_lambda_y
                        )
                    end

                    if anchor_active then
                        self._anchor_lambda_x, self._anchor_lambda_y = _enforce_anchor(
                            data, n_particles,
                            anchor_weights,
                            anchor_x, anchor_y,
                            anchor_alpha,
                            self._anchor_lambda_x,
                            self._anchor_lambda_y
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

        self._elapsed = math.min(self._elapsed, timestep) -- prevent accumulating death spiral

        -- update draw contour
        local draw_contour_vertices = self._draw_contour:get_vertices()
        local frame_interpolation_alpha = self._elapsed / timestep

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

        self._centroid_x = centroid_x / self._n_particles
        self._centroid_y = centroid_y / self._n_particles

        return self
    end
end

-- volume

function rt.SoftBody:set_target_volume(fraction) -- fraction
    meta.typecheck(self, rt.SoftBody, fraction, mt.Number)
    self._volume_multiplier = fraction
    self._volume_lambda = 0
end

function rt.SoftBody:get_target_volume()
    meta.typecheck(self, rt.SoftBody)
    return self._volume_multiplier
end

function rt.SoftBody:set_gravity(dx, dy)
    meta.typecheck(self, rt.SoftBody, dx, mt.Number, dy, mt.Number)
    self._gravity_x, self._gravity_y = dx, dy
end

local _entry_hash = 0
local _get_hash = function()
    local hash = _entry_hash
    _entry_hash = _entry_hash + 1
    return hash
end

-- linear

function rt.SoftBody:add_linear_force(dx, dy)
    meta.typecheck(self, rt.SoftBody, dx, mt.Number, dy, mt.Number)
    local magnitude = math.magnitude(dx, dy)
    if magnitude <= math.eps then
        return
    end

    dx, dy = math.normalize(dx, dy)
    local id = _get_hash()
    self._linear_forces[id] = {
        magnitude = magnitude,
        dx = dx,
        dy = dy
    }
    return id
end

function rt.SoftBody:remove_linear_force(hash)
    if hash == nil then return end
    meta.typecheck(self, rt.SoftBody, hash, mt.Number)
    self._linear_forces[hash] = nil
end

function rt.SoftBody:add_linear_impulse(dx, dy)
    meta.typecheck(self, rt.SoftBody, dx, mt.Number, dy, mt.Number)
    local magnitude = math.magnitude(dx, dy)
    if magnitude > math.eps then
        dx, dy = math.normalize(dx, dy)
        local id = _get_hash()
        self._linear_impulses[id] = {
            magnitude = magnitude,
            dx = dx,
            dy = dy
        }
        return id
    end
end

function rt.SoftBody:remove_linear_impulse(hash)
    if hash == nil then return end
    meta.typecheck(self, rt.SoftBody, hash, mt.Number)
    self._linear_impulses[hash] = nil
end

-- rotation

function rt.SoftBody:add_angular_force(torque)
    meta.typecheck(self, rt.SoftBody, torque, mt.Number)
    if torque ~= 0 then
        local id = _get_hash()
        self._angular_forces[id] = {
            torque = torque
        }
        return id
    end
end

function rt.SoftBody:remove_angular_force(hash)
    if hash == nil then return end
    meta.typecheck(self, rt.SoftBody, hash, mt.Number)
    self._angular_forces[hash] = nil
end

function rt.SoftBody:add_angular_impulse(angular_impulse)
    meta.typecheck(self, rt.SoftBody, angular_impulse, mt.Number)
    if angular_impulse ~= 0 then
        local id = _get_hash()
        self._angular_impulses[id] = {
            angular_impulse = angular_impulse
        }
        return id
    end
end

function rt.SoftBody:remove_angular_impulse(hash)
    if hash == nil then return end
    meta.typecheck(self, rt.SoftBody, hash, mt.Number)
    self._angular_impulses[hash] = nil
end

function rt.SoftBody:get_centroid()
    meta.typecheck(self, rt.SoftBody)
    return self._centroid_x, self._centroid_y
end

--- qbrief
function rt.SoftBody:set_pinch(x, y)
    self._pinch_x, self._pinch_y = x, y
end

--- @brief weights w_i (sum 1) such that sum(w_i * p_i) is the material point at
--- (rest center - offset), expressed in the body's rest frame. For a rigid motion
--- of the body this point moves exactly with it, so pinning it makes the body
--- rotate around the anchor. Uses the best-fit linear map A = sum(m p q^T) (sum m q q^T)^-1.
function rt.SoftBody:_compute_pivot_weights(offset_x, offset_y)
    local data = self._particles
    local n = self._n_particles
    local rest_xs, rest_ys = self._rest_xs, self._rest_ys

    local mass_sum, cx, cy = 0, 0, 0
    for particle_i = 1, n do
        local m = data[_particle_i_to_data_offset(particle_i) + _mass_offset]
        mass_sum = mass_sum + m
        cx = cx + m * rest_xs[particle_i]
        cy = cy + m * rest_ys[particle_i]
    end
    cx, cy = cx / mass_sum, cy / mass_sum

    -- S = sum m q q^T (2x2 symmetric)
    local sxx, sxy, syy = 0, 0, 0
    for particle_i = 1, n do
        local m = data[_particle_i_to_data_offset(particle_i) + _mass_offset]
        local qx, qy = rest_xs[particle_i] - cx, rest_ys[particle_i] - cy
        sxx = sxx + m * qx * qx
        sxy = sxy + m * qx * qy
        syy = syy + m * qy * qy
    end

    -- r = vector from rest center to the pivot; S^-1 r via the 2x2 inverse
    local rx, ry = -offset_x, -offset_y
    local det = sxx * syy - sxy * sxy
    local weights = {}

    if math.abs(det) < math.eps then
        -- degenerate shape: fall back to pinning the center of mass
        for particle_i = 1, n do
            weights[particle_i] = data[_particle_i_to_data_offset(particle_i) + _mass_offset] / mass_sum
        end
        return weights
    end

    local ux = (syy * rx - sxy * ry) / det
    local uy = (-sxy * rx + sxx * ry) / det

    for particle_i = 1, n do
        local m = data[_particle_i_to_data_offset(particle_i) + _mass_offset]
        local qx, qy = rest_xs[particle_i] - cx, rest_ys[particle_i] - cy
        weights[particle_i] = m / mass_sum + m * (qx * ux + qy * uy)
    end

    return weights
end

--- @brief the body rotates around and is pulled so that the pivot (rest center - offset) sits on the anchor; at rest orientation the center is at (x + offset_x, y + offset_y)
function rt.SoftBody:set_anchor(x, y, offset_x, offset_y)
    if offset_x == nil then offset_x = 0 end
    if offset_y == nil then offset_y = 0 end
    meta.typecheck(self, rt.SoftBody, x, mt.Number, y, mt.Number, offset_x, mt.Number, offset_y, mt.Number)

    if self._anchor_particle_i == nil then
        local data = self._particles
        local nearest_particle_i = nil
        local nearest_distance_squared = math.huge

        for particle_i = 1, self._n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            if data[i + _inverse_mass_offset] > 0 then
                local dx = data[i + _x_offset] - x
                local dy = data[i + _y_offset] - y
                local distance_squared = dx * dx + dy * dy

                if distance_squared < nearest_distance_squared then
                    nearest_distance_squared = distance_squared
                    nearest_particle_i = particle_i
                end
            end
        end

        rt.assert(nearest_particle_i ~= nil,
            "In softbody_set_anchor: cannot anchor a softbody without movable particles")
        self._anchor_particle_i = nearest_particle_i
    end

    self._anchor_particle_i = 1
    self._anchor_x, self._anchor_y = x, y
    self._anchor_offset_x, self._anchor_offset_y = offset_x, offset_y

    if self._anchor_weights == nil
        or self._anchor_weights_offset_x ~= offset_x
        or self._anchor_weights_offset_y ~= offset_y
    then
        self._anchor_weights = self:_compute_pivot_weights(offset_x, offset_y)
        self._anchor_weights_offset_x = offset_x
        self._anchor_weights_offset_y = offset_y
    end

    return self
end

function rt.SoftBody:clear_anchor()
    meta.typecheck(self, rt.SoftBody)
    self._anchor_x, self._anchor_y = nil, nil
    self._anchor_offset_x, self._anchor_offset_y = 0, 0
    self._anchor_weights = nil
    self._anchor_weights_offset_x, self._anchor_weights_offset_y = nil, nil
    self._anchor_particle_i = nil
    self._anchor_lambda_x, self._anchor_lambda_y = 0, 0
    return self
end

function rt.SoftBody:clear_forces()
    meta.typecheck(self, rt.SoftBody)

    -- clear pending impulses and persistent forces
    for id in pairs(self._linear_impulses) do
        self._linear_impulses[id] = nil
    end

    for id in pairs(self._angular_impulses) do
        self._angular_impulses[id] = nil
    end

    for id in pairs(self._linear_forces) do
        self._linear_forces[id] = nil
    end

    for id in pairs(self._angular_forces) do
        self._angular_forces[id] = nil
    end

    local data = self._particles
    for particle_i = 1, self._n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        data[i + _velocity_x_offset] = 0
        data[i + _velocity_y_offset] = 0
    end

    return self
end

function rt.SoftBody:set_friction(static_friction, kinetic_friction)
    meta.typecheck(self, rt.SoftBody, static_friction, mt.Number, kinetic_friction, mt.Number)
    rt.assert(static_friction >= 0 and kinetic_friction >= 0, "In softbody_set_friction: coefficients must be non-negative")
    self._static_friction = static_friction
    self._kinetic_friction = math.min(kinetic_friction, static_friction)
    return self
end

function rt.SoftBody:get_mass()
    local data = self._particles
    local total = 0
    for particle_i = 1, self._n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        if data[i + _inverse_mass_offset] > 0 then
            total = total + data[i + _mass_offset]
        end
    end
    return total
end

do -- softbody_relax
    local eps = math.eps
    local dot = math.dot

    function rt.SoftBody:relax()
        meta.typecheck(self, rt.SoftBody)

        local eps_squared = eps * eps
        local data = self._particles
        local n_particles = self._n_particles

        -- recover initial positions, same de-duplication as instantiate
        local source = self._initial_contour:get_vertices()
        local n_source = math.floor(#source / 2)
        local xs, ys = {}, {}
        local n_initial = 0

        for source_i = 1, n_source do
            local x, y = source[2 * source_i - 1], source[2 * source_i]
            local is_new = true
            if n_initial > 0 then
                local dx, dy = x - xs[n_initial], y - ys[n_initial]
                is_new = dot(dx, dy, dx, dy) > eps_squared
            end

            if is_new then
                n_initial = n_initial + 1
                xs[n_initial], ys[n_initial] = x, y
            end
        end

        if n_initial > 1 then
            local dx, dy = xs[n_initial] - xs[1], ys[n_initial] - ys[1]
            if dot(dx, dy, dx, dy) <= eps_squared then
                n_initial = n_initial - 1
            end
        end

        rt.assert(n_initial == n_particles, "In softbody_relax: initial contour no longer matches particle count")

        -- centroids
        local initial_centroid_x, initial_centroid_y = 0, 0
        local current_centroid_x, current_centroid_y = 0, 0

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            initial_centroid_x = initial_centroid_x + xs[particle_i]
            initial_centroid_y = initial_centroid_y + ys[particle_i]
            current_centroid_x = current_centroid_x + data[i + _x_offset]
            current_centroid_y = current_centroid_y + data[i + _y_offset]
        end

        initial_centroid_x = initial_centroid_x / n_particles
        initial_centroid_y = initial_centroid_y / n_particles
        current_centroid_x = current_centroid_x / n_particles
        current_centroid_y = current_centroid_y / n_particles

        -- reset to initial offset from the current centroid
        local draw_contour_vertices = self._draw_contour:get_vertices()

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local contour_i = (particle_i - 1) * 2 + 1

            local x = current_centroid_x + (xs[particle_i] - initial_centroid_x)
            local y = current_centroid_y + (ys[particle_i] - initial_centroid_y)

            data[i + _x_offset] = x
            data[i + _y_offset] = y
            data[i + _previous_x_offset] = x
            data[i + _previous_y_offset] = y
            data[i + _snapshot_x_offset] = x
            data[i + _snapshot_y_offset] = y
            data[i + _draw_x_offset] = x
            data[i + _draw_y_offset] = y
            data[i + _velocity_x_offset] = 0
            data[i + _velocity_y_offset] = 0

            data[i + _distance_lambda_offset] = 0
            data[i + _bending_lambda_offset] = 0
            data[i + _polygon_lambda_offset] = 0

            draw_contour_vertices[contour_i + 0] = x
            draw_contour_vertices[contour_i + 1] = y
        end

        draw_contour_vertices[n_particles * 2 + 1] = draw_contour_vertices[1]
        draw_contour_vertices[n_particles * 2 + 2] = draw_contour_vertices[2]

        self._centroid_x = current_centroid_x
        self._centroid_y = current_centroid_y

        self._volume_lambda = 0
        self._angular_velocity_lambda = 0
        self._linear_velocity_lambda_x = 0
        self._linear_velocity_lambda_y = 0
        self._anchor_lambda_x = 0
        self._anchor_lambda_y = 0
        self._pinch_lambda_x = 0
        self._pinch_lambda_y = 0

        return self
    end
end

--- @brief
function rt.SoftBody:set_config(config)
    config_schema:validate(config)
    self._override = config
end

do -- softbody_set_shape
    local eps = math.eps
    local dot = math.dot

    --- @brief
    function rt.SoftBody:set_shape(contour)
        meta.typecheck(self, rt.SoftBody)
        meta.typecheck(contour, rt.Polyline)

        local eps_squared = eps * eps
        local data = self._particles
        local n_particles = self._n_particles

        local source = contour:get_vertices()
        local n_source = math.floor(#source / 2)
        local xs, ys = {}, {}
        local n_vertices = 0

        for source_i = 1, n_source do
            local x, y = source[2 * source_i - 1], source[2 * source_i]
            local is_new = true
            if n_vertices > 0 then
                local dx, dy = x - xs[n_vertices], y - ys[n_vertices]
                is_new = dot(dx, dy, dx, dy) > eps_squared
            end

            if is_new then
                n_vertices = n_vertices + 1
                xs[n_vertices], ys[n_vertices] = x, y
            end
        end

        if n_vertices > 1 then
            local dx, dy = xs[n_vertices] - xs[1], ys[n_vertices] - ys[1]
            if dot(dx, dy, dx, dy) <= eps_squared then
                n_vertices = n_vertices - 1
            end
        end

        rt.assert(n_vertices == n_particles, "In softbody_set_shape: contour vertex count does not match particle count")

        local centroid_x, centroid_y = 0, 0
        for particle_i = 1, n_particles do
            centroid_x = centroid_x + xs[particle_i]
            centroid_y = centroid_y + ys[particle_i]
        end
        centroid_x = centroid_x / n_particles
        centroid_y = centroid_y / n_particles

        local draw_contour_vertices = self._draw_contour:get_vertices()

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local contour_i = (particle_i - 1) * 2 + 1
            local x, y = xs[particle_i], ys[particle_i]

            data[i + _x_offset] = x
            data[i + _y_offset] = y
            data[i + _previous_x_offset] = x
            data[i + _previous_y_offset] = y
            data[i + _snapshot_x_offset] = x
            data[i + _snapshot_y_offset] = y
            data[i + _draw_x_offset] = x
            data[i + _draw_y_offset] = y
            data[i + _velocity_x_offset] = 0
            data[i + _velocity_y_offset] = 0

            data[i + _distance_lambda_offset] = 0
            data[i + _bending_lambda_offset] = 0
            data[i + _polygon_lambda_offset] = 0

            draw_contour_vertices[contour_i + 0] = x
            draw_contour_vertices[contour_i + 1] = y
        end

        draw_contour_vertices[n_particles * 2 + 1] = draw_contour_vertices[1]
        draw_contour_vertices[n_particles * 2 + 2] = draw_contour_vertices[2]

        self._centroid_x = centroid_x
        self._centroid_y = centroid_y

        self._volume_lambda = 0
        self._angular_velocity_lambda = 0
        self._linear_velocity_lambda_x = 0
        self._linear_velocity_lambda_y = 0
        self._anchor_lambda_x = 0
        self._anchor_lambda_y = 0
        self._pinch_lambda_x = 0
        self._pinch_lambda_y = 0

        return self
    end
end