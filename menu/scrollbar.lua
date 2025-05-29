rt.settings.scrollbar = {
    corner_radius = rt.settings.frame.corner_radius / 2
}

--- @class
mn.Scrollbar = meta.class("Scrollbar", rt.Widget)

function mn.Scrollbar:instantiate()
    meta.install(self, {
        _base = rt.Rectangle(0, 0, 1, 1),
        _base_outline = rt.Rectangle(0, 0, 1, 1),
        _cursor = rt.Rectangle(0, 0, 1, 1),
        _cursor_outline = rt.Rectangle(0, 0, 1, 1),
        _outline_width = 1,

        _page_index = 1,
        _n_pages = 100,
        _page_size = 1,
    })
end

--- @brief
function mn.Scrollbar:realize()
    if self:already_realized() then return end
    self._base:set_color(rt.Palette.GRAY_5)
    self._base_outline:set_color(rt.Palette.BACKGROUND_OUTLINE)
    self._base_outline:set_is_outline(true)
    self._base_outline:set_line_width(self._outline_width)

    self._cursor:set_color(rt.Palette.FOREGROUND)
    self._cursor_outline:set_color(rt.Palette.BACKGROUND_OUTLINE)
    self._cursor_outline:set_is_outline(true)
    self._cursor_outline:set_line_width(self._outline_width)

    for shape in range(self._base, self._base_outline, self._cursor, self._cursor_outline) do
        shape:set_corner_radius(rt.settings.scrollbar.corner_radius)
    end
    self._is_realized = true
end

--- @brief
function mn.Scrollbar:set_n_pages(value)
    if self._n_pages == value then return end
    self._n_pages = value
    if self._is_realized then
        self:reformat()
    end
end

--- @brief
function mn.Scrollbar:set_page_index(value, n_pages_maybe)
    local i_before, n_before = self._page_index, self._n_pages

    self._page_index = value
    if n_pages_maybe ~= nil then
        self._n_pages = n_pages_maybe
    end

    if self._is_realized and i_before ~= self._page_index or n_before ~= self._n_pages then
        self:reformat()
    end
end

--- @brief
function mn.Scrollbar:size_allocate(x, y, w, h)
    local t = math.floor(self._outline_width / 2)
    self._base:reformat(x, y, w, h)
    self._base_outline:reformat(x + t, y + t, w - 2 * t, h - 2 * t)

    local cursor_h = math.max(self._page_size / self._n_pages * h, rt.settings.margin_unit / 2)
    local cursor_y = y + (self._page_index - 1) / self._n_pages * h

    self._cursor:reformat(x, cursor_y, w, cursor_h)
    self._cursor_outline:reformat(x + t, cursor_y + t, w - 2 * t, cursor_h - 2 * t)
end

--- @brief
function mn.Scrollbar:draw()
    if self:get_is_visible() then
        self._base:draw()
        self._base_outline:draw()
        self._cursor:draw()
        self._cursor_outline:draw()
    end
end

--- @brief
function mn.Scrollbar:set_opacity(alpha)
    self._opacity = alpha
    self._base:set_opacity(alpha)
    self._base_outline:set_opacity(alpha)
    self._cursor:set_opacity(alpha)
    self._cursor_outline:set_opacity(alpha)
end

--- @brief
function mn.Scrollbar:set_color(color)
    self._cursor:set_color(color)
end