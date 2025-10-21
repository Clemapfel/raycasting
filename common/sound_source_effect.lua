--- @class rt.SoundEffectType
rt.SoundEffectType = meta.enum("SoundEffectType", {
    CHORUS = "chorus",
    COMPRESSION = "compressor",
    DISTORTION = "distortion",
    DELAY = "echo",
    EQUALIZER = "equalizer",
    FLANGER = "flanger",
    REVERB = "reverb",
    RING_MODULATION = "ringmodulator",
    FILTER = "filter"
})

--- @class rt.SoundEffectWaveform
rt.SoundEffectWaveform = meta.enum("SoundEffectWaveform", {
    SINE = "sine",
    SQUARE = "square",
    SAWTOOTH = "sawtooth",
    TRIANGLE = "triangle"
})

--- @class rt.SoundSourceEffect
rt.SoundSourceEffect = meta.class("SoundEffect")

--- @brief
function rt.SoundSourceEffect:instantiate(native_id)
    meta.assert(native_id, "String")
    self._native = native_id
end

--- @brief
function rt.SoundSourceEffect:get_native()
    return self._native
end

-- generate unique hash for any config table
local _hash_config = function(config)
    local to_concat = {}
    -- values would be non-determinitic, but all configs in this file are guaranteed to have the 
    -- same number of entries due to the defaulting logic
    for value in values(config) do
        local as_string
        if meta.is_number(as_string) then
            as_string = tostring(math.floor(as_string * 1000))
        elseif meta.is_boolean(as_string) then
            as_string = ternary(as_string, "true", "false")
        else
            as_string = tostring(as_string)
        end

        rt.assert(as_string ~= nil)
        table.insert(to_concat, as_string)
    end
    
    return table.concat(to_concat, "_")
end

local _default_volume = 1

do
    local _atlas = {}
    local _current_id = 0

    --- @class rt.ChorusSoundEffect
    function rt.ChorusSoundEffect(config)
        if config == nil then config = {} end
        meta.assert(config, "Table")

        if config.waveform == nil then config.waveform = rt.SoundEffectWaveform.SINE end
        if config.phase == nil then config.phase = (90 + 180) / 360 end
        if config.rate == nil then config.rate = 1.1 / 10 end
        if config.depth == nil then config.depth = 0.1 end
        if config.feedback == nil then config.feedback = (0.25 + 1) / 2 end
        if config.delay == nil then config.delay = 0.016 / 0.016 end

        meta.assert(
            config.waveform, "String",
            config.phase, "Number",
            config.rate, "Number",
            config.depth, "Number",
            config.feedback, "Number",
            config.delay, "Number"
        )

        local phase_native = math.mix(config.phase, -180, 180)
        local rate_native = math.mix(config.rate, 0, 10)
        local depth_native = config.depth
        local feedback_native = math.mix(config.feedback, -1, 1)
        local delay_native = math.mix(config.delay, 0, 0.016)

        local hash = _hash_config(config)
        local native_id = _atlas[hash]
        if native_id == nil then
            native_id = "chorus_" .. tostring(_current_id)
            if not love.audio.setEffect(native_id, {
                type = rt.SoundEffectType.CHORUS,
                volume = _default_volume,
                waveform = config.waveform,
                phase = phase_native,
                rate = rate_native,
                depth = depth_native,
                feedback = feedback_native,
                delay = delay_native
            }) then
                rt.critical("In rt.ChorusSoundEffect: unable to create sound effect `", hash, "`")
            end

            _atlas[hash] = native_id
            _current_id = _current_id + 1
        end

        return rt.SoundSourceEffect(native_id)
    end
end

do
    local _native_id

    --- @class rt.CompressionSoundEffect
    function rt.CompressionSoundEffect()
        if _native_id == nil then
            _native_id = "compressor"

            if not love.audio.setEffect(_native_id, {
                type = rt.SoundEffectType.COMPRESSION,
                volume = _default_volume,
                enable = true
            }) then
                rt.critical("In rt.CompressionSoundEffect: unable to create sound effect `", _native_id, "`")
            end
        end

        return rt.SoundSourceEffect(_native_id)
    end
end

