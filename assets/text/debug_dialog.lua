local PLAYER = rt.Translation.player_name
local PLAYER_SIDE = "right"
local NPC = rt.Translation.npc_name
local NPC_SIDE = "left"

return {
    {
        speaker = NPC,
        orientation = NPC_SIDE,
        next = nil,

        "Are|| you|||| sure about that?"
    },

    {
        speaker = PLAYER,
        orientation = PLAYER_SIDE,

        "I did.\n But idk if the player should talk at all, the NPC definitely should, but I really want to implement that thing where instead of choosing an option, the player has to nod or shake their head."
    },

    {
        speaker = PLAYER,
        orientation = PLAYER_SIDE,
        next = "loop_a",

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
    },
}

--[[
return {

    [1] = {
        speaker = left_speaker,
        orientation = "left",
        next = 2,

        "I am testing debug dialog, it has <b><wave><rainbow>fancy formatting</rainbow></wave></b>, too.",
    },


    [2] = {
        speaker = right_speaker,
        orientation = "right",
        next = 3,

        "Are you <i>sure</i> this is the best way to implement it? It feels like you're just copying Mystery Dungeon."
    },

    [3] = {
        speaker = left_speaker,
        orientation = "left",
        next = 2,

        "I am testing debug dialog, it has <b><wave><rainbow>fancy formatting</rainbow></wave></b>, too.",
    },


    [4] = {
        speaker = right_speaker,
        orientation = "right",
        next = 3,

        "Are you <i>sure</i> this is the best way to implement it? It feels like you're just copying Mystery Dungeon."
    },

    [5] = {
        speaker = left_speaker,
        orientation = "left",
        next = 2,

        "I am testing debug dialog, it has <b><wave><rainbow>fancy formatting</rainbow></wave></b>, too.",
    },


    [6] = {
        speaker = right_speaker,
        orientation = "right",
        next = 3,

        "Are you <i>sure</i> this is the best way to implement it? It feels like you're just copying Mystery Dungeon."
    },

    [7] = {
        speaker = left_speaker,
        orientation = "left",
        next = 2,

        "I am testing debug dialog, it has <b><wave><rainbow>fancy formatting</rainbow></wave></b>, too.",
    },


    [8] = {
        speaker = right_speaker,
        orientation = "right",
        next = 3,

        "Are you <i>sure</i> this is the best way to implement it? It feels like you're just copying Mystery Dungeon."
    },

    [9] = {
        speaker = left_speaker,
        next = 4,

        "...||||", -- | = dialog beat unit
    },

    [10] = {
        speaker = left_speaker,
        next = 5,

        "Well, anyway, it has multiple choices too, like this:",
    },

    [11] = {
        choices = {
            {
                "<wave>Wow, such choice</wave>",
                next = 6
            },
            {
                "Truly one of the most RPGs of all time",
                next = 4 -- loop
            }
        }
    },

    [12] = {
        speaker = left_speaker,
        next = nil, -- end of conversation

        "Thanks for listening.~",
        "Also here's the shader I added for clickbait on it's own. I guess it looks like nightmare fuel worms or something so you probably didn't read any of this, it is pretty distracting.",
        "Anyway, here you go:"
    }
}
]]--