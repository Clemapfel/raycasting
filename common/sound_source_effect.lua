if love.audio.isEffectsSupported() ~= true then goto skip end

--- @class rt.SoundEffectType
rt.SoundEffectType = meta.enum("SoundEffectType", {
    CHORUS = "chorus",
    COMPRESSION = "compressor",
    DISTORTION = "distortion",
    DELAY = "echo",
    EQUALIZER = "equalizer",
    FLANGER = "flanger",
    REVERB = "reverb",
    RING_MODULATION = "ringmodulator"
})

--- @class rt.SoundEffectWaveform
rt.SoundEffectWaveform = meta.enum("SoundEffectWaveform", {
    SINE = "sine",
    SQUARE = "square",
    SAWTOOTH = "sawtooth",
    TRIANGLE = "triangle"
})

--- @class rt.SouncEffect
rt.SoundEffect = meta.class("SoundEffect")

--- @brief
function rt.SoundEffect:instantiate(native_id)
    meta.assert(native_id, "String")
    self._native = native_id
end

local _round_hash_component = function(x) return math.floor(x * 1000)  end
local _hash_separator = "_"
local _default_volume = 1

do
    local _atlas = {}
    local _current_id = 0

    --- @class rt.ChorusSoundEffect
    function rt.ChorusSoundEffect(
        waveform,
        phase,
        rate,
        depth,
        feedback,
        delay
    )
        if waveform == nil then waveform = rt.SoundEffectWaveform.SINE end
        if phase == nil then phase = (90 + 180) / 360 end
        if rate == nil then rate = 1.1 / 10 end
        if depth == nil then depth = 0.1 end
        if feedback == nil then feedback = (0.25 + 1) / 2 end
        if delay == nil then delay = 1 end

        meta.assert(
            waveform, "String",
            phase, "Number",
            rate, "Number",
            depth, "Number",
            feedback, "Number",
            delay, "Number"
        )

        local phase_native = math.mix(phase, -180, 180)
        local rate_native = math.mix(rate, 0, 10)
        local depth_native = depth
        local feedback_native = math.mix(feedback, -1, 1)
        local delay_native = math.mix(delay, 0, 0.016)

        local hash_to_concat = { waveform }
        for x in range(phase, rate, depth, feedback, delay) do
            table.insert(hash_to_concat, _round_hash_component(x))
        end

        local hash = table.concat(hash_to_concat, _hash_separator)
        local native_id = _atlas[hash]
        if native_id == nil then
            native_id = "chorus_" .. tostring(_current_id)
            if not love.audio.setEffect(native_id, {
                type = rt.SoundEffectType.CHORUS,
                volume = _default_volume,
                waveform = waveform,
                phase = phase_native,
                rate = rate_native,
                depth = depth_native,
                feedback = feedback_native,
                delay = delay_native
            }) then
                rt.critical("In rt.ChorusSoundEffect: unable to create sound effect `" .. hash .. "`")
            end

            _atlas[hash] = native_id
            _current_id = _current_id + 1
        end

        return rt.SoundEffect(native_id)
    end
end

do
    local _atlas = {}
    local _current_id = 0

    --- @class rt.CompressionSoundEffect
    function rt.CompressionSoundEffect(
        enable
    )
        if enable == nil then enable = true end
        
        local hash = string.tostring(enable)
        local native_id = _atlas[hash]
        if native_id == nil then
            native_id = "compressor_" .. tostring(_current_id)
            if not love.audio.setEffect(native_id, {
                type = rt.SoundEffectType.COMPRESSION,
                volume = _default_volume,
                enable = enable
            }) then
                rt.critical("In rt.CompressionSoundEffect: unable to create sound effect `" .. hash .. "`")
            end

            _atlas[hash] = native_id
            _current_id = _current_id + 1
        end

        return rt.SoundEffect(native_id)
    end
end

do
    local _atlas = {}
    local _current_id = 0

    --- @class rt.DistortionSoundEffect
    function rt.DistortionSoundEffect(
        gain,
        edge,
        lowcut,
        center,
        bandwidth
    )
        if gain == nil then gain = (0.2 - 0.01) / (1 - 0.01) end
        if edge == nil then edge = 0.2 end
        if lowcut == nil then lowcut = (8000 - 80) / (24000 - 80) end
        if center == nil then center = (3600 - 80) / (24000 - 80) end
        if bandwidth == nil then bandwidth = (3600 - 80) / (24000 - 80) end

        local gain_native = math.mix(gain, 0.01, 1)
        local edge_native = edge
        local lowcut_native = math.mix(lowcut, 80, 24000)
        local center_native = math.mix(center, 80, 24000)
        local bandwidth_native = math.mix(bandwidth, 80, 24000)

        local hash_to_concat = {}
        for x in range(gain, edge, lowcut, center, bandwidth) do
            table.insert(hash_to_concat, _round_hash_component(x))
        end

        local hash = table.concat(hash_to_concat, _hash_separator)
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
                rt.critical("In rt.DistortionSoundEffect: unable to create sound effect `" .. hash .. "`")
            end

            _atlas[hash] = native_id
            _current_id = _current_id + 1
        end

        return rt.SoundEffect(native_id)
    end
