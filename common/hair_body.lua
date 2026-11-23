rt.settings.softbody = {
    max_n_steps = 8,

    default = {
        damping = 1 - 1e-4,
        n_sub_steps = 2,
        n_constraint_iterations = 2,
        timestep = 1 / 120,

        static_friction = 0.7,
        kinetic_friction = 0.5,

        distance_compliance = 1e-6,
        enforce_distance = true,

        volume_compliance = 0,
        enforce_volume = true,

        contour_collision_compliance = 0,
        enforce_contour_collision = true,

        bending_compliance = 1e-6,
        enforce_bending = true,

        angular_momentum_compliance = 0,
        enforce_angular_momentum = true,

        linear_momentum_compliance = 0,
        enforce_linear_momentum = true,

        anchor_compliance = 1e-8,
        enforce_anchor = true,

        pinch_compliance = 1e-8,
        enforce_pinch = false
    }
}

local NumberMaybe = mt.Optional(mt.Number)
local BooleanMaybe = mt.Optional(mt.Boolean)
local IntegerMaybe = mt.Optional(mt.Integer)

local ConfigSchema = meta.Schema({
    static_friction = NumberMaybe,
    kinetic_friction = NumberMaybe,

    distance_compliance = NumberMaybe,
    enforce_distance = BooleanMaybe,

    volume_compliance = NumberMaybe,
    enforce_volume = BooleanMaybe,

    contour_collision_compliance = NumberMaybe,
    enforce_contour_collision = BooleanMaybe,

    bending_compliance = NumberMaybe,
    enforce_bending = BooleanMaybe,

    angular_momentum_compliance = NumberMaybe,
    enforce_angular_momentum = BooleanMaybe,

    particle_collision_compliance = NumberMaybe,
    enforce_particle_collision = BooleanMaybe,

    linear_momentum_compliance = NumberMaybe,
    enforce_linear_momentum = BooleanMaybe,

    anchor_compliance = NumberMaybe,
    enforce_anchor = BooleanMaybe,

    pinch_compliance = NumberMaybe,
    enforce_pinch = BooleanMaybe,

    damping = NumberMaybe,
    timestep = NumberMaybe,
    n_sub_steps = IntegerMaybe,
    n_constraint_iterations = IntegerMaybe
})

--- @class rt.Softbody
rt.SoftBody = meta.class("SoftBody")

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
local _anchor_weight_offset = 13
local _rest_length_offset = 14
local _bending_rest_offset = 15
local _distance_lambda_offset = 16
local _bending_lambda_offset = 17

local _stride = _bending_lambda_offset + 1

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

