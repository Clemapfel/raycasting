--- @class ow.CoinParticle
ow.CoinParticle = meta.class("CoinParticle")

--- @brief
function ow.CoinParticle:instantiate(radius)
    self._radius = radius
    self._theta, self._phi = 0, 0
    self._elapsed = 0

    self._contour = {}
    self:update(0) -- generate vertices
end

--- @brief Generate the ring contour for a latitude circle at given z offset
function ow.CoinParticle:_generate_contour(theta, phi, offset)
    local vertices = {}

    -- Clamp offset to [-1, 1]
    if offset > 1 then offset = 1 elseif offset < -1 then offset = -1 end

    -- The plane is always parallel to the xy-plane, normal (0,0,1)
    local nz = 1
    local d = nz * offset

    if math.abs(d) > 1 then
        return vertices
    end

    -- Circle center
    local cx, cy, cz = 0, 0, d

    -- Circle radius
    local r = math.sqrt(1 - d * d)

    -- u = (1,0,0), v = (0,1,0) for xy-plane
    local ux, uy, uz = 1, 0, 0
    local vx, vy, vz = 0, 1, 0

    -- Generate points along the circle
    for i = 1, 64 do
        local angle = 2 * math.pi * (i - 1) / 64
        local x = cx + r * (math.cos(angle) * ux + math.sin(angle) * vx)
        local y = cy + r * (math.cos(angle) * uy + math.sin(angle) * vy)
        -- Optionally, apply rotation for globe effect
        -- Rotate around z by self._theta, around x by self._phi
        local z = cz + r * (math.cos(angle) * uz + math.sin(angle) * vz)

        -- Rotate by theta (around z)
        local xt = x * math.cos(theta) - y * math.sin(theta)
        local yt = x * math.sin(theta) + y * math.cos(theta)
        local zt = z

        -- Rotate by phi (around x)
        local yt2 = yt * math.cos(phi) - zt * math.sin(phi)
        local zt2 = yt * math.sin(phi) + zt * math.cos(phi)
        local xt2 = xt

        table.insert(vertices, xt2 * self._radius)
        table.insert(vertices, yt2 * self._radius)
    end

    -- Close the loop
    table.insert(vertices, vertices[1])
    table.insert(vertices, vertices[2])

    return vertices
end

--- @brief
function ow.CoinParticle:update(delta)
    local speed = 0.5 -- radians per second
    self._elapsed = self._elapsed + delta

    self._phi = self._phi + speed * delta
    local n_latitudes = 14 -- number of latitude lines (including poles)
    self._contours = {}

    for i = 0, n_latitudes do
        -- Evenly spaced offsets from -1 (south pole) to 1 (north pole)
        local offset = -1 + 2 * (i / (n_latitudes - 1))
        local contour =
        table.insert(self._contours, self:_generate_contour(self._theta, self._phi, offset))
        table.insert(self._contours, self:_generate_contour(self._theta + 0.25 * math.pi, self._phi + 0.5 * math.pi, offset))

    end
end

function ow.CoinParticle:draw(x, y, is_collected)
    love.graphics.push()
    love.graphics.translate(x, y)
    for contour in values(self._contours) do
        love.graphics.line(contour)
    end
    love.graphics.pop()
end