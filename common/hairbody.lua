require "common.interpolation_functions"

rt.settings.hairbody = {
    max_n_steps = 8,

    default = {
        damping = 0.95,
        n_sub_steps = 4,
        n_constraint_iterations = 4,
        timestep = 1 / 120,

        static_friction = 1.2,
        kinetic_friction = 0.9,

        distance_compliance = 0,
        enforce_distance = true,

        contour_collision_compliance = 1e-7,
        enforce_contour_collision = true,

        bending_compliance = 1e-6,
        enforce_bending = true,

        angular_momentum_compliance = 1e-7,
        enforce_angular_momentum = true,

        anchor_compliance = 2 * math.eps,
        enforce_anchor = true,

        density = 1
    }
}

require "common.softbody"

--- @class rt.HairBody
rt.HairBody = meta.class("HairBody")

local NumberMaybe = mt.Optional(mt.Number)
local BooleanMaybe = mt.Optional(mt.Boolean)
local IntegerMaybe = mt.Optional(mt.Integer)
local HairBodyConfigSchema = meta.Schema({
    static_friction = NumberMaybe,
    kinetic_friction = NumberMaybe,

    distance_compliance = NumberMaybe,
    enforce_distance = BooleanMaybe,

    contour_collision_compliance = NumberMaybe,
    enforce_contour_collision = BooleanMaybe,

    bending_compliance = NumberMaybe,
    enforce_bending = BooleanMaybe,

    angular_momentum_compliance = NumberMaybe,
    enforce_angular_momentum = BooleanMaybe,

    anchor_compliance = NumberMaybe,
    enforce_anchor = BooleanMaybe,

    damping = NumberMaybe,
    timestep = NumberMaybe,
    n_sub_steps = IntegerMaybe,
    n_constraint_iterations = IntegerMaybe,

    density = NumberMaybe
})

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
local _rest_length_offset = 13
local _damping_weight_offset = 14
local _distance_lambda_offset = 15
local _bending_lambda_offset = 16

local _stride = _bending_lambda_offset + 1

local _particle_i_to_data_offset = function(particle_i)
    return (particle_i - 1) * _stride + 1
end

--- @brief
function rt.HairBody:instantiate(x, y, base_radius, n_circles, circle_easing, rest_segment_length)
    if circle_easing == nil then
        circle_easing = function(t)
            return 1 - t
        end
    end

    meta.typecheck(
        self, rt.HairBody,
        x, mt.Number,
        y, mt.Number,
        base_radius, mt.Number,
        n_circles, mt.Integer,
        circle_easing, mt.Function,
        rest_segment_length, mt.Optional(mt.Number)
    )

    rt.assert(base_radius > 0, "In hairbody_init: base radius must be positive")
    rt.assert(n_circles >= 2, "In hairbody_init: line needs at least 2 vertices")
    rt.assert(rest_segment_length == nil or rest_segment_length >= 0,
        "In hairbody_init: rest segment length must be non-negative")

    self._n_particles = n_circles
    self._override = {}
    self._rest_x, self._rest_y = x, y
    self._rest_segment_length = rest_segment_length
    self._contraction = 1
    self._use_collision = true

    local damping_easing = function(t) return 1 end
    local density_easing = function(t) return 1 end

    local eps = math.eps
    local max = math.max

    local data = table.new(self._n_particles * _stride)
    local line_vertices = table.new(2 * n_circles)
    local radii = table.new(n_circles)

    for circle_i = 1, n_circles do
        local base = _particle_i_to_data_offset(circle_i)
        local px, py = x, y -- init rest as all overlapping
        local radius = base_radius * circle_easing((circle_i - 1) / n_circles)
        rt.assert(radius >= 0, "In hairbody_init: circle easing must produce non-negative radii")

        local t = (circle_i - 1) / (n_circles - 1)

        local mass = density_easing(t) * math.pi * radius^2
        local inverse_mass = 1 / mass

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
        data[base + _radius_offset] = radius
        data[base + _mass_offset] = mass
        data[base + _inverse_mass_offset] = inverse_mass
        data[base + _rest_length_offset] = 0
        data[base + _damping_weight_offset] = damping_easing(t)
        data[base + _distance_lambda_offset] = 0
        data[base + _bending_lambda_offset] = 0
        radii[circle_i] = radius

        line_vertices[2 * circle_i - 1] = px
        line_vertices[2 * circle_i] = py
    end

    for particle_i = 1, n_circles - 1 do
        local i = _particle_i_to_data_offset(particle_i)
        local rest_length = rest_segment_length
        if rest_length == nil then
            rest_length = 0.25 * (radii[particle_i] + radii[particle_i + 1])
        end
        data[i + _rest_length_offset] = rest_length
    end

    self._particles = data
    self._draw_line = rt.Polyline(line_vertices)
    self._draw_contour_particles = table.new(256 * 3)

    self._gravity_x, self._gravity_y = 0, 0

    self._anchor_x = x
    self._anchor_y = y
    self._anchor_lambda_x = 0
    self._anchor_lambda_y = 0
    self._angular_momentum_lambda = 0

    self._collision_contours = {}

    self._elapsed = 0
    self._reverse_iteration = false
    self._is_initialized = true
    return self
