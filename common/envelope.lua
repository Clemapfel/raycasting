--- @class rt.Envelope
rt.Envelope = meta.class("Envelope")

--- @enum rt.EnvelopeCurve
rt.EnvelopeCurve = {
    LINEAR = "LINEAR",
    SIN = "SIN",
    WELCH = "WELCH",
    STEP = "STEP"
}

--- @alias rt.EnvelopeCurve
rt.EnvelopeCurve = meta.enum("EnvelopeCurve", rt.EnvelopeCurve)

--- @brief
--- @param attack Number seconds
--- @param release Number seconds
--- @param sustain Number seconds, or, inf for gated asr envelope
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

    self.attack = attack
    self.release = release
    self.sustain = sustain

    for i, which in ipairs({
        { self.attack, "attack" },
        { self.sustain, "sustain" },
        { self.release, "release" }
    }) do
        local value, name = table.unpack(which)
        rt.assert(value >= 0, "In rt.Envelope.instantiate: argument #", i, ": `", name, "` cannot be negative")
    end

    self.attack_shape = attack_shape
    self.release_shape = release_shape

    self.elapsed = 0

    self.current_value_needs_update = true
    self.current_value = 0
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
        else
            return 1 - phase
        end
    else
        return 0
    end
end

--- @brief
function rt.Envelope:gate()
    self.elapsed = 0
    self.current_value_needs_update = true
end

--- @brief
function rt.Envelope:update(delta)
    self.elapsed = self.elapsed + delta
    self.current_value_needs_update = true
end

--- @brief
function rt.Envelope:get_value()
    if self.current_value_needs_update then
        self.current_value = _shape(
            self.elapsed,
            self.attack,
            self.sustain,
            self.release,
            self.attack_shape,
            self.release_shape
        )

        self.current_value_needs_update = false
    end

    return self.current_value
end

--- @brief
function rt.Envelope:at(t)
    meta.assert(t, mt.Number)
    return _shape(
        t,
        self.attack,
        self.sustain,
        self.release,
        self.attack_shape,
        self.release_shape
    )
end

--- @brief
function rt.Envelope:get_attack()
    return self.attack
end

--- @brief
function rt.Envelope:get_sustain()
    return self.sustain
end

--- @brief
function rt.Envelope:get_release()
    return self.release
end

--- @brief
function rt.Envelope:get_elapsed()
    return self.elapsed
end

--- @brief
function rt.Envelope:set_elapsed(elapsed)
    self.elapsed = elapsed
end

--- @brief
function rt.Envelope:get_duration()
    return self.attack + self.sustain + self.release
end

--- @brief
function rt.Envelope:get_is_done()
    return self.elapsed > (self.attack + self.sustain + self.release)
end