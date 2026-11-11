ControlIndicator_t = "ControlIndicator"

_settings_font_size_binding = 30 / 800
_settings_font_size_command = 27 / 800

control_indicator_new = function(...)
    return control_indicator_init(object_new(ControlIndicator_t, {
        bounds = aabb_new(0, 0, 1, 1),
        elapsed = 0
    }), ...)
end

control_indicator_init = function(self, ...)
    log_typecheck(self, ControlIndicator_t)

    local n = select("#", ...)
    log_assert(n % 2 == 0, "In control_indicator_init: number of arguments is not a multiple of 2")

    local native_h = graphics_get_height()
    local command_font_size = _settings_font_size_command *  native_h
    local binding_font_size = _settings_font_size_binding * native_h

    self.entries = {}
    for i = 1, n, 2 do
        local action = select(i + 0, ...)
        local command = select(i + 1, ...)
        log_typecheck_arg_i(action, String_t, i + 0)
        log_typecheck_arg_i(command, String_t, i + 1)
        log_assert(input_is_input_action(action), "In control_indicator_init: `", object_to_string(action), "` is not a valid input action")

        local keyboard_keys = input_get_keyboard_keys(action)
        local gamepad_buttons = input_get_gamepad_buttons(action)
        local keyboard_key = ""
        local gamepad_button = ""

        if #keyboard_keys > 0 then
            keyboard_key = input_keyboard_key_get_cleartext_name(keyboard_keys[1])
        end

        if #gamepad_buttons > 0 then
            gamepad_button = input_gamepad_button_get_cleartext_name(gamepad_buttons[1])
        end

        table_push(self.entries, {
            action = action,
            command = command,
            keyboard_keys = keyboard_keys,
            gamepad_buttons = gamepad_buttons,
            keyboard_label = label_new(keyboard_key, binding_font_size, TextStyle.BOLD, nil, JustifyMode.LEFT, true),
            gamepad_label = label_new(gamepad_button, binding_font_size, TextStyle.BOLD, nil, JustifyMode.LEFT, true),
            command_label = label_new(command, command_font_size, TextStyle.REGULAR, nil, JustifyMode.LEFT, true),
            color = rgba_new(1, 1, 1, 1)
        })
    end

    self.input_method = input_get_input_method()
    control_indicator_reformat(self, 0, 0, 1, 1)
    return self
end

control_indicator_reformat = function(self, x, y, width, height)
    log_typecheck(self, ControlIndicator_t)

    self.bounds = aabb_init(self.bounds, x , y, width, height)

    local max_label_height = 0
    local max_keyboard_binding_width = 0
    local max_gamepad_binding_width = 0
    local max_command_width = 0
    local command_spacing = 0

    for _, entry in ipairs(self.entries) do
        max_label_height = math.max(max_label_height,
            label_get_height(entry.keyboard_label),
            label_get_height(entry.gamepad_label),
            label_get_height(entry.command_label)
        )
        max_keyboard_binding_width = math.max(max_keyboard_binding_width, label_get_width(entry.keyboard_label))
        max_gamepad_binding_width = math.max(max_gamepad_binding_width, label_get_width(entry.gamepad_label))
        max_command_width = math.max(max_command_width, label_get_width(entry.command_label))
        command_spacing = 0
    end

    self.max_label_height = max_label_height
    self.max_keyboard_binding_width = max_keyboard_binding_width
    self.max_gamepad_binding_width = max_gamepad_binding_width
    self.max_command_width = max_command_width
    self.command_spacing = command_spacing
    self.keyboard_command_offset = max_keyboard_binding_width + command_spacing + 0.5 * _global_outer_margin
    self.gamepad_command_offset = max_gamepad_binding_width + command_spacing + 0.5 * _global_outer_margin

    self.bounds.width = math.max(self.keyboard_command_offset, self.gamepad_command_offset) + max_command_width
    self.bounds.height = max_label_height * #self.entries

    for i, entry in ipairs(self.entries) do
        local cy = self.bounds.y + (i - 1) * max_label_height
        label_reformat(entry.keyboard_label, self.bounds.x, cy, max_keyboard_binding_width, max_label_height)
        label_reformat(entry.gamepad_label, self.bounds.x, cy, max_gamepad_binding_width, max_label_height)
        label_reformat(entry.command_label, self.bounds.x + self.keyboard_command_offset, cy, max_command_width, max_label_height)
    end

    return self
end

control_indicator_update = function(self, delta)
    log_typecheck(self, ControlIndicator_t, delta, Number_t)

    self.input_method = input_get_input_method()
    self.elapsed = self.elapsed + delta * 0 -- TODO

    local n = table_sizeof(self.entries)
    for i, entry in ipairs(self.entries) do
        local hue = (i - 1) / n
        entry.color = lcha_to_rgba(0.8, 1, hue + self.elapsed, 1)
    end
end

control_indicator_draw = function(self)
    log_typecheck(self, ControlIndicator_t)

    local input_method = input_get_input_method()
    self.input_method = input_method

    for _, entry in ipairs(self.entries) do
        local binding_label
        local command_offset

        if input_method == InputMethod.KEYBOARD then
            binding_label = entry.keyboard_label
            command_offset = self.keyboard_command_offset
        elseif input_method == InputMethod.GAMEPAD then
            binding_label = entry.gamepad_label
            command_offset = self.gamepad_command_offset
        end

        if binding_label ~= nil then
            local _, y = label_get_position(binding_label)
            rgba_bind(palette_white)
            label_reformat(entry.command_label,
                self.bounds.y + command_offset,
                y,
                self.max_command_width,
                self.max_label_height
            )

            rgba_bind(entry.color)
            label_draw(binding_label)
            label_draw(entry.command_label)
        end
    end
end