end

function rt.HairBody:set_collision_contours(contours)
    return rt.SoftBody.set_collision_contours(self, contours)
end

function rt.HairBody:get_collision_contours()
    return rt.SoftBody.get_collision_contours(self)
end

function rt.HairBody:set_gravity(dx, dy)
    meta.typecheck(self, rt.HairBody, dx, mt.Number, dy, mt.Number)
    self._gravity_x, self._gravity_y = dx, dy
    return self
end

--- @brief set anchor of first particle
function rt.HairBody:set_anchor(x, y)
    meta.typecheck(
        self, rt.HairBody,
        x, mt.Optional(mt.Number),
        y, mt.Optional(mt.Number)
    )
    rt.assert((x == nil) == (y == nil),
        "In hairbody_set_anchor: both coordinates must be set or cleared together")

    self._anchor_x = x
    self._anchor_y = y
    self._anchor_lambda_x = 0
    self._anchor_lambda_y = 0
    return self
end

function rt.HairBody:set_contraction(factor)
    meta.typecheck(self, rt.HairBody, factor, mt.Number)
    self._contraction = math.max(factor, 0.001)

    local data = self._particles
    for particle_i = 1, self._n_particles - 1 do
        local i = _particle_i_to_data_offset(particle_i)
        data[i + _distance_lambda_offset] = 0
    end
    return self
end

function rt.HairBody:set_rest_segment_length(length)
    meta.typecheck(self, rt.HairBody, length, mt.Number)
    rt.assert(length >= 0, "In hairbody_set_rest_segment_length: length must be non-negative")

    local data = self._particles
    for particle_i = 1, self._n_particles - 1 do
        local i = _particle_i_to_data_offset(particle_i)
        data[i + _rest_length_offset] = length
        data[i + _distance_lambda_offset] = 0
    end
    self._rest_segment_length = length
    return self
end

function rt.HairBody:get_line()
    meta.typecheck(self, rt.HairBody)
    local data = self._particles
    local vertices = table.new(2 * self._n_particles)
    for particle_i = 1, self._n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        table.insert(vertices, data[i + _x_offset])
        table.insert(vertices, data[i + _y_offset])
    end
    return rt.Polyline(vertices)
end

function rt.HairBody:get_draw_line()
    meta.typecheck(self, rt.HairBody)
    return self._draw_line
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

    local density = config.density or rt.settings.hairbody.default.density
    rt.assert(density > 0, "In hairbody_set_config: density must be positive")

    local data = self._particles
    local max = math.max
    local eps = math.eps
    for particle_i = 1, self._n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        local radius = data[i + _radius_offset]
        local mass = max(density * math.pi * radius * radius, eps)
        data[i + _mass_offset] = mass
        data[i + _inverse_mass_offset] = 1 / mass
    end

    return self
end

function rt.HairBody:relax()
    meta.typecheck(self, rt.HairBody)
    local data = self._particles
    local x, y = self._anchor_x or self._rest_x, self._anchor_y or self._rest_y
    local draw_vertices = self._draw_line:get_vertices()

    for particle_i = 1, self._n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        local vertex_i = 2 * particle_i - 1
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
        draw_vertices[vertex_i] = x
        draw_vertices[vertex_i + 1] = y
    end

    self._elapsed = 0
    self._anchor_lambda_x, self._anchor_lambda_y = 0, 0
    self._angular_momentum_lambda = 0
    for contour_i = 1, #self._collision_contours do
        local lambdas = self._collision_contours[contour_i].lambdas
        for particle_i = 1, self._n_particles do
            lambdas[particle_i] = 0
        end
    end
    return self
