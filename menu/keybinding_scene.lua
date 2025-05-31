require "common.scene"
require "common.keybinding_indicator"
require "common.control_indicator"
require "menu.message_dialog"
require "menu.verbose_info_panel"
require "menu.settings_scene"

--- @class mn.KeybindingScene
mn.KeybindingScene = meta.class("KeybindingsScene", rt.Scene)

mn.InputAction = meta.enum("InputAction", {
    A = "a",
    B = "b",
    X = "x",
    Y = "y",
    UP = "up",
    RIGHT = "right",
    DOWN = "down",
    LEFT = "left",
    START = "start",
    L = "l",
    R = "r"
})

--- @brief
function mn.KeybindingScene:instantiate()
    local translation = rt.Translation.keybinding_scene
    self._control_indicator = rt.ControlIndicator(
        rt.ControlIndicatorButton.UP_DOWN, translation.control_indicator_move,
        rt.ControlIndicatorButton.A, translation.control_indicator_select,
        rt.ControlIndicatorButton.B, translation.control_indicator_back,
        rt.ControlIndicatorButton.X, translation.control_indicator_start_sequence,
        rt.ControlIndicatorButton.Y, translation.control_indicator_reset_to_default
    )

    self._heading_label = rt.Label("<b>" .. translation.heading .. "</b>")
    self._heading_label_frame = rt.Frame()

    self._confirm_exit_dialog = mn.MessageDialog(
        translation.confirm_exit_message,
        translation.confirm_exit_submessage,
        mn.MessageDialog.ACCEPT, mn.MessageDialog.CANCEL
    )

    self._confirm_reset_to_default_dialog = mn.MessageDialog(
        translation.confirm_reset_to_default_message,
        translation.confirm_rest_to_default_submessage,
        mn.MessageDialog.ACCEPT, mn.MessageDialog.CANCEL
    )

    self._keybinding_invalid_dialog = mn.MessageDialog(
        translation.keybinding_invalid_message,
        "", -- set on check,
        mn.MessageDialog.CANCEL
    )

    self._verbose_info = mn.VerboseInfoPanel()
    self._scrollbar = mn.Scrollbar()

    -- items

    local input_button_to_input_action = {
        [rt.InputButton.A] = mn.InputAction.A,
        [rt.InputButton.B] = mn.InputAction.B,
        [rt.InputButton.X] = mn.InputAction.X,
        [rt.InputButton.Y] = mn.InputAction.Y,
        [rt.InputButton.L] = mn.InputAction.L,
        [rt.InputButton.R] = mn.InputAction.R,
        [rt.InputButton.START] = mn.InputAction.START,
        [rt.InputButton.UP] = mn.InputAction.UP,
        [rt.InputButton.RIGHT] = mn.InputAction.RIGHT,
        [rt.InputButton.DOWN] = mn.InputAction.DOWN,
        [rt.InputButton.LEFT] = mn.InputAction.LEFT,
    }

    local input_action_to_input_button = {}
    for key, value in pairs(input_button_to_input_action) do input_action_to_input_button[value] = key end

    local input_action_to_verbose_info = {
        [mn.InputAction.A] = mn.VerboseInfoObject.INPUT_ACTION_A,
        [mn.InputAction.B] = mn.VerboseInfoObject.INPUT_ACTION_B,
        [mn.InputAction.X] = mn.VerboseInfoObject.INPUT_ACTION_X,
        [mn.InputAction.Y] = mn.VerboseInfoObject.INPUT_ACTION_Y,
        [mn.InputAction.L] = mn.VerboseInfoObject.INPUT_ACTION_L,
        [mn.InputAction.R] = mn.VerboseInfoObject.INPUT_ACTION_R,
        [mn.InputAction.START] = mn.VerboseInfoObject.INPUT_ACTION_START,
        [mn.InputAction.UP] = mn.VerboseInfoObject.INPUT_ACTION_UP,
        [mn.InputAction.RIGHT] = mn.VerboseInfoObject.INPUT_ACTION_RIGHT,
        [mn.InputAction.DOWN] = mn.VerboseInfoObject.INPUT_ACTION_DOWN,
        [mn.InputAction.LEFT] = mn.VerboseInfoObject.INPUT_ACTION_LEFT,
    }

    local input_action_to_translation = {
        [mn.InputAction.A] = translation.a_prefix,
        [mn.InputAction.B] = translation.b_prefix,
        [mn.InputAction.X] = translation.x_prefix,
        [mn.InputAction.Y] = translation.y_prefix,
        [mn.InputAction.L] = translation.l_prefix,
        [mn.InputAction.R] = translation.r_prefix,
        [mn.InputAction.START] = translation.start_prefix,
        [mn.InputAction.UP] = translation.up_prefix,
        [mn.InputAction.RIGHT] = translation.right_prefix,
        [mn.InputAction.DOWN] = translation.down_prefix,
        [mn.InputAction.LEFT] = translation.left_prefix,
    }

    local prefix_prefix, prefix_postfix = "<b>", "</b>"

    self._items = {}
    self._n_items = 0
    for input_button, input_action in pairs(input_button_to_input_action) do
        local prefix = input_action_to_translation[input_action]
        local to_assign = input_action_to_input_button[input_action]
        local info = input_action_to_verbose_info[input_action]
        assert(to_assign ~= nil, input_action)
        assert(prefix ~= nil, input_action)
        assert(info ~= nil, input_action)

        local item = {
            prefix = rt.Label(prefix_prefix .. prefix .. prefix_postfix),
            to_assign = to_assign,
            indicator = rt.KeybindingIndicator(),
            frame = rt.Frame(),
            selected_frame = rt.Frame(),
            info = info,
            height_above = 0
        }

        item.selected_frame:set_selection_state(rt.SelectionState.ACTIVE)
        table.insert(self._items, item)
        self._n_items = self._n_items + 1
    end

    self._scrollbar:set_n_pages(self._n_items)
    self._item_stencil = rt.AABB()

    -- input

    self._selected_item_i = 1
    self._item_y_offset = 0
    self._max_item_y_offset = math.huge

    self._scroll_elapsed = 0
    self._scroll_delay_elapsed = 0
    self._scroll_active = false
    self._scroll_direction = nil

    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        self._scale_active = false

        if which == rt.InputButton.UP then
            if self._selected_item_i == 1 then
                self:_set_selected_item(self._n_items)
            elseif self:_can_scroll_up() then
                self:_set_selected_item(self._selected_item_i - 1)
                self._scroll_active = true
                self._scroll_delay_elapsed = 0
                self._scroll_elapsed = 0
                self._scroll_direction = rt.Direction.UP
            end
        elseif which == rt.InputButton.DOWN then
            if self._selected_item_i == self._n_items then
                self:_set_selected_item(1)
            elseif self:_can_scroll_down() then
                self:_set_selected_item(self._selected_item_i + 1)
                self._scroll_active = true
                self._scroll_delay_elapsed = 0
                self._scroll_elapsed = 0
                self._scroll_direction = rt.Direction.DOWN
            end
        elseif which == rt.InputButton.A then
            -- TODO: start keybinding
        elseif which == rt.InputButton.Y then
            -- TODO: show dialog, restore default
        elseif which == rt.InputButton.X then
            -- TODO: do serial keybind
        elseif which == rt.InputButton.B then
            -- TODO: ask for confirm, then change scene
        end
    end)

    self._input:signal_connect("released", function(_, which)
        if which == rt.InputButton.UP or which == rt.InputButton.DOWN then
            self._scroll_active = false
        end
    end)
