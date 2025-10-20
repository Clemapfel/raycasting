require "common.input_action"

--- @class rt.Translation
rt.Translation = {
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
            [rt.InputAction.A] = "Jump / Confirm",
            [rt.InputAction.B] = "Sprint / Go Back",
            [rt.InputAction.X] = "Reset",
            [rt.InputAction.Y] = "UNUSED",
            [rt.InputAction.L] = "Zoom In",
            [rt.InputAction.R] = "Zoom Out",
            [rt.InputAction.START] = "Pause / Unpause",
            [rt.InputAction.SELECT] = "UNUSED",
            [rt.InputAction.UP] = "Move Up",
            [rt.InputAction.RIGHT] = "Move Right",
            [rt.InputAction.DOWN] = "Move Down",
            [rt.InputAction.LEFT] = "Move Left"
        })[action]
    end,

    stage_grade_to_string = function(grade)
        return ({
            [rt.StageGrade.S] = "S",
            [rt.StageGrade.A] = "A",
            [rt.StageGrade.B] = "B",
            [rt.StageGrade.C] = "C",
            [rt.StageGrade.F] = "F",
            [rt.StageGrade.NONE] = "?" --\u{2014}" -- long dash
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
        confirm_restart_submessage = "All Progress will be lost",

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

    -- splits viewer
    splits_viewer = {
        current_header = "Current",
        delta_header = "+/-",
        best_header = "Best",
        overall_prefix = "Total : ",
        unknown = "\u{2014}" -- long dash
    },

    -- overworld gameplay
    player_name = "Player",
    npc_name = "NPC",

    overworld_scene = {
        control_indicator_move = "Move",
        control_indicator_down = "Duck",
        control_indicator_jump = "Jump",
        control_indicator_sprint = "Sprint",
        control_indicator_bubble_move = "Move Around",
        control_indicator_interact = "Interact",
        control_indicator_dialog_confirm = "Advance",
        control_indicator_dialog_leave = "Leave"
    },

    -- title screen / stage select
    menu_scene = {
        title_screen = {
            title = "Chroma Drift",
            control_indicator_select = "Select",
            control_indicator_move = "Move",

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

    stage_select_item = {
        flow_prefix = "Best Flow",
        flow_grade_prefix = "Flow",
        time_prefix = "Best Time",
        time_grade_prefix = "Time",
        coins_grade_prefix = "Collectibles",
        total_grade_prefix = "Total",
        difficulty_prefix = "Difficulty",
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
        fullscreen_description = "If enabled, automatically resizes the window to cover the entire monitor",

        msaa_title = "Multi-Sample Anti Aliasing (MSAA)",
        msaa_description = "Reduces jagged lines and other artifacts, may impact performance",

        bloom_title = "Bloom",
        bloom_description = "TODO",

        sound_effect_level_title = "Sound Effects",
        sound_effect_level_description = "Volume of non-music audio playback",

        music_level_title = "Music",
        music_level_description = "Volume of music playback",

        shake_enabled_title = "Screen Shake",
        shake_enabled_description = "TODO",

        joystick_deadzone_title = "Deadzone",
        joystick_deadzone_description = "How far the controllers joystick has to be moved away from the center before an input is recognized",

        performance_mode_enabled_title = "Performance Mode",
        performance_mode_enabled_description = "Disables various visual-only effects to increase performance",

        color_blind_mode_enabled_title = "Color Blind Mode",
        color_blind_mode_enabled_description = "Adds non-diagetic visual indicators for gameplay elements that rely on differentiating colors",

        draw_debug_info_enabled_title = "Draw Debug Information",
        draw_debug_info_enabled_description = "Whether to show various information at the top of the screen",

        text_speed_title = "Text Speed",
        text_speed_description = "How fast letters appear in dialog boxes",
        text_speed_visualization_text = "this text is scrolling.\nthis text is scrolling.\nthis text is scrolling.",

        sprint_mode_title = "Sprint Button Mode",
        sprint_mode_description = "How TODO",

        input_action_a_title = "A: Jump / Confirm",
        input_action_b_title = "B: Sprint / Go Back",
        input_action_x_title = "X: Unused",
        input_action_y_title = "Y: Unused",
        input_action_up_title = "UP: Move Up",
        input_action_right_title = "RIGHT: Move Right",
        input_action_down_title = "DOWN TODO",
        input_action_left_title = "LEFT TODO",
        input_action_start_title = "START TODO",
        input_action_select_title = "SElECT TODO",
        input_action_l_title = "L TODO",
        input_action_r_title = "R TODO",

        input_action_a_description = "A DESCRIPTION TODO",
        input_action_b_description = "B DESCRIPTION TODO",
        input_action_x_description = "X DESCRIPTION TODO",
        input_action_y_description = "Y  DESCRIPTION TODO",
        input_action_up_description = "UP  DESCRIPTION TODO",
        input_action_right_description = "RIGHT DESCRIPTION TODO",
        input_action_down_description = "DOWN DESCRIPTION TODO",
        input_action_left_description = "LEFT DESCRIPTION TODO",
        input_action_start_description = "START DESCRIPTION TODO",
        input_action_select_description = "SELECT DESCRIPTION TODO",
        input_action_l_description = "L DESCRIPTION TODO",
        input_action_r_description = "R DESCRIPTION TODO"
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
        msaa_max = "16x",

        bloom_prefix = "Bloom",
        bloom_on = "On",
        bloom_off = "Off",

        sprint_mode_prefix = "Sprint Mode",
        sprint_mode_hold = "Hold",
        sprint_mode_toggle = "Toggle",

        shake_prefix = "Screen Shake",
        shake_on = "On",
        shake_off = "Off",

        performance_mode_prefix = "Performance Mode",
        performance_mode_on = "On",
        performance_mode_off = "Off",

        draw_debug_info_prefix = "Draw Debug Info",
        draw_debug_info_on = "Yes",
        draw_debug_info_off = "No",

        music_level_prefix = "Music",
        sound_effect_level_prefix = "Sound Effects",
        joystick_deadzone_prefix = "Deadzone",
        text_speed_prefix = "Text Speed"
    },

    -- keybinding scene
    keybinding_scene = {
        heading = "Controls",

        confirm_exit_message = "Are you sure you want to exit?",
        confirm_exit_submessage = "TODO TODO",

        confirm_reset_to_default_message = "Are you sure you want to reset to default?",
        confirm_reset_to_default_submessage = "TODO TODO",

        keybinding_invalid_message = "Keybinding Invalid",

        control_indicator_move = "Move",
        control_indicator_select = "Select",
        control_indicator_back = "Save",
        control_indicator_reset_to_default = "Reset",
        control_indicator_abort = "Exit"
    },

    -- ## STAGES ## ---

    stages = {
        [1] = {
            id = "tutorial",
            title = "Not a Tutorial",
            description = "tutorial description TODO",
            difficulty = 0,
            target_time = math.huge,
        },

        [2] = {
            id = "boost_tutorial",
            title = "Boost Tutorial",
            description = "boost tutorial description TODO",
            difficulty = 1,
            target_time = math.huge
        },

        [3] = {
            id = "debug_stage",
            title = "Debug Stage",
            description = "debug stage description TODO",
            difficulty = 1,
            target_time = math.huge
        }
    }
}

--- ###

do -- recursively replace all tables with proxy tables, such that when they are accessed, only the metatables are invoked
    local _as_immutable = function(t)
        return setmetatable(t, {
            __index = function(self, key)
                local value = rawget(self, key)
                if value == nil then
                    rt.warning("In rt.Translation: key `" .. key .. "` does not point to valid text")
                    return "(#" .. key .. ")"
                else
                    return value
                end
            end,

            __newindex = function(self, key, new_value)
                rt.error("In rt.Translation: trying to modify text atlas, but it is declared immutable")
            end
        })
    end

    local function _make_immutable(t)
        local to_process = {}
        local n_to_process = 0

        for k, v in pairs(t) do
            if meta.is_table(v) then
                t[k] = _as_immutable(v)
                table.insert(to_process, v)
                n_to_process = n_to_process + 1
            end
        end

        for i = 1, n_to_process do
            _make_immutable(to_process[i])
        end
        return _as_immutable(t)
    end

    -- singleton
    rt.Translation = _make_immutable(rt.Translation)
end