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
    R = "R",

    JUMP = "JUMP",
    SPRINT = "SPRINT"
})

--- @class rt.InputMapping
rt.InputMapping = meta.class("InputMapping")

--- @brief [internal]
function rt.InputMapping:instantiate()
    -- sanitize INPUT_MAPPING
    for input_button in values(meta.instances(rt.InputButton)) do
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
    self._keyboard_key_to_input_action = {}
    self._controller_button_to_input_action = {}

    for action in values(meta.instances(rt.InputButton)) do
        local mapping = _G.SETTINGS.INPUT_MAPPING[action]

        if mapping == nil then
            rt.warning("In rt.InputMapping: no keymapping entry for input action `" .. action .. "`")
            goto continue
        end

        if mapping.keyboard == nil or #mapping.keyboard == 0 then
            rt.warning("In rt.InputMapping: no keyboard key is mapped to input action `" .. action .. "`")
            goto continue
        end

        if mapping.controller == nil or #mapping.controller == 0 then
            rt.warning("In rt.InputMapping: no controller button is mapped to input action `" .. action .. "`")
            goto continue
        end

        for key in values(mapping.keyboard) do
            local actions = self._keyboard_key_to_input_action[key]
            if actions == nil then
                actions = {}
                self._keyboard_key_to_input_action[key] = actions
            end
            table.insert(actions, action)
        end

        for button in values(mapping.controller) do
            local actions = self._controller_button_to_input_action[button]
            if actions == nil then
                actions = {}
                self._controller_button_to_input_action[button] = actions
            end
            table.insert(actions, action)
        end

        ::continue::
    end
end

--- @brief
--- @return Table<rt.InputButton>
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



