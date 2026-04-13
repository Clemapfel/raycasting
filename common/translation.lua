require "common.input_action"

rt.settings.translation = {
    path = "assets/text",
    filename = "translation.lua"
}

--- @class rt.Translation
rt.Translation = {}

do
    require "common.filesystem"
    require "common.language"

    local language = bd.get_config().language
    local prefix = rt.settings.translation.path
    if not bd.exists(bd.join_path(prefix, language)) then
        rt.critical(
            "In rt.Translation: trying to load language `",
            language,
            "` but no such folder at `",
            bd.join_path(bd.get_source_directory(), prefix),
            "` exist"
        )

        language = rt.Language.ENGLISH
    end

    local path = bd.join_path(prefix, language, rt.settings.translation.filename)

    if not bd.exists(path) then
        rt.fatal("In rt.Translation: asset file at `", path, "` does not exist")
    end

    local success, translation_or_error = pcall(bd.load, path, true, {
        math = { huge = math.huge },
        rt = {
            InputAction = meta.instances(rt.InputAction),
            StageGrade = meta.instances(rt.StageGrade)
        }
    }) -- sandboxed fenv

    if not success then
        rt.fatal("In rt.Translation: when trying to load file at `", path, "`: ", translation_or_error)
    end

    if not meta.is_table(translation_or_error) then
        rt.fatal("In rt.Translation: object returned by `", path, "` is not a table")
    end

    -- recursively replace all tables with proxy tables, such that when they are accessed, only the metatables are invoked
    local _as_immutable = function(t)
        return setmetatable(t, {
            __index = function(self, key)
                local value = rawget(self, key)
                if value == nil then
                    rt.warning("In rt.Translation: key `",  key,  "` does not point to valid text")
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

    rt.Translation = _make_immutable(translation_or_error) -- singleton
end
