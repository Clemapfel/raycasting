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

local _identity_transform = slick.newTransform()

local _bind_transform = function(transform)
    if transform == nil then return end
    love.graphics.push()
    love.graphics.translate(transform.x or 0, transform.y or 0)
    love.graphics.rotate(transform.rotation or 0)
    love.graphics.scale(transform.scaleX or 1, transform.scaleY or 1)
end

local _unbind_transform = function(transform)
    if transform == nil then return end
    love.graphics.pop()
end

--- @brief
function b2.Rectangle:draw(transform)
    _bind_transform(transform)

    local x, y, w, h = table.unpack(self._native.arguments)
    love.graphics.setColor(1, 1, 1, _fill_a)
    love.graphics.rectangle("fill", x, y, w, h)

    love.graphics.setColor(1, 1, 1, _line_a)
    love.graphics.rectangle("line", x, y, w, h)

    _unbind_transform(transform)
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
function b2.Circle:draw(transform)
    _bind_transform(transform)

    local x, y, r = table.unpack(self._native.arguments)
    love.graphics.setColor(1, 1, 1, _fill_a)
    love.graphics.circle("fill", x, y, r)

    love.graphics.setColor(1, 1, 1, _line_a)
    love.graphics.circle("line", x, y, r)

    _unbind_transform(transform)
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
function b2.Polygon:draw(transform)
    _bind_transform(transform)

    local vertices = self._native.arguments
    love.graphics.setColor(1, 1, 1, _fill_a)
    love.graphics.polygon("fill", vertices)

    love.graphics.setColor(1, 1, 1, _line_a)
    love.graphics.polygon("line", vertices)

    _unbind_transform(transform)
end