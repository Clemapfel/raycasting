require "common.meta"
require "common.filesystem"

rt.settings.animalese = {
    filetype = "wav",

    attack_duration = 0.5 / 60, -- seconds
    decay_duration = 0.25 / 60,
    word_overlap = 2.5 / 60, -- seconds
    window_duration = 1 / 30,
    window_overlap = 0.9,

    target_peak = 0.1,
    scroll_speed_factor = 1,
    n_words_per_file = 3,

    path = "jtalk", -- mount point
    native_prefix = "jtalk", -- native directory name

    export_path = "jtalk/export",
    script_filename = "jtalk/to_phonemes.py",
    hash_filename = "export/.animalese.hash",
    translation_filename = "export/.animalese",
    sample_file_extension = ".wav",

    long_postfix = "_long",
    question_postfix = "_q",
    question_max_pitch = 1.1,
    question_n_phonemes = 5,

    pitch_variance_magnitude = 0.25
}

--- @class rt.Animalese
rt.Animalese = meta.class("Animalese")

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
        [English.IY] = Japanese.I,
        [English.UH] = Japanese.U,
        [English.UW] = Japanese.U,
        [English.AW] = Japanese.AU,
        [English.AY] = Japanese.AI,
        [English.EY] = Japanese.EI,
        [English.OW] = Japanese.O,
        [English.OY] = Japanese.O,
        [English.ER] = Japanese.E,
    }

    local english_suffix_vowel_to_japanese_vowel = {
        [English.AA] = Japanese.O,
        [English.AE] = Japanese.A,
        [English.AH] = Japanese.A,
        [English.AO] = Japanese.OU,
        [English.EH] = Japanese.EI,
        [English.IH] = Japanese.I,
        [English.IY] = Japanese.II,
        [English.UH] = Japanese.U,
        [English.UW] = Japanese.UU,
        [English.AW] = Japanese.AU,
        [English.AY] = Japanese.AI,
        [English.EY] = Japanese.EI,
        [English.OW] = Japanese.OU,
        [English.OY] = Japanese.OI,
        [English.ER] = Japanese.E,
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
        [English.V] = "V",
        [English.Z]  = "Z",
        [English.ZH] = "J",
        [English.CH] = "SH",
        [English.JH] = "J",
        [English.M]  = "M",
        [English.N]  = "N",
        [English.NG] = "G",
        [English.L] = "R",
        [English.R] = "R",
        [English.W] = "W",
        [English.Y] = "Y",
    }

    local _remap = {} -- no remap

    --- @brief
    function rt.Animalese:_english_phonemes_to_animalese_phonemes(phonemes)
        meta.assert(phonemes, "Table")

        if table.is_empty(phonemes) then
            return { rt.AnimalesePhoneme.BEAT }
        end

        for i, phoneme in ipairs(phonemes) do
            rt.assert(meta.is_enum_value(phoneme, rt.EnglishPhoneme), "In rt.Animalese._english_to_animalese_phonemes: phoneme `", phoneme, "` at `", i, "` is not a value of rt.EnglishPhonemes")
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
                or x == English.END
        end

        local result = {}

        local phoneme_used = {}
        for syllable in values(meta.instances(rt.AnimalesePhoneme)) do
            phoneme_used[syllable] = false
        end

        local push = function(x)
            local seen = {}
            while _remap[x] ~= nil do
                x = _remap[x]
                if seen[x] then break end
                seen[x] = true
            end

            rt.assert(meta.is_enum_value(x, Japanese), "In push: `", x, "` is not a japanese phenome")
            table.insert(result, x)
            phoneme_used[x] = true
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
                    elseif next == English.QUESTION_MARK then
                        push(Japanese.QUESTION_MARK)
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
                elseif current == English.QUESTION_MARK then
                    push(rt.AnimalesePhoneme.QUESTION_MARK)
                    i = i + 1
                elseif current == nil then
                    break
                else
                    rt.critical("In rt.Animalese.translate: unhandled character `", current, "`")
                end
            end
        end

        local unused = {}
        for phoneme, used in pairs(phoneme_used) do
            if used == false then
                table.insert(unused, phoneme)
            end
        end

        rt.warning("In rt.Animalese: deleting unused phoneme `{", table.concat(unused, ", "), "}`")
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

