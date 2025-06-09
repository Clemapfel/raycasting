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
    self._scroll_offset = 0 -- for scrolling
    self._total_item_height = 0
    self._radius = 1

    self._circle_mapping_upgrade_needed = true
end

--- @brief
function mn.StageSelectPageIndicator:set_stage_grade(i, grade)
    meta.assert_enum_value(grade, rt.StageGrade, 2)
    self._page_i_to_grade[i] = grade
    self._circle_mapping_upgrade_needed = true
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

    if self._total_item_height <= self._stencil.height then
        self._scroll_offset = 0
    else
        local current = self._selection_y
        local center = self._bounds.y + 0.5 * self._bounds.height
        local max_offset = self._total_item_height - (self._stencil.height - (self._stencil.y - self._bounds.y))

        if current >= center then
            local new_offset = current - center
            new_offset = math.min(new_offset, max_offset)

            self._scroll_offset = -1 * new_offset
        else
            self._scroll_offset = 0
        end
    end
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
    self._selection_radius = radius + 2 * rt.get_pixel_scale()

    local current_x, current_y = x + 0.5 * width, y + 0.5 * radius

    local top_y = y + 0.5 * radius
    local tri_x = current_x
    local tri_y = 0
    local tri_r = radius
    self._top_tri = {
        current_x, top_y - tri_r,
        current_x - tri_r * math.sqrt(3) / 2, top_y + tri_r / 2,
        current_x + tri_r * math.sqrt(3) / 2, top_y + tri_r / 2
    }

    local tri_h = 2 * radius
    current_y = current_y + tri_h

    local padding = self._selection_radius - self._radius + 2.5 * rt.get_pixel_scale()
    self._stencil:reformat(
        x - padding, y + 1 * radius,
        width + 2 * padding, height - 2 * radius
    )

    self._circles = {}
    local circle_height = height - 2 * radius
    local circle_m = 0.5 * m
    local total_circle_height = 0
    for i = 1, self._n_pages do
        table.insert(self._circles, { current_x, current_y, radius })
        current_y = current_y + 2 * radius + circle_m
        total_circle_height = total_circle_height + 2 * radius + circle_m
    end

    self._total_item_height = total_circle_height - circle_m

    local bottom_y = math.min(y + height - 0.5 * radius, current_y)
    self._bottom_tri = {
        current_x, bottom_y + tri_r,
        current_x - tri_r * math.sqrt(3) / 2, bottom_y - tri_r / 2,
        current_x + tri_r * math.sqrt(3) / 2, bottom_y - tri_r / 2
    }

    self:set_selected_page(self._selected_page_i)
    self._motion:skip()
end

--- @brief
function mn.StageSelectPageIndicator:draw()
    if self._circle_mapping_upgrade_needed == true then
        self._grade_to_circles = meta.make_weak({})
        for grade in values(meta.instances(rt.StageGrade)) do
            self._grade_to_circles[grade] = {}
        end

        for i, grade in pairs(self._page_i_to_grade) do
            table.insert(self._grade_to_circles[grade], self._circles[i])
        end

        self._circle_mapping_upgrade_needed = false
    end

    love.graphics.push()

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
    love.graphics.setLineWidth(2)

    -- circle base, sorted by grade for better batching
    for grade, circles in pairs(self._grade_to_circles) do
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
        for circle in values(circles) do
            love.graphics.circle("fill", table.unpack(circle))
        end
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

