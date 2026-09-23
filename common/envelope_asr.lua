require "common.envelope_curve"

--- @class rt.EnvelopeASR
rt.EnvelopeASR = meta.class("EnvelopeASR")

local STATE_ATTACK = 0
local STATE_SUSTAIN = 1
local STATE_RELEASE = 2

--- @brief
--- @param attack Number seconds
--- @param release Number seconds
--- @param attack_shape rt.EnvelopeCurve attack phase curve
--- @param release_shape rt.EnvelopeCurve release phase curve
function rt.EnvelopeASR:instantiate(attack, release, attack_shape, release_shape)
    if attack == nil then attack = 0.05 end
    if release == nil then release = 1.0 end
    if attack_shape == nil then attack_shape = rt.EnvelopeCurve.LINEAR end
    if release_shape == nil then release_shape = rt.EnvelopeCurve.LINEAR end

    meta.assert(
        attack, mt.Number,
        release, mt.Number,
        attack_shape, rt.EnvelopeCurve,
        release_shape, rt.EnvelopeCurve
    )

    self._attack = attack
    self._release = release

    self._state = STATE_ATTACK
    self._state_elapsed = 0
    self._state_release_value = 0

    rt.assert(self._attack >= 0,
        "In rt.EnvelopeASR.instantiate: argument #", 1, ": `", "attack", "` cannot be negative"
    )

    rt.assert(self._release >= 0,
        "In rt.EnvelopeASR.instantiate: argument #", 2, ": `", "release", "` cannot be negative"
    )

    self._attack_shape = attack_shape
    self._release_shape = release_shape

    self._current_value_needs_update = true
    self._current_value = 0
end

local _asr_shape = function(state, t, attack, release, release_value, attack_shape, release_shape)
    if state == STATE_SUSTAIN then
        return 1
    elseif state == STATE_ATTACK then
        if t <= 0 then
            return 0
        elseif t >= attack then
            return 1
        else
            -- attack phase, ignore release value
            local phase = math.min(t / attack, 1)
            if attack_shape == rt.EnvelopeCurve.LINEAR then
                return phase
            elseif attack_shape == rt.EnvelopeCurve.SIN then
                return 0.5 - 0.5 * math.cos(math.pi * phase)
            elseif attack_shape == rt.EnvelopeCurve.WELCH then
                return math.sin(0.5 * math.pi * phase)
            elseif attack_shape == rt.EnvelopeCurve.STEP then
                if phase <= 0.5 then return 0 else return 1 end
            else
                return phase
            end
        end
    elseif state == STATE_RELEASE then
        -- release phase, release from release value
        local phase = math.min(t / release, 1)
        local v
        if release_shape == rt.EnvelopeCurve.LINEAR then
            v = 1 - phase
        elseif release_shape == rt.EnvelopeCurve.SIN then
            v = 0.5 + 0.5 * math.cos(math.pi * phase)
        elseif release_shape == rt.EnvelopeCurve.WELCH then
            v =  math.cos(0.5 * math.pi * phase)
        elseif release_shape == rt.EnvelopeCurve.STEP then
            if phase <= 0.5 then
                v = 1
            else
                v = 0
            end
        else
            v = 1 - phase
        end

        return v * release_value
    else
        rt.error("In rt.EnvelopeASR._shape: unhandled state `", state, "`")
    end
end

--- @brief reset envelope
function rt.EnvelopeASR:gate()
    self._state_elapsed = 0
    self._state = STATE_ATTACK
    self._current_value_needs_update = true
end

--- @brief
function rt.EnvelopeASR:release()
    if self._state == STATE_RELEASE then
        return -- already releasing
    end

    -- update value, it will release from this position even in attack
    self._current_value_needs_update = true
    self._state_release_value = self:get_value()

    self._state_elapsed = 0
    self._state = STATE_RELEASE
end

--- @brief
function rt.EnvelopeASR:update(delta)
    self._state_elapsed = self._state_elapsed + delta

    if self._state == STATE_ATTACK and self._state_elapsed > self._attack then
        self._state = STATE_SUSTAIN
        self._state_release_value = 1
        self._state_elapsed = 0
    end

    self._current_value_needs_update = true
end

--- @brief
function rt.EnvelopeASR:get_value()
    if self._current_value_needs_update then
        self._current_value = _asr_shape(
            self._state,
            self._state_elapsed,
            self._attack,
            self._release,
            self._state_release_value,
            self._attack_shape,
            self._release_shape
        )

        self._current_value_needs_update = false
    end

    return self._current_value
end

--- @brief
function rt.EnvelopeASR:get_attack()
    return self._attack
end

--- @brief
function rt.EnvelopeASR:get_release()
    return self._release
end

--- @brief
function rt.EnvelopeASR:get_is_done()
    return self._state == STATE_RELEASE and self._state_elapsed >= self._release
end