do
    local _input_buttons = {
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
    }

    -- aliases
    _input_buttons["JUMP"] = _input_buttons.A
    _input_buttons["SPRINT"] = _input_buttons.B
    _input_buttons["CONFIRM"] = _input_buttons.A
    _input_buttons["BACK"] = _input_buttons.B

    --- @class rt.InputButton
    rt.InputButton = meta.enum("InputButton", _input_buttons)
end

--- @class rt.GamepadButton
rt.GamepadButton = meta.enum("GamepadButton", {
    TOP = "y",
    RIGHT = "b",
    BOTTOM = "a",
    LEFT = "x",
    DPAD_UP = "dpup",
    DPAD_DOWN = "dpdown",
    DPAD_LEFT = "dpleft",
    DPAD_RIGHT = "dpright",
    START = "start",
    SELECT = "back",
    HOME = "guide",
    LEFT_STICK = "leftstick",
    RIGHT_STICK = "rightstick",
    LEFT_SHOULDER = "leftshoulder",
    RIGHT_SHOULDER = "rightshoulder",
    LEFT_TRIGGER = "triggerleft",
    RIGHT_TRIGGER = "triggerright"
})

--- @class rt.InputMapping
rt.InputMapping = meta.class("InputMapping")

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

    self:update_reverse_mapping()
end