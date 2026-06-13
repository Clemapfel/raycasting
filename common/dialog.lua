rt.settings.dialog = {
    path = "assets/text",
    filename = "dialog.lua",

    speaker_key = "speaker",
    speaker_orientation_key = "orientation",
    next_key = "next",
    dialog_choice_key = "choices",
    state_key = "state",
    gender_key = "gender"
}

--- @class rt.Dialog
rt.Dialog = {}

--- @enum rt.DialogSpeakerOrientation
rt.DialogSpeakerOrientation = meta.enum("DialogSpeakerOrientation", {
    LEFT = "left",
    RIGHT = "right"
})

do
    require "common.filesystem"
    require "common.language"
    require "common.translation"
    require "common.animalese_gender"

    local settings = rt.settings.dialog
    local path = bd.join_path(settings.path, bd.get_config().language, settings.filename)

    local load_success, dialog_or_error = pcall(bd.load, path, true, setmetatable({
        rt = {
            SpeakerOrientation = {
                LEFT = rt.DialogSpeakerOrientation.LEFT,
                RIGHT = rt.DialogSpeakerOrientation.RIGHT
            },

            Emotion = {
                ANGRY = rt.AnimaleseEmotion.ANGRY,
                BASHFUL = rt.AnimaleseEmotion.BASHFUL,
                HAPPY = rt.AnimaleseEmotion.HAPPY,
                NORMAL = rt.AnimaleseEmotion.NORMAL,
                SAD = rt.AnimaleseEmotion.SAD
            },

            Gender = {
                MALE = rt.AnimaleseGender.MALE,
                FEMALE = rt.AnimaleseGender.FEMALE
            },

            PLAYER_NAME = rt.Translation.player_name,
            NPC_NAME = rt.Translation.npc_name,
            GHOST_NAME = rt.Translation.ghost_name
        }
    }, {
        __index = function(self, key)
            rt.error("In rt.Dialog: trying to access global `", key, "` but no such value exists")
        end,

        __newindex = function(self, key, value)
            rt.error("In rt.Dialog: trying to set global `", key, "` but the global environment is immutable")
        end
    })) -- sandboxed fenv

    if not load_success then
        rt.fatal("In rt.Dialog: when trying to load file at `", path, "`: ", dialog_or_error)
    end

    if not meta.is_table(dialog_or_error) then
        rt.fatal("In rt.Dialog: object returned by `", path, "` is not a table")
    end

    local valid_keys_to_type = {
        [settings.speaker_key] = mt.String,
        [settings.speaker_orientation_key] = rt.DialogSpeakerOrientation,
        [settings.gender_key] = rt.AnimaleseGender,
        [settings.state_key] = mt.Table,
        [settings.dialog_choice_key] = mt.Table
    }

    local function validate(scope, nodes)
        local function throw(...)
            rt.critical("In rt.Dialog: for dialog `", scope, "`: ", ...)
        end

        local function warn(...)
            rt.critical("In rt.Dialog: for dialog `", scope, "`: ", ...)
        end

        local node_to_is_reachable = {}

        for node_key, node in pairs(nodes) do
            local consecutive_numbers = {}
            for key, value in pairs(node) do
                if meta.is_number(key) then
                    table.insert(consecutive_numbers, key)
                elseif key == settings.next_key then
                    local next_node = nodes[value]
                    if next_node == nil then
                        throw("next value `", value, "` does not point to another valid node")
                    end

                    node_to_is_reachable[next_node] = true
                elseif key == settings.dialog_choice_key then
                    local node_choices = value
                    for i = 1, table.sizeof(node_choices) do
                        if node_choices[i] == nil then
                            throw("choices in node `", node_key, "` are not a consecutive list of tables")
                        end
                    end

                    for choice_key, choice_node in pairs(node_choices) do
                        if not meta.is_number(choice_key) then
                            throw("choices in node `", node_key, "` can only be indexed with numbers, got `", choice_key, "`")
                        end

                        if not meta.is_table(choice_node) then
                            throw("choice #", choice_key, " is not a table")
                        end

                        for k, v in keys(choice_node) do
                            if k == settings.next_key then
                                if nodes[v] == nil then
                                    throw("choices in node `", node_key, "` has next key `", choice_node[settings.next_key], "`, which does not point to a valid node")
                                end

                                node_to_is_reachable[nodes[v]] = true
                            elseif not meta.is_number(k) or k ~= 1 then
                                throw("choices in node `", node_key, "` can only have single line of dialog, which has to be located at [1]")
                            end
                        end
                    end
                else
                    local expected_type = valid_keys_to_type[key]
                    if expected_type == nil then
                        throw("invalid key `", key, "`")
                    end

                    if meta.is_enum(type) then
                        if not meta.is_enum_value(value, type) then
                            throw("for key `", key, "`, expected value of enum `", meta.get_enum_name(type), "`, got `", meta.typeof(value), "`")
                        end
                    elseif meta.is_type(type) then
                        if not meta.isa(value, type) then
                            throw("for key `", key, "`, expected value of type `", meta.get_typename(type), "`, got `", meta.typeof(value), "`")
                        end
                    else
                        if not meta.typeof(value) == type then
                            throw("for key `", key, "`, expected value of type `", type, "`, got `", meta.typeof(value), "`")
                        end
                    end
                end
            end

            table.sort(consecutive_numbers)
            if not consecutive_numbers[1] == 1 then
                throw("list of lines does not start at 1")
            end

            local last = 1
            for i = 2, #consecutive_numbers do
                local n = consecutive_numbers[i]
                if n - last ~= 1 then
                    throw("list of lines is not a consecutive list of numbers, key `", last - 1, "` is unassigned")
                end
            end

            for node_key, node in pairs(nodes) do
                if node_to_is_reachable[node] ~= true then
                    warn("node `", node_key, "` is not reachable")
                end
            end
        end
    end

    local dialog = dialog_or_error

    for scope, nodes in pairs(dialog) do
        validate(scope, nodes)
    end

    -- make immutable
    rt.Dialog = setmetatable(dialog, {
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