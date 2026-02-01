require "common.player_body"
require "common.smoothed_motion_1d"
require "common.stage_grade"
require "menu.stage_select_page_indicator_ring"
require "common.game_state"

--- @class mn.StageSelectPageIndicator
mn.StageSelectPageIndicator = meta.class("StageSelectPageIndicator", rt.Widget)

local _shader = rt.Shader("menu/stage_select_page_indicator.glsl")

--- @brief
function mn.StageSelectPageIndicator:instantiate()

    self._hue = 0
    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, 0, 1))
    self._top_tri = {}
    self._bottom_tri = {}
    self._circles = {}
    self._has_notification = {}
    self._notification = nil -- rt.Mesh
    self._notification_outline = {} -- love.Line
    self._n_pages = 0
    self._page_i_to_grade = {}
    self._elapsed = 0

    self._selection_x = 0
    self._selection_y = 0
    self._selection_radius = 1
    self._selected_page_i = 1

    self._stencil = rt.AABB()

    self._motion = rt.SmoothedMotion1D(0, 2 * rt.get_pixel_scale())
    self._ring = nil -- mn.StageSelectPageIndicatorRing
    self._scroll_offset = 0 -- for scrolling
    self._total_item_height = 0
    self._radius = 1
    self._y_offset = 0

    self._circle_mapping_upgrade_needed = true

    self:create_from_state()
end

--- @brief
function mn.StageSelectPageIndicator:create_from_state()
    local ids = rt.GameState:list_stage_ids()
    self._n_pages = #ids
    self._has_notification = {}

    local page_i = 1
    for id in values(ids) do
        self._page_i_to_grade[page_i] = select(4, rt.GameState:get_stage_grades(id))
        self._has_notification[page_i] = rt.GameState:get_stage_was_cleared(id)
        page_i = page_i + 1
    end
    self._circle_mapping_upgrade_needed = true

    if self:get_is_realized() then
        self:reformat()
    end
end

--- @brief
function mn.StageSelectPageIndicator:set_selected_page(i)
    if not (i > 0 and i <= self._n_pages) then
        rt.error("In mn.StageSelectPageIndicator: page `", i, "` is out of range")
    end

    self._selected_page_i = i
    self._motion:set_target_value(self._circles[i][2])
end

