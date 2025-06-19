--- @class ow.DoubleJumpParticle
ow.DoubleJumpParticle = meta.class("DoubleJumpParticle")

local _sqrt2 = math.sqrt(2)
local _sqrt3 = math.sqrt(3)
local _sqrt6 = math.sqrt(6)

local function _rotate(v, theta, phi)
    local cos_phi, sin_phi = math.cos(phi), math.sin(phi)
    local x1 = v.x * cos_phi + v.z * sin_phi
    local y1 = v.y
    local z1 = -v.x * sin_phi + v.z * cos_phi

    local cos_theta, sin_theta = math.cos(theta), math.sin(theta)
    local x2 = x1
    local y2 = y1 * cos_theta - z1 * sin_theta
    local z2 = y1 * sin_theta + z1 * cos_theta

    return {x = x2, y = y2, z = z2}
end

--- @brief
function ow.DoubleJumpParticle:instantiate(radius)
    self._theta, self._phi = 0, 0 -- Spherical rotation angles
    self._radius = radius
    self._x, self._y, self._z = 0.5 * radius, 0.5 * radius, 0.5 * radius
    self:_update_vertices()
end

--- @brief
function ow.DoubleJumpParticle:_update_vertices()
    local vertices = {
        {x =  1, y =  1, z =  1},
        {x = -1, y = -1, z =  1},
        {x = -1, y =  1, z = -1},
        {x =  1, y = -1, z = -1},
    }
    
    for v in values(vertices) do
        v.x = v.x / _sqrt3
        v.y = v.y / _sqrt3
        v.z = v.z / _sqrt3
    end

    -- Scale to desired radius
    for v in values(vertices) do
        v.x = v.x * self._radius
        v.y = v.y * self._radius
        v.z = v.z * self._radius
    end

    -- Apply spherical rotation
    local theta, phi = self._theta, self._phi
    for i, v in ipairs(vertices) do
        vertices[i] = _rotate(v, theta, phi)
    end

    -- Translate to center
    for v in values(vertices) do
        v.x = v.x + self._x
        v.y = v.y + self._y
        v.z = v.z + self._z
    end

    self._vertices = vertices
end

--- @brief
function ow.DoubleJumpParticle:update(delta)
    local speed = 0.5 -- radians per second
    self._theta = (self._theta + delta * 2 * math.pi * speed) % (2 * math.pi)
    self._phi = (self._phi + delta * 2 * math.pi * speed) % (2 * math.pi)
    self:_update_vertices()
end

local _edges = {
    {1, 2}, {1, 3}, {1, 4},
    {2, 3}, {2, 4},
    {3, 4}
}

function ow.DoubleJumpParticle:draw(x, y)
    -- Project 3D vertices to 2D (simple orthographic projection: ignore z)
    local verts = self._vertices
    if not verts then return end

    love.graphics.push()
    love.graphics.translate(x, y)

    local line_width = 3
    love.graphics.setLineWidth(line_width)

    -- Define the 6 edges of a tetrahedron by vertex indices (1-based)
    

    for _, edge in ipairs(_edges) do
        local v1 = verts[edge[1]]
        local v2 = verts[edge[2]]
        love.graphics.line(v1.x, v1.y, v2.x, v2.y)
    end

    for vertex in values(self._vertices) do
        love.graphics.circle("fill", vertex.x, vertex.y, line_width / 2)
    end

    love.graphics.pop()
end