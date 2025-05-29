require "common.shape"
require "common.blend_mode"

rt.settings.direction_indicator = {
    min_line_width = rt.settings.margin_unit,
    arrow_offset = 0 -- thickness factor
}

--- @class rt.Direction
rt.Direction = meta.enum("Direction", {
    UP = "up",
    RIGHT = "right",
    DOWN = "down",
    LEFT = "left",
    NONE = "none"
})

--- @class rt.DirectionIndicator
rt.DirectionIndicator = meta.class("DirectionIndicator", rt.Widget)

--- @brief
function rt.DirectionIndicator:instantiate(direction)
    if direction == nil then
        direction = rt.Direction.NONE
    end

    meta.install(self, {
        _direction = direction,
        _color = {},
        _ring = rt.Circle(),
        _ring_outline_outer = rt.Circle(),
        _ring_outline_inner = rt.Circle(),
        _arrow = rt.Polygon(),
        _arrow_outline = rt.LineLoop()
    })

    self:set_color(rt.Palette.FOREGROUND)

    self._ring:set_is_outline(true)
    self._ring_outline_inner:set_is_outline(true)
    self._ring_outline_outer:set_is_outline(true)

    self._ring:set_color(self._color)
    self._ring_outline_inner:set_color(rt.Palette.BASE_OUTLINE)
    self._ring_outline_outer:set_color(rt.Palette.BASE_OUTLINE)

    self._arrow:set_color(self._color)
    self._arrow_outline:set_color(rt.Palette.BASE_OUTLINE)
    return self
end

--- @overload rt.Drawable.draw
function rt.DirectionIndicator:draw()
    if not self:get_is_visible() then return end

    rt.graphics.set_blend_mode(rt.BlendMode.NORMAL, rt.BlendMode.MAX)
    if self._direction == rt.Direction.NONE then
        self._ring:draw()
        self._ring_outline_outer:draw()
        self._ring_outline_inner:draw()
    else
        self._arrow:draw()
        self._arrow_outline:draw()
    end
    rt.graphics.set_blend_mode()
end

--- @overload rt.Widget.size_allocate
function rt.DirectionIndicator:size_allocate(x, y, width, height)
    local center_x, center_y = x + 0.5 * width, y + 0.5 * height
    local radius = math.min(width, height) / 2
    local ring_thickness = 0.4 * radius
    local eps = 1
    if self._direction == rt.Direction.NONE then
        self._ring:resize(center_x, center_y, radius - 0.5 * ring_thickness)
        self._ring:set_line_width(ring_thickness)
        self._ring_outline_inner:resize(center_x, center_y, radius - ring_thickness)
        self._ring_outline_outer:resize(center_x, center_y, radius)
    else
        local thickness = math.max(radius / 2, rt.settings.direction_indicator.min_line_width)
        local vertices = {}

        if self._direction == rt.Direction.UP then
            vertices = {
                center_x, center_y - radius,
                center_x + radius, center_y,
                center_x + radius, center_y + thickness,
                center_x, center_y - radius + thickness,
                center_x - radius, center_y + thickness,
                center_x - radius, center_y
            }

            for i = 2, 12, 2 do
                vertices[i] = vertices[i] + rt.settings.direction_indicator.arrow_offset * thickness + (radius - thickness) * 0.5
            end
        elseif self._direction == rt.Direction.RIGHT then
            vertices = {
                center_x + radius, center_y,
                center_x, center_y + radius,
                center_x - thickness, center_y + radius,
                center_x + radius - thickness, center_y,
                center_x - thickness, center_y - radius,
                center_x, center_y - radius
            }

            for i = 1, 12, 2 do
                vertices[i] = vertices[i] - rt.settings.direction_indicator.arrow_offset * thickness
            end
        elseif self._direction == rt.Direction.DOWN then
            vertices = {
                center_x, center_y + radius - thickness,
                center_x + radius, center_y - thickness,
                center_x + radius, center_y,
                center_x, center_y + radius,
                center_x - radius, center_y,
                center_x - radius, center_y - thickness
            }

            for i = 2, 12, 2 do
                vertices[i] = vertices[i] - rt.settings.direction_indicator.arrow_offset * thickness - (radius - thickness) * 0.5
            end
        elseif self._direction == rt.Direction.LEFT then
            vertices = {
                center_x - radius + thickness, center_y,
                center_x + thickness, center_y + radius,
                center_x, center_y + radius,
                center_x - radius, center_y,
                center_x, center_y  - radius,
                center_x + thickness, center_y - radius
            }

            for i = 1, 12, 2 do
                vertices[i] = vertices[i] + rt.settings.direction_indicator.arrow_offset * thickness
            end
        end

        for i = 1, #vertices do
            vertices[i] = math.round(vertices[i])
        end

        self._arrow:reformat(vertices)
        self._arrow_outline:reformat(vertices)
    end
end

--- @brief
function rt.DirectionIndicator:set_direction(direction)
    if self._direction ~= direction then
        self._direction = direction
        self:reformat()
    end
end

--- @brief
function rt.DirectionIndicator:get_direction()
    return self._direction
end

--- @brief
function rt.DirectionIndicator:set_color(color)
    meta.assert(color, rt.RGBA)
    self._color = color
    self._arrow:set_color(self._color)
    self._ring:set_color(self._color)
end

--- @brief
function rt.DirectionIndicator:get_color()
    return self._color
end

--- @brief
function rt.DirectionIndicator:set_opacity(alpha)
    self._opacity = alpha
    self._ring:set_opacity(alpha)
    self._ring_outline_outer:set_opacity(alpha)
    self._ring_outline_inner:set_opacity(alpha)
    self._arrow:set_opacity(alpha)
    self._arrow_outline:set_opacity(alpha)
end