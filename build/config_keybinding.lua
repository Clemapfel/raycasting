--- @brief
bd.config.parse_keybind_from_string = function(str)
    require "common.input_action"

    local throw = function(...)
        rt.error("In bd.config.parse_keybind_from_string: ", ...)
    end

    local keyboard, controller = {}, {}
    local parsed = bd.config._string_to_table(str)

    local mapping = {
        ["shift"] = rt.KeyboardKey.LEFT_SHIFT,
        ["alt"] = rt.KeyboardKey.LEFT_ALT,
        ["control"] = rt.KeyboardKey.LEFT_CONTROL
    }

    for key, value in pairs(parsed) do
        if not meta.is_table(value) then value = { value } end

        for i, v in ipairs(value) do
            if mapping[v] ~= nil then value[i] = mapping[v] end
        end

        local input_action_keyboard = string.match(key, "^(.-)_keyboard$")
        local input_action_controller = string.match(key, "^(.-)_controller$")

        local to_assign
        if input_action_keyboard ~= nil then
            if not meta.is_enum_value(input_action_keyboard, rt.InputAction) then
                throw("unknown input action `", input_action_keyboard, "` for key `", key, "`")
            end

            for keyboard_key in values(value) do
                if not meta.is_enum_value(keyboard_key, rt.KeyboardKey) then
                    throw("unknown keyboard key `", keyboard_key, "` for key `", key, "`")
                end
            end

            keyboard[input_action_keyboard] = value

        elseif input_action_controller ~= nil then
            if not meta.is_enum_value(input_action_controller, rt.InputAction) then
                throw("unknown input action `", input_action_controller, "` for key `", key, "`")
            end

            for controller_button in values(value) do
                if not meta.is_enum_value(controller_button, rt.ControllerButton) then
                    throw("unknown controller button `", controller_button, "` for key `", key, "`")
                end
            end

            controller[input_action_controller] = value
        else
            throw("malformed key `", key, "`")
        end
    end

    for input_action in values(meta.instances(rt.InputAction)) do
        if keyboard[input_action] == nil then
            throw("no keyboard key present for input action `", input_action, "`, is `", input_action .. "_keyboard", "` assigned?")
        end

        if controller[input_action] == nil then
            throw("no keyboard key present for input action `", input_action, "`, is `", input_action .. "_controller", "` assigned?")
        end
    end

    return keyboard, controller
end

do
    local path = rt.settings.config.default_keybind_path
    local success, file_or_error = pcall(love.filesystem.read, path)

    if not success then
        rt.error("In bd.parse_config: unable to open config file at `", path, "`: ", file_or_error)
    else
        local keyboard, controller = bd.config.parse_keybind_from_string(file_or_error)

        bd.config.default_keybind_keyboard = keyboard
        bd.config.keybind_keyboard = table.deepcopy(keyboard)

        bd.config.default_keybind_controller = controller
        bd.config.keybind_controller = table.deepcopy(controller)
    end
end