function rt.SoftBody:instantiate(contour)
    meta.typecheck(
        self, rt.SoftBody,
        contour, rt.Polyline
    )

    self._initial_contour = contour
    self._contraction = 1

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
        data[base + _anchor_weight_offset] = 0
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

        data[bi + _rest_length_offset] = math.distance(bx, by, cx, cy)

        local chord_x, chord_y = cx - ax, cy - ay
        local chord_length = math.magnitude(chord_x, chord_y)
        if chord_length > math.eps then
            local nx, ny = -chord_y / chord_length, chord_x / chord_length
            local ex = 0.5 * (ax + cx) - bx
            local ey = 0.5 * (ay + cy) - by
            data[bi + _bending_rest_offset] = ex * nx + ey * ny
        end

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
    self._angular_momentum_lambda = 0
    self._linear_velocity_lambda_x = 0
    self._linear_velocity_lambda_y = 0

    self._anchor_x = nil
    self._anchor_y = nil
    self._anchor_offset_x = 0
    self._anchor_offset_y = 0
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

    self._linear_forces = {}
    self._linear_impulses = {}

    self._gravity_x = 0
    self._gravity_y = 0

    self._draw_contour = rt.Polyline(draw_contour):close()
    self._collision_contours = {}

    self._is_initialized = true
    self._elapsed = 0
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
    local normalize = math.normalize
    local clamp = math.clamp
    local mix = math.mix

    -- Each constraint kernel reads one particle (and, where required, its
    -- neighbourhood) and returns that particle's correction. The update loop
    -- owns all writes and shared-lambda updates.
    rt.SoftBody._enforce_polygon_collision = function(
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

        local edge_distance = sqrt(min_dist_squared)
        local signed_distance
        local normal_x, normal_y

        if keep_outside then
            signed_distance = inside and -edge_distance or edge_distance
            normal_x, normal_y = best_nx, best_ny
        else
            signed_distance = inside and edge_distance or -edge_distance

            if inside and edge_distance > eps then
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

    rt.SoftBody._enforce_exact_distance = function(
        position_x, position_y, neighbor_x, neighbor_y,
        inverse_mass, neighbor_inverse_mass,
        target_distance,
        alpha,
        lambda_before
    )
        local dx = position_x - neighbor_x
        local dy = position_y - neighbor_y
        local length = magnitude(dx, dy)

        if length < eps then
            return 0, 0, lambda_before
        end

        local denominator = inverse_mass + neighbor_inverse_mass + alpha
        if denominator < eps then
            return 0, 0, lambda_before
        end

        local constraint = length - target_distance
        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = lambda_before + delta_lambda
        local scale = inverse_mass * delta_lambda / length

        return dx * scale, dy * scale, lambda_new
    end

    rt.SoftBody._enforce_bending = function(
        ax, ay, bx, by, cx, cy,
        inverse_mass_a, inverse_mass_b, inverse_mass_c,
        rest, alpha, lambda_before
    )
        local chord_x, chord_y = cx - ax, cy - ay
        local chord_length = magnitude(chord_x, chord_y)
        if chord_length < eps then
            return ax, ay, bx, by, cx, cy, lambda_before
        end

        local inverse_chord_length = 1 / chord_length
        local tx, ty = chord_x * inverse_chord_length, chord_y * inverse_chord_length
        local nx, ny = -ty, tx
        local ex = mix(ax, cx, 0.5) - bx
        local ey = mix(ay, cy, 0.5) - by

        local constraint = dot(ex, ey, nx, ny) - rest
        local k = dot(ex, ey, tx, ty) * inverse_chord_length
        local wa = 0.5 + k
        local wb = -1.0
        local wc = 0.5 - k
        local weight_sum = inverse_mass_a * wa * wa
            + inverse_mass_b * wb * wb
            + inverse_mass_c * wc * wc

        local denominator = weight_sum + alpha
        if denominator < eps then
            return ax, ay, bx, by, cx, cy, lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator

        return
        ax + inverse_mass_a * delta_lambda * wa * nx,
        ay + inverse_mass_a * delta_lambda * wa * ny,
        bx + inverse_mass_b * delta_lambda * wb * nx,
        by + inverse_mass_b * delta_lambda * wb * ny,
        cx + inverse_mass_c * delta_lambda * wc * nx,
        cy + inverse_mass_c * delta_lambda * wc * ny,
        lambda_before + delta_lambda
    end

    rt.SoftBody._enforce_volume = function(inverse_mass, gradient_x, gradient_y, delta_lambda)
        return inverse_mass * delta_lambda * gradient_x,
        inverse_mass * delta_lambda * gradient_y
    end

    rt.SoftBody._enforce_angular_momentum = function(
        mass, inverse_mass,
        previous_x, previous_y,
        center_x, center_y,
        delta_lambda
    )
        if inverse_mass <= 0 or mass <= 0 then
            return 0, 0
        end

        local rx = previous_x - center_x
        local ry = previous_y - center_y
        return inverse_mass * delta_lambda * (-mass * ry),
        inverse_mass * delta_lambda * (mass * rx)
    end

    rt.SoftBody._enforce_linear_momentum = function(
        mass, inverse_mass,
        delta_lambda_x, delta_lambda_y
    )
        if inverse_mass <= 0 or mass <= 0 then
            return 0, 0
        end

        return inverse_mass * mass * delta_lambda_x,
        inverse_mass * mass * delta_lambda_y
    end

    rt.SoftBody._enforce_friction = function(
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

    rt.SoftBody._enforce_pinch = function(
        position_x, position_y, inverse_mass,
        anchor_x, anchor_y,
        alpha,
        lambda_x_before, lambda_y_before
    )
        if inverse_mass <= 0 then
            return 0, 0, lambda_x_before, lambda_y_before
        end

        local denominator = inverse_mass + alpha
        if denominator < eps then
            return 0, 0, lambda_x_before, lambda_y_before
        end

        local constraint_x = position_x - anchor_x
        local constraint_y = position_y - anchor_y
        local delta_lambda_x = -(constraint_x + alpha * lambda_x_before) / denominator
        local delta_lambda_y = -(constraint_y + alpha * lambda_y_before) / denominator

        return inverse_mass * delta_lambda_x,
        inverse_mass * delta_lambda_y,
        lambda_x_before + delta_lambda_x,
        lambda_y_before + delta_lambda_y
    end

    rt.SoftBody._enforce_anchor = function(inverse_mass, weight, delta_lambda_x, delta_lambda_y)
        if inverse_mass <= 0 then
            return 0, 0
        end

        return inverse_mass * weight * delta_lambda_x,
        inverse_mass * weight * delta_lambda_y
    end

    -- Public solver kernels shared by SoftBody and HairBody.
    local _enforce_polygon_collision = rt.SoftBody._enforce_polygon_collision
    local _enforce_exact_distance = rt.SoftBody._enforce_exact_distance
    local _enforce_bending = rt.SoftBody._enforce_bending
    local _enforce_volume = rt.SoftBody._enforce_volume
    local _enforce_angular_momentum = rt.SoftBody._enforce_angular_momentum
    local _enforce_linear_momentum = rt.SoftBody._enforce_linear_momentum
    local _enforce_friction = rt.SoftBody._enforce_friction
    local _enforce_pinch = rt.SoftBody._enforce_pinch
    local _enforce_anchor = rt.SoftBody._enforce_anchor

    function rt.SoftBody:update(delta)
        meta.typecheck(self, rt.SoftBody, delta, mt.Number)
        if delta <= 0 then return self end

        local override = self._override or {}
        local default = rt.settings.softbody.default

        local get_setting = function(name)
            if override[name] ~= nil then
                return override[name]
            elseif default[name] ~= nil then
                return default[name]
            else
                rt.error("In rt.SoftBody.update: unhandled settings key `", name, "`")
            end
        end

        local damping = get_setting("damping")
        local timestep = get_setting("timestep")
        local n_sub_steps = get_setting("n_sub_steps")
        local n_constraint_iterations = get_setting("n_constraint_iterations")
        local max_n_steps = rt.settings.softbody.max_n_steps

        local sub_delta = timestep / n_sub_steps
        local sub_delta_sq = sub_delta * sub_delta

        local contraction = self._contraction

        local volume_alpha = get_setting("volume_compliance") / sub_delta_sq
        local contour_alpha = get_setting("contour_collision_compliance") / sub_delta_sq
        local distance_alpha = get_setting("distance_compliance") / sub_delta_sq
        local bending_alpha = get_setting("bending_compliance") / sub_delta_sq
        local angular_alpha = get_setting("angular_momentum_compliance") / sub_delta_sq
        local linear_alpha = get_setting("linear_momentum_compliance") / sub_delta_sq
        local anchor_alpha = get_setting("anchor_compliance") / sub_delta_sq
        local pinch_alpha = get_setting("pinch_compliance") / sub_delta_sq

        local static_friction = get_setting("static_friction")
        local kinetic_friction = get_setting("kinetic_friction")

        local enforce_friction = static_friction > 0 or kinetic_friction > 0
        local enforce_distance = get_setting("enforce_distance")
        local enforce_volume = get_setting("enforce_volume")
        local enforce_contour_collision = get_setting("enforce_contour_collision")
        local enforce_bending = get_setting("enforce_bending")
        local enforce_angular_momentum = get_setting("enforce_angular_momentum")
        local enforce_linear_momentum = get_setting("enforce_linear_momentum")
        local enforce_pinch = get_setting("enforce_pinch")
        local enforce_anchor = get_setting("enforce_anchor")

        enforce_friction = enforce_friction and (static_friction > 0 or kinetic_friction > 0)

        local target_area = self._volume * self._volume_multiplier * contraction * contraction

        local data = self._particles
        local n_particles = self._n_particles
        local collision_contours = self._collision_contours
        local n_collision_contours = #collision_contours

        local volume_gradient = self._volume_gradient

        local anchor_x, anchor_y = self._anchor_x, self._anchor_y
        local anchor_particle_i = self._anchor_particle_i
        enforce_anchor = enforce_anchor and anchor_x ~= nil and anchor_y ~= nil and anchor_particle_i ~= nil

        local pinch_x, pinch_y = self._pinch_x, self._pinch_y
        enforce_pinch = enforce_pinch and (pinch_x ~= nil and pinch_y ~= nil)

        local gravity_x = self._gravity_x
        local gravity_y = self._gravity_y

        local linear_force_x, linear_force_y = 0, 0
        for _, entry in pairs(self._linear_forces) do
            linear_force_x = linear_force_x + entry.magnitude * entry.dx
            linear_force_y = linear_force_y + entry.magnitude * entry.dy
        end

        local impulse_x, impulse_y = 0, 0
        for _, entry in pairs(self._linear_impulses) do
            impulse_x = impulse_x + entry.magnitude * entry.dx
            impulse_y = impulse_y + entry.magnitude * entry.dy
        end
        table.clear(self._linear_impulses)

        if impulse_x ~= 0 or impulse_y ~= 0 then
            local total_mass = 0
            for particle_i = 1, n_particles do
                local i = _particle_i_to_data_offset(particle_i)
                local inverse_mass = data[i + _inverse_mass_offset]
                local mass = data[i + _mass_offset]
                if inverse_mass > 0 and mass > 0 then
                    total_mass = total_mass + mass
                end
            end

            if total_mass > eps then
                local delta_velocity_x = impulse_x / total_mass
                local delta_velocity_y = impulse_y / total_mass
                for particle_i = 1, n_particles do
                    local i = _particle_i_to_data_offset(particle_i)
                    if data[i + _inverse_mass_offset] > 0 then
                        data[i + _velocity_x_offset] = data[i + _velocity_x_offset] + delta_velocity_x
                        data[i + _velocity_y_offset] = data[i + _velocity_y_offset] + delta_velocity_y
                    end
                end
            end
        end

        self._elapsed = self._elapsed + delta
        local n_steps = 0
        local reverse_iteration = self._reverse_iteration or false

        while self._elapsed >= timestep and n_steps < max_n_steps do
            self._elapsed = self._elapsed - timestep
            n_steps = n_steps + 1

            -- snapshot for frame interpolation
            for particle_i = 1, n_particles do
                local i = _particle_i_to_data_offset(particle_i)
                data[i + _snapshot_x_offset] = data[i + _x_offset]
                data[i + _snapshot_y_offset] = data[i + _y_offset]
            end

            for _ = 1, n_sub_steps do
                -- flip flop gauss-seidel direction to prevent injection angular momentum
                reverse_iteration = not reverse_iteration
                local first_particle_i, last_particle_i, particle_step
                if reverse_iteration then
                    first_particle_i, last_particle_i, particle_step = n_particles, 1, -1
                else
                    first_particle_i, last_particle_i, particle_step = 1, n_particles, 1
                end

                for contour_i = 1, n_collision_contours do
                    local lambdas = collision_contours[contour_i].lambdas
                    for particle_i = 1, n_particles do
                        lambdas[particle_i] = 0
                    end
                end

                local total_mass = 0
                for particle_i = 1, n_particles do
                    local i = _particle_i_to_data_offset(particle_i)
                    local inverse_mass = data[i + _inverse_mass_offset]
                    local mass = data[i + _mass_offset]
                    if inverse_mass > 0 and mass > 0 then
                        total_mass = total_mass + mass
                    end
                end

                local force_acceleration_x, force_acceleration_y = 0, 0
                if total_mass > eps then
                    force_acceleration_x = linear_force_x / total_mass
                    force_acceleration_y = linear_force_y / total_mass
                end

                -- integrate
                for particle_i = 1, n_particles do
                    local i = _particle_i_to_data_offset(particle_i)
                    local position_x = data[i + _x_offset]
                    local position_y = data[i + _y_offset]
                    local inverse_mass = data[i + _inverse_mass_offset]
                    local acceleration_x = gravity_x + force_acceleration_x
                    local acceleration_y = gravity_y + force_acceleration_y

                    local velocity_x, velocity_y = 0, 0
                    local new_position_x, new_position_y = position_x, position_y
                    if inverse_mass > 0 then
                        velocity_x = data[i + _velocity_x_offset] * damping + acceleration_x * sub_delta
                        velocity_y = data[i + _velocity_y_offset] * damping + acceleration_y * sub_delta
                        new_position_x = position_x + velocity_x * sub_delta
                        new_position_y = position_y + velocity_y * sub_delta
                    end

                    data[i + _x_offset] = new_position_x
                    data[i + _y_offset] = new_position_y
                    data[i + _velocity_x_offset] = velocity_x
                    data[i + _velocity_y_offset] = velocity_y
                    data[i + _previous_x_offset] = position_x
                    data[i + _previous_y_offset] = position_y

                    data[i + _distance_lambda_offset] = 0
                    data[i + _bending_lambda_offset] = 0
                end

                self._volume_lambda = 0
                self._angular_momentum_lambda = 0
                self._linear_velocity_lambda_x = 0
                self._linear_velocity_lambda_y = 0
                self._anchor_lambda_x = 0
                self._anchor_lambda_y = 0

                for _ = 1, n_constraint_iterations do
                    -- distance
                    if enforce_distance then
                        for particle_i = first_particle_i, last_particle_i, particle_step do
                            local ai = _particle_i_to_data_offset(particle_i)
                            local bi = _particle_i_to_data_offset(particle_i + 1, n_particles)

                            local ax, ay = data[ai + _x_offset], data[ai + _y_offset]
                            local bx, by = data[bi + _x_offset], data[bi + _y_offset]
                            local inverse_mass_a = data[ai + _inverse_mass_offset]
                            local inverse_mass_b = data[bi + _inverse_mass_offset]
                            local lambda_before = data[ai + _distance_lambda_offset]

                            local correction_ax, correction_ay, lambda_new = _enforce_exact_distance(
                                ax, ay, bx, by,
                                inverse_mass_a, inverse_mass_b,
                                data[ai + _rest_length_offset] * contraction,
                                distance_alpha,
                                lambda_before
                            )

                            local correction_bx, correction_by = _enforce_exact_distance(
                                bx, by, ax, ay,
                                inverse_mass_b, inverse_mass_a,
                                data[ai + _rest_length_offset] * contraction,
                                distance_alpha,
                                lambda_before
                            )

                            data[ai + _x_offset] = ax + correction_ax
                            data[ai + _y_offset] = ay + correction_ay
                            data[bi + _x_offset] = bx + correction_bx
                            data[bi + _y_offset] = by + correction_by
                            data[ai + _distance_lambda_offset] = lambda_new
                        end
                    end

                    -- bending
                    if enforce_bending then
                        for particle_i = first_particle_i, last_particle_i, particle_step do
                            local ai = _particle_i_to_data_offset(particle_i)
                            local bi = _particle_i_to_data_offset(particle_i + 1, n_particles)
                            local ci = _particle_i_to_data_offset(particle_i + 2, n_particles)

                            local new_ax, new_ay, new_bx, new_by, new_cx, new_cy, new_lambda = _enforce_bending(
                                data[ai + _x_offset], data[ai + _y_offset],
                                data[bi + _x_offset], data[bi + _y_offset],
                                data[ci + _x_offset], data[ci + _y_offset],
                                data[ai + _inverse_mass_offset],
                                data[bi + _inverse_mass_offset],
                                data[ci + _inverse_mass_offset],
                                data[bi + _bending_rest_offset] * contraction,
                                bending_alpha,
                                data[ai + _bending_lambda_offset]
                            )

                            data[ai + _x_offset], data[ai + _y_offset] = new_ax, new_ay
                            data[bi + _x_offset], data[bi + _y_offset] = new_bx, new_by
                            data[ci + _x_offset], data[ci + _y_offset] = new_cx, new_cy
                            data[ai + _bending_lambda_offset] = new_lambda
                        end
                    end

                    -- volume
                    if enforce_volume then
                        local current_area = 0
                        local weight_sum = 0
                        for particle_i = 1, n_particles do
                            local previous_i = _particle_i_to_data_offset(particle_i - 1, n_particles)
                            local current_i = _particle_i_to_data_offset(particle_i)
                            local next_i = _particle_i_to_data_offset(particle_i + 1, n_particles)

                            local previous_x = data[previous_i + _x_offset]
                            local previous_y = data[previous_i + _y_offset]
                            local current_x = data[current_i + _x_offset]
                            local current_y = data[current_i + _y_offset]
                            local next_x = data[next_i + _x_offset]
                            local next_y = data[next_i + _y_offset]

                            current_area = current_area + 0.5 * cross(current_x, current_y, next_x, next_y)

                            local gradient_x = 0.5 * (next_y - previous_y)
                            local gradient_y = 0.5 * (previous_x - next_x)
                            local gradient_i = 2 * particle_i - 1
                            volume_gradient[gradient_i] = gradient_x
                            volume_gradient[gradient_i + 1] = gradient_y

                            local inverse_mass = data[current_i + _inverse_mass_offset]
                            weight_sum = weight_sum + inverse_mass * dot(gradient_x, gradient_y, gradient_x, gradient_y)
                        end

                        local volume_denominator = weight_sum + volume_alpha
                        if volume_denominator >= eps then
                            local volume_constraint = current_area - target_area
                            local volume_delta_lambda = -(volume_constraint + volume_alpha * self._volume_lambda)
                                / volume_denominator
                            local volume_lambda_new = self._volume_lambda + volume_delta_lambda

                            for particle_i = 1, n_particles do
                                local i = _particle_i_to_data_offset(particle_i)
                                local gradient_i = 2 * particle_i - 1
                                local correction_x, correction_y = _enforce_volume(
                                    data[i + _inverse_mass_offset],
                                    volume_gradient[gradient_i],
                                    volume_gradient[gradient_i + 1],
                                    volume_delta_lambda
                                )
                                data[i + _x_offset] = data[i + _x_offset] + correction_x
                                data[i + _y_offset] = data[i + _y_offset] + correction_y
                            end

                            self._volume_lambda = volume_lambda_new
                        end
                    end

                    if enforce_angular_momentum then
                        local mass_sum = 0
                        local com_x, com_y = 0, 0

                        for particle_i = 1, n_particles do
                            local i = _particle_i_to_data_offset(particle_i)
                            local inverse_mass = data[i + _inverse_mass_offset]
                            local mass = data[i + _mass_offset]
                            if inverse_mass > 0 and mass > 0 then
                                mass_sum = mass_sum + mass
                                com_x = com_x + mass * data[i + _previous_x_offset]
                                com_y = com_y + mass * data[i + _previous_y_offset]
                            end
                        end

                        if mass_sum > 0 then
                            com_x = com_x / mass_sum
                            com_y = com_y / mass_sum

                            local angular_momentum = 0
                            local weight_sum = 0

                            for particle_i = 1, n_particles do
                                local i = _particle_i_to_data_offset(particle_i)
                                local mass = data[i + _mass_offset]
                                local inverse_mass = data[i + _inverse_mass_offset]

                                if inverse_mass > 0 and mass > 0 then
                                    local rx = data[i + _previous_x_offset] - com_x
                                    local ry = data[i + _previous_y_offset] - com_y
                                    local dx = data[i + _x_offset] - data[i + _previous_x_offset]
                                    local dy = data[i + _y_offset] - data[i + _previous_y_offset]

                                    angular_momentum = angular_momentum + mass * cross(rx, ry, dx, dy)
                                    local gx, gy = -mass * ry, mass * rx
                                    weight_sum = weight_sum + inverse_mass * dot(gx, gy, gx, gy)
                                end
                            end

                            local denominator = weight_sum + angular_alpha
                            if denominator > 0 then
                                local constraint = angular_momentum
                                local delta_lambda = -(constraint + angular_alpha * self._angular_momentum_lambda)
                                    / denominator
                                local lambda_new = self._angular_momentum_lambda + delta_lambda

                                for particle_i = 1, n_particles do
                                    local i = _particle_i_to_data_offset(particle_i)
                                    local correction_x, correction_y = _enforce_angular_momentum(
                                        data[i + _mass_offset],
                                        data[i + _inverse_mass_offset],
                                        data[i + _previous_x_offset],
                                        data[i + _previous_y_offset],
                                        com_x, com_y,
                                        delta_lambda
                                    )
                                    data[i + _x_offset] = data[i + _x_offset] + correction_x
                                    data[i + _y_offset] = data[i + _y_offset] + correction_y
                                end

                                self._angular_momentum_lambda = lambda_new
                            end
                        end
                    end

                    if enforce_linear_momentum then
                        local mass_sum = 0
                        local momentum_x, momentum_y = 0, 0
                        local weight_sum = 0

                        for particle_i = 1, n_particles do
                            local i = _particle_i_to_data_offset(particle_i)
                            local inverse_mass = data[i + _inverse_mass_offset]
                            local mass = data[i + _mass_offset]
                            if inverse_mass > 0 and mass > 0 then
                                local dx = data[i + _x_offset] - data[i + _previous_x_offset]
                                local dy = data[i + _y_offset] - data[i + _previous_y_offset]
                                mass_sum = mass_sum + mass
                                momentum_x = momentum_x + mass * dx
                                momentum_y = momentum_y + mass * dy
                                weight_sum = weight_sum + inverse_mass * mass * mass
                            end
                        end

                        local denominator = weight_sum + linear_alpha
                        if mass_sum > 0 and denominator > 0 then
                            local delta_lambda_x = -(momentum_x + linear_alpha * self._linear_velocity_lambda_x)
                                / denominator
                            local delta_lambda_y = -(momentum_y + linear_alpha * self._linear_velocity_lambda_y)
                                / denominator

                            for particle_i = 1, n_particles do
                                local i = _particle_i_to_data_offset(particle_i)
                                local correction_x, correction_y = _enforce_linear_momentum(
                                    data[i + _mass_offset],
                                    data[i + _inverse_mass_offset],
                                    delta_lambda_x,
                                    delta_lambda_y
                                )
                                data[i + _x_offset] = data[i + _x_offset] + correction_x
                                data[i + _y_offset] = data[i + _y_offset] + correction_y
                            end

                            self._linear_velocity_lambda_x = self._linear_velocity_lambda_x + delta_lambda_x
                            self._linear_velocity_lambda_y = self._linear_velocity_lambda_y + delta_lambda_y
                        end
                    end

                    -- pinch a single contour particle
                    if enforce_pinch then
                        local i = _particle_i_to_data_offset(1)
                        local correction_x, correction_y, lambda_x_new, lambda_y_new = _enforce_pinch(
                            data[i + _x_offset],
                            data[i + _y_offset],
                            data[i + _inverse_mass_offset],
                            self._pinch_x, self._pinch_y,
                            pinch_alpha,
                            self._pinch_lambda_x,
                            self._pinch_lambda_y
                        )
                        data[i + _x_offset] = data[i + _x_offset] + correction_x
                        data[i + _y_offset] = data[i + _y_offset] + correction_y
                        self._pinch_lambda_x, self._pinch_lambda_y = lambda_x_new, lambda_y_new
                    end

                    -- translate and pivot the entire contour around a global anchor
                    if enforce_anchor then
                        local point_x, point_y = 0, 0
                        local denominator = anchor_alpha

                        for particle_i = 1, n_particles do
                            local i = _particle_i_to_data_offset(particle_i)
                            local weight = data[i + _anchor_weight_offset]
                            local inverse_mass = data[i + _inverse_mass_offset]
                            point_x = point_x + weight * data[i + _x_offset]
                            point_y = point_y + weight * data[i + _y_offset]
                            if inverse_mass > 0 then
                                denominator = denominator + inverse_mass * weight * weight
                            end
                        end

                        if denominator >= eps then
                            local constraint_x = point_x - anchor_x
                            local constraint_y = point_y - anchor_y
                            local delta_lambda_x = -(constraint_x + anchor_alpha * self._anchor_lambda_x)
                                / denominator
                            local delta_lambda_y = -(constraint_y + anchor_alpha * self._anchor_lambda_y)
                                / denominator
                            local lambda_x_new = self._anchor_lambda_x + delta_lambda_x
                            local lambda_y_new = self._anchor_lambda_y + delta_lambda_y

                            for particle_i = 1, n_particles do
                                local i = _particle_i_to_data_offset(particle_i)
                                local correction_x, correction_y = _enforce_anchor(
                                    data[i + _inverse_mass_offset],
                                    data[i + _anchor_weight_offset],
                                    delta_lambda_x, delta_lambda_y
                                )
                                data[i + _x_offset] = data[i + _x_offset] + correction_x
                                data[i + _y_offset] = data[i + _y_offset] + correction_y
                            end

                            self._anchor_lambda_x, self._anchor_lambda_y = lambda_x_new, lambda_y_new
                        end
                    end
                end

                -- contour collision
                if enforce_contour_collision then
                    for _ = 1, n_constraint_iterations do
                        for contour_i = 1, n_collision_contours do
                            local entry = collision_contours[contour_i]
                            local edges = entry.edges
                            local n_edges = entry.n_edges
                            local lambdas = entry.lambdas
                            local normals_x, normals_y = entry.normals_x, entry.normals_y
                            local keep_outside = entry.contour:get_winding()

                            for particle_i = first_particle_i, last_particle_i, particle_step do
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

                    if enforce_friction then
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
                end

                for particle_i = 1, n_particles do
                    local i = _particle_i_to_data_offset(particle_i)
                    data[i + _velocity_x_offset] = (data[i + _x_offset] - data[i + _previous_x_offset]) / sub_delta
                    data[i + _velocity_y_offset] = (data[i + _y_offset] - data[i + _previous_y_offset]) / sub_delta
                end
            end -- n_sub_steps
        end -- timestep

        self._reverse_iteration = reverse_iteration
        self._elapsed = math.min(self._elapsed, timestep) -- prevent accumulating death spiral

        -- update draw contour
        local draw_contour_vertices = self._draw_contour:get_vertices()
        local frame_interpolation_alpha = self._elapsed / timestep
        local centroid_x, centroid_y = 0, 0

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local contour_i = (particle_i - 1) * 2 + 1
            local previous_x = data[i + _snapshot_x_offset]
            local previous_y = data[i + _snapshot_y_offset]
            local current_x = data[i + _x_offset]
            local current_y = data[i + _y_offset]

            local x = previous_x + (current_x - previous_x) * frame_interpolation_alpha
            local y = previous_y + (current_y - previous_y) * frame_interpolation_alpha

            data[i + _draw_x_offset] = x
            data[i + _draw_y_offset] = y
            draw_contour_vertices[contour_i] = x
            draw_contour_vertices[contour_i + 1] = y
            centroid_x = centroid_x + x
            centroid_y = centroid_y + y
        end

        draw_contour_vertices[n_particles * 2 + 1] = draw_contour_vertices[1]
        draw_contour_vertices[n_particles * 2 + 2] = draw_contour_vertices[2]

        self._centroid_x = centroid_x / n_particles
        self._centroid_y = centroid_y / n_particles

        return self
    end
end

function rt.SoftBody:set_target_volume(fraction)
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

-- linear forces and impulses

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

function rt.SoftBody:get_centroid()
    meta.typecheck(self, rt.SoftBody)
    return self._centroid_x, self._centroid_y
end

--- @brief
function rt.SoftBody:set_pinch(x, y)
    self._pinch_x, self._pinch_y = x, y
end

--- @brief
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

    self._anchor_x, self._anchor_y = x, y
    self._anchor_offset_x, self._anchor_offset_y = offset_x, offset_y

    if self._anchor_weight_offset_x ~= offset_x
        or self._anchor_weight_offset_y ~= offset_y
    then
        local data = self._particles
        local n_particles = self._n_particles
        local rest_xs, rest_ys = self._rest_xs, self._rest_ys

        local mass_sum, center_x, center_y = 0, 0, 0
        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local mass = data[i + _mass_offset]
            mass_sum = mass_sum + mass
            center_x = center_x + mass * rest_xs[particle_i]
            center_y = center_y + mass * rest_ys[particle_i]
        end
        center_x, center_y = center_x / mass_sum, center_y / mass_sum

        local sxx, sxy, syy = 0, 0, 0
        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local mass = data[i + _mass_offset]
            local qx = rest_xs[particle_i] - center_x
            local qy = rest_ys[particle_i] - center_y
            sxx = sxx + mass * qx * qx
            sxy = sxy + mass * qx * qy
            syy = syy + mass * qy * qy
        end

        local rx, ry = -offset_x, -offset_y
        local determinant = sxx * syy - sxy * sxy
        if math.abs(determinant) < math.eps then
            for particle_i = 1, n_particles do
                local i = _particle_i_to_data_offset(particle_i)
                data[i + _anchor_weight_offset] = data[i + _mass_offset] / mass_sum
            end
        else
            local ux = (syy * rx - sxy * ry) / determinant
            local uy = (-sxy * rx + sxx * ry) / determinant
            for particle_i = 1, n_particles do
                local i = _particle_i_to_data_offset(particle_i)
                local mass = data[i + _mass_offset]
                local qx = rest_xs[particle_i] - center_x
                local qy = rest_ys[particle_i] - center_y
                data[i + _anchor_weight_offset] = mass / mass_sum + mass * (qx * ux + qy * uy)
            end
        end

        self._anchor_weight_offset_x = offset_x
        self._anchor_weight_offset_y = offset_y
    end

    return self
end

function rt.SoftBody:clear_anchor()
    meta.typecheck(self, rt.SoftBody)
    self._anchor_x, self._anchor_y = nil, nil
    self._anchor_offset_x, self._anchor_offset_y = 0, 0
    self._anchor_weight_offset_x, self._anchor_weight_offset_y = nil, nil
    self._anchor_particle_i = nil
    self._anchor_lambda_x, self._anchor_lambda_y = 0, 0
    return self
end

function rt.SoftBody:clear_forces()
    meta.typecheck(self, rt.SoftBody)

    -- Clear pending linear impulses and persistent linear forces.
    table.clear(self._linear_impulses)
    table.clear(self._linear_forces)

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

            draw_contour_vertices[contour_i + 0] = x
            draw_contour_vertices[contour_i + 1] = y
        end

        draw_contour_vertices[n_particles * 2 + 1] = draw_contour_vertices[1]
        draw_contour_vertices[n_particles * 2 + 2] = draw_contour_vertices[2]

        self._centroid_x = current_centroid_x
        self._centroid_y = current_centroid_y

        self._volume_lambda = 0
        self._angular_momentum_lambda = 0
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
    ConfigSchema:validate(config)
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

            draw_contour_vertices[contour_i + 0] = x
            draw_contour_vertices[contour_i + 1] = y
        end

        draw_contour_vertices[n_particles * 2 + 1] = draw_contour_vertices[1]
        draw_contour_vertices[n_particles * 2 + 2] = draw_contour_vertices[2]

        self._centroid_x = centroid_x
        self._centroid_y = centroid_y

        self._volume_lambda = 0
        self._angular_momentum_lambda = 0
        self._linear_velocity_lambda_x = 0
        self._linear_velocity_lambda_y = 0
        self._anchor_lambda_x = 0
        self._anchor_lambda_y = 0
        self._pinch_lambda_x = 0
        self._pinch_lambda_y = 0

        return self
    end
end

function rt.SoftBody:set_contraction(factor)
    meta.typecheck(self, rt.SoftBody, factor, mt.Number)
    self._contraction = math.max(factor, 0.001)
    return self
end

-- HairBody -------------------------------------------------------------------

rt.settings.hairbody = {
    max_n_steps = 8,

    default = {
        n_hairs = 16,

        damping = 1 - 1e-4,
        n_sub_steps = 2,
        n_constraint_iterations = 2,
        timestep = 1 / 120,

        static_friction = 0.7,
        kinetic_friction = 0.5,

        particle_radius = 1,
        particle_collision_compliance = 0,
        enforce_particle_collision = true,

        distance_compliance = 1e-6,
        enforce_distance = true,

        contour_collision_compliance = 0,
        enforce_contour_collision = true,

        bending_compliance = 1e-6,
        enforce_bending = true,

        anchor_compliance = 1e-8,
        enforce_anchor = true,

        pinch_compliance = 1e-8,
        enforce_pinch = false
    }
}

local HairBodyConfigSchema = meta.Schema({
    static_friction = NumberMaybe,
    kinetic_friction = NumberMaybe,

    particle_radius = NumberMaybe,
    particle_collision_compliance = NumberMaybe,
    enforce_particle_collision = BooleanMaybe,

    distance_compliance = NumberMaybe,
    enforce_distance = BooleanMaybe,

    contour_collision_compliance = NumberMaybe,
    enforce_contour_collision = BooleanMaybe,

    bending_compliance = NumberMaybe,
    enforce_bending = BooleanMaybe,

    anchor_compliance = NumberMaybe,
    enforce_anchor = BooleanMaybe,

    pinch_compliance = NumberMaybe,
    enforce_pinch = BooleanMaybe,

    damping = NumberMaybe,
    timestep = NumberMaybe,
    n_sub_steps = IntegerMaybe,
    n_constraint_iterations = IntegerMaybe
})

--- @class rt.HairBody
rt.HairBody = meta.class("HairBody")

local _golden_angle = math.pi * (3 - math.sqrt(5))

local _hair_i_to_particle_i = function(hair_i, vertex_i, n_vertices_per_line)
    return (hair_i - 1) * n_vertices_per_line + vertex_i
end

rt.HairBody._enforce_particle_collision = function(
    ax, ay, bx, by,
    inverse_mass_a, inverse_mass_b,
    radius_a, radius_b,
    alpha, lambda_before,
    particle_a, particle_b
)
    local dx, dy = bx - ax, by - ay
    local distance = math.magnitude(dx, dy)
    local normal_x, normal_y

    if distance > math.eps then
        normal_x, normal_y = dx / distance, dy / distance
    else
        local angle = ((particle_a * 17 + particle_b * 31) % 360) * math.pi / 180
        normal_x, normal_y = math.cos(angle), math.sin(angle)
        distance = 0
    end

    local constraint = distance - radius_a - radius_b
    if constraint >= 0 and lambda_before <= 0 then
        return 0, 0, 0, 0, lambda_before
    end

    local denominator = inverse_mass_a + inverse_mass_b + alpha
    if denominator < math.eps then
        return 0, 0, 0, 0, lambda_before
    end

    local delta_lambda = -(constraint + alpha * lambda_before) / denominator
    local lambda_new = math.max(lambda_before + delta_lambda, 0)
    delta_lambda = lambda_new - lambda_before

    return
    -inverse_mass_a * delta_lambda * normal_x,
    -inverse_mass_a * delta_lambda * normal_y,
    inverse_mass_b * delta_lambda * normal_x,
    inverse_mass_b * delta_lambda * normal_y,
    lambda_new
end

function rt.HairBody:instantiate(n_vertices_per_line, length, disk_radius)
    meta.typecheck(
        self, rt.HairBody,
        n_vertices_per_line, mt.Integer,
        length, mt.Number,
        disk_radius, mt.Number
    )

    local n_hairs = rt.settings.hairbody.default.n_hairs
    rt.assert(n_hairs >= 1, "In hairbody_init: settings.n_hairs must be at least 1")
    rt.assert(n_vertices_per_line >= 3, "In hairbody_init: each line needs at least 3 vertices")
    rt.assert(length > math.eps, "In hairbody_init: line length must be positive")
    rt.assert(disk_radius >= 0, "In hairbody_init: disk radius must be non-negative")

    self._n_hairs = n_hairs
    self._n_vertices_per_line = n_vertices_per_line
    self._n_particles = n_hairs * n_vertices_per_line
    self._length = length
    self._disk_radius = disk_radius
    self._shape_center_x, self._shape_center_y = 0, 0
    self._anchor_set = false
    self._override = {}

    local data = table.new(self._n_particles * _stride)
    local anchor_offsets_x, anchor_offsets_y = {}, {}
    local pinch_offsets_x, pinch_offsets_y = {}, {}
    local initial_local_xs, initial_local_ys = {}, {}
    local draw_lines = table.new(n_hairs)
    local rest_angle = _golden_angle

    for hair_i = 1, n_hairs do
        local angle = (hair_i - 1) * rest_angle
        local radial_fraction = math.sqrt((hair_i - 0.5) / n_hairs)
        local radial_distance = disk_radius * radial_fraction
        local offset_x = radial_distance * math.cos(angle)
        local offset_y = radial_distance * math.sin(angle)

        anchor_offsets_x[hair_i], anchor_offsets_y[hair_i] = offset_x, offset_y
        pinch_offsets_x[hair_i], pinch_offsets_y[hair_i] = offset_x, offset_y

        local line_vertices = table.new(2 * n_vertices_per_line)
        local direction_x, direction_y = math.cos(angle), math.sin(angle)

        for vertex_i = 1, n_vertices_per_line do
            local particle_i = _hair_i_to_particle_i(hair_i, vertex_i, n_vertices_per_line)
            local base = _particle_i_to_data_offset(particle_i)
            local t = (vertex_i - 1) / (n_vertices_per_line - 1)
            local px = offset_x + direction_x * length * t
            local py = offset_y + direction_y * length * t
            local mass = 1

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
            data[base + _radius_offset] = rt.settings.hairbody.default.particle_radius
            data[base + _mass_offset] = mass
            data[base + _inverse_mass_offset] = 1 / mass
            data[base + _anchor_weight_offset] = 0
            data[base + _rest_length_offset] = 0
            data[base + _bending_rest_offset] = 0
            data[base + _distance_lambda_offset] = 0
            data[base + _bending_lambda_offset] = 0

            initial_local_xs[particle_i] = px
            initial_local_ys[particle_i] = py
            table.insert(line_vertices, px)
            table.insert(line_vertices, py)
        end

        -- Open-chain rest lengths and bending offsets; there is no wraparound.
        for vertex_i = 1, n_vertices_per_line - 1 do
            local ai = _particle_i_to_data_offset(
                _hair_i_to_particle_i(hair_i, vertex_i, n_vertices_per_line)
            )
            local bi = _particle_i_to_data_offset(
                _hair_i_to_particle_i(hair_i, vertex_i + 1, n_vertices_per_line)
            )
            data[ai + _rest_length_offset] = math.distance(
                data[ai + _x_offset], data[ai + _y_offset],
                data[bi + _x_offset], data[bi + _y_offset]
            )
        end

        for vertex_i = 2, n_vertices_per_line - 1 do
            local ai = _particle_i_to_data_offset(
                _hair_i_to_particle_i(hair_i, vertex_i - 1, n_vertices_per_line)
            )
            local bi = _particle_i_to_data_offset(
                _hair_i_to_particle_i(hair_i, vertex_i, n_vertices_per_line)
            )
            local ci = _particle_i_to_data_offset(
                _hair_i_to_particle_i(hair_i, vertex_i + 1, n_vertices_per_line)
            )
            local ax, ay = data[ai + _x_offset], data[ai + _y_offset]
            local bx, by = data[bi + _x_offset], data[bi + _y_offset]
            local cx, cy = data[ci + _x_offset], data[ci + _y_offset]
            local chord_x, chord_y = cx - ax, cy - ay
            local chord_length = math.magnitude(chord_x, chord_y)

            if chord_length > math.eps then
                local nx, ny = -chord_y / chord_length, chord_x / chord_length
                local ex = 0.5 * (ax + cx) - bx
                local ey = 0.5 * (ay + cy) - by
                data[bi + _bending_rest_offset] = ex * nx + ey * ny
            end
        end

        draw_lines[hair_i] = rt.Polyline(line_vertices)
    end

    self._particles = data
    self._anchor_offsets_x, self._anchor_offsets_y = anchor_offsets_x, anchor_offsets_y
    self._pinch_offsets_x, self._pinch_offsets_y = pinch_offsets_x, pinch_offsets_y
    self._initial_local_xs, self._initial_local_ys = initial_local_xs, initial_local_ys
    self._draw_lines = draw_lines

    self._anchor_lambda_x = table.rep(0, n_hairs)
    self._anchor_lambda_y = table.rep(0, n_hairs)
    self._pinch_lambda_x = table.rep(0, n_hairs)
    self._pinch_lambda_y = table.rep(0, n_hairs)

    self._collision_contours = {}
    self._particle_collision_lambdas = {}
    self._linear_forces = {}
    self._linear_impulses = {}
    self._gravity_x, self._gravity_y = 0, 0

    self._centroid_x, self._centroid_y = 0, 0
    for particle_i = 1, self._n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        self._centroid_x = self._centroid_x + data[i + _x_offset]
        self._centroid_y = self._centroid_y + data[i + _y_offset]
    end
    self._centroid_x = self._centroid_x / self._n_particles
    self._centroid_y = self._centroid_y / self._n_particles

    self._elapsed = 0
    self._reverse_iteration = false
    self._is_initialized = true
    return self
end

function rt.HairBody:get_n_hairs()
    return self._n_hairs
end

function rt.HairBody:get_n_vertices_per_line()
    return self._n_vertices_per_line
end

function rt.HairBody:get_lines()
    local results = table.new(self._n_hairs)
    local data = self._particles
    for hair_i = 1, self._n_hairs do
        local vertices = table.new(2 * self._n_vertices_per_line)
        for vertex_i = 1, self._n_vertices_per_line do
            local particle_i = _hair_i_to_particle_i(hair_i, vertex_i, self._n_vertices_per_line)
            local i = _particle_i_to_data_offset(particle_i)
            table.insert(vertices, data[i + _x_offset])
            table.insert(vertices, data[i + _y_offset])
        end
        table.insert(results, rt.Polyline(vertices))
    end
    return results
end

function rt.HairBody:get_draw_lines()
    return self._draw_lines
end

function rt.HairBody:set_collision_contours(contours)
    local eps_squared = math.eps * math.eps
    local abs = math.abs
    table.clear(self._collision_contours)

    for contour_i = 1, #contours do
        local contour = contours[contour_i]
        local closed_contour = contour:close()
        local n_corners = closed_contour:get_n_vertices()
        rt.assert(n_corners >= 3, "In hairbody_set_collision_contours: need at least 3 vertices")

        local signed_area = closed_contour:get_signed_area()
        rt.assert(abs(signed_area) > math.eps,
            "In hairbody_set_collision_contours: contour must enclose an area")

        local orientation = math.sign(signed_area)
        local vertices = closed_contour:get_vertices()
        local edges = table.new(n_corners * _edge_stride)
        local n_edges = 0

        for vertex_i = 1, n_corners do
            local next_vertex_i = math.wrap(vertex_i + 1, n_corners)
            local ai = (vertex_i - 1) * 2 + 1
            local bi = (next_vertex_i - 1) * 2 + 1
            local x1, y1 = vertices[ai], vertices[ai + 1]
            local x2, y2 = vertices[bi], vertices[bi + 1]
            local dx, dy = x2 - x1, y2 - y1
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

        local entry = {
            contour = closed_contour,
            edges = edges,
            n_edges = n_edges,
            lambdas = table.rep(0, self._n_particles),
            normals_x = table.rep(0, self._n_particles),
            normals_y = table.rep(0, self._n_particles)
        }
        table.insert(self._collision_contours, entry)
    end

    return self
end

function rt.HairBody:get_collision_contours()
    local results = {}
    for entry in values(self._collision_contours) do
        table.insert(results, entry.contour)
    end
    return results
end

function rt.HairBody:set_gravity(dx, dy)
    meta.typecheck(self, rt.HairBody, dx, mt.Number, dy, mt.Number)
    self._gravity_x, self._gravity_y = dx, dy
    return self
end

local _hairbody_entry_hash = 0
local _hairbody_get_hash = function()
    local hash = _hairbody_entry_hash
    _hairbody_entry_hash = _hairbody_entry_hash + 1
    return hash
end

function rt.HairBody:add_linear_force(dx, dy)
    meta.typecheck(self, rt.HairBody, dx, mt.Number, dy, mt.Number)
    local magnitude = math.magnitude(dx, dy)
    if magnitude <= math.eps then return end
    dx, dy = math.normalize(dx, dy)
    local id = _hairbody_get_hash()
    self._linear_forces[id] = { magnitude = magnitude, dx = dx, dy = dy }
    return id
end

function rt.HairBody:remove_linear_force(hash)
    if hash == nil then return end
    meta.typecheck(self, rt.HairBody, hash, mt.Number)
    self._linear_forces[hash] = nil
    return self
end

function rt.HairBody:add_linear_impulse(dx, dy)
    meta.typecheck(self, rt.HairBody, dx, mt.Number, dy, mt.Number)
    local magnitude = math.magnitude(dx, dy)
    if magnitude > math.eps then
        dx, dy = math.normalize(dx, dy)
        local id = _hairbody_get_hash()
        self._linear_impulses[id] = { magnitude = magnitude, dx = dx, dy = dy }
        return id
    end
end

function rt.HairBody:remove_linear_impulse(hash)
    if hash == nil then return end
    meta.typecheck(self, rt.HairBody, hash, mt.Number)
    self._linear_impulses[hash] = nil
    return self
end

function rt.HairBody:get_centroid()
    meta.typecheck(self, rt.HairBody)
    return self._centroid_x, self._centroid_y
end

--- Set the position of the first line's pinched (root) particle. All other
--- roots retain their Fibonacci-spiral offsets from the resulting shape center.
function rt.HairBody:set_anchor(x, y, offset_x, offset_y)
    if offset_x == nil then offset_x = 0 end
    if offset_y == nil then offset_y = 0 end
    meta.typecheck(
        self, rt.HairBody,
        x, mt.Number, y, mt.Number,
        offset_x, mt.Number, offset_y, mt.Number
    )

    self._shape_center_x = x + offset_x - self._anchor_offsets_x[1]
    self._shape_center_y = y + offset_y - self._anchor_offsets_y[1]
    self._anchor_set = true

    for hair_i = 1, self._n_hairs do
        self._anchor_lambda_x[hair_i] = 0
        self._anchor_lambda_y[hair_i] = 0
    end
    return self
end

function rt.HairBody:clear_anchor()
    meta.typecheck(self, rt.HairBody)
    self._anchor_set = false
    for hair_i = 1, self._n_hairs do
        self._anchor_lambda_x[hair_i] = 0
        self._anchor_lambda_y[hair_i] = 0
    end
    return self
end

--- Set one line's pinch target in world coordinates. Its pinch node is always
--- vertex one; the target is stored relative to the overall shape center.
function rt.HairBody:set_pinch(hair_i, x, y)
    meta.typecheck(self, rt.HairBody, hair_i, mt.Integer, x, mt.Number, y, mt.Number)
    rt.assert(hair_i >= 1 and hair_i <= self._n_hairs,
        "In hairbody_set_pinch: line index out of range")
    self._pinch_offsets_x[hair_i] = x - self._shape_center_x
    self._pinch_offsets_y[hair_i] = y - self._shape_center_y
    self._pinch_lambda_x[hair_i] = 0
    self._pinch_lambda_y[hair_i] = 0
    return self
end

function rt.HairBody:clear_pinch(hair_i)
    meta.typecheck(self, rt.HairBody, hair_i, mt.Integer)
    rt.assert(hair_i >= 1 and hair_i <= self._n_hairs,
        "In hairbody_clear_pinch: line index out of range")
    self._pinch_offsets_x[hair_i] = self._anchor_offsets_x[hair_i]
    self._pinch_offsets_y[hair_i] = self._anchor_offsets_y[hair_i]
    self._pinch_lambda_x[hair_i] = 0
    self._pinch_lambda_y[hair_i] = 0
    return self
end

function rt.HairBody:clear_forces()
    meta.typecheck(self, rt.HairBody)
    table.clear(self._linear_impulses)
    table.clear(self._linear_forces)

    local data = self._particles
    for particle_i = 1, self._n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        data[i + _velocity_x_offset] = 0
        data[i + _velocity_y_offset] = 0
    end
    return self
end

function rt.HairBody:set_friction(static_friction, kinetic_friction)
    meta.typecheck(self, rt.HairBody, static_friction, mt.Number, kinetic_friction, mt.Number)
    rt.assert(static_friction >= 0 and kinetic_friction >= 0,
        "In hairbody_set_friction: coefficients must be non-negative")
    self._override.static_friction = static_friction
    self._override.kinetic_friction = math.min(kinetic_friction, static_friction)
    return self
end

function rt.HairBody:set_particle_radius(radius)
    meta.typecheck(self, rt.HairBody, radius, mt.Number)
    rt.assert(radius >= 0, "In hairbody_set_particle_radius: radius must be non-negative")
    self._override.particle_radius = radius
    return self
end

function rt.HairBody:get_mass()
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

function rt.HairBody:set_config(config)
    HairBodyConfigSchema:validate(config)
    self._override = config
    return self
end

function rt.HairBody:relax()
    meta.typecheck(self, rt.HairBody)
    local data = self._particles
    local center_x, center_y = self._shape_center_x, self._shape_center_y
    local draw_lines = self._draw_lines

    for hair_i = 1, self._n_hairs do
        local draw_vertices = draw_lines[hair_i]:get_vertices()
        for vertex_i = 1, self._n_vertices_per_line do
            local particle_i = _hair_i_to_particle_i(hair_i, vertex_i, self._n_vertices_per_line)
            local i = _particle_i_to_data_offset(particle_i)
            local x = center_x + self._initial_local_xs[particle_i]
            local y = center_y + self._initial_local_ys[particle_i]

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

            local vertex_offset = (vertex_i - 1) * 2 + 1
            draw_vertices[vertex_offset] = x
            draw_vertices[vertex_offset + 1] = y
        end
    end

    for hair_i = 1, self._n_hairs do
        self._anchor_lambda_x[hair_i] = 0
        self._anchor_lambda_y[hair_i] = 0
        self._pinch_lambda_x[hair_i] = 0
        self._pinch_lambda_y[hair_i] = 0
    end
    table.clear(self._particle_collision_lambdas)
    self._elapsed = 0

    self._centroid_x, self._centroid_y = 0, 0
    for particle_i = 1, self._n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        self._centroid_x = self._centroid_x + data[i + _x_offset]
        self._centroid_y = self._centroid_y + data[i + _y_offset]
    end
    self._centroid_x = self._centroid_x / self._n_particles
    self._centroid_y = self._centroid_y / self._n_particles
    return self
end

function rt.HairBody:update(delta)
    meta.typecheck(self, rt.HairBody, delta, mt.Number)
    if delta <= 0 then return self end

    local override = self._override or {}
    local default = rt.settings.hairbody.default
    local function get_setting(name)
        if override[name] ~= nil then
            return override[name]
        elseif default[name] ~= nil then
            return default[name]
        else
            rt.error("In rt.HairBody.update: unhandled settings key `", name, "`")
        end
    end

    local damping = get_setting("damping")
    local timestep = get_setting("timestep")
    local n_sub_steps = get_setting("n_sub_steps")
    local n_constraint_iterations = get_setting("n_constraint_iterations")
    local max_n_steps = rt.settings.hairbody.max_n_steps
    local sub_delta = timestep / n_sub_steps
    local sub_delta_sq = sub_delta * sub_delta

    local distance_alpha = get_setting("distance_compliance") / sub_delta_sq
    local bending_alpha = get_setting("bending_compliance") / sub_delta_sq
    local contour_alpha = get_setting("contour_collision_compliance") / sub_delta_sq
    local particle_collision_alpha = get_setting("particle_collision_compliance") / sub_delta_sq
    local pinch_alpha = get_setting("pinch_compliance") / sub_delta_sq
    local anchor_alpha = get_setting("anchor_compliance") / sub_delta_sq

    local particle_radius = get_setting("particle_radius")
    local static_friction = get_setting("static_friction")
    local kinetic_friction = get_setting("kinetic_friction")
    local enforce_friction = static_friction > 0 or kinetic_friction > 0

    local enforce_distance = get_setting("enforce_distance")
    local enforce_bending = get_setting("enforce_bending")
    local enforce_contour_collision = get_setting("enforce_contour_collision")
    local enforce_particle_collision = get_setting("enforce_particle_collision")
    local enforce_pinch = get_setting("enforce_pinch")
    local enforce_anchor = get_setting("enforce_anchor") and self._anchor_set

    local data = self._particles
    local n_particles = self._n_particles
    local n_hairs = self._n_hairs
    local n_vertices_per_line = self._n_vertices_per_line
    local collision_contours = self._collision_contours
    local n_collision_contours = #collision_contours
    local gravity_x, gravity_y = self._gravity_x, self._gravity_y

    local linear_force_x, linear_force_y = 0, 0
    for _, entry in pairs(self._linear_forces) do
        linear_force_x = linear_force_x + entry.magnitude * entry.dx
        linear_force_y = linear_force_y + entry.magnitude * entry.dy
    end

    local impulse_x, impulse_y = 0, 0
    for _, entry in pairs(self._linear_impulses) do
        impulse_x = impulse_x + entry.magnitude * entry.dx
        impulse_y = impulse_y + entry.magnitude * entry.dy
    end
    table.clear(self._linear_impulses)

    if impulse_x ~= 0 or impulse_y ~= 0 then
        local total_mass = self:get_mass()
        if total_mass > math.eps then
            local delta_velocity_x = impulse_x / total_mass
            local delta_velocity_y = impulse_y / total_mass
            for particle_i = 1, n_particles do
                local i = _particle_i_to_data_offset(particle_i)
                if data[i + _inverse_mass_offset] > 0 then
                    data[i + _velocity_x_offset] = data[i + _velocity_x_offset] + delta_velocity_x
                    data[i + _velocity_y_offset] = data[i + _velocity_y_offset] + delta_velocity_y
                end
            end
        end
    end

    self._elapsed = self._elapsed + delta
    local n_steps = 0
    local reverse_iteration = self._reverse_iteration or false

    while self._elapsed >= timestep and n_steps < max_n_steps do
        self._elapsed = self._elapsed - timestep
        n_steps = n_steps + 1

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            data[i + _snapshot_x_offset] = data[i + _x_offset]
            data[i + _snapshot_y_offset] = data[i + _y_offset]
        end

        for _ = 1, n_sub_steps do
            reverse_iteration = not reverse_iteration
            local first_vertex_i, last_vertex_i, vertex_step
            if reverse_iteration then
                first_vertex_i, last_vertex_i, vertex_step = n_vertices_per_line - 1, 1, -1
            else
                first_vertex_i, last_vertex_i, vertex_step = 1, n_vertices_per_line - 1, 1
            end

            table.clear(self._particle_collision_lambdas)
            for contour_i = 1, n_collision_contours do
                local lambdas = collision_contours[contour_i].lambdas
                for particle_i = 1, n_particles do
                    lambdas[particle_i] = 0
                end
            end

            local total_mass = 0
            for particle_i = 1, n_particles do
                local i = _particle_i_to_data_offset(particle_i)
                local inverse_mass = data[i + _inverse_mass_offset]
                local mass = data[i + _mass_offset]
                if inverse_mass > 0 and mass > 0 then
                    total_mass = total_mass + mass
                end
            end

            local force_acceleration_x, force_acceleration_y = 0, 0
            if total_mass > math.eps then
                force_acceleration_x = linear_force_x / total_mass
                force_acceleration_y = linear_force_y / total_mass
            end

            -- Integrate all open chains using the SoftBody particle layout.
            for particle_i = 1, n_particles do
                local i = _particle_i_to_data_offset(particle_i)
                local position_x = data[i + _x_offset]
                local position_y = data[i + _y_offset]
                local inverse_mass = data[i + _inverse_mass_offset]
                local acceleration_x = gravity_x + force_acceleration_x
                local acceleration_y = gravity_y + force_acceleration_y

                local velocity_x, velocity_y = 0, 0
                local new_position_x, new_position_y = position_x, position_y
                if inverse_mass > 0 then
                    velocity_x = data[i + _velocity_x_offset] * damping + acceleration_x * sub_delta
                    velocity_y = data[i + _velocity_y_offset] * damping + acceleration_y * sub_delta
                    new_position_x = position_x + velocity_x * sub_delta
                    new_position_y = position_y + velocity_y * sub_delta
                end

                data[i + _x_offset] = new_position_x
                data[i + _y_offset] = new_position_y
                data[i + _velocity_x_offset] = velocity_x
                data[i + _velocity_y_offset] = velocity_y
                data[i + _previous_x_offset] = position_x
                data[i + _previous_y_offset] = position_y
                data[i + _radius_offset] = particle_radius
                data[i + _distance_lambda_offset] = 0
                data[i + _bending_lambda_offset] = 0
            end

            for hair_i = 1, n_hairs do
                self._anchor_lambda_x[hair_i] = 0
                self._anchor_lambda_y[hair_i] = 0
                self._pinch_lambda_x[hair_i] = 0
                self._pinch_lambda_y[hair_i] = 0
            end

            for _ = 1, n_constraint_iterations do
                -- Distance constraints on consecutive vertices of each line.
                if enforce_distance then
                    for hair_i = 1, n_hairs do
                        for vertex_i = first_vertex_i, last_vertex_i, vertex_step do
                            local particle_a = _hair_i_to_particle_i(hair_i, vertex_i, n_vertices_per_line)
                            local particle_b = particle_a + 1
                            local ai = _particle_i_to_data_offset(particle_a)
                            local bi = _particle_i_to_data_offset(particle_b)
                            local ax, ay = data[ai + _x_offset], data[ai + _y_offset]
                            local bx, by = data[bi + _x_offset], data[bi + _y_offset]
                            local inverse_mass_a = data[ai + _inverse_mass_offset]
                            local inverse_mass_b = data[bi + _inverse_mass_offset]
                            local lambda_before = data[ai + _distance_lambda_offset]
                            local target_distance = data[ai + _rest_length_offset]

                            local correction_ax, correction_ay, lambda_new = rt.SoftBody._enforce_exact_distance(
                                ax, ay, bx, by,
                                inverse_mass_a, inverse_mass_b,
                                target_distance, distance_alpha, lambda_before
                            )
                            local correction_bx, correction_by = rt.SoftBody._enforce_exact_distance(
                                bx, by, ax, ay,
                                inverse_mass_b, inverse_mass_a,
                                target_distance, distance_alpha, lambda_before
                            )

                            data[ai + _x_offset] = ax + correction_ax
                            data[ai + _y_offset] = ay + correction_ay
                            data[bi + _x_offset] = bx + correction_bx
                            data[bi + _y_offset] = by + correction_by
                            data[ai + _distance_lambda_offset] = lambda_new
                        end
                    end
                end

                -- Three-particle bending constraints; line endpoints are open.
                if enforce_bending then
                    local first_middle_i, last_middle_i, middle_step
                    if reverse_iteration then
                        first_middle_i, last_middle_i, middle_step = n_vertices_per_line - 1, 2, -1
                    else
                        first_middle_i, last_middle_i, middle_step = 2, n_vertices_per_line - 1, 1
                    end

                    for hair_i = 1, n_hairs do
                        for vertex_i = first_middle_i, last_middle_i, middle_step do
                            local particle_b = _hair_i_to_particle_i(hair_i, vertex_i, n_vertices_per_line)
                            local particle_a, particle_c = particle_b - 1, particle_b + 1
                            local ai = _particle_i_to_data_offset(particle_a)
                            local bi = _particle_i_to_data_offset(particle_b)
                            local ci = _particle_i_to_data_offset(particle_c)

                            local new_ax, new_ay, new_bx, new_by, new_cx, new_cy, new_lambda =
                            rt.SoftBody._enforce_bending(
                                data[ai + _x_offset], data[ai + _y_offset],
                                data[bi + _x_offset], data[bi + _y_offset],
                                data[ci + _x_offset], data[ci + _y_offset],
                                data[ai + _inverse_mass_offset],
                                data[bi + _inverse_mass_offset],
                                data[ci + _inverse_mass_offset],
                                data[bi + _bending_rest_offset],
                                bending_alpha,
                                data[bi + _bending_lambda_offset]
                            )

                            data[ai + _x_offset], data[ai + _y_offset] = new_ax, new_ay
                            data[bi + _x_offset], data[bi + _y_offset] = new_bx, new_by
                            data[ci + _x_offset], data[ci + _y_offset] = new_cx, new_cy
                            data[bi + _bending_lambda_offset] = new_lambda
                        end
                    end
                end

                -- Each chain's first vertex is its pinch node and anchor point.
                if enforce_pinch then
                    for hair_i = 1, n_hairs do
                        local particle_i = _hair_i_to_particle_i(hair_i, 1, n_vertices_per_line)
                        local i = _particle_i_to_data_offset(particle_i)
                        local target_x = self._shape_center_x + self._pinch_offsets_x[hair_i]
                        local target_y = self._shape_center_y + self._pinch_offsets_y[hair_i]
                        local correction_x, correction_y, lambda_x_new, lambda_y_new =
                        rt.SoftBody._enforce_pinch(
                            data[i + _x_offset], data[i + _y_offset],
                            data[i + _inverse_mass_offset],
                            target_x, target_y,
                            pinch_alpha,
                            self._pinch_lambda_x[hair_i],
                            self._pinch_lambda_y[hair_i]
                        )
                        data[i + _x_offset] = data[i + _x_offset] + correction_x
                        data[i + _y_offset] = data[i + _y_offset] + correction_y
                        self._pinch_lambda_x[hair_i] = lambda_x_new
                        self._pinch_lambda_y[hair_i] = lambda_y_new
                    end
                end

                if enforce_anchor then
                    for hair_i = 1, n_hairs do
                        local particle_i = _hair_i_to_particle_i(hair_i, 1, n_vertices_per_line)
                        local i = _particle_i_to_data_offset(particle_i)
                        local inverse_mass = data[i + _inverse_mass_offset]
                        local target_x = self._shape_center_x + self._anchor_offsets_x[hair_i]
                        local target_y = self._shape_center_y + self._anchor_offsets_y[hair_i]
                        local denominator = inverse_mass + anchor_alpha

                        if denominator >= math.eps then
                            local constraint_x = data[i + _x_offset] - target_x
                            local constraint_y = data[i + _y_offset] - target_y
                            local delta_lambda_x = -(constraint_x + anchor_alpha * self._anchor_lambda_x[hair_i])
                                / denominator
                            local delta_lambda_y = -(constraint_y + anchor_alpha * self._anchor_lambda_y[hair_i])
                                / denominator
                            local correction_x, correction_y = rt.SoftBody._enforce_anchor(
                                inverse_mass, 1, delta_lambda_x, delta_lambda_y
                            )
                            data[i + _x_offset] = data[i + _x_offset] + correction_x
                            data[i + _y_offset] = data[i + _y_offset] + correction_y
                            self._anchor_lambda_x[hair_i] = self._anchor_lambda_x[hair_i] + delta_lambda_x
                            self._anchor_lambda_y[hair_i] = self._anchor_lambda_y[hair_i] + delta_lambda_y
                        end
                    end
                end

                -- Environment contour collision, shared with SoftBody.
                if enforce_contour_collision then
                    for contour_i = 1, n_collision_contours do
                        local entry = collision_contours[contour_i]
                        local edges = entry.edges
                        local n_edges = entry.n_edges
                        local lambdas = entry.lambdas
                        local normals_x, normals_y = entry.normals_x, entry.normals_y
                        local keep_outside = entry.contour:get_winding()

                        for particle_i = 1, n_particles do
                            local i = _particle_i_to_data_offset(particle_i)
                            local correction_x, correction_y, lambda_new, normal_x, normal_y =
                            rt.SoftBody._enforce_polygon_collision(
                                data[i + _x_offset], data[i + _y_offset],
                                data[i + _inverse_mass_offset], data[i + _radius_offset],
                                edges, n_edges, contour_alpha, lambdas[particle_i], keep_outside
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

                -- Circle-circle minimum distance between particles from distinct lines.
                if enforce_particle_collision then
                    for hair_a = 1, n_hairs - 1 do
                        for hair_b = hair_a + 1, n_hairs do
                            for vertex_a = 1, n_vertices_per_line do
                                local particle_a = _hair_i_to_particle_i(hair_a, vertex_a, n_vertices_per_line)
                                local ai = _particle_i_to_data_offset(particle_a)
                                for vertex_b = 1, n_vertices_per_line do
                                    local particle_b = _hair_i_to_particle_i(hair_b, vertex_b, n_vertices_per_line)
                                    local bi = _particle_i_to_data_offset(particle_b)
                                    local lambda_key = (particle_a - 1) * n_particles + particle_b
                                    local lambda_before = self._particle_collision_lambdas[lambda_key] or 0
                                    local correction_ax, correction_ay, correction_bx, correction_by, lambda_new =
                                    rt.HairBody._enforce_particle_collision(
                                        data[ai + _x_offset], data[ai + _y_offset],
                                        data[bi + _x_offset], data[bi + _y_offset],
                                        data[ai + _inverse_mass_offset], data[bi + _inverse_mass_offset],
                                        data[ai + _radius_offset], data[bi + _radius_offset],
                                        particle_collision_alpha, lambda_before,
                                        particle_a, particle_b
                                    )
                                    data[ai + _x_offset] = data[ai + _x_offset] + correction_ax
                                    data[ai + _y_offset] = data[ai + _y_offset] + correction_ay
                                    data[bi + _x_offset] = data[bi + _x_offset] + correction_bx
                                    data[bi + _y_offset] = data[bi + _y_offset] + correction_by
                                    self._particle_collision_lambdas[lambda_key] = lambda_new
                                end
                            end
                        end
                    end
                end
            end -- constraint iterations

            if enforce_contour_collision and enforce_friction then
                for contour_i = 1, n_collision_contours do
                    local entry = collision_contours[contour_i]
                    local lambdas = entry.lambdas
                    local normals_x, normals_y = entry.normals_x, entry.normals_y
                    for particle_i = 1, n_particles do
                        local i = _particle_i_to_data_offset(particle_i)
                        local correction_x, correction_y = rt.SoftBody._enforce_friction(
                            data[i + _x_offset], data[i + _y_offset],
                            data[i + _previous_x_offset], data[i + _previous_y_offset],
                            normals_x[particle_i], normals_y[particle_i],
                            data[i + _inverse_mass_offset], lambdas[particle_i],
                            static_friction, kinetic_friction
                        )
                        data[i + _x_offset] = data[i + _x_offset] + correction_x
                        data[i + _y_offset] = data[i + _y_offset] + correction_y
                    end
                end
            end

            for particle_i = 1, n_particles do
                local i = _particle_i_to_data_offset(particle_i)
                data[i + _velocity_x_offset] =
                (data[i + _x_offset] - data[i + _previous_x_offset]) / sub_delta
                data[i + _velocity_y_offset] =
                (data[i + _y_offset] - data[i + _previous_y_offset]) / sub_delta
            end
        end -- substeps
    end -- timestep

    self._reverse_iteration = reverse_iteration
    self._elapsed = math.min(self._elapsed, timestep)

    -- Interpolate the open-chain draw polylines and update the particle centroid.
    local frame_interpolation_alpha = self._elapsed / timestep
    local centroid_x, centroid_y = 0, 0
    for hair_i = 1, n_hairs do
        local draw_vertices = self._draw_lines[hair_i]:get_vertices()
        for vertex_i = 1, n_vertices_per_line do
            local particle_i = _hair_i_to_particle_i(hair_i, vertex_i, n_vertices_per_line)
            local i = _particle_i_to_data_offset(particle_i)
            local previous_x = data[i + _snapshot_x_offset]
            local previous_y = data[i + _snapshot_y_offset]
            local current_x = data[i + _x_offset]
            local current_y = data[i + _y_offset]
            local x = previous_x + (current_x - previous_x) * frame_interpolation_alpha
            local y = previous_y + (current_y - previous_y) * frame_interpolation_alpha

            data[i + _draw_x_offset] = x
            data[i + _draw_y_offset] = y
            local vertex_offset = (vertex_i - 1) * 2 + 1
            draw_vertices[vertex_offset] = x
            draw_vertices[vertex_offset + 1] = y
            centroid_x = centroid_x + x
            centroid_y = centroid_y + y
        end
    end

    self._centroid_x = centroid_x / n_particles
    self._centroid_y = centroid_y / n_particles
    return self
end
