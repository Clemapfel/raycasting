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
        table.insert(self._segments, {
            radius = r,
            x = current_x,
            y = current_y
        })

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
    local _sin, _cos = math.sin, math.cos
    local segments = self._segments

    local vertices = {}
    local step = (2 * math.pi) / 8

    local function check(x, y, i)
        local left = segments[i - 1]
        local left_allowed = true
        if left ~= nil then
            left_allowed = math.distance(x, y, left.x, left.y) >= left.radius
        end

        local right = segments[i + 1]
        local right_allowed = true
        if right ~= nil then
            right_allowed = math.distance(x, y, right.x, right.y) >= right.radius
        end

        return left_allowed and right_allowed
    end

    local x_sum, y_sum, n = 0, 0, 0
    for i, segment in ipairs(segments) do
        for angle = 0, 2 * math.pi + step, step do
            local x = segment.x + _cos(angle) * segment.radius
            local y = segment.y + _sin(angle) * segment.radius

            if check(x, y, i) then
                table.insert(vertices, { x, y })
                x_sum = x_sum + x
                y_sum = y_sum + y
                n = n + 1
            end
        end
    end

    local mean_x, mean_y = x_sum / n, y_sum / n


    self._vertices = slick.polygonize({vertices})
end

--- @brief
function ow.PlayerBody:draw()
    for polygon in values(self._vertices) do
        love.graphics.polygon("line", polygon)
    end
end