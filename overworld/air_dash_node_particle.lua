require "common.smoothed_motion_1d"

rt.settings.overworld.double_jump_tether_particle = {
    explosion_distance = 80, -- px
    scale_offset_distance = 5, -- px
    brightness_offset = 0.5 -- fraction
}

--- @class ow.AirDashNodeParticle
ow.AirDashNodeParticle = meta.class("AirDashNodeParticle")

local _padding = 10
local _outline_shader = rt.Shader("overworld/double_jump_tether_particle.glsl", { MODE = 0 })

-- number of segments used to approximate each ring
local _RING_SEGMENTS = 32

--- @brief Rotate a 3D point by yaw (phi) around Y and pitch (theta) around X, then return projected 2D (x,y) and z
local function _rotate_point(x, y, z, theta, phi)
    -- rotate around Y by phi
    local cos_phi, sin_phi = math.cos(phi), math.sin(phi)
    local x1 =  x * cos_phi + z * sin_phi
    local y1 =  y
    local z1 = -x * sin_phi + z * cos_phi

    -- rotate around X by theta
    local cos_theta, sin_theta = math.cos(theta), math.sin(theta)
    local x2 = x1
    local y2 = y1 * cos_theta - z1 * sin_theta
    local z2 = y1 * sin_theta + z1 * cos_theta

    return x2, y2, z2
end

--- @brief
function ow.AirDashNodeParticle:instantiate(radius)
    self._theta, self._phi = rt.random.number(0, 2 * math.pi), rt.random.number(0, 2 * math.pi) -- spherical rotation angles
    self._radius = radius
    self._x, self._y, self._z = 0, 0, 0
    self._canvas = rt.RenderTexture(2 * (radius + _padding), 2 * (radius + _padding))
    self._canvas:set_scale_mode(rt.TextureScaleMode.LINEAR)

    self._explosion_motion = rt.SmoothedMotion1D(0) -- 0: not exploded, 1: fully exploded
    self._explosion_motion:set_speed(2, 1) -- attack, decay, fractional

    self._brightness_offset = 0
    self._scale_offset = 0

    -- storage for flattened line vertices of each ring
    self._rings_draw_lines = {} -- array of {x1, y1, x2, y2, ...}
    self:_update_rings()
end

-- Base ring orientations in object space (orthogonal planes):
-- Ring A in XY plane (normal +Z), Ring B in YZ plane (normal +X), Ring C in ZX plane (normal +Y)
local _ring_planes = {
    { u = {1, 0, 0}, v = {0, 1, 0} }, -- XY
    { u = {0, 1, 0}, v = {0, 0, 1} }, -- YZ
    { u = {0, 0, 1}, v = {1, 0, 0} }, -- ZX
}

--- @brief Recompute ring polylines with current rotation and offsets
function ow.AirDashNodeParticle:_update_rings()
    -- outward offset behavior consistent with previous tetrahedron
    local offset = self._scale_offset * rt.settings.overworld.double_jump_tether_particle.scale_offset_distance
        + self._explosion_motion:get_value() * rt.settings.overworld.double_jump_tether_particle.explosion_distance

    -- choose three radii that are concentric and visually distinct
    local base_r = self._radius + offset
    local radii = {
        base_r * 0.55,
        base_r * 0.8,
        base_r * 1.05
    }

    local theta, phi = self._theta, self._phi
    local rings = {}

    for i = 1, 3 do
        local plane = _ring_planes[i]
        local u = plane.u
        local v = plane.v
        local r = radii[i]

        -- approximate circle in the plane spanned by u and v
        local pts = {}
        for s = 0, _RING_SEGMENTS do
            local t = (s / _RING_SEGMENTS) * 2 * math.pi
            local cx, cy = math.cos(t), math.sin(t)

            local x = r * (cx * u[1] + cy * v[1])
            local y = r * (cx * u[2] + cy * v[2])
            local z = r * (cx * u[3] + cy * v[3])

            -- apply global rotation
            local xr, yr, zr = _rotate_point(x, y, z, theta, phi)

            -- translate (kept for parity with previous implementation)
            xr = xr + self._x
            yr = yr + self._y
            zr = zr + self._z

            table.insert(pts, xr)
            table.insert(pts, yr)
        end

        rings[i] = pts
    end

    self._rings_draw_lines = rings
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
    local speed = 0.05 -- radians per second
    self._theta = math.normalize_angle(self._theta + delta * 2 * math.pi * speed)
    self._phi = math.normalize_angle(self._phi + delta * 2 * math.pi * speed)
    self:_update_rings()
    self._canvas_needs_update = true

    self._explosion_motion:update(delta)
end

function ow.AirDashNodeParticle:draw(x, y, draw_shape, draw_core)
    local line_width = self._canvas:get_width() / 35
    local w, h = self._canvas:get_size()
    local r, g, b, a = love.graphics.getColor()

    if self._canvas_needs_update then
        love.graphics.push()
        love.graphics.origin()
        self._canvas:bind()
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.translate(0.5 * w, 0.5 * h)

        if draw_shape then
            love.graphics.setLineWidth(line_width)
            love.graphics.setLineJoin("none")
            love.graphics.setColor(r, g, b, a * (1 - self._explosion_motion:get_value()))

            for i = 1, #self._rings_draw_lines do
                love.graphics.line(self._rings_draw_lines[i])
            end
        end

        self._canvas:unbind()
        love.graphics.pop()

        self._canvas_needs_update = false
    end

    _outline_shader:bind()
    _outline_shader:send("black", { rt.Palette.BLACK:unpack() })
    _outline_shader:send("draw_core", draw_core)
    _outline_shader:send("brightness_offset", self._brightness_offset)
    love.graphics.draw(self._canvas:get_native(), x - 0.5 * w, y - 0.5 * h)
    _outline_shader:unbind()

    if draw_shape == true then
        local offset = math.mix(1, rt.settings.impulse_manager.max_brightness_factor, self._brightness_offset)
        love.graphics.push()
        love.graphics.setLineWidth(math.mix(line_width, line_width * 1.5, self._brightness_offset))
        love.graphics.setLineJoin("none")

        love.graphics.translate(x, y)
        love.graphics.setColor(r * offset, g * offset, b * offset, a)

        for i = 1, #self._rings_draw_lines do
            love.graphics.line(self._rings_draw_lines[i])
        end

        love.graphics.pop()
    end
end