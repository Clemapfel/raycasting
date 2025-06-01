require "common.scene"
require "common.keybinding_indicator"
require "common.control_indicator"
require "menu.message_dialog"
require "menu.verbose_info_panel"
require "menu.settings_scene"

rt.settings.keybinding_scene = {
    spacer_width = 3
}

--- @class mn.KeybindingScene
mn.KeybindingScene = meta.class("KeybindingsScene", rt.Scene)

--- @class mn.KeybindingScene.Item
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
    self.spacer_outline:draw()
    self.spacer:draw()
end

local _ellipses = "\u{2026}"

--- @brief
function mn.KeybindingScene:instantiate()
    local translation = rt.Translation.keybinding_scene
    self._control_indicator = rt.ControlIndicator(
        rt.ControlIndicatorButton.UP_DOWN, translation.control_indicator_move,
        rt.ControlIndicatorButton.A, translation.control_indicator_select,
        rt.ControlIndicatorButton.B, translation.control_indicator_back,
        rt.ControlIndicatorButton.Y, translation.control_indicator_reset_to_default
    )

    self._heading_label = rt.Label("<b>" .. translation.heading .. "</b>")
    self._heading_label_frame = rt.Frame()

    self._confirm_exit_dialog = mn.MessageDialog(
        translation.confirm_exit_message,
        translation.confirm_exit_submessage,
        mn.MessageDialogOption.ACCEPT, mn.MessageDialogOption.CANCEL
    )

    self._confirm_reset_to_default_dialog = mn.MessageDialog(
        translation.confirm_reset_to_default_message,
        translation.confirm_reset_to_default_submessage,
        mn.MessageDialogOption.ACCEPT, mn.MessageDialogOption.CANCEL
    )

    self._keybinding_invalid_dialog = mn.MessageDialog(
        translation.keybinding_invalid_message,
        "", -- set on check,
        mn.MessageDialogOption.CANCEL
    )

    self._verbose_info = mn.VerboseInfoPanel()
    self._list = mn.ScrollableList()

    -- items

    local input_action_order = {
        rt.InputAction.A,
        rt.InputAction.B,
        rt.InputAction.X,
        rt.InputAction.Y,
        rt.InputAction.UP,
        rt.InputAction.RIGHT,
        rt.InputAction.DOWN,
        rt.InputAction.LEFT,
        rt.InputAction.L,
        rt.InputAction.R,
        rt.InputAction.START,
        rt.InputAction.SELECT
    }

    local input_action_to_verbose_info = {
        [rt.InputAction.A] = mn.VerboseInfoObject.INPUT_ACTION_A,
        [rt.InputAction.B] = mn.VerboseInfoObject.INPUT_ACTION_B,
        [rt.InputAction.X] = mn.VerboseInfoObject.INPUT_ACTION_X,
        [rt.InputAction.Y] = mn.VerboseInfoObject.INPUT_ACTION_Y,
        [rt.InputAction.L] = mn.VerboseInfoObject.INPUT_ACTION_L,
        [rt.InputAction.R] = mn.VerboseInfoObject.INPUT_ACTION_R,
        [rt.InputAction.START] = mn.VerboseInfoObject.INPUT_ACTION_START,
        [rt.InputAction.SELECT] = mn.VerboseInfoObject.INPUT_ACTION_SELECT,
        [rt.InputAction.UP] = mn.VerboseInfoObject.INPUT_ACTION_UP,
        [rt.InputAction.RIGHT] = mn.VerboseInfoObject.INPUT_ACTION_RIGHT,
        [rt.InputAction.DOWN] = mn.VerboseInfoObject.INPUT_ACTION_DOWN,
        [rt.InputAction.LEFT] = mn.VerboseInfoObject.INPUT_ACTION_LEFT,
    }

    local prefix_prefix, prefix_postfix = "<b>", "</b>"

    local scene = self
    for input_action in values(input_action_order) do
        local prefix = rt.Translation.input_action_to_string(input_action)
        local info = input_action_to_verbose_info[input_action]
        assert(prefix ~= nil, input_action)
        assert(info ~= nil, input_action)

        local item = mn.KeybindingScene.Item({
            prefix = rt.Label(prefix_prefix .. prefix .. prefix_postfix),
            input_action = input_action,
            keyboard_indicator = rt.KeybindingIndicator(),
            keyboard_key = nil,
            controller_indicator = rt.KeybindingIndicator(),
            controller_button = nil,
            spacer = rt.Rectangle(),
            spacer_outline = rt.Rectangle(),
            info = info,
        })

        item.spacer_outline:set_color(rt.Palette.BLACK)
        item.spacer:set_color(rt.Palette.FOREGROUND)
        for space in range(item.spacer, item.spacer_outline) do
            item.spacer:set_corner_radius(2)
        end

        item.set_selection_state = function(self, state)
            if state == rt.SelectionState.ACTIVE then
                scene._verbose_info:show(item.info)
            end
        end

        item.set_keyboard_indicator = function(self, key)
            if key == nil then
                self.keyboard_indicator:create_as_label(_ellipses)
            else
                self.keyboard_indicator:create_from_keyboard_key(key)
                self.keyboard_key = key
            end
        end

        item.set_controller_indicator = function(self, button)
            if button == nil then
                self.controller_indicator:create_as_label(_ellipses)
            else
                self.controller_indicator:create_from_gamepad_button(button)
                self.controller_button = button
            end
        end

        self._list:add_item(item)
    end

    self:_update_all_indicators()

    -- input
    self._listening_active = false
    self._listening_item = nil
    self._skip_n_input_frames = 0

    self._scroll_elapsed = 0
    self._scroll_delay_elapsed = 0
    self._scroll_active = false
    self._scroll_direction = nil

    for dialog in range(
        self._confirm_exit_dialog,
        self._confirm_reset_to_default_dialog
    ) do
        dialog:signal_connect("presented", function()
            self._input:deactivate()
            self:_abort_listening()
        end)

        dialog:signal_connect("closed", function()
            self._input:activate()
        end)
    end

    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        if self._listening_active or self._skip_n_input_frames > 0 then return end

        if which == rt.InputAction.UP then
            if self._list:can_scroll_up() then
                self._list:scroll_up()
                self._scroll_active = true
                self._scroll_delay_elapsed = 0
                self._scroll_elapsed = 0
                self._scroll_direction = rt.Direction.UP
            end
        elseif which == rt.InputAction.DOWN then
            if self._list:can_scroll_down() then
                self._list:scroll_down()
                self._scroll_active = true
                self._scroll_delay_elapsed = 0
                self._scroll_elapsed = 0
                self._scroll_direction = rt.Direction.DOWN
            end
        elseif which == rt.InputAction.A then
            if not self._listening_active then
                self._listening_active = true
                self._listening_item = self._list:get_selected_item()

                if self._input:get_input_method() == rt.InputMethod.KEYBOARD then
                    self._listening_item:set_keyboard_indicator(nil)
                elseif self._input:get_input_method() == rt.InputMethod.CONTROLLER then
                    self._listening_item:set_controller_indicator(nil)
                end
            end
        elseif which == rt.InputAction.Y then
            self._confirm_reset_to_default_dialog:signal_connect("selection", function(dialog, option)
                if option == mn.MessageDialogOption.ACCEPT then
                    self:_update_all_indicators()
                end
                dialog:close()
                return meta.DISCONNECT_SIGNAL
            end)

            self._confirm_reset_to_default_dialog:present()
        elseif which == rt.InputAction.B then
            -- TODO: ask for confirm, then change scene
        end
    end)

    self._input:signal_connect("left_joystick_moved", function(_, x, y)
        if y > 0 then
            if self._scroll_active == false then
                self._scroll_active = true
                self._scroll_delay_elapsed = math.huge
                self._scroll_elapsed = 1 / rt.settings.settings_scene.scroll_ticks_per_second
            end

            self._scroll_direction = rt.Direction.DOWN
        elseif y < 0 then
            if self._scroll_active == false then
                self._scroll_active = true
                self._scroll_delay_elapsed = math.huge
                self._scroll_elapsed = 1 / rt.settings.settings_scene.scroll_ticks_per_second
            end

            self._scroll_direction = rt.Direction.UP
        else
            self._scroll_active = false
        end
    end)

    self._input:signal_connect("released", function(_, which)
        if which == rt.InputAction.UP or which == rt.InputAction.DOWN then
            self._scroll_active = false
        end
    end)

    self._input:signal_connect("input_method_changed", function(_, new)
        self:_abort_listening()
    end)

    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if not self._listening_active then return end
        self._listening_item:set_keyboard_indicator(which)
        self._listening_active = false
        self._skip_n_input_frames = 3
    end)

    self._input:signal_connect("controller_button_pressed", function(_, which)
        if not self._listening_active then return end
        self._listening_item:set_controller_indicator(which)
        self._listening_active = false
        self._skip_n_input_frames = 3
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

    self._confirm_exit_dialog:reformat(0, 0, width, height)
    self._confirm_reset_to_default_dialog:reformat(0, 0, width, height)

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

    for i = 1, self._list:get_n_items() do
        local item = self._list:get_item(i)
        item.size_allocate = function(self, x, y, width, height)
            local prefix_w, prefix_h = self.prefix:measure()

            self.prefix:reformat(
                x + item_outer_margin,
                y + 0.5 * height - 0.5 * prefix_h,
                math.huge, math.huge
            )

            local widget_w, widget_h = height, height

            local widget_left_x = x + item_outer_margin + max_prefix_w + m
            local widget_right_x = x + width - item_outer_margin
            local widget_area_w = widget_right_x - widget_left_x
            local widget_margin = (widget_area_w - 2 * widget_w) / (2 + 1)

            self.keyboard_indicator:reformat(
                widget_left_x + widget_margin,
                y + 0.5 * height - 0.5 * widget_h,
                widget_w,
                widget_h
            )

            self.controller_indicator:reformat(
                widget_right_x - widget_margin - widget_w,
                y + 0.5 * height - 0.5 * widget_h,
                widget_w,
                widget_h
            )

            self.spacer:reformat(
                widget_left_x + 0.5 * widget_area_w,
                y + m,
                rt.settings.keybinding_scene.spacer_width * rt.get_pixel_scale(),
                height - 2 * m
            )

            self.spacer_outline:reformat(
                widget_left_x + 0.5 * widget_area_w - 1,
                y + m,
                rt.settings.keybinding_scene.spacer_width * rt.get_pixel_scale() + 2,
                height - 2 * m
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
    if self._skip_n_input_frames > 0 then self._skip_n_input_frames = self._skip_n_input_frames - 1 end

    for widget in range(
        self._confirm_reset_to_default_dialog,
        self._confirm_exit_dialog
    ) do
        widget:update(delta)
    end

    if self._scroll_active then
        self._scroll_delay_elapsed = self._scroll_delay_elapsed + delta
        if self._scroll_delay_elapsed > rt.settings.settings_scene.scroll_delay then
            self._scroll_elapsed = self._scroll_elapsed + delta
            local step = 1 / rt.settings.settings_scene.scroll_ticks_per_second
            while self._scroll_elapsed > step do
                self._scroll_elapsed = self._scroll_elapsed - step
                if self._scroll_direction == rt.Direction.UP then
                    self._list:scroll_up()
                elseif self._scroll_direction == rt.Direction.DOWN then
                    self._list:scroll_down()
                end
            end
        end
    end
end

--- @brief
function mn.KeybindingScene:_update_all_indicators()
    for i = 1, self._list:get_n_items() do
        local item = self._list:get_item(i)
        item:set_keyboard_indicator(rt.GameState:get_input_mapping(item.input_action, rt.InputMethod.KEYBOARD)[1])
        item:set_controller_indicator(rt.GameState:get_input_mapping(item.input_action, rt.InputMethod.CONTROLLER)[1])
    end

    if self:get_is_realized() then self:reformat() end
end

--- @brief
function mn.KeybindingScene:_abort_listening()
    if self._listening_active == false then return end
    local item = self._listening_item
    item:set_keyboard_indicator(item.keyboard_key)
    item:set_controller_indicator(item.controller_button)
    self._listening_active = false
end

--- @brief
function mn.KeybindingScene:draw()
    self._heading_label_frame:draw()
    self._heading_label:draw()
    self._verbose_info:draw()
    self._list:draw()
    self._control_indicator:draw()

    self._confirm_reset_to_default_dialog:draw()
    self._confirm_exit_dialog:draw()
end

--- @brief
function mn.KeybindingScene:enter()
    self._input:activate()
end

--- @brief
function mn.KeybindingScene:exit()
    self._input:activate()
    self:_abort_listening()
end
