require "common.widget"
require "common.direction_indicator"
require "common.shape"
require "common.label"
require "common.stencil"

rt.settings.menu.option_button = {
    scroll_speed = 1000, -- px per second
    indicator_glow_duration = 0.2, -- seconds
}

--- @class mn.OptionButton
--- @signal selection (mn.OptionButton, string) -> nil
mn.OptionButton = meta.class("OptionButton", rt.Widget)
meta.add_signal(mn.OptionButton, "selection")

--- @brief
function mn.OptionButton:instantiate(...)
    assert(select("#", ...) > 0)

    local options
    if meta.is_table(select(1, ...)) then
        options = select(1, ...)
    else
        options = { ... }
    end

    for i, value in ipairs(options) do
        meta.assert_typeof(value, "String", i)
    end

    meta.install(self, {
        _options = options,
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
        _stencil = rt.Rectangle(),
        _final_w = 1,
        _final_h = 1
    })

    for i, option in ipairs(self._options) do
        self._item_label_to_item_i[option] = i
    end
end

--- @brief
function mn.OptionButton:_emit_selection()
    local success = self:signal_try_emit("selection", self._options[self._current_item_i])
    if success then
        rt.SoundManager:play(rt.SoundIDs.menu.option_button.selection)
    end
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
            offset = 0
        }
        to_push.label:realize()
        to_push.label:set_justify_mode(rt.JustifyMode.CENTER)

        self._n_items = self._n_items + 1
        table.insert(self._items, to_push)
    end

    self._left_indicator:realize()
    self._right_indicator:realize()
end

--- @override
function mn.OptionButton:size_allocate(x, y, width, height)
    local m = rt.settings.margin_unit

    local max_w, max_h = -math.huge, -math.huge
    for item in values(self._items) do
        local w, h = item.label:measure()
        max_w = math.max(max_w, w)
        max_h = math.max(max_h, h)
    end

    local indicator_r = max_h
    self._left_indicator:reformat(
        x, y + 0.5 * height - 0.5 * max_h, indicator_r, indicator_r
    )

    self._right_indicator:reformat(
        x + width - indicator_r, y + 0.5 * height - 0.5 * max_h, indicator_r, indicator_r
    )

    self._final_w = width
    self._final_h = max_h

    local label_start_x = x + indicator_r + m
    local label_y = y + 0.5 * height - 0.5 * max_h
    local tile_w = width - 2 * m - 2 * indicator_r
    local padding = 5 * rt.get_pixel_scale()

    local current_x = label_start_x
    for item in values(self._items) do
        local w, h = item.label:measure()
        item.label:reformat(current_x, label_y, tile_w, math.huge)
        item.offset = current_x - label_start_x
        current_x = current_x + tile_w + padding
    end

    local stencil_h = max_h + 2 * padding
    self._stencil:reformat(
        x + indicator_r, y + 0.5 * height - 0.5 * stencil_h, tile_w, stencil_h
    )

    self:_update_direction_indicators()
    self._current_offset = self._items[self._current_item_i].offset
end

--- @override
function mn.OptionButton:draw()
    self._left_indicator:draw()
    self._right_indicator:draw()

    local stencil_value = rt.graphics.get_stencil_value()
    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW)
    self._stencil:draw()
    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST, rt.StencilCompareMode.EQUAL)

    local offset = self._current_offset
    love.graphics.translate(-offset, 0)

    for i = self._current_item_i - 1, self._current_item_i + 1 do
        local item = self._items[i]
        if item ~= nil then
            item.label:draw()
        end
    end

    love.graphics.translate(offset, 0)
    rt.graphics.set_stencil_mode(nil)
end

local _color_mix = function(color_a, color_b, fraction) 
    return rt.RGBA(math.mix4(color_a.r, color_a.g, color_a.b, color_a.a, color_b.r, color_b.g, color_b.b, color_b.a, fraction))
end

--- @brief
function mn.OptionButton:update(delta)
    local target_offset = self._items[self._current_item_i].offset

    local offset = delta * rt.settings.menu.option_button.scroll_speed
    if self._current_offset < target_offset then
        self._current_offset = math.clamp(self._current_offset + offset, 0, target_offset)
    elseif self._current_offset > target_offset then
        self._current_offset = math.clamp(self._current_offset - offset, target_offset)
    end

    local glow_duration = rt.settings.menu.option_button.indicator_glow_duration
    if self._right_indicator_glow_active then
        self._right_indicator_elapsed = self._right_indicator_elapsed + delta
        local fraction = math.clamp(self._right_indicator_elapsed / glow_duration, 0, 1)
        self._right_indicator:set_color(_color_mix(rt.Palette.SELECTION, rt.Palette.FOREGROUND, fraction))

        if self._right_indicator_elapsed >= glow_duration then
            self._right_indicator_elapsed = 0
            self._right_indicator_glow_active = false
        end
    end

    if self._left_indicator_glow_active then
        self._left_indicator_elapsed = self._left_indicator_elapsed + delta
        local fraction = math.clamp(self._left_indicator_elapsed / glow_duration, 0, 1)
        self._left_indicator:set_color(_color_mix(rt.Palette.SELECTION, rt.Palette.FOREGROUND, fraction))

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
            rt.error("In mn.OptionButton:set_option: option #",  i,  " is out of bounds for OptionButton with `",  self._n_items,  "` options")
            return
        end

        self._current_item_i = i
        self:_emit_selection()
    else
        meta.assert(i_or_text, "String")
        local text = i_or_text
        local new_i = self._item_label_to_item_i[text]
        if new_i == nil then
            rt.error("In mn.OptionButton:set_option: option `",  text,  "` is not available")
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
