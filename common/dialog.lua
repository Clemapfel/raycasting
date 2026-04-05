rt.settings.dialog = {
    path = "assets/text",
    filename = "dialog.lua",
    hash_filename = ".hash",
    animalese_translation_filename = ".animalese",

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
    require "jtalk.animalese"

    local settings = rt.settings.dialog

    local language = bd.get_config().language
    local prefix = settings.path
    if not bd.exists(bd.join_path(prefix, language)) then
        rt.critical(
            "In rt.Dialog: trying to load language `",
            language,
            "` but no such folder at `",
            bd.join_path(bd.get_source_directory(), prefix),
            "` exist"
        )

        language = rt.Language.ENGLISH
    end

    local path = bd.join_path(prefix, language, settings.filename)

    if not bd.exists(path) then
        rt.fatal("In rt.Dialog: asset file at `", path, "` does not exist")
    end

    local load_success, dialog_or_error = pcall(bd.load, path, true, {

    }) -- sandboxed fenv

    if not load_success then
        rt.fatal("In rt.Dialog: when trying to load file at `", path, "`: ", dialog_or_error)
    end

    if not meta.is_table(dialog_or_error) then
        rt.fatal("In rt.Dialog: object returned by `", path, "` is not a table")
    end

    local read_success, string_or_error = pcall(bd.read_file, path)
    local current_hash

    if not read_success then
        rt.error("In rt.Dialog: when trying to read file at `", path, "`: ", string_or_error)
    else
        current_hash = string.sha256(string_or_error)
    end

    -- export animalese
    -- compare dialog hash to past hash, if mismatch or not yet generated, regenerate

    local dialog_prefix = rt.settings.filesystem.internal_directory
    if not bd.exists(dialog_prefix) then bd.create_directory(dialog_prefix) end

    dialog_prefix = bd.join_path(dialog_prefix, "dialog")
    if not bd.exists(dialog_prefix) then bd.create_directory(dialog_prefix) end

    local hash_path = bd.join_path(dialog_prefix, settings.hash_filename)
    local translation_path = bd.join_path(dialog_prefix, settings.animalese_translation_filename)

    local should_regenerate = false
    if not bd.exists(hash_path) or not bd.exists(translation_path) or current_hash == nil then
        should_regenerate = true
    else
        local hash_success, hash_or_error = pcall(bd.read_file, hash_path)
        if hash_success == false then
            rt.error("In rt.Dialog: when trying to read file at `", hash_path, "`: ", hash_or_error)
            should_regenerate = true
        else
            should_regenerate = hash_or_error ~= current_hash
        end
    end

    if should_regenerate then
        bd.write_file(hash_path, current_hash, true) -- overwite allowed

        local to_translate = {}

        local is_integer = function(key)
            return meta.is_number(key) and math.fract(key) == 0 and key > 0
        end

        local to_exclude = {}
        for exclude in range(
            settings.speaker_key,
            settings.next_key,
            settings.state_key
        ) do
            to_exclude[exclude] = true
        end

        local should_exclude = function(key)
            return to_exclude[key] == true
        end
        
        -- extract all string
        for dialog in values(dialog_or_error) do
            for entries_key, entries in pairs(dialog) do
                local valid = false
                for key, value in pairs(entries) do
                    if key == settings.dialog_choice_key then
                        for choice in values(value) do
                            table.insert(to_translate, choice[1])
                            valid = true
                        end
                    elseif not should_exclude(key) then
                        table.insert(to_translate, value)
                        valid = true
                    end
                end

                if not valid then
                    rt.warning("In rt.Dialog: entry `", entries_key, "` has not valid lines at integer indices")
                end
            end
        end

        local translations = rt.Animalese:translate(to_translate)
        assert(#translations == #to_translate)

        local to_write = {}
        for i = 1, #translations do
            to_write[to_translate[i]] = translations[i]
        end

        to_write = "return " .. table.serialize(to_write)
        bd.write_file(translation_path, to_write, true) -- overwrite allowed
    else
        local translation_success, translation_or_error = pcall(bd.load, translation_path)
        if not translation_success then
            rt.error("In rt.Dialog: when trying to read file at `", translation_path, "`: ", translation_or_error)
        end

        if not meta.is_table(translation_or_error) then
            rt.error("In rt.Dialog: when trying to read file at `", translation_path, "`: file does not return a table")
        end

        rt.Animalese.load_translation(translation_or_error)
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