local PLAYER = rt.Translation.player_name
local PLAYER_SIDE = "right"
local NPC = rt.Translation.npc_name
local NPC_SIDE = "left"

local EYES_NAME = "(# EYES_NAME)"
local GHOST_NAME = "(# GHOST_NAME)"

local BOOST_FIELD_NAME = "Boost Field"

return setmetatable({

    slippery_floor_tutorial = {
        {
            speaker = EYES_NAME,
            "<b>Glass</b> like this is <wave>slippery</wave>, if you walk on it you slide around instead of stopping.",
            "There is no way to climb walls made out of glass, and none of your \"paint\" will stick to it. Be careful and always try to keep in mind the type of surface you are touching"
        }
    },

    boost_field_tip_01 = {
        {
            speaker = EYES_NAME,
            "These <b>" .. BOOST_FIELD_NAME .. "s</b> make you go faster while your are touching them. Make sure to <b>maximize the amount of time you are touching them</b> to get the most speed"
        }
    },

    on_bounce_complain = {
        {
            next = 2,
            speaker = "Yet Unnamend Ghost",
            "If you don't lock the player movement, the very first thing they are going to do is try to bounce on me",
        },

        {
            speaker = "Yet Unnamend Ghost",
            "Which is very rude"
        }
    },

    one_way_platform_tutorial_debug = {
        {
            speaker = "Mysterious Object",
            next = 2,
            state = {
                test = "test test test test test test test test test test test test test test test test"
            },

            "Hey, pss, up here"
        },

        {
            speaker = "Mysterious Object",
            next = nil,

            "new line"
        },
    },

    one_way_platform_tutorial_cant_pass = {
        {
             "test test test test test test test test test test test test test test test test",
            orientation = "right",

            choices = {
                {
                    "choice A",
                    next = nil
                },
                {
                    "choice B",
                    next = nil
                }
            }
        }
    },

    -- template

    template = {
        {
            speaker = NPC,
            orientation = NPC_SIDE,
            next = 2,
            state = {
                happy = 0.4,
                other_state = "test",
            },

            "Are|| you|||| sure about that?"
        },

        {
            speaker = PLAYER,
            orientation = PLAYER_SIDE,
            next = 3,

            "I did.\n But idk if the player should talk at all, the NPC definitely should, but I really want to implement that thing where instead of choosing an option, the player has to nod or shake their head."
        },

        {
            speaker = PLAYER,
            orientation = PLAYER_SIDE,
            next = "loop_a",
            next = 4,

            "Anyway, this dialog also has fancy camera movement."
        },

        loop_a = {
            speaker = NPC,
            orientation = NPC_SIDE,
            next = "loop_b",

            "like this?"
        },

        loop_b = {
            speaker = PLAYER,
            orientation = PLAYER_SIDE,
            next = "loop_a",

            "no, like this"
        }
    }
}, {
    __newindex = function(self, key, value)
        rt.error("In ow.Dialog: trying to set key `", key, "` in dialog table, but it was declared immutable")
        return
    end,

    __index = function(self, key)
        local result = rawget(self, key)
        if result == nil then
            rt.critical("In ow.Dialog: no dialog with id `", key, "` present")

            -- return placeholder
            return {
                {
                    speaker = "Error",
                    [1] = "(#" .. key .. ")"
                }
            }
        else
            return result
        end
    end
})