require "common.meta"
require "common.filesystem"

rt.settings.animalese = {
    filetype = "wav",
    silence_eps = 0.06, -- normalized
    attack_decay_duration = 2.5 / 60, -- seconds
    scroll_speed_factor = 1 / 1.5,

    path = "jtalk", -- mount point
    native_prefix = "jtalk", -- native directory name

    export_path = "jtalk/export",
    script_filename = "jtalk/to_phonemes.py",
    hash_filename = "export/.animalese.hash",
    translation_filename = "export/.animalese",
    sample_file_extension = ".wav"
}

--- @class rt.Animalese
rt.Animalese = meta.class("Animales e")

meta.add_signals(rt.Animalese,
    --- @signal (rt.Animalese, id)
    "batch_done",

    --- @signal (rt.Animalese, id, beat_count, beat_type)
    "beat"
)

--- @brief
function rt.Animalese:instantiate()
    -- instanced as singleton, see below
    self:_initialize()
end

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
            "!", --"?",
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

    local success, translation_or_error = pcall(bd.load, animalese_translation_path)
    if not success then return end

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
        [English.AW] = Japanese.A,--{ Japanese.A, Japanese.U },
        [English.AY] = Japanese.I,--{ Japanese.A, Japanese.I },
        [English.EY] = Japanese.I,--{ Japanese.E, Japanese.I },
        [English.OW] = Japanese.O,
        [English.OY] = Japanese.O,
        [English.ER] = Japanese.E--{ Japanese.E, Japanese.RU },
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
                or x == English.QUESTION_MARK
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

        do
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

        if rt.SceneManager:get_current_scene() == nil then
            -- splashscreen only before initialization
            require("common.splash_screen")("translating animalese...")
        end

        -- convert unknown tokens to phonemes in one batch
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
        for _, token in ipairs(tokens) do
            for _, phoneme in ipairs(_token_to_animalese[token]) do
                table.insert(animalese, phoneme)
            end
        end
    end

    return animalese
end

--- @brief
function rt.Animalese:_initialize()
    local prefix = rt.settings.animalese.export_path
    local fallback = bd.join_path(prefix, rt.AnimaleseGender.FEMALE, rt.AnimaleseEmotion.NORMAL)
    if not bd.is_directory(fallback) then
        rt.error("In rt.Animalese: unable to locate fallback directory at `", fallback, "`")
    end

    self._data = {}
    self._queue = {}
    self._queue_i = 0
    self._is_done = {} -- Set

    local data = self._data

    local is_beat = {}
    for x in range(
        rt.AnimalesePhoneme.BEAT,
        rt.AnimalesePhoneme.QUESTION_MARK
    ) do is_beat[x] = true end

    local beat_weights = rt.settings.label.syntax.BEAT_TO_WEIGHT
    local beat_duration = 1 / rt.settings.label.scroll_speed

    local seen_paths = {}

    for gender in values(meta.instances(rt.AnimaleseGender)) do
        if data[gender] == nil then data[gender] = {} end
        for emotion in values(meta.instances(rt.AnimaleseEmotion)) do
            if data[gender][emotion] == nil then data[gender][emotion] = {} end

            local path = bd.join_path(prefix, gender, emotion)
            if not bd.exists(path) then path = fallback end

            local entry = data[gender][emotion]

            for phoneme in values(meta.instances(rt.AnimalesePhoneme)) do
                local beat = is_beat[phoneme] == true

                local full_path = bd.join_path(prefix, gender, emotion, phoneme .. rt.settings.animalese.sample_file_extension)
                if beat or bd.exists(full_path) then
                    data[gender][emotion][phoneme] = {
                        is_initialized = beat,
                        path = ternary(not beat, full_path, nil),
                        sources = {},
                        phoneme = phoneme,
                        is_beat = beat,

                        -- set in _initialize_entry
                        start_t = nil, -- seconds
                        end_t = nil,
                        duration = nil,
                    }

                    seen_paths[full_path] = true
                end
            end

            -- delete unused samples
            --[[
            bd.apply(bd.join_path(prefix, gender, emotion), function(filename)
                if seen_paths[filename] ~= true then
                    rt.warning("In rt.Animalese._initialize: detected unused sample at `", filename, "`. It will be deleted")
                    bd.remove_file(filename)
                end
            end)
            ]]
        end
    end
end

--- @brief
function rt.Animalese:_initialize_entry(entry)
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
            local attack_decay_samples = math.floor(rt.settings.animalese.attack_decay_duration * sample_rate)

            for i = 0, n_samples - 1 do
                local sample = sound_data:getSample(i)

                local envelope
                if i < first_sample_i or i > last_sample_i then
                    envelope = 0
                else
                    local relative_i = i - first_sample_i
                    local active_samples = last_sample_i - first_sample_i
                    local x = active_samples > 1 and (relative_i / (active_samples - 1)) or 0

                    local attack_fraction = math.min(attack_decay_samples, active_samples / 2) / active_samples
                    local decay_fraction  = attack_fraction

                    envelope = rt.InterpolationFunctions.ENVELOPE(x, attack_fraction, decay_fraction)
                end

                sound_data:setSample(i, sample * envelope)
            end

            entry.start_t = first_sample_i / sample_rate
            entry.end_t = last_sample_i / sample_rate
            entry.sound_data = sound_data
            entry.sources = {}
            entry.duration = entry.end_t - entry.start_t

            entry.is_initialized = true
        end
    end
