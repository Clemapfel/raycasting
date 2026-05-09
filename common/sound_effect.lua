--- @enum rt.SoundEffectType
rt.SoundEffectType = meta.enum("SoundEffectType", {
    CHORUS = "chorus",
    COMPRESSION = "compressor",
    DISTORTION = "distortion",
    DELAY = "echo",
    EQUALIZER = "equalizer",
    FLANGER = "flanger",
    REVERB = "reverb",
    RING_MODULATOR = "ringmodulator",
    FILTER = "filter"
})

--- @enum rt.SoundEffectWaveform
rt.SoundEffectWaveform = meta.enum("SoundEffectWaveform", {
    SINE = "sine",
    SQUARE = "square",
    SAWTOOTH = "sawtooth",
    TRIANGLE = "triangle"
})

--- @class rt.SoundEffect
--- @see https://nrgcore.com/docs/manual/en-us/effects_extension_guide.pdf
rt.SoundEffect = meta.class("SoundEffect")

--- @brief
function rt.SoundEffect:instantiate(native_id)
    meta.assert(native_id, "String")
    self._native = native_id
end

--- @brief
function rt.SoundEffect:get_native()
    return self._native
end

-- hash arbitrary config
local _hash_config = function(config)
    local buffer = require "string.buffer"
    if buffer == nil then
        local to_concat = {}
        for key, value in pairs(config) do
            local as_string
            if meta.is_number(value) then
                as_string = tostring(math.floor(value * 1000))
            elseif meta.is_boolean(value) then
                as_string = ternary(value, "true", "false")
            else
                as_string = tostring(value)
            end

            rt.assert(as_string ~= nil)
            table.insert(to_concat, key)
            table.insert(to_concat, as_string)
        end

        return table.concat(to_concat, "_")
    else
        local hash = string.sha256(buffer.encode(config))
        return hash
    end
end

local INTERVAL = function(min, max)
    return { "INTERVAL", min = min, max = max }
end
local INTERVAL_ZERO_ONE = INTERVAL(0, 1)
local INTERVAL_MINUS_ONE_ONE = INTERVAL(-1, 1)
local _validate_config = function(scope, config, spec)
    config = table.deepcopy(config)

    -- check for invalid keys
    for key in keys(config) do
        if spec[key] == nil then
            rt.error("In ", scope, ": invalid key `", key, "`")
            config[key] = nil
        end
    end

    return config
    --[[

    -- valid argument range
    for key, type in pairs(spec) do
        local config_value = config[key]
        if meta.is_table(type) and type[1] == "INTERVAL" then
            if config_value < 0 or config_value > 1 then
                rt.error("In ", scope, ": for config value `", key, "`: expected number in [", INTERVAL.min, ", ", INTERVAL.max, "], got `", config_value, "`")
            end
        elseif meta.typeof(type) == "Enum" then
            if not meta.is_enum_value(config_value, type) then
                rt.error("In ", scope, ": for config value `", key, "`: expected value of enum `", meta.get_enum_name(type), "`, got `", config_value, "`")
            end
        end
    end

    return config
    ]]
end

local _to_t = function(value, min, max)
    return (value - min) / (max - min)
end

local _new_effect
do
    local _current_id = 0
    local _atlas = {}
    _new_effect = function(prefix, config)
        meta.assert(prefix, "String", config, "Table")
        if config.volume == nil then config.volume = 1 end
        local hash = _hash_config(config)
        local native_id = _atlas[hash]
        if native_id == nil then
            native_id = prefix .. tostring(_current_id)
            if not love.audio.setEffect(native_id, config) then
                rt.critical("In rt.SoundEffect: unable to create sound effect `", hash, "`")
            end

            _atlas[hash] = native_id
            _current_id = _current_id + 1
        end

        return rt.SoundEffect(native_id)
    end
end

