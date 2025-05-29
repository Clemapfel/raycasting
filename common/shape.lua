require "common.color"

local _unpack = table.unpack

--- @class rt.Shape
rt.Shape = meta.abstract_class("Shape")

--- @brief
function rt.Shape:set_color(color_or_r, g, b, a)
    if meta.isa(color_or_r, rt.Color) then
        self._color = { color_or_r:unpack() }
    else
        self._color = { color_or_r, g, b, a }
    end
end

--- @brief
function rt.Shape:set_line_width(v)
    self._line_width = v
end

-- ### RECTANGLE ###

--- @class rt.Rectangle
rt.Rectangle = meta.class("Rectangle", rt.Shape)

--- @brief
function rt.Rectangle:instantiate(x, y, w, h, corner_radius)
    if x == nil then
        x, y, w, h, corner_radius = 0, 0, 1, 1, 0
    elseif corner_radius == nil then
        corner_radius = 0
    end

    self._data = { x, y, w, h, corner_radius }
end

--- @brief
function rt.Rectangle:set_corner_radius(v)
    self._data[5] = v
end

--- @brief
function rt.Rectangle:reformat(x, y, w, h, corner_radius)
    if corner_radius == nil then corner_radius =  self._data[5] end

    self._data = { x, y, w, h, corner_radius }
end

--- @brief
function rt.Rectangle:set_is_outline(b)
    self._mode = b and "line" or "fill"
end

--- @brief
function rt.Rectangle:get_is_outline()
    return self._mode == "line"
end

--- @brief
function rt.Rectangle:draw()
    if self._color ~= nil then
        love.graphics.setColor(_unpack(self._color))
    end

    if self._line_width ~= nil and self._mode == "line" then
        love.graphics.setLineWidth(self._line_width)
    end

    love.graphics.rectangle(self._mode or "fill", _unpack(self._data))
end

--- ### ELLIPSE ###

--- @class rt.Ellipse
rt.Ellipse = meta.class("Ellipse", rt.Shape)

--- @brief
function rt.Ellipse:instantiate(x, y, x_radius, y_radius)
    if x == nil then
        x, y, x_radius, y_radius = 0, 0, 1, 1
    elseif y_radius == nil then
        y_radius = x_radius
    end

    self._data = { x, y, x_radius, y_radius }
end

--- @brief
function rt.Circle(x, y, radius)
    return rt.Ellipse(x, y, radius, radius)
end

--- @brief
function rt.Ellipse:set_is_outline(b)
    self._mode = b and "line" or "fill"
end

--- @brief
function rt.Ellipse:get_is_outline()
    return self._mode == "line"
end

--- @brief
function rt.Ellipse:reformat(x, y, x_radius, y_radius)
    if y_radius == nil then y_radius = x_radius end
    self._data = { x, y, x_radius, y_radius }
end

--- @brief
function rt.Ellipse:draw()
    if self._color ~= nil then
        love.graphics.setColor(_unpack(self._color))
    end

    if self._line_width ~= nil and self._mode == "line" then
        love.graphics.setLineWidth(self._line_width)
    end

    love.graphics.ellipse(self._mode or "fill", _unpack(self._data))
end

--- ### POLYGON ###

--- @class rt.Polygon
rt.Polygon = meta.class("Polygon", rt.Shape)

--- @brief
function rt.Polygon:instantiate(...)
    local n = select("#", ...)
    if n == 0 then
        self._data = { 0, 0, 1, 0, 0.5, 1 }
    elseif n == 1 then
        self._data = ...
    else
        self._data = { ... }
    end
end

--- @brief
function rt.Polygon:set_is_outline(b)
    self._mode = b and "line" or "fill"
end

--- @brief
function rt.Polygon:get_is_outline()
    return self._mode == "line"
end

--- @brief
function rt.Polygon:reformat(...)
    if select("#", ...) == 1 then
        self._data = ...
    else
        self._data = { ... }
    end
end

--- @brief
function rt.Polygon:draw()
    if self._color ~= nil then
        love.graphics.setColor(_unpack(self._color))
    end

    if self._line_width ~= nil and self._mode == "line" then
        love.graphics.setLineWidth(self._line_width)
    end

    love.graphics.polygon(self._mode or "fill", self._data)
end

--- ### LINE ###

--- @class rt.LineJoin
rt.LineJoin = meta.enum("LineJoin", {
    MITER = "miter",
    NONE = "none",
    BEVEL = "bevel"
})

--- @class rt.Line
rt.Line = meta.class("Line", rt.Shape)

--- @brief
function rt.Line:instantiate(...)
    local n = select("#", ...)
    if n == 0 then
        self._data = { 0, 0, 1, 1 }
    elseif n == 1 then
        self._data = ...
    else
        self._data = { ... }
    end
end

--- @brief
function rt.Line:reformat(...)
    if select("#", ...) == 1 then
        self._data = ...
    else
        self._data = { ... }
    end
end

--- @brief
function rt.Line:set_line_join(line_join)
    self._line_join = line_join
end

--- @brief
function rt.Line:draw()
    if self._color ~= nil then
        love.graphics.setColor(_unpack(self._color))
    end

    if self._line_width ~= nil then
        love.graphics.setLineWidth(self._line_width)
    end

    if self._line_join ~= nil then
        love.graphics.setLineJoin(self._line_join)
    end

    love.graphics.line(self._data)
end
