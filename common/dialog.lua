rt.settings.dialog = {
    path = "assets/text",
    filename = "dialog.lua",

    speaker_key = "speaker",
    speaker_orientation_key = "orientation",
    next_key = "next",
    dialog_choice_key = "choices",
    state_key = "state",
    gender_key = "gender",

    default_gender = rt.AnimaleseGender.NONE
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
            NPC_NAME = rt.Translation.npc_name
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

    local dialog = dialog_or_error

    local valid_keys = {}
    for key in range(
        settings.speaker_key,
        settings.speaker_orientation_key,
        settings.next_key,
        settings.dialog_choice_key,
        settings.state_key,
        settings.gender_key
    ) do
        valid_keys[key] = true
    end

    local function validate(scope, nodes)
        local throw = function(message)
            rt.error("In rt.Dialog: for node `", scope, "`: ", message)
        end

        local validate_enum = function(value, enum)
            if not meta.is_enum_value(value, enum) then
                local to_concat = {
                    "value `", value, "` is not part of enum `", meta.get_enum_name(enum), "`. Expected one of "
                }

                for instance in values(meta.instances(enum)) do
                    table.insert(to_concat, string.paste("`", instance, "`"))
                    table.insert(to_concat, ", ")
                end

                table.remove(to_concat, #to_concat) -- last comma
                throw(table.concat(to_concat))
            end
        end

        if nodes[1] == nil then throw("no node at position `1`") end

        for node in values(nodes) do
            local speaker = node[settings.speaker_key]
            local speaker_orientation = node[settings.speaker_orientation_key]
            local next = node[settings.next_key]
            local state = node[settings.state_key]
            local gender = node[settings.gender_key]
            local choice = node[settings.dialog_choice_key]

            if gender == nil then node[settings.gender_key] = rt.settings.dialog.default_gender end

            local consecutive_numbers = {}
            for key, value in pairs(node) do
                if meta.is_number(key) then
                    table.insert(consecutive_numbers, key)
                else
                    if valid_keys[key] ~= true then
                        throw("unknown key `", key, "`")
                    end
                end
            end

            table.sort(consecutive_numbers)
            for i = 1, #consecutive_numbers - 1, 1 do
                if consecutive_numbers[i+1] - consecutive_numbers[i] ~= 1 then
                    throw("lines do not have consecutive numerical indices")
                end
            end

            if node[1] == nil then
                throw("node does not have a line or choice at position `1`")
            end

            if speaker ~= nil and not meta.is_string(speaker) then
                throw("`speaker` is not a string")
            elseif speaker_orientation ~= nil then
                validate_enum(speaker_orientation, rt.DialogSpeakerOrientation)
            elseif next ~= nil then
                -- noop
            elseif state ~= nil and not meta.is_table(state) then
                throw("`state` is not a table")
            elseif gender ~= nil then
                validate_enum(gender, rt.AnimaleseGender)
            end
        end
    end

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