do
    local _spec = {
        volume = INTERVAL_ZERO_ONE,
        waveform = rt.SoundEffectWaveform,
        lfo_phase_difference = INTERVAL_ZERO_ONE,
        lfo_rate = INTERVAL_ZERO_ONE,
        lfo_magnitude = INTERVAL_ZERO_ONE,
        feedback = INTERVAL_MINUS_ONE_ONE,
        delay = INTERVAL_ZERO_ONE
    }

    --- @class rt.ChorusSoundEffect
    function rt.ChorusSoundEffect(config)
        if config == nil then config = {} end
        meta.assert(config, "Table")
        config = _validate_config("rt.ChorusSoundEffect", config, _spec)

        if config.lfo_phase_difference ~= nil then
            config.lfo_phase_difference = math.mix(-180, 180, config.lfo_phase_difference)
        end

        if config.lfo_rate ~= nil then
            config.lfo_rate = math.mix(0, 10, config.lfo_rate)
        end

        if config.lfo_magnitude ~= nil then
            config.lfo_magnitude = math.mix(0, 1, config.lfo_magnitude)
        end

        -- feedback already in [-1, 1]

        if config.delay ~= nil then
            config.delay = math.mix(0, 0.016, config.delay)
        end

        return _new_effect("chorus", {
            type     = rt.SoundEffectType.CHORUS,
            volume   = config.volume,
            waveform = config.waveform,
            phase    = config.lfo_phase_difference,
            rate     = config.lfo_rate,
            depth    = config.lfo_magnitude,
            feedback = config.feedback,
            delay    = config.delay
        })
    end
end

do
    local _spec = {
        volume = INTERVAL_ZERO_ONE,
        fuzziness = INTERVAL_ZERO_ONE,
        gain = INTERVAL_ZERO_ONE,
        lowpass_cutoff = INTERVAL_ZERO_ONE,
        gain_center_frequency = INTERVAL_ZERO_ONE,
        attenuation_bandwidth = INTERVAL_ZERO_ONE,
    }

    --- @class rt.DistortionSoundEffect
    function rt.DistortionSoundEffect(config)
        if config == nil then config = {} end
        meta.assert(config, "Table")
        config = _validate_config("rt.DistortionSoundEffect", config, _spec)

        if config.fuzziness ~= nil then
            config.fuzziness = math.mix(0, 1, config.fuzziness)
        end

        if config.gain ~= nil then
            config.gain = math.mix(0.01, 1, config.gain)
        end

        if config.lowpass_cutoff ~= nil then
            config.lowpass_cutoff = math.mix(80, 24000, config.lowpass_cutoff)
        end

        if config.gain_center_frequency ~= nil then
            config.gain_center_frequency = math.mix(80, 24000, config.gain_center_frequency)
        end

        if config.attenuation_bandwidth ~= nil then
            config.attenuation_bandwidth = math.mix(80, 24000, config.attenuation_bandwidth)
        end

        return _new_effect("distortion", {
            type      = rt.SoundEffectType.DISTORTION,
            volume    = config.volume,
            edge      = config.fuzziness,
            gain      = config.gain,
            lowcut    = config.lowpass_cutoff,
            center    = config.gain_center_frequency,
            bandwidth = config.attenuation_bandwidth
        })
    end
end

do
    local _spec = {
        volume = INTERVAL_ZERO_ONE,
        delay = INTERVAL_ZERO_ONE,
        tap_delay = INTERVAL_ZERO_ONE,
        damping = INTERVAL_ZERO_ONE,
        feedback = INTERVAL_ZERO_ONE,
        panning = INTERVAL_MINUS_ONE_ONE, -- 0: full left, 1: full right
    }

    --- @class rt.DelaySoundEffect
    function rt.DelaySoundEffect(config)
        if config == nil then config = {} end
        meta.assert(config, "Table")
        config = _validate_config("rt.DelaySoundEffect", config, _spec)

        if config.delay ~= nil then
            config.delay = math.mix(0, 0.207, config.delay)
        end

        if config.tap_delay ~= nil then
            config.tap_delay = math.mix(0, 0.404, config.tap_delay)
        end

        if config.damping ~= nil then
            config.damping = math.mix(0, 0.99, config.damping)
        end

        if config.feedback ~= nil then
            config.feedback = math.mix(0, 1, config.feedback)
        end

        -- panning already in [-1, 1]

        return _new_effect("echo", {
            type     = rt.SoundEffectType.DELAY,
            volume   = config.volume,
            delay    = config.echo_interval,
            tapdelay = config.tap_delay,
            damping  = config.damping,
            feedback = config.feedback,
            spread   = config.panning
        })
    end
end

