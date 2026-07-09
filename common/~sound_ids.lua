--- @class rt.SoundIDs
rt.SoundIDs = {
    keybinding_scene = {
        listening_activated = "todo", --
        listening_aborted = "todo", --
        assign_successfull = "todo", --
        keybinding_invalid = "todo", --
        reset = "todo", --
        save = "todo", --
        no_save = "todo", --
        enter = "todo", --
    },

    settings_scene = {
        reset = "todo", --
        save = "todo", --
    },

    menu_scene = {
        title_screen = {
            player_reflected = "todo", --
            selection = "todo", --
            confirm = "todo", --
            neon_buzz = "todo", --
        },

        stage_select = {
            wind_rush = "todo", --
            debris_continuous = "todo", --
            debris_collision = "todo", --
            frame_expand = "todo",
            frame_contract = "todo",
            frame_move = "todo"
        }
    },

    menu = {
        scrollable_list = {
            scroll = "todo" --
        },

        message_dialog = {
            select_button = "todo", --
            selection = "todo", --
        },

        option_button = {
            selection = "todo" --
        },

        scale = {
            tick = "todo" --
        }
    }
}

rt.SoundIDs = meta.make_id_table(rt.SoundIDs, "rt.SoundIDs", true)

