--- @class rt.SmoothedMotion1D
rt.SmoothedMotion1D = meta.class("SmoothedMotion1D")

--- @brief
function rt.SmoothedMotion1D:instantiate(value, speed, ramp)
    if ramp == nil then ramp = 6 end
    if speed == nil then speed = 1 end
    meta.assert(value, "Number", speed, "Number")

    self._attack_speed = speed
    self._decay_speed = speed
    self._ramp = ramp
    self._current_value = value
    self._target_value = value
    self._elapsed = 0

    self._is_periodic = false
    self._lower_bound = 0
    self._upper_bound = 1
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
    local distance
    if self._is_periodic then
        local range = self._upper_bound - self._lower_bound
        local direct_distance = self._target_value - self._current_value
        local wrapped_distance = direct_distance - range * math.floor((direct_distance + range * 0.5) / range)
        distance = wrapped_distance
    else
        distance = self._target_value - self._current_value
    end

    local step
    if distance > 0 then
        step = self._ramp * distance * self._attack_speed * delta
    else
        step = self._ramp * distance * self._decay_speed * delta
    end

    self._current_value = self._current_value + step

    if self._is_periodic then
        local range = self._upper_bound - self._lower_bound
        self._current_value = self._lower_bound + ((self._current_value - self._lower_bound) % range)

        local final_distance = self._target_value - self._current_value
        local wrapped_final_distance = final_distance - range * math.floor((final_distance + range * 0.5) / range)
        if math.abs(wrapped_final_distance) < math.abs(step) then
            self._current_value = self._target_value
        end
    else
        if  (distance > 0 and self._current_value > self._target_value) or
            (distance < 0 and self._current_value < self._target_value)
        then
            self._current_value = self._target_value
        end
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

--- @brief
function rt.SmoothedMotion1D:set_speed(speed)
    self._attack_speed = speed
    self._decay_speed = speed
end

--- @brief
function rt.SmoothedMotion1D:set_attack_speed(speed)
    self._attack_speed = speed
end

--- @brief
function rt.SmoothedMotion1D:set_decay_speed(speed)
    self._decay_speed = speed
end

--- @brief
function rt.SmoothedMotion1D:set_is_periodic(b, lower, upper)
    if b == true then
        meta.assert(b, "Boolean", lower, "Number", upper, "Number")
    end

    self._is_periodic = b
    if lower ~= nil then
        self._lower_bound = lower
    end

    if upper ~= nil then
        self._upper_bound = upper
    end
end