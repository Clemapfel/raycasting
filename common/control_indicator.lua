require "common.frame"
require "common.input_subscriber"
require "common.keybinding_indicator"

--- @class rt.ControlIndicator
rt.ControlIndicator = meta.class("ControlIndicator", rt.Widget)

do -- generate enum for all input buttons
    local enum_values = {
        UP_DOWN = rt.InputButton.UP .. "_" .. rt.InputButton.DOWN,
        LEFT_RIGHT = rt.InputButton.LEFT .. "_" .. rt.InputButton.RIGHT,
        ALL_DIRECTIONS = "ALL_DIRECTIONS"
    }

    for key, button in pairs(meta.instances(rt.InputButton)) do
        enum_values[key] = button
    end

    rt.ControlIndicatorButton = meta.enum("ControlIndicatorButton", enum_values)
end

--- @brief
function rt.ControlIndicator:instantiate(layout, use_frame)
    meta.install(self, {
        _use_frame = use_frame or true,
        _layout = layout or {},
        _keyboard_indicators = {},  -- Table<rt.KeybindingsIndicator>
        _gamepad_indicators = {},   -- Table<rt.KeybindingsIndicator>
        _labels = {},               -- Table<rt.Label>
        _frame = rt.Frame(),

        _opacity = 1,
        _is_allocated = false,
        _final_width = 1,
        _final_height = 1,

        _input = rt.InputSubscriber()
    })
end

--- @brief
function rt.ControlIndicator:_initialize_indicator_from_control_indicator_button(indicator, button, is_keyboard)
    if is_keyboard then
        if button == rt.ControlIndicatorButton.UP_DOWN then
            local up = rt.InputMapping:get_mapping(rt.InputButton.UP, true)
            local down = rt.InputMapping:get_mapping(rt.InputButton.DOWN, true)
            indicator:create_as_two_vertical_keys(
                rt.keyboard_key_to_string(up),
                rt.keyboard_key_to_string(down)
            )
        elseif button == rt.ControlIndicatorButton.LEFT_RIGHT then
            local left = rt.InputMapping:get_mapping(rt.InputButton.LEFT, true)
            local right = rt.InputMapping:get_mapping(rt.InputButton.RIGHT, true)
            indicator:create_as_two_horizontal_keys(
                rt.keyboard_key_to_string(left),
                rt.keyboard_key_to_string(right)
            )
        elseif button == rt.ControlIndicatorButton.ALL_DIRECTIONS then
            local up = rt.InputMapping:get_mapping(rt.InputButton.UP, true)
            local down = rt.InputMapping:get_mapping(rt.InputButton.DOWN, true)
            local left = rt.InputMapping:get_mapping(rt.InputButton.LEFT, true)
            local right = rt.InputMapping:get_mapping(rt.InputButton.RIGHT, true)
            indicator:create_as_four_keys(
                rt.keyboard_key_to_string(up),
                rt.keyboard_key_to_string(right),
                rt.keyboard_key_to_string(down),
                rt.keyboard_key_to_string(left)
            )
        else
            local binding = rt.InputMapping:get_mapping(button, true)
            indicator:create_from_keyboard_key(binding)
        end
    else
        if button == rt.ControlIndicatorButton.UP_DOWN then
            indicator:create_as_dpad(true, false, true, false)
        elseif button == rt.ControlIndicatorButton.LEFT_RIGHT then
            indicator:create_as_dpad(false, true, false, true)
        elseif button == rt.ControlIndicatorButton.ALL_DIRECTIONS then
            indicator:create_as_dpad(false, false, false, false)
        else
            local binding = rt.InputMapping:get_mapping(button, false)
            indicator:create_from_gamepad_button(binding)
        end
    end
end

--- @override
function rt.ControlIndicator:realize()
    if self:already_realized() then return end

    self._frame:realize()
    self:create_from(self._layout)

    self._input:signal_connect("input_mapping_changed", function(_)
        self:create_from(self._layout)
    end)

    self._input:signal_connect("input_method_changed", function(_)
        self:reformat()
    end)
end

