require "common.widget"

rt.settings.menu.scrollable_list = {
    scroll_ticks_per_second = 4,
    scroll_delay = 20 / 60,
}

--- @class mn.ScrollableList
mn.ScrollableList = meta.class("ScrollableList", rt.Widget)

--- @brief
function mn.ScrollableList:instantiate()
    self._items = {}
    self._n_items = 0
    self._selected_item_i = 1
    self._item_stencil = rt.AABB()
    self._item_y_offset = 0
    self._max_item_y_offset = 0
    self._scrollbar = rt.Scrollbar()
end

--- @brief
function mn.ScrollableList:realize()
    for item in values(self._items) do
        for widget in range(
            item.widget,
            item.frame,
            item.selected_frame
        ) do
            widget:realize()
        end
    end

    self._scrollbar:realize()
end

--- @brief
function mn.ScrollableList:size_allocate(x, y, width, height)
    local m = rt.settings.margin_unit
    local outer_margin = 2 * m
    local item_y_padding = m
    local item_y_margin = m

    local max_widget_w, max_widget_h = -math.huge, -math.huge
    for item in values(self._items) do
        local item_w, item_h = item.widget:measure()
        max_widget_w = math.max(max_widget_w, item_w)
        max_widget_h = math.max(max_widget_h, item_h)
    end

    local current_x, current_y = x, y + item_y_margin

    local scrollbar_w = rt.settings.settings_scene.scrollbar_width_factor * rt.settings.margin_unit
    self._scrollbar:reformat(
        x + width - scrollbar_w,
        current_y,
        scrollbar_w,
        height
    )

    local frame_thickness = rt.settings.frame.thickness
    self._item_stencil:reformat(current_x, current_y, width, height)

    local item_h = math.max(
        max_widget_h,
        height / self._n_items
    )

    item_h = height / math.ceil(height / item_h)
    item_h = item_h - ((self._n_items - 1) * item_y_margin) / self._n_items

    local item_w = width - 2 * outer_margin - scrollbar_w

    local height_above = 0
    local total_height = 0
    for item in values(self._items) do
        for frame in range(
            item.frame,
            item.selected_frame
        ) do
            frame:reformat(
                x + frame_thickness,
                current_y + frame_thickness,
                item_w - 2 * frame_thickness,
                item_h - 2 * frame_thickness
            )
        end

        local prefix_w, prefix_h = item.prefix:measure()
        item.widget:reformat(
            x, current_y + 0.5 * item_h - 0.5 * prefix_h,
            item_w, item_h
        )

        local current_height = item_h + item_y_margin
        item.y = current_y
        item.height_above = height_above
        item.height = current_height
        height_above = height_above + current_height
        current_y = current_y + current_height
        total_height = total_height + current_height
    end

    total_height = total_height - item_y_margin
    self._max_item_y_offset = total_height - height
    self:_set_selected_item(self._selected_item_i)
end

--- @brief
function mn.ScrollableList:draw()
    love.graphics.setScissor(self._item_stencil:unpack())
    love.graphics.push()
    love.graphics.translate(0, self._item_y_offset)

    for i, item in ipairs(self._items) do
        if i == self._selected_item_i then
            item.selected_frame:draw()
        else
            item.frame:draw()
        end

        item.widget:draw()
    end

    love.graphics.pop()
    love.graphics.setScissor()

    self._scrollbar:draw()
end

--- @brief
function mn.ScrollableList:add_item(widget, skip_reformat)
    if not meta.isa(widget, rt.Widget) then
        rt.error("In mn.ScrollableList:add_item: item is not a widget`")
    end

    if skip_reformat == nil then skip_reformat = false end

    self._n_items = self._n_items + 1
    local item = {
        widget = widget,
        frame = rt.Frame(),
        selected_frame = rt.Frame(),
        y = 0,
        height = 0,
        height_above = 0
    }

    if self:get_is_realized() then
        item.widget:realize()
        item.frame:realize()
        item.selected_frame:realize()

        if skip_reformat ~= false then
            self:reformat()
        end
    end

    table.insert(self._items, item)
end

--- @brief
function mn.ScrollableList:scroll_up()
    if self:can_scroll_up() then
        self:_set_selected_item(self._selected_item_i - 1)
    end
end

--- @brief
function mn.ScrollableList:scroll_down()
    if self:can_scroll_down() then
        self._set_selected_item(self._selected_item_i + 1)
    end
end

--- @brief
function mn.ScrollableList:get_current_item()
    return self._items[self._selected_item_i]
end

--- @brief
function mn.ScrollableList:can_scroll_up()
    return self._selected_item_i > 1
end

--- @brief
function mn.ScrollableList:can_scroll_down()
    return self._selected_item_i < self._n_items
end

--- @brief
function mn.ScrollableList:set_selected_item(i)
    if self._selected_item_i > self._n_items then return end

    local before = self._items[self._selected_item_i]
    self._selected_item_i = i
    local after = self._items[self._selected_item_i]

    local item = self._items[self._selected_item_i]
    if item.y > self._item_stencil.y + self._item_stencil.height then
        self._item_y_offset = -1 * math.min(item.height_above, self._max_item_y_offset)
    else
        self._item_y_offset = 0
    end

    if before ~= nil then
        before:set_selection_state(rt.SelectionState.INACTIVE)
    end

    if after ~= nil then
        after:set_selection_state(rt.SelectionState.ACTIVE)
    end

    self._scrollbar:set_page_index(self._selected_item_i)
end