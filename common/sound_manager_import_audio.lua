local _attack = 5 / 60 -- seconds
local _decay = 5 / 60 -- seconds
local _sigma = 0.3 -- gaussian slope

local _envelope = function(sample_i, n_samples, sample_rate)
    -- convert sample index to time in seconds
    local t = sample_i / sample_rate
    local total_duration = n_samples / sample_rate

    -- calculate phase durations
    local attack_samples = _attack * sample_rate
    local decay_samples = _decay * sample_rate

    -- attack
    if sample_i <= attack_samples then
        local normalized_pos = sample_i / attack_samples
        local x = normalized_pos * 3 - 3
        return math.exp(-(x * x) / (2 * _sigma * _sigma))
    end

    -- decay
    local decay_start = n_samples - decay_samples
    if sample_i >= decay_start then
        local normalized_pos = (sample_i - decay_start) / decay_samples
        local x = normalized_pos * 3
        return math.exp(-(x * x) / (2 * _sigma * _sigma))
    end

    -- sustain
    return 1.0
end

--- @brief loads audio from disk, converts to mono if necessary, and applies envelope
local function _import_audio(sound_path)
    local success, data_or_error = pcall(love.sound.newSoundData, sound_path)
    if not success then
        rt.critical("In rt.SoundManager.play: when trying to play sound at `" .. sound_path .. "`: " .. data_or_error)
        return nil
    end

    local data = data_or_error

    local sample_count = data:getSampleCount()
    local sample_rate = data:getSampleRate()
    local channel_count = data:getChannelCount()
    local bit_depth = data:getBitDepth()

    if sample_count == 0 then
        return true
    end

    local is_mono = channel_count == 1

    local mono_sound_data
    if not is_mono then
        mono_sound_data = love.sound.newSoundData(
            sample_count,
            sample_rate,
            bit_depth,
            1
        )
    else
        mono_sound_data = data
    end

    for i = 0, sample_count - 1 do
        local sample

        -- get sample, convert to mono if necessary
        if not is_mono then
            -- mean of all channels
            local sample_sum = 0
            for channel = 1, channel_count do
                sample_sum = sample_sum + data:getSample(i, channel)
            end
            sample = sample_sum / channel_count
        else
            sample = data:getSample(i, 1)
        end

        -- apply envelope
        local enveloped_sample = sample * _envelope(i, sample_count, sample_rate)

        if bit_depth == 8 then -- uint8_t
            enveloped_sample = math.floor(((enveloped_sample + 1) / 2) * 2^8) / 2^8
        elseif bit_depth == 16 then -- int16_t
            enveloped_sample = math.round(enveloped_sample * 2^16) / 2^16
        end

        mono_sound_data:setSample(i, 1, enveloped_sample)
    end

    if not is_mono then
        data:release()
    end

    return mono_sound_data
end

return _import_audio