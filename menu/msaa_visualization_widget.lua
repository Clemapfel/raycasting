require "common.frame"
require "common.shape"

--- @class mn.MSAAVisualizationWidget
mn.MSAAVisualizationWidget = meta.class("MSAAVisualizationWidget", rt.Widget)

--- @brief
function mn.MSAAVisualizationWidget:instantiate()
    return meta.install(self, {
        _line = rt.Line(),
        _line_radius_x = 1,
        _line_radius_y = 1,
        _line_center_x = 0,
        _line_center_y = 0,
        _background = rt.Rectangle(),
        _background_outline = rt.Rectangle(),
        _elapsed = 0,
        _duration = 15, -- in seconds, on full rotation
    })
end

--- @override
function mn.MSAAVisualizationWidget:realize()
    if self:already_realized() then return end

    self._background:set_color(rt.Palette.WHITE)
    self._background:set_is_outline(false)
    self._background_outline:set_color(rt.Palette.BLACK)
    self._background_outline:set_is_outline(true)

    self._line:set_color(rt.Palette.BLACK)
    self._line:set_line_join(rt.LineJoin.MITER)
end

--- @override
function mn.MSAAVisualizationWidget:size_allocate(x, y, width, height)
    local w, h = 0.8 * width, 0.8 * height
    for shape in range(
        self._background,
        self._background_outline
    ) do
        shape:reformat(x + 0.5 * width - 0.5 * w, y + 0.5 * height - 0.5 * h, w, h)
        shape:set_corner_radius(rt.settings.frame.corner_radius)
    end

    self._line:set_line_width(5 * rt.get_pixel_scale())

    local rx, ry = 0.3 * w, 0.3 * h
    self._line_radius_x = rx
    self._line_radius_y = ry
    self._line_center_x = x + 0.5 * width
    self._line_center_y =  y + 0.5 * height
    self:update(0)
end

--- @override
function mn.MSAAVisualizationWidget:update(delta)
    self._elapsed = math.fmod(self._elapsed + delta, self._duration)

    local n_vertices = 5
    local points = {}
    local angle_step = 2 * math.pi / n_vertices

    local center_x, center_y = self._line_center_x, self._line_center_y
    local radius_x, radius_y = self._line_radius_x, self._line_radius_y

    local angle_offset = self._elapsed / self._duration * 2 * math.pi
    for i = 0, n_vertices - 1 do
        local angle = i * angle_step + angle_offset
        local x = center_x + radius_x * math.cos(angle)
        local y = center_y + radius_y * math.sin(angle)
        table.insert(points, x)
        table.insert(points, y)
    end

    table.insert(points, points[1])
    table.insert(points, points[2])

    self._line:reformat(points)
end

--- @override
function mn.MSAAVisualizationWidget:draw()
    self._background:draw()
    self._background_outline:draw()
    self._line:draw()
end