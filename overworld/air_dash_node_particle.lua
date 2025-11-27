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

--- @brief Project a 3D ring onto 2D as an ellipse
--- Returns: center_x, center_y, radius_x, radius_y, rotation_angle
local function _project_ring_to_ellipse(normal_x, normal_y, normal_z, radius, theta, phi)
    -- Rotate the normal vector by the same rotations
    -- First rotate around Y by phi
    local cos_phi, sin_phi = math.cos(phi), math.sin(phi)
    local nx1 =  normal_x * cos_phi + normal_z * sin_phi
    local ny1 =  normal_y
    local nz1 = -normal_x * sin_phi + normal_z * cos_phi

    -- Then rotate around X by theta
    local cos_theta, sin_theta = math.cos(theta), math.sin(theta)
    local nx2 = nx1
    local ny2 = ny1 * cos_theta - nz1 * sin_theta
    local nz2 = ny1 * sin_theta + nz1 * cos_theta

    -- The rotated normal is (nx2, ny2, nz2)
    -- For a ring with this normal, we need two orthogonal vectors in the plane
    -- Find an arbitrary vector not parallel to the normal
    local temp_x, temp_y, temp_z
    if math.abs(nx2) < 0.9 then
        temp_x, temp_y, temp_z = 1, 0, 0
    else
        temp_x, temp_y, temp_z = 0, 1, 0
    end

    -- First basis vector: cross product of normal and temp
    local u_x = ny2 * temp_z - nz2 * temp_y
    local u_y = nz2 * temp_x - nx2 * temp_z
    local u_z = nx2 * temp_y - ny2 * temp_x
    local u_len = math.sqrt(u_x * u_x + u_y * u_y + u_z * u_z)
    u_x, u_y, u_z = u_x / u_len, u_y / u_len, u_z / u_len

    -- Second basis vector: cross product of normal and first basis
    local v_x = ny2 * u_z - nz2 * u_y
    local v_y = nz2 * u_x - nx2 * u_z
    local v_z = nx2 * u_y - ny2 * u_x

    -- When projected to 2D (ignoring z), the ellipse is defined by these vectors
    -- Ellipse semi-axes are the projected lengths of radius * u and radius * v
    local axis1_x = radius * u_x
    local axis1_y = radius * u_y

    local axis2_x = radius * v_x
    local axis2_y = radius * v_y

    -- Find the ellipse parameters from these two axes
    -- The semi-major and semi-minor axes and rotation angle
    local a_sq = axis1_x * axis1_x + axis1_y * axis1_y
    local b_sq = axis2_x * axis2_x + axis2_y * axis2_y

    -- Compute rotation angle from axis1
    local angle = math.atan2(axis1_y, axis1_x)

    -- Radii are the lengths of the projected axes
    local rx = math.sqrt(a_sq)
    local ry = math.sqrt(b_sq)

    return 0, 0, rx, ry, angle
end

--- @brief
function ow.AirDashNodeParticle:instantiate(radius)
    self._theta, self._phi = rt.random.number(0, 2 * math.pi), rt.random.number(0, 2 * math.pi)
    self._radius = radius
    self._x, self._y, self._z = 0, 0, 0
    self._canvas = rt.RenderTexture(2 * (radius + _padding), 2 * (radius + _padding))
    self._canvas:set_scale_mode(rt.TextureScaleMode.LINEAR)

    self._explosion_motion = rt.SmoothedMotion1D(0)
    self._explosion_motion:set_speed(2, 1)

    self._brightness_offset = 0
    self._scale_offset = 0

    -- Storage for ellipse parameters: {cx, cy, rx, ry, rotation}
    self._rings_ellipses = {}
    self:_update_rings()
end

-- Ring normals in object space (perpendicular to each ring plane)
local _ring_normals = {
    {0, 0, 1}, -- XY plane, normal is +Z
    {1, 0, 0}, -- YZ plane, normal is +X
    {0, 1, 0}, -- ZX plane, normal is +Y
}

--- @brief Recompute ellipse parameters for each ring with current rotation and offsets
function ow.AirDashNodeParticle:_update_rings()
    local offset = self._scale_offset * rt.settings.overworld.double_jump_tether_particle.scale_offset_distance
        + self._explosion_motion:get_value() * rt.settings.overworld.double_jump_tether_particle.explosion_distance

    local base_r = self._radius + offset
    local radii = {
        base_r * 0.55,
        base_r * 0.8,
        base_r * 1.05
    }

    local theta, phi = self._theta, self._phi
    local ellipses = {}

    for i = 1, 3 do
        local normal = _ring_normals[i]
        local r = radii[i]

        local cx, cy, rx, ry, angle = _project_ring_to_ellipse(
            normal[1], normal[2], normal[3],
            r, theta, phi
        )

        -- Apply translation
        cx = cx + self._x
        cy = cy + self._y

        ellipses[i] = {
            cx = cx,
            cy = cy,
            rx = rx,
            ry = ry,
            angle = angle
        }
    end

    self._rings_ellipses = ellipses
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
            love.graphics.setColor(r, g, b, a * (1 - self._explosion_motion:get_value()))

            for i = 1, #self._rings_ellipses do
                local ellipse = self._rings_ellipses[i]
                love.graphics.push()
                love.graphics.translate(ellipse.cx, ellipse.cy)
                love.graphics.rotate(ellipse.angle)
                love.graphics.ellipse("line", 0, 0, ellipse.rx, ellipse.ry)
                love.graphics.pop()
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

        love.graphics.translate(x, y)
        love.graphics.setColor(r * offset, g * offset, b * offset, a)

        for i = 1, #self._rings_ellipses do
            local ellipse = self._rings_ellipses[i]
            love.graphics.push()
            love.graphics.translate(ellipse.cx, ellipse.cy)
            love.graphics.rotate(ellipse.angle)
            love.graphics.ellipse("line", 0, 0, ellipse.rx, ellipse.ry)
            love.graphics.pop()
        end

        love.graphics.pop()
    end
end