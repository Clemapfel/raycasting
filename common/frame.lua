require "common.widget"
require "common.palette"
require "common.aabb"
require "common.stencil"

rt.settings.frame = {
    thickness = 2, -- px
    corner_radius = 10,
    selected_base_color = (function()
        local a = rt.Palette.GRAY_7
        local b = rt.Palette.BACKGROUND
        local weight = 0.25
        return rt.RGBA(
            math.mix(a.r, b.r, weight),
            math.mix(a.g, b.g, weight),
            math.mix(a.b, b.b, weight),
            math.max(a.a, b.a)
        )
    end)(),

    bloom_strength = 0.25,
    default_color = rt.Palette.GRAY_4
}

--- @class rt.Frame
rt.Frame = meta.class("Frame", rt.Widget)

--- @brief
function rt.Frame:instantiate()
    meta.install(self, {
        _child = {},
        _child_valid = false,

        _aabb = rt.AABB(0, 0, 1, 1),

        _color = rt.settings.frame.default_color,
        _stencil_color = rt.Palette.BACKGROUND,
        _stencil_color_override = nil,

        _frame_color = rt.settings.frame.default_color,
        _outline_color = rt.Palette.BASE_OUTLINE,

        _thickness = rt.settings.frame.thickness,
        _corner_radius = rt.settings.frame.corner_radius,
        _selection_state = rt.SelectionState.INACTIVE
    })
end

--- @brief
function rt.Frame:_get_effective_thickness()
    return self._thickness * rt.get_pixel_scale() + ternary(
        self._selection_state == rt.SelectionState.ACTIVE,
        2,
        0
    )
end

--- @brief
function rt.Frame:draw()
    local x, y, w, h = self._bounds:unpack()
    local stencil_r, stencil_g, stencil_b, stencil_a = (self._stencil_color_override or self._stencil_color):unpack()
    local frame_r, frame_g, frame_b = self._frame_color:unpack()
    local outline_r, outline_g, outline_b = self._outline_color:unpack()

    local opacity = self._opacity
    local thickness = self:_get_effective_thickness()
    local corner_radius = self._corner_radius

    love.graphics.setLineWidth(thickness + 2)
    love.graphics.setLineStyle("smooth")
    love.graphics.setColor(stencil_r, stencil_g, stencil_b, opacity * stencil_a)

    love.graphics.rectangle(
        "fill",
        x, y, w, h,
        corner_radius, corner_radius
    )

    love.graphics.setColor(outline_r, outline_g, outline_b, opacity)
    love.graphics.rectangle(
        "line",
        x, y, w, h,
        corner_radius, corner_radius
    )

    love.graphics.setLineWidth(thickness)
    love.graphics.setColor(frame_r, frame_g, frame_b, opacity)
    love.graphics.rectangle(
        "line",
        x, y, w, h,
        corner_radius, corner_radius
    )
end

--- @brief
function rt.Frame:draw_bloom()
    local x, y, w, h = self._bounds:unpack()
    local frame_r, frame_g, frame_b = self._frame_color:unpack()

    local strength = rt.settings.frame.bloom_strength

    love.graphics.setLineStyle("smooth")
    love.graphics.setLineWidth(self:_get_effective_thickness())
    love.graphics.setColor(
        frame_r * strength,
        frame_g * strength,
        frame_b * strength,
        self._opacity
    )

    love.graphics.rectangle(
        "line",
        x, y, w, h,
        self._corner_radius, self._corner_radius
    )
end

--- @brief
function rt.Frame:bind_stencil()
    local stencil_value = rt.graphics.get_stencil_value()
    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW)
    local x, y, w, h = self._bounds:unpack()
    local corner_radius = self._corner_radius
    local thickness = self._thickness * rt.get_pixel_scale()
    love.graphics.rectangle(
        "fill",
        x + thickness, y + thickness, w - 2 * thickness, h - 2 * thickness,
        corner_radius, corner_radius
    )
    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST)
end

function rt.Frame:unbind_stencil()
    rt.graphics.set_stencil_mode(nil)
end

--- @override rt.Widget.realize
function rt.Frame:realize()
    if self:already_realized() then return end
    if meta.isa(self._child, rt.Widget) then
        self._child:realize()
    end
    rt.Widget.realize(self)
end

--- @override
function rt.Frame:size_allocate(x, y, w, h)
    self._aabb = rt.AABB(x, y, w, h)
end

--- @brief
function rt.Frame:set_color(color, g, b, a)
    if meta.is_number(color) then
        color = rt.RGBA(color, g, b, a)
    else
        meta.assert(color, rt.RGBA)
    end

    self._frame_color = color
end

--- @brief
function rt.Frame:set_base_color(color, g, b, a)
    if meta.is_number(color) then color = rt.RGBA(color, g, b, a) end
    self._stencil_color_override = color
end

--- @brief
function rt.Frame:set_thickness(thickness)
    if thickness < 0 then
        rt.error("In rt.Frame.set_thickness: value `", tostring(thickness), "` is out of range")
        return
    end

    if self._thickness ~= thickness then
        self._thickness = thickness
    end
end

--- @brief
function rt.Frame:get_thickness()
    return self._thickness
end

--- @brief
function rt.Frame:set_corner_radius(radius)
    if radius < 0 then
        rt.error("In rt.Frame.set_corner_radius: value `", radius, "` is out of range")
        return
    end
    self._corner_radius = radius
end

--- @brief
function rt.Frame:get_corner_radius()
    return self._corner_radius
end

--- @override rt.Widget.measure
function rt.Frame:measure()
    if meta.is_widget(self._child) then
        local w, h = self._child:measure()
        w = math.max(w, select(1, self:get_minimum_size()))
        h = math.max(h, select(2, self:get_minimum_size()))
        return w + self._thickness * rt.graphics.get_pixel_scale() * 2,
            h + self._thickness * rt.graphics.get_pixel_scale() * 2
    else
        return rt.Widget.measure(self)
    end
end

--- @override
function rt.Frame:set_opacity(alpha)
    self._opacity = alpha
end

--- @brief
function rt.Frame:set_selection_state(selection_state)
    self._selection_state = selection_state
    if self._selection_state == rt.SelectionState.INACTIVE then
        self._stencil_color = rt.Palette.BACKGROUND
        self._frame_color = self._color
        self._opacity = 1
    elseif self._selection_state == rt.SelectionState.ACTIVE then
        self._frame_color = rt.Palette.SELECTION
        self._stencil_color = rt.settings.frame.selected_base_color
        self._opacity = 1
    elseif self._selection_state == rt.SelectionState.UNSELECTED then
        self._stencil_color = rt.Palette.BACKGROUND
        self._frame_color = self._color
        self._opacity = 0.5
    end
end

--- @brief
function rt.Frame:set_use_bloom(b)
    self._use_bloom = b
end

--- @brief
function rt.Frame:get_selection_state()
    return self._selection_state
end

--- @brief
function rt.Frame:set_is_animated(b)
    self._is_animated = b
end