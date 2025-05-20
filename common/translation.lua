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
    title_screen_scene = {
        title = "Chroma Drift",
        level_select = "Start",
        settings = "Settings",

    },

    -- stage select
    stage_select_scene = {
        title_header = "Level",
        difficulty_header = "Difficulty",
        flow_header = "Best Flow %",
        time_header = "Best Time",
        grade_header = "Grade",
    }
})
