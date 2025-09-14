--- @class rt.Path
--- @brief arc-length parameterized chain of line segments, unlike spline, extremely fast to evaluate
rt.Path = meta.class("Path")

--- @brief
function rt.Path:instantiate(points, ...)
    if meta.is_number(points) then
        points = {points, ...}
    end

    assert(#points >= 4, "In rt.Path: need at least 2 points (4 coordinates) to create a path")
    assert(#points % 2 == 0, "In rt.Path: number of point coordinates must be even")

    local out = meta.install(self, {
        _points = points,
        _entries = {},
        _n_points = #points,
        _n_entries = 0,
        _length = 0,
        _first_distance = 0,
        _last_distance = 0
    })
    out:create_from(points, ...)
    return out
end

--- @brief
function rt.Path:_update()
    local entries = {}
    local points = self._points
    local n_points = self._n_points
    local total_length = 0
    local n_entries = 0

    -- create entries for each line segment
    for i = 1, n_points - 2, 2 do
        local x1, y1 = points[i], points[i+1]
        local x2, y2 = points[i+2], points[i+3]

        local dx = x2 - x1
        local dy = y2 - y1
        local distance = math.distance(x1, y1, x2, y2)
        dx, dy = math.normalize(dx, dy)

        local entry = {
            from_x = x1,
            from_y = y1,
            to_x = x2,
            to_y = y2,
            dx = dx,  -- normalized direction vector
            dy = dy,
            distance = distance,
            cumulative_distance = total_length,
            fraction = 0, -- set below
            fraction_length = 0
        }

        table.insert(entries, entry)
        total_length = total_length + distance
        n_entries = n_entries + 1
    end

    if n_entries == 1 then
        entries[1].fraction = 0
        entries[1].fraction_length = 1
    else
        -- calculate fractions for multiple segments
        for i = 1, n_entries do
            local entry = entries[i]
            if total_length > 0 then
                entry.fraction = entry.cumulative_distance / total_length
                if i < n_entries then
                    local next_entry = entries[i + 1]
                    entry.fraction_length = (next_entry.cumulative_distance - entry.cumulative_distance) / total_length
                else
                    entry.fraction_length = (total_length - entry.cumulative_distance) / total_length
                end
            else
                -- handle degenerate case where all segments have zero length
                entry.fraction = i == 1 and 0 or 1
                entry.fraction_length = 0
            end
        end
    end

    self._entries = entries
    self._n_entries = n_entries
    self._length = total_length
    self._first_distance = n_entries > 0 and entries[1].fraction or 0
    self._last_distance = n_entries > 0 and entries[n_entries].fraction or 0
end

--- @brief
function rt.Path:_find_segment(t)
    local entries = self._entries
    local n_entries = self._n_entries

    if n_entries == 0 then
        return nil
    end

    if n_entries == 1 then
        return entries[1]
    end

    if t <= 0 then
        return entries[1]
    elseif t >= 1 then
        return entries[n_entries]
    end

    -- binary search for the correct segment
    local low = 1
    local high = n_entries

    while low <= high do
        local mid = math.floor((low + high) / 2)
        local entry = entries[mid]
        local entry_end = entry.fraction + entry.fraction_length

        if t >= entry.fraction and t <= entry_end then
            return entry
        elseif t < entry.fraction then
            high = mid - 1
        else
            low = mid + 1
        end
    end

    return entries[math.clamp(low, 1, n_entries)]
end

--- @brief get position at parameter t [0, 1]
function rt.Path:at(t)
    t = math.clamp(t, 0, 1)

    local segment = self:_find_segment(t)
    local local_t = (t - segment.fraction) / segment.fraction_length

    local distance_along_segment = local_t * segment.distance
    return math.add(
        segment.from_x,
        segment.from_y,
        segment.dx * distance_along_segment,
        segment.dy * distance_along_segment
    )
end

--- @brief
function rt.Path:get_segment(t)
    local segment = self:_find_segment(math.clamp(t, 0, 1))
    return segment.from_x, segment.from_y, segment.to_x, segment.to_y
end

--- @brief
function rt.Path:get_tangent(t)
    local segment = self:_find_segment(math.clamp(t, 0, 1))
    return segment.dx, segment.dy
end

--- @brief
function rt.Path:create_from(points, ...)
    if meta.is_number(points) then
        points = {points, ...}
    end

    local n_points = #points
    assert(n_points >= 4, "In rt.Path: need at least 2 points (4 coordinates) to draw a path")
    assert(n_points % 2 == 0, "In rt.Path: number of point coordinates must be even")

    self._points = points
    self._n_points = n_points
    self:_update()
end

--- @brief
function rt.Path:list_points()
    local out = {}
    for i = 1, self._n_points, 2 do
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
    if self._n_points >= 4 then
        love.graphics.line(self._points)
    end
end

--- @brief override arclength parameterization with custom per-segment fraction
--- @param ... Number of values equal to number of segments, must sum to 1
function rt.Path:override_parameterization(...)
    local n_args = select("#", ...)
    if n_args ~= self._n_entries then
        rt.error("In rt.Path.override_parameterization: expected `" .. self._n_entries .. "` parameters, got `" .. n_args .. "`")
        return
    end

    local total = 0
    local args = {...}

    -- validate arguments sum to 1
    for i = 1, n_args do
        local arg = args[i]
        if type(arg) ~= "number" or arg < 0 then
            rt.error("In rt.Path:override_parameterization: parameter " .. i .. " must be a non-negative number")
            return
        end
        total = total + arg
    end

    if math.abs(total - 1) > 1e-10 then
        rt.error("In rt.Path:override_parameterization: total length of override parameters is `" .. total .. "`, but `1` was expected")
        return
    end

    local fraction = 0
    for i = 1, self._n_entries do
        local entry = self._entries[i]
        entry.fraction = fraction
        entry.fraction_length = args[i]
        fraction = fraction + args[i]
    end
end

--- @brief Get the number of segments in the path
function rt.Path:get_segment_count()
    return self._n_entries
end

--- @brief helper function to find closest point on a specific line segment
--- @param x Number query point x
--- @param y Number query point y  
--- @param entry Table segment entry from self._entries
--- @return Number, Number, Number closest point x, y and global parameter t
function rt.Path:_closest_point_on_segment(x, y, entry)
    local x1, y1 = entry.from_x, entry.from_y
    local x2, y2 = entry.to_x, entry.to_y

    -- vector from start to end of segment
    local segment_dx = x2 - x1
    local segment_dy = y2 - y1
    local segment_length_sq = segment_dx * segment_dx + segment_dy * segment_dy

    if segment_length_sq < 1e-10 then
        -- degenerate segment
        local global_t = entry.fraction + entry.fraction_length * 0.5
        return x1, y1, global_t
    end

    local dot = (x - x1) * segment_dx + (y - y1) * segment_dy
    local local_t = math.clamp(dot / segment_length_sq, 0, 1)

    local closest_x = x1 + local_t * segment_dx
    local closest_y = y1 + local_t * segment_dy
    local global_t = entry.fraction + entry.fraction_length * local_t

    return closest_x, closest_y, global_t
end

--- @brief 
function rt.Path:get_closest_point(x, y)
    if self._n_entries == 0 then
        return nil, nil, nil
    end

    local closest_distance_sq = math.huge
    local closest_x, closest_y = nil, nil
    local closest_t = 0

    for i = 1, self._n_entries do
        local entry = self._entries[i]
        local segment_x, segment_y, segment_t = self:_closest_point_on_segment(x, y, entry)

        local dx = segment_x - x
        local dy = segment_y - y
        local distance_sq = dx * dx + dy * dy

        if distance_sq < closest_distance_sq then
            closest_distance_sq = distance_sq
            closest_x = segment_x
            closest_y = segment_y
            closest_t = segment_t
        end
    end

    return closest_x, closest_y, closest_t
end

--- @brief
function rt.Path:get_points()
    return self._points
end