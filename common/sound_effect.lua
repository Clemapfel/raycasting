--- @brief
rt.AudioEffect = meta.class("AudioEffect")

--- @brief
function rt.AudioEffect.stereo_to_mono(stereo_data_or_path)
    local stereo_data
    if meta.is_string(stereo_data_or_path) then
        stereo_data = love.sound.newSoundData(stereo_data_or_path)
    else
        assert(stereo_data_or_path:typeOf("SoundData"), "In rt.AudioEffect.stereo_to_mono: expected `love.SoundData`, got `" .. meta.typeof(stereo_data_or_path) .. "`")
        stereo_data = stereo_data_or_path
    end

    if stereo_data:getSampleCount() == 1 then return stereo_data end

    local sample_rate = stereo_data:getSampleRate()
    local bit_depth = stereo_data:getBitDepth()
    local samples_per_channel = stereo_data:getSampleCount() / 2 -- stereo has 2 channels

    assert(bit_depth == 8 or bit_depth == 16, "Unsupported bit depth in stereo_to_mono")

    -- create mono SoundData (1 channel)
    local mono_data = love.sound.newSoundData(samples_per_channel, sample_rate, bit_depth, 1)

    local sample_t = ternary(bit_depth == 16, "int16_t", "uint8_t")
    local sample_size = ffi.sizeof(sample_t)

    local stereo_ptr = ffi.cast(sample_t .. "*", stereo_data:getFFIPointer())
    local mono_ptr = ffi.cast(sample_t .. "*", mono_data:getFFIPointer())

    if bit_depth == 16 then
        -- 16-bit signed samples
        for i = 0, samples_per_channel - 1 do
            local left_sample = stereo_ptr[i * 2 + 0] -- left channel
            local right_sample = stereo_ptr[i * 2 + 1] -- right channel

            -- Average the channels and clamp to prevent overflow
            local averaged = math.mix(tonumber(left_sample), tonumber(right_sample), 0.5)
            averaged = math.clamp(averaged, -32768, 32767)

            mono_ptr[i] = averaged
        end
    else
        -- 8-bit unsigned samples (0-255, with 128 being center/silence)
        for i = 0, samples_per_channel - 1 do
            local left_sample = stereo_ptr[i * 2 + 0] -- left channel
            local right_sample = stereo_ptr[i * 2 + 1] -- right channel

            -- vverage the channels and clamp to prevent overflow
            local averaged = math.mix(tonumber(left_sample), tonumber(right_sample), 0.5)
            averaged = math.clamp(averaged, 0, 255)

            mono_ptr[i] = averaged
        end
    end

    return mono_data
end