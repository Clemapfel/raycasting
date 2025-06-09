require "common.widget"
require "common.frame"
require "menu.scrollbar"

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
    self._scrollbar = mn.Scrollbar()

    self._item_top_y = 0
    self._item_bottom_y = 0
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

    local scrollbar_w = rt.settings.settings_scene.scrollbar_width_factor * rt.settings.margin_unit
    self._scrollbar:reformat(
        x + width - scrollbar_w,
        y,
        scrollbar_w,
        height
    )

    self._item_stencil:reformat(x, y, width, height)

    local item_h = math.max(
        max_widget_h,
        height / self._n_items
    )

    local frame_thickness = rt.settings.frame.thickness
    item_h = item_h - ((self._n_items - 1) * item_y_margin) / self._n_items
    item_h = math.ceil(height / math.floor(height / item_h))
    local item_w = width - scrollbar_w - m

    self._item_top_y = y
    local item_total_height = item_h + item_y_margin

    for i, item in ipairs(self._items) do
        local current_y = y + (i - 1) * item_total_height

        for frame in range(item.frame, item.selected_frame) do
            frame:reformat(
                x + frame_thickness,
                current_y + frame_thickness,
                item_w - 2 * frame_thickness,
                item_h - 2 * frame_thickness
            )
        end

        item.widget:reformat(x, current_y, item_w, item_h)

        item.y = current_y
        item.height = item_h
    end

    self._item_bottom_y = self._item_top_y + height
    self:set_selected_item(self._selected_item_i)
end

--- @brief
function mn.ScrollableList:draw()
    love.graphics.setScissor(self._item_stencil:unpack())
    love.graphics.push()
    love.graphics.origin()
    love.graphics.translate(0, math.floor(self._item_y_offset))

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

    local item = {
        widget = widget,
        frame = rt.Frame(),
        selected_frame = rt.Frame(),
        y = 0,
        height = 0
    }

    item.selected_frame:set_selection_state(rt.SelectionState.ACTIVE)

    if self:get_is_realized() then
        item.widget:realize()
        item.frame:realize()
        item.selected_frame:realize()

        if skip_reformat ~= false then
            self:reformat()
        end
    end

    table.insert(self._items, item)
    self._n_items = self._n_items + 1
    self._scrollbar:set_n_pages(self._n_items)
end

--- @brief
function mn.ScrollableList:scroll_up()
    if self:can_scroll_up() then
        self:set_selected_item(self._selected_item_i - 1)
    end
end

--- @brief
function mn.ScrollableList:scroll_down()
    if self:can_scroll_down() then
        self:set_selected_item(self._selected_item_i + 1)
    end
end

--- @brief
function mn.ScrollableList:get_selected_item()
    return self._items[self._selected_item_i].widget
end

--- @brief
function mn.ScrollableList:get_item(i)
    return self._items[i].widget
end

--- @brief
function mn.ScrollableList:get_selected_item_i()
    return self._selected_item_i
end

--- @brief
function mn.ScrollableList:get_n_items()
    return self._n_items
end

--- @brief
function mn.ScrollableList:set_should_wrap(b)
    self._should_wrap = b
end

--- @brief
function mn.ScrollableList:can_scroll_up()
    if self._should_wrap and self._selected_item_i == 1 then
        return true
    else
        return self._selected_item_i > 1
    end
end

--- @brief
function mn.ScrollableList:can_scroll_down()
    if self._should_wrap and self._selected_item_i == self._n_items then
        return true
    else
        return self._selected_item_i < self._n_items
    end
end

function mn.ScrollableList:set_selected_item(i)
    meta.assert(i, "Number")
    if self._selected_item_i > self._n_items then return end

    local before = self._items[self._selected_item_i]
    self._selected_item_i = i
    local after = self._items[self._selected_item_i]

    local item = self._items[self._selected_item_i]
    local item_top_y = item.y
    local item_bottom_y = item_top_y + item.height

    if item_top_y <= self._item_top_y then
        self._item_y_offset = self._item_top_y - item_top_y
    elseif item_bottom_y >= self._item_bottom_y then
        self._item_y_offset = self._item_bottom_y - item_bottom_y
    end

    if before ~= nil then
        before.widget:set_selection_state(rt.SelectionState.INACTIVE)
    end

    if after ~= nil then
        after.widget:set_selection_state(rt.SelectionState.ACTIVE)
    end

    self._scrollbar:set_page_index(self._selected_item_i)
end