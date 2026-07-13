return {
    -- game state
    game_state = {
        validate_keybinding_error = {
            unassigned_keyboard_message = "The following actions do not have an assigned keyboard key:",
            unassigned_controller_message = "The following actions od not have an assigned gamepad button:",
            double_assigned_keyboard_message = "The following keyboard keys are assigned to more than one action:",
            double_assigned_controller_message = "The following gamepad buttons are assigned to more than one action:"
        },
    },

    input_action_to_string = function(action)
        return ({
            [rt.InputAction.UP]       = "Move Up",
            [rt.InputAction.RIGHT]    = "Move Right",
            [rt.InputAction.DOWN]     = "Move Down",
            [rt.InputAction.LEFT]     = "Move Left",
            [rt.InputAction.JUMP]     = "Jump",
            [rt.InputAction.SPRINT]   = "Sprint",
            [rt.InputAction.INTERACT] = "Interact",
            [rt.InputAction.PAUSE]    = "Pause / Unpause",
            [rt.InputAction.CONFIRM]  = "Confirm",
            [rt.InputAction.BACK]     = "Back",
            [rt.InputAction.RESET]    = "Restored Default",
            [rt.InputAction.SPECIAL]  = "???"
        })[action]
    end,

    stage_grade_to_string = function(grade)
        return ({
            [rt.StageGrade.S] = "S",
            [rt.StageGrade.A] = "A",
            [rt.StageGrade.B] = "B",
            [rt.StageGrade.C] = "C",
            [rt.StageGrade.F] = "F",
            [rt.StageGrade.NONE] = "?"
        })[grade]
    end,

    -- pause menu
    pause_menu = {
        resume = "Resume",
        restart = "Restart",
        retry = "Respawn",
        controls = "Controls",
        settings = "Settings",
        exit = "Exit",

        confirm_exit_message = "Return to Main Menu?",
        confirm_exit_submessage = "All unsaved progress will be lost",

        confirm_restart_message = "Restart Stage?",
        confirm_restart_submessage = "All progress will be lost",

        control_indicator_select = "Select",
        control_indicator_move = "Move",
        control_indicator_unpause = "Unpause"
    },

    -- results screen scene
    result_screen_scene = {
        flow = "Flow",
        time = "Time",
        coins = "Coins",
        total = "Personal Best",

        personal_best = "Personal Best",
        new_record = "New Record",

        option_retry_stage = "Retry",
        option_next_stage = "Continue",
        option_return_to_main_menu = "Stage Select",
        option_show_splits = "Show Timings",

        option_control_indicator_move = "Move",
        option_control_indicator_select = "Select",
        option_control_indicator_go_back = "Go Back",
        grade_control_indicator_continue = "Continue"
    },

    -- overworld gameplay
    player_name = "Player",
    npc_name = "NPC",
    ghost_name = "GHOST",

    time_attack_start_countdown = {
        ready = "Ready",
        set = "Set",
        go = "Go!"
    },

    overworld_scene = {
        control_indicator_move = "Move",
        control_indicator_down = "Duck",
        control_indicator_jump = "Jump",
        control_indicator_double_jump = "<i>(while tethered)</i> Double Jump",
        control_indicator_sprint = "Sprint",
        control_indicator_bubble_move = "Move Around",
        control_indicator_interact = "Interact",
        control_indicator_dialog_skip = "",
        control_indicator_dialog_advance = "Advance",
        control_indicator_dialog_exit = "Leave",
        control_indicator_dialog_select_option = "Select",
        control_indicator_dialog_confirm_option = "Confirm",

        control_indicator_air_dash = "<i>(mid-air)</i> Dash",
        control_indicator_slide = "<i>(grounded)</i> Slide Freely",
        control_indicator_hold_down = "<i>(mid-air)</i> Fall Faster",
        control_indicator_omnidirectional_movement = "Move Freely",

        control_indicator_accelerator_surface_hold = "(hold direction) accelerate",


        debug_information_no_coins = "(none)",

        enter_time_attack_dialog_message = "Enter Time Attack Mode?",
        enter_time_attack_dialog_submessage = "Your current progress will be lost. Checkpoints no longer save your progress, dying immediately restarts the stage, your time is tracked and displayed, and your exact path through the stage is recorded such that it can be compared with other runs of the same stage.",

        exit_time_attack_dialog_message = "Exit Time Attack Mode?",
        exit_time_attack_dialog_submessage = "Your current run will be abandoned."
    },

    -- title screen / stage select
    menu_scene = {
        title_screen = {
            title = "Chroma Void",
            control_indicator_select = "Select",
            control_indicator_move = "Move",
            control_indicator_exit = "Quit",

            new_speedrun = "<s>New Run</s>",
            stage_select = "Stage Select",
            settings = "Settings",
            controls = "Controls",
            quit = "Quit"
        },

        stage_select = {
            control_indicator_select = "Select Stage",
            control_indicator_confirm = "Confirm",
            control_indicator_back = "Go Back",
        },

        cleared_label = "clear",
        hundred_percent_label = "100%"
    },

    message_dialog = {
        option_accept = "OK",
        option_cancel = "Cancel"
    },

    stage_select_item = {
        flow_prefix = "Best Flow",
        flow_grade_prefix = "Flow",
        time_prefix = "Best Time",
        time_grade_prefix = "Time",
        coins_prefix = "Collected",
        coins_grade_prefix = "Coins",
        total_grade_prefix = "Total",
    },

    -- verbose info
    verbose_info = {
        vsync_title = "Vertical Synchronization (VSync)",
        vsync_description = "If enabled, limits maximum FPS to the refresh rate of the monitor",
        vsync_widget = function(fps)
            return "Current FPS: " .. fps
        end,

        music_level_widget = function(percentage)
            return "Music Volume: " .. percentage .. "%"
        end,

        sound_effect_level_widget = function(percentage)
            return "Sound Effect Volume:  " .. percentage .. "%"
        end,

        fullscreen_title = "Fullscreen",
        fullscreen_description = "If enabled, automatically resizes to monitor resolution",

        msaa_title = "Multi-Sample Anti Aliasing (MSAA)",
        msaa_description = "Reduces jagged lines and other rendering artifacts.\n\n<b>Performance Impact</b>: moderate",

        bloom_title = "Bloom",
        bloom_description = "Draws a soft glow around all light sources.\n\n<b>Performance Impact</b>: high",

        hdr_title = "HDR (High Dynamic Range)",
        hdr_description = "Uses a larger range of colors for rendering, which can result in better output on certain monitors.\n\n<b>Performance Impact</b>: low",

        downscaling_title = "Resolution Downscaling",
        downscaling_description = "Reduces image quality to increase performance.\n\n<b>Performance Impact</b>: very high",

        dynamic_lighting_title = "Dynamic Lighting",
        dynamic_lighting_description = "Draws and computes lighting for certain objects in real time.\n\n<b>Performance Impact</b>: high",

        reflections_title = "Reflections",
        reflections_description = "Draw a mirror image of the player on certain reflective surfaces.\n\n<b>Performance Impact</b>: negligible",

        background_animation_title = "Animate Background",
        background_animation_description = "If disabled, the background behind a stage will no longer be animated.\n\n<b>Performance Impact</b>: low",

        sound_effect_level_title = "Sound Effects",
        sound_effect_level_description = "Volume of non-music audio playback",

        music_level_title = "Music",
        music_level_description = "Volume of music playback",

        shake_enabled_title = "Screen Shake",
        shake_enabled_description = "If enabled, screen may shake during certain animations",

        controller_vibration_strength_title = "Controller Vibration",
        controller_vibration_strength_description = "How strongly the controller will vibrate",

        joystick_deadzone_title = "Deadzone",
        joystick_deadzone_description = "How far the controller's joysticks have to be moved away from the center before an input is registered",

        input_buffering_enabled_title = "Input Buffering",
        input_buffering_enabled_description = "If enabled, inputs pressed slightly bfeore or after they can be acted on are executed anyway",

        color_blind_mode_enabled_title = "Color Blind Mode",
        color_blind_mode_enabled_description = "Adds various non-diagetic visual elements to objects that rely on the player being able to differentiate colors.\n\n<b>Performance Impact</b>: none",

        draw_debug_info_enabled_title = "Draw Debug Information",
        draw_debug_info_enabled_description = "Whether to show various information at the top of the screen",

        draw_speedrun_splits_enabled_title = "Draw Checkpoint Timings",
        draw_speedrun_splits_enabled_description = "Show frame-perfect timestamps for when a checkpoint is reached or a level is completed. Useful for speedrunners, automatically accounts for lag and load time.",

        text_speed_title = "Text Speed",
        text_speed_description = "How fast letters appear when displaying text during dialog",
        text_speed_visualization_text = "This text is scrolling",

        double_press_threshold_title = "Double Press",
        double_press_threshold_description = "Determines maximum amount of time between two presses allowed to still detect a double-press input",

        sprint_mode_title = "Sprint Mode",
        sprint_mode_description = "Determines the default movement state. In \"Sprint\", the player walks by default and sprints while the button is held. In \"Walk\", the player sprints by default and walks while the button is held.",

        input_action_up_title = "Up",
        input_action_up_description = "Menu: scroll up. Player: move up",

        input_action_right_title = "Right",
        input_action_right_description = "Menu: move right. Player: move right",

        input_action_down_title = "Down",
        input_action_down_description = "Menu: scroll down. Player: duck, or accelerate downward while airborne",

        input_action_left_title = "Left",
        input_action_left_description = "Menu: move left. Player: move left",

        input_action_jump_title = "Jump",
        input_action_jump_description = "Player: jump",

        input_action_sprint_title = "Sprint",
        input_action_sprint_description = "Player: enter sprint mode",

        input_action_interact_title = "Interact",
        input_action_interact_description = "Player: interact with the nearest object or character",

        input_action_confirm_title = "Confirm",
        input_action_confirm_description = "Menu: select current item",

        input_action_back_title = "Back / Undo",
        input_action_back_description = "Menu: return to the previous page, or undo the last action",

        input_action_reset_title = "Reset",
        input_action_reset_description = "Menu: restore the selected setting to its default value",

        input_action_pause_title = "Pause / Unpause",
        input_action_pause_description = "Pause or resume gameplay",

        input_action_special_title = "Special",
        input_action_special_description = "???"
    },

    -- settings screen
    settings_scene = {
        heading = "Settings",

        control_indicator_move = "Move",
        control_indicator_select = "Select",
        control_indicator_back = "Back",
        control_indicator_restore_default = "Reset",
        control_indicator_option_button = "Select Option",
        control_indicator_scale = "Change Value",

        vsync_prefix = "VSync",
        vsync_adaptive = "Adaptive",
        vsync_off = "Off",
        vsync_on = "On",

        color_blind_mode_prefix = "Color Blind Mode",
        color_blind_mode_on = "On",
        color_blind_mode_off = "Off",

        fullscreen_prefix = "Fullscreen",
        fullscreen_on = "On",
        fullscreen_off = "Off",

        msaa_prefix = "Anti Aliasing",
        msaa_off = "0x",
        msaa_good = "2x",
        msaa_better = "4x",
        msaa_best = "8x",

        bloom_prefix = "Bloom",
        bloom_off = "Off",
        bloom_lowest = "Lowest",
        bloom_low = "Low",
        bloom_normal = "Normal",
        bloom_better = "Better",
        bloom_best = "Best",

        hdr_prefix = "HDR",
        hdr_on = "On",
        hdr_off = "Off",

        downscaling_prefix = "Resolution Downscaling",
        downscaling_off = "Off",
        downscaling_half = "2x",
        downscaling_quarter = "4x",
        downscaling_eighth = "8x",

        dynamic_lighting_prefix = "Dynamic Lighting",
        dynamic_lighting_on = "On",
        dynamic_lighting_off = "Off",

        reflections_prefix = "Dynamic Reflections",
        reflections_on = "On",
        reflections_off = "Off",

        background_animation_prefix = "Animate Background",
        background_animation_on = "On",
        background_animation_off = "Off",

        sprint_mode_prefix = "Sprint Mode",
        sprint_mode_hold_to_sprint = "Sprint",
        sprint_mode_hold_to_walk = "Walk",

        shake_prefix = "Screen Shake",
        shake_on = "On",
        shake_off = "Off",

        controller_vibration_strength_prefix = "Controller Vibration",
        controller_vibration_strength_on = "On",
        controller_vibration_strength_off = "Off",

        input_buffering_enabled_prefix = "Input Buffering",
        input_buffering_enabled_on = "Enabled",
        input_buffering_enabled_off = "Disabled",

        draw_debug_info_prefix = "Draw Debug Info",
        draw_debug_info_on = "Yes",
        draw_debug_info_off = "No",

        draw_speedrun_splits_prefix = "Draw Checkpoint Times",
        draw_speedrun_splits_on = "Yes",
        draw_speedrun_splits_off = "No",

        music_level_prefix = "Music",
        sound_effect_level_prefix = "Sound Effects",
        joystick_deadzone_prefix = "Deadzone",
        text_speed_prefix = "Text Speed",
        double_press_threshold_prefix = "Double Press"
    },

    -- keybinding scene
    keybinding_scene = {
        heading = "Controls",

        confirm_exit_message = "Exit without saving?",
        confirm_exit_submessage = "Any changes made to the keybindings will be lost.",

        confirm_reset_to_default_message = "Reset all keybindings to default?",
        confirm_reset_to_default_submessage = "This will overwrite the current keybindings. Cannot be undone.",

        keybinding_invalid_message = "Keybinding Invalid",

        control_indicator_move = "Move",
        control_indicator_select = "Select",
        control_indicator_back = "Save",
        control_indicator_reset_to_default = "Reset",
        control_indicator_abort = "Exit"
    },

    -- error handler
    error_handler = {
        prefix_message = "An Error has occurred and the Application was unable to recover.",
        wrote_stack_dump_message = "Wrote stack dump to ",
        unable_to_write_stack_dump_message = "(unable to write stack dump)",
        open_log_or_exit_message = "Press ENTER to open log file, ESCAPE to exit.",
        exit_message = "Press ESCAPE to exit.",
        stack_dump_disabled_message = "(unable to write stack dump, disabled in DEBUG mode)"
    },

    -- ## STAGES ## ---

    stages = { -- order matters
        {
            id = "introductions",
            title = "Introductions",
            target_time = math.huge
        },

        {
            id = "air_dash_node_tutorial",
            title = "A Dashing Experience",
            target_time = math.huge
        },

        {
            id = "accelerator_tutorial",
            title = "TODO",
            target_time = -1
        }

        --[[

        },

        {
            id = "template",
            title = "[DEBUG TEMPLATE]",
            target_time = math.huge,
        },



        {
            id = "portal_tutorial",
            title = "TODO",
            target_time = math.huge,
        },

        ]]
    }
}