local prefix = "<normal>"
local postfix = "</normal>"

return {
    animalese_test = {

        {
            speaker = "Animalese Test",
            gender = rt.Gender.FEMALE,
            next = 2,
            "What do you think of my <wave><rainbow><b>animalese</b></rainbow></wave> implementation?",
        },

        {
            speaker = "Animalese Test",
            gender = rt.Gender.FEMALE,
            next = 3,
            "You can actually hear it pronounce the words like this: <wave>|phoneme.</wave> <shake>|phoneme.</shake>"
        },

        {
            speaker = "Animalese Test",
            gender = rt.Gender.FEMALE,
            next = 4,
            "It supports multiple intonations, <color=yellow><happy>like this, it sounds way different now.</happy></color>",
            "<color=blue><sad>I'm unhappy with how it sounds though.</sad></color>"
        },

        {
            speaker = "Animalese Test (Male)",
            gender = rt.Gender.MALE,
            next = 5,
            "This now uses a male voice. <angry><color=red>I think the main issue is that the AI announciates each syllable as if it was the start or end of a sentence.</color></angry>",
            "<sad><color=blue>It causes the syllable to feel disconnected instead of flowing into each other like actual speech.</color></sad>"
        },

        {
            speaker = "Animalese Test",
            gender = rt.Gender.FEMALE,
            next = 6,
            "<color=pink><bashful>Another issue I noticed is that the text scroll is uneven, since it has to wait for each syllable to be done playing.</color></bashful>",
        },

        {
            speaker = "Animalese Test",
            gender = rt.Gender.FEMALE,
            next = 7,
            "<color=red><angry>How can I improve my animalese?</angry></color>"
        },

        {
            speaker = "Clem",
            gender = rt.Gender.FEMALE,
            next = nil,
            "<color=yellow><happy>Thank you</happy></color>"
        }

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
}