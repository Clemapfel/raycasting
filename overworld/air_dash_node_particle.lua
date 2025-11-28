require "common.smoothed_motion_1d"

rt.settings.overworld.air_dash_node_particle = {
    explosion_distance = 80, -- px
    scale_offset_distance = 5, -- px
    brightness_offset = 0.5, -- fraction
    n_circles = 3 -- number of circles rotating around core
}

--- @class ow.AirDashNodeParticle
ow.AirDashNodeParticle = meta.class("AirDashNodeParticle")

local _sqrt2 = math.sqrt(2)
local _sqrt3 = math.sqrt(3)

-- local math helpers
local function _normalize3(x, y, z)
    local l = math.sqrt(x * x + y * y + z * z)
    if l == 0 then return 0, 0, 1 end
    return x / l, y / l, z / l
end

local function _cross(ax, ay, az, bx, by, bz)
    return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
end

local function _dot(ax, ay, az, bx, by, bz)
    return ax * bx + ay * by + az * bz
end

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

    -- Initialize circles
    self._n_circles = rt.settings.overworld.air_dash_node_particle.n_circles
    self._circles = {}

    for i = 1, self._n_circles do
        self._circles[i] = {
            radius = radius - 3, --math.mix(0.75 * radius, radius, (i - 1) / self._n_circles),
            angle_offset = (i - 1) * (2 * math.pi / self._n_circles), -- distribute evenly around sphere

            -- computed each update:
            back_strips = {},  -- array of {x1,y1,x2,y2,...}
            front_strips = {}  -- array of {x1,y1,x2,y2,...}
        }
    end

    self:_update_segments()
end

