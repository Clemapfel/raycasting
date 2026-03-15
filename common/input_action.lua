--- @class rt.InputAction
rt.InputAction = {
    -- common
    UP = "up",
    RIGHT = "right",
    DOWN = "down",
    LEFT = "left",

    -- overworld
    JUMP = "jump",
    SPRINT = "sprint",
    INTERACT = "interact",
    PAUSE = "pause",

    -- menu
    CONFIRM = "confirm",
    BACK = "back",
    RESET = "reset",

    SPECIAL = "special"
}
rt.InputAction = meta.enum("InputAction", rt.InputAction)

require "common.controller_button"
require "common.keyboard_key"