do
    local _spec = {
        volume = INTERVAL_ZERO_ONE,
        waveform = rt.SoundEffectWaveform,
        lfo_phase_difference = INTERVAL_ZERO_ONE,
        lfo_rate = INTERVAL_ZERO_ONE,
        lfo_magnitude = INTERVAL_ZERO_ONE,
        feedback = INTERVAL_MINUS_ONE_ONE,
        delay = INTERVAL_ZERO_ONE
    }

    --- @class rt.FlangerSoundEffect
    function rt.FlangerSoundEffect(config)
        if config == nil then config = {} end
        meta.assert(config, "Table")
        config = _validate_config("rt.FlangerSoundEffect", config, _spec)

        if config.lfo_phase_difference ~= nil then
            config.lfo_phase_difference = math.mix(-180, 180, config.lfo_phase_difference)
        end

        if config.lfo_rate ~= nil then
            config.lfo_rate = math.mix(0, 10, config.lfo_rate)
        end

        if config.lfo_magnitude ~= nil then
            config.lfo_magnitude = math.mix(0, 1, config.lfo_magnitude)
        end

        -- feedback already in [-1, 1]

        if config.delay ~= nil then
            config.delay = math.mix(0, 0.016, config.delay)
        end

        return _new_effect("flanger", {
            type     = rt.SoundEffectType.FLANGER,
            volume   = config.volume,
            waveform = config.waveform,
            phase    = config.lfo_phase_difference,
            rate     = config.lfo_rate,
            depth    = config.lfo_magnitude,
            feedback = config.feedback,
            delay    = config.delay
        })
    end
end

do
    local _spec = {
        volume = INTERVAL_ZERO_ONE,
        frequency = INTERVAL(0, 8000), -- Hz
        waveform = rt.SoundEffectWaveform,
        highpass_cutoff = INTERVAL_ZERO_ONE,
    }

    --- @class rt.RingModulatorSoundEffect
    function rt.RingModulatorSoundEffect(config)
        if config == nil then config = {} end
        meta.assert(config, "Table")
        config = _validate_config("rt.RingModulatorSoundEffect", config, _spec)

        -- frequency already in Hz

        if config.highpass_cutoff ~= nil then
            config.highpass_cutoff = math.mix(0, 24000, config.highpass_cutoff)
        end

        return _new_effect("ring_modulator", {
            type      = rt.SoundEffectType.RING_MODULATOR,
            volume    = config.volume,
            waveform  = config.waveform,
            frequency = config.frequency,
            highcut   = config.highpass_cutoff
        })
    end
end

do
    local _spec = {
        volume = INTERVAL_ZERO_ONE
    }

    --- @class rt.CompressionSoundEffect
    function rt.CompressionSoundEffect(config)
        if config == nil then config = {} end
        meta.assert(config, "Table")
        config = _validate_config("rt.CompressionSoundEffect", config, _spec)

        return _new_effect("compressor", {
            type      = rt.SoundEffectType.COMPRESSION,
            volume    = config.volume,
        })
    end
end

do
    local low_cutoff_min, low_cutoff_max = 50, 800
    local low_mid_min, low_mid_max = 200, 3000
    local high_mid_min, high_mid_max = 1000, 8000
    local high_cutoff_min, high_cutoff_max = 4000, 16000

    local _spec = {
        volume = INTERVAL_ZERO_ONE,

        low_gain = INTERVAL_ZERO_ONE,
        low_cutoff = INTERVAL(low_cutoff_min, low_cutoff_max),

        low_mid_gain = INTERVAL_ZERO_ONE,
        low_mid_frequency = INTERVAL(low_mid_min, low_mid_max),
        low_mid_bandwidth = INTERVAL_ZERO_ONE,

        high_mid_gain = INTERVAL_ZERO_ONE,
        high_mid_frequency = INTERVAL(high_mid_min, high_mid_max),
        high_mid_bandwidth = INTERVAL_ZERO_ONE,

        high_gain = INTERVAL_ZERO_ONE,
        high_cutoff = INTERVAL(high_cutoff_min, high_cutoff_max)
    }

    --- @class rt.EqualizerSoundEffect
    function rt.EqualizerSoundEffect(config)
        if config == nil then config = {} end
        meta.assert(config, "Table")
        config = _validate_config("rt.EqualizerSoundEffect", config, _spec)

        if config.low_gain ~= nil then
            config.low_gain = math.mix(0.126, 7.943, config.low_gain)
        end

        if config.low_cutoff ~= nil then
            local t = _to_t(config.low_cutoff, low_cutoff_min, low_cutoff_max)
            config.low_cutoff = math.mix(50, 800, t)
        end

        if config.low_mid_gain ~= nil then
            config.low_mid_gain = math.mix(0.126, 7.943, config.low_mid_gain)
        end

        if config.low_mid_bandwidth ~= nil then
            config.low_mid_bandwidth = math.mix(0.01, 1.0, config.low_mid_bandwidth)
        end

        if config.low_mid_frequency ~= nil then
            local t = _to_t(config.low_mid_frequency, low_mid_min, low_mid_max)
            config.low_mid_frequency = math.mix(200, 3000, t)
        end

        if config.high_mid_gain ~= nil then
            config.high_mid_gain = math.mix(0.126, 7.943, config.high_mid_gain)
        end

        if config.high_mid_bandwidth ~= nil then
            config.high_mid_bandwidth = math.mix(0.01, 1.0, config.high_mid_bandwidth)
        end

        if config.high_mid_frequency ~= nil then
            local t = _to_t(config.high_mid_frequency, high_mid_min, high_mid_max)
            config.high_mid_frequency = math.mix(1000, 8000, t)
        end

        if config.high_cutoff ~= nil then
            local t = _to_t(config.high_cutoff, high_cutoff_min, high_cutoff_max)
            config.high_cutoff = math.mix(4000, 16000, t)
        end

        return _new_effect("equalizer", {
            type              = rt.SoundEffectType.EQUALIZER,
            volume            = config.volume,
            lowgain           = config.low_gain,
            lowcut            = config.low_cutoff,
            lowmidgain        = config.low_mid_gain,
            lowmidfrequency   = config.low_mid_frequency,
            lowmidbandwidth   = config.low_mid_bandwidth,
            highmidgain       = config.high_mid_gain,
            highmidfrequency  = config.high_mid_frequency,
            highmidbandwidth  = config.high_mid_bandwidth,
            highgain          = config.high_gain,
            highcut           = config.high_cutoff
        })
    end
