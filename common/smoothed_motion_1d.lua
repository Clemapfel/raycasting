--- @class rt.SmoothedMotion1D
rt.SmoothedMotion1D = meta.class("SmoothedMotion1D")

--- @brief
function rt.SmoothedMotion1D:instantiate(value, speed)
    if speed == nil then speed = 100 end
    meta.assert(value, "Number", speed, "Number")
    meta.install(self, {
        _speed = speed,
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
function rt.SmoothedMotion1D:update(delta)
    local distance = self._target_value - self._current_value
    local step = 6 * distance * self._speed * delta

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