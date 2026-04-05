rt.settings.dialog = {
    path = "assets/text",
    filename = "dialog.lua"
}

--- @class rt.Dialog
rt.Dialog = {}

do
    require "common.filesystem"
    require "common.language"

    local language = bd.get_config().language
    local prefix = rt.settings.dialog.path
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

    local path = bd.join_path(prefix, language, rt.settings.dialog.filename)

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

    if not read_success then
        rt.error("In rt.Dialog: when trying to read file at `", path, "`: ", string_or_error)
    end

    -- export animalese

    local current_hash = string.sha256(string_or_error)
    local hash_prefix = rt.settings.filesystem.internal_directory
    if not bd.exists(hash_prefix) then bd.create_directory(hash_prefix) end

    hash_prefix = bd.join_path(hash_prefix, "dialog")
    if not bd.exists(hash_prefix) then bd.create_directory(hash_prefix) end

    local hash_path = bd.join_path(hash_prefix, ".hash")

    local should_regenerate = false
    if not bd.exists(hash_path) then
        should_regenerate = true
    else
        local hash_success, hash_or_error = pcall(bd.read_file, hash_path)
        if hash_success == false then
            rt.error("In rt.Dialog: when trying to read file at `", hash_path, "`: ", hash_or_error)
        end

        should_regenerate = hash_or_error ~= current_hash
    end

    if should_regenerate then
        bd.overwrite_file(hash_path, current_hash)


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