end

do
    local min_seconds, max_seconds = 0, 20
    local _spec = {
        volume = INTERVAL_ZERO_ONE,
        coloration = INTERVAL_ZERO_ONE,
        diffusion = INTERVAL_ZERO_ONE,
        gain = INTERVAL_ZERO_ONE,
        low_gain = INTERVAL_ZERO_ONE,
        high_gain = INTERVAL_ZERO_ONE,

        decay_time = INTERVAL(min_seconds, max_seconds), -- seconds
        decay_high_ratio = INTERVAL_ZERO_ONE,

        early_gain = INTERVAL_ZERO_ONE,
        early_delay = INTERVAL_ZERO_ONE,
        late_gain = INTERVAL_ZERO_ONE,
        late_delay = INTERVAL_ZERO_ONE,

        air_absorption = INTERVAL_ZERO_ONE,
        -- room rolloff omitted
        -- highlimit omitted
    }

    --- @class rt.ReverbSoundEffect
    function rt.ReverbSoundEffect(config)
        if config == nil then config = {} end
        meta.assert(config, "Table")
        config = _validate_config("rt.ReverbSoundEffect", config, _spec)

        -- coloration already in [0, 1]
        -- diffusion already in [0, 1]
        -- gain already in [0, 1]
        -- low_gain already in [0, 1]
        -- high_gain already in [0, 1]

        if config.decay_time ~= nil then
            local t = _to_t(config.decay_time, min_seconds, max_seconds)
            config.decay_time = math.mix(0.1, 20, t)
        end

        if config.decay_high_ratio ~= nil then
            config.decay_high_ratio = math.mix(0.1, 2, config.decay_high_ratio)
        end

        if config.early_gain ~= nil then
            config.early_gain = math.mix(0, 3.16, config.early_gain)
        end

        if config.early_delay ~= nil then
            config.early_delay = math.mix(0, 0.3, config.early_delay)
        end

        if config.late_gain ~= nil then
            config.late_gain = math.mix(0, 10, config.late_gain)
        end

        if config.late_delay ~= nil then
            config.late_delay = math.mix(0, 0.1, config.late_delay)
        end

        if config.air_absorption ~= nil then
            config.air_absorption = math.mix(0.892, 1, config.air_absorption)
        end

        return _new_effect("reverb", {
            type = rt.SoundEffectType.REVERB,
            volume = config.volume,
            density = config.coloration,
            diffusion = config.diffusion,
            lowgain = config.low_gain,
            gain = config.gain,
            highgain = config.high_gain,
            decaytime = config.decay_time,
            decayhighratio = config.decay_high_ratio,
            earlygain = config.early_gain,
            earlydelay = config.early_delay,
            lategain = config.late_gain,
            latedelay = config.late_delay,
            airabsorption = config.air_absorption,
            -- roomrolloff = config.room_rolloff,
            -- highlimit = config.apply_high_limit
        })
    end
end




