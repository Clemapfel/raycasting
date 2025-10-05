local left_speaker = "Player"
local right_speaker = "NPC"

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
        next = 4,

        "...||||", -- | = dialog beat unit
    },

    [4] = {
        speaker = left_speaker,
        next = 5,

        "Well, anyway, it has multiple choices too, like this:",
    },

    [5] = {
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

    [6] = {
        speaker = left_speaker,
        next = nil, -- end of conversation

        "Thanks for listening.~",
        "Also here's the shader I added for clickbait on it's own. I guess it looks like nightmare fuel worms or something so you probably didn't read any of this, it is pretty distracting.",
        "Anyway, here you go:"
    }
}