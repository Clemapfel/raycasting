--- @class rt.InputButton
rt.InputButton = meta.enum("InputButton", {
    UP = "UP",
    RIGHT = "RIGHT",
    DOWN = "DOWN",
    LEFT = "LEFT",
    A = "A",
    B = "B",
    X = "X",
    Y = "Y",
    START = "START",
    SELECT = "SELECT",
    L = "L",
    R = "R"
})

--- @class rt.InputMapping
rt.InputMapping = meta.class("InputMapping")

--- @brief [internal]
function rt.InputMapping:instantiate()
    -- sanitize INPUT_MAPPING
    for input_button in range(
        rt.InputButton.UP,
        rt.InputButton.RIGHT,
        rt.InputButton.DOWN,
        rt.InputButton.LEFT,
        rt.InputButton.A,
        rt.InputButton.B,
        rt.InputButton.X,
        rt.InputButton.Y,
        rt.InputButton.START,
        rt.InputButton.SELECT,
        rt.InputButton.L,
        rt.InputButton.R
    ) do
        local mapped = _G.SETTINGS.INPUT_MAPPING[input_button]
        if mapped == nil then
            rt.error("In rt.InputMapping: mapping in conf.lua does not map input action `" .. input_button .. "`")
        end

        if not meta.is_table(mapped.keyboard) then mapped.keyboard = { mapped.keyboard } end
        if not meta.is_table(mapped.controller) then mapped.controller = { mapped.controller } end
        if table.sizeof(mapped.keyboard) == 0 then
            rt.error("In rt.InputMapping: mapping in conf.lua does not assign a keyboard key to input action `" .. input_button .. "`")
        end

        if table.sizeof(mapped.controller) == 0 then
            rt.error("In rt.InputMapping: mapping in conf.lua does not assign a controller button to input action `" .. input_button .. "`")
        end
    end

    self:update_reverse_mapping()
end

--- @brief [internal]
function rt.InputMapping:update_reverse_mapping()
    local _keyboard_key_to_input_action = {}
    local _controller_button_to_input_action = {}

    for action in values(meta.instances(rt.InputButton)) do
        local binding = _G.SETTINGS.INPUT_MAPPING[action]
        if binding ~= nil then
            local keyboard = binding.keyboard
            if keyboard ~= nil then
                if type(keyboard) ~= "table" then keyboard = { keyboard } end
                for key in values(keyboard) do
                    _keyboard_key_to_input_action[key] = action
                end
            else
                rt.warning("In rt.InputMapping: input action `" .. action .. "` does not have any keyboard mapping")
            end

            local controller = binding.controller
            if controller ~= nil then
                if type(controller) ~= "table" then controller = { controller } end
                for button in values(controller) do
                    _controller_button_to_input_action[button] = action
                end
            else
                rt.warning("In rt.InputMapping: input action `" .. action .. "` does not have any controller mapping")
            end
        else
            rt.warning("In rt.InputMapping: input action `" .. action .. "` does not have any mapping")
        end
    end

    self._keyboard_key_to_input_action = _keyboard_key_to_input_action
    self._controller_button_to_input_action = _controller_button_to_input_action
end

--- @brief 
function rt.InputMapping:map(native, keyboard_or_controller)
    if keyboard_or_controller == nil then keyboard_or_controller = true end
    meta.assert(native, "String", keyboard_or_controller, "Boolean")

    if keyboard_or_controller == true then
        return self._keyboard_key_to_input_action[native]
    else
        return self._controller_button_to_input_action[native]
    end
end

--- @brief 
function rt.InputMapping:get_mapping(input_action)
    local mapped = _G.SETTINGS.INPUT_MAPPING[input_action]
    if mapped == nil then
        log.error("In rt.InputMapping.get_mapping: no mapping for input action `" .. input_action .. "`")
        return nil, nil
    end

    local keyboard = { table.unpack(_G.SETTINGS.INPUT_MAPPING[input_action].keyboard) }
    local controller = { table.unpack(_G.SETTINGS.INPUT_MAPPING[input_action].controller) }
    return keyboard, controller
end

--- @brief update current mapping
--- @param input_action rt.InputButton
--- @param keyboard Table<love.KeyConstant>
--- @param controller Table<love.GamepadButton>
function rt.InputMapping:set_mapping(input_action, keyboard, controller)
    assert(meta.is_enum_value(input_action), type(keyboard) == "table" and type(controller) == "table")

    local mapped = _G.SETTINGS.INPUT_MAPPING[input_action]
    if mapped == nil then
        log.error("In rt.InputMapping.set_mapping: no mapping for input action `" .. input_action .. "`")
        return nil, nil
    end

    mapped.keyboard = keyboard
    mapped.controller = controller
    self:update_reverse_mapping()
end

rt.InputMapping = rt.InputMapping() -- static instance



