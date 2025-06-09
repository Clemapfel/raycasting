require "common.player_body"
require "common.smoothed_motion_1d"
require "common.stage_grade"

--- @class mn.StageSelectPageIndicator
mn.StageSelectPageIndicator = meta.class("StageSelectPageIndicator", rt.Widget)

local _shader = nil

--- @brief
function mn.StageSelectPageIndicator:instantiate(n_pages)
    meta.assert(n_pages, "Number")

    if _shader == nil then _shader = rt.Shader("menu/stage_select_page_indicator.glsl") end

    self._top_tri = {}
    self._bottom_tri = {}
    self._circles = {}
    self._n_pages = n_pages
    self._page_i_to_grade = {}
    self._elapsed = 0

    self._selection_x = 0
    self._selection_y = 0
    self._selection_radius = 1
    self._selected_page_i = 1

    self._stencil = rt.AABB()

    self._motion = rt.SmoothedMotion1D(0, 2 * rt.get_pixel_scale())
    self._y_offset = 0 -- for centering widget overall
    self._scroll_offset = 0 -- for scrolling
    self._radius = 1
end

--- @brief
function mn.StageSelectPageIndicator:set_stage_grade(i, grade)
    meta.assert_enum_value(grade, rt.StageGrade, 2)
    self._page_i_to_grade[i] = grade
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
    self._elapsed = self._elapsed + delta

    local center = self._bounds.y + 0.5 * self._bounds.height
    self._scroll_offset = center - self._selection_y
end

--- @brief
function mn.StageSelectPageIndicator:skip()
    self._motion:set_value(self._motion:get_target_value())
    self:update(0)
end

--- @brief
function mn.StageSelectPageIndicator:size_allocate(x, y, width, height)
    local radius = width / 2
    local m = rt.settings.margin_unit

    self._radius = radius
    self._selection_x = x + 0.5 * width
    self._selection_radius = radius

    local current_x, current_y = x + 0.5 * width, y + 0.5 * radius

    local top_y = y + 0.5 * radius
    self._top_tri = {
        current_x, top_y - radius,
        current_x - radius * math.sqrt(3) / 2, top_y + radius / 2,
        current_x + radius * math.sqrt(3) / 2, top_y + radius / 2
    }

    local tri_h = 2 * radius
    current_y = current_y + tri_h

    local padding = 7 * rt.get_pixel_scale()
    self._stencil:reformat(
        x - padding, y + radius + 0.5 * padding,
        width + 2 * padding, height - 2 * radius - 2 * 0.5 * padding
    )

    self._circles = {}
    local circle_height = height - 2 * radius
    local circle_m = 0.5 * m
    for i = 1, self._n_pages do
        table.insert(self._circles, { current_x, current_y, radius })
        current_y = current_y + 2 * radius + circle_m
    end

    local bottom_y = math.min(y + height - 0.5 * radius, current_y)
    self._bottom_tri = {
        current_x, bottom_y + radius,
        current_x - radius * math.sqrt(3) / 2, bottom_y - radius / 2,
        current_x + radius * math.sqrt(3) / 2, bottom_y - radius / 2
    }

    local total_h = (2 + self._n_pages) * 2 * radius + (2 + self._n_pages - 1) * m
    self._y_offset = math.max((height - total_h) / 2, 0)

    self:set_selected_page(self._selected_page_i)
    self._motion:skip()
end

--- @brief
function mn.StageSelectPageIndicator:draw()
    love.graphics.push()
    love.graphics.translate(0, self._y_offset)

    -- tris
    if self._selected_page_i > 1 then
        rt.Palette.FOREGROUND:bind()
    else
        rt.Palette.GRAY_6:bind()
    end
    love.graphics.polygon("fill", self._top_tri)

    if self._selected_page_i < self._n_pages then
        rt.Palette.FOREGROUND:bind()
    else
        rt.Palette.GRAY_6:bind()
    end
    love.graphics.polygon("fill", self._bottom_tri)

    _shader:send("elapsed", self._elapsed)
    love.graphics.setScissor(self._stencil:unpack())

    love.graphics.push()
    love.graphics.translate(0, self._scroll_offset)

    -- circle base
    love.graphics.setLineWidth(2)
    for i, circle in ipairs(self._circles) do
        local grade = self._page_i_to_grade[i]
        if grade == rt.StageGrade.SS then
            _shader:send("state", 1) -- perfect
        elseif grade == rt.StageGrade.F or grade == rt.StageGrade.NONE then
            _shader:send("state", -1) -- shadow
            _shader:send("color", { rt.Palette.STAGE_GRADE_TO_COLOR[grade]:unpack() })
        else
            _shader:send("state", 0) -- shadow + highlight
            _shader:send("color", { rt.Palette.STAGE_GRADE_TO_COLOR[grade]:unpack() })
        end

        _shader:bind()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", table.unpack(circle))
        _shader:unbind()
    end

    -- outlines
    love.graphics.setLineWidth(rt.settings.player_body.outline_width)
    local black_r, black_g, black_b = rt.Palette.BLACK:unpack()
    love.graphics.setColor(black_r, black_g, black_b, self._a)

    for circle in values(self._circles) do
        love.graphics.circle("line", table.unpack(circle))
    end

    -- selection
    rt.Palette.BLACK:bind()
    love.graphics.setLineWidth((3 + 2) * rt.get_pixel_scale())
    love.graphics.circle("line", self._selection_x, self._selection_y, self._selection_radius)

    rt.Palette.FOREGROUND:bind()
    love.graphics.setLineWidth(3 * rt.get_pixel_scale())
    love.graphics.circle("line", self._selection_x, self._selection_y, self._selection_radius)

    love.graphics.pop()
    love.graphics.setColor(black_r, black_g, black_b, self._a)
    love.graphics.polygon("line", self._top_tri)
    love.graphics.polygon("line", self._bottom_tri)

    love.graphics.pop()
    love.graphics.setScissor()
end