end

do
    local _atlas = {}
    local _current_id = 0

    --- @class rt.DelaySoundEffect
    function rt.DelaySoundEffect(
        delay,
        tapdelay,
        damping,
        feedback,
        spread
    )
        if delay == nil then delay = 0.1 / 0.207 end
        if tapdelay == nil then tapdelay = 0.1 / 0.404 end
        if damping == nil then damping = 0.5 / 0.99 end
        if feedback == nil then feedback = 0.5 end
        if spread == nil then spread = (-1 + 1) / 2 end

        local delay_native = math.mix(delay, 0, 0.207)
        local tapdelay_native = math.mix(tapdelay, 0, 0.404)
        local damping_native = math.mix(damping, 0, 0.99)
        local feedback_native = feedback
        local spread_native = math.mix(spread, -1, 1)

        local hash_to_concat = {}
        for x in range(delay, tapdelay, damping, feedback, spread) do
            table.insert(hash_to_concat, _round_hash_component(x))
        end

        local hash = table.concat(hash_to_concat, _hash_separator)
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
                rt.critical("In rt.DelaySoundEffect: unable to create sound effect `" .. hash .. "`")
            end

            _atlas[hash] = native_id
            _current_id = _current_id + 1
        end

        return rt.SoundEffect(native_id)
    end
end

do
    local _atlas = {}
    local _current_id = 0

    --- @class rt.EqualizerSoundEffect
    function rt.EqualizerSoundEffect(
        low_gain,
        low_cut,
        low_mid_gain,
        low_mid_frequency,
        low_mid_bandwidth,
        high_mid_gain,
        high_mid_frequency,
        high_mid_bandwidth,
        high_gain,
        high_cut
    )
        if low_gain == nil then low_gain = (1 - 0.126) / (7.943 - 0.126) end
        if low_cut == nil then low_cut = (200 - 50) / (800 - 50) end
        if low_mid_gain == nil then low_mid_gain = (1 - 0.126) / (7.943 - 0.126) end
        if low_mid_frequency == nil then low_mid_frequency = (500 - 200) / (3000 - 200) end
        if low_mid_bandwidth == nil then low_mid_bandwidth = (1 - 0.01) / (1 - 0.01) end
        if high_mid_gain == nil then high_mid_gain = (1 - 0.126) / (7.943 - 0.126) end
        if high_mid_frequency == nil then high_mid_frequency = (3000 - 1000) / (8000 - 1000) end
        if high_mid_bandwidth == nil then high_mid_bandwidth = (1 - 0.01) / (1 - 0.01) end
        if high_gain == nil then high_gain = (1 - 0.126) / (7.943 - 0.126) end
        if high_cut == nil then high_cut = (6000 - 4000) / (16000 - 4000) end

        local lowgain_native = math.mix(low_gain, 0.126, 7.943)
        local lowcut_native = math.mix(low_cut, 50, 800)
        local lowmidgain_native = math.mix(low_mid_gain, 0.126, 7.943)
        local lowmidfrequency_native = math.mix(low_mid_frequency, 200, 3000)
        local lowmidbandwidth_native = math.mix(low_mid_bandwidth, 0.01, 1)
        local highmidgain_native = math.mix(high_mid_gain, 0.126, 7.943)
        local highmidfrequency_native = math.mix(high_mid_frequency, 1000, 8000)
        local highmidbandwidth_native = math.mix(high_mid_bandwidth, 0.01, 1)
        local highgain_native = math.mix(high_gain, 0.126, 7.943)
        local highcut_native = math.mix(high_cut, 4000, 16000)

        local hash_to_concat = {}
        for x in range(
            low_gain, low_cut, 
            low_mid_gain, low_mid_frequency, low_mid_bandwidth, 
            high_mid_gain, high_mid_frequency, high_mid_bandwidth, 
            high_gain, high_cut
        ) do
            table.insert(hash_to_concat, _round_hash_component(x))
        end

        local hash = table.concat(hash_to_concat, _hash_separator)
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
                rt.critical("In rt.EqualizerSoundEffect: unable to create sound effect `" .. hash .. "`")
            end

            _atlas[hash] = native_id
            _current_id = _current_id + 1
        end

        return rt.SoundEffect(native_id)
    end
end

