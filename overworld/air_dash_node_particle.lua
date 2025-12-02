require "common.smoothed_motion_1d"

rt.settings.overworld.objects.air_dash_node_particle = {
    explosion_distance = 30, -- px
    scale_offset_distance = 5, -- px
    brightness_offset = 0.5, -- fraction
    n_circles = 3 -- number of circles rotating around core
}

--- @class ow.AirDashNodeParticle
ow.AirDashNodeParticle = meta.class("AirDashNodeParticle")

--- @brief
function ow.AirDashNodeParticle:instantiate(radius)
    self._theta, self._phi = rt.random.number(0, 2 * math.pi), rt.random.number(0, 2 * math.pi) -- spherical rotation angles
    self._radius = radius
    self._x, self._y, self._z = 0, 0, 0

    self._explosion_motion = rt.SmoothedMotion1D(0) -- 0: not exploded, 1: fully exploded
    self._explosion_motion:set_speed(2, 1) -- attack, decay, fractional

    self._brightness_offset = 0
    self._scale_offset = 0

    self._is_aligned = false
    self._target_normal_x = 0
    self._target_normal_y = 0
    self._target_normal_z = 1
    self._alignment_motion = rt.SmoothedMotion1D(0) -- 0: not aligned, 1: fully aligned

    local n_outer_vertices = 24
    local core_radius = rt.settings.overworld.double_jump_tether_particle.core_radius_factor * radius
    self._core = rt.MeshRing(
        0, 0,
        0.75 * core_radius,
        core_radius,
        true,
        n_outer_vertices
    )

    local n = self._core:get_n_vertices()
    for i = n, n - n_outer_vertices, -1 do -- outer aliasing
        self._core:set_vertex_color(i, 1, 1, 1, 0)
    end
    self._core:set_vertex_color(1, 1, 1, 1)

    self._n_circles = rt.settings.overworld.objects.air_dash_node_particle.n_circles
    self._circles = {}

    for i = 1, self._n_circles do
        self._circles[i] = {
            radius = radius - 3,
            angle_offset = (i - 1) * (2 * math.pi / self._n_circles),
            back_strips = {},
            front_strips = {}
        }
    end

    self:_update_segments()
end

local _sqrt2 = math.sqrt(2)
local _sqrt3 = math.sqrt(3)

