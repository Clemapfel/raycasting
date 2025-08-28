require "common.label"
require "common.font"
require "common.frame"
require "common.input_subscriber"

rt.settings.menu.message_dialog = {
    input_delay = 0.2, -- seconds
    shadow_strength = 0.2
}

mn.MessageDialogOption = meta.enum("MessageDialogOption", {
    ACCEPT = "OK",
    CANCEL = "Cancel"
})

--- @class mn.MessageDialog
mn.MessageDialog = meta.class("MessageDialog", rt.Widget)

--- @param message String
--- @param submessage String
--- @param option1 vararg
--- @signal selection (mn.MessageDialog, Unsigned) -> nil
function mn.MessageDialog:instantiate(message, submessage, option1, ...)
    message = message or " "
    submessage = submessage or " "
    meta.assert(message, "String", submessage, "String")
    meta.assert_enum_value(option1, mn.MessageDialogOption, 3)

    local default_option = 1
    local options = { option1, ... }
    for i, option in ipairs(options) do
        if option == mn.MessageDialogOption.CANCEL then
            default_option = i
            break
        end
    end

    meta.install(self, {
        _message = message,
        _submessage = submessage,
        _options = options,
        _default_option = default_option,

        _selected_item_i = 1,

        _message_label = {}, -- rt.Label
        _submessage_label = {}, -- rt.Label
        _buttons = {},
        _frame = rt.Frame(),

        _render_x_offset = 0,
        _render_y_offset = 0,

        _is_active = false,
        _queue_activate = 0,

        _shadow = rt.AABB(0, 0, 1, 1),
        _shadow_color = rt.settings.menu.message_dialog.shadow_strength,

        _elapsed = 0
    })

    self._n_buttons = 0
    for i, option in ipairs(self._options) do
        meta.assert_enum_value(option, mn.MessageDialogOption)
        if option == mn.MessageDialogOption.CANCEL then
            self._selected_item_i = i
        end
        self._n_buttons = self._n_buttons + 1
    end
end

meta.add_signal(mn.MessageDialog, "selection", "presented", "closed")

--- @override
function mn.MessageDialog:realize()
    if self:already_realized() then return end

    self._frame:realize()

    self._message_label = rt.Label("<b>" .. self._message .. "</b>")
    self._submessage_label = rt.Label(self._submessage, rt.FontSize.SMALL)

    for label in range(self._message_label, self._submessage_label) do
        label:set_justify_mode(rt.JustifyMode.CENTER)
        label:realize()
    end

    self._buttons = {}
    for option in values(self._options) do
        local to_insert = {
            label = rt.Label(option, rt.FontSize.SMALL),
            frame = rt.Frame()
        }

        to_insert.frame:realize()
        to_insert.frame:set_color(rt.Palette.GRAY_3)
        to_insert.label:realize()
        to_insert.label:set_justify_mode(rt.JustifyMode.CENTER)

        table.insert(self._buttons, to_insert)
    end
end

--- @override
function mn.MessageDialog:size_allocate(x, y, width, height)
    local m = rt.settings.margin_unit
    local outer_xm = 4 * m
    local outer_ym = 2 * m
    local button_margin = m
    local button_label_margin = m

    self._message_label:reformat(0, 0, math.huge, math.huge)
    local message_w, message_h = self._message_label:measure()

    self._submessage_label:reformat(0, 0, math.huge, math.huge)
    local submessage_w, submessage_h = self._submessage_label:measure()

    local button_w = 0
    local max_button_w, max_button_h = -math.huge, -math.huge
    for button in values(self._buttons) do
        local label_w, label_h = button.label:measure()
        button_w = button_w + label_w
        max_button_w = math.max(max_button_w, label_w)
        max_button_h = math.max(max_button_h, label_h)
    end

    button_w = button_w + 2 * button_label_margin * self._n_buttons + m * (self._n_buttons - 1)
    button_w = math.max(button_w, message_w, submessage_w)
    button_w = math.min(button_w, width * 2 / 3)

    local start_x, start_y = outer_xm, outer_ym
    local current_x, current_y = start_x, start_y

    self._message_label:reformat(current_x, current_y, button_w, math.huge)
    current_y = current_y + select(2, self._message_label:measure())
    current_y = current_y + m

    self._submessage_label:reformat(current_x, current_y, button_w, math.huge)
    current_y = current_y + select(2, self._submessage_label:measure())
    current_y = current_y + 2 * m

    local frame_thickness = self._frame:get_thickness()
    local item_w = (button_w - (self._n_buttons + 1) * button_margin - (self._n_buttons) * 2 * frame_thickness) / self._n_buttons
    item_w = math.min(item_w, 2 / 3 * button_w)
    local item_m = (button_w - self._n_buttons * item_w) / (self._n_buttons + 1)

    local item_h = max_button_h + 2 * m

    local item_x = outer_xm + item_m
    for item in values(self._buttons) do
        local label_h = select(2, item.label:measure())
        item.label:reformat(item_x, current_y + 0.5 * item_h - 0.5 * label_h, item_w, item_h)
        item.frame:reformat(item_x, current_y, item_w, item_h)
        item_x = item_x + item_w + item_m
    end

    current_y = current_y + item_h

    local frame_w, frame_h = button_w + 2 * outer_xm, (current_y - start_y) + 2 * outer_ym
    self._frame:reformat(start_x - outer_xm, start_y - outer_ym, frame_w, frame_h)

    self._render_x_offset = (x + 0.5 * width - 0.5 * frame_w)
    self._render_y_offset = (y + 0.5 * height - 0.5 * frame_h)
    self._shadow = rt.AABB(x, y, width, height)

    self:_update_selected_item()