do
    local _atlas = {}
    local _current_id = 0

    --- @class rt.DistortionSoundEffect
    function rt.DistortionSoundEffect(config)
        if config == nil then config = {} end
        meta.assert(config, "Table")

        if config.gain == nil then config.gain = (0.2 - 0.01) / (1 - 0.01) end
        if config.edge == nil then config.edge = 0.2 end
        if config.lowcut == nil then config.lowcut = (8000 - 80) / (24000 - 80) end
        if config.center == nil then config.center = (3600 - 80) / (24000 - 80) end
        if config.bandwidth == nil then config.bandwidth = (3600 - 80) / (24000 - 80) end

        meta.assert(
            config.gain, "Number",
            config.edge, "Number",
            config.lowcut, "Number",
            config.center, "Number",
            config.bandwidth, "Number"
        )

        local gain_native = math.mix(config.gain, 0.01, 1)
        local edge_native = config.edge
        local lowcut_native = math.mix(config.lowcut, 80, 24000)
        local center_native = math.mix(config.center, 80, 24000)
        local bandwidth_native = math.mix(config.bandwidth, 80, 24000)

        local hash = _hash_config(config)
        local native_id = _atlas[hash]
        if native_id == nil then
            native_id = "distortion_" .. tostring(_current_id)
            if not love.audio.setEffect(native_id, {
                type = rt.SoundEffectType.DISTORTION,
                volume = _default_volume,
                gain = gain_native,
                edge = edge_native,
                lowcut = lowcut_native,
                center = center_native,
                bandwidth = bandwidth_native
            }) then
                rt.critical("In rt.DistortionSoundEffect: unable to create sound effect `",  hash,  "`")
            end

            _atlas[hash] = native_id
            _current_id = _current_id + 1
        end

        return rt.SoundSourceEffect(native_id)
    end
end

do
    local _atlas = {}
    local _current_id = 0

    --- @class rt.DelaySoundEffect
    function rt.DelaySoundEffect(config)
        if config == nil then config = {} end
        meta.assert(config, "Table")

        if config.delay == nil then config.delay = 0.1 / 0.207 end
        if config.tap_delay == nil then config.tap_delay = 0.1 / 0.404 end
        if config.damping == nil then config.damping = 0.5 / 0.99 end
        if config.feedback == nil then config.feedback = 0.5 end
        if config.spread == nil then config.spread = (-1 + 1) / 2 end

        meta.assert(
            config.delay, "Number",
            config.tap_delay, "Number",
            config.damping, "Number",
            config.feedback, "Number",
            config.spread, "Number"
        )

        local delay_native = math.mix(config.delay, 0, 0.207)
        local tapdelay_native = math.mix(config.tap_delay, 0, 0.404)
        local damping_native = math.mix(config.damping, 0, 0.99)
        local feedback_native = config.feedback
        local spread_native = math.mix(config.spread, -1, 1)

        local hash = _hash_config(config)
        local native_id = _atlas[hash]
        if native_id == nil then
            native_id = "echo_" .. tostring(_current_id)
            if not love.audio.setEffect(native_id, {
                type = rt.SoundEffectType.DELAY,
                volume = _default_volume,
                delay = delay_native,
                tapdelay = tapdelay_native,
                damping = damping_native,
                feedback = feedback_native,
                spread = spread_native
            }) then
                rt.critical("In rt.DelaySoundEffect: unable to create sound effect `",  hash,  "`")
            end

            _atlas[hash] = native_id
            _current_id = _current_id + 1
        end

        return rt.SoundSourceEffect(native_id)
    end
end

