local PLAYER = rt.Translation.player_name
local PLAYER_SIDE = "right"
local NPC = rt.Translation.npc_name
local NPC_SIDE = "left"

return setmetatable({

    -- on_way_platform_tutorial

    one_way_platform_tutorial_debug = {
        {
            speaker = "Mysterious Object",
            next = nil,
            state = {
                test = "test"
            },

            "Hey, pss, up here"
        },
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