require "common.meta"
require "common.filesystem"

-- In your settings configuration:
rt.settings.animalese = {
    asset_path = "jtalk/export",
    phonemes_list_filename = "phonemes_jp.txt",
    filetype = "wav",
    silence_eps = 0.05,
    beat_duration = 0.15, -- seconds

    path = "jtalk/export",
    hash_filename = ".animalese.hash",
    animalese_translation_filename = ".animalese",
}

--- @class rt.Animalese
rt.Animalese = meta.class("Animalese")


require "common.animalese_gender"
require "common.animalese_emotion"
require "common.animalese_phonemes"

local _precomputed = nil

--- @brief
function rt.Animalese:instantiate()
    self._data = {}
    self._queue = {}

    local settings = rt.settings.animalese

    -- get list of phonemes
    local prefix = settings.asset_path
    local phonemes = {}
    for phoneme in bd.iterate_lines(bd.join_path(prefix, settings.phonemes_list_filename)) do
        if not meta.is_enum_value(phoneme, rt.Animalese.Phoneme) then
            rt.warning("In rt.Animalese: phoneme `", phoneme, "` is found on disk but not part of enum `rt.Animalese.Phoneme`")
        else
            table.insert(phonemes, phoneme)
        end
    end

    local data = self._data
    for gender in values(meta.instances(rt.Animalese.Gender)) do
        if data[gender] == nil then data[gender] = {} end

        for emotion in values(meta.instances(rt.Animalese.Emotion)) do
            if data[gender][emotion] == nil then data[gender][emotion] = {} end

            for phoneme in values(phonemes) do
                local path = bd.join_path(prefix, gender, emotion, phoneme) .. "." .. settings.filetype
                if bd.exists(path) then
                    data[gender][emotion][phoneme] = {
                        path = path,
                        phoneme = phoneme,
                        is_initialized = false,
                        source = nil,
                        duration = -1
                    }
                end
            end
        end
    end
end

function rt.Animalese:_get_free_source(entry)
    for i = 1, #entry.sources do
        local src = entry.sources[i]
        if not src:isPlaying() then
            return src
        end
    end

    local new_source = entry.sources[1]:clone()
    table.insert(entry.sources, new_source)
    return new_source
end

