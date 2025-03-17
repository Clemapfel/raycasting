local slick = require "physics.slick.slick"

--- @class ow.PlayerBody
ow.PlayerBody = meta.class("PlayerBody", rt.Drawable)

--- @brief
function ow.PlayerBody:instantiate(world, radius, x, y)

    meta.install(self, {
        _anchor_x = x,
        _anchor_y = y,
        _radius = radius,
        _segments = {},
        _vertices = {}
    })

    local radius_factor = {1.35, 1.4, 1.2, 0.9}
    local current_x, current_y = self._anchor_x, self._anchor_y
    for i = 1, 4 do
        local r = radius * radius_factor[i]
        local segment = {
            radius = r,
            x = current_x,
            y = current_y
        }
        table.insert(self._segments, segment)
        current_x = current_x - r
    end

    self:update(0)
end

--- @brief
function ow.PlayerBody:set_position(x, y)
    self._anchor_x = x
    self._anchor_y = y
end


function ow.PlayerBody:update(delta)

    -- regenerat mesh
    local to_clip = {}
    local n_outer_vertices = 14
    local step = (2 * math.pi) / n_outer_vertices
    for segment in values(self._segments) do
        local vertices = {}
        for angle = 0, 2 * math.pi + 2 * step, step do
            local cx = segment.x + math.cos(angle) * segment.radius
            local cy = segment.y + math.sin(angle) * segment.radius

            table.insert(vertices, cx)
            table.insert(vertices, cy)
        end

        table.insert(to_clip, slick.polygonize({vertices}))
    end

    self._vertices = slick.clip(
        slick.newUnionClipOperation(
            slick.newUnionClipOperation(to_clip[1], to_clip[2]),
            slick.newUnionClipOperation(to_clip[3], to_clip[4])
        )
    )

    local points = {}
    local mean_x, mean_y, n = 0, 0, 0
    for tri in values(self._vertices) do
        for i = 1, #tri, 2 do
            local x, y = tri[i+0], tri[i+1]
            table.insert(points, {x, y})
            mean_x = mean_x + x
            mean_y = mean_y + y
            n = n + 1
        end
    end


    mean_x = mean_x / n
    mean_y = mean_y / n
    table.sort(points, function(a, b)
        local a_angle = (math.angle(a[1] - mean_x, a[2] - mean_y) + math.pi) % (2 * math.pi)
        local b_angle = (math.angle(b[1] - mean_x, b[2] - mean_y) + math.pi) % (2 * math.pi)
        return a_angle < b_angle
    end)

    self._contour = {}
    for point in values(points) do
        table.insert(self._contour, point[1])
        table.insert(self._contour, point[2])
    end

    local triangulator = slick.geometry.triangulation.delaunay.new()
    --triangulator:clean(self._contour)

    table.insert(self._contour, self._contour[1])
    table.insert(self._contour, self._contour[2])
end

--- @brief
function ow.PlayerBody:draw()
    love.graphics.setWireframe(false)
    for tri in values(self._vertices) do
        --love.graphics.polygon("fill", tri)
    end

    love.graphics.line(self._contour)
    love.graphics.setWireframe(false)
end