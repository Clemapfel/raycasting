local prefix = "<normal>"
local postfix = "</normal>"

return {
    slippery_floor_tutorial = {
        {
            speaker = rt.NPC_NAME,
            "<b>Glass</b> like this is <wave>slippery</wave>, if you walk on it you slide around instead of stopping.",
            "There is no way to climb walls made out of glass, and none of your \"paint\" will stick to it. Be careful and always try to keep in mind the type of surface you are touching"
        }
    },

    accelerator_tutorial_press_tangential = {
        [1] = {
            next = 2,
            gender = rt.Gender.FEMALE,
            "my <happy>animalese</happy> works but it sounds awful. <sad>I already tried manipulating the samples but I'm about to throw away like 3 days of work</sad>."
        },

        [2] = {
            next = nil,
            "<bashful>the worst part is that the text doesn't scroll evenly, but if I don't synchronize by stopping ocassionally then the audio will go out of synch with the words</bashful>"
        },

        --[[
        [1] = {
            speaker = rt.NPC_NAME,
            gender = rt.Gender.FEMALE,
            next = 2,
            prefix .. "These <rainbow><wave>crystalline surfaces</wave></rainbow> will allow you to <rainbow>accelerate</rainbow> along them, but only as long as you're touching them and are holding the correct direction" .. postfix
        },

        [2] = {
            speaker = rt.NPC_NAME,
            next = nil,
            "Hold <b>up</b> to go <b>up</b>, hold <b>right</b> to go <b>right</b>, hold <i>diagonally</i> to go <i>diagonally</i>, you'll figure it out"
        }
        ]]
    },

    boost_field_tip_01 = {
        {
            speaker = rt.NPC_NAME,
            "These <b>" .. "boost field" .. "s</b> make you go faster whigle your are touching them. Make sure to <b>maximize the amount of time you are touching them</b> to get the most speed"
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
            speaker = rt.NPC_NAME,
            orientation = rt.SpeakerOrientation.LEFT,
            next = 2,
            state = {
                happy = 0.4,
                other_state = "test",
            },

            "Are|| you|||| sure about that?"
        },

        {
            speaker = rt.PLAYER_NAME,
            orientation = rt.SpeakerOrientation.RIGHT,
            next = 3,

            "I did.\n But idk if the player should talk at all, the NPC definitely should, but I really want to implement that thing where instead of choosing an option, the player has to nod or shake their head."
        },

        {
            speaker = rt.PLAYER_NAME,
            orientation = rt.SpeakerOrientation.RIGHT,
            --next = "loop_a",
            next = nil,

            "Anyway, this dialog also has fancy camera movement."
        },

        loop_a = {
            speaker = rt.NPC_NAME,
            orientation = rt.SpeakerOrientation.LEFT,
            next = "loop_b",

            "like test?"
        },

        loop_b = {
            speaker = rt.PLAYER_NAME,
            orientation = rt.SpeakerOrientation.RIGHT,
            next = "loop_a",

            "no, like this"
        }
    }
}