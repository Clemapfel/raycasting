require "common.shader"
require "common.mesh"
require "common.color"
require "common.interpolation_functions"

rt.settings.overworld.player_recorder_eyes = {
    aspect_ratio = 1 / 2, -- width to height
}

--- @class ow.PlayerRecordEyes
ow.PlayerRecorderEyes = meta.class("PlayerRecorderEyes")

local _base_shader = rt.Shader("common/player_body_core.glsl")

--- @brief
function ow.PlayerRecorderEyes:instantiate(radius, position_x, position_y)
    self._radius = radius
    self._position_x = position_x or 0
    self._position_y = position_y or 0

    self._look_at_x = self._position_x
    self._look_at_y = self._position_y

    -- Spherical coordinates (radius, theta, phi)
    -- theta: angle in xz-plane from z-axis (left-right rotation)
    -- phi: angle from y-axis (up-down rotation)
    self._sphere_radius = radius * 1.5
    self._sphere_theta = 0  -- horizontal rotation
    self._sphere_phi = math.pi / 2  -- vertical rotation (pi/2 = equator, facing forward)

    self:_initialize()
end

--- @brief
function ow.PlayerRecorderEyes:_initialize()
    local radius_to_h = 0.8
    local radius_to_spacing = 0.6

    local ratio = rt.settings.overworld.player_recorder_eyes.aspect_ratio
    local base_y_radius = radius_to_h * self._radius
    local base_x_radius = ratio * base_y_radius

    local center_x, center_y = 0, 0
    local spacing = radius_to_spacing * self._radius
    local left_x = center_x - base_x_radius - 0.5 * spacing
    local right_x = center_x + base_x_radius + 0.5 * spacing

    local left_y, right_y = center_y, center_y

    local n_vertices = 32

    local easing = rt.InterpolationFunctions.SINUSOID_EASE_IN_OUT
    local gradient_color = function(y)
        local y_shift = 0.25
        local v = math.clamp(easing(1 - y + y_shift), 0, 1)
        return v, v, v, 1
    end

    local position_to_uv = function(x, y)
        local u = (x + base_x_radius) / (2 * base_x_radius)
        local v = (y + base_y_radius) / (2 * base_y_radius)
        return u, v
    end

    do
        local x = 0
        local y = 0
        local u, v = position_to_uv(x, y)

        self._base_left_data = {
            { left_x + x, left_y + y, u, v, gradient_color(0.5) }
        }
        self._base_right_data = {
            { right_x + x, right_y + y, u, v, gradient_color(0.5) }
        }
    end

    self._base_left_outline = {}
    self._base_right_outline = {}

    for i = 1, n_vertices + 1 do
        local angle = (i - 1) / n_vertices * 2 * math.pi
        local x = math.cos(angle) * base_x_radius
        local y = math.sin(angle) * base_y_radius

        local u, v = position_to_uv(x, y)

        local gradient_v = (math.sin(angle) + 1) / 2

        table.insert(self._base_left_data, {
            left_x + x, left_y + y, u, v, gradient_color(gradient_v)
        })

        table.insert(self._base_right_data, {
            right_x + x, right_y + y, u, v, gradient_color(gradient_v)
        })

        table.insert(self._base_left_outline, left_x + x)
        table.insert(self._base_left_outline, left_y + y)
        table.insert(self._base_right_outline, right_x + x)
        table.insert(self._base_right_outline, right_y + y)
    end

    self._base_left = rt.Mesh(self._base_left_data)
    self._base_right = rt.Mesh(self._base_right_data)

    self._outline_width = self._radius / 50
    self._hue = 0.5
    self._outline_color = { rt.lcha_to_rgba(0.8, 1, self._hue, 1) }

    local highlight_x_radius = 0.5 * base_x_radius
    local highlight_y_radius = 0.35 * base_y_radius
    local highlight_x_offset = 0 * base_x_radius
    local highlight_y_offset = -1 * (base_y_radius - highlight_y_radius - self._outline_width * 4)

    self._left_highlight = {
        left_x + highlight_x_offset,
        left_y + highlight_y_offset,
        highlight_x_radius,
        highlight_y_radius,
        n_vertices
    }

    self._right_highlight = {
        right_x + highlight_x_offset,
        right_y + highlight_y_offset,
        highlight_x_radius,
        highlight_y_radius,
        n_vertices
    }

    do
        local v = 0.25
        self._highlight_color = { v, v, v, 0 }
    end
end