do
    local _atlas = {}
    local _current_id = 0

    --- @class rt.EqualizerSoundEffect
    function rt.EqualizerSoundEffect(config)
        if config == nil then config = {} end
        meta.assert(config, "Table")

        if config.low_gain == nil then config.low_gain = (1 - 0.126) / (7.943 - 0.126) end
        if config.low_cut == nil then config.low_cut = (200 - 50) / (800 - 50) end
        if config.low_mid_gain == nil then config.low_mid_gain = (1 - 0.126) / (7.943 - 0.126) end
        if config.low_mid_frequency == nil then config.low_mid_frequency = (500 - 200) / (3000 - 200) end
        if config.low_mid_bandwidth == nil then config.low_mid_bandwidth = (1 - 0.01) / (1 - 0.01) end
        if config.high_mid_gain == nil then config.high_mid_gain = (1 - 0.126) / (7.943 - 0.126) end
        if config.high_mid_frequency == nil then config.high_mid_frequency = (3000 - 1000) / (8000 - 1000) end
        if config.high_mid_bandwidth == nil then config.high_mid_bandwidth = (1 - 0.01) / (1 - 0.01) end
        if config.high_gain == nil then config.high_gain = (1 - 0.126) / (7.943 - 0.126) end
        if config.high_cut == nil then config.high_cut = (6000 - 4000) / (16000 - 4000) end

        meta.assert(
            config.low_gain, "Number",
            config.low_cut, "Number",
            config.low_mid_gain, "Number",
            config.low_mid_frequency, "Number",
            config.low_mid_bandwidth, "Number",
            config.high_mid_gain, "Number",
            config.high_mid_frequency, "Number",
            config.high_mid_bandwidth, "Number",
            config.high_gain, "Number",
            config.high_cut, "Number"
        )

        local lowgain_native = math.mix(config.low_gain, 0.126, 7.943)
        local lowcut_native = math.mix(config.low_cut, 50, 800)
        local lowmidgain_native = math.mix(config.low_mid_gain, 0.126, 7.943)
        local lowmidfrequency_native = math.mix(config.low_mid_frequency, 200, 3000)
        local lowmidbandwidth_native = math.mix(config.low_mid_bandwidth, 0.01, 1)
        local highmidgain_native = math.mix(config.high_mid_gain, 0.126, 7.943)
        local highmidfrequency_native = math.mix(config.high_mid_frequency, 1000, 8000)
        local highmidbandwidth_native = math.mix(config.high_mid_bandwidth, 0.01, 1)
        local highgain_native = math.mix(config.high_gain, 0.126, 7.943)
        local highcut_native = math.mix(config.high_cut, 4000, 16000)

        local hash = _hash_config(config)
        local native_id = _atlas[hash]
        if native_id == nil then
            native_id = "equalizer_" .. tostring(_current_id)
            if not love.audio.setEffect(native_id, {
                type = rt.SoundEffectType.EQUALIZER,
                volume = _default_volume,
                lowgain = lowgain_native,
                lowcut = lowcut_native,
                lowmidgain = lowmidgain_native,
                lowmidfrequency = lowmidfrequency_native,
                lowmidbandwidth = lowmidbandwidth_native,
                highmidgain = highmidgain_native,
                highmidfrequency = highmidfrequency_native,
                highmidbandwidth = highmidbandwidth_native,
                highgain = highgain_native,
                highcut = highcut_native
            }) then
                rt.critical("In rt.EqualizerSoundEffect: unable to create sound effect `",  hash,  "`")
            end

            _atlas[hash] = native_id
            _current_id = _current_id + 1
        end

        return rt.SoundSourceEffect(native_id)
    end
end

do
    local _atlas = {}
    local _current_id = 0

    --- @class rt.FlangerSoundEffect
    function rt.FlangerSoundEffect(config)
        if config == nil then config = {} end
        meta.assert(config, "Table")

        if config.waveform == nil then config.waveform = rt.SoundEffectWaveform.TRIANGLE end
        if config.phase == nil then config.phase = (0 + 180) / 360 end
        if config.rate == nil then config.rate = 0.27 / 10 end
        if config.depth == nil then config.depth = 1 end
        if config.feedback == nil then config.feedback = (-0.5 + 1) / 2 end
        if config.delay == nil then config.delay = 0.002 / 0.004 end

        meta.assert(
            config.waveform, "String",
            config.phase, "Number",
            config.rate, "Number",
            config.depth, "Number",
            config.feedback, "Number",
            config.delay, "Number"
        )

        local phase_native = math.mix(config.phase, -180, 180)
        local rate_native = math.mix(config.rate, 0, 10)
        local depth_native = config.depth
        local feedback_native = math.mix(config.feedback, -1, 1)
        local delay_native = math.mix(config.delay, 0, 0.004)

        local hash = _hash_config(config)
        local native_id = _atlas[hash]
        if native_id == nil then
            native_id = "flanger_" .. tostring(_current_id)
            if not love.audio.setEffect(native_id, {
                type = rt.SoundEffectType.FLANGER,
                volume = _default_volume,
                waveform = config.waveform,
                phase = phase_native,
                rate = rate_native,
                depth = depth_native,
                feedback = feedback_native,
                delay = delay_native
            }) then
                rt.critical("In rt.FlangerSoundEffect: unable to create sound effect `",  hash,  "`")
            end

            _atlas[hash] = native_id
            _current_id = _current_id + 1
        end

        return rt.SoundSourceEffect(native_id)
    end
end

