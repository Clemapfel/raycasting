local prefix = "<normal>"
local postfix = "</normal>"

return {
    animalese_test = {
        {
            speaker = "test",
            gender = rt.Gender.MALE,
            next = 2,
            "<sad><color=blue>My dude, check this out.</sad></color>."
        },
        {
            gender = rt.Gender.MALE,
            next = 3,
            "<sad><color=blue>Y'know how this is a male voice all deep and stuff</color></sad>. I like mei much better, but just now, <i>I found out how to</i>-"
        },
        {
            gender = rt.Gender.MALE,
            next = nil,
            "<rainbow><happy>Pitch it up and it sounds so fucking stupid, he whips out his mickey mouse voice for this in a way so captivating, I might actually put it in the game.</happy></rainbow>"
        }--[[,
        {
            gender = rt.Gender.FEMALE,
            next = nil
        },
        {
            gender = rt.Gender.FEMALE,
            next = 2,
            "Do you have any advice on how to improve my <rainbow><wave>animalese</wave></rainbow> implementation?",
        },
        {
            gender = rt.Gender.FEMALE,
            next = 3,
            "<sad><color=BLUE>I'm unhappy with how it sounds overall, even though you can swap intonations</color></sad>|<happy><color=YELLOW><b> like this, it sounds way different now</b></color></happy>|<sad><color=BLUE> but overall it doesn't feel like animal crossing.</color></sad>"
        },
        {
            gender = rt.Gender.FEMALE,
            next = 4,
            "<bashful><color=PINK>This is another intonation, it is called <shake><b>`bashful`</b></shake> by the developers of the vocoder</bashful>, <color=red><angry>but idk if it sounds very <wave>flirty</wave> at all. This angry one does sound <s>tsundere</s> approriate at least.</color></angry>",
        },
        {
            gender = rt.Gender.MALE,
            next = 5,
            "<happy><color=yellow>This is a <b>male</b> voice now. </happy></color><sad><color=blue>It sounds way different but I don't like it very much.</sad></color>, it's a little bit too deep",
        },
        {
            gender = rt.Gender.MALE,
            next = 6,
            "<angry><color=red>Do you have any advice on how to improve my animalese?</angry></color>"
        },
        {
            gender = rt.Gender.MALE,
            next = nil,
            "<happy><wave><color=YELLOW><b>Thank you~</b></color></wave></happy>"
        }
         ]]
    },

    time_attack_trigger_npc = {
        {
            speaker = rt.GHOST_NAME,
            gender = rt.Gender.MALE,
            orientation = rt.SpeakerOrientation.RIGHT,
            next = nil,
            "Wanna race?",

            choices = {
                {
                    "Yes",
                    next = nil
                },
                {
                    "No",
                    next = nil
                }
            }
        }
    },

    slippery_floor_tutorial = {
        {
            speaker = rt.NPC_NAME,
            "<b>Glass</b> like this is <wave>slippery</wave>, if you walk on it you slide around instead of stopping.",
            "There is no way to climb walls made out of glass, and none of your \"paint\" will stick to it. Be careful and always try to keep in mind the type of surface you are touching"
        }
    },

    accelerator_tutorial_press_tangential = {
        [1] = {
            speaker = rt.NPC_NAME,
            next = 2,
            prefix .. "These <rainbow><wave>crystalline surfaces</wave></rainbow> will allow you to <rainbow>accelerate</rainbow> along them, but only as long as you're touching them and are holding the correct direction" .. postfix
        },

        [2] = {
            speaker = rt.NPC_NAME,
            next = nil,
            "Hold <b>up</b> to go <b>up</b>, hold <b>right</b> to go <b>right</b>, hold <i>diagonally</i> to go <i>diagonally</i>, you'll figure it out"
        }
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