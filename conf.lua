VSYNC_ADAPTIVE = -1
VSYNC_OFF = 0
VSYNC_ON = 1

function love.conf(settings)
    settings.window.msaa = 4
    settings.window.resizable = true
    settings.window.vsync = VSYNC_OFF
    settings.graphics.renderers = {"opengl"}
end

GAMEPAD_BUTTON_TOP = "y"
GAMEPAD_BUTTON_RIGHT = "b"
GAMEPAD_BUTTON_BOTTOM = "a"
GAMEPAD_BUTTON_LEFT = "x"
GAMEPAD_BUTTON_START = "start"
GAMEPAD_BUTTON_SELECT = "back"

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
            keyboard = {"space"},
            controller = GAMEPAD_BUTTON_RIGHT
        },

        ["B"] = {
            keyboard = {"b"},
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
        },

        ["SPRINT"] = {
            keyboard = "b",
            controller = GAMEPAD_BUTTON_LEFT
        },

        ["JUMP"] = {
            keyboard = "space",
            controller = GAMEPAD_BUTTON_BOTTOM
        },
    },
}


