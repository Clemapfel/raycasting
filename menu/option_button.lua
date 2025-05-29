rt.settings.menu.option_button = {
    scroll_speed = 1000, -- px per second
    indicator_glow_duration = 0.2, -- seconds
}

--- @class mn.OptionButton
--- @signal selection (mn.OptionButton, string) -> nil
mn.OptionButton = meta.new_type("OptionButton", rt.Widget)

--- @brief
function mn.OptionButton:instantiate(...)
    assert(select("#", ...) > 0)
    local out = meta.new(mn.OptionButton, {
        _options = { ... },
        _left_indicator = rt.DirectionIndicator(rt.Direction.LEFT),
        _right_indicator = rt.DirectionIndicator(rt.Direction.RIGHT),

        _right_indicator_glow_active = false,
        _right_indicator_elapsed = 0,

        _left_indicator_glow_active = false,
        _left_indicator_elapsed = 0,

        _items = {}, -- Table<rt.Label>
        _item_label_to_item_i = {},
        _current_item_i = 1,
        _current_offset = 0,
        _n_items = 0,
        _stencil = rt.Rectangle(0, 0, 1, 1),
        _final_w = 1,
        _final_h = 1
    })

    for i, option in ipairs(out._options) do
        out._item_label_to_item_i[option] = i
    end

    return out
end

meta.add_signal(mn.OptionButton, "selection")

--- @brief
function mn.OptionButton:_emit_selection()
    self:signal_emit("selection", self._items[self._current_item_i].text)
end

--- @override
function mn.OptionButton:realize()
    if self:already_realized() then return end

    self._option_labels = {}
    self._n_items = 0
    self._items = {}
    for option in values(self._options) do
        local to_push = {
            text = option,
            label = rt.Label("<o>" .. option .. "</o>"),
            offset = 0,
            line = rt.Rectangle(0, 0, 1, 1),
        }
        to_push.label:realize()
        to_push.label:set_justify_mode(rt.JustifyMode.LEFT)

        self._n_items = self._n_items + 1
        table.insert(self._items, to_push)
    end

    self._left_indicator:realize()
    self._right_indicator:realize()

    self:create_from_state(self._state)
end

--- @override
function mn.OptionButton:create_from_state(state)
    self._state = state
end

--- @override
function mn.OptionButton:size_allocate(x, y, width, height)
    local m = rt.settings.margin_unit
    local current_x = x

    local label_ws = {}
    local label_hs = {}
    local max_h, max_w = NEGATIVE_INFINITY, NEGATIVE_INFINITY
    local total_w = 0
    local n = 0
    for item in values(self._items) do
        local w, h = item.label:measure()
        table.insert(label_ws, w)
        table.insert(label_hs, h)
        max_w = math.max(max_w, w)
        max_h = math.max(max_h, h)
        total_w = total_w + w
        n = n + 1
    end

    local label_m = m
    local tile_w = width - 2 * label_m - 2 * max_h --max_w + 2 * label_m

    local left_x = x
    self._left_indicator:fit_into(left_x, y + 0.5 * height - 0.5 * max_h, max_h, max_h)

    local right_x = x + width - max_h --left_x + max_h + label_m + tile_w + label_m
    self._right_indicator:fit_into(right_x, y + 0.5 * height - 0.5 * max_h, max_h, max_h)

    self._final_w = width --right_x + max_h - left_x
    self._final_h = max_h

    local label_start_x = x + max_h + label_m
    local label_y = y + 0.5 * height - 0.5 * max_h

    current_x = label_start_x
    for i, item in ipairs(self._items) do
        local w, h = label_ws[i], label_hs[i]

        item.line:resize(current_x, label_y, tile_w, h)
        item.line:set_color(rt.hsva_to_rgba(rt.HSVA(i / n, 1, 1, 1)))
        item.line:set_opacity(0.5)

        item.label:fit_into(current_x + 0.5 * tile_w - 0.5 * w, label_y, POSITIVE_INFINITY, POSITIVE_INFINITY)
        item.offset = current_x - label_start_x
        current_x = current_x + tile_w + 5
    end

    local stencil_h = max_h + 10
    left_x = left_x + max_h
    self._stencil:resize(left_x, y + 0.5 * height - 0.5 * stencil_h, (right_x - left_x), stencil_h)

    self:_update_direction_indicators()
    self._current_offset = self._items[self._current_item_i].offset
