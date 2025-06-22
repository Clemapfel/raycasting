require "common.aabb"
require "common.widget"
require "common.selection_state"
require "menu.scroll_indicator"

rt.settings.menu.verbose_info_panel = {
    indicator_highlight_duration = 0.25,
    indicator_base_color = rt.Palette.FOREGROUND
}

mn.VerboseInfoObject = meta.enum("VerboseInfoObject", {
    VSYNC = "vsync",
    VSYNC_WIDGET = "vsync_widget",
    FULLSCREEN = "fullscreen",
    MSAA = "msaa",
    MSAA_WIDGET = "msaa_visualization_widget",
    BLOOM = "bloom",
    SOUND_EFFECT_LEVEL = "sound_effect_level",
    SOUND_EFFECT_LEVEL_WIDGET = "sound_effect_level_widget",
    MUSIC_LEVEL = "music_level",
    MUSIC_LEVEL_WIDGET = "music_level_widget",
    SHAKE_ENABLED = "shake_enabled",
    PERFORMANCE_MODE_ENABLED = "performance_mode_enabled",
    DRAW_DEBUG_INFO_ENABLED = "draw_debug_info_enabled",
    JOYSTICK_DEADZONE = "joystick_deadzone",
    JOYSTICK_DEADZONE_WIDGET = "deadzone_visualization_widget",
    TEXT_SPEED = "text_speed",
    TEXT_SPEED_WIDGET = "text_speed_visualization_widget",
    INPUT_ACTION_A = "input_action_a",
    INPUT_ACTION_B = "input_action_b",
    INPUT_ACTION_X = "input_action_x",
    INPUT_ACTION_Y = "input_action_y",
    INPUT_ACTION_UP = "input_action_up",
    INPUT_ACTION_RIGHT = "input_action_right",
    INPUT_ACTION_DOWN = "input_action_down",
    INPUT_ACTION_LEFT = "input_action_left",
    INPUT_ACTION_START = "input_action_start",
    INPUT_ACTION_SELECT = "input_action_select",
    INPUT_ACTION_L = "input_action_l",
    INPUT_ACTION_R = "input_action_r"
})

--- @class mn.VerboseInfoPanel
mn.VerboseInfoPanel = meta.class("MenuVerboseInfoPanel", rt.Widget)
require "menu.verbose_info_panel_item"

function mn.VerboseInfoPanel:instantiate()
    meta.install(self, {
        _items = {},
        _current_item_i = 0,
        _n_items = 0,
        _y_offset = 0,
        _total_height = 0,
        _frame = rt.Frame(),
        _frame_visible = true,
        _scroll_up_indicator = mn.ScrollIndicator(),
        _scroll_up_indicator_visible = true,
        _scroll_down_indicator = mn.ScrollIndicator(),
        _scroll_down_indicator_visible = true,
        _indicator_up_duration = math.huge,
        _indicator_down_duration = math.huge
    })
end

--- @brief
function mn.VerboseInfoPanel:show(...)
    local to_iterate
    if meta.is_table(select(1, ...)) then
        to_iterate = select(1, ...)
    else
        to_iterate = { ... }
    end

    self._items = {}

    for object in values(to_iterate) do
        local item = mn.VerboseInfoPanel.Item()
        item:create_from(object)
        if self._frame_visible then
            item.frame:set_corner_radius(0)
        else
            item.frame:set_corner_radius(rt.settings.frame.corner_radius)
        end

        item:realize()
        table.insert(self._items, item)
    end

    self._n_items = table.sizeof(self._items)
    self:_set_current_item(self._n_items > 0 and 1 or 0)
    self:reformat()
end

--- @override
function mn.VerboseInfoPanel:realize()
    if self:already_realized() then return end
    self._frame:realize()
end

--- @override
function mn.VerboseInfoPanel:size_allocate(x, y, width, height)
    local frame_thickness = self._frame:get_thickness()
    self._frame:reformat(x + frame_thickness, y + frame_thickness, width - 2 * frame_thickness, height - 2 * frame_thickness)

    local m = rt.settings.margin_unit

    local thickness = rt.settings.margin_unit
    local arrow_width = 6 * m
    local angle = (2 * math.pi) / 3

    self._scroll_up_indicator:reformat(
        x + 0.5 * width, y - thickness,
        angle,
        arrow_width, thickness
    )

    self._scroll_down_indicator:reformat(
        x + 0.5 * width, y + height + thickness,
        (2 * math.pi) - angle,
        arrow_width, thickness
    )

    local item_m = 0
    if not self._frame_visible then item_m = m end

    local current_x, current_y = x, y
    local height_above = 0
    self._total_height = 0
    for i = 1, self._n_items do
        local item = self._items[i]
        item:reformat(current_x, current_y, width, math.huge)
        local h = select(2, item:measure())
        item.height_above = height_above
        item.aabb = rt.AABB(current_x, current_y, width, h)

        height_above = height_above + h
        current_y = current_y + h + item_m
        self._total_height = self._total_height + h + item_m
    end

    self._y_offset = 0
    self:_update_scroll_indicators()
