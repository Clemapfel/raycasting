--- @class rt.FlowMotion
rt.FlowMotion = meta.class("FlowMotion")

--- @brief
function rt.FlowMotion:instantiate(attack_duration, decay_duration)
    self._attack_duration = attack_duration or 1
    self._decay_duration = decay_duration or 1
    self._current_value = 0
    self._target_value = 0
end

--- @brief
function rt.FlowMotion:get_value()
    return self._current_value
end

--- @brief
function rt.FlowMotion:get_target_value()
    return self._target_value
end

--- @brief
function rt.FlowMotion:set_target_value(x)
    self._target_value = x
end
--- @brief
function rt.FlowMotion:update(delta)
    local difference = self._target_value - self._current_value

    local duration
    if difference >= 0 then
        duration = self._attack_duration
    else
        duration = self._decay_duration
    end

    self._current_value = self._current_value + difference * (1 - math.exp(-delta / duration))
    return self._current_value
end

--- @brief
function rt.FlowMotion:set_attack_duration(seconds)
    self._attack_duration = seconds
end

--- @brief
function rt.FlowMotion:set_decay_duration(seconds)
    self._decay_duration = seconds
end

--- @brief
function rt.FlowMotion:set_value(x)
    self._current_value = x
end

--- @brief
function rt.FlowMotion:skip()
    self:set_value(self._target_value)
end