do
    local _atlas = {}
    local _current_id = 0

    --- @class rt.FlangerSoundEffect
    function rt.FlangerSoundEffect(
        waveform,
        phase,
        rate,
        depth,
        feedback,
        delay
    )
        if waveform == nil then waveform = rt.SoundEffectWaveform.TRIANGLE end
        if phase == nil then phase = (0 + 180) / 360 end
        if rate == nil then rate = 0.27 / 10 end
        if depth == nil then depth = 1 end
        if feedback == nil then feedback = (-0.5 + 1) / 2 end
        if delay == nil then delay = 0.002 / 0.004 end

        local phase_native = math.mix(phase, -180, 180)
        local rate_native = math.mix(rate, 0, 10)
        local depth_native = depth
        local feedback_native = math.mix(feedback, -1, 1)
        local delay_native = math.mix(delay, 0, 0.004)

        local hash_to_concat = { waveform }
        for x in range(phase, rate, depth, feedback, delay) do
            table.insert(hash_to_concat, _round_hash_component(x))
        end

        local hash = table.concat(hash_to_concat, _hash_separator)
        local native_id = _atlas[hash]
        if native_id == nil then
            native_id = "flanger_" .. tostring(_current_id)
            if not love.audio.setEffect(native_id, {
                type = rt.SoundEffectType.FLANGER,
                volume = _default_volume,
                waveform = waveform,
                phase = phase_native,
                rate = rate_native,
                depth = depth_native,
                feedback = feedback_native,
                delay = delay_native
            }) then
                rt.critical("In rt.FlangerSoundEffect: unable to create sound effect `" .. hash .. "`")
            end

            _atlas[hash] = native_id
            _current_id = _current_id + 1
        end

        return rt.SoundEffect(native_id)
    end
end

do
    local _atlas = {}
    local _current_id = 0

    --- @class rt.ReverbSoundEffect
    function rt.ReverbSoundEffect(
        gain,
        high_gain,
        density,
        diffusion,
        decay_time,
        decay_high_ratio,
        early_gain,
        early_delay,
        late_gain,
        late_delay,
        room_rolloff,
        air_absorption,
        high_limit
    )
        if gain == nil then gain = 0.32 end
        if high_gain == nil then high_gain = 0.89 end
        if density == nil then density = 1 end
        if diffusion == nil then diffusion = 1 end
        if decay_time == nil then decay_time = (1.49 - 0.1) / (20 - 0.1) end
        if decay_high_ratio == nil then decay_high_ratio = (0.83 - 0.1) / (2 - 0.1) end
        if early_gain == nil then early_gain = 0.05 / 3.16 end
        if early_delay == nil then early_delay = 0.05 / 0.3 end
        if late_gain == nil then late_gain = 1.26 / 10 end
        if late_delay == nil then late_delay = 0.011 / 0.1 end
        if room_rolloff == nil then room_rolloff = 0 / 10 end
        if air_absorption == nil then air_absorption = (0.994 - 0.892) / (1 - 0.892) end
        if high_limit == nil then high_limit = 1 end

        local gain_native = gain
        local highgain_native = high_gain
        local density_native = density
        local diffusion_native = diffusion
        local decaytime_native = math.mix(decay_time, 0.1, 20)
        local decayhighratio_native = math.mix(decay_high_ratio, 0.1, 2)
        local earlygain_native = math.mix(early_gain, 0, 3.16)
        local earlydelay_native = math.mix(early_delay, 0, 0.3)
        local lategain_native = math.mix(late_gain, 0, 10)
        local latedelay_native = math.mix(late_delay, 0, 0.1)
        local roomrolloff_native = math.mix(room_rolloff, 0, 10)
        local airabsorption_native = math.mix(air_absorption, 0.892, 1)
        local highlimit_native = high_limit > 0.5

        local hash_to_concat = {}
        for x in range(
            gain, high_gain,
            density,
            diffusion,
            decay_time, decay_high_ratio,
            early_gain, early_delay,
            late_gain, late_delay,
            room_rolloff,
            air_absorption,
            high_limit
        ) do
            table.insert(hash_to_concat, _round_hash_component(x))
        end

        local hash = table.concat(hash_to_concat, _hash_separator)
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
                rt.critical("In rt.ReverbSoundEffect: unable to create sound effect `" .. hash .. "`")
            end

            _atlas[hash] = native_id
            _current_id = _current_id + 1
        end

        return rt.SoundEffect(native_id)
    end
end

do
    local _atlas = {}
    local _current_id = 0

    --- @class rt.RindModulationSoundEffect
    function rt.RingModulationSoundEffect(
        waveform,
        frequency,
        highcut
    )
        if waveform == nil then waveform = rt.SoundEffectWaveform.SINE end
        if frequency == nil then frequency = 440 / 8000 end
        if highcut == nil then highcut = 800 / 24000 end

        local frequency_native = math.mix(frequency, 0, 8000)
        local highcut_native = math.mix(highcut, 0, 24000)

        local hash_to_concat = { waveform, }
        for x in range(frequency, highcut) do
            table.insert(hash_to_concat, _round_hash_component(x))
        end

        local hash = table.concat(hash_to_concat, _hash_separator)
        local native_id = _atlas[hash]
        if native_id == nil then
            native_id = "ringmodulator_" .. tostring(_current_id)
            if not love.audio.setEffect(native_id, {
                type = rt.SoundEffectType.RING_MODULATION,
                volume = _default_volume,
                waveform = waveform,
                frequency = frequency_native,
                highcut = highcut_native
            }) then
                rt.critical("In rt.RingModulationSoundEffect: unable to create sound effect `" .. hash .. "`")
            end

            _atlas[hash] = native_id
            _current_id = _current_id + 1
        end

        return rt.SoundEffect(native_id)
    end
end

::skip::