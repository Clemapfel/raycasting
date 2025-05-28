VSYNC_ADAPTIVE = -1
VSYNC_OFF = 0
VSYNC_ON = 1

function love.conf(settings)
    --settings.graphics.renderers = {"opengl"}
    settings.window.msaa = 8
    settings.window.resizable = true
    settings.window.vsync = VSYNC_ON
    settings.window.usedpiscale = false
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
            keyboard = {"w", "up"},
            controller = "dpup",
        },

        ["DOWN"] = {
            keyboard = {"s", "down"},
            controller = "dpdown"
        },

        ["LEFT"] = {
            keyboard = {"a", "left"},
            controller = "dpleft"
        },

        ["RIGHT"] = {
            keyboard = {"d", "right"},
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


