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

--- @class rt.Animalese
rt.Animalese = meta.class("Animalese")

--- @enum rt.AnimaleseGender
rt.Animalese.Gender = {
    MALE = "takumi",
    FEMALE = "mei"
}
rt.Animalese.Gender = meta.enum("AnimaleseGender", rt.Animalese.Gender)

--- @enum rt.AnimaleseEmotion
rt.Animalese.Emotion = {
    ANGRY = "angry",
    BASHFUL = "bashful",
    HAPPY = "happy",
    NORMAL = "normal",
    SAD = "sad"
}
rt.Animalese.Emotion = meta.enum("AnimaleseEmotion", rt.Animalese.Emotion)

require "jtalk.animalese_phonemes"

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
            rt.critical("In rt.Animalese: phoneme `", phoneme, "` is found on disk but not part of enum `rt.AnimalesePhoneme`")
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
    if gender == nil then gender = rt.AnimaleseGender.FEMALE end
    if emotion == nil then emotion = rt.AnimaleseEmotion.NORMAL end

    meta.assert_enum_value(gender, rt.AnimaleseGender, 2)
    meta.assert_enum_value(emotion, rt.AnimaleseEmotion, 3)

    local data = self._data
    local gender_entry = data[gender] or data[rt.AnimaleseGender.FEMALE]
    local emotion_entry = gender_entry[emotion] or gender_entry[rt.AnimaleseEmotion.NORMAL]

    -- track if the queue was completely empty before we started appending
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
function rt.Animalese:translate(english_text)
    if not bd.is_file("jtalk/to_phonemes.py") then
        rt.error("In rt.Animalese: `jtalk/to_phonemes.py` not present, are you trying to call this function outside build time?")
        return {}
    end

    -- capture tty output
    local command = string.format("python ./jtalk/to_phonemes.py \"%s\"", english_text)
    local f = io.popen(command, 'r')
    local s = assert(f:read('*a'))
    f:close()
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
        else
            local output = error_maybe
            if not meta.is_table(output) then
                return { output }
            else
                return output
            end
        end
    end

    return {} -- unreachable
end

