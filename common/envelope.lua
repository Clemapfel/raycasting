require "common.envelope_curve"

--- @class rt.Envelope
rt.Envelope = meta.class("Envelope")

--- @brief
--- @param attack Number seconds
--- @param sustain Number seconds, or, inf for gated asr envelope
--- @param release Number seconds
--- @param attack_shape rt.EnvelopeCurve attack phase curve
--- @param release_shape rt.EnvelopeCurve release phase curve
function rt.Envelope:instantiate(attack, sustain, release, attack_shape, release_shape)
    if attack == nil then attack = 0.05 end
    if sustain == nil then sustain = 1.0 end
    if release == nil then release = 1.0 end
    if attack_shape == nil then attack_shape = rt.EnvelopeCurve.LINEAR end
    if release_shape == nil then release_shape = rt.EnvelopeCurve.LINEAR end

    meta.assert(
        attack, mt.Number,
        sustain, mt.Number,
        release, mt.Number,
        attack_shape, rt.EnvelopeCurve,
        release_shape, rt.EnvelopeCurve
    )

    self._attack = attack
    self._release = release
    self._sustain = sustain

    for i, which in ipairs({
        { self._attack, "attack" },
        { self._sustain, "sustain" },
        { self._release, "release" }
    }) do
        local value, name = table.unpack(which)
        rt.assert(value >= 0, "In rt.Envelope.instantiate: argument #", i, ": `", name, "` cannot be negative")
    end

    self._attack_shape = attack_shape
    self._release_shape = release_shape

    self._elapsed = 0

    self._current_value_needs_update = true
    self._current_value = 0
end

local _exp = function(x)
    -- cf. rt.InterpolationFunctions.EXPONENTIAL_ACCELERATION
    return 0.045 * math.exp(math.log(1 / 0.045 + 1) * (-1 * x + 1)) - 0.045
end

local _shape = function(t, attack, sustain, release, attack_shape, release_shape)
    if t <= 0 then
        return 0
    elseif t <= attack then
        -- attack phase
        local phase = math.min(t / attack, 1)
        if attack_shape == rt.EnvelopeCurve.LINEAR then
            return phase
        elseif attack_shape == rt.EnvelopeCurve.SIN then
            return 0.5 - 0.5 * math.cos(math.pi * phase)
        elseif attack_shape == rt.EnvelopeCurve.WELCH then
            return math.sin(0.5 * math.pi * phase)
        elseif attack_shape == rt.EnvelopeCurve.STEP then
            if phase <= 0.5 then return 0 else return 1 end
        elseif attack_shape == rt.EnvelopeCurve.EXPONENTIAL then
            return _exp(t)
        else
            return phase
        end
    elseif t <= (attack + sustain) then
        -- sustain phase
        return 1
    elseif t <= (attack + sustain + release) then
        -- release phase
        local phase = math.min((t - attack - sustain) / release, 1)
        if release_shape == rt.EnvelopeCurve.LINEAR then
            return 1 - phase
        elseif release_shape == rt.EnvelopeCurve.SIN then
            return 0.5 + 0.5 * math.cos(math.pi * phase)
        elseif release_shape == rt.EnvelopeCurve.WELCH then
            return math.cos(0.5 * math.pi * phase)
        elseif release_shape == rt.EnvelopeCurve.STEP then
            if phase <= 0.5 then return 1 else return 0 end
        elseif release_shape == rt.EnvelopeCurve.EXPONENTIAL then
            return _exp(1 - t)
        else
            return 1 - phase
        end
    else
        return 0
    end
end

--- @brief
function rt.Envelope:gate()
    self._elapsed = 0
    self._current_value_needs_update = true
end

--- @brief
function rt.Envelope:release()
    self._elapsed = self._attack + self._sustain
    self._current_value_needs_update = true
end

--- @brief
function rt.Envelope:update(delta)
    self._elapsed = self._elapsed + delta
    self._current_value_needs_update = true
end

--- @brief
function rt.Envelope:get_value()
    if self._current_value_needs_update then
        self._current_value = _shape(
            self._elapsed,
            self._attack,
            self._sustain,
            self._release,
            self._attack_shape,
            self._release_shape
        )

        self._current_value_needs_update = false
    end

    return self._current_value
end

--- @brief
function rt.Envelope:at(t)
    meta.assert(t, mt.Number)
    return _shape(
        t,
        self._attack,
        self._sustain,
        self._release,
        self._attack_shape,
        self._release_shape
    )
end

--- @brief
function rt.Envelope:get_attack()
    return self._attack
end

--- @brief
function rt.Envelope:get_sustain()
    return self._sustain
end

--- @brief
function rt.Envelope:get_release()
    return self._release
end

--- @brief
function rt.Envelope:get_elapsed()
    return self._elapsed
end

--- @brief
function rt.Envelope:set_elapsed(elapsed)
    self._elapsed = elapsed
end

--- @brief
function rt.Envelope:get_duration()
    return self._attack + self._sustain + self._release
end

--- @brief
function rt.Envelope:get_is_done()
    return self._elapsed > (self._attack + self._sustain + self._release)
end