--- @brief compute 3D oriented circle basis, sample it, and split into back/front line strips
function ow.AirDashNodeParticle:_update_segments()
    local offset = self._scale_offset * rt.settings.overworld.air_dash_node_particle.scale_offset_distance
        + self._explosion_motion:get_value() * rt.settings.overworld.air_dash_node_particle.explosion_distance

    local cx = self._x
    local cy = self._y
    local cz = self._z

    -- alignment factor in [0,1]
    local align_t = self._alignment_motion:get_value()

    -- normalized target normal for aligned pose
    local Nx, Ny, Nz = _normalize3(self._target_normal_x, self._target_normal_y, self._target_normal_z)

    -- choose a robust reference that's not parallel to N
    local rx, ry, rz
    if math.abs(Nz) < 0.999 then
        rx, ry, rz = 0, 0, 1
    else
        rx, ry, rz = 0, 1, 0
    end

    -- build an orthonormal basis (U_align, V_align) spanning plane perpendicular to N
    local Uax, Uay, Uaz = _cross(Nx, Ny, Nz, rx, ry, rz)
    Uax, Uay, Uaz = _normalize3(Uax, Uay, Uaz)
    -- If degenerate (shouldn't be), fall back to X axis
    if Uax == 0 and Uay == 0 and Uaz == 0 then Uax, Uay, Uaz = 1, 0, 0 end
    local Vax, Vay, Vaz = _cross(Nx, Ny, Nz, Uax, Uay, Uaz)
    Vax, Vay, Vaz = _normalize3(Vax, Vay, Vaz)

    for circle_idx = 1, self._n_circles do
        local circle = self._circles[circle_idx]
        local circle_radius = circle.radius + offset
        local angle_offset = circle.angle_offset

        -- Define initial basis U=(1,0,0), V=(0,1,0) in XY plane and normal N=(0,0,1) for the "regular" pose
        local ux, uy, uz = 1, 0, 0
        local vx, vy, vz = 0, 1, 0

        -- Regular pose: first rotate around Y by angle_offset to tilt the plane
        do
            local c, s = math.cos(angle_offset), math.sin(angle_offset)
            local ux1, uy1, uz1 = ux * c - uz * s, uy, ux * s + uz * c
            local vx1, vy1, vz1 = vx * c - vz * s, vy, vx * s + vz * c
            ux, uy, uz = ux1, uy1, uz1
            vx, vy, vz = vx1, vy1, vz1
        end

        -- Apply spherical rotations: phi around Y, then theta around X
        do
            local phi = self._phi
            local c, s = math.cos(phi), math.sin(phi)
            local ux1, uy1, uz1 = ux * c - uz * s, uy, ux * s + uz * c
            local vx1, vy1, vz1 = vx * c - vz * s, vy, vx * s + vz * c
            ux, uy, uz = ux1, uy1, uz1
            vx, vy, vz = vx1, vy1, vz1
        end
        do
            local theta = self._theta
            local c, s = math.cos(theta), math.sin(theta)
            local ux1, uy1, uz1 = ux, uy * c - uz * s, uy * s + uz * c
            local vx1, vy1, vz1 = vx, vy * c - vz * s, vy * s + vz * c
            ux, uy, uz = ux1, uy1, uz1
            vx, vy, vz = vx1, vy1, vz1
        end

        -- Aligned pose: use plane perpendicular to target normal, rotate in-plane by angle_offset
        local ca, sa = math.cos(angle_offset), math.sin(angle_offset)
        local uax = Uax * ca + Vax * sa
        local uay = Uay * ca + Vay * sa
        local uaz = Uaz * ca + Vaz * sa
        local vax = -Uax * sa + Vax * ca
        local vay = -Uay * sa + Vay * ca
        local vaz = -Uaz * sa + Vaz * ca

        -- Prepare sampling resolution: roughly one vertex every ~4px of circumference, clamped
        local approx_circ = 2 * math.pi * circle_radius
        local n_segments = math.max(24, math.min(256, math.floor(approx_circ / 4)))
        local n_points = n_segments -- we'll wrap the last segment to the first point

        -- Generate points for regular and aligned poses and blend them
        local pts = {} -- array of {x, y, z}
        for i = 0, n_points - 1 do
            local t = (i / n_points) * 2 * math.pi
            local ct, st = math.cos(t), math.sin(t)

            -- regular
            local rx1 = cx + circle_radius * (ct * ux + st * vx)
            local ry1 = cy + circle_radius * (ct * uy + st * vy)
            local rz1 = cz + circle_radius * (ct * uz + st * vz)

            -- aligned (in the plane of target normal)
            local ax1 = cx + circle_radius * (ct * uax + st * vax)
            local ay1 = cy + circle_radius * (ct * uay + st * vay)
            local az1 = cz + circle_radius * (ct * uaz + st * vaz)

            -- blend
            local px = math.mix(rx1, ax1, align_t)
            local py = math.mix(ry1, ay1, align_t)
            local pz = math.mix(rz1, az1, align_t)

            pts[#pts + 1] = { px, py, pz }
        end

        -- Convenience for wrap indexing
        local function get_point(i)
            local idx = ((i - 1) % n_points) + 1
            return pts[idx][1], pts[idx][2], pts[idx][3]
        end

        -- Split into back/front strips relative to core z (cz)
        local back_strips = {}
        local front_strips = {}
        local curr_back = nil
        local curr_front = nil

        local function append_point(strip, x, y)
            strip[#strip + 1] = x
            strip[#strip + 1] = y
        end

        for i = 1, n_points do
            local x0, y0, z0 = get_point(i)
            local x1, y1, z1 = get_point(i + 1)

            local d0 = z0 - cz
            local d1 = z1 - cz

            if d0 < 0 and d1 < 0 then
                -- Entirely behind
                if curr_back == nil then curr_back = {} end
                if #curr_back == 0 then append_point(curr_back, x0, y0) end
                append_point(curr_back, x1, y1)
            elseif d0 >= 0 and d1 >= 0 then
                -- Entirely in front
                if curr_front == nil then curr_front = {} end
                if #curr_front == 0 then append_point(curr_front, x0, y0) end
                append_point(curr_front, x1, y1)
            else
                -- Segment crosses the core plane, split at intersection
                local t = d1 ~= d0 and (-d0) / (d1 - d0) or 0.5
                t = math.max(0, math.min(1, t))
                local xi = x0 + (x1 - x0) * t
                local yi = y0 + (y1 - y0) * t
                -- zi would be cz by construction

                if d0 < 0 and d1 >= 0 then
                    -- Back -> Front
                    if curr_back == nil then curr_back = {} end
                    if #curr_back == 0 then append_point(curr_back, x0, y0) end
                    append_point(curr_back, xi, yi)
                    if #curr_back >= 4 then back_strips[#back_strips + 1] = curr_back end
                    curr_back = nil

                    if curr_front == nil then curr_front = {} end
                    append_point(curr_front, xi, yi)
                    append_point(curr_front, x1, y1)
                else
                    -- Front -> Back
                    if curr_front == nil then curr_front = {} end
                    if #curr_front == 0 then append_point(curr_front, x0, y0) end
                    append_point(curr_front, xi, yi)
                    if #curr_front >= 4 then front_strips[#front_strips + 1] = curr_front end
                    curr_front = nil

                    if curr_back == nil then curr_back = {} end
                    append_point(curr_back, xi, yi)
                    append_point(curr_back, x1, y1)
                end
            end
        end

        -- Close any remaining current strips
        if curr_back ~= nil and #curr_back >= 4 then
            back_strips[#back_strips + 1] = curr_back
        end
        if curr_front ~= nil and #curr_front >= 4 then
            front_strips[#front_strips + 1] = curr_front
        end

        -- Store results
        circle.back_strips = back_strips
        circle.front_strips = front_strips

        -- Avg z can still be useful for optional ordering if needed
        circle.avg_z = cz
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
    -- animate rotations
    local speed = 0.05 -- rotations per second
    self._theta = math.normalize_angle(self._theta + delta * 2 * math.pi * speed)
    self._phi = math.normalize_angle(self._phi + delta * 2 * math.pi * speed)

    -- update smoothing motions
    self._explosion_motion:update(delta)
    self._alignment_motion:update(delta)

    self:_update_segments()
end

--- @brief
function ow.AirDashNodeParticle:draw(x, y, draw_shape, draw_core)

    local offset = math.mix(1, rt.settings.impulse_manager.max_brightness_factor, self._brightness_offset)

    local _draw = function(r, g, b, a, line_width, scale)
        love.graphics.push()
        love.graphics.translate(x, y)

        if draw_shape == true then
            -- Draw BACK strips first (behind core)
            for i = 1, self._n_circles do
                local circle = self._circles[i]

                for _, strip in ipairs(circle.back_strips) do
                    love.graphics.setColor(r * offset, g * offset, b * offset, a)
                    love.graphics.setLineWidth(math.mix(line_width, line_width * 1.5, self._brightness_offset))
                    if #strip >= 4 then
                        love.graphics.line(strip)
                    end
                end
            end
        end

        -- Draw CORE in between
        if draw_core == true then
            love.graphics.push()
            love.graphics.scale(scale, scale) -- core outline
            love.graphics.setColor(r, g, b, a)
            self._core:draw()
            love.graphics.pop()
        end

        if draw_shape == true then
            -- Draw FRONT strips last (in front of core)
            for i = 1, self._n_circles do
                local circle = self._circles[i]

                for _, strip in ipairs(circle.front_strips) do
                    love.graphics.setColor(r * offset, g * offset, b * offset, a)
                    love.graphics.setLineWidth(math.mix(line_width, line_width * 1.5, self._brightness_offset))
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