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
    triangle = "triangle"
})

--- @class rt.SouncEffect
rt.SoundEffect = meta.class("SoundEffect")

--- @brief
function rt.SoundEffect:instantiate(config)
    meta.assert(config, "Table")

    if config.type == rt.SoundEffect.CHORUS then
    elseif config.type == rt.SoundEffectType.COMPRESSION then
    elseif config.type == rt.SoundEffectType.DISTORTION then
    elseif config.type == rt.SoundEffectType.DELAY then
    elseif config.type == rt.SoundEffectType.EQUALIZER then
    elseif config.type == rt.SoundEffectType.FLANGER then
    elseif config.type == rt.SoundEffectType.REVERB then
    elseif config.type == rt.SoundEffectType.RING_MODULATION then
    else
        rt.error("In rt.SoundEffect.instantiate: unknown effect type `" .. tostring(config.type) .. "`")
    end
end

local _chorus_atlas = meta.make_auto_extend({}, true)
local _chorus_id = 0

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

    local phase_native = math.mix(phase, -180, 180)
    local rate_native = math.mix(rate, 0, 10)
    local depth_native = depth
    local feedback_native = math.mix(feedback, -1, 1)
    local delay_native = math.mix(delay, 0, 0.016)

    local id = _chorus_atlas[phase_native][rate_native][depth_native][feedback_native][delay_native]
    if id == nil then
        id = "chorus_" .. tostring(_chorus_id)
        _chorus_id = _chorus_id + 1
        _chorus_atlas[phase_native][rate_native][depth_native][feedback_native][delay_native] = _chorus_id
    end


end

::skip::