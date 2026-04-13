require "common.meta"
require "common.filesystem"

rt.settings.animalese = {
    filetype = "wav",
    silence_eps = 0.05,

    path = "jtalk",
    native_prefix = "jtalk",

    script_filename = "jtalk/to_phonemes.py",
    hash_filename = "export/.animalese.hash",
    translation_filename = "export/.animalese",
}

--- @class rt.Animalese
rt.Animalese = meta.class("Animalese")

require "common.animalese_gender"
require "common.animalese_emotion"
require "common.animalese_phonemes"
require "common.label"

do
    local _label = rt.Label()

    local _sanitize = function(str)
        for character in range(
            "\"", "'", "`",
            ".", ",", ":", ";",
            "!", "?",
            "@", "#", "$", "%", "^", "&", "*",
            "-", "+", "=", "~",
            "|",
            "/", "\\",
            "\t", "\n", "\r",
            "[", "]", "<", ">", "(", ")", "{", "}"
        ) do
            str = string.gsub(str, string.gsub(character, "%p", "%%%1"), "")
        end
        return str
    end

    --- @brief
    function rt.Animalese:_text_to_tokens(text)
        local tokens = _label:_parse(text)
        for i, token in ipairs(tokens) do
            tokens[i] = _sanitize(token)
        end

        return tokens
    end
end

local _token_to_animalese = {}

