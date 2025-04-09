--- @class b2.Shape
b2.Shape = meta.abstract_class("Shape")

local _fill_a = 0.4
local _line_a = 1

--- @class b2.Rectangle
--- @param x Number
--- @param y Number
--- @param width Number
--- @param height Number
b2.Rectangle = meta.class("PhysicsRectangle", b2.Shape, function(self, x, y, width, height)
    meta.install(self, {
        _native = slick.newRectangleShape(x, y, width, height)
    })
end)

--- @brief
function b2.Rectangle:draw()
    local x, y, w, h = table.unpack(self._native.arguments)
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(r, g, b, _fill_a * a)
    love.graphics.rectangle("fill", x, y, w, h)

    love.graphics.setColor(r, g, b, _line_a * a)
    love.graphics.rectangle("line", x, y, w, h)
end

--- @brief
function b2.Rectangle:_add_to_body(body)
    local x, y, w, h = table.unpack(self._native.arguments)
    return love.physics.newPolygonShape(body, {
        x, y,
        x + w, y,
        x + w, y + h,
        x, y + h
    })
end

--- @class b2.Circle
--- @param x Number
--- @param y Number
--- @param radius Number
b2.Circle = meta.class("PhysicsCircle", b2.Shape,function(self, x, y, radius)
    meta.install(self, {
        _native = slick.newCircleShape(x, y, radius)
    })
end)

--- @brief
function b2.Circle:get_radius()
    return self._native.arguments[3]
end

--- @brief
function b2.Circle:draw()
    local x, y, radius = table.unpack(self._native.arguments)
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(r, g, b, _fill_a * a)
    love.graphics.circle("fill", x, y, radius)

    love.graphics.setColor(r, g, b, _line_a * a)
    love.graphics.circle("line", x, y, radius)
end

--- @brief
function b2.Circle:_add_to_body(body)
    return love.physics.newCircleShape(body, table.unpack(self._native.arguments))
end

--- @class b2.Polygon
--- @param vertices Table<Number>
b2.Polygon = meta.class("PhysicsPolygon", b2.Shape,function(self, vertices, ...)
    if meta.is_number(vertices) then
        vertices = {vertices, ...}
    end

    self._native = slick.newPolygonShape(vertices)
end)

--- @brief
function b2.Polygon:draw()
    local vertices = self._native.arguments
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(r, g, b, _fill_a * a)
    love.graphics.polygon("fill", vertices)

    love.graphics.setColor(r, g, b, _line_a * a)
    love.graphics.polygon("line", vertices)
end

--- @brief
function b2.Polygon:_add_to_body(body)
    return love.physics.newPolygonShape(body, self._native.arguments)
end