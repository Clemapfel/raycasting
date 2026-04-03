require "common.meta"
require "common.filesystem"

-- In your settings configuration:
rt.settings.animalese = {
    asset_path = "jtalk/export",
    phonemes_list_filename = "phonemes_jp.txt",
    filetype = "wav",
    silence_eps = 0.05,
    beat_duration = 0.15 -- seconds
}

--- @enum rt.AnimaleseGender
rt.AnimaleseGender = {
    MALE = "takumi",
    FEMALE = "mei"
}
rt.AnimaleseGender = meta.enum("AnimaleseGender", rt.AnimaleseGender)

--- @enum rt.AnimaleseEmotion
rt.AnimaleseEmotion = {
    ANGRY = "angry",
    BASHFUL = "bashful",
    HAPPY = "happy",
    NORMAL = "normal",
    SAD = "sad"
}
rt.AnimaleseEmotion = meta.enum("AnimaleseEmotion", rt.AnimaleseEmotion)

--- @enum rt.AnimalesePhoneme
rt.AnimalesePhoneme = {
    -- vowels
    A = "a", I = "i", U = "u", E = "e", O = "o",
    -- long vowels
    AA = "aa", II = "ii", UU = "uu", EE = "ee", OO = "oo",

    -- k
    KA = "ka", KI = "ki", KU = "ku", KE = "ke", KO = "ko",
    -- g
    GA = "ga", GI = "gi", GU = "gu", GE = "ge", GO = "go",
    -- s
    SA = "sa", SHI = "shi", SU = "su", SE = "se", SO = "so",
    -- z
    ZA = "za", JI = "ji", ZU = "zu", ZE = "ze", ZO = "zo",
    -- z
    TA = "ta", CHI = "chi", TSU = "tsu", TE = "te", TO = "to",
    -- d
    DA = "da", DI = "di", DU = "du", DE = "de", DO = "do",
    -- n
    NA = "na", NI = "ni", NU = "nu", NE = "ne", NO = "no",
    -- h
    HA = "ha", HI = "hi", HU = "hu", HE = "he", HO = "ho",
    -- b
    BA = "ba", BI = "bi", BU = "bu", BE = "be", BO = "bo",
    -- p
    PA = "pa", PI = "pi", PU = "pu", PE = "pe", PO = "po",
    -- m
    MA = "ma", MI = "mi", MU = "mu", ME = "me", MO = "mo",
    -- y
    YA = "ya", YU = "yu", YO = "yo",
    -- r
    RA = "ra", RI = "ri", RU = "ru", RE = "re", RO = "ro",
    -- w
    WA = "wa", WO = "wo",

    -- palatized k
    KYA = "kya", KYU = "kyu", KYO = "kyo",
    -- palatalized g
    GYA = "gya", GYU = "gyu", GYO = "gyo",
    -- palatalized sh
    SHA = "sha", SHI = "shi", SHU = "shu", SHE = "she", SHO = "sho",
    -- palatalized j
    JA = "ja", JI = "ji", JU = "ju", JE = "je", JO = "jo",
    -- palatalized ch
    CHA = "cha", CHI = "chi", CHU = "chu", CHE = "che", CHO = "cho",
    -- palatalized ts
    TSA = "tsa", TSI = "tsi", TSU = "tsu", TSE = "tse", TSO = "tso",
    -- palatized n
    NYU = "nyu", NYO = "nyo",
    -- palatized h
    HYA = "hya", HYU = "hyu", HYO = "hyo",
    -- palatized f
    FA = "fa", FI = "fi", FU = "fu", FE = "fe", FO = "fo",
    -- palatized b
    BYA = "bya", BYU = "byu", BYO = "byo",
    -- palatized p
    PYA = "pya", PYU = "pyu", PYO = "pyo",
    -- palatized m
    MYA = "mya", MYU = "myu", MYO = "myo",
    -- palatized r
    RYA = "rya", RYU = "ryu", RYO = "ryo",

    -- v (foreign loans)
    VI = "vi", VU = "vu", VE = "ve", VO = "vo",

    -- foreign stops
    THI = "thi", TYU = "tyu", DYU = "dyu",

    -- moraic nasal
    N = "n",

    -- control characters,
    BEAT = "beat",
}
rt.AnimalesePhoneme = meta.enum("AnimalesePhoneme", rt.AnimalesePhoneme)