end

--- @brief
function mn.KeybindingScene:realize()
    for widget in range(
        self._control_indicator,
        self._heading_label,
        self._heading_label_frame,
        self._confirm_exit_dialog,
        self._confirm_reset_to_default_dialog,
        self._keybinding_invalid_dialog,
        self._verbose_info,
        self._scrollbar
    ) do
        widget:realize()
    end

    for item in values(self._items) do
        for widget in range(
            item.prefix,
            item.indicator,
            item.frame,
            item.selected_frame
        ) do
            widget:realize()
        end
    end
end

--- @brief
function mn.KeybindingScene:size_allocate(x, y, width, height)
    local m = rt.settings.margin_unit
    local outer_margin = 2 * m
    local item_outer_margin = 2 * m
    local item_y_padding = m
    local item_y_margin = m
    local item_inner_margin = 4 * m

    local max_prefix_w, max_prefix_h = -math.huge, -math.huge
    for item in values(self._items) do
        local prefix_w, prefix_h = item.prefix:measure()
        max_prefix_h = math.max(max_prefix_h, prefix_h)
    end

    local control_w, control_h = self._control_indicator:measure()
    local heading_w, heading_h = self._heading_label:measure()

    local left_x, top_y = x + outer_margin, y + outer_margin
    local heading_frame_h = math.max(heading_h + 2 * item_y_padding, control_h)
    self._heading_label_frame:reformat(left_x, top_y, heading_w + 2 * item_outer_margin, heading_frame_h)
    self._heading_label:reformat(left_x + item_outer_margin, top_y + 0.5 * heading_frame_h - 0.5 * heading_h, math.huge)

    self._control_indicator:reformat(x + width - outer_margin - control_w, top_y, control_w, control_h)

    local current_x, current_y = left_x, top_y + heading_frame_h + item_y_margin

    local verbose_info_w = (width - 2 * outer_margin) * rt.settings.settings_scene.verbose_info_width_fraction
    local verbose_info_h = height - 2 * outer_margin - heading_frame_h - item_y_margin
    self._verbose_info:reformat(
        x + width - outer_margin - verbose_info_w, current_y,
        verbose_info_w, verbose_info_h
    )

    local scrollbar_w = rt.settings.settings_scene.scrollbar_width_factor * rt.settings.margin_unit
    self._scrollbar:reformat(
        x + width - outer_margin - verbose_info_w - item_y_margin - scrollbar_w,
        current_y,
        scrollbar_w,
        verbose_info_h
    )

    local frame_thickness = rt.settings.frame.thickness

    self._item_stencil:reformat(
        current_x,
        current_y,
        width - 2 * outer_margin - verbose_info_w - item_y_margin,
        verbose_info_h
    )

    local item_h = math.max(
        max_prefix_h,
        control_h,
        verbose_info_h / self._n_items
    )

    item_h = verbose_info_h / math.ceil(verbose_info_h / item_h)
    item_h = item_h - ((self._n_items - 1) * item_y_margin) / self._n_items

    local item_w = width - 2 * outer_margin - verbose_info_w - item_outer_margin - scrollbar_w
    local widget_w = item_w - 2 * item_outer_margin - item_inner_margin - max_prefix_w

    local height_above = 0
    local total_height = 0
    for item in values(self._items) do
        for frame in range(
            item.frame,
            item.selected_frame
        ) do
            frame:reformat(left_x + frame_thickness, current_y + frame_thickness, item_w - 2 * frame_thickness, item_h - 2 * frame_thickness)
        end

        local prefix_w, prefix_h = item.prefix:measure()
        item.prefix:reformat(
            left_x + item_outer_margin,
            current_y + 0.5 * item_h - 0.5 * prefix_h,
            math.huge, math.huge
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
    self._max_item_y_offset = total_height - verbose_info_h
    self:_set_selected_item(self._selected_item_i)
end

--- @brief
function mn.KeybindingScene:update(delta)

end

--- @brief
function mn.KeybindingScene:draw()
    self._heading_label_frame:draw()
    self._heading_label:draw()
    self._verbose_info:draw()

    love.graphics.setScissor(self._item_stencil:unpack())
    love.graphics.push()
    love.graphics.translate(0, self._item_y_offset)

    for i, item in ipairs(self._items) do
        if i == self._selected_item_i then
            item.selected_frame:draw()
        else
            item.frame:draw()
        end

        item.prefix:draw()
        item.indicator:draw()
    end

    love.graphics.pop()
    love.graphics.setScissor()

    self._scrollbar:draw()
    self._control_indicator:draw()
end

--- @brief
function mn.KeybindingScene:enter()

end

--- @brief
function mn.KeybindingScene:exit()

end
--- @brief
function mn.KeybindingScene:_set_selected_item(i)
    self._selected_item_i = i

    local item = self._items[self._selected_item_i]
    if item.y > self._item_stencil.y + self._item_stencil.height then
        self._item_y_offset = -1 * math.min(item.height_above, self._max_item_y_offset)
    else
        self._item_y_offset = 0
    end

    self._verbose_info:show(item.info)
    self._scrollbar:set_page_index(self._selected_item_i)
end

--- @brief
function mn.KeybindingScene:_can_scroll_up()
    return self._selected_item_i > 1
end

--- @brief
function mn.KeybindingScene:_can_scroll_down()
    return self._selected_item_i < self._n_items
end

