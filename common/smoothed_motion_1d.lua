--- @class rt.SmoothedMotion1D
rt.SmoothedMotion1D = meta.class("SmoothedMotion1D")

--- @brief
function rt.SmoothedMotion1D:instantiate(value, speed, ramp)
    if ramp == nil then ramp = 6 end
    if speed == nil then speed = 1 end
    meta.assert(value, "Number", speed, "Number")
    meta.install(self, {
        _attack_speed = speed,
        _decay_speed = speed,
        _ramp = ramp,
        _current_value = value,
        _target_value = value,
        _elapsed = 0
    })
end

--- @brief
function rt.SmoothedMotion1D:get_value()
    return self._current_value
end

--- @brief
function rt.SmoothedMotion1D:get_target_value()
    return self._target_value
end

--- @brief
function rt.SmoothedMotion1D:set_target_value(x)
    self._target_value = x
end

--- @brief
function rt.SmoothedMotion1D:set_speed(attack_speed, decay_speed)
    if decay_speed == nil then decay_speed = attack_speed end
    self._attack_speed = attack_speed
    self._decay_speed = decay_speed
end

--- @brief
function rt.SmoothedMotion1D:update(delta)
    local distance = self._target_value - self._current_value
    local step
    if distance > 0 then
        step = self._ramp * distance * self._attack_speed * delta
    else
        step = self._ramp * distance * self._decay_speed * delta
    end

    self._current_value = self._current_value + step

    if  (distance > 0 and self._current_value > self._target_value) or
        (distance < 0 and self._current_value < self._target_value)
    then
        self._current_value = self._target_value
    end

    return self._current_value
end

--- @brief
function rt.SmoothedMotion1D:set_value(x)
    self._current_value = x
end

--- @brief
function rt.SmoothedMotion1D:skip()
    self:set_value(self._target_value)
end