end

--- @override
function mn.MessageDialog:draw()
    if self._is_active == false then return end

    love.graphics.push()
    love.graphics.origin()

    rt.graphics.set_blend_mode(rt.BlendMode.MULTIPLY, rt.BlendMode.ADD)
    love.graphics.setColor(self._shadow_color, self._shadow_color, self._shadow_color, 1)
    love.graphics.rectangle("fill", self._shadow:unpack())
    rt.graphics.set_blend_mode()

    love.graphics.translate(math.floor(self._render_x_offset), math.floor(self._render_y_offset))

    self._frame:draw()
    self._message_label:draw()
    self._submessage_label:draw()

    for item in values(self._buttons) do
        item.frame:draw()
        item.label:draw()
    end

    love.graphics.pop()
end

--- @brief
function mn.MessageDialog:_update_selected_item()
    for item_i, item in ipairs(self._buttons) do
        if item_i == self._selected_item_i then
            item.frame:set_selection_state(rt.SelectionState.ACTIVE)
        else
            item.frame:set_selection_state(rt.SelectionState.INACTIVE)
        end
    end
end

--- @brief
function mn.MessageDialog:handle_button(which)
    if self._is_active ~= true then return end

    if self._elapsed < rt.settings.menu.message_dialog.input_delay then
        --return
    end

    if which == rt.InputAction.LEFT then
        if self._selected_item_i > 1 then
            self._selected_item_i = self._selected_item_i - 1
            self:_update_selected_item()
        end
    elseif which == rt.InputAction.RIGHT then
        if self._selected_item_i < table.sizeof(self._buttons) then
            self._selected_item_i = self._selected_item_i + 1
            self:_update_selected_item()
        end
    elseif which == rt.InputAction.A then
        local success = self:signal_try_emit("selection", self._options[self._selected_item_i])
        if not success then self:close() end -- default button behavior
    end
end

--- @brief
function mn.MessageDialog:get_is_active()
    return self._is_active == true or self._queue_activate > 0
end

--- @brief
function mn.MessageDialog:close()
    local before = self._is_active
    self._is_active = false
    if before == true then
        self:signal_emit("closed")
    end
end

--- @brief
function mn.MessageDialog:present()
    self._queue_activate = 2 -- delay input by 2 frames
end

--- @brief
function mn.MessageDialog:set_message(message, submessage, justify)
    if submessage == nil then submessage = self._submessage end
    meta.assert(message, "String", submessage, "String")
    if justify ~= nil then self._message_label:set_justify_mode(justify) end
    self._message_label:set_text(message)

    if self._submessage ~= submessage then
        if justify ~= nil then self._submessage_label:set_justify_mode(justify) end
        self._submessage_label:set_text(submessage)
    end

    if self._is_realized then
        self:reformat()
    end
end

--- @brief
function mn.MessageDialog:set_submessage(submessage, justify)
    meta.assert(submessage, "String")
    if justify ~= nil then self._submessage_label:set_justify_mode(justify) end
    self._submessage_label:set_text(submessage)
    if self._is_realized then
        self:reformat()
    end
end

--- @override
function mn.MessageDialog:update(delta)
    if self._is_active then
        self._elapsed = self._elapsed + delta
    end

    local before = self._is_active
    if self._queue_activate > 0 then
        self._queue_activate = self._queue_activate - 1
        if self._queue_activate == 0 then
            self._is_active = true
            self._selected_item_i = self._default_option
            self:_update_selected_item()

            if before == false then
                self:signal_emit("presented")
            end
        end
    end
end

--- @brief
function mn.MessageDialog:set_default_option(option)
    meta.assert_enum_value(option, mn.MessageDialogOption, 1)

    for i, other in ipairs(self._options) do
        if option == other then
            self._default_option = i
            return
        end
    end

    rt.error("In mn.MessageDialog.set_default_option: dialog has no option `" .. option .. "`")
end