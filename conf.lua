function love.conf(settings)
    --settings.graphics.renderers = {"opengl"}
end

local GAMEPAD_BUTTON_TOP = "y"
local GAMEPAD_BUTTON_RIGHT = "b"
local GAMEPAD_BUTTON_BOTTOM = "a"
local GAMEPAD_BUTTON_LEFT = "x"

_G.SETTINGS = {
    -- for a list of valid keys and button, see:
    --  https://love2d.org/wiki/GamepadButton
    --  https://love2d.org/wiki/KeyConstant
    INPUT_MAPPING = {
        ["UP"] = {
            keyboard = {"up", "w"},
            controller = "dpup",
        },

        ["DOWN"] = {
            keyboard = {"down", "s"},
            controller = "dpdown"
        },

        ["LEFT"] = {
            keyboard = {"left", "a"},
            controller = "dpleft"
        },

        ["RIGHT"] = {
            keyboard = {"right", "d"},
            controller = "dpright"
        },

        ["A"] = {
            keyboard = {"space", "e"},
            controller = GAMEPAD_BUTTON_RIGHT
        },

        ["B"] = {
            keyboard = "b",
            controller = GAMEPAD_BUTTON_BOTTOM
        },

        ["X"] = {
            keyboard = "x",
            controller = GAMEPAD_BUTTON_TOP
        },

        ["Y"] = {
            keyboard = "y",
            controller = GAMEPAD_BUTTON_LEFT
        },

        ["L"] = {
            keyboard = {"n", "l"},
            controller = "leftshoulder"
        },

        ["R"] = {
            keyboard = {"m", "r"},
            controller = "rightshoulder"
        },

        ["START"] = {
            keyboard = "escape",
            controller = "start"
        },

        ["SELECT"] = {
            keyboard = "#",
            controller = "back"
        }
    },
}