--- @brief
function rt.ControlIndicator:create_from(layout)
    self._layout = layout
    self._labels = {}
    self._keyboard_indicators = {}
    self._gamepad_indicators = {}

    for button, text in pairs(self._layout) do
        local keyboard_indicator = rt.KeybindingIndicator()
        local gamepad_indicator = rt.KeybindingIndicator()

        self:_initialize_indicator_from_control_indicator_button(keyboard_indicator, button, true)
        self:_initialize_indicator_from_control_indicator_button(gamepad_indicator, button, false)

        for indicator in range(keyboard_indicator, gamepad_indicator) do
            indicator:realize()
        end

        table.insert(self._keyboard_indicators, keyboard_indicator)
        table.insert(self._gamepad_indicators, gamepad_indicator)

        local prefix, postfix = "<o>", "</o>"
        local label
        if string.find(text, "<o>|</o>|<outline>|</outline>") then
            label = rt.Label(text, rt.settings.font.default, rt.settings.font.default_mono)
        else
            label = rt.Label(prefix .. text .. postfix, rt.settings.font.default, rt.settings.font.default_mono)
        end
        label:realize()
        table.insert(self._labels, label)

        for widget in range(label, keyboard_indicator, gamepad_indicator) do
            widget:set_opacity(self._opacity)
        end
    end

    self:reformat()
end

--- @brief
function rt.ControlIndicator:_get_margin()
    local m = rt.settings.margin_unit
    local outer_xm = self._use_frame and 2 * m or 2 * m
    local outer_ym = self._use_frame and m or m
    local inner_m = 2 * m

    return outer_xm, outer_ym, inner_m
end

--- @override
function rt.ControlIndicator:size_allocate(x, y, width, height)
    local outer_xm , outer_ym, inner_m = self:_get_margin()

    local indicator_size = height
    local use_keyboard = self._input:get_input_method() == rt.InputMethod.KEYBOARD
    local current_x = x + outer_xm
    for i, label in ipairs(self._labels) do
        local indicator
        if use_keyboard then
            indicator = self._keyboard_indicators[i]
        else
            indicator = self._gamepad_indicators[i]
        end

        indicator:reformat(
            current_x, y + 0.5 * height - 0.5 * indicator_size,
            indicator_size, indicator_size
        )
        current_x = current_x + indicator_size + inner_m

        local label_w, label_h = label:measure()
        label:reformat(current_x, y + 0.5 * height - 0.5 * label_h, math.huge)

        if i == #self._labels then
            current_x = current_x + label_w + outer_xm
        else
            current_x = current_x + label_w + inner_m
        end
    end

    self._final_height = height
    self._final_width = current_x - x
    self._is_allocated = true
    self._frame:reformat(x, y, self._final_width, self._final_height)
end

--- @override
function rt.ControlIndicator:measure()
    local outer_xm , outer_ym, inner_m = self:_get_margin()

    local max_h = -math.huge
    local n_indicators = 0
    local width_sum = outer_xm
    for i, label in ipairs(self._labels) do
        n_indicators = n_indicators + 1

        local label_w, label_h = label:measure()
        max_h = math.max(label_h, max_h)

        if i == #self._labels then
            width_sum = width_sum + label_w + 1 * inner_m + outer_xm
        else
            width_sum = width_sum + label_w + 2 * inner_m
        end
    end

    local indicator_size = max_h + 2 * outer_ym
    local width = width_sum + n_indicators * indicator_size
    local height = max_h + 2 * outer_ym
    return width, height
end

--- @override
function rt.ControlIndicator:draw()
    local use_keyboard = self._input:get_input_method() == rt.InputMethod.KEYBOARD

    if self._use_frame then
        self._frame:draw()
    end

    for i = 1, #self._labels do
        local keyboard_indicator, gamepad_indicator, label = self._keyboard_indicators[i], self._gamepad_indicators[i], self._labels[i]
        if use_keyboard then
            keyboard_indicator:draw()
        else
            gamepad_indicator:draw()
        end

        label:draw()
    end
end

--- @override
function rt.ControlIndicator:set_opacity(alpha)
    self._opacity = alpha
    for i = 1, #self._labels do
        for widget in range(self._keyboard_indicators[i], self._gamepad_indicators[i], self._labels[i]) do
            widget:set_opacity(alpha)
        end
    end
end

--- @brief
function rt.ControlIndicator:set_selection_state(state)
    local current = self._frame:get_selection_state()
    if state ~= current then
        self._frame:set_selection_state(state)
    end
end

--- @brief
function rt.ControlIndicator:set_use_frame(b)
    self._use_frame = b
    if self:get_is_realized() then
        self:reformat()
    end
end