end

--- @override
function mn.OptionButton:draw()
    self._left_indicator:draw()
    self._right_indicator:draw()

    local stencil_value = meta.hash(self) % 254 + 1
    rt.graphics.stencil(stencil_value, self._stencil)
    rt.graphics.set_stencil_test(rt.StencilCompareMode.EQUAL, stencil_value)

    local offset = self._current_offset
    rt.graphics.translate(-offset, 0)

    for i = self._current_item_i - 1, self._current_item_i + 1 do
        local item = self._items[i]
        if item ~= nil then
            item.label:draw()
        end
    end

    rt.graphics.translate(offset, 0)
    rt.graphics.set_stencil_test()
end

--- @brief
function mn.OptionButton:update(delta)
    local target_offset = self._items[self._current_item_i].offset

    local offset = delta * rt.settings.menu.option_button.scroll_speed
    if self._current_offset < target_offset then
        self._current_offset = clamp(self._current_offset + offset, 0, target_offset)
    elseif self._current_offset > target_offset then
        self._current_offset = clamp(self._current_offset - offset, target_offset)
    end

    local glow_duration = rt.settings.menu.option_button.indicator_glow_duration
    if self._right_indicator_glow_active then
        self._right_indicator_elapsed = self._right_indicator_elapsed + delta
        local fraction = clamp(self._right_indicator_elapsed / glow_duration, 0, 1)
        local target_color = rt.color_mix(rt.Palette.SELECTION, rt.Palette.FOREGROUND, fraction)
        self._right_indicator:set_color(target_color)

        if self._right_indicator_elapsed >= glow_duration then
            self._right_indicator_elapsed = 0
            self._right_indicator_glow_active = false
        end
    end

    if self._left_indicator_glow_active then
        self._left_indicator_elapsed = self._left_indicator_elapsed + delta
        local fraction = clamp(self._left_indicator_elapsed / glow_duration, 0, 1)
        local target_color = rt.color_mix(rt.Palette.SELECTION, rt.Palette.FOREGROUND, fraction)
        self._left_indicator:set_color(target_color)

        if self._left_indicator_elapsed >= glow_duration then
            self._left_indicator_elapsed = 0
            self._left_indicator_glow_active = false
        end
    end
end

--- @brief
function mn.OptionButton:_update_direction_indicators()
    local off_opacity = 0.2;
    if self:can_move_right() then
        self._right_indicator:set_opacity(1)
    else
        self._right_indicator:set_opacity(off_opacity)
    end

    if self:can_move_left() then
        self._left_indicator:set_opacity(1)
    else
        self._left_indicator:set_opacity(off_opacity)
    end
end

--- @brief
function mn.OptionButton:move_right()
    if self:can_move_right() then
        self._current_item_i = self._current_item_i + 1

        self._right_indicator_glow_active = true
        self._right_indicator:set_color(rt.Palette.TRUE_WHITE)
        self:_update_direction_indicators()
        self:_emit_selection()
        return true
    else
        return false
    end
end

--- @brief
function mn.OptionButton:move_left()
    if self:can_move_left() then
        self._current_item_i = self._current_item_i - 1

        self._left_indicator_glow_active = true
        self._left_indicator:set_color(rt.Palette.TRUE_WHITE)
        self:_update_direction_indicators()
        self:_emit_selection()
        return true
    else
        return false
    end
end

--- @brief
function mn.OptionButton:set_option(i_or_text)
    if meta.is_number(i_or_text) then
        local i = i_or_text
        if i > self._n_items then
            rt.error("In mn.OptionButton:set_option: option #" .. i .. " is out of bounds for OptionButton with `" .. self._n_items .. "` options")
            return
        end

        self._current_item_i = i
        self:_emit_selection()
    else
        meta.assert_string(i_or_text)
        local text = i_or_text
        local new_i = self._item_label_to_item_i[text]
        if new_i == nil then
            rt.error("In mn.OptionButton:set_option: option `" .. text .. "` is not available")
            return
        end

        self._current_item_i = new_i
        self:_emit_selection()
    end
end

--- @brief
function mn.OptionButton:can_move_left()
    return self._current_item_i > 1
end

--- @brief
function mn.OptionButton:can_move_right()
    return self._current_item_i < self._n_items
end

--- @brief
function mn.OptionButton:measure()
    return self._final_w, self._final_h
end