end

--- @override
function mn.VerboseInfoPanel:draw()
    if self._frame_visible then
        self._frame:draw()
        self._frame:bind_stencil()
    end

    love.graphics.push()
    love.graphics.translate(0, self._y_offset)

    for item in values(self._items) do
        if self._frame_visible then
            item.divider:draw()
        else
            item.frame:draw()
        end
        item:draw()
    end

    if self._frame_visible then
        self._frame:unbind_stencil()
    end

    love.graphics.pop()

    if self._scroll_up_indicator_visible then
        self._scroll_up_indicator:draw()
    end

    if self._scroll_down_indicator_visible then
        self._scroll_down_indicator:draw()
    end
end

local _color_mix = function(color_a, color_b, fraction)
    return rt.RGBA(math.mix4(color_a.r, color_a.g, color_a.b, color_a.a, color_b.r, color_b.g, color_b.b, color_b.a, fraction))
end

--- @override
function mn.VerboseInfoPanel:update(delta)
    self._indicator_up_duration = self._indicator_up_duration + delta
    self._indicator_down_duration = self._indicator_down_duration + delta

    local fraction = self._indicator_up_duration / rt.settings.menu.verbose_info_panel.indicator_highlight_duration
    fraction = math.clamp(fraction, 0, 1)
    local color = _color_mix(rt.Palette.SELECTION, rt.settings.menu.verbose_info_panel.indicator_base_color, fraction)

    for shape in range(self._scroll_up_indicator) do
        shape:set_color(color)
    end

    fraction = self._indicator_down_duration / rt.settings.menu.verbose_info_panel.indicator_highlight_duration
    fraction = math.clamp(fraction, 0, 1)
    color = _color_mix(rt.Palette.SELECTION, rt.settings.menu.verbose_info_panel.indicator_base_color, fraction)

    for shape in range(self._scroll_down_indicator) do
        shape:set_color(color)
    end

    for item in values(self._items) do
        if item.update ~= nil then
            item:update(delta)
        end
    end
end

--- @brief
function mn.VerboseInfoPanel:set_selection_state(state)
    meta.assert_enum_value(state, rt.SelectionState)
    self._frame:set_selection_state(state)
end

--- @brief
function mn.VerboseInfoPanel:_update_scroll_indicators()
    self._scroll_up_indicator_visible = self:can_scroll_up()
    self._scroll_down_indicator_visible = self:can_scroll_down()
end

--- @brief [internal]
function mn.VerboseInfoPanel:_set_current_item(i)
    self._current_item_i = i

    if self._current_item_i < 1 or self._current_item_i > self._n_items then
        self._y_offset = 0
    else
        self._y_offset = -1 * self._items[self._current_item_i].height_above
    end

    self:_update_scroll_indicators()
end

--- @brief
function mn.VerboseInfoPanel:scroll_up()
    self._indicator_up_duration = 0
    if self:can_scroll_up() then
        self._current_item_i = self._current_item_i - 1
        self:_set_current_item(self._current_item_i)
        return true
    else
        return false
    end
end

--- @brief
function mn.VerboseInfoPanel:scroll_down()
    local n = table.sizeof(self._items)
    if n < 2 then return false end

    self._indicator_down_duration = 0
    if self:can_scroll_down() then
        self._current_item_i = self._current_item_i + 1
        self:_set_current_item(self._current_item_i)
        return true
    else
        return false
    end
end

--- @brief
function mn.VerboseInfoPanel:can_scroll_up()
    return self._current_item_i > 1 and self._y_offset < 0
end

--- @brief
function mn.VerboseInfoPanel:can_scroll_down()
    local last_item = self._items[self._n_items]
    if last_item == nil then return false end
    return self._current_item_i < self._n_items - 1 and last_item._bounds.y + select(2, last_item:measure()) + self._y_offset > self._bounds.y + self._bounds.height
end

--- @brief
function mn.VerboseInfoPanel:set_has_frame(b)
    self._frame_visible = b
end

--- @brief
function mn.VerboseInfoPanel:measure()
    return self._bounds.width, self._total_height
end