end

-- XPBD inequality: max_length - |a-b| >= 0. Its multiplier is kept
-- non-negative, so a segment is pulled together only while over-stretched.
do
    local magnitude = math.magnitude
    local max = math.max
    local eps = math.eps

    rt.HairBody._enforce_max_distance = function(
        ax, ay, bx, by,
        inverse_mass_a, inverse_mass_b,
        max_length, alpha, lambda_before
    )
        local dx, dy = ax - bx, ay - by
        local length = magnitude(dx, dy)
        if length < eps then
            return 0, 0, 0, 0, 0
        end

        local denominator = inverse_mass_a + inverse_mass_b + alpha
        if denominator < eps then
            return 0, 0, 0, 0, lambda_before
        end

        local constraint = max_length - length
        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = max(lambda_before + delta_lambda, 0)
        delta_lambda = lambda_new - lambda_before

        local scale = delta_lambda / length
        return
        -inverse_mass_a * scale * dx,
        -inverse_mass_a * scale * dy,
        inverse_mass_b * scale * dx,
        inverse_mass_b * scale * dy,
        lambda_new
    end
end

do -- hairbody_update
    local min = math.min
    local pow = math.pow

    local _enforce_max_distance = rt.HairBody._enforce_max_distance
    local _enforce_bending = rt.SoftBody._enforce_bending
    local _enforce_pinch = rt.SoftBody._enforce_pinch
    local _enforce_angular_momentum = rt.SoftBody._enforce_angular_momentum
    local _enforce_polygon_collision = rt.SoftBody._enforce_polygon_collision
    local _enforce_friction = rt.SoftBody._enforce_friction

    function rt.HairBody:update(delta)
        meta.typecheck(self, rt.HairBody, delta, mt.Number)
        if delta <= 0 then return self end

        local override = self._override or {}
        local default = rt.settings.hairbody.default

        local get_setting = function(name)
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

        local contraction = self._contraction
        local n_sub_steps = get_setting("n_sub_steps")
        local n_constraint_iterations = get_setting("n_constraint_iterations")
        local max_n_steps = rt.settings.hairbody.max_n_steps
        rt.assert(timestep > 0 and n_sub_steps > 0,
            "In rt.HairBody.update: timestep and substep count must be positive")

        local sub_delta = timestep / n_sub_steps
        local sub_delta_sq = sub_delta * sub_delta

        local distance_alpha = get_setting("distance_compliance") / sub_delta_sq
        local contour_alpha = get_setting("contour_collision_compliance") / sub_delta_sq
        local bending_alpha = get_setting("bending_compliance") / sub_delta_sq
        local angular_alpha = get_setting("angular_momentum_compliance") / sub_delta_sq
        local anchor_alpha = get_setting("anchor_compliance") / sub_delta_sq

        local static_friction = get_setting("static_friction")
        local kinetic_friction = get_setting("kinetic_friction")
        local enforce_friction = static_friction > 0 or kinetic_friction > 0

        local enforce_distance = get_setting("enforce_distance")
        local enforce_contour_collision = get_setting("enforce_contour_collision")
        local enforce_bending = get_setting("enforce_bending")
        local enforce_angular_momentum = get_setting("enforce_angular_momentum")
        local enforce_anchor = get_setting("enforce_anchor")

        enforce_contour_collision = enforce_contour_collision and (self._use_collision ~= false)


        local density = get_setting("density")
        local inverse_density = 1 / density

        local data = self._particles
        local n_particles = self._n_particles
        local collision_contours = self._collision_contours
        local n_collision_contours = #collision_contours

        local anchor_x, anchor_y = self._anchor_x, self._anchor_y
        enforce_anchor = enforce_anchor and anchor_x ~= nil and anchor_y ~= nil

        -- compensate gravity for damping, since damping should mostly calm the simulation, not reduce gravity
        local gravity_x, gravity_y = self._gravity_x / damping, self._gravity_y / damping

        self._elapsed = self._elapsed + delta

        -- broadphase once per frame
        if enforce_contour_collision and self._elapsed >= timestep then
            for contour_i = 1, n_collision_contours do
                local entry = collision_contours[contour_i]
                local candidates = entry.candidate_particles
                table.clear(candidates)

                local aabb_min_x = entry.aabb_min_x
                local aabb_min_y = entry.aabb_min_y
                local aabb_max_x = entry.aabb_max_x
                local aabb_max_y = entry.aabb_max_y
                local n_candidates = 0

                for particle_i = 1, n_particles do
                    local i = _particle_i_to_data_offset(particle_i)
                    if data[i + _inverse_mass_offset] > 0 then
                        local x = data[i + _x_offset]
                        local y = data[i + _y_offset]
                        local radius = data[i + _radius_offset]

                        if x + radius >= aabb_min_x and x - radius <= aabb_max_x
                            and y + radius >= aabb_min_y and y - radius <= aabb_max_y
                        then
                            n_candidates = n_candidates + 1
                            candidates[n_candidates] = particle_i
                        end
                    end
                end

                entry.n_candidate_particles = n_candidates
            end
        end

        local n_steps = 0
        local reverse_iteration = self._reverse_iteration or false

        while self._elapsed >= timestep and n_steps < max_n_steps do
            self._elapsed = self._elapsed - timestep
            n_steps = n_steps + 1

            -- Snapshot for frame interpolation.
            for particle_i = 1, n_particles do
                local i = _particle_i_to_data_offset(particle_i)
                data[i + _snapshot_x_offset] = data[i + _x_offset]
                data[i + _snapshot_y_offset] = data[i + _y_offset]
            end

            for _ = 1, n_sub_steps do
                -- Alternate the Gauss-Seidel sweep direction every substep.
                reverse_iteration = not reverse_iteration
                for contour_i = 1, n_collision_contours do
                    local lambdas = collision_contours[contour_i].lambdas
                    for particle_i = 1, n_particles do
                        lambdas[particle_i] = 0
                    end
                end

                -- Integrate.
                for particle_i = 1, n_particles do
                    local i = _particle_i_to_data_offset(particle_i)
                    local position_x = data[i + _x_offset]
                    local position_y = data[i + _y_offset]
                    local inverse_mass = data[i + _inverse_mass_offset] * inverse_density

                    local velocity_x, velocity_y = 0, 0
                    local new_position_x, new_position_y = position_x, position_y
                    if inverse_mass > 0 then
                        local particle_damping = pow(damping, data[i + _damping_weight_offset])
                        velocity_x = data[i + _velocity_x_offset] * particle_damping + gravity_x * sub_delta
                        velocity_y = data[i + _velocity_y_offset] * particle_damping + gravity_y * sub_delta
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

                self._anchor_lambda_x = 0
                self._anchor_lambda_y = 0
                self._angular_momentum_lambda = 0

                -- A hard anchor is a kinematic boundary for the structural
                -- solve. The contact pass below deliberately uses the real
                -- inverse mass, so particle 1 can still resolve collisions.
                local hard_anchor = enforce_anchor and anchor_alpha == 0

                -- Chain constraints: only n-1 segment limits and n-2 bends.
                -- Reapply the anchor before each Gauss-Seidel pass so every
                -- pass solves the chain relative to the anchored endpoint.
                for _ = 1, n_constraint_iterations do
                    if enforce_anchor then
                        local i = _particle_i_to_data_offset(1)
                        if anchor_alpha == 0 then
                            data[i + _x_offset] = anchor_x
                            data[i + _y_offset] = anchor_y
                            self._anchor_lambda_x, self._anchor_lambda_y = 0, 0
                        else
                            local correction_x, correction_y, lambda_x_new, lambda_y_new = _enforce_pinch(
                                data[i + _x_offset], data[i + _y_offset],
                                data[i + _inverse_mass_offset] * inverse_density,
                                anchor_x, anchor_y,
                                anchor_alpha,
                                self._anchor_lambda_x, self._anchor_lambda_y
                            )

                            data[i + _x_offset] = data[i + _x_offset] + correction_x
                            data[i + _y_offset] = data[i + _y_offset] + correction_y
                            self._anchor_lambda_x, self._anchor_lambda_y = lambda_x_new, lambda_y_new
                        end
                    end

                    if enforce_distance then
                        local first_segment_i = reverse_iteration and n_particles - 1 or 1
                        local last_segment_i = reverse_iteration and 1 or n_particles - 1
                        local segment_step = reverse_iteration and -1 or 1

                        for particle_i = first_segment_i, last_segment_i, segment_step do
                            local ai = _particle_i_to_data_offset(particle_i)
                            local bi = _particle_i_to_data_offset(particle_i + 1)
                            local ax, ay = data[ai + _x_offset], data[ai + _y_offset]
                            local bx, by = data[bi + _x_offset], data[bi + _y_offset]

                            local inverse_mass_a = data[ai + _inverse_mass_offset] * inverse_density
                            local inverse_mass_b = data[bi + _inverse_mass_offset] * inverse_density
                            if hard_anchor and particle_i == 1 then inverse_mass_a = 0 end

                            local correction_ax, correction_ay, correction_bx, correction_by, lambda_new = _enforce_max_distance(
                                ax, ay, bx, by,
                                inverse_mass_a, inverse_mass_b,
                                data[ai + _rest_length_offset] * contraction,
                                distance_alpha,
                                data[ai + _distance_lambda_offset]
                            )

                            data[ai + _x_offset] = ax + correction_ax
                            data[ai + _y_offset] = ay + correction_ay
                            data[bi + _x_offset] = bx + correction_bx
                            data[bi + _y_offset] = by + correction_by
                            data[ai + _distance_lambda_offset] = lambda_new
                        end
                    end

                    if enforce_bending then
                        local first_bend_i = reverse_iteration and n_particles - 2 or 1
                        local last_bend_i = reverse_iteration and 1 or n_particles - 2
                        local bend_step = reverse_iteration and -1 or 1

                        for particle_i = first_bend_i, last_bend_i, bend_step do
                            local ai = _particle_i_to_data_offset(particle_i)
                            local bi = _particle_i_to_data_offset(particle_i + 1)
                            local ci = _particle_i_to_data_offset(particle_i + 2)

                            local inverse_mass_a = data[ai + _inverse_mass_offset] * inverse_density
                            if hard_anchor and particle_i == 1 then
                                inverse_mass_a = 0
                            end

                            local new_ax, new_ay, new_bx, new_by, new_cx, new_cy, lambda_new = _enforce_bending(
                                data[ai + _x_offset], data[ai + _y_offset],
                                data[bi + _x_offset], data[bi + _y_offset],
                                data[ci + _x_offset], data[ci + _y_offset],
                                inverse_mass_a,
                                data[bi + _inverse_mass_offset] * inverse_density,
                                data[ci + _inverse_mass_offset] * inverse_density,
                                0,
                                bending_alpha,
                                data[ai + _bending_lambda_offset]
                            )

                            data[ai + _x_offset], data[ai + _y_offset] = new_ax, new_ay
                            data[bi + _x_offset], data[bi + _y_offset] = new_bx, new_by
                            data[ci + _x_offset], data[ci + _y_offset] = new_cx, new_cy
                            data[ai + _bending_lambda_offset] = lambda_new
                        end
                    end

                    if enforce_angular_momentum then
                        -- Falloff along the chain: particle 1 gets full weight, the last particle
                        -- gets (1 - angular_falloff). angular_falloff in [0, 1]; 0 = old behavior.
                        -- Using t = (particle_i - 1) / (n_particles - 1) so the profile is
                        -- independent of chain length.
                        local falloff_denominator = math.max(n_particles - 1, 1)
                        local angular_falloff = self._angular_falloff or 0.9 -- tune / expose as parameter

                        local center_x, center_y = anchor_x, anchor_y
                        if not enforce_anchor then
                            local mass_sum = 0
                            center_x, center_y = 0, 0
                            for particle_i = 1, n_particles do
                                local i = _particle_i_to_data_offset(particle_i)
                                local inverse_mass = data[i + _inverse_mass_offset] * inverse_density
                                local mass = data[i + _mass_offset] * density
                                if inverse_mass > 0 and mass > 0 then
                                    mass_sum = mass_sum + mass
                                    center_x = center_x + mass * data[i + _previous_x_offset]
                                    center_y = center_y + mass * data[i + _previous_y_offset]
                                end
                            end
                            if mass_sum > 0 then
                                center_x, center_y = center_x / mass_sum, center_y / mass_sum
                            end
                        end

                        local angular_momentum = 0
                        local weight_sum = 0
                        for particle_i = 1, n_particles do
                            local i = _particle_i_to_data_offset(particle_i)
                            local inverse_mass = data[i + _inverse_mass_offset] * inverse_density
                            local mass = data[i + _mass_offset] * density
                            if inverse_mass > 0 and mass > 0
                                and not (hard_anchor and particle_i == 1) then
                                local rx = data[i + _previous_x_offset] - center_x
                                local ry = data[i + _previous_y_offset] - center_y
                                local dx = data[i + _x_offset] - data[i + _previous_x_offset]
                                local dy = data[i + _y_offset] - data[i + _previous_y_offset]
                                angular_momentum = angular_momentum + mass * (rx * dy - ry * dx)

                                -- index-dependent attenuation of this particle's response
                                local falloff = 1 - angular_falloff * (particle_i - 1) / falloff_denominator

                                local gx = -mass * ry
                                local gy = mass * rx
                                weight_sum = weight_sum + (inverse_mass * falloff) * (gx * gx + gy * gy)
                            end
                        end

                        local denominator = weight_sum + angular_alpha
                        if denominator > 0 then
                            local delta_lambda = -(angular_momentum + angular_alpha * self._angular_momentum_lambda)
                                / denominator
                            local lambda_new = self._angular_momentum_lambda + delta_lambda

                            for particle_i = 1, n_particles do
                                local i = _particle_i_to_data_offset(particle_i)
                                local inverse_mass = data[i + _inverse_mass_offset] * inverse_density
                                if hard_anchor and particle_i == 1 then inverse_mass = 0 end
                                local falloff = 1 - angular_falloff * (particle_i - 1) / falloff_denominator

                                local correction_x, correction_y = _enforce_angular_momentum(
                                    data[i + _mass_offset] * density,
                                    inverse_mass * falloff, -- same scaling as in weight_sum
                                    data[i + _previous_x_offset],
                                    data[i + _previous_y_offset],
                                    center_x, center_y,
                                    delta_lambda
                                )
                                data[i + _x_offset] = data[i + _x_offset] + correction_x
                                data[i + _y_offset] = data[i + _y_offset] + correction_y
                            end

                            self._angular_momentum_lambda = lambda_new
                        end
                    end
                end

                if enforce_contour_collision then
                    for _ = 1, n_constraint_iterations do
                        for contour_i = 1, n_collision_contours do
                            local entry = collision_contours[contour_i]
                            local edges = entry.edges
                            local n_edges = entry.n_edges
                            local lambdas = entry.lambdas
                            local normals_x, normals_y = entry.normals_x, entry.normals_y
                            local candidates = entry.candidate_particles
                            local n_candidates = entry.n_candidate_particles
                            local keep_outside = entry.contour:get_winding()

                            local first_candidate_i, last_candidate_i, candidate_step
                            if reverse_iteration then
                                first_candidate_i, last_candidate_i, candidate_step = n_candidates, 1, -1
                            else
                                first_candidate_i, last_candidate_i, candidate_step = 1, n_candidates, 1
                            end

                            for candidate_i = first_candidate_i, last_candidate_i, candidate_step do
                                local particle_i = candidates[candidate_i]
                                local i = _particle_i_to_data_offset(particle_i)
                                local inverse_mass = data[i + _inverse_mass_offset]

                                local correction_x, correction_y, lambda_new, normal_x, normal_y = _enforce_polygon_collision(
                                    data[i + _x_offset], data[i + _y_offset],
                                    inverse_mass,
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
                            local candidates = entry.candidate_particles

                            for candidate_i = 1, entry.n_candidate_particles do
                                local particle_i = candidates[candidate_i]
                                local i = _particle_i_to_data_offset(particle_i)
                                local inverse_mass = data[i + _inverse_mass_offset]

                                local correction_x, correction_y = _enforce_friction(
                                    data[i + _x_offset], data[i + _y_offset],
                                    data[i + _previous_x_offset], data[i + _previous_y_offset],
                                    normals_x[particle_i], normals_y[particle_i],
                                    inverse_mass,
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
        self._elapsed = min(self._elapsed, timestep)

        -- Interpolate the render line between the previous frame snapshot and
        -- the current physical positions, as SoftBody does for its draw contour.
        local draw_vertices = self._draw_line:get_vertices()
        local frame_interpolation_alpha = self._elapsed / timestep
        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local vertex_i = 2 * particle_i - 1
            local previous_x = data[i + _snapshot_x_offset]
            local previous_y = data[i + _snapshot_y_offset]
            local current_x = data[i + _x_offset]
            local current_y = data[i + _y_offset]

            local x = previous_x + (current_x - previous_x) * frame_interpolation_alpha
            local y = previous_y + (current_y - previous_y) * frame_interpolation_alpha

            data[i + _draw_x_offset] = x
            data[i + _draw_y_offset] = y
            draw_vertices[vertex_i] = x
            draw_vertices[vertex_i + 1] = y
        end

        return self
    end
end

function rt.HairBody:_debug_draw()
    meta.typecheck(self, rt.HairBody)

    local data = self._particles

    local color_r, color_g, color_b, color_a = love.graphics.getColor()

    if self._draw_buffer == nil then
        self._draw_buffer = {}
        for particle_i = 1, self._n_particles do
            local r = data[_particle_i_to_data_offset(particle_i) + _radius_offset]
            local current = {}
            local n_vertices = rt.Mesh.radius_to_n_vertices(r)
            for i = 0, n_vertices do
                local angle = (i - 1) / n_vertices * math.tau
                table.insert(current, math.cos(angle) * r)
                table.insert(current, math.sin(angle) * r)
            end
            table.insert(self._draw_buffer, current)
        end
    end

    love.graphics.setLineWidth(3)
    love.graphics.setLineJoin("bevel")
    love.graphics.setLineStyle("smooth")

    love.graphics.setColor(color_r, color_g, color_b, color_a)
    for particle_i = 1, self._n_particles - 1 do
        local i = _particle_i_to_data_offset(particle_i)
        local x, y = data[i + _x_offset], data[i + _y_offset]

        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.line(self._draw_buffer[particle_i])
        love.graphics.pop()
    end

    rt.Palette.BLACK:bind()
    for particle_i = 1, self._n_particles - 1 do
        local i = _particle_i_to_data_offset(particle_i)
        local x, y = data[i + _x_offset], data[i + _y_offset]
        local r = data[i + _radius_offset]

        love.graphics.circle("fill", x, y, r)
    end
end

do

    local function get_hull(samples)
        local sorted = {}
        for i = 1, #samples do
            sorted[i] = samples[i]
        end

        table.sort(sorted, function(a, b)
            if a[1] == b[1] then return a[2] < b[2] end
            return a[1] < b[1]
        end)

        if #sorted <= 2 then return sorted end

        local lower = {}
        for i = 1, #sorted do
            local point = sorted[i]
            while #lower >= 2 do
                local a = lower[#lower - 1]
                local b = lower[#lower]
                local cross = (b[1] - a[1]) * (point[2] - a[2]) -
                    (b[2] - a[2]) * (point[1] - a[1])
                if cross > 0 then break end
                lower[#lower] = nil
            end
            lower[#lower + 1] = point
        end

        local upper = {}
        for i = #sorted, 1, -1 do
            local point = sorted[i]
            while #upper >= 2 do
                local a = upper[#upper - 1]
                local b = upper[#upper]
                local cross = (b[1] - a[1]) * (point[2] - a[2]) -
                    (b[2] - a[2]) * (point[1] - a[1])
                if cross > 0 then break end
                upper[#upper] = nil
            end
            upper[#upper + 1] = point
        end

        local hull = {}
        for i = 1, #lower - 1 do
            hull[#hull + 1] = lower[i]
        end
        for i = 1, #upper - 1 do
            hull[#hull + 1] = upper[i]
        end
        return hull
    end

    function rt.HairBody:get_draw_contour()
        meta.typecheck(self, rt.HairBody)

        local data = self._particles
        local n_circles = self._n_particles - 1
        if n_circles <= 0 then
            return rt.Polyline({})
        end

        local max_radius = 0
        for particle_i = 1, n_circles do
            local i = _particle_i_to_data_offset(particle_i)
            local radius = data[i + _radius_offset]
            if radius > max_radius then max_radius = radius end
        end

        local tolerance = math.max(max_radius * 0.0025, 1e-10)
        local max_points = math.min(256, math.max(128, n_circles * 8))
        local duplicate_epsilon = 1
        local duplicate_epsilon_sq = duplicate_epsilon * duplicate_epsilon

        local samples = {}
        local function add_sample(x, y)
            for sample_i = 1, #samples do
                local point = samples[sample_i]
                local dx = point[1] - x
                local dy = point[2] - y
                if dx * dx + dy * dy <= duplicate_epsilon_sq then
                    return false
                end
            end

            samples[#samples + 1] = { x, y }
            return true
        end

        local function get_support(nx, ny)
            local best_projection = -math.huge
            local best_x, best_y

            for particle_i = 1, n_circles do
                local i = _particle_i_to_data_offset(particle_i)
                local x = data[i + _draw_x_offset]
                local y = data[i + _draw_y_offset]
                local radius = data[i + _radius_offset]
                local projection = x * nx + y * ny + radius

                if projection > best_projection then
                    best_projection = projection
                    best_x = x + radius * nx
                    best_y = y + radius * ny
                end
            end

            return best_x, best_y, best_projection
        end

        local initial_directions = 8
        for direction_i = 0, initial_directions - 1 do
            local angle = direction_i / initial_directions * math.tau
            local nx, ny = math.cos(angle), math.sin(angle)
            local x, y = get_support(nx, ny)
            add_sample(x, y)
        end

        while #samples < max_points do
            local hull = get_hull(samples)
            local hull_size = #hull
            if hull_size < 3 then break end

            local added = false
            for edge_i = 1, hull_size do
                local a = hull[edge_i]
                local b = hull[edge_i % hull_size + 1]
                local dx = b[1] - a[1]
                local dy = b[2] - a[2]
                local length = math.sqrt(dx * dx + dy * dy)

                if length > duplicate_epsilon then
                    local nx, ny = dy / length, -dx / length
                    local edge_projection = 0.5 * (
                        a[1] * nx + a[2] * ny + b[1] * nx + b[2] * ny
                    )
                    local x, y, support_projection = get_support(nx, ny)

                    if support_projection - edge_projection > tolerance then
                        if add_sample(x, y) then
                            added = true
                            if #samples >= max_points then break end
                        end
                    end
                end
            end

            if not added then break end
        end

        local hull = get_hull(samples)
        local n_vertices = #hull
        local draw_particles = self._draw_contour_particles

        -- The scratch particle layout is x, y, lambda. Draw vertices have
        -- zero radius and unit inverse mass, so neither needs an array slot.
        for particle_i = 1, n_vertices do
            local base = (particle_i - 1) * 3 + 1
            local point = hull[particle_i]
            draw_particles[base] = point[1]
            draw_particles[base + 1] = point[2]
            draw_particles[base + 2] = 0
        end

        local override = self._override or {}
        local default = rt.settings.hairbody.default
        local enforce_collision = override.enforce_contour_collision
        if enforce_collision == nil then enforce_collision = default.enforce_contour_collision end
        enforce_collision = enforce_collision and (self._use_collision ~= false)

        local collision_contours = self._collision_contours
        if enforce_collision and #collision_contours > 0 then
            local timestep = override.timestep or default.timestep
            local n_sub_steps = override.n_sub_steps or default.n_sub_steps
            local n_iterations = override.n_constraint_iterations or default.n_constraint_iterations
            local compliance = 0
            if compliance == nil then compliance = default.contour_collision_compliance end

            local sub_delta = timestep / n_sub_steps
            local alpha = compliance / (sub_delta * sub_delta)

            for contour_i = 1, #collision_contours do
                local entry = collision_contours[contour_i]
                local edges = entry.edges
                local n_edges = entry.n_edges

                if n_edges > 0 then
                    for particle_i = 1, n_vertices do
                        local base = (particle_i - 1) * 3 + 1
                        draw_particles[base + 2] = 0
                    end

                    local keep_outside = entry.contour:get_winding()
                    for _ = 1, n_iterations do
                        for particle_i = 1, n_vertices do
                            local base = (particle_i - 1) * 3 + 1
                            local correction_x, correction_y, lambda_new =
                            rt.SoftBody._enforce_polygon_collision(
                                draw_particles[base],
                                draw_particles[base + 1],
                                1, -- inverse mass
                                1, -- point particle: no collision radius
                                edges, n_edges,
                                alpha,
                                draw_particles[base + 2],
                                keep_outside
                            )

                            draw_particles[base] = draw_particles[base] + correction_x
                            draw_particles[base + 1] = draw_particles[base + 1] + correction_y
                            draw_particles[base + 2] = lambda_new
                        end
                    end
                end
            end
        end

        local vertices = {}
        for particle_i = 1, n_vertices do
            local base = (particle_i - 1) * 3 + 1
            vertices[2 * particle_i - 1] = draw_particles[base]
            vertices[2 * particle_i] = draw_particles[base + 1]
        end

        return rt.Polyline(vertices)
    end
end

--- @brief
function rt.HairBody:set_use_collision(b)
    self._use_collision = b
end