--- @brief compute 3D oriented circle basis, sample it, and split into back/front line strips
function ow.AirDashNodeParticle:_update_segments()
    local explosion_offset = self._explosion_motion:get_value() * rt.settings.overworld.objects.air_dash_node_particle.explosion_distance
    local scale_offset = self._scale_offset * rt.settings.overworld.objects.air_dash_node_particle.scale_offset_distance
    local total_offset = scale_offset + explosion_offset

    local center_x = self._x
    local center_y = self._y
    local center_z = self._z

    local alignment_factor = self._alignment_motion:get_value()

    local target_normal_x, target_normal_y, target_normal_z = math.normalize3(
        self._target_normal_x,
        self._target_normal_y,
        self._target_normal_z
    )

    -- choose reference vector that's not parallel to target normal
    local reference_x, reference_y, reference_z
    if math.abs(target_normal_z) < 1 - math.eps then
        reference_x, reference_y, reference_z = 0, 0, 1
    else
        reference_x, reference_y, reference_z = 0, 1, 0
    end

    -- build orthonormal basis spanning plane perpendicular to target normal
    local aligned_u_x, aligned_u_y, aligned_u_z = math.cross3(
        target_normal_x, target_normal_y, target_normal_z,
        reference_x, reference_y, reference_z
    )
    aligned_u_x, aligned_u_y, aligned_u_z = math.normalize3(aligned_u_x, aligned_u_y, aligned_u_z)

    if aligned_u_x == 0 and aligned_u_y == 0 and aligned_u_z == 0 then
        aligned_u_x, aligned_u_y, aligned_u_z = 1, 0, 0
    end

    local aligned_v_x, aligned_v_y, aligned_v_z = math.cross3(
        target_normal_x, target_normal_y, target_normal_z,
        aligned_u_x, aligned_u_y, aligned_u_z
    )
    aligned_v_x, aligned_v_y, aligned_v_z = math.normalize3(aligned_v_x, aligned_v_y, aligned_v_z)

    for circle_index = 1, self._n_circles do
        local circle = self._circles[circle_index]
        local circle_radius = circle.radius + total_offset
        local angle_offset = circle.angle_offset

        -- initial basis in XY plane for regular pose
        local basis_u_x, basis_u_y, basis_u_z = 1, 0, 0
        local basis_v_x, basis_v_y, basis_v_z = 0, 1, 0

        -- rotate around Y axis by angle_offset to tilt the plane
        do
            local cos_offset, sin_offset = math.cos(circle.angle_offset), math.sin(circle.angle_offset)            local new_u_x = basis_u_x * cos_offset - basis_u_z * sin_offset
            local new_u_y = basis_u_y
            local new_u_z = basis_u_x * sin_offset + basis_u_z * cos_offset

            local new_v_x = basis_v_x * cos_offset - basis_v_z * sin_offset
            local new_v_y = basis_v_y
            local new_v_z = basis_v_x * sin_offset + basis_v_z * cos_offset

            basis_u_x, basis_u_y, basis_u_z = new_u_x, new_u_y, new_u_z
            basis_v_x, basis_v_y, basis_v_z = new_v_x, new_v_y, new_v_z
        end

        -- apply spherical rotation around Y axis (phi)
        do
            local cos_phi, sin_phi = math.cos(self._phi), math.sin(self._phi)
            local new_u_x = basis_u_x * cos_phi - basis_u_z * sin_phi
            local new_u_y = basis_u_y
            local new_u_z = basis_u_x * sin_phi + basis_u_z * cos_phi

            local new_v_x = basis_v_x * cos_phi - basis_v_z * sin_phi
            local new_v_y = basis_v_y
            local new_v_z = basis_v_x * sin_phi + basis_v_z * cos_phi

            basis_u_x, basis_u_y, basis_u_z = new_u_x, new_u_y, new_u_z
            basis_v_x, basis_v_y, basis_v_z = new_v_x, new_v_y, new_v_z
        end

        -- apply spherical rotation around X axis (theta)
        do
            local cos_theta, sin_theta = math.cos(self._theta), math.sin(self._theta)
            local new_u_x = basis_u_x
            local new_u_y = basis_u_y * cos_theta - basis_u_z * sin_theta
            local new_u_z = basis_u_y * sin_theta + basis_u_z * cos_theta

            local new_v_x = basis_v_x
            local new_v_y = basis_v_y * cos_theta - basis_v_z * sin_theta
            local new_v_z = basis_v_y * sin_theta + basis_v_z * cos_theta

            basis_u_x, basis_u_y, basis_u_z = new_u_x, new_u_y, new_u_z
            basis_v_x, basis_v_y, basis_v_z = new_v_x, new_v_y, new_v_z
        end

        -- compute aligned basis rotated in-plane by angle_offset
        local cos_aligned, sin_aligned = math.cos(circle.angle_offset), math.sin(circle.angle_offset)
        local aligned_basis_u_x = aligned_u_x * cos_aligned + aligned_v_x * sin_aligned
        local aligned_basis_u_y = aligned_u_y * cos_aligned + aligned_v_y * sin_aligned
        local aligned_basis_u_z = aligned_u_z * cos_aligned + aligned_v_z * sin_aligned

        local aligned_basis_v_x = -aligned_u_x * sin_aligned + aligned_v_x * cos_aligned
        local aligned_basis_v_y = -aligned_u_y * sin_aligned + aligned_v_y * cos_aligned
        local aligned_basis_v_z = -aligned_u_z * sin_aligned + aligned_v_z * cos_aligned

        -- determine sampling resolution
        local approximate_circumference = 2 * math.pi * circle_radius
        local segment_count = math.max(24, math.min(256, math.floor(approximate_circumference / 4)))
        local point_count = segment_count

        -- generate and blend regular and aligned circle points
        local circle_points = {}
        for point_index = 0, point_count - 1 do
            local parametric_angle = (point_index / point_count) * 2 * math.pi
            local cos_angle, sin_angle = math.cos(parametric_angle), math.sin(parametric_angle)

            -- regular pose point
            local regular_x = center_x + circle_radius * (cos_angle * basis_u_x + sin_angle * basis_v_x)
            local regular_y = center_y + circle_radius * (cos_angle * basis_u_y + sin_angle * basis_v_y)
            local regular_z = center_z + circle_radius * (cos_angle * basis_u_z + sin_angle * basis_v_z)

            -- aligned pose point
            local aligned_x = center_x + circle_radius * (cos_angle * aligned_basis_u_x + sin_angle * aligned_basis_v_x)
            local aligned_y = center_y + circle_radius * (cos_angle * aligned_basis_u_y + sin_angle * aligned_basis_v_y)
            local aligned_z = center_z + circle_radius * (cos_angle * aligned_basis_u_z + sin_angle * aligned_basis_v_z)

            -- blend between regular and aligned
            local blended_x = math.mix(regular_x, aligned_x, alignment_factor)
            local blended_y = math.mix(regular_y, aligned_y, alignment_factor)
            local blended_z = math.mix(regular_z, aligned_z, alignment_factor)

            circle_points[#circle_points + 1] = blended_x
            circle_points[#circle_points + 1] = blended_y
            circle_points[#circle_points + 1] = blended_z
        end

        -- wrap indexing helper
        local function get_point(index)
            local wrapped_index = ((index - 1) % point_count) + 1
            local base_index = (wrapped_index - 1) * 3 + 1
            return circle_points[base_index], circle_points[base_index + 1], circle_points[base_index + 2]
        end

        -- split circle into back and front strips relative to core z-plane
        local back_strips = {}
        local front_strips = {}
        local current_back_strip = nil
        local current_front_strip = nil

        local function append_point_to_strip(strip, x, y)
            strip[#strip + 1] = x
            strip[#strip + 1] = y
        end

        for segment_index = 1, point_count do
            local start_x, start_y, start_z = get_point(segment_index)
            local end_x, end_y, end_z = get_point(segment_index + 1)

            local start_depth = start_z - center_z
            local end_depth = end_z - center_z

            if start_depth < 0 and end_depth < 0 then
                -- segment entirely behind core
                if current_back_strip == nil then current_back_strip = {} end
                if #current_back_strip == 0 then
                    append_point_to_strip(current_back_strip, start_x, start_y)
                end
                append_point_to_strip(current_back_strip, end_x, end_y)

            elseif start_depth >= 0 and end_depth >= 0 then
                -- segment entirely in front of core
                if current_front_strip == nil then current_front_strip = {} end
                if #current_front_strip == 0 then
                    append_point_to_strip(current_front_strip, start_x, start_y)
                end
                append_point_to_strip(current_front_strip, end_x, end_y)

            else
                -- segment crosses core plane, compute intersection
                local interpolation_factor = end_depth ~= start_depth and (-start_depth) / (end_depth - start_depth) or 0.5
                interpolation_factor = math.max(0, math.min(1, interpolation_factor))

                local intersection_x = start_x + (end_x - start_x) * interpolation_factor
                local intersection_y = start_y + (end_y - start_y) * interpolation_factor

                if start_depth < 0 and end_depth >= 0 then
                    -- transition from back to front
                    if current_back_strip == nil then current_back_strip = {} end
                    if #current_back_strip == 0 then
                        append_point_to_strip(current_back_strip, start_x, start_y)
                    end
                    append_point_to_strip(current_back_strip, intersection_x, intersection_y)

                    if #current_back_strip >= 4 then
                        back_strips[#back_strips + 1] = current_back_strip
                    end
                    current_back_strip = nil

                    if current_front_strip == nil then current_front_strip = {} end
                    append_point_to_strip(current_front_strip, intersection_x, intersection_y)
                    append_point_to_strip(current_front_strip, end_x, end_y)

                else
                    -- transition from front to back
                    if current_front_strip == nil then current_front_strip = {} end
                    if #current_front_strip == 0 then
                        append_point_to_strip(current_front_strip, start_x, start_y)
                    end
                    append_point_to_strip(current_front_strip, intersection_x, intersection_y)

                    if #current_front_strip >= 4 then
                        front_strips[#front_strips + 1] = current_front_strip
                    end
                    current_front_strip = nil

                    if current_back_strip == nil then current_back_strip = {} end
                    append_point_to_strip(current_back_strip, intersection_x, intersection_y)
                    append_point_to_strip(current_back_strip, end_x, end_y)
                end
            end
        end

        -- finalize any remaining strips
        if current_back_strip ~= nil and #current_back_strip >= 4 then
            back_strips[#back_strips + 1] = current_back_strip
        end
        if current_front_strip ~= nil and #current_front_strip >= 4 then
            front_strips[#front_strips + 1] = current_front_strip
        end

        circle.back_strips = back_strips
        circle.front_strips = front_strips
    end
end

--- @brief
function ow.AirDashNodeParticle:set_is_exploded(b)
    if b == true then
        self._explosion_motion:set_target_value(1)
    else
        self._explosion_motion:set_target_value(0)
    end
end

--- @brief
function ow.AirDashNodeParticle:set_aligned(is_aligned, normal_x, normal_y, normal_z)
    meta.assert(is_aligned, "Boolean")
    self._is_aligned = is_aligned

    if is_aligned == true then
        meta.assert(normal_x, "Number")
        meta.assert(normal_y, "Number")
        meta.assert(normal_z, "Number")

        self._target_normal_x = normal_x
        self._target_normal_y = normal_y
        self._target_normal_z = normal_z
        self._alignment_motion:set_target_value(1)
    else
        self._alignment_motion:set_target_value(0)
    end
end

--- @brief
function ow.AirDashNodeParticle:set_brightness_offset(t)
    meta.assert(t, "Number")
    self._brightness_offset = t
end

--- @brief
function ow.AirDashNodeParticle:set_scale_offset(t)
    meta.assert(t, "Number")
    self._scale_offset = t
end

--- @brief
function ow.AirDashNodeParticle:update(delta)
    local speed = rt.settings.overworld.double_jump_tether_particle.rotation_speed
    self._theta = math.normalize_angle(self._theta + delta * 2 * math.pi * speed)
    self._phi = math.normalize_angle(self._phi + delta * 2 * math.pi * speed)

    self._explosion_motion:update(delta)
    self._alignment_motion:update(delta)

    self:_update_segments()
end

--- @brief
function ow.AirDashNodeParticle:draw(x, y, draw_shape, draw_core)
    local offset = math.mix(1, rt.settings.impulse_manager.max_brightness_factor, self._brightness_offset)

    local _draw = function(r, g, b, a, line_width, core_scale)
        love.graphics.push()
        love.graphics.translate(x, y)

        if draw_shape then
            -- backstrips behind core
            for i = 1, self._n_circles do
                local circle = self._circles[i]

                love.graphics.setLineWidth(math.mix(line_width, line_width * 1.5, self._brightness_offset))
                for strip in values(circle.back_strips) do
                    love.graphics.setColor(r * offset, g * offset, b * offset, a)
                    if #strip >= 4 then
                        love.graphics.line(strip)
                    end
                end
            end
        end

        if draw_core then
            love.graphics.push()
            love.graphics.scale(core_scale, core_scale) -- core outline
            love.graphics.setColor(r, g, b, a)
            self._core:draw()
            love.graphics.pop()
        end

        if draw_shape then
            -- in front of core
            for i = 1, self._n_circles do
                local circle = self._circles[i]

                love.graphics.setLineWidth(math.mix(line_width, line_width * 1.5, self._brightness_offset))
                for strip in values(circle.front_strips) do
                    love.graphics.setColor(r * offset, g * offset, b * offset, a)
                    if #strip >= 4 then
                        love.graphics.line(strip)
                    end
                end
            end
        end

        love.graphics.pop()
    end

    local r, g, b, a = love.graphics.getColor()
    local line_width = 2
    local black_r, black_g, black_b = rt.Palette.BLACK:unpack()

    _draw(black_r, black_g, black_b, a, line_width + 1.5, 1.25)
    _draw(r, g, b, a, line_width, 1)
end