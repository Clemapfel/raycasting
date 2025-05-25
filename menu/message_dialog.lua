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
    local out = meta.install(self, {
        _message = message,
        _submessage = submessage,
        _options = {option1, ...},

        _selected_item_i = 1,

        _message_label = {}, -- rt.Label
        _submessage_label = {}, -- rt.Label
        _buttons = {},
        _frame = rt.Frame(),

        _render_x_offset = 0,
        _render_y_offset = 0,

        _is_active = false,
        _queue_deactivate = 0,
        _queue_activate = 0,

        _input = rt.InputSubscriber(),

        _shadow = rt.AABB(0, 0, 1, 1),
        _shadow_color = rt.settings.menu.message_dialog.shadow_strength,

        _elapsed = 0
    })

    meta.assert(out._message, "String", out._submessage, "String")
    for i, option in ipairs(out._options) do
        assert(meta.typeof(option) == "String", "In mn.MessageDialog: option `" .. option .. "` is not a string")
        if option == mn.MessageDialogOption.CANCEL then
            out._selected_item_i = i
        end
    end

    return out
end

meta.add_signal(mn.MessageDialog, "selection")

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

    self._input:signal_connect("pressed", function(_, which)
        self:_handle_button_pressed(which)
    end)
end

--- @override
function mn.MessageDialog:size_allocate(x, y, width, height)
    local m = rt.settings.margin_unit

    local max_w = -math.huge
    local max_h = -math.huge
    for item in values(self._buttons) do
        local label_w, label_h = item.label:measure()
        max_w = math.max(max_w, label_w)
        max_h = math.max(max_h, label_h)
    end

    local n_buttons = table.sizeof(self._buttons)
    local title_label_w, title_label_h = self._message_label:measure()
    max_w = math.max(max_w, title_label_w / n_buttons)
    max_w = math.max(max_w, width / 4 / n_buttons)

    local item_w = max_w + 4 * m
    local item_h = max_h + 1.5 * m

    local button_w = n_buttons * item_w + (n_buttons - 1) * m

    self._message_label:reformat(0, 0, button_w)
    self._submessage_label:reformat(0, 0, button_w)

    local sub_label_w, sub_label_h = self._submessage_label:measure()

    local xm, ym = 4 * m, 2 * m
    local start_x, start_y = xm, ym
    local current_x, current_y = start_x, start_y
    self._message_label:reformat(current_x, current_y, button_w, title_label_h)
    current_y = current_y + title_label_h + m
    self._submessage_label:reformat(current_x, current_y, button_w, sub_label_h)
    current_y = current_y + sub_label_h + 2 * m

    for item in values(self._buttons) do
        local label_h = select(2, item.label:measure())
        item.label:reformat(current_x, current_y + 0.5 * item_h - 0.5 * label_h, item_w, item_h)
        item.frame:reformat(current_x, current_y, item_w, item_h)
        current_x = current_x + item_w + m
    end

    current_y = current_y + item_h

    local frame_w, frame_h = button_w + 2 * xm, current_y - start_y + 2 * ym
    self._frame:reformat(start_x - xm, start_y - ym, frame_w, frame_h)

    self._render_x_offset = math.floor(x + 0.5 * width - 0.5 * frame_w)
    self._render_y_offset = math.floor(y + 0.5 * height - 0.5 * frame_h)

    self._shadow = rt.AABB(x, y, width, height)

    self:_update_selected_item()
end

--- @override
function mn.MessageDialog:draw()
    if self._is_active == false then return end

    rt.graphics.set_blend_mode(rt.BlendMode.MULTIPLY, rt.BlendMode.ADD)
    love.graphics.setColor(self._shadow_color, self._shadow_color, self._shadow_color, 1)
    love.graphics.rectangle("fill", self._shadow:unpack())
    rt.graphics.set_blend_mode()

    love.graphics.translate(self._render_x_offset, self._render_y_offset)

    self._frame:draw()
    self._message_label:draw()
    self._submessage_label:draw()

    for item_i, item in ipairs(self._buttons) do
        item.frame:draw()
        item.label:draw()
    end

    love.graphics.translate(-1 * self._render_x_offset, -1 * self._render_y_offset)
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
function mn.MessageDialog:_handle_button_pressed(which)
    if self._is_active ~= true then return end

    if self._elapsed < rt.settings.menu.message_dialog.input_delay then
        return
    end

    if which == rt.InputButton.LEFT then
        if self._selected_item_i > 1 then
            self._selected_item_i = self._selected_item_i - 1
            self:_update_selected_item()
        end
    elseif which == rt.InputButton.RIGHT then
        if self._selected_item_i < table.sizeof(self._buttons) then
            self._selected_item_i = self._selected_item_i + 1
            self:_update_selected_item()
        end
    elseif which == rt.InputButton.A then
        self:signal_emit("selection", self._options[self._selected_item_i])
    end
end

--- @brief
function mn.MessageDialog:get_is_active()
    return self._is_active == true or self._queue_activate > 0
end

--- @brief
function mn.MessageDialog:close()
    self._queue_deactivate = 2
end

--- @brief
function mn.MessageDialog:present()
    self._queue_activate = 2 -- delay input by 2 frames
end

--- @brief
function mn.MessageDialog:set_message(message, submessage)
    meta.assert_string(message)
    self._message_label:set_text(message)

    if submessage ~= nil then
        meta.assert_string(submessage)
        self._submessage_label:set_text(submessage)
    end

    if self._is_realized then
        self:reformat()
    end
end

--- @brief
function mn.MessageDialog:set_submessage(submessage)
    meta.assert_string(submessage)
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

    if self._queue_activate > 0 then
        self._queue_activate = self._queue_activate - 1
        if self._queue_activate == 0 then
            self._is_active = true
        end
    end

    if self._queue_deactivate > 0 then
        self._queue_deactivate = self._queue_deactivate - 1
        if self._queue_deactivate == 0 then
            self._is_active = false
        end
    end
end