end

--- @brief
function rt.Animalese:queue(phonemes, gender, emotion)
    if gender == nil then gender = rt.AnimaleseGender.FEMALE end
    if emotion == nil then emotion = rt.AnimaleseEmotion.NORMAL end

    if not meta.is_table(phonemes) then phonemes = { phonemes } end

    for phoneme in values(phonemes) do
        meta.assert_enum_value(phoneme, rt.AnimalesePhoneme, 1)
    end

    meta.assert_enum_value(gender, rt.AnimaleseGender, 2)
    meta.assert_enum_value(emotion, rt.AnimaleseEmotion, 3)

    if gender == rt.AnimaleseGender.NONE then return end

    local gender_entry = self._data[gender]
    if gender == nil then
        gender_entry = self._data[rt.Gender.FEMALE]
        rt.critical("In rt.Animalese.talk: no sample files for gender `", gender, "` available")
    end

    local emotion_entry = gender_entry[emotion]
    if emotion == nil then
        emotion_entry = gender_entry[rt.AnimaleseEmotion.NORMAL]
        rt.critical("In rt.Animalese.talk: no sample files for gender `", gender, "` with emotion `", emotion, "` available")
    end

    local beat_duration = 1 / rt.settings.label.scroll_speed * (rt.settings.label.syntax.BEAT_TO_WEIGHT[phonemes] or 0)

    local queue_i = self._queue_i
    self._queue_i = self._queue_i + 1

    for _, phoneme in ipairs(phonemes) do
        local entry = emotion_entry[phoneme]
        if entry == nil then
            rt.critical("In rt.Animalese.talk: no sample files for gender `", gender, "`, emotion `", emotion, "`, phoneme `", phonemes, "` available")
            entry = emotion_entry[rt.AnimalesePhoneme.BEAT]
        end

        if entry.is_initialized == false then
            self:_initialize_entry(entry)
        end

        local is_beat, duration
        if phoneme == rt.AnimalesePhoneme.BEAT then
            is_beat = true
            duration = beat_duration
        else
            is_beat = false
            duration = entry.duration
        end

        table.insert(self._queue, {
            id = queue_i,
            entry = entry,
            is_beat = is_beat,
            duration = duration, -- seconds
            elapsed = 0
        })
    end

    return queue_i
end

--- @brief
function rt.Animalese:queue_beat(duration, gender, emotion)
    if gender == nil then gender = rt.AnimaleseGender.FEMALE end
    if emotion == nil then emotion = rt.AnimaleseEmotion.NORMAL end
    meta.assert_enum_value(gender, rt.AnimaleseGender, 2)
    meta.assert_enum_value(emotion, rt.AnimaleseEmotion, 3)

    if gender == rt.AnimaleseGender.NONE then return end

    local queue_i = self._queue_i
    self._queue_i = self._queue_i + 1

    table.insert(self._queue, {
        id = queue_i,
        entry = nil,
        is_beat = true,
        duration = duration, -- seconds
        elapsed = 0
    })

    return queue_i
end

--- @brief
function rt.Animalese:talk(text, gender, emotion)
    if gender == nil then gender = rt.AnimaleseGender.FEMALE end
    if emotion == nil then emotion = rt.AnimaleseEmotion.NORMAL end

    meta.assert_typeof(text, "String", 1)
    meta.assert_enum_value(gender, rt.AnimaleseGender, 2)
    meta.assert_enum_value(emotion, rt.AnimaleseEmotion, 3)

    local translated = rt.Animalese:translate(text)
    if translated == nil or #translated == 0 then return end

    local queue_is = {}
    for phoneme in values(translated) do
        table.insert(queue_is, rt.Animalese:queue(phoneme, gender, emotion))
    end

    return table.unpack(queue_is)
end

--- @brief
function rt.Animalese:remove(id)
    local to_remove = {}
    for i, entry in ipairs(self._queue) do
        if entry.id == id then
            table.insert(to_remove, i, 1)
        end
    end

    for i in values(to_remove) do
        table.remove(self._queue, i)
    end
end

--- @brief
function rt.Animalese:get_is_done(batch_id)
    return self._is_done[batch_id] == true
end

function rt.Animalese:update(delta)
    local remaining = delta
    while remaining > 0 do
        local current = self._queue[1]
        if current == nil then return end

        local time_left = current.duration - current.elapsed
        if remaining < time_left then
            current.elapsed = current.elapsed + remaining
            return
        end

        remaining = math.max(0, remaining - time_left)

        self._is_done[current.id] = true
        table.remove(self._queue, 1)

        local next = self._queue[1]

        if next == nil then return end

        if not next.is_beat then
            local free_source = nil
            for source in values(next.sources) do
                if not source:isPlaying() then
                    free_source = source
                    break
                end
            end

            if free_source == nil then
                free_source = love.audio.newSource(next.entry.sound_data, "static")
                table.insert(next.entry.sources, free_source)
            end

            free_source:seek(next.entry.start_t)
            free_source:setPitch(rt.random.number(0.9, 1.1))
            free_source:play()
        end
    end
end

rt.Animalese = meta.as_singleton(rt.Animalese)
rt.Animalese:_load_precomputed()

do -- try retranslate dialog / translation
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
        or not bd.exists(animalese_translation_path)
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

