--- @class rt.SmoothedMotion3D
rt.SmoothedMotion3D = meta.class("SmoothedMotion3D")

--- @brief
function rt.SmoothedMotion3D:instantiate(position_x, position_y, position_z, speed)
    if position_x == nil then position_x = 0 end
    if position_y == nil then position_y = position_x end
    if position_z == nil then position_z = position_y end
    if speed == nil then speed = 1 end
    meta.assert(position_x, "Number", position_y,  "Number", speed, "Number")
    meta.install(self, {
        _speed = speed,
        _current_position_x = position_x,
        _current_position_y = position_y,
        _current_position_z = position_z,
        _target_position_x = position_x,
        _target_position_y = position_y,
        _target_position_z = position_z
    })
end

--- @brief
function rt.SmoothedMotion3D:set_position(x, y, z)
    self._current_position_x, self._current_position_y, self._current_position_z = x, y, z
end

--- @brief
function rt.SmoothedMotion3D:get_position()
    return self._current_position_x, self._current_position_y, self._current_position_z
end

--- @brief
function rt.SmoothedMotion3D:set_target_position(x, y, z)
    self._target_position_x, self._target_position_y, self._target_position_z = x, y, z
end

--- @brief
function rt.SmoothedMotion3D:get_target_position()
    return self._target_position_x, self._target_position_y, self._target_position_z
end

--- @brief
function rt.SmoothedMotion3D:set_speed(speed)
    self._speed = speed
end

--- @brief
function rt.SmoothedMotion3D:update(delta)
    local distance_x = self._target_position_x - self._current_position_x
    local distance_y = self._target_position_y - self._current_position_y
    local distance_z = self._target_position_z - self._current_position_z

    local step_x = 6 * distance_x * self._speed * delta
    local step_y = 6 * distance_y * self._speed * delta
    local step_z = 6 * distance_z * self._speed * delta

    self._current_position_x = self._current_position_x + step_x
    self._current_position_y = self._current_position_y + step_y
    self._current_position_z = self._current_position_z + step_z

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

    if  (distance_z > 0 and self._current_position_z > self._target_position_z) or
        (distance_z < 0 and self._current_position_z < self._target_position_z)
    then
        self._current_position_z = self._target_position_z
    end

    return self._current_position_x, self._current_position_y, self._current_position_z
end

--- @brief
function rt.SmoothedMotion3D:skip()
    self._current_position_x, self._current_position_y, self._current_position_z = self._target_position_x, self._target_position_y, self._target_position_z
end