--- @brief
function mn.StageSelectPageIndicator:update(delta)
    self._selection_y = self._motion:update(delta)
    self._elapsed = self._elapsed + delta
    self._ring:update(delta)

    if self._total_item_height <= self._stencil.height then
        self._scroll_offset = 0
    else
        local current = self._selection_y
        local center = self._bounds.y + 0.5 * self._bounds.height
        local max_offset = self._total_item_height - (self._stencil.height - (self._stencil.y - self._bounds.y)) - 2 * self._radius

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

    local top_y = y + radius
    local tri_x = current_x
    local tri_y = 0
    local tri_r = radius
    self._top_tri = {
        current_x, top_y - tri_r,
        current_x - tri_r * math.sqrt(3) / 2, top_y + tri_r / 2,
        current_x + tri_r * math.sqrt(3) / 2, top_y + tri_r / 2
    }

    local tri_h = 2 * radius
    current_y = current_y + tri_h + m

    local padding = self._selection_radius - self._radius + 2.5 * rt.get_pixel_scale()
    self._stencil:reformat(
        x - padding, y + 2 * radius,
        width + 2 * padding, height - 4 * radius
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

    local bottom_y = math.min(y + height - radius, current_y)
    self._bottom_tri = {
        current_x, bottom_y + tri_r,
        current_x - tri_r * math.sqrt(3) / 2, bottom_y - tri_r / 2,
        current_x + tri_r * math.sqrt(3) / 2, bottom_y - tri_r / 2
    }

    local notification_radius = radius / 3
    local notification_x = 0 -- local coords relative to ball center
    local notification_y = 0

    self._notification = rt.MeshCircle(notification_x, notification_y, notification_radius)
    self._notification:set_vertex_color(1, rt.Palette.YELLOW:unpack())
    for i = 2, self._notification:get_n_vertices() do
        self._notification:set_vertex_color(i, rt.Palette.RED:unpack())
    end

    self._notification_outline = {}
    do
        local n_outer_vertices = 16
        local step = (2 * math.pi) / n_outer_vertices
        for i = 1, n_outer_vertices * rt.get_pixel_scale() do
            table.insert(self._notification_outline, notification_x + math.cos((i - 1) * step) * notification_radius)
            table.insert(self._notification_outline, notification_y + math.sin((i - 1) * step) * notification_radius)
        end
        table.insert(self._notification_outline, self._notification_outline[1])
        table.insert(self._notification_outline, self._notification_outline[2])
    end

    self:set_selected_page(self._selected_page_i)
    self._motion:skip()
    self._circle_mapping_upgrade_needed = true
    self._ring = mn.StageSelectPageIndicatorRing(self._selection_radius, math.floor(2.5 * rt.get_pixel_scale()))

    self._y_offset = 0.5 * height - 0.5 * (bottom_y - y)
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
    love.graphics.translate(0, self._y_offset)
    _shader:send("elapsed", self._elapsed)

    love.graphics.setColor(1, 1, 1, 1)

    love.graphics.setScissor(self._stencil:unpack())

    love.graphics.push()
    love.graphics.translate(0, self._scroll_offset)
    love.graphics.setLineWidth(2)

    -- circle base, sorted by grade for better batching
    for grade, circles in pairs(self._grade_to_circles) do
        if grade == rt.StageGrade.S then
            _shader:send("state", 1) -- perfect
        elseif grade == rt.StageGrade.F or grade == rt.StageGrade.NONE then
            _shader:send("state", -1) -- shadow
            _shader:send("color", { rt.Palette[grade]:unpack() })
        else
            _shader:send("state", 0) -- shadow + highlight
            _shader:send("color", { rt.Palette[grade]:unpack() })
        end

        _shader:bind()
        love.graphics.setColor(1, 1, 1, 1)
        for circle in values(circles) do
            love.graphics.circle("fill", table.unpack(circle))
        end
        _shader:unbind()
    end

    -- outlines
    love.graphics.setLineWidth(2)
    local black_r, black_g, black_b = rt.Palette.BLACK:unpack()
    love.graphics.setColor(black_r, black_g, black_b, self._a)

    for circle in values(self._circles) do
        love.graphics.circle("line", table.unpack(circle))
    end

    love.graphics.setScissor()

    -- selection
    love.graphics.translate(self._selection_x, self._selection_y)
    love.graphics.setColor(1, 1, 1, 1)
    self._ring:draw()
    love.graphics.pop()

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

    love.graphics.setColor(black_r, black_g, black_b, self._a)
    love.graphics.polygon("line", self._top_tri)
    love.graphics.polygon("line", self._bottom_tri)

    -- notifications
    love.graphics.push()
    love.graphics.translate(0, self._scroll_offset)

    --[[
    -- notifications
    rt.Palette.BLACK:bind()
    local offset_x, offset_y = self._radius * 0.5, -self._radius * 0.5
    for i = 1, self._n_pages do
        local circle = self._circles[i]
        love.graphics.push()
        love.graphics.translate(circle[1] + offset_x, circle[2] + offset_y)
        love.graphics.line(self._notification_outline)
        love.graphics.pop()
    end

    love.graphics.setColor(1, 1, 1, 1)
    for i = 1, self._n_pages do
        local circle = self._circles[i]
        love.graphics.push()
        love.graphics.translate(circle[1] + offset_x, circle[2] + offset_y)
        self._notification:draw()
        love.graphics.pop()
    end

    ]]--

    love.graphics.pop()
    love.graphics.pop()
end

--- @brief
function mn.StageSelectPageIndicator:set_hue(hue)
    self._hue = hue
    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, hue, 1))
    self._ring:set_hue(hue)
end

--- @brief
function mn.StageSelectPageIndicator:draw_bloom()
    love.graphics.push()
    love.graphics.translate(0, self._y_offset)

    love.graphics.push()
    love.graphics.translate(self._selection_x, self._selection_y)
    self._ring:draw()
    love.graphics.pop()

    local shader_bound = false
    for grade, circles in pairs(self._grade_to_circles) do
        if grade == rt.StageGrade.S then
            if not shader_bound then
                _shader:bind()
                _shader:send("state", 1) -- perfect
                shader_bound = true
            end

            love.graphics.setColor(1, 1, 1, 1)
            for circle in values(circles) do
                love.graphics.circle("fill", table.unpack(circle))
            end
        end
    end

    if shader_bound then
        _shader:unbind()
    end

    love.graphics.pop()
end