--- @class rt.Animalese
rt.Animalese = meta.class("Animalese")

--- @brief
function rt.Animalese:instantiate()
    self._data = {}
    self._queue = {}

    local settings = rt.settings.animalese

    -- get list of phonemes
    local prefix = settings.asset_path
    local phonemes = {}
    for phoneme in bd.iterate_lines(bd.join_path(prefix, settings.phonemes_list_filename)) do
        if not meta.is_enum_value(phoneme, rt.AnimalesePhoneme) then
            rt.critical("In rt.Animalese: phoneme `", phoneme, "` is found on disk but not part of enum `rt.AnimalesePhoneme`")
        else
            table.insert(phonemes, phoneme)
        end
    end

    local data = self._data
    for gender in values(meta.instances(rt.AnimaleseGender)) do
        if data[gender] == nil then data[gender] = {} end

        for emotion in values(meta.instances(rt.AnimaleseEmotion)) do
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
    -- Look for a source in the buffer that isn't actively playing
    for i = 1, #entry.sources do
        local src = entry.sources[i]
        if not src:isPlaying() then
            return src
        end
    end

    -- If all existing sources are playing, allocate a new one
    local new_source = entry.sources[1]:clone()
    table.insert(entry.sources, new_source)
    return new_source
end

function rt.Animalese:queue(gender, emotion, ...)
    if gender == nil then gender = rt.AnimaleseGender.FEMALE end
    if emotion == nil then emotion = rt.AnimaleseEmotion.NORMAL end

    meta.assert_enum_value(gender, rt.AnimaleseGender, 2)
    meta.assert_enum_value(emotion, rt.AnimaleseEmotion, 3)

    local data = self._data
    local gender_entry = data[gender] or data[rt.AnimaleseGender.FEMALE]
    local emotion_entry = gender_entry[emotion] or gender_entry[rt.AnimaleseEmotion.NORMAL]

    -- Track if the queue was completely empty before we started appending
    local was_empty = (#self._queue == 0)

    for i = 1, select("#", ...) do
        local phoneme = select(i, ...)

        if phoneme == rt.AnimalesePhoneme.BEAT then
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

                        -- Divided by sample rate to map to seconds correctly
                        entry.start_t = first_sample_i / sample_rate
                        entry.end_t = last_sample_i / sample_rate

                        -- INITIALIZE THE POOL
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
                        active_source = nil -- Will be assigned right before playing
                    })
                end
            else
                rt.critical("In rt.Animalese: no entry for phoneme `", phoneme, "` using gender `", gender, "` with emotion `", emotion, "`")
            end
        end
    end

    -- Kickstart playback ONLY if the queue was empty when we began
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
        -- Standard timer logic for silence
        current.timer = current.timer + delta
        if current.timer >= current.duration then
            should_transition = true
        end
    else
        -- Active overlap logic for actual audio
        local transition_time = current.entry.end_t
        if next_item ~= nil then
            if next_item.is_beat then
                -- Beats don't have leading silence, so just wait until end_t
                transition_time = current.entry.end_t
            else
                -- Overlap the leading silence of the upcoming phoneme
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
        -- Pop current item. If it's an audio source, LÖVE seamlessly finishes
        -- playing the trailing silence naturally in the background.
        table.remove(self._queue, 1)

        local new_current = self._queue[1]
        if new_current ~= nil then
            if new_current.is_beat then
                new_current.timer = 0
            else
                -- Fetch an available source from the buffer and begin playing
                local source = self:_get_free_source(new_current.entry)
                new_current.active_source = source
                source:seek(0)
                source:play()
            end
        end
    end
end

