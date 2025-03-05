--- @class b2.Shape
b2.Shape = meta.abstract_class("Shape")

--- @brief
function b2.Shape:_unpack()
    assert(self._native.arguments ~= nil)
    return table.unpack(self._native.arguments)
end

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
function b2.Rectangle:draw(offset_x, offset_y, angle)
    if offset_x == nil then offset_x = 0 end
    if offset_y == nil then offset_y = 0 end
    if angle == nil then angle = 0 end

    love.graphics.push()
    love.graphics.translate(offset_x, offset_y)
    love.graphics.rotate(angle)

    local x, y, w, h = self:_unpack()
    love.graphics.setColor(1, 1, 1, _fill_a)
    love.graphics.rectangle("fill", x, y, w, h)

    love.graphics.setColor(1, 1, 1, _line_a)
    love.graphics.rectangle("line", x, y, w, h)

    love.graphics.pop()
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
function b2.Circle:draw(offset_x, offset_y, angle)
    if offset_x == nil then offset_x = 0 end
    if offset_y == nil then offset_y = 0 end
    if angle == nil then angle = 0 end

    love.graphics.push()
    love.graphics.translate(offset_x, offset_y)
    love.graphics.rotate(angle)

    local x, y, r = self:_unpack()
    love.graphics.setColor(1, 1, 1, _fill_a)
    love.graphics.circle("fill", x, y, r)

    love.graphics.setColor(1, 1, 1, _line_a)
    love.graphics.circle("line", x, y, r)

    love.graphics.pop()
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
function b2.Polygon:draw(offset_x, offset_y, angle)
    if offset_x == nil then offset_x = 0 end
    if offset_y == nil then offset_y = 0 end
    if angle == nil then angle = 0 end

    love.graphics.push()
    love.graphics.translate(offset_x, offset_y)
    love.graphics.rotate(angle)

    love.graphics.setColor(1, 1, 1, _fill_a)
    love.graphics.polygon("fill", self._native.arguments)

    love.graphics.setColor(1, 1, 1, _line_a)
    love.graphics.polygon("line", self._native.arguments)
    love.graphics.pop()
end