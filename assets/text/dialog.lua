return {
    debug_dialog = {
        [1] = {
            portrait = "assets/sprites/portrait.png",
            speaker = "Barboach",
            next = 2,

            "So, you're testing the debug dialog, eh?",
            "Well, let's try to do a long sentence, that will most likey scroll for a long time, Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vivamus lacinia odio vitae vestibulum vestibulum. Cras venenatis euismod malesuada. Nulla facilisi. Curabitur ac felis arcu. Sed vehicula, urna at aliquam rhoncus, urna quam viverra nisi, in interdum massa nibh nec erat. Ut ultricies, justo eu facilisis gravida, arcu libero tincidunt purus, eget scelerisque nunc turpis quis eros. Integer ac ligula nec urna cursus tincidunt. Suspendisse potenti. Phasellus euismod, sapien non fermentum tincidunt, libero orci cursus erat, vitae suscipit nunc felis a libero. Donec vel sapien nec arcu tincidunt tincidunt."
        },

        [2] = {
            portrait = nil,
            speaker = nil,
            next = 4,

            "This is a question?"
        },

        [3] = {
            choices = {
                {
                    "yes",
                    next = nil, -- assumes 4
                },
                {
                    "no",
                    next = 4,
                }
            }
        },

        [4] = {
            portrait = "assets/sprites/portrait.png",
            speaker = "Barboach",
            next = nil,

            "really? Is this really the best way to write dialog?"
         },
    }
}