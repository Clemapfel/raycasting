rt.settings.dialog = {
    path = "assets/text",
    filename = "dialog.lua",

    speaker_key = "speaker",
    speaker_orientation_key = "orientation",
    speaker_orientation_left = "left",
    speaker_orientation_right = "right",
    next_key = "next",
    dialog_choice_key = "choices",
    state_key = "state"
}

--- @class rt.Dialog
rt.Dialog = {}

do
    require "common.filesystem"
    require "common.language"

    local settings = rt.settings.dialog
    local path = bd.join_path(settings.path, bd.get_config().language, settings.filename)
    local load_success, dialog_or_error = pcall(bd.load, path, true, {

    }) -- sandboxed fenv

    if not load_success then
        rt.fatal("In rt.Dialog: when trying to load file at `", path, "`: ", dialog_or_error)
    end

    if not meta.is_table(dialog_or_error) then
        rt.fatal("In rt.Dialog: object returned by `", path, "` is not a table")
    end

    -- make immutable
    rt.Dialog = setmetatable(dialog_or_error, {
        __newindex = function(self, key, value)
            rt.error("In ow.Dialog: trying to set key `", key, "` in dialog table, but it was declared immutable")
            return
        end,

        __index = function(self, key)
            local result = rawget(self, key)
            if result == nil then
                rt.critical("In ow.Dialog: no dialog with id `", key, "` present")

                -- return placeholder
                return {
                    {
                        speaker = "Error",
                        [1] = "(#" .. key .. ")"
                    }
                }
            else
                return result
            end
        end
    })
end