do
    local _atlas = {}
    local _current_id = 0

    --- @class rt.ReverbSoundEffect
    function rt.ReverbSoundEffect(config)
        if config == nil then config = {} end
        meta.assert(config, "Table")

        if config.gain == nil then config.gain = 0.32 end
        if config.high_gain == nil then config.high_gain = 0.89 end
        if config.density == nil then config.density = 1 end
        if config.diffusion == nil then config.diffusion = 1 end
        if config.decay_time == nil then config.decay_time = (1.49 - 0.1) / (20 - 0.1) end
        if config.decay_high_ratio == nil then config.decay_high_ratio = (0.83 - 0.1) / (2 - 0.1) end
        if config.early_gain == nil then config.early_gain = 0.05 / 3.16 end
        if config.early_delay == nil then config.early_delay = 0.05 / 0.3 end
        if config.late_gain == nil then config.late_gain = 1.26 / 10 end
        if config.late_delay == nil then config.late_delay = 0.011 / 0.1 end
        if config.room_rolloff == nil then config.room_rolloff = 0 / 10 end
        if config.air_absorption == nil then config.air_absorption = (0.994 - 0.892) / (1 - 0.892) end
        if config.high_limit == nil then config.high_limit = true end

        meta.assert(
            config.gain, "Number",
            config.high_gain, "Number",
            config.density, "Number",
            config.diffusion, "Number",
            config.decay_time, "Number",
            config.decay_high_ratio, "Number",
            config.early_gain, "Number",
            config.early_delay, "Number",
            config.late_gain, "Number",
            config.late_delay, "Number",
            config.room_rolloff, "Number",
            config.air_absorption, "Number",
            config.high_limit, "Boolean"
        )

        local gain_native = config.gain
        local highgain_native = config.high_gain
        local density_native = config.density
        local diffusion_native = config.diffusion
        local decaytime_native = math.mix(config.decay_time, 0.1, 20)
        local decayhighratio_native = math.mix(config.decay_high_ratio, 0.1, 2)
        local earlygain_native = math.mix(config.early_gain, 0, 3.16)
        local earlydelay_native = math.mix(config.early_delay, 0, 0.3)
        local lategain_native = math.mix(config.late_gain, 0, 10)
        local latedelay_native = math.mix(config.late_delay, 0, 0.1)
        local roomrolloff_native = math.mix(config.room_rolloff, 0, 10)
        local airabsorption_native = math.mix(config.air_absorption, 0.892, 1)
        local highlimit_native = config.high_limit

        local hash = _hash_config(config)
        local native_id = _atlas[hash]
        if native_id == nil then
            native_id = "reverb_" .. tostring(_current_id)
            if not love.audio.setEffect(native_id, {
                type = rt.SoundEffectType.REVERB,
                volume = _default_volume,
                gain = gain_native,
                highgain = highgain_native,
                density = density_native,
                diffusion = diffusion_native,
                decaytime = decaytime_native,
                decayhighratio = decayhighratio_native,
                earlygain = earlygain_native,
                earlydelay = earlydelay_native,
                lategain = lategain_native,
                latedelay = latedelay_native,
                roomrolloff = roomrolloff_native,
                airabsorption = airabsorption_native,
                highlimit = highlimit_native
            }) then
                rt.critical("In rt.ReverbSoundEffect: unable to create sound effect `",  hash,  "`")
            end

            _atlas[hash] = native_id
            _current_id = _current_id + 1
        end

        return rt.SoundSourceEffect(native_id)
    end
end

do
    local _atlas = {}
    local _current_id = 0

    --- @class rt.RindModulationSoundEffect
    function rt.RingModulationSoundEffect(config)
        if config == nil then config = {} end
        meta.assert(config, "Table")

        if config.waveform == nil then config.waveform = rt.SoundEffectWaveform.SINE end
        if config.frequency == nil then config.frequency = 440 / 8000 end
        if config.highcut == nil then config.highcut = 800 / 24000 end

        meta.assert(
            config.waveform, "String",
            config.frequency, "Number",
            config.highcut, "Number"
        )

        local frequency_native = math.mix(config.frequency, 0, 8000)
        local highcut_native = math.mix(config.highcut, 0, 24000)

        local hash = _hash_config(config)
        local native_id = _atlas[hash]
        if native_id == nil then
            native_id = "ringmodulation_" .. tostring(_current_id)
            if not love.audio.setEffect(native_id, {
                type = rt.SoundEffectType.RING_MODULATION,
                volume = _default_volume,
                waveform = config.waveform,
                frequency = frequency_native,
                highcut = highcut_native
            }) then
                rt.critical("In rt.RingModulationSoundEffect: unable to create sound effect `",  hash,  "`")
            end

            _atlas[hash] = native_id
            _current_id = _current_id + 1
        end

        return rt.SoundSourceEffect(native_id)
    end
end
