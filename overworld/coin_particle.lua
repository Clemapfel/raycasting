require "common.timed_animation"

--- @class ow.CoinParticle
ow.CoinParticle = meta.class("CoinParticle")

--- @brief
function ow.CoinParticle:instantiate(radius)
    self._radius = radius
    self._theta, self._phi = 0, 0
    self._elapsed = 0

    self._contour = nil
    self:update(0) -- generate vertices
end

--- @brief Generate the ring contour for a latitude circle at given z offset
function ow.CoinParticle:_generate_contour(theta, phi, offset)
    local vertices = {}

    local n_points = 16

    -- Compute normal vector n
    local nx = math.sin(theta) * math.cos(phi)
    local ny = math.sin(theta) * math.sin(phi)
    local nz = math.cos(theta)

    -- Find two orthogonal vectors u, v perpendicular to n
    -- Pick an arbitrary vector not parallel to n
    local ax, ay, az = 0, 0, 1
    if math.abs(nz) > 0.999 then
        ax, ay, az = 1, 0, 0
    end

    -- u = n x a (cross product)
    local ux = ny * az - nz * ay
    local uy = nz * ax - nx * az
    local uz = nx * ay - ny * ax
    local u_length = math.sqrt(ux*ux + uy*uy + uz*uz)
    ux, uy, uz = ux/u_length, uy/u_length, uz/u_length

    -- v = n x u
    local vx = ny * uz - nz * uy
    local vy = nz * ux - nx * uz
    local vz = nx * uy - ny * ux
    local v_length = math.sqrt(vx*vx + vy*vy + vz*vz)
    vx, vy, vz = vx/v_length, vy/v_length, vz/v_length

    -- Generate points along the great circle
    for i = 1, n_points do
        local angle = 2 * math.pi * (i-1) / n_points
        local x = math.cos(angle) * ux + math.sin(angle) * vx
        local y = math.cos(angle) * uy + math.sin(angle) * vy
        local z = math.cos(angle) * uz + math.sin(angle) * vz
        table.insert(vertices, x * self._radius)
        table.insert(vertices, y * self._radius)
    end

    table.insert(vertices, vertices[1])
    table.insert(vertices, vertices[2])

    return vertices
end

--- @brief
function ow.CoinParticle:update(delta)
    self._elapsed = self._elapsed + delta
    self._theta = self._elapsed * 0.05 * 2 * math.pi
    self._phi = self._elapsed * 0.025 * 2 * math.pi


    self._contour = self:_generate_contour(
        self._theta,
        self._phi
    )
end

function ow.CoinParticle:draw(x, y, is_collected)
    local r, g, b, a = love.graphics.getColor()
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.setLineWidth(8)
    love.graphics.setLineJoin("bevel")
    love.graphics.setColor(r, g, b, 1 * a)
    love.graphics.line(self._contour)
    love.graphics.setColor(r, g, b, 0.4 * a)
    love.graphics.polygon("fill", self._contour)
    love.graphics.pop()
end