--- @brief Calculate 2D transform from spherical coordinates
function ow.PlayerRecorderEyes:_get_spherical_transform()
    -- Convert spherical to Cartesian for projection
    local x = self._sphere_radius * math.sin(self._sphere_phi) * math.sin(self._sphere_theta)
    local y = self._sphere_radius * math.cos(self._sphere_phi)
    local z = self._sphere_radius * math.sin(self._sphere_phi) * math.cos(self._sphere_theta)

    -- Simple perspective projection (orthographic-like)
    -- Translate based on x and y
    local translate_x = x
    local translate_y = y

    -- Scale based on z-depth (closer = larger, farther = smaller)
    -- z ranges from -sphere_radius to +sphere_radius
    -- Normalize to 0 to 1, where 1 is closest (z = sphere_radius)
    local depth_factor = (z + self._sphere_radius) / (2 * self._sphere_radius)
    local scale = 0.5 + 0.5 * depth_factor  -- scale from 0.5 to 1.0

    -- Calculate rotation based on surface normal
    -- For a sphere, the normal at a point is the direction from center to point
    -- We want to rotate the eyes to align with this normal
    local rotation = -self._sphere_theta  -- negative because of coordinate system

    return translate_x, translate_y, scale, rotation
end

--- @brief
function ow.PlayerRecorderEyes:draw()
    love.graphics.push()
    love.graphics.translate(self._position_x, self._position_y)

    -- Apply spherical transform
    local tx, ty, scale, rotation = self:_get_spherical_transform()
    love.graphics.translate(tx, ty)
    love.graphics.rotate(rotation)
    love.graphics.scale(scale, scale)

    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.circle("fill", 0, 0, self._radius)

    rt.Palette.BLACK:bind()
    love.graphics.setLineWidth(self._outline_width + 2)
    love.graphics.line(self._base_left_outline)
    love.graphics.line(self._base_right_outline)

    love.graphics.setColor(1, 1, 1, 1)
    _base_shader:bind()
    _base_shader:send("hue", self._hue)
    _base_shader:send("elapsed", rt.SceneManager:get_elapsed())
    self._base_left:draw()
    _base_shader:send("elapsed", rt.SceneManager:get_elapsed() + math.pi * 123) -- irrational offset
    self._base_right:draw()
    _base_shader:unbind()

    local blend_mode = { love.graphics.getBlendMode() }
    love.graphics.setBlendMode("add", "premultiplied")
    love.graphics.setColor(self._highlight_color)
    love.graphics.ellipse("fill", table.unpack(self._left_highlight))
    love.graphics.ellipse("fill", table.unpack(self._right_highlight))
    love.graphics.setBlendMode(table.unpack(blend_mode))

    love.graphics.setColor(self._outline_color)
    love.graphics.setLineWidth(self._outline_width)
    love.graphics.line(self._base_left_outline)
    love.graphics.line(self._base_right_outline)

    love.graphics.pop()
end

--- @brief
function ow.PlayerRecorderEyes:update(delta)

end

--- @brief
function ow.PlayerRecorderEyes:set_radius(radius)
    if self._radius ~= radius then
        self._radius = radius
        self:_initialize()
    end
end

--- @brief
function ow.PlayerRecorderEyes:set_position(position_x, position_y)
    self._position_x, self._position_y = position_x, position_y
end

--- @brief
function ow.PlayerRecorderEyes:get_position()
    return self._position_x, self._position_y
end

--- @brief Set spherical coordinates
--- @param theta Number horizontal angle (left-right rotation)
--- @param phi Number vertical angle from y-axis (up-down rotation)
--- @param radius Number? optional sphere radius
function ow.PlayerRecorderEyes:set_spherical_coordinates(theta, phi, radius)
    self._sphere_theta = theta
    self._sphere_phi = phi
    if radius then
        self._sphere_radius = radius
    end
end

--- @brief Get spherical coordinates
--- @return Number theta, Number phi, Number radius
function ow.PlayerRecorderEyes:get_spherical_coordinates()
    return self._sphere_theta, self._sphere_phi, self._sphere_radius
end

--- @brief Make the eyes look at a 3D point by setting spherical coordinates
--- @param px Number x-coordinate of target point
--- @param py Number y-coordinate of target point
--- @param pz Number z-coordinate of target point
function ow.PlayerRecorderEyes:look_at(px, py, pz)
    if not px or not py or not pz then
        return
    end

    -- Calculate vector from sphere center (0, 0, 0) to target point
    local dx = px
    local dy = py
    local dz = pz

    -- Calculate distance to target
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

    if distance < 0.0001 then
        -- Target is at origin, keep current orientation
        return
    end

    -- Normalize the direction vector
    dx = dx / distance
    dy = dy / distance
    dz = dz / distance

    -- Convert Cartesian direction to spherical coordinates
    -- phi: angle from positive y-axis (0 to pi)
    -- phi = arccos(y / r) where r = 1 (normalized)
    self._sphere_phi = math.acos(math.clamp(dy, -1, 1))

    -- theta: angle in xz-plane from positive z-axis (-pi to pi)
    -- theta = atan2(x, z)
    self._sphere_theta = math.atan2(dx, dz)
end