--- @class rt.Translation
rt.Translation = {}

--- @brief initialize translation table as immutable
function rt.initialize_translation(x)
    -- recursively replace all tables with proxy tables, such that when they are accessed, only the metatables are invoked
    local _as_immutable = function(t)
        return setmetatable({}, {
            __index = function(_, key)
                local value = t[key]
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
            else
                assert(meta.is_string(v) or meta.is_function(v), "In rt.initialize_translation: unrecognized type: `" .. meta.typeof(v) .. "`")
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
    -- pause menu scene
    pause_menu_scene = {
        resume = "Resume",
        retry = "Retry",
        controls = "Controls",
        settings = "Settings",
        exit = "Exit",

        confirm_exit_message = "Quit the game?",
        confirm_exit_submessage = "All unsaved progress will be lost"
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

            stage_select = "Select Level",
            settings = "Settings",
            credits = "Credits",
            quit = "Quit"
        },

        stage_select = {
            flow_prefix = "Flow",
            time_prefix = "Best Time",
            difficulty_prefix = "Difficulty",

            control_indicator_select = "Select Stage",
            control_indicator_confirm = "Confirm",
            control_indicator_back = "Go Back"
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

        shake_enabled = "Screen Shake",
        shake_enabled_description = "TODO",

        joystick_deadzone_title = "Deadzone",
        joystick_deadzone_description = "TODO",

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
        input_action_l_description = "L DESCRIPTION TODO",
        input_action_r_description = "R DESCRIPTION TODO"
    },

    -- settings screen
    settings_scene = {
        heading = "Settings",

        control_indicator_move = "Select",
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
        control_indicator_back = "Back",
        control_indicator_reset_to_default = "Reset",
        control_indicator_start_sequence = "Set All",

        a_prefix = "Jump / Confirm",
        b_prefix = "Sprint / Go Back",
        y_prefix = "Reset",
        x_prefix = "UNUSED",
        start_prefix = "Pause / Unpause",
        up_prefix = "Move Up",
        right_prefix = "Move Right",
        down_prefix = "Move Down",
        left_prefix = "Move Left",
        l_prefix = "Zoom In",
        r_prefix = "Zoom Out",
    }
})
