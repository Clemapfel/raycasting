require "common.player_body"
require "common.smoothed_motion_1d"

--- @class mn.StageSelectPageIndicator
mn.StageSelectPageIndicator = meta.class("StageSelectPageIndicator", rt.Widget)

--- @brief
function mn.StageSelectPageIndicator:instantiate(n_pages)
    meta.assert(n_pages, "Number")
    self._top_tri = {}
    self._bottom_tri = {}
    self._circles = {}
    self._n_pages = n_pages

    self._selection_x = 0
    self._selection_y = 0
    self._selection_radius = 1
    self._selected_page_i = 1

    self._motion = rt.SmoothedMotion1D(0, 2 * rt.get_pixel_scale())

    self._r = 1
    self._g = 1
    self._b = 1
    self._a = 1
    self._darken = rt.settings.player_body.outline_value_offset
    self._y_offset = 0

end

--- @brief
function mn.StageSelectPageIndicator:set_n_pages(n)
    self._n_pages = n

    if self:get_is_realized() then
        self:reformat()
    end
end

--- @brief
function mn.StageSelectPageIndicator:set_selected_page(i)
    self._selected_page_i = i
    self._motion:set_target_value(self._circles[i][2])
end

--- @brief
function mn.StageSelectPageIndicator:update(delta)
    self._selection_y = self._motion:update(delta)
end

--- @brief
function mn.StageSelectPageIndicator:size_allocate(x, y, width, height)
    local radius = width / 2
    local m = rt.settings.margin_unit

    self._selection_x = x + 0.5 * radius
    self._selection_radius = radius

    local current_x, current_y = x + 0.5 * radius, y + 0.5 * radius
    self._top_tri = {
        current_x, current_y - radius,
        current_x - radius * math.sqrt(3) / 2, current_y + radius / 2,
        current_x + radius * math.sqrt(3) / 2, current_y + radius / 2
    }

    current_y = current_y + 2 * radius + m

    self._circles = {}
    for i = 1, self._n_pages do
        table.insert(self._circles, { current_x, current_y, radius })
        current_y = current_y + 2 * radius + m
    end

    self._bottom_tri = {
        current_x, current_y + radius,
        current_x - radius * math.sqrt(3) / 2, current_y - radius / 2,
        current_x + radius * math.sqrt(3) / 2, current_y - radius / 2
    }

    local total_h = (2 + self._n_pages) * 2 * radius + (2 + self._n_pages - 1) * m
    self._y_offset = (height - total_h) / 2

    self:set_selected_page(self._selected_page_i)
    self._motion:skip()
end

--- @brief
function mn.StageSelectPageIndicator:draw()
    local dark_r, dark_g, dark_b = self._r - self._darken, self._g - self._darken, self._b - self._darken
    local r, g, b = self._r, self._g, self._b

    love.graphics.push()
    love.graphics.translate(0, self._y_offset)

    -- tris
    if self._selected_page_i > 1 then
        love.graphics.setColor(r, g, b)
    else
        love.graphics.setColor(dark_r, dark_g, dark_b)
    end
    love.graphics.polygon("fill", self._top_tri)

    if self._selected_page_i < self._n_pages then
        love.graphics.setColor(r, g, b)
    else
        love.graphics.setColor(dark_r, dark_g, dark_b)
    end
    love.graphics.polygon("fill", self._bottom_tri)

    -- circle base
    love.graphics.setColor(dark_r, dark_g, dark_b)
    for circle in values(self._circles) do
        love.graphics.circle("fill", table.unpack(circle))
    end

    -- outlines
    love.graphics.setLineWidth(rt.settings.player_body.outline_width)
    local black_r, black_g, black_b = rt.Palette.BLACK:unpack()
    love.graphics.setColor(black_r, black_g, black_b, self._a)
    love.graphics.polygon("line", self._top_tri)
    love.graphics.polygon("line", self._bottom_tri)

    for circle in values(self._circles) do
        love.graphics.circle("line", table.unpack(circle))
    end

    -- selection
    rt.Palette.BLACK:bind()
    love.graphics.setLineWidth((3 + 2) * rt.get_pixel_scale())
    love.graphics.circle("line", self._selection_x, self._selection_y, self._selection_radius)

    love.graphics.setColor(self._r, self._g, self._b, self._a)
    love.graphics.setLineWidth(3 * rt.get_pixel_scale())
    love.graphics.circle("line", self._selection_x, self._selection_y, self._selection_radius)

    love.graphics.pop()
end

