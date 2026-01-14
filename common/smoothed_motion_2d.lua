--- @class rt.SmoothedMotion2D
rt.SmoothedMotion2D = meta.class("SmoothedMotion2D")

--- @brief
function rt.SmoothedMotion2D:instantiate(position_x, position_y, speed, is_linear)
    if position_x == nil then position_x = 0 end
    if position_y == nil then position_y = position_x end
    if speed == nil then speed = 1 end
    if is_linear == nil then is_linear = false end

    meta.assert(position_x, "Number", position_y,  "Number", speed, "Number", is_linear, "Boolean")
    self._speed = speed
    self._current_position_x = position_x
    self._current_position_y = position_y
    self._target_position_x = position_x
    self._target_position_y = position_y
    self._is_linear = is_linear
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

--- @brief
function rt.SmoothedMotion2D:update(delta)
    if self._is_linear ~= true then
        local distance_x = self._target_position_x - self._current_position_x
        local distance_y = self._target_position_y - self._current_position_y

        local step_x = 6 * distance_x * self._speed * delta
        local step_y = 6 * distance_y * self._speed * delta

        self._current_position_x = self._current_position_x + step_x
        self._current_position_y = self._current_position_y + step_y

        if  (distance_x > 0 and self._current_position_x > self._target_position_x) or
            (distance_x < 0 and self._current_position_x < self._target_position_x)
        then
            self._current_position_x = self._target_position_x
        end

        if  (distance_y > 0 and self._current_position_y > self._target_position_y) or
            (distance_y < 0 and self._current_position_y < self._target_position_y)
        then
            self._current_position_y = self._target_position_y
        end

        return self._current_position_x, self._current_position_y
    else
        local t = 1 - math.exp(-self._speed * delta)

        self._current_position_x = self._current_position_x + (self._target_position_x - self._current_position_x) * t
        self._current_position_y = self._current_position_y + (self._target_position_y - self._current_position_y) * t

        local threshold = 0.001
        if math.abs(self._target_position_x - self._current_position_x) < threshold then
            self._current_position_x = self._target_position_x
        end
        if math.abs(self._target_position_y - self._current_position_y) < threshold then
            self._current_position_y = self._target_position_y
        end

        return self._current_position_x, self._current_position_y
    end
end

--- @brief
function rt.SmoothedMotion2D:skip()
    self._current_position_x, self._current_position_y = self._target_position_x, self._target_position_y
end