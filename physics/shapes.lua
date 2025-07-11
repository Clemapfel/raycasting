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
        _x = x,
        _y = y,
        _width = width,
        _height = height
    })
end)

--- @brief
function b2.Rectangle:draw(mask_only)
    local x, y, w, h = self._x, self._y, self._width, self._height
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(r, g, b, _fill_a * a)
    love.graphics.rectangle("fill", x, y, w, h)

    if mask_only ~= true then
        love.graphics.setColor(r, g, b, _line_a * a)
        love.graphics.rectangle("line", x, y, w, h)
    end
end

--- @brief
function b2.Rectangle:_add_to_body(body)
    local x, y, w, h = self._x, self._y, self._width, self._height
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
        _x = x,
        _y = y,
        _radius = radius
    })
end)

--- @brief
function b2.Circle:get_radius()
    return self._radius
end

--- @brief
function b2.Circle:draw(mask_only)
    local x, y, radius = self._x, self._y, self._radius
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(r, g, b, _fill_a * a)
    love.graphics.circle("fill", x, y, radius)

    if mask_only ~= true then
        love.graphics.setColor(r, g, b, _line_a * a)
        love.graphics.circle("line", x, y, radius)
    end
end

--- @brief
function b2.Circle:_add_to_body(body)
    return love.physics.newCircleShape(body, self._x, self._y, self._radius)
end

--- @class b2.Polygon
--- @param vertices Table<Number>
b2.Polygon = meta.class("PhysicsPolygon", b2.Shape,function(self, vertices, ...)
    if meta.is_number(vertices) then
        vertices = {vertices, ...}
    end

    self._vertices = vertices
end)

--- @brief
function b2.Polygon:draw(mask_only)
    local vertices = self._vertices
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(r, g, b, _fill_a * a)
    love.graphics.polygon("fill", vertices)

    if mask_only ~= true then
        love.graphics.setColor(r, g, b, _line_a * a)
        love.graphics.polygon("line", vertices)
    end
end

--- @brief
function b2.Polygon:_add_to_body(body)
    local success, out = pcall(love.physics.newPolygonShape, body, self._vertices)
    if success == true then
        return out
    else
        return nil -- shape has volume of 0
    end
end

--- @class b2.Segment
--- @param vertices Table<Number>
b2.Segment = meta.class("PhysicsSegment", b2.Shape,function(self, vertices, ...)
    if meta.is_number(vertices) then
        vertices = {vertices, ...}
    end
    self._vertices = vertices
    self._is_one_sided = false
end)

--- @brief
function b2.Segment:set_is_one_sided(b)
    self._is_one_sided = b
end

--- @brief
function b2.Segment:_add_to_body(body)
    if self._is_one_sided then
        return love.physics.newChainShape(body, false, self._vertices)
    else
        return love.physics.newEdgeShape(body, table.unpack(self._vertices))
    end
end

--- @brief
function b2.Segment:draw(mask_only)
    love.graphics.line(self._vertices)
end