--- @brief
function rt.Animalese:_tokens_to_english_phonemes(tokens)
    local in_filename, out_filename = "in.temp", "out.temp"

    local settings = rt.settings.animalese
    local in_file = bd.join_path(settings.path, in_filename)
    local out_file = bd.join_path(settings.path, out_filename)

    local success, results_or_error = pcall(function(tokens)
        if meta.is_string(tokens) then tokens = { tokens } end
        for i, token in ipairs(tokens) do
            meta.assert_typeof(token, "String", i)
        end

        bd.create_file(in_file, table.concat(tokens, "\n"), true)
        bd.create_file(out_file, "", true)

        local script = bd.join_path(".", settings.script_filename)
        local command = string.format("python " .. script .. " %s %s",
            bd.join_path(bd.get_source_directory(), settings.path, in_filename),
            bd.join_path(bd.get_source_directory(), settings.path, out_filename)
        )

        rt.log("In rt.Animalese._english_to_phonemes: starting translation of `", #tokens, "` strings")

        -- capture tty output
        local before = love.timer.getTime()
        local f = io.popen(command, 'r')
        local s = assert(f:read('*a'))
        f:close()

        rt.log("done. Took ", love.timer.getTime() - before, "s")

        s = string.gsub(s, '^%s+', '')
        s = string.gsub(s, '%s+$', '')
        s = string.gsub(s, '[\n\r]+', ' ')

        if not bd.exists(out_file) then
            rt.error("In rt.Animalese._english_phonemes_to_animalese_phonemes: error when running script at `", script, "`: ", s)
        end

        -- python script writes to outfile

        local success, error_or_result = pcall(bd.load, out_file)
        if success ~= true then
            rt.error("In rt.Animalese.translate: when trying to run output of `jtalk/to_phonemes.py`: ", error_or_result)
            return {}
        else
            return error_or_result
        end
    end, tokens) -- pcall

    bd.remove_file(in_file)
    bd.remove_file(out_file)

    if success == false then
        rt.error(results_or_error)
        return {}
    else
        return results_or_error
    end
end

-- mount on require
bd.mount_path(bd.join_path(
        bd.get_source_directory(),
        rt.settings.animalese.native_prefix
    ),
    rt.settings.animalese.path
)

--- @brief
function rt.Animalese:_export_precomputed()
    local animalese_translation_path = bd.join_path(
        rt.settings.animalese.path,
        rt.settings.animalese.translation_filename
    )

    local to_write = "return " .. table.serialize(_token_to_animalese)
    bd.write_file(
        animalese_translation_path,
        to_write,
        true -- overwrite allowed
    )
end

--- @brief
function rt.Animalese:_load_precomputed()
    local animalese_translation_path = bd.join_path(
        rt.settings.animalese.path,
        rt.settings.animalese.translation_filename
    )

    local translation_success, translation_or_error = pcall(bd.load, animalese_translation_path)
    if not translation_success then
        rt.error("In rt.Animalese: when trying to read file at `", animalese_translation_path, "`: ", translation_or_error)
    end

    if not meta.is_table(translation_or_error) then
        rt.error("In rt.Dialog: when trying to read file at `", animalese_translation_path, "`: file does not return a table")
    end

    if _token_to_animalese == nil then _token_to_animalese = {} end
    for key, value in pairs(translation_or_error) do
        if _token_to_animalese[key] == nil then _token_to_animalese[key] = value end
    end
end

do
    local English = rt.EnglishPhoneme
    local Japanese = rt.AnimalesePhoneme

    local english_is_consonant = {}
    for x in range(
        English.B,
        English.D,
        English.G,
        English.K,
        English.P,
        English.T,
        English.DH,
        English.F,
        English.HH,
        English.S,
        English.SH,
        English.TH,
        English.V,
        English.Z,
        English.ZH,
        English.CH,
        English.JH,
        English.M,
        English.N,
        English.NG,
        English.L,
        English.R,
        English.W,
        English.Y
    ) do
        english_is_consonant[x] = true
    end

    local stress_levels = { "0", "1", "2" }

    local english_is_vowel = {}
    for x in range(
        English.AA,
        English.AE,
        English.AH,
        English.AO,
        English.EH,
        English.IH,
        English.IY,
        English.UH,
        English.UW,
        English.AW,
        English.AY,
        English.EY,
        English.OW,
        English.OY,
        English.ER
    ) do
        english_is_vowel[x] = true
        for stress in values(stress_levels) do
            english_is_vowel[x .. stress] = true
        end
    end

    local english_pure_vowel_to_japanese_vowel = {
        [English.AA] = Japanese.A,
        [English.AE] = Japanese.A,
        [English.AH] = Japanese.A,
        [English.AO] = Japanese.O,
        [English.EH] = Japanese.E,
        [English.IH] = Japanese.I,
        [English.IY] = Japanese.II,
        [English.UH] = Japanese.U,
        [English.UW] = Japanese.UU,
        [English.AW] = { Japanese.A, Japanese.U },
        [English.AY] = { Japanese.A, Japanese.I },
        [English.EY] = { Japanese.EE, Japanese.I },
        [English.OW] = Japanese.OO,
        [English.OY] = Japanese.O,
        [English.ER] = { Japanese.E, Japanese.RU },
    }

    local english_suffix_vowel_to_japanese_vowel = {
        [English.AA] = Japanese.A,
        [English.AE] = Japanese.A,
        [English.AH] = Japanese.A,
        [English.AO] = Japanese.O,
        [English.EH] = Japanese.E,
        [English.IH] = Japanese.I,
        [English.IY] = Japanese.I,
        [English.UH] = Japanese.U,
        [English.UW] = Japanese.U,
        [English.AW] = { Japanese.A, Japanese.U },
        [English.AY] = { Japanese.A, Japanese.I },
        [English.EY] = { Japanese.E, Japanese.I },
        [English.OW] = Japanese.O,
        [English.OY] = Japanese.O,
        [English.ER] = { Japanese.E, Japanese.RU },
    }

    for t in range(
        english_pure_vowel_to_japanese_vowel,
        english_suffix_vowel_to_japanese_vowel
    ) do
        local to_add = {}
        for x, value in pairs(t) do
            for stress in values(stress_levels) do
                to_add[x .. stress] = value
            end
        end

        for k, v in pairs(to_add) do
            t[k] = v
        end

        for k, v in pairs(t) do
            if not meta.is_table(v) then
                t[k] = { v }
            end
        end
    end

    local english_consonant_to_japanese_prefix = {
        [English.B] = "B",
        [English.D] = "D",
        [English.G] = "G",
        [English.K] = "K",
        [English.P] = "P",
        [English.T] = "T",
        [English.DH] = "Z",
        [English.F]  = "F",
        [English.HH] = "H",
        [English.S]  = "S",
        [English.SH] = "SH",
        [English.TH] = "Z",
        [English.V] = "W",
        [English.Z]  = "Z",
        [English.ZH] = "J",
        [English.CH] = "CH",
        [English.JH] = "J",
        [English.M]  = "M",
        [English.N]  = "N",
        [English.NG] = "N",
        [English.L] = "R",
        [English.R] = "R",
        [English.W] = "W",
        [English.Y] = "Y",
    }

    local _remap = {
        ["SI"] = Japanese.SHI,
        ["ZI"] = Japanese.JI,
        ["TI"] = Japanese.CHI,
        ["TU"] = Japanese.TSU,
        ["YI"] = Japanese.JI,
        ["YE"] = Japanese.JE,
        ["WI"] = Japanese.VI,
        ["WE"] = Japanese.VE,
        ["WU"] = Japanese.VU,
        ["VA"] = Japanese.WA
    }

    --- @brief
    function rt.Animalese:_english_phonemes_to_animalese_phonemes(phonemes)
        meta.assert(phonemes, "Table")

        if table.is_empty(phonemes) then
            return { rt.AnimalesePhoneme.BEAT }
        end

        for i, phoneme in ipairs(phonemes) do
            rt.assert(meta.is_enum_value(phoneme, rt.EnglishPhoneme), "In rt.Animalese._english_phoenems_to_animalese_phonemes: phoneme `", phoneme, "` at `", i, "` is not a value of rt.EnglishPhonemes")
        end
        local to_translate = {}

        local is_vowel = function(x)
            return english_is_vowel[x] == true
        end

        local is_consonant = function(x)
            return english_is_consonant[x] == true
        end

        local is_stop = function(x)
            return x == nil
                or x == English.BEAT
                or x == English.COMMA
                or x == English.COLON
                or x == English.END
        end

        local result = {}

        local push = function(x)
            x = _remap[x] or x
            rt.assert(meta.is_enum_value(x, Japanese), "In push: `", x, "` is not a japanese phenome")
            table.insert(result, x)
        end

        local throw = function(...)
            rt.error("In rt.Animalese._english_phonemes_to_animalese_phonemes: ", ...)
        end

        for phoneme in values(phonemes) do
            local i = 1
            local n = #phonemes

            while i <= n do
                local current = phonemes[i + 0]
                local next = phonemes[i + 1]

                if is_consonant(current) then
                    if is_vowel(next) then
                        -- consonant-vowel: form syllable
                        local vowels = english_suffix_vowel_to_japanese_vowel[next]
                        if vowels == nil then
                            rt.error("Unhandled vowel `", next, "`")
                        end

                        push(english_consonant_to_japanese_prefix[current] .. vowels[1])
                        for j = 2, #vowels do push(vowels[j]) end
                        i = i + 2
                    elseif is_consonant(next) or is_stop(next) then
                        if current == "N" then
                            push(Japanese.N)
                        else
                            -- consonant-consonant: use silent u
                            push(english_consonant_to_japanese_prefix[current] .. "U")
                        end
                        i = i + 1
                    else
                        throw("unhandled case: `", current, "`, `", next, "`")
                    end
                elseif is_vowel(current) then
                    if is_vowel(next) or is_consonant(next) or is_stop(next) then
                        -- pure vowel
                        local vowels = english_pure_vowel_to_japanese_vowel[current]
                        if vowels == nil then
                            throw("unhandled vowel `", next, "`")
                        end

                        for x in values(vowels) do push(x) end
                        i = i + 1
                    else
                        throw("unhandled case: `", current, "`, `", next, "`")
                    end
                elseif is_stop(current) then
                    push(rt.AnimalesePhoneme.BEAT)
                    i = i + 1
                elseif current == nil then
                    break
                else
                    rt.critical("In rt.Animalese.translate: unhandled character `", current, "`")
                end
            end
        end

        return result
    end
end

--- @brief
function rt.Animalese:translate(texts, update_precomputed)
    if not meta.is_table(texts) then texts = { texts } end
    if update_precomputed == nil then update_precomputed = true end

    for i, text in ipairs(texts) do
        meta.assert_typeof(text, "String", i)
    end

    -- conver to tokens
    local text_i_to_tokens = {}

    local needs_translation = {}
    for text_i, text in ipairs(texts) do
        local tokens = rt.Animalese:_text_to_tokens(text)
        text_i_to_tokens[text_i] = tokens

        -- extract untranslated
        for token in values(tokens) do
            if _token_to_animalese[token] == nil then
                needs_translation[token] = true
            end
        end
    end

    if not table.is_empty(needs_translation) then
        local tokens = {}
        for token in keys(needs_translation) do table.insert(tokens, token) end

        -- convert unknown tokens to phonemes in one batch
        require("common.splash_screen")("translating animalese...")
        local phonemes = rt.Animalese:_tokens_to_english_phonemes(tokens)

        -- convert phonemes to animalese, update precomputed
        for i, english_phonemes in ipairs(phonemes) do
            _token_to_animalese[tokens[i]] = rt.Animalese:_english_phonemes_to_animalese_phonemes(english_phonemes)
        end

        if update_precomputed == true then rt.Animalese:_export_precomputed() end
    end

    -- convert text to animalese
    local animalese = {}
    for text_i, text in ipairs(texts) do
        local tokens = text_i_to_tokens[text_i]
        local translation = {}
        for token in values(tokens) do
            if DEBUG then
                rt.assert(_token_to_animalese[token] ~= nil, "In rt.Animalese.translate: encountered untranslated token `", token, "`")
            end
            table.insert(translation, _token_to_animalese[token])
        end

        table.insert(animalese, translation)
    end

    return animalese
end

rt.Animalese = meta.as_singleton(rt.Animalese)
rt.Animalese:_load_precomputed()

do
    -- try retranslate dialog / translation
    require "common.filesystem"
    require "common.language"
    require "common.dialog"
    require "common.translation"

    local dialog_settings = rt.settings.dialog
    local dialog_path = bd.join_path(dialog_settings.path, bd.get_config().language, dialog_settings.filename)

    local translation_settings = rt.settings.translation
    local translation_path = bd.join_path(translation_settings.path, bd.get_config().language, translation_settings.filename)

    local animalese_settings = rt.settings.animalese
    local animalese_hash_path = bd.join_path(animalese_settings.path, animalese_settings.hash_filename)
    local animalese_translation_path = bd.join_path(animalese_settings.path, animalese_settings.translation_filename)

    local hash
    do
        local dialog_file = bd.read_file(dialog_path)
        local translation_file = bd.read_file(translation_path)
        hash = string.sha256(dialog_file) .. string.sha256(translation_file)
    end

    local should_regenerate = false
    if not bd.exists(animalese_hash_path)
        or hash ~= bd.read_file(animalese_hash_path)
    then
        should_regenerate = true
    end

    if should_regenerate then
        -- write new hash
        bd.write_file(animalese_hash_path, hash, true) -- overwrite allowed

        local lines = {}
        local function extract(lines, t, seen, to_exclude)
            if meta.is_table(t) then
                if seen[t] == true then return end
                seen[t] = true

                for key, value in pairs(t) do
                    if to_exclude[key] ~= true then
                        extract(lines, value, seen, to_exclude)
                    end
                end
            elseif meta.is_string(t) or meta.is_number(t) then
                table.insert(lines, tostring(t))
            end
        end

        extract(lines, rt.Dialog, {}, {
            [dialog_settings.next_key] = true,
            [dialog_settings.state_key] = true,
            [dialog_settings.emotion_key] = true,
            [dialog_settings.gender_key] = true,
            [dialog_settings.speaker_key] = true
        })

        extract(lines, rt.Translation, {}, {
            -- no excludes
        })

        rt.Animalese:translate(lines) -- automatically updates _precomputed
        rt.Animalese:_export_precomputed()
        rt.Animalese:_load_precomputed() -- reload to verify file integrity
    end
end

