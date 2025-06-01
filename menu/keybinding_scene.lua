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

mn.KeybindingScene.Item = meta.class("KeybindingsSceneItem", rt.Widget)

--- @brief [internal]
function mn.KeybindingScene.Item:instantiate(t)
    meta.install(self, t)
end

--- @brief [internal]
function mn.KeybindingScene.Item:realize()
    self.prefix:realize()
    self.controller_indicator:realize()
    self.keyboard_indicator:realize()
end

--- @brief [internal]
function mn.KeybindingScene.Item:draw()
    self.prefix:draw()
    self.controller_indicator:draw()
    self.keyboard_indicator:draw()
end

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
    self._list = mn.ScrollableList()

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

    local scene = self
    for input_button, input_action in pairs(input_button_to_input_action) do
        local prefix = input_action_to_translation[input_action]
        local to_assign = input_action_to_input_button[input_action]
        local info = input_action_to_verbose_info[input_action]
        assert(to_assign ~= nil, input_action)
        assert(prefix ~= nil, input_action)
        assert(info ~= nil, input_action)

        local item = mn.KeybindingScene.Item({
            prefix = rt.Label(prefix_prefix .. prefix .. prefix_postfix),
            to_assign = to_assign,
            keyboard_indicator = rt.KeybindingIndicator(),
            controller_indicator = rt.KeybindingIndicator(),
            info = info,
        })

        item.set_selection_state = function(self, state)
            if state == rt.SelectionState.ACTIVE then
                scene._verbose_info:show(item.info)
            end
        end

        item.set_keyboard_indicator = function(self, key)
            self.keyboard_indicator:create_from_keyboard_key(key)
        end

        item.set_controller_indicator = function(self, button)
            self.control_indicator:create_from_gamepad_button(button)
        end

        self._list:add_item(item)
    end

    self:_update_all_indicators()

    -- input
    self._listening_active = false
    self._listening_item = nil

    self._scroll_elapsed = 0
    self._scroll_delay_elapsed = 0
    self._scroll_active = false
    self._scroll_direction = nil

    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        if self._listening_active then return end

        if which == rt.InputButton.UP then
            if self._list:can_scroll_up() then
                self._list:scroll_up()
                self._scroll_active = true
                self._scroll_delay_elapsed = 0
                self._scroll_elapsed = 0
                self._scroll_direction = rt.Direction.UP
            end
        elseif which == rt.InputButton.DOWN then
            if self._list:can_scroll_down() then
                self._list:scroll_down()
                self._scroll_active = true
                self._scroll_delay_elapsed = 0
                self._scroll_elapsed = 0
                self._scroll_direction = rt.Direction.DOWN
            end
        elseif which == rt.InputButton.A then
            if not self._listening_active then
                self._listening_active = true
                self._listening_item = self._list:get_selected_item()
            end
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

    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if not self._listening_active then return end
        self._listening_item:set_keyboard_indicator(which)
    end)

    self._input:signal_connect("controller_button_pressed", function(_, which)
        if not self._listening_active then return end
        self._listening_item:set_controller_indicator(which)
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
        self._scrollbar,
        self._list
    ) do
        widget:realize()
    end
end

--- @brief
function mn.KeybindingScene:size_allocate(x, y, width, height)
    local m = rt.settings.margin_unit
    local outer_margin = 2 * m
    local item_outer_margin = 2 * m

    local control_w, control_h = self._control_indicator:measure()

    local heading_w, heading_h = self._heading_label:measure()
    local left_x, top_y = x + outer_margin, y + outer_margin
    local heading_frame_h = math.max(heading_h + 2 * m, control_h)
    self._heading_label_frame:reformat(left_x, top_y, heading_w + 2 * item_outer_margin, heading_frame_h)
    self._heading_label:reformat(left_x + item_outer_margin, top_y + 0.5 * heading_frame_h - 0.5 * heading_h, math.huge)

    local current_x, current_y = left_x, top_y + heading_frame_h + m
    self._control_indicator:reformat(
        x + width - outer_margin - control_w, top_y,
        control_w, control_h
    )

    local verbose_info_w = (width - 2 * outer_margin) * rt.settings.settings_scene.verbose_info_width_fraction
    local verbose_info_h = height - 2 * outer_margin - heading_frame_h - m
    self._verbose_info:reformat(
        x + width - outer_margin - verbose_info_w, current_y, verbose_info_w, verbose_info_h
    )

    local max_prefix_w = -math.huge
    for i = 1, self._list:get_n_items() do
        local item = self._list:get_item(i)
        local prefix_w, prefix_h = item.prefix:measure()
        max_prefix_w = math.max(max_prefix_w, prefix_w)
    end

    local list_w = width - 2 * outer_margin - verbose_info_w - m
    local widget_w = list_w - 2 * item_outer_margin - max_prefix_w
    widget_w = widget_w / 2

    for i = 1, self._list:get_n_items() do
        local item = self._list:get_item(i)
        item.size_allocate = function(self, x, y, width, height)
            local prefix_w, prefix_h = self.prefix:measure()

            self.prefix:reformat(
                x + item_outer_margin,
                y + 0.5 * height - 0.5 * prefix_h,
                math.huge, math.huge
            )

            self.keyboard_indicator:reformat(
                x + item_outer_margin + prefix_w,
                y,
                widget_w,
                prefix_h
            )

            self.controller_indicator:reformat(
                x + item_outer_margin + prefix_w + widget_w,
                y,
                widget_w,
                prefix_h
            )

        end

        item.measure = function(self)
            local prefix_w, prefix_h = self.prefix:measure()
            return prefix_w + 2 * outer_margin, 2 * prefix_h + 2 * m
        end
    end

    self._list:reformat(
        current_x, current_y,
        list_w,
        verbose_info_h
    )
end

--- @brief
function mn.KeybindingScene:update(delta)

end

--- @brief
function mn.KeybindingScene:_update_all_indicators()
    for item in values(self._items) do
        item:set_keyboard_indicator(rt.InputMapping:get_reverse_mapping())
    end
end

--- @brief
function mn.KeybindingScene:draw()
    self._heading_label_frame:draw()
    self._heading_label:draw()
    self._verbose_info:draw()
    self._list:draw()
    self._control_indicator:draw()
end

--- @brief
function mn.KeybindingScene:enter()
    self._listening_active = false
    self._input:activate()
end

--- @brief
function mn.KeybindingScene:exit()
    self._listening_active = false
    self._input:activate()
end