function rt.Animalese:queue(gender, emotion, ...)
    if gender == nil then gender = rt.Animalese.Gender.FEMALE end
    if emotion == nil then emotion = rt.Animalese.Emotion.NORMAL end

    meta.assert_enum_value(gender, rt.Animalese.Gender, 2)
    meta.assert_enum_value(emotion, rt.Animalese.Emotion, 3)

    local data = self._data
    local gender_entry = data[gender] or data[rt.Animalese.Gender.FEMALE]
    local emotion_entry = gender_entry[emotion] or gender_entry[rt.Animalese.Emotion.NORMAL]

    -- track if the queue was completely empty before we started appending
    local was_empty = (#self._queue == 0)

    for i = 1, select("#", ...) do
        local phoneme = select(i, ...)

        if phoneme == rt.Animalese.Phoneme.BEAT then
            table.insert(self._queue, {
                is_beat = true,
                duration = rt.settings.animalese.beat_duration,
                timer = 0
            })
        else
            local entry = emotion_entry[phoneme]

            if entry ~= nil then
                if entry.is_initialized ~= true then
                    local success, sound_data_or_error = pcall(love.sound.newSoundData, entry.path)
                    if not success then
                        rt.error("In rt.Animalese: failed to initialize source at `", entry.path, "`: ", sound_data_or_error)
                    else
                        local sound_data = sound_data_or_error
                        local n_samples = sound_data:getSampleCount()
                        local eps = rt.settings.animalese.silence_eps

                        local first_sample_i = 0
                        while first_sample_i < n_samples do
                            if math.abs(sound_data:getSample(first_sample_i)) > eps then break end
                            first_sample_i = first_sample_i + 1
                        end

                        local last_sample_i = n_samples - 1
                        while last_sample_i >= 0 do
                            if math.abs(sound_data:getSample(last_sample_i)) > eps then break end
                            last_sample_i = last_sample_i - 1
                        end

                        local sample_rate = sound_data:getSampleRate()

                        entry.start_t = first_sample_i / sample_rate
                        entry.end_t = last_sample_i / sample_rate

                        local initial_source = love.audio.newSource(sound_data)
                        initial_source:setLooping(false)
                        entry.sources = { initial_source }

                        entry.is_initialized = true
                    end
                end

                if entry.is_initialized then
                    table.insert(self._queue, {
                        is_beat = false,
                        entry = entry,
                        active_source = nil
                    })
                end
            else
                rt.critical("In rt.Animalese: no entry for phoneme `", phoneme, "` using gender `", gender, "` with emotion `", emotion, "`")
            end
        end
    end

    if was_empty and #self._queue > 0 then
        local first = self._queue[1]
        if first.is_beat then
            first.timer = 0
        else
            local source = self:_get_free_source(first.entry)
            first.active_source = source
            source:seek(0)
            source:play()
        end
    end
end

function rt.Animalese:update(delta)
    local current = self._queue[1]
    local next_item = self._queue[2]

    if current == nil then return end -- queue empty

    local should_transition = false

    if current.is_beat then
        current.timer = current.timer + delta
        if current.timer >= current.duration then
            should_transition = true
        end
    else
        local transition_time = current.entry.end_t
        if next_item ~= nil then
            if next_item.is_beat then
                transition_time = current.entry.end_t
            else
                transition_time = current.entry.end_t - next_item.entry.start_t
                transition_time = math.max(0, transition_time)
            end
        end

        if current.active_source then
            if current.active_source:tell("seconds") + delta >= transition_time
                or current.active_source:isPlaying() == false
            then
                should_transition = true
            end
        else
            should_transition = true
        end
    end

    if should_transition then
        table.remove(self._queue, 1)

        local new_current = self._queue[1]
        if new_current ~= nil then
            if new_current.is_beat then
                new_current.timer = 0
            else
                local source = self:_get_free_source(new_current.entry)
                new_current.active_source = source
                source:seek(0)
                source:play()
            end
        end
    end
end

--- @brief
function rt.Animalese:_english_to_phoneme(args)
    if not bd.is_file("jtalk/to_phonemes.py") then
        rt.error("In rt.Animalese: `jtalk/to_phonemes.py` not present, are you trying to call this function outside build time?")
        return {}
    end

    local quoted = {}
    for _, text in ipairs(args) do
        table.insert(quoted, string.format("%q", text))
    end

    local command = string.format("python ./jtalk/to_phonemes.py %s", table.concat(quoted, " "))
    rt.log("In rt.Animalese._english_to_phonemes: starting translation of `", #args, "` strings")

    -- capture tty output
    local before = love.timer.getTime()
    local f = io.popen(command, 'r')
    local s = assert(f:read('*a'))
    f:close()

    rt.log("done. Took ", love.timer.getTime() - before, "s")

    s = string.gsub(s, '^%s+', '')
    s = string.gsub(s, '%s+$', '')
    s = string.gsub(s, '[\n\r]+', ' ')

    -- python script returns lua table
    local chunk = load(s)

    if chunk == nil then
        rt.error("In rt.Animalese.translate: output of `jtalk/to_phonemes.py` is malformatted")
        return {}
    else
        local success, error_maybe = pcall(chunk)
        if success ~= true then
            rt.error("In rt.Animalese.translate: when trying to run output of `jtalk/to_phonemes.py`: ", error_maybe)
            return {}
        else
            return { chunk() } -- call again to captue varargs
        end
    end

    return {} -- unreachable
end

--- @brief
function rt.Animalese.load_translation(t) -- sic, static method
    if _precomputed == nil then _precomputed = {} end

    for text, translation in pairs(t) do
        if not meta.is_string(text) then
            rt.critical("In rt.Animalese:load_translation: key `", text, "` is not a string")
            goto continue
        end

        if not meta.is_table(translation) then
            rt.critical("In rt.Animalese.load_translation: value at key `", text, "` is not a table")
            goto continue
        end

        for phoneme in values(translation) do
            if not meta.is_enum_value(phoneme, rt.Animalese.Phoneme) then
                rt.critical("In rt.Animalese.load_translation: for key `", text, "`: `", phoneme, "` is not a valid phoneme")
                goto continue
            end
        end

        _precomputed[text] = translation
        ::continue::
    end
end

do
    local English = rt.Animalese.EnglishPhoneme
    local Japanese = rt.Animalese.Phoneme

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

    local _sanitize = function(str)
        for character in range(
            "\"",
            ".",
            ":",
            ";",
            "!",
            "\t",
            "\n",
            "/",
            "\\",
            "(",
            ")",
            "{",
            "}"
        ) do
            str = string.gsub(str, string.gsub(character, "%p", "%%%1"), "")
        end
        return str
    end

    --- @brief
    function rt.Animalese:translate(...)
        local input
        if meta.is_string(select(1, ...)) then
            input = { ... }
        else
            input = select(1, ...)
        end

        if _precomputed ~= nil then
            local tokens = {}

            require "common.label"
            local proxy = rt.Label()
            for text in values(input) do
                local glyphs = proxy:_parse(text)
                for glyph in values(glyphs) do
                    table.insert(tokens, _sanitize(glyph.text))
                end
            end

            local translation = {}
            for token in values(tokens) do
                local translated = _precomputed[token]
                if translated == nil then
                    rt.error("In rt.Animalese.translate: precomputed translation was loaded, but encountered unknown token `", token, "`")
                end
                table.insert(translation, translated)
            end

            return translation
        end

        -- else, generate externally

        for i = 1, #input do
            input[i] = _sanitize(input[i])
        end

        local table_of_table_of_phonemes = self:_english_to_phoneme(input)

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
                or not meta.is_enum_value(x, English)
        end

        local mapping = {
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

        local result = {}

        for t in values(table_of_table_of_phonemes) do
            for phonemes in values(t) do
                local i = 1
                local n = #phonemes

                local translation = {}

                local push = function(x)
                    x = mapping[x] or x
                    rt.assert(meta.is_enum_value(x, Japanese), "In push: `", x, "` is not a japanese phenome")
                    table.insert(translation, x)
                end

                while i <= n do
                    local current = phonemes[i+0]
                    local next = phonemes[i+1]

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
                            rt.error("Unhandled case: `", current, "`, `", next, "`")
                        end
                    elseif is_vowel(current) then
                        if is_vowel(next) or is_consonant(next) or is_stop(next) then
                            -- pure vowel
                            local vowels = english_pure_vowel_to_japanese_vowel[current]
                            if vowels == nil then
                                rt.error("Unhandled vowel `", next, "`")
                            end

                            for x in values(vowels) do push(x) end
                            i = i + 1
                        else
                            rt.error("Unhandled case: `", current, "`, `", next, "`")
                        end
                    elseif meta.is_enum_value(current, Japanese) then
                        push(current)
                        i = i + 1
                    elseif current == nil then
                        break
                    else
                        rt.critical("In rt.Animalese.translate: unhandled character `", current, "`")
                    end
                end

                table.insert(result, translation)
            end
        end

        return result
    end
end

do
    require "common.filesystem"
    require "common.language"
    require "common.dialog"
    require "common.translation"

    local dialog_settings = rt.settings.dialog
    local dialog_path = bd.join_path(dialog_settings.path, bd.get_config().language, dialog_settings.filename)

    local translation_settings = rt.settings.translation
    local translation_path = bd.join_path(translation_settings.path, bd.get_config().language, translation_settings.filename)

    local animalese_settings = rt.settings.animalese
    local animalese_translation_path = bd.join_path(animalese_settings.path, animalese_settings.animalese_translation_filename)

    local dialog_file = bd.read_file(dialog_path)
    local translation_file = bd.read_file(translation_path)

    local hash = string.sha256(dialog_file) .. string.sha256(translation_file)

    local should_regenerate = false

    bd.mount_path(bd.join_path(bd.get_source_directory(), "jtalk"), "jtalk")
    local hash_path = bd.join_path(animalese_settings.path, animalese_settings.hash_filename)

    if not bd.exists(hash_path) then
        should_regenerate = true
    else
        local old_hash = bd.read_file(hash_path)
        should_regenerate = old_hash ~= hash
    end

    if should_regenerate then
        bd.write_file(hash_path, hash, true) -- overwite allowed

        local lines = {}

        local is_integer = function(key)
            return meta.is_number(key) and math.fract(key) == 0 and key > 0
        end

        -- extract dialog strings

        local to_exclude = {}
        for exclude in range(
            dialog_settings.speaker_key,
            dialog_settings.next_key,
            dialog_settings.state_key
        ) do
            to_exclude[exclude] = true
        end

        local should_exclude = function(key)
            return to_exclude[key] == true
        end

        for dialog in values(rt.Dialog) do
            for entries_key, entries in pairs(dialog) do
                local valid = false
                for key, value in pairs(entries) do
                    if key == dialog_settings.dialog_choice_key then
                        for choice in values(value) do
                            table.insert(lines, choice[1])
                            valid = true
                        end
                    elseif not should_exclude(key) then
                        table.insert(lines, value)
                        valid = true
                    end
                end

                if not valid then
                    rt.warning("In rt.Dialog: entry `", entries_key, "` has not valid lines at integer indices")
                end
            end
        end

        -- extract translation string
        do
            require "common.translation"
            local function parse(to_parse)
                if meta.is_table(to_parse) then
                    for key, value in pairs(to_parse) do
                        if meta.is_table(value) then
                            parse(value)
                        elseif meta.is_string(value) then
                            table.insert(lines, value)
                        end
                    end
                end
            end

            parse(rt.Translation)
        end

        -- use label parser to extract control sequences and map lines to words
        require "common.label"
        local proxy = rt.Label()
        local words = {}
        for line in values(lines) do
            for glyph in values(proxy:_parse(line)) do
                table.insert(words, glyph.text)
            end
        end

        -- then translate words individually
        local translations = rt.Animalese:translate(words)
        assert(#translations == #words)

        local to_write = {}
        for i = 1, #translations do
            to_write[words[i]] = translations[i]
        end

        to_write = "return " .. table.serialize(to_write)
        bd.write_file(
            animalese_translation_path,
            to_write,
            true -- overwrite allowed
        )

        bd.write_file(
            hash_path,
            hash,
            true
        )
    else
        local translation_success, translation_or_error = pcall(bd.load, animalese_translation_path)
        if not translation_success then
            rt.error("In rt.Animalese: when trying to read file at `", translation_path, "`: ", translation_or_error)
        end

        if not meta.is_table(translation_or_error) then
            rt.error("In rt.Dialog: when trying to read file at `", translation_path, "`: file does not return a table")
        end

        rt.Animalese.load_translation(translation_or_error)
    end
end

