require "common.smoothed_motion_1d"

rt.settings.overworld.double_jump_tether_particle = {
    explosion_distance = 80, -- px
    scale_offset_distance = 5, -- px
    brightness_offset = 0.5, -- fraction
    core_radius_factor = 0.35
}

--- @class ow.DoubleJumpTetherParticle
ow.DoubleJumpTetherParticle = meta.class("DoubleJumpTetherParticle")

local _sqrt2 = math.sqrt(2)
local _sqrt3 = math.sqrt(3)
local _sqrt6 = math.sqrt(6)

--- @brief
function ow.DoubleJumpTetherParticle:instantiate(radius)
    self._theta, self._phi = rt.random.number(0, 2 * math.pi), rt.random.number(0, 2 * math.pi) -- spherical rotation angles
    self._radius = radius
    self._x, self._y, self._z = 0, 0, 0

    self._explosion_motion = rt.SmoothedMotion1D(0) -- 0: not exploded, 1: fully exploded
    self._explosion_motion:set_speed(2, 1) -- attack, decay, fractional

    self._brightness_offset = 0
    self._scale_offset = 0

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

    self:_update_vertices()
end

local _edges = {
    {1, 2}, {1, 3}, {1, 4},
    {2, 3}, {2, 4},
    {3, 4}
}

--- @brief
function ow.DoubleJumpTetherParticle:_update_vertices()
    local offset = self._scale_offset * rt.settings.overworld.double_jump_tether_particle.scale_offset_distance
        + self._explosion_motion:get_value() * rt.settings.overworld.double_jump_tether_particle.explosion_distance

    local vertices = self._vertices
    if vertices == nil then
        vertices = {
            {  1,  1,  1 },
            { -1, -1,  1 },
            { -1,  1, -1 },
            {  1, -1, -1 },
        }
    else
        vertices[1][1], vertices[1][2], vertices[1][3] =  1,  1,  1
        vertices[2][1], vertices[2][2], vertices[2][3] = -1, -1,  1
        vertices[3][1], vertices[3][2], vertices[3][3] = -1,  1, -1
        vertices[4][1], vertices[4][2], vertices[4][3] =  1, -1, -1
    end

    for v in values(vertices) do
        v[1] = (v[1] / _sqrt3) * (self._radius + offset)
        v[2] = (v[2] / _sqrt3) * (self._radius + offset)
        v[3] = (v[3] / _sqrt3) * (self._radius + offset)
    end

    -- rotate (spherical coordinates)
    local theta, phi = self._theta, self._phi
    for v in values(vertices) do
        local cos_phi, sin_phi = math.cos(phi), math.sin(phi)
        local x1 =  v[1] * cos_phi + v[3] * sin_phi
        local y1 =  v[2]
        local z1 = -v[1] * sin_phi + v[3] * cos_phi

        local cos_theta, sin_theta = math.cos(theta), math.sin(theta)
        local x2 = x1
        local y2 = y1 * cos_theta - z1 * sin_theta
        local z2 = y1 * sin_theta + z1 * cos_theta

        v[1] = x2
        v[2] = y2
        v[3] = z2
    end

    for v in values(vertices) do
        v[1] = v[1] + self._x
        v[2] = v[2] + self._y
        v[3] = v[3] + self._z
    end

    self._vertices = vertices

    self._draw_line = {}
    for edge in values(_edges) do
        local v1 = self._vertices[edge[1]]
        local v2 = self._vertices[edge[2]]
        for x in range(v1[1], v1[2], v2[1], v2[2]) do
            table.insert(self._draw_line, x)
        end
    end
end

--- @brief
function ow.DoubleJumpTetherParticle:set_is_exploded(b)
    if b == true then
        self._explosion_motion:set_target_value(1)
    else
        self._explosion_motion:set_target_value(0)
    end
end

--- @brief
function ow.DoubleJumpTetherParticle:set_brightness_offset(t)
    meta.assert(t, "Number")
    self._brightness_offset = t
end

--- @brief
function ow.DoubleJumpTetherParticle:set_scale_offset(t)
    meta.assert(t, "Number")
    self._scale_offset = t
end

--- @brief
function ow.DoubleJumpTetherParticle:update(delta)
    local speed = 0.05 -- radians per second
    self._theta = math.normalize_angle(self._theta + delta * 2 * math.pi * speed)
    self._phi = math.normalize_angle(self._phi + delta * 2 * math.pi * speed)
    self:_update_vertices()
    self._canvas_needs_update = true

    self._explosion_motion:update(delta)
end

function ow.DoubleJumpTetherParticle:draw(x, y, draw_shape, draw_core)
    local line_width = 2
    local r, g, b, a = love.graphics.getColor()

    if draw_core == true then
        local offset = math.mix(1, rt.settings.impulse_manager.max_brightness_factor, self._brightness_offset)
        love.graphics.push()
        love.graphics.translate(x, y)

        local black_r, black_g, black_b = rt.Palette.BLACK:unpack()
        love.graphics.setColor(black_r, black_g, black_b, a)
        self._core:draw()

        love.graphics.setColor(r * offset, g * offset, b * offset, a)
        self._core:draw()

        love.graphics.pop()
    end

    if draw_shape == true then
        local offset = math.mix(1, rt.settings.impulse_manager.max_brightness_factor, self._brightness_offset)
        love.graphics.push()
        love.graphics.setLineJoin("none")

        love.graphics.translate(x, y)

        local black_r, black_g, black_b = rt.Palette.BLACK:unpack()
        love.graphics.setColor(black_r, black_g, black_b, a)

        love.graphics.setLineWidth(math.mix(line_width, line_width * 1.5, self._brightness_offset) + 2)
        love.graphics.line(self._draw_line)

        love.graphics.push()
        love.graphics.scale(1.33, 1.33) -- core outline
        self._core:draw()
        love.graphics.pop()

        love.graphics.setLineWidth(math.mix(line_width, line_width * 1.5, self._brightness_offset))
        love.graphics.setColor(r * offset, g * offset, b * offset, a)
        love.graphics.line(self._draw_line)
        self._core:draw()

        for v in values(self._vertices) do
            love.graphics.circle("fill", v[1], v[2], 0.5 * line_width)
        end
        love.graphics.pop()
    end
end