do
    local long_postfix = rt.settings.animalese.long_postfix
    local question_postfix = rt.settings.animalese.question_postfix

    rt.AnimalesePronounciation = {
        NORMAL = "",
        LONG = long_postfix,
        NORMAL_QUESTION = question_postfix,
        LONG_QUESTION = long_postfix .. question_postfix
    }
end

rt.AnimalesePronounciation = meta.enum("AnimalesePronounciation", rt.AnimalesePronounciation)

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
    self._all_entries = {}

    local data = self._data

    local is_beat = {}
    for x in range(
        rt.AnimalesePhoneme.BEAT,
        rt.AnimalesePhoneme.QUESTION_MARK
    ) do is_beat[x] = true end

    local beat_weights = rt.settings.label.syntax.BEAT_TO_WEIGHT
    local beat_duration = 1 / rt.settings.label.scroll_speed

    local extension = rt.settings.animalese.sample_file_extension

    local seen_paths = {}

    for gender in values(meta.instances(rt.AnimaleseGender)) do
        if data[gender] == nil then data[gender] = {} end
        for emotion in values(meta.instances(rt.AnimaleseEmotion)) do
            if data[gender][emotion] == nil then data[gender][emotion] = {} end

            local path = bd.join_path(prefix, gender, emotion)
            if not bd.exists(path) then path = fallback end

            for phoneme in values(meta.instances(rt.AnimalesePhoneme)) do
                local beat = is_beat[phoneme] == true
                local entry = {
                    phoneme = phoneme,
                    is_beat = beat
                }

                if not beat then
                    for pronounciation in values(meta.instances(rt.AnimalesePronounciation)) do
                        local full_path = bd.join_path(prefix, gender, emotion, phoneme .. pronounciation .. extension)
                        entry[pronounciation] = {
                            is_initialized = false,
                            path = full_path,
                            sources = {},
                            x = {}, -- { start_t, end_t, duration }
                            peak = nil
                        }

                        seen_paths[full_path] = true
                    end
                end

                data[gender][emotion][phoneme] = entry
                table.insert(self._all_entries, entry)
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


    local config = {
        gain = 0.05,
        late_gain = 0.09,
        early_gain = 0.1,
        decay_time = 2,
    }

    local points = 1
    local update_effects = function()
        self._sound_effects = {
            rt.ReverbSoundEffect(config)
        }
    end
    update_effects()

    if false then
        local pointers = {
            [1] = "gain", [2] = "late_gain", [3] = "early_gain", [4] = "decay_time"
        }
        local current_pointer = 1
        DEBUG_INPUT:signal_connect("pressed", function(_, which)
            if which == rt.InputAction.UP then
                config[pointers[current_pointer]] = config[pointers[current_pointer]] + 0.01
            elseif which == rt.InputAction.DOWN then
                config[pointers[current_pointer]] = config[pointers[current_pointer]] - 0.01
            elseif which == rt.InputAction.LEFT then
                current_pointer = math.max(1, current_pointer - 1)
            elseif which == rt.InputAction.RIGHT then
                current_pointer = math.min(#pointers, current_pointer + 1)
            end

            update_effects()
            dbg(pointers[current_pointer], config)
        end)
    end
end

local function _detect_sections(sound_data, emotion)
    local total_duration = sound_data:getDuration()
    local n_samples = sound_data:getSampleCount()
    local sample_rate = sound_data:getSampleRate()

    local samples = {}
    for i = 1, n_samples do samples[i] = sound_data:getSample(i - 1) end

    local window_n_samples = math.max(1, math.floor(0.015 * sample_rate))
    local hop_size = math.max(1, math.floor(window_n_samples * 0.5))

    local windows = {}
    for i = 1, n_samples, hop_size do
        local start_index = i
        local end_index = math.min(i + window_n_samples - 1, n_samples)

        if start_index > n_samples then break end

        local energy_sum = 0
        for j = start_index, end_index do
            energy_sum = energy_sum + samples[j] ^ 2
        end

        table.insert(windows, {
            start_i = start_index,
            end_i = end_index,
            magnitude = energy_sum
        })
    end

    local end_eps = rt.settings.animalese.emotion_to_silence_start_eps[emotion] or rt.settings.animalese.default_silence_start_eps
    local start_eps = rt.settings.animalese.emotion_to_silence_start_eps[emotion] or rt.settings.animalese.default_silence_start_eps

    start_eps = start_eps ^ 2
    end_eps = end_eps ^ 2

    local window_sections = {}
    do
        local is_in_word = false
        local window_start_i = 1
        for window_i = 1, #windows do
            local window = windows[window_i]
            if is_in_word == false and window.magnitude > start_eps then
                is_in_word = true
                window_start_i = window_i
            elseif is_in_word == true and window.magnitude < end_eps then
                is_in_word = false
                table.insert(window_sections, {
                    start_i = window_start_i,
                    end_i = window_i,
                })
            end
        end
    end

    local sections = {}
    for _, window_section in ipairs(window_sections) do
        local window_start_i = windows[window_section.start_i].start_i
        local window_end_i = windows[window_section.end_i].end_i

        local start_i, end_i = window_start_i, window_end_i

        for i = window_start_i, window_end_i do
            if samples[i] > start_eps then
                start_i = i
                break
            end
        end

        for i = window_end_i, window_start_i, -1 do
            if samples[i] > end_eps then
                end_i = i
                break
            end
        end

        table.insert(sections, {
            start_i = start_i,
            end_i = end_i,
            duration = (end_i - start_i) / sample_rate
        })
    end

    return sections
end

local function _detect_sections(sound_data)
    local total_duration = sound_data:getDuration()
    local n_samples = sound_data:getSampleCount()
    local sample_rate = sound_data:getSampleRate()

    local samples = {}
    for i = 1, n_samples do samples[i] = sound_data:getSample(i - 1) end

    local window_n_samples = math.max(1, math.floor(1 / 60 * sample_rate))
    local window_overlap = 0.5
    local hop_size = math.max(1, math.floor(window_n_samples * window_overlap))

    -- compute signal energy
    local energy = {}
    local energy_i_to_window = {}
    local window_i = 1
    local min_energy, max_energy = math.huge, -math.huge
    for i = 1, n_samples, hop_size do
        local start_index = i
        local end_index = math.min(i + window_n_samples - 1, n_samples)

        if start_index > n_samples then break end

        local energy_sum = 0
        for j = start_index, end_index do
            energy_sum = energy_sum + samples[j] ^ 2
        end

        energy_i_to_window[window_i] = {
            start_i = start_index,
            end_i = end_index,
            magnitude = energy_sum
        }

        energy[window_i] = energy_sum

        min_energy = math.min(min_energy, energy_sum)
        max_energy = math.max(max_energy, energy_sum)

        window_i = window_i + 1
    end

    local n_words = rt.settings.animalese.n_words_per_file

    ---------------------------------------------------------------------------
    -- TOPOLOGICAL SIGNAL PROCESSING: 1D Persistent Homology & Morse Theory
    ---------------------------------------------------------------------------

    -- Step 1: Extract the initial Morse complex (Strictly alternating Mins/Maxs)
    local C = {}
    table.insert(C, {type = "min", i = 1, e = energy[1]})
    local dir = 1 -- 1 for searching max, -1 for searching min

    for i = 2, #energy do
        if dir == 1 then
            if energy[i] < energy[i-1] then
                table.insert(C, {type = "max", i = i-1, e = energy[i-1]})
                dir = -1
            end
        else
            if energy[i] > energy[i-1] then
                table.insert(C, {type = "min", i = i-1, e = energy[i-1]})
                dir = 1
            end
        end
    end

    -- Ensure the topological boundary conditions (starts and ends with a valley)
    if C[#C].type == "max" then
        table.insert(C, {type = "min", i = #energy, e = energy[#energy]})
    else
        C[#C] = {type = "min", i = #energy, e = energy[#energy]}
    end

    -- Helper to count current macroscopic features (peaks)
    local function get_num_peaks()
        return math.floor(#C / 2)
    end

    -- Fallback: If the signal is dead flat or lacks features
    if get_num_peaks() < n_words then
        -- Generate uniform splits as a fail-safe
        local segments = {}
        local step = math.floor(n_samples / n_words)
        for i = 1, n_words do
            local start_s = (i - 1) * step + 1
            local end_s = (i == n_words) and n_samples or (i * step)
            table.insert(segments, {
                start_i = start_s,
                end_i = end_s,
                duration = (end_s - start_s + 1) / sample_rate
            })
        end
        return segments
    end

    -- Step 2: Topological Simplification (Cancel lowest persistence features)
    -- We merge shallow valleys into adjacent deeper ones until exactly n_words remain
    while get_num_peaks() > n_words do
        local min_persistence = math.huge
        local min_pers_idx = -1

        -- Find the peak with the lowest topological persistence
        for k = 2, #C - 1, 2 do
            local left_min = C[k-1]
            local right_min = C[k+1]

            -- Persistence = peak energy minus the HIGHER of its two bounding valleys
            local persistence = C[k].e - math.max(left_min.e, right_min.e)

            if persistence < min_persistence then
                min_persistence = persistence
                min_pers_idx = k
            end
        end

        -- Cancel the peak and its highest adjacent valley (merging the two valleys)
        local left_min = C[min_pers_idx-1]
        local right_min = C[min_pers_idx+1]

        if left_min.e > right_min.e then
            table.remove(C, min_pers_idx)       -- Remove the max
            table.remove(C, min_pers_idx - 1)   -- Remove the shallower left min
        else
            table.remove(C, min_pers_idx + 1)   -- Remove the shallower right min
            table.remove(C, min_pers_idx)       -- Remove the max
        end
    end

    -- Step 3: Delineate word boundaries using Perceptual (Logarithmic) Knee Detection
    local segments = {}

    -- Convert linear energy to Decibels to compress the dynamic range.
    -- This prevents the geometry from snapping to the extreme peaks.
    local log_energy = {}
    for i = 1, #energy do
        log_energy[i] = 10 * math.log10(energy[i] + 1e-12)
    end

    for w = 1, n_words do
        local left_valley = C[2*w - 1]
        local peak = C[2*w]
        local right_valley = C[2*w + 1]

        local start_window = peak.i
        local end_window = peak.i

        -- -----------------------------------------
        -- Detect Start (Onset)
        -- -----------------------------------------
        local L_left = peak.i - left_valley.i
        local e_start_left = log_energy[left_valley.i]
        local e_end_left = log_energy[peak.i]
        local e_range_left = e_end_left - e_start_left

        if L_left > 0 and e_range_left > 0 then
            local max_deviation = -math.huge
            for j = left_valley.i, peak.i do
                local norm_x = (j - left_valley.i) / L_left
                local norm_y = (log_energy[j] - e_start_left) / e_range_left

                -- Maximize distance below the chord (x - y)
                local deviation = norm_x - norm_y
                if deviation > max_deviation then
                    max_deviation = deviation
                    start_window = j
                end
            end
        else
            start_window = left_valley.i
        end

        -- -----------------------------------------
        -- Detect End (Offset)
        -- -----------------------------------------
        local L_right = right_valley.i - peak.i
        local e_start_right = log_energy[peak.i]
        local e_end_right = log_energy[right_valley.i]
        local e_range_right = e_start_right - e_end_right

        if L_right > 0 and e_range_right > 0 then
            local max_deviation = -math.huge
            for j = peak.i, right_valley.i do
                local norm_x = (j - peak.i) / L_right
                local norm_y = (log_energy[j] - e_end_right) / e_range_right

                -- Maximize distance below the decaying chord ((1 - x) - y)
                local deviation = (1 - norm_x) - norm_y
                if deviation > max_deviation then
                    max_deviation = deviation
                    end_window = j
                end
            end
        else
            end_window = right_valley.i
        end

        -- -----------------------------------------
        -- Finalize Segment
        -- -----------------------------------------
        local start_sample = energy_i_to_window[start_window].start_i
        local end_sample = energy_i_to_window[end_window].end_i
        local duration = (end_sample - start_sample + 1) / sample_rate

        table.insert(segments, {
            start_i = start_sample,
            end_i = end_sample,
            duration = duration
        })
    end

    return segments
end

local function _detect_sections(sound_data, filename)
    local total_duration = sound_data:getDuration()
    local n_samples = sound_data:getSampleCount()
    local sample_rate = sound_data:getSampleRate()

    local samples = {}
    for i = 1, n_samples do samples[i] = sound_data:getSample(i - 1) end

    local window_n_samples = math.max(1, math.floor(rt.settings.animalese.window_duration * sample_rate))
    local window_overlap = rt.settings.animalese.window_overlap
    local hop_size = math.max(1, math.floor(window_n_samples * (1 - window_overlap)))

    -- compute signal energy
    local energy = {}
    local energy_i_to_window = {}
    local window_i = 1
    local min_energy, max_energy = math.huge, -math.huge

    for i = 1, n_samples, hop_size do
        local start_index = i
        local end_index = math.min(i + window_n_samples - 1, n_samples)

        if start_index > n_samples then break end

        local energy_sum = 0
        for j = start_index, end_index do
            local n = j - start_index + 1
            energy_sum = energy_sum + math.abs(samples[j])
        end

        energy_sum = energy_sum / (end_index - start_index)

        energy_i_to_window[window_i] = {
            start_i = start_index,
            end_i = end_index,
            magnitude = energy_sum
        }

        energy[window_i] = energy_sum

        min_energy = math.min(min_energy, energy_sum)
        max_energy = math.max(max_energy, energy_sum)

        window_i = window_i + 1
    end

    -- binary search for threshold after which segmentation yields exactly n slices
    local upper_threshold = max_energy
    local lower_threshold = min_energy

    local target_n = rt.settings.animalese.n_words_per_file

    local is_start_event = function(a, b, threshold)
        return a < threshold and b > threshold
    end

    local is_end_event = function(a, b, threshold)
        return a > threshold and b < threshold
    end

    local find_threshold = function(lower_threshold, upper_threshold, direction)
        local threshold = upper_threshold
        local n_events = 0
        local n_iterations = 0
        repeat
            if direction == 1 then
                local last = energy[1]
                for i = 2, #energy, 1 do
                    local current = energy[i]
                    if (last - current) > threshold then
                        n_events = n_events + 1
                    end
                    last = current
                end
            else
                local last = energy[#energy]
                for i = #energy - 1, 1, -1 do
                    local current = energy[i]
                    if (last - current) > threshold then
                        n_events = n_events + 1
                    end
                    last = current
                end
            end

            local before = threshold
            if n_events <= target_n then
                upper_threshold = threshold
            else
                lower_threshold = threshold
            end
            threshold = (lower_threshold + upper_threshold) / 2

            n_iterations = n_iterations + 1
            if n_iterations > 100 then return lower_threshold end
        until math.abs(before - threshold) < 0.00001
        return threshold
    end

    local start_threshold = find_threshold(min_energy, max_energy, is_start_event, 1)
    local end_threshold = find_threshold(min_energy, max_energy, is_end_event, -1)

    -- final scan for segmentation
    local sections = {}
    local current_section

    do
        local last = energy[1]
        for i = 2, #energy do
            local current = energy[i]
            if current_section == nil and is_start_event(last, current, start_threshold) then
                -- open word section
                local window = energy_i_to_window[i]
                local sample_i = window.start_i
                while sample_i < window.end_i and sample_i < n_samples do
                    if math.abs(samples[sample_i]) >= start_threshold then
                        break
                    end

                    sample_i = sample_i + 1
                end

                current_section = {
                    start_i = sample_i
                }
            elseif current_section ~= nil and is_end_event(last, current, end_threshold) then
                -- close word section
                local window = energy_i_to_window[i]
                local sample_i = window.end_i

                while sample_i > window.start_i and sample_i > 1 do
                    if math.abs(samples[sample_i]) <= end_threshold then
                        break
                    end

                    sample_i = sample_i - 1
                end

                current_section.end_i = sample_i
                current_section.duration = (current_section.end_i - current_section.start_i) / sample_rate
                table.insert(sections, current_section)
                current_section = nil
            end

            last = current
            if #sections == target_n then break end
        end
    end

    return sections
end

--- @brief
function rt.Animalese:_initialize_entry(entry, gender, emotion)
    if entry.is_initialized ~= true then
        local success, sound_data_or_error = pcall(love.sound.newSoundData, entry.path)
        if not success then
            rt.error("In rt.Animalese: failed to initialize source at `", entry.path, "`: ", sound_data_or_error)
        else
            local sound_data = sound_data_or_error

            entry.sections = _detect_sections(
                sound_data,
                entry.path
            ) -- { start_i, end_i, duration }

            local peak = -math.huge

            for section in values(entry.sections) do
                local start_sample = section.start_i
                local end_sample = section.end_i
                section.sound_data = sound_data:slice(start_sample, end_sample - start_sample)

                -- apply envelope
                local n_samples = section.sound_data:getSampleCount()
                local duration = section.sound_data:getDuration()
                local attack_fraction = rt.settings.animalese.attack_duration / duration
                local decay_fraction = rt.settings.animalese.decay_duration / duration

                for sample_i = 1, n_samples do
                    local t = (sample_i - 1) / math.max(n_samples - 1, 1)
                    local sample = section.sound_data:getSample(sample_i - 1)
                    sample = sample * rt.InterpolationFunctions.ENVELOPE(t, attack_fraction, decay_fraction)
                    section.sound_data:setSample(sample_i - 1, sample)
                    peak = math.max(peak, math.abs(sample))
                end

                section.sources = {}
            end

            entry.peak = peak
            entry.is_initialized = true
        end
    end
end

--- @brief
function rt.Animalese:free()
    for entry in values(self._all_entries) do
        for pronounciation in values(meta.instances(rt.AnimalesePronounciation)) do
            local current = entry[pronounciation]
            if current ~= nil and current.is_initialized then
                current.is_initialized = false
                current.sections = nil
                current.sound_data = nil
            end
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

    local pitch_variance = rt.settings.animalese.pitch_variance_magnitude

    for phoneme_i, phoneme in ipairs(phonemes) do
        local phoneme_entry = emotion_entry[phoneme]
        if phoneme_entry == nil then
            rt.critical("In rt.Animalese.talk: no sample files for gender `", gender, "`, emotion `", emotion, "`, phoneme `", phonemes, "` available")
            phoneme_entry = emotion_entry[rt.AnimalesePhoneme.BEAT]
        end

        local is_beat = phoneme == rt.AnimalesePhoneme.BEAT or phoneme == rt.AnimalesePhoneme.QUESTION_MARK
        table.insert(self._queue, {
            id = queue_i,
            phoneme = phoneme,
            pronounciation = rt.AnimalesePronounciation.NORMAL,
            section_i = 1,
            entry = phoneme_entry,
            emotion = emotion,
            is_beat = is_beat,
            duration = ternary(is_beat, beat_duration, nil), -- non-beat duration set in pronounciation
            elapsed = 0,
            pitch = rt.random.number(1 - pitch_variance, 1 + pitch_variance)
        })
    end

    self._pronounciation_needs_update = true
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
        phoneme = rt.AnimalesePhoneme.BEAT,
        pronounciation = rt.AnimalesePronounciation.NORMAL,
        section_i = 1,
        entry = nil,
        is_beat = true,
        duration = duration,
        elapsed = 0,
        is_question = false,
        pitch = 1
    })

    self._pronounciation_needs_update = true
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

local _mod_to_pronounciation = {
    [1] = rt.AnimalesePronounciation.NORMAL,
    [2] = rt.AnimalesePronounciation.LONG,
    [3] = rt.AnimalesePronounciation.NORMAL,
    [4] = rt.AnimalesePronounciation.LONG
}

local _delay_sound_effect = nil

function rt.Animalese:update(delta)
    -- rescan queue to set pronounciation
    if self._pronounciation_needs_update then
        local pitch_variance = rt.settings.animalese.pitch_variance_magnitude

        -- first pass: flip-flop so consecutive copies get different prononuciations
        local signs = {}
        local question_marks = {}
        for i, queue_entry in ipairs(self._queue) do
            if queue_entry.is_beat ~= true then
                local sign = signs[queue_entry.phoneme]
                if sign == nil then
                    sign = 0
                else
                    sign = sign + 1
                end

                signs[queue_entry.phoneme] = sign
                queue_entry.pronounciation = _mod_to_pronounciation[sign % 4 + 1]

            elseif queue_entry.phoneme == rt.AnimalesePhoneme.QUESTION_MARK then
                table.insert(question_marks, i)
            end

            queue_entry.pitch = 1 --+ rt.random.number(-pitch_variance, pitch_variance) -- reset pitch
        end

        -- update pitch, mark words before ? as questions
        for _, i in ipairs(question_marks) do
            local word_seen = false
            for j = i - 1, 1, -1 do
                local entry = self._queue[j]

                if word_seen and entry.is_beat then
                    break
                end

                if entry.phoneme ~= rt.AnimalesePhoneme.BEAT then
                    word_seen = true
                end

                if entry.pronounciation == rt.AnimalesePronounciation.NORMAL then
                    entry.pronounciation = rt.AnimalesePronounciation.NORMAL_QUESTION
                elseif entry.pronounciation == rt.AnimalesePronounciation.LONG then
                    entry.pronounciation = rt.AnimalesePronounciation.LONG_QUESTION
                end

                -- pitch raises towards questionmark
                entry.pitch = math.mix(
                    1,
                    rt.settings.animalese.question_max_pitch,
                    1 - math.clamp(math.abs(j + 1 - i) / rt.settings.animalese.question_n_phonemes, 0, 1)
                )
            end
        end

        -- initialize
        local last_entry_was_beat = true
        for i, queue_entry in ipairs(self._queue) do
            if queue_entry.is_beat ~= true then
                local pronounciation_entry = queue_entry.entry[queue_entry.pronounciation]
                if pronounciation_entry.is_initialized == false then
                    self:_initialize_entry(pronounciation_entry, queue_entry.gender, queue_entry.emotion)
                end

                if last_entry_was_beat then
                    queue_entry.section_i = 1
                else
                    queue_entry.section_i = math.min(
                        rt.random.integer(2, #pronounciation_entry.sections),
                        #pronounciation_entry.sections
                    )
                end

                queue_entry.duration = pronounciation_entry.sections[queue_entry.section_i].duration

                if i ~= #self._queue and not self._queue[1].is_beat then
                    queue_entry.duration = math.max(0, queue_entry.duration - rt.settings.animalese.word_overlap)
                end
            end

            last_entry_was_beat = queue_entry.is_beat
        end

        self._pronounciation_needs_update = false
    end

    local remaining = delta
    while remaining > 0 do
        local current = self._queue[1]
        if current == nil then return end

        self._is_done[current.id] = true

        local time_left = current.duration - current.elapsed
        if remaining < time_left then
            current.elapsed = current.elapsed + remaining
            return
        end

        remaining = math.max(0, remaining - time_left)
        table.remove(self._queue, 1)

        local next_queue_entry = self._queue[1]

        if next_queue_entry == nil then return end

        if not next_queue_entry.is_beat then
            local next_entry = next_queue_entry.entry[next_queue_entry.pronounciation]

            if next_entry.is_initialized ~= true then
                self:_initialize_entry(next_entry, next_queue_entry.gender, next_queue_entry.emotion)
            end

            local section = next_entry.sections[next_queue_entry.section_i]

            local free_source = nil
            for source in values(section.sources) do
                if not source:isPlaying() then
                    free_source = source
                    break
                end
            end

            if free_source == nil then
                free_source = love.audio.newSource(section.sound_data, "static")
                table.insert(section.sources, free_source)
            end


            for effect in values(self._sound_effects) do
                for active in values(free_source:getActiveEffects()) do
                    free_source:setEffect(active, false)
                end

                free_source:setEffect(effect:get_native())
            end

            free_source:setVolume(rt.settings.animalese.target_peak / next_entry.peak)
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
        local this_file = bd.read_file("common/animalese.lua")
        hash = string.sha256(dialog_file) .. string.sha256(translation_file) .. string.sha256(this_file)
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