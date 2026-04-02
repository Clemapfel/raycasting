
--- @enum rt.ControllerButton
rt.ControllerButton = {
    TOP = "top",                       -- "y"
    RIGHT = "right",                   -- "b"
    BOTTOM = "bottom",                 -- "a"
    LEFT = "left",                     -- "x"
    DPAD_UP = "dpad_up",               -- "dpup"
    DPAD_DOWN = "dpad_down",           -- "dpdown"
    DPAD_LEFT = "dpad_left",           -- "dpleft"
    DPAD_RIGHT = "dpad_right",         -- "dpright"
    START = "start",                   -- "start"
    SELECT = "select",                 -- "back"
    HOME = "home",                     -- "guide"
    LEFT_STICK = "left_stick",         -- "leftstick"
    RIGHT_STICK = "right_stick",       -- "rightstick"
    LEFT_SHOULDER = "left_shoulder",   -- "leftshoulder"
    RIGHT_SHOULDER = "right_shoulder", -- "rightshoulder"
    PADDLE_01 = "paddle_01",           -- "paddle1"
    PADDLE_02 = "paddle_02",           -- "paddle2"
    PADDLE_03 = "paddle_03",           -- "paddle3"
    PADDLE_04 = "paddle_04"            -- "paddle4"
}
rt.ControllerButton = meta.enum("ControllerButton", rt.ControllerButton)

--- @brief
rt.controller_button_to_native = function(button)
    local binding = {
        [rt.ControllerButton.TOP] = "y",
        [rt.ControllerButton.RIGHT] = "b",
        [rt.ControllerButton.BOTTOM] = "a",
        [rt.ControllerButton.LEFT] = "x",
        [rt.ControllerButton.DPAD_UP] = "dpup",
        [rt.ControllerButton.DPAD_DOWN] = "dpdown",
        [rt.ControllerButton.DPAD_LEFT] = "dpleft",
        [rt.ControllerButton.DPAD_RIGHT] = "dpright",
        [rt.ControllerButton.START] = "start",
        [rt.ControllerButton.SELECT] = "back",
        [rt.ControllerButton.HOME] = "guide",
        [rt.ControllerButton.LEFT_STICK] = "leftstick",
        [rt.ControllerButton.RIGHT_STICK] = "rightstick",
        [rt.ControllerButton.LEFT_SHOULDER] = "leftshoulder",
        [rt.ControllerButton.RIGHT_SHOULDER] = "rightshoulder",
        [rt.ControllerButton.PADDLE_01] = "paddle1",
        [rt.ControllerButton.PADDLE_02] = "paddle2",
        [rt.ControllerButton.PADDLE_03] = "paddle3",
        [rt.ControllerButton.PADDLE_04] = "paddle4",
    }

    local result = binding[button]
    if result == nil then
        rt.error("In rt.controller_button_to_native: unknown controller button `", button, "`")
    end

    return result
end

--- @brief
rt.native_to_controller_button = function(native)
    local binding = {
        ["y"] = rt.ControllerButton.TOP,
        ["b"] = rt.ControllerButton.RIGHT,
        ["a"] = rt.ControllerButton.BOTTOM,
        ["x"] = rt.ControllerButton.LEFT,
        ["dpup"] = rt.ControllerButton.DPAD_UP,
        ["dpdown"] = rt.ControllerButton.DPAD_DOWN,
        ["dpleft"] = rt.ControllerButton.DPAD_LEFT,
        ["dpright"] = rt.ControllerButton.DPAD_RIGHT,
        ["start"] = rt.ControllerButton.START,
        ["back"] = rt.ControllerButton.SELECT,
        ["guide"] = rt.ControllerButton.HOME,
        ["leftstick"] = rt.ControllerButton.LEFT_STICK,
        ["rightstick"] = rt.ControllerButton.RIGHT_STICK,
        ["leftshoulder"] = rt.ControllerButton.LEFT_SHOULDER,
        ["rightshoulder"] = rt.ControllerButton.RIGHT_SHOULDER,
        ["paddle1"] = rt.ControllerButton.PADDLE_01,
        ["paddle2"] = rt.ControllerButton.PADDLE_02,
        ["paddle3"] = rt.ControllerButton.PADDLE_03,
        ["paddle4"] = rt.ControllerButton.PADDLE_04,
    }

    local result = binding[native]
    if result == nil then
        rt.error("In rt.native_to_controller_button: unknown native button `", native, "`")
    end

    return result
end


function rt.controller_button_to_string(button)
    return ({
        [rt.ControllerButton.TOP] = "top",
        [rt.ControllerButton.RIGHT] = "right",
        [rt.ControllerButton.BOTTOM] = "bottom",
        [rt.ControllerButton.LEFT] = "left",
        [rt.ControllerButton.DPAD_UP] = "dpad up",
        [rt.ControllerButton.DPAD_RIGHT] = "dpad right",
        [rt.ControllerButton.DPAD_DOWN] = "dpad down",
        [rt.ControllerButton.DPAD_LEFT] = "dpad left",
        [rt.ControllerButton.LEFT_SHOULDER] = "left bumper",
        [rt.ControllerButton.RIGHT_SHOULDER] = "right bumper",
        [rt.ControllerButton.START] = "start",
        [rt.ControllerButton.SELECT] = "select",
    })[button]
end
