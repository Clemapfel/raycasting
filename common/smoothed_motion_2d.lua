--- @class rt.SmoothedMotion2D
rt.SmoothedMotion2D = meta.class("SmoothedMotion2D")

--- @brief
function rt.SmoothedMotion2D:instantiate(position_x, position_y, speed, is_linear)
    if position_x == nil then position_x = 0 end
    if position_y == nil then position_y = position_x end
    if speed == nil then speed = 1 end
    if is_linear == nil then is_linear = false end

    meta.assert(position_x, mt.Number, position_y,  mt.Number, speed, mt.Number, is_linear, mt.Boolean)
    self._speed = speed
    self._ramp = math.ln(1000) -- 1s lag time
    self._current_position_x = position_x
    self._current_position_y = position_y
    self._target_position_x = position_x
    self._target_position_y = position_y
    self._is_linear = is_linear -- kept for compatibility, no longer affects update
end

--- @brief
function rt.SmoothedMotion2D:set_position(x, y)
    self._current_position_x, self._current_position_y = x, y
end

--- @brief
function rt.SmoothedMotion2D:get_position()
    return self._current_position_x, self._current_position_y
end

--- @brief
function rt.SmoothedMotion2D:set_target_position(x, y)
    if math.is_nan(x) or math.is_nan(y) then
        rt.error("In rt.SmoothedMotion2D.set_target_position: argument is NaN")
        return
    end

    self._target_position_x, self._target_position_y = x, y
end

--- @brief
function rt.SmoothedMotion2D:get_target_position()
    return self._target_position_x, self._target_position_y
end

--- @brief
function rt.SmoothedMotion2D:set_speed(speed)
    self._speed = speed
end

--- @brief set speed such that 99.9% of a step is covered in `seconds`
function rt.SmoothedMotion2D:set_lag_time(seconds)
    self._speed = 1 / seconds
end

--- @brief
function rt.SmoothedMotion2D:update(delta)
    local alpha = 1 - math.exp(-self._ramp * self._speed * delta)

    self._current_position_x = self._current_position_x + (self._target_position_x - self._current_position_x) * alpha
    self._current_position_y = self._current_position_y + (self._target_position_y - self._current_position_y) * alpha

    local threshold = 0.001
    if math.abs(self._target_position_x - self._current_position_x) < threshold then
        self._current_position_x = self._target_position_x
    end
    if math.abs(self._target_position_y - self._current_position_y) < threshold then
        self._current_position_y = self._target_position_y
    end

    return self._current_position_x, self._current_position_y
end

--- @brief
function rt.SmoothedMotion2D:skip()
    self._current_position_x, self._current_position_y = self._target_position_x, self._target_position_y
end