do
    local _input_actions = {
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
    _input_actions["JUMP"] = _input_actions.A
    _input_actions["SPRINT"] = _input_actions.B
    _input_actions["CONFIRM"] = _input_actions.A
    _input_actions["BACK"] = _input_actions.B

    --- @class rt.InputAction
    rt.InputAction = meta.enum("InputAction", _input_actions)
end

--- @class rt.ControllerButton
rt.ControllerButton = meta.enum("ControllerButton", {
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

--- @class rt.KeyboardKey
--- @see https://love2d.org/wiki/KeyConstant
rt.KeyboardKey = meta.enum("KeyboardKey", {
    UNKNOWN = "unknown",
    A = "a",
    B = "b",
    C = "c",
    D = "d",
    E = "e",
    F = "f",
    G = "g",
    H = "h",
    I = "i",
    J = "j",
    K = "k",
    L = "l",
    M = "m",
    N = "n",
    O = "o",
    P = "p",
    Q = "q",
    R = "r",
    S = "s",
    T = "t",
    U = "u",
    V = "v",
    W = "w",
    X = "x",
    Y = "y",
    Z = "z",
    ZERO = "0",
    ONE = "1",
    TWO = "2",
    THREE = "3",
    FOUR = "4",
    FIVE = "5",
    SIX = "6",
    SEVEN = "7",
    EIGHT = "8",
    NINE = "9",
    SPACE = "space",
    EXCLAMATION_MARK = "!",
    DOUBLE_QUOTE = "\"",
    HASHTAG = "#",
    DOLLAR_SIGN= "$",
    SINGLE_QUOTE = "'",
    LEFT_BRACKET = "(",
    RIGHT_BRACKET = ")",
    ASTERISK = "*",
    PLUS = "+",
    COMMA = ",",
    MINUS = "-",
    DOT = ".",
    SLASH = "/",
    COLON = ":",
    SEMICOLON = ";",
    LESS_THAN = "<",
    EQUAL = "=",
    MORE_THAN = ">",
    QUESTION_MARK = "?",
    AT = "@",
    LEFT_SQUARE_BRACKET = "[",
    RIGHT_SQUARE_BRACKET = "]",
    CIRCUMFLEX = "^",
    UNDERSCORE = "_",
    GRAVE_ACCENT = "`",
    ARROW_UP = "up",
    ARROW_DOWN = "down",
    ARROW_RIGHT = "right",
    ARROW_LEFT = "left",
    HOME = "home",
    END = "end",
    PAGE_UP = "pageup",
    PAGE_DOWN = "pagedown",
    INSERT = "insert",
    BACKSPACE = "backspace",
    TAB = "tab",
    CLEAR = "clear",
    RETURN = "return",
    DELETE = "delete",
    F1 = "f1",
    F2 = "f2",
    F3 = "f3",
    F4 = "f4",
    F5 = "f5",
    F6 = "f6",
    F7 = "f7",
    F8 = "f8",
    F9 = "f9",
    F10 = "f10",
    F11 = "f11",
    F12 = "f12",
    NUM_LOCK = "numlock",
    CAPS_LOCK = "capslock",
    RIGHT_SHIFT = "rshift",
    LEFT_SHIFT = "lshift",
    LEFT_CONTROL = "rcrtl",
    RIGHT_CONTROL = "lcrtl",
    RIGHT_ALT = "ralt",
    LEFT_ALT = "lalt",
    PAUSE = "pause",
    ESCAPE = "escape",
    HELP = "help",
    PRINT_SCREEN = "printscreen",
    SYSTEM_REQUEST = "sysreq",
    MENU = "menu",
    APPLICATION = "application",
    POWER = "power",
    EURO = "currencyunit",
    UNDO = "undo",
    SEARCH = "appsearch",
    HOME = "apphome",
    BACK = "appback",
    FORWARD = "appforward",
    REFRESH = "apprefresh",
    BOOKMARKS = "appbookmarks",
    KEYPAD_0 = "kp0",
    KEYPAD_1 = "kp1",
    KEYPAD_2 = "kp2",
    KEYPAD_3 = "kp3",
    KEYPAD_4 = "kp4",
    KEYPAD_5 = "kp5",
    KEYPAD_6 = "kp6",
    KEYPAD_7 = "kp7",
    KEYPAD_8 = "kp8",
    KEYPAD_DOT = "kp.",
    KEYPAD_COMMA = "kp,",
    KEYPAD_SLASH = "kp/",
    KEYPAD_ASTERISK = "kp*",
    KEYPAD_MINUS = "kp-",
    KEYPAD_PLUS = "kp+",
    KEYPAD_ENTER = "kpenter",
    KEYPAD_EQUALS = "kp=",
})

local _gamepad_button_to_string = {
    [rt.ControllerButton.BOTTOM] = "BOTTOM",
    [rt.ControllerButton.RIGHT] = "RIGHT",
    [rt.ControllerButton.LEFT] = "LEFT",
    [rt.ControllerButton.TOP] = "TOP",
    [rt.ControllerButton.DPAD_UP] = "UP",
    [rt.ControllerButton.DPAD_DOWN] = "DOWN",
    [rt.ControllerButton.DPAD_LEFT] = "LEFT",
    [rt.ControllerButton.DPAD_RIGHT] = "RIGHT",
    [rt.ControllerButton.LEFT_SHOULDER] = "L",
    [rt.ControllerButton.RIGHT_SHOULDER] = "R",
    [rt.ControllerButton.START] = "START",
    [rt.ControllerButton.SELECT] = "SELECT",
    [rt.ControllerButton.HOME] = "CENTER",
    [rt.ControllerButton.LEFT_STICK] = "RIGHT STICK",
    [rt.ControllerButton.RIGHT_STICK] = "LEFT STICK",
    ["paddle1"] = "PADDLE #1",
    ["paddle2"] = "PADDLE #2",
    ["paddle3"] = "PADDLE #3",
    ["paddle4"] = "PADDLE #4"
}

function rt.gamepad_button_to_string(gamepad_button)
    local raw = string.sub(gamepad_button, #rt.ControllerButtonPrefix + 1, #gamepad_button)
    local out = _gamepad_button_to_string[raw]
    if out == nil then return "UNKNOWN" else return out end
end

local _keyboard_key_to_string = {
    ["ä"] = "Ä",
    ["ö"] = "Ö",
    ["ü"] = "Ü",
    ["escape"] = "ESC",
    ["up"] = "\u{2191}",       -- up arrow
    ["right"] = "\u{2192}",    -- right arrow
    ["down"] = "\u{2193}",     -- down arrow
    ["left"] = "\u{2190}",     -- left arrow
    ["space"] = "\u{2500}",    -- space bar
    ["return"] = "\u{21B5}",   -- enter
    ["backspace"] = "\u{232B}" -- backspace
}

function rt.keyboard_key_to_string(keyboard_key)
    local result = _keyboard_key_to_string[keyboard_key]
    if result then
        return result
    end
    return string.upper(keyboard_key)
end