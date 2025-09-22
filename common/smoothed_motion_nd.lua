rt.settings.smoothed_motion_nd = {
    -- fraction / second; 1.0 means a full lerp to the target over one second
    default_duration = 1,
}

--- @class rt.SmoothedMotionND
rt.SmoothedMotionND = meta.class("SmoothedMotionND")

local _stop_dimension = -math.huge

--- @brief
function rt.SmoothedMotionND:instantiate(speed)
    self._speed = math.log(100) / (6 * rt.settings.smoothed_motion_nd.default_duration)
    self._dimensions = {} -- Set
    self._current_position = {}
    self._target_dimension = nil
end

--- @brief
function rt.SmoothedMotionND:add_dimension(id, value)
    if value == nil then value = 0 end

    local make_current = table.is_empty(self._dimensions)

    if self._dimensions[id] then
        self:set_dimension(id, value)
        return
    end

    self._dimensions[id] = true
    self._current_position[id] = math.clamp(value, 0, 1)
    if make_current then self:set_target_dimension(id) end
end

--- @brief
function rt.SmoothedMotionND:remove_dimension(id)
    if self._dimensions[id] == nil then
        rt.error("In rt.SmoothedMotionND:remove_dimension: no dimension with id `" .. tostring(id) .. "`")
        return
    end

    self._dimensions[id] = nil
    self._current_position[id] = nil

    if self._target_dimension == id then
        self._target_dimension = nil
    end
end

--- @brief
function rt.SmoothedMotionND:set_target_dimension(id)
    if self._dimensions[id] == nil then
        self:add_dimension(id, 0)
    end

    self._target_dimension = id
end

function rt.SmoothedMotionND:set_dimension(id, value)
    if self._dimensions[id] == nil then
        rt.error("In rt.SmoothedMotionND:set_dimension: no dimension with id `" .. tostring(id) .. "`")
        return
    end

    value = math.clamp(value or 0)
    local dimension_count = table.sizeof(self._dimensions)

    if dimension_count == 1 then
        self._current_position[id] = value
        return
    end

    local other_sum = 0
    for other_id in keys(self._dimensions) do
        if other_id ~= id then
            other_sum = other_sum + (self._current_position[other_id] or 0)
        end
    end

    self._current_position[id] = value
    local remaining = 1 - value

    -- if other dimensions currently sum to 0, distribute equally
    if other_sum == 0 then
        local equal_share = remaining / (dimension_count - 1)
        for other_id in pairs(self._dimensions) do
            if other_id ~= id then
                self._current_position[other_id] = equal_share
            end
        end
    else
        -- redistribute proportionally based on current values
        local scale_factor = remaining / other_sum
        for other_id in pairs(self._dimensions) do
            if other_id ~= id then
                local current_value = self._current_position[other_id] or 0
                self._current_position[other_id] = current_value * scale_factor
            end
        end
    end
end

--- @brief
function rt.SmoothedMotionND:update(delta)
    meta.assert(delta, "Number")

    local target_id = self._target_dimension

    local speed = self._speed

    -- compute distances to per-dimension targets
    local distances = {}
    for id, value in pairs(self._current_position) do
        local target
        if target_id == _stop_dimension then
            -- when stopping, all dimensions move to 0
            target = 0
            speed = speed^2
        else
            -- normal behavior: target dimension moves to 1, others to 0
            target = (id == target_id) and 1 or 0
        end
        distances[id] = target - value
    end

    -- advance with exponential smoothing
    for id, value in pairs(self._current_position) do
        local distance = distances[id]
        local step = 6 * distance * speed * delta
        local next_value = value + step
        self._current_position[id] = next_value
    end

    -- clamp overshoot exactly at the targets
    for id in keys(self._current_position) do
        local target
        if target_id == _stop_dimension then
            target = 0
        else
            target = (id == target_id) and 1 or 0
        end

        local distance = distances[id]
        local v = self._current_position[id]

        if (distance > 0 and v > target) or (distance < 0 and v < target) then
            self._current_position[id] = target
        end

        -- also clamp to [0, 1] against numerical drift
        if self._current_position[id] < 0 then self._current_position[id] = 0 end
        if self._current_position[id] > 1 then self._current_position[id] = 1 end
    end
end

--- @brief
function rt.SmoothedMotionND:get_dimension(...)
    if select("#", ...) == 1 then
        local id = select(1, ...)
        if self._dimensions[id] == nil then
            rt.error("In rt.SmoothedMotionND: no dimension with id `" .. tostring(id) .. "`")
        end
        return self._current_position[id] or 0
    else
        local out = {}
        for i = 1, select("#", ...) do
            local id = select(i, ...)
            if self._dimensions[id] == nil then
                rt.error("In rt.SmoothedMotionND: no dimension with id `" .. tostring(id) .. "`")
            end
            table.insert(out, self._current_position[id] or 0)
        end
        return table.unpack(out)
    end
end

--- @brief Get the currently set target dimension id or nil
function rt.SmoothedMotionND:get_target_dimension()
    return self._target_dimension
end

--- @brief
function rt.SmoothedMotionND:get_ids()
    local out = {}
    for id in keys(self._dimensions) do
        table.insert(out, id)
    end
    return out
end

--- @brief
function rt.SmoothedMotionND:stop()
    self._target_dimension = _stop_dimension
end
