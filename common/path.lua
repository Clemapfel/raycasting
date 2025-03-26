--- @class rt.Path
--- @brief arc-length parameterized chain of line segments, unlike spline, extremely fast to evaluate
rt.Path = meta.class("Path")

--- @brief
function rt.Path:instantiate(points, ...)
    if meta.is_number(points) then
        points = {points, ...}
    end

    assert(#points >= 2 and #points % 2 == 0)
    local out = meta.install(self, {
        _points = points,
        _distances = {},
        _n_points = 0,
        _first_distance = 0,
        _last_distance = 0
    })
    out:create_from(points, ...)
    return out
end

do
    local _sqrt = math.sqrt -- upvalues for optimization
    local _insert = table.insert
    local _atan2, _sin, _cos = math.atan2, math.sin, math.cos
    local _ceil = math.ceil

    --- @brief
    function rt.Path:_update()
        local distances = {}
        local points = self._points
        local n = self._n_points
        local total_length = 0
        local n_entries = 0

        local first_distance, last_distance

        for i = 1, n - 2, 2 do
            local x1, y1 = self._points[i+0], self._points[i+1]
            local x2, y2 = self._points[i+2], self._points[i+3]

            local distance = _sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2))
            local slope = (y2 - y1) / (x2 - x1)
            local to_insert = {
                from_x = x1,
                from_y = y1,
                angle = _atan2(y2 - y1, x2 - x1),
                distance = distance,
                cumulative_distance = total_length,
                cumulative_fraction = nil,
                fraction = nil,
                fraction_length = nil
            }
            _insert(distances, to_insert)
            total_length = total_length + distance
            n_entries = n_entries + 1
        end

        if n_entries == 1 then
            local entry = distances[1]
            entry.fraction = 0
            entry.fraction_length = 1
            entry.cumulate_fraction = 0
        else
            for i = 1, n_entries - 1 do
                local current = distances[i]
                local next = distances[i + 1]

                if total_length == 0 then
                    current.fraction = 0
                    next.fraction = 0
                    current.fraction_length = 0
                else
                    current.fraction = current.cumulative_distance / total_length
                    next.fraction = next.cumulative_distance / total_length
                    current.fraction_length = next.fraction - current.fraction
                end

                if i == 1 then self._first_distance = current.fraction end
                if i == n_entries - 1 then self._last_distance = next.fraction end
            end

            do
                local last = distances[n_entries]
                last.fraction_length = 1 - last.fraction
            end
        end

        self._entries = distances
        self._n_entries = n_entries
        self._length = total_length
    end

    --- @brief
    function rt.Path:at(t)
        if t > 1 then t = 1 elseif t < 0 then t = 0 end
        local n_entries = self._n_entries
        local entries = self._entries

        local closest_entry
        if n_entries == 1 then
            closest_entry = self._entries[1]
        elseif n_entries == 2 then
            if t <= self._entries[2].fraction then
                closest_entry = self._entries[1]
            else
                closest_entry = self._entries[2]
            end
        else
            local low = 1
            local high = n_entries
            while low < high do
                local mid = _ceil((low + high) / 2)
                local left = entries[mid]
                local right = entries[mid+1]
                if left.fraction < t and right.fraction > t then
                    closest_entry = left
                    break
                elseif t < left.fraction then
                    high = mid - 1
                else
                    low = mid + 1
                end
            end

            if not closest_entry then
                closest_entry = entries[low]
            end
        end

        -- translate point along line from current to next entry
        local delta = (t - closest_entry.fraction) / closest_entry.fraction_length * closest_entry.distance
        return closest_entry.from_x + delta * _cos(closest_entry.angle),
        closest_entry.from_y + delta * _sin(closest_entry.angle)
    end
end

--- @brief
function rt.Path:create_from(points, ...)
    if meta.is_number(points) then points = {points, ...} end
    self._points = points
    local n_points = #points
    assert(n_points >= 4, "In rt.Path: need at least 2 points to draw a path")
    assert(n_points % 2 == 0, "In rt.Path: number of point coordinates is not a multiple of two")
    self._n_points = n_points
    self:_update()
end

--- @brief
function rt.Path:list_points()
    local out = {}
    for i = 1, #self._points, 2 do
        table.insert(out, {self._points[i], self._points[i+1]})
    end
    return out
end

--- @brief
function rt.Path:get_length()
    return self._length
end

--- @brief
function rt.Path:draw()
    love.graphics.line(self._points)
end

--- @brief override arclength parameterization with custom per-edge fraction
--- @param ... Number n-1 values, where n is the number of points, has to sum to 1
function rt.Path:override_parameterization(...)
    local total = 0
    if select("#", ...) ~= self._n_entries then
        rt.error("In rt.Path.override_parametrization: expected `" .. self._n_entries .. "` parameters, got `" .. select("#", ...) .. "`")
        return
    end

    local fraction = 0
    for i = 1, self._n_entries do
        local arg = select(i, ...)
        local entry = self._entries[i]
        entry.fraction = fraction
        entry.fraction_length = arg

        fraction = fraction + arg
        total = total + arg
    end

    if not total == 1 then
        rt.error("In rt.Path:override_parametrization: total length of override paramters is `" .. total .. "`, but `1` was expected")
        return
    end
end