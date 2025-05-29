require "common.input_manager"
require "common.shape"

--- @class mn.DeadzoneVisualizationWidget
mn.DeadzoneVisualizationWidget = meta.class("DeadzoneVisualizationWidget", rt.Widget)

function mn.DeadzoneVisualizationWidget:instantiate()
    meta.install(self, {
        _inner_shape = rt.Circle(),
        _inner_shape_outline = rt.Circle(),
        _outer_shape = rt.Circle(),
        _outer_shape_outline = rt.Circle(),
        _last_deadzone = rt.GameState:get_joystick_deadzone()
    })
end

--- @override
function mn.DeadzoneVisualizationWidget:realize()
    if self:already_realized() then return end
    self._outer_shape:set_color(rt.Palette.FOREGROUND_OUTLINE)
    self._inner_shape:set_color(rt.Palette.FOREGROUND)

    for outline in range(self._outer_shape_outline, self._inner_shape_outline) do
        outline:set_is_outline(true)
        outline:set_color(rt.Palette.BLACK)
    end
end

--- @override
function mn.DeadzoneVisualizationWidget:size_allocate(x, y, width, height)
    local center_x, center_y = x + 0.5 * width, y + 0.5 * height
    local deadzone = self._last_deadzone
    local outer_r = (math.min(width, height) - 4 * rt.settings.margin_unit) / 2
    self._inner_shape:reformat(center_x, center_y, deadzone * outer_r)
    self._inner_shape_outline:reformat(center_x, center_y, deadzone * outer_r)

    self._outer_shape:reformat(center_x, center_y, outer_r)
    self._outer_shape_outline:reformat(center_x, center_y, outer_r)
end

--- @override
function mn.DeadzoneVisualizationWidget:draw()
    love.graphics.setLineWidth(1)
    self._outer_shape:draw()
    self._outer_shape_outline:draw()
    self._inner_shape:draw()
    self._inner_shape_outline:draw()
end

--- @override
function mn.DeadzoneVisualizationWidget:update(delta)
    if rt.GameState:get_joystick_deadzone() ~= self._last_deadzone then
        self._last_deadzone = rt.GameState:get_joystick_deadzone()
        self:reformat()
    end
end