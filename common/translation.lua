require "common.input_action"

--- @class rt.Translation
rt.Translation = {}

--- @brief initialize translation table as immutable
function rt.initialize_translation(x)
    -- recursively replace all tables with proxy tables, such that when they are accessed, only the metatables are invoked
    local _as_immutable = function(t)
        return setmetatable(t, {
            __index = function(self, key)
                local value = self[key]
                if value == nil then
                    rt.warning("In rt.Translation: key `" .. key .. "` does not point to valid text")
                    return "(#" .. key .. ")"
                end
                return value
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

    meta.assert(x, "Table")
    return _make_immutable(x)
end

rt.Translation = rt.initialize_translation({
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
            [rt.InputAction.Y] = "X UNUSED",
            [rt.InputAction.L] = "Zoom In",
            [rt.InputAction.R] = "Zoom Out",
            [rt.InputAction.START] = "Pause / Unpause",
            [rt.InputAction.SELECT] =  "Select UNUSED",
            [rt.InputAction.UP] = "Move Up",
            [rt.InputAction.RIGHT] = "Move Right",
            [rt.InputAction.DOWN] = "Move Down",
            [rt.InputAction.LEFT] = "Move Left"
        })[action]
    end,

    stage_grade_to_string = function(grade)
        return ({
            [rt.StageGrade.SS] = "S",
            [rt.StageGrade.S] = "A",
            [rt.StageGrade.A] = "B",
            [rt.StageGrade.B] = "C",
            [rt.StageGrade.F] = "D",
            [rt.StageGrade.NONE] = "\u{2014}" -- long dash
        })[grade]
    end,

    -- pause menu
    pause_menu = {
        resume = "Resume",
        retry = "Retry",
        controls = "Controls",
        settings = "Settings",
        exit = "Exit",

        confirm_exit_message = "Return to Main Menu?",
        confirm_exit_submessage = "All unsaved progress will be lost",

        control_indicator_select = "Select",
        control_indicator_move = "Move",
        control_indicator_unpause = "Unpause"
    },

    -- results screen
    overworld_scene = {
        results_screen = {
            flow_percentage = "Flow",
            time = "Time"
        }
    },

    -- title screen
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
            flow_prefix = "Flow",
            time_prefix = "Best Time",
            difficulty_prefix = "Difficulty",

            control_indicator_select = "Select Stage",
            control_indicator_confirm = "Confirm",
            control_indicator_back = "Go Back",

            personal_best_header = "Personal Best",
            grade_header = "Grade"
        }
    },

    -- verbose info
    verbose_info = {
        vsync_title = "VSYNC",
        vsync_description = "TODO",
        vsync_widget = function(fps)
            return "Current FPS: " .. fps
        end,

        music_level_widget = function(percentage)
            return "Music Level: " .. percentage .. "%"
        end,

        sound_effect_level_widget = function(percentage)
            return "Sound Effect Level:  " .. percentage .. "%"
        end,

        fullscreen_title = "Fullscreen",
        fullscreen_description = "TODO",

        msaa_title = "MSAA",
        msaa_description = "TODO",

        sound_effect_level_title = "Sound Effects",
        sound_effect_level_description = "TODO",

        music_level_title = "Music",
        music_level_description = "TODO",

        shake_enabled_title = "Screen Shake",
        shake_enabled_description = "TODO",

        joystick_deadzone_title = "Deadzone",
        joystick_deadzone_description = "TODO",

        performance_mode_enabled_title = "Performance Mode",
        performance_mode_enabled_description = "Reduces visual effects to achieve better performance on low-end machines, does not affect gameplay",

        draw_debug_info_enabled_title = "Draw Debug Information",
        draw_debug_info_enabled_description = "TODO",

        text_speed_title = "Text Speed",
        text_speed_description = "TODO",
        text_speed_visualization_text = "asbdl aiudbalisda idbasd baslidbalis dba",

        input_action_a_title = "A TODO",
        input_action_b_title = "B TODO",
        input_action_x_title = "X TODO",
        input_action_y_title = "Y TODO",
        input_action_up_title = "UP TODO",
        input_action_right_title = "RIGHT TODO",
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

        fullscreen_prefix = "Fullscreen",
        fullscreen_on = "On",
        fullscreen_off = "Off",

        msaa_prefix = "Anti Aliasing",
        msaa_off = "0x",
        msaa_good = "2x",
        msaa_better = "4x",
        msaa_best = "8x",
        msaa_max = "16